//
//  CompanionGitRegistry.swift
//  HermesHostCompanion
//

import Foundation

enum CompanionGitRegistryError: LocalizedError {
    case invalidWorkspace(String)
    case missingHermesRepository(String)
    case gitCommandFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidWorkspace(let path):
            "Hermes workspace does not exist: \(path)"
        case .missingHermesRepository(let path):
            "Hermes Agent repository was not found at \(path)."
        case .gitCommandFailed(let message):
            message
        }
    }
}

final class CompanionGitRegistry {
    private let officialRepositoryURL = "https://github.com/NousResearch/hermes-agent.git"
    private let forkRepositoryURL = "git@github.com:lad75020/hermes-agent.git"
    private let officialMainRef = "refs/remotes/hermes-official/main"
    private let localMainBranch = "main"
    private let upstreamLatestBranch = "upstream-latest"
    private let pendingBranchConfigKey = "hermesios.pendingUpdateBranch"
    private let pendingCommitConfigKey = "hermesios.pendingUpdateCommit"
    private let pendingConflictsConfigKey = "hermesios.pendingUpdateConflicts"
    private let lastUpdateOutputConfigKey = "hermesios.lastUpdateOutput"

    func hermesInstallationStatus(workspacePath: String) async throws -> HermesInstallationStatusResult {
        let repoURL = try hermesRepoURL(workspacePath: workspacePath)
        _ = try await runGit(["fetch", "--quiet", officialRepositoryURL, "main:\(officialMainRef)"], repoURL: repoURL, timeout: 60)
        return try await status(workspacePath: workspacePath, repoURL: repoURL)
    }

    func updateHermesInstallation(workspacePath: String) async throws -> HermesInstallationOperationResult {
        let repoURL = try hermesRepoURL(workspacePath: workspacePath)
        try ensureNoMergeInProgress(repoURL: repoURL)
        try await ensureCleanWorkingTree(repoURL: repoURL)
        try await ensureLocalMainBranchExists(repoURL: repoURL)

        var output: [String] = []
        let startingBranch = try await runGit(["branch", "--show-current"], repoURL: repoURL, timeout: 10).trimmedOutput
        if startingBranch != localMainBranch {
            _ = try await runGit(["switch", localMainBranch], repoURL: repoURL, timeout: 30)
            output.append("Switched from \(startingBranch.isEmpty ? "detached HEAD" : startingBranch) to local main.")
        }

        let fetchOutput = try await runGit([
            "fetch",
            officialRepositoryURL,
            "+main:refs/heads/\(upstreamLatestBranch)",
            "+main:\(officialMainRef)"
        ], repoURL: repoURL, timeout: 120).trimmedOutput
        let upstreamCommit = try await runGit(["rev-parse", "--short", upstreamLatestBranch], repoURL: repoURL, timeout: 10).trimmedOutput
        output.append("Pulled NousResearch/hermes-agent main into local \(upstreamLatestBranch) at \(upstreamCommit).")
        if fetchOutput.isEmpty == false {
            output.append(fetchOutput)
        }

        let mergeResult = try await runGitAllowingFailure(["merge", "--no-ff", upstreamLatestBranch], repoURL: repoURL, timeout: 180)
        if mergeResult.exitCode != 0 {
            let conflictFiles = try await unresolvedConflictFiles(repoURL: repoURL)
            let conflictMessage: String
            if conflictFiles.isEmpty {
                conflictMessage = "Merge stopped before push. Resolve the local git state on the Mac, then refresh."
            } else {
                conflictMessage = "Merge conflicts detected; push was not attempted. Resolve these files on the Mac:\n\(conflictFiles.joined(separator: "\n"))"
            }
            output.append(mergeResult.output)
            output.append(conflictMessage)
            try await setGitConfig(pendingBranchConfigKey, value: localMainBranch, repoURL: repoURL)
            try await setGitConfig(pendingCommitConfigKey, value: upstreamCommit, repoURL: repoURL)
            try await setGitConfig(pendingConflictsConfigKey, value: conflictFiles.joined(separator: "\n"), repoURL: repoURL)
            let operationMessage = output.filter { $0.isEmpty == false }.joined(separator: "\n\n")
            try await setGitConfig(lastUpdateOutputConfigKey, value: operationMessage, repoURL: repoURL)
            let currentStatus = try await status(workspacePath: workspacePath, repoURL: repoURL, skipFetch: true)
            return HermesInstallationOperationResult(status: currentStatus, output: operationMessage)
        }

        if mergeResult.output.isEmpty == false {
            output.append(mergeResult.output)
        } else {
            output.append("Merged \(upstreamLatestBranch) into local main.")
        }

        let pushTarget = try await pushRemoteTarget(repoURL: repoURL)
        let pushOutput = try await runGit(["push", pushTarget, "main:main"], repoURL: repoURL, timeout: 180).trimmedOutput
        output.append("Pushed local main to lad75020/hermes-agent main.")
        if pushOutput.isEmpty == false {
            output.append(pushOutput)
        }

        try await clearPendingUpdateConfig(repoURL: repoURL)
        let operationMessage = output.filter { $0.isEmpty == false }.joined(separator: "\n\n")
        try await setGitConfig(lastUpdateOutputConfigKey, value: operationMessage, repoURL: repoURL)
        let currentStatus = try await status(workspacePath: workspacePath, repoURL: repoURL, skipFetch: true)
        return HermesInstallationOperationResult(status: currentStatus, output: operationMessage)
    }

    func reviewHermesInstallationConflicts(workspacePath: String) throws -> HermesInstallationOperationResult {
        throw CompanionGitRegistryError.gitCommandFailed("Conflict review was removed. Resolve merge conflicts on the Mac, then refresh Hermes Installation status.")
    }

    func mergeReviewedHermesInstallationUpdate(workspacePath: String) throws -> HermesInstallationOperationResult {
        throw CompanionGitRegistryError.gitCommandFailed("The separate merge step was removed. Use Update Hermes to fetch, merge, and push in one workflow.")
    }

    private func status(workspacePath: String, repoURL: URL, skipFetch: Bool = false) async throws -> HermesInstallationStatusResult {
        if skipFetch == false {
            _ = try await runGit(["fetch", "--quiet", officialRepositoryURL, "main:\(officialMainRef)"], repoURL: repoURL, timeout: 60)
        }
        let branch = try await runGit(["branch", "--show-current"], repoURL: repoURL, timeout: 10).trimmedOutput
        let currentCommit = try await runGit(["rev-parse", "--short", localMainBranch], repoURL: repoURL, timeout: 10).trimmedOutput
        let upstreamCommit = try await runGit(["rev-parse", "--short", officialMainRef], repoURL: repoURL, timeout: 10).trimmedOutput
        let behindOutput = try await runGit(["rev-list", "--count", "\(localMainBranch)..\(officialMainRef)"], repoURL: repoURL, timeout: 10).trimmedOutput
        let remoteURL = (try? await runGit(["remote", "get-url", "origin"], repoURL: repoURL, timeout: 10).trimmedOutput) ?? ""
        let conflictFiles = try await unresolvedConflictFiles(repoURL: repoURL)
        let mergeInProgress = isMergeInProgress(repoURL: repoURL)
        var pendingBranch = mergeInProgress ? localMainBranch : ""
        var pendingCommit = mergeInProgress ? upstreamCommit : ""
        var lastUpdateOutput = try await gitConfigValue(lastUpdateOutputConfigKey, repoURL: repoURL)
        if mergeInProgress == false {
            try await clearPendingUpdateConfig(repoURL: repoURL)
            if conflictFiles.isEmpty == false {
                lastUpdateOutput = "Unresolved conflict files were found, but no merge is marked in progress. Resolve them on the Mac before updating again."
                try await setGitConfig(lastUpdateOutputConfigKey, value: lastUpdateOutput, repoURL: repoURL)
            }
        }

        return HermesInstallationStatusResult(
            workspacePath: workspacePath,
            resolvedWorkspacePath: repoURL.deletingLastPathComponent().path,
            repositoryPath: repoURL.path,
            remoteURL: remoteURL,
            branch: branch,
            currentCommit: currentCommit,
            upstreamCommit: upstreamCommit,
            behindBy: Int(behindOutput) ?? 0,
            checkedAt: Date(),
            pendingUpdateBranch: pendingBranch.isEmpty ? nil : pendingBranch,
            pendingUpdateCommit: pendingCommit.isEmpty ? nil : pendingCommit,
            conflictFiles: conflictFiles,
            lastUpdateOutput: lastUpdateOutput
        )
    }

    private func hermesRepoURL(workspacePath: String) throws -> URL {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let repoURL = workspaceURL.appendingPathComponent("hermes-agent", isDirectory: true)
        guard FileManager.default.fileExists(atPath: repoURL.appendingPathComponent(".git").path) else {
            throw CompanionGitRegistryError.missingHermesRepository(repoURL.path)
        }
        return repoURL
    }

    private func ensureCleanWorkingTree(repoURL: URL) async throws {
        let status = try await runGit(["status", "--porcelain"], repoURL: repoURL, timeout: 10).trimmedOutput
        guard status.isEmpty else {
            throw CompanionGitRegistryError.gitCommandFailed("Commit, stash, or discard local working-tree changes before updating Hermes Agent.")
        }
    }

    private func unresolvedConflictFiles(repoURL: URL) async throws -> [String] {
        try await runGit(["diff", "--name-only", "--diff-filter=U"], repoURL: repoURL, timeout: 10)
            .split(separator: "\n")
            .map(String.init)
            .filter { $0.isEmpty == false }
    }

    private func isAncestor(_ ancestor: String, of descendant: String, repoURL: URL) async throws -> Bool {
        let result = try await runGitAllowingFailure(["merge-base", "--is-ancestor", ancestor, descendant], repoURL: repoURL, timeout: 10)
        return result.exitCode == 0
    }

    private func hasStagedChanges(repoURL: URL) async throws -> Bool {
        let result = try await runGitAllowingFailure(["diff", "--cached", "--quiet"], repoURL: repoURL, timeout: 10)
        return result.exitCode != 0
    }

    private func gitBlobContent(ref: String, file: String, repoURL: URL) async throws -> String {
        let result = try await runGitAllowingFailure(["show", "\(ref):\(file)"], repoURL: repoURL, timeout: 30)
        if result.exitCode == 0 {
            return result.output
        }
        return "[No version of \(file) exists at \(ref). The file may have been added, deleted, or renamed in this side of the merge.]"
    }

    private func hermesConflictReviewPrompt(file: String, localContent: String, officialContent: String) -> String {
        """
        Merge those two files in git conflict. They belong to the hermes agent source code. Review the merged file for syntax correctness. Run relevant tests on the hermes agent.

        File path to write with the final merged result: \(file)

        Use the current working tree at this repository. Overwrite the conflicted file at the path above with the final merged version. Preserve local branch changes unless official main intentionally supersedes them. Preserve official main changes unless they are incompatible with the local branch. Remove all git conflict markers. After writing the file, review syntax correctness and run relevant Hermes Agent tests for this file. In your final response, summarize the merge decisions and tests run.

        Version from the current local branch:
        ```
        \(localContent)
        ```

        Version from the pulled official main branch:
        ```
        \(officialContent)
        ```
        """
    }

    private func runHermesAgent(prompt: String, repoURL: URL, timeout: TimeInterval) async throws -> String {
        try await runProcess(executable: "/usr/bin/env", arguments: ["hermes", "chat", "-q", prompt], workingDirectory: repoURL, timeout: timeout)
    }

    private func ensureFileHasNoConflictMarkers(_ file: String, repoURL: URL) throws {
        let fileURL = repoURL.appendingPathComponent(file)
        let content = (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
        let hasMarkers = content.contains("<<<<<<< ") || content.contains("=======\n") || content.contains(">>>>>>> ")
        guard hasMarkers == false else {
            throw CompanionGitRegistryError.gitCommandFailed("Hermes Agent left git conflict markers in \(file).")
        }
    }

    private func clearPendingUpdateConfig(repoURL: URL) async throws {
        try await unsetGitConfig(pendingBranchConfigKey, repoURL: repoURL)
        try await unsetGitConfig(pendingCommitConfigKey, repoURL: repoURL)
        try await unsetGitConfig(pendingConflictsConfigKey, repoURL: repoURL)
    }

    private func commitWorkingTreeChangesIfNeeded(repoURL: URL, branch: String) async throws -> String {
        let status = try await runGit(["status", "--porcelain"], repoURL: repoURL, timeout: 10).trimmedOutput
        guard status.isEmpty == false else {
            return ""
        }
        guard branch.isEmpty == false else {
            throw CompanionGitRegistryError.gitCommandFailed("Hermes Agent has local changes, but the checkout is detached. Check out a local branch before updating so changes can be committed safely.")
        }

        _ = try await runGit(["add", "-A"], repoURL: repoURL, timeout: 30)
        let commitOutput = try await runGit(["commit", "-m", "chore: save local changes before Hermes update"], repoURL: repoURL, timeout: 60).trimmedOutput
        let commitHash = try await runGit(["rev-parse", "--short", "HEAD"], repoURL: repoURL, timeout: 10).trimmedOutput
        if commitOutput.isEmpty {
            return "Committed local Hermes Agent changes to \(branch) as \(commitHash) before fetching official main."
        }
        return "Committed local Hermes Agent changes to \(branch) as \(commitHash) before fetching official main.\n\(commitOutput)"
    }

    private func ensureNoMergeInProgress(repoURL: URL) throws {
        guard isMergeInProgress(repoURL: repoURL) == false else {
            throw CompanionGitRegistryError.gitCommandFailed("A merge is already in progress. Resolve it on the Mac, then try again.")
        }
    }

    private func isMergeInProgress(repoURL: URL) -> Bool {
        let mergeHead = repoURL.appendingPathComponent(".git/MERGE_HEAD").path
        return FileManager.default.fileExists(atPath: mergeHead)
    }

    private func ensureLocalMainBranchExists(repoURL: URL) async throws {
        let result = try await runGitAllowingFailure(["rev-parse", "--verify", localMainBranch], repoURL: repoURL, timeout: 10)
        guard result.exitCode == 0 else {
            throw CompanionGitRegistryError.gitCommandFailed("Local Hermes Agent branch 'main' was not found. Create or restore local main before updating.")
        }
    }

    private func pushRemoteTarget(repoURL: URL) async throws -> String {
        let originURL = (try? await runGit(["remote", "get-url", "origin"], repoURL: repoURL, timeout: 10).trimmedOutput) ?? ""
        let normalizedOrigin = originURL.lowercased()
        if normalizedOrigin.contains("lad75020/hermes-agent") || normalizedOrigin.contains("lad75020:hermes-agent") {
            return "origin"
        }
        return forkRepositoryURL
    }

    private func conflictFiles(from mergeTreeOutput: String) -> [String] {
        mergeTreeOutput
            .split(separator: "\n")
            .compactMap { line -> String? in
                let value = String(line).trimmingCharacters(in: .whitespacesAndNewlines)
                if value.hasPrefix("Auto-merging ") {
                    return String(value.dropFirst("Auto-merging ".count))
                }
                if value.hasPrefix("CONFLICT") == false, value.contains("\t") {
                    return value.split(separator: "\t").last.map(String.init)
                }
                return nil
            }
            .reduce(into: []) { files, file in
                if files.contains(file) == false { files.append(file) }
            }
    }

    private func setGitConfig(_ key: String, value: String, repoURL: URL) async throws {
        _ = try await runGit(["config", "--local", key, value], repoURL: repoURL, timeout: 10)
    }

    private func unsetGitConfig(_ key: String, repoURL: URL) async throws {
        _ = try? await runGit(["config", "--local", "--unset", key], repoURL: repoURL, timeout: 10)
    }

    private func gitConfigValue(_ key: String, repoURL: URL) async throws -> String {
        (try? await runGit(["config", "--local", "--get", key], repoURL: repoURL, timeout: 10).trimmedOutput) ?? ""
    }

    private func resolvedWorkspaceURL(from workspacePath: String) throws -> URL {
        guard let workspaceURL = CompanionWorkspaceSecurity.resolvedHermesWorkspaceURL(from: workspacePath) else {
            throw CompanionGitRegistryError.invalidWorkspace(workspacePath)
        }
        return workspaceURL
    }

    private func runGit(_ arguments: [String], repoURL: URL, timeout: TimeInterval) async throws -> String {
        let result = try await runGitAllowingFailure(arguments, repoURL: repoURL, timeout: timeout)
        guard result.exitCode == 0 else {
            throw CompanionGitRegistryError.gitCommandFailed(result.output)
        }
        return result.output
    }

    private func runGitAllowingFailure(_ arguments: [String], repoURL: URL, timeout: TimeInterval) async throws -> (output: String, exitCode: Int32) {
        let result = try await runProcessAllowingFailure(executable: "/usr/bin/env", arguments: ["git", "-C", repoURL.path] + arguments, workingDirectory: repoURL, timeout: timeout)
        return (result.output, result.exitCode)
    }

    private func runProcess(executable: String, arguments: [String], workingDirectory: URL, timeout: TimeInterval) async throws -> String {
        let result = try await runProcessAllowingFailure(executable: executable, arguments: arguments, workingDirectory: workingDirectory, timeout: timeout)
        guard result.exitCode == 0 else {
            throw CompanionGitRegistryError.gitCommandFailed(result.output)
        }
        return result.output
    }

    private func runProcessAllowingFailure(executable: String, arguments: [String], workingDirectory: URL, timeout: TimeInterval) async throws -> (output: String, exitCode: Int32) {
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

        do {
            let result = try await CompanionSubprocess.run(
                executableURL: URL(fileURLWithPath: executable),
                arguments: arguments,
                environment: environment,
                currentDirectoryURL: workingDirectory,
                timeout: timeout,
                maxOutputBytes: CompanionSubprocess.defaultMaxOutputBytes
            )
            let out = String(data: result.stdout, encoding: .utf8) ?? ""
            let err = String(data: result.stderr, encoding: .utf8) ?? ""
            let output = err.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? out : [out, err].joined(separator: "\n")
            return (output.trimmedOutput, result.status)
        } catch CompanionSubprocess.Failure.timedOut {
            throw CompanionGitRegistryError.gitCommandFailed("\(executable) \(arguments.joined(separator: " ")) timed out.")
        } catch let error as CompanionGitRegistryError {
            throw error
        } catch {
            throw CompanionGitRegistryError.gitCommandFailed(error.localizedDescription)
        }
    }
}

private extension String {
    var trimmedOutput: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
