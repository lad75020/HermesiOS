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
    private let officialMainRef = "refs/remotes/hermes-official/main"
    private let pendingBranchConfigKey = "hermesios.pendingUpdateBranch"
    private let pendingCommitConfigKey = "hermesios.pendingUpdateCommit"
    private let pendingConflictsConfigKey = "hermesios.pendingUpdateConflicts"
    private let lastUpdateOutputConfigKey = "hermesios.lastUpdateOutput"

    func hermesInstallationStatus(workspacePath: String) throws -> HermesInstallationStatusResult {
        let repoURL = try hermesRepoURL(workspacePath: workspacePath)
        _ = try runGit(["fetch", "--quiet", officialRepositoryURL, "main:\(officialMainRef)"], repoURL: repoURL, timeout: 45)
        return try status(workspacePath: workspacePath, repoURL: repoURL)
    }

    func updateHermesInstallation(workspacePath: String) throws -> HermesInstallationOperationResult {
        let repoURL = try hermesRepoURL(workspacePath: workspacePath)
        try ensureNoMergeInProgress(repoURL: repoURL)

        let branch = try runGit(["branch", "--show-current"], repoURL: repoURL, timeout: 10).trimmedOutput
        let preUpdateCommitOutput = try commitWorkingTreeChangesIfNeeded(repoURL: repoURL, branch: branch)
        try ensureCleanWorkingTree(repoURL: repoURL)

        let localRef = branch.isEmpty ? "HEAD" : branch
        _ = try runGit(["fetch", officialRepositoryURL, "main:\(officialMainRef)"], repoURL: repoURL, timeout: 60).trimmedOutput
        let officialCommit = try runGit(["rev-parse", "--short", officialMainRef], repoURL: repoURL, timeout: 10).trimmedOutput
        let mergeProbe = try runGitAllowingFailure(["merge-tree", "--write-tree", officialMainRef, localRef], repoURL: repoURL, timeout: 30)
        let conflictFiles = conflictFiles(from: mergeProbe.output)

        try setGitConfig(pendingBranchConfigKey, value: branch.isEmpty ? "HEAD" : branch, repoURL: repoURL)
        try setGitConfig(pendingCommitConfigKey, value: officialCommit, repoURL: repoURL)
        try setGitConfig(pendingConflictsConfigKey, value: conflictFiles.joined(separator: "\n"), repoURL: repoURL)

        let reviewMessage: String
        if mergeProbe.exitCode == 0 {
            reviewMessage = "Fetched official main \(officialCommit). No merge conflicts were detected; review the update, then tap Merge Reviewed Update."
        } else {
            reviewMessage = "Fetched official main \(officialCommit). Review and resolve conflicts before tapping Merge Reviewed Update.\n\(mergeProbe.output)"
        }
        let operationMessage = [preUpdateCommitOutput, reviewMessage]
            .filter { $0.isEmpty == false }
            .joined(separator: "\n\n")
        try setGitConfig(lastUpdateOutputConfigKey, value: operationMessage, repoURL: repoURL)


        let currentStatus = try status(workspacePath: workspacePath, repoURL: repoURL, skipFetch: true)
        return HermesInstallationOperationResult(status: currentStatus, output: operationMessage)
    }

    func mergeReviewedHermesInstallationUpdate(workspacePath: String) throws -> HermesInstallationOperationResult {
        let repoURL = try hermesRepoURL(workspacePath: workspacePath)
        try ensureNoMergeInProgress(repoURL: repoURL)
        try ensureCleanWorkingTree(repoURL: repoURL)

        let pendingBranch = try gitConfigValue(pendingBranchConfigKey, repoURL: repoURL)
        guard pendingBranch.isEmpty == false else {
            throw CompanionGitRegistryError.gitCommandFailed("No reviewed Hermes update is pending. Tap Hermes Update first.")
        }

        let branch = try runGit(["branch", "--show-current"], repoURL: repoURL, timeout: 10).trimmedOutput
        guard branch == pendingBranch || pendingBranch == "HEAD" else {
            throw CompanionGitRegistryError.gitCommandFailed("The pending update was prepared for \(pendingBranch), but the checkout is currently on \(branch.isEmpty ? "detached HEAD" : branch).")
        }

        let pendingCommit = try gitConfigValue(pendingCommitConfigKey, repoURL: repoURL)
        let officialRef = pendingCommit.isEmpty ? officialMainRef : pendingCommit
        let mergeOutput = try runGit(["merge", "--no-ff", officialRef, "-m", "Merge official Hermes Agent main into \(branch.isEmpty ? "local checkout" : branch)"], repoURL: repoURL, timeout: 120).trimmedOutput
        try unsetGitConfig(pendingBranchConfigKey, repoURL: repoURL)
        try unsetGitConfig(pendingCommitConfigKey, repoURL: repoURL)
        try unsetGitConfig(pendingConflictsConfigKey, repoURL: repoURL)
        try setGitConfig(lastUpdateOutputConfigKey, value: mergeOutput.isEmpty ? "Merged official main into local branch." : mergeOutput, repoURL: repoURL)

        let currentStatus = try status(workspacePath: workspacePath, repoURL: repoURL, skipFetch: true)
        return HermesInstallationOperationResult(status: currentStatus, output: mergeOutput)
    }

    private func status(workspacePath: String, repoURL: URL, skipFetch: Bool = false) throws -> HermesInstallationStatusResult {
        if skipFetch == false {
            _ = try runGit(["fetch", "--quiet", officialRepositoryURL, "main:\(officialMainRef)"], repoURL: repoURL, timeout: 45)
        }
        let branch = try runGit(["branch", "--show-current"], repoURL: repoURL, timeout: 10).trimmedOutput
        let currentCommit = try runGit(["rev-parse", "--short", "HEAD"], repoURL: repoURL, timeout: 10).trimmedOutput
        let upstreamCommit = try runGit(["rev-parse", "--short", officialMainRef], repoURL: repoURL, timeout: 10).trimmedOutput
        let behindOutput = try runGit(["rev-list", "--count", "HEAD..\(officialMainRef)"], repoURL: repoURL, timeout: 10).trimmedOutput
        let remoteURL = (try? runGit(["remote", "get-url", "origin"], repoURL: repoURL, timeout: 10).trimmedOutput) ?? ""
        let pendingBranch = try gitConfigValue(pendingBranchConfigKey, repoURL: repoURL)
        let pendingCommit = try gitConfigValue(pendingCommitConfigKey, repoURL: repoURL)
        let conflictFiles = try gitConfigValue(pendingConflictsConfigKey, repoURL: repoURL)
            .split(separator: "\n")
            .map(String.init)
        let lastUpdateOutput = try gitConfigValue(lastUpdateOutputConfigKey, repoURL: repoURL)

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

    private func ensureCleanWorkingTree(repoURL: URL) throws {
        let status = try runGit(["status", "--porcelain"], repoURL: repoURL, timeout: 10).trimmedOutput
        guard status.isEmpty else {
            throw CompanionGitRegistryError.gitCommandFailed("Commit, stash, or discard local working-tree changes before updating Hermes Agent.")
        }
    }

    private func commitWorkingTreeChangesIfNeeded(repoURL: URL, branch: String) throws -> String {
        let status = try runGit(["status", "--porcelain"], repoURL: repoURL, timeout: 10).trimmedOutput
        guard status.isEmpty == false else {
            return ""
        }
        guard branch.isEmpty == false else {
            throw CompanionGitRegistryError.gitCommandFailed("Hermes Agent has local changes, but the checkout is detached. Check out a local branch before updating so changes can be committed safely.")
        }

        _ = try runGit(["add", "-A"], repoURL: repoURL, timeout: 30)
        let commitOutput = try runGit(["commit", "-m", "chore: save local changes before Hermes update"], repoURL: repoURL, timeout: 60).trimmedOutput
        let commitHash = try runGit(["rev-parse", "--short", "HEAD"], repoURL: repoURL, timeout: 10).trimmedOutput
        if commitOutput.isEmpty {
            return "Committed local Hermes Agent changes to \(branch) as \(commitHash) before fetching official main."
        }
        return "Committed local Hermes Agent changes to \(branch) as \(commitHash) before fetching official main.\n\(commitOutput)"
    }

    private func ensureNoMergeInProgress(repoURL: URL) throws {
        let mergeHead = repoURL.appendingPathComponent(".git/MERGE_HEAD").path
        guard FileManager.default.fileExists(atPath: mergeHead) == false else {
            throw CompanionGitRegistryError.gitCommandFailed("A merge is already in progress. Resolve it on the Mac, then try again.")
        }
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

    private func setGitConfig(_ key: String, value: String, repoURL: URL) throws {
        _ = try runGit(["config", "--local", key, value], repoURL: repoURL, timeout: 10)
    }

    private func unsetGitConfig(_ key: String, repoURL: URL) throws {
        _ = try? runGit(["config", "--local", "--unset", key], repoURL: repoURL, timeout: 10)
    }

    private func gitConfigValue(_ key: String, repoURL: URL) throws -> String {
        (try? runGit(["config", "--local", "--get", key], repoURL: repoURL, timeout: 10).trimmedOutput) ?? ""
    }

    private func resolvedWorkspaceURL(from workspacePath: String) throws -> URL {
        let expandedPath = NSString(string: workspacePath.trimmingCharacters(in: .whitespacesAndNewlines)).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw CompanionGitRegistryError.invalidWorkspace(expandedPath)
        }
        return URL(fileURLWithPath: expandedPath, isDirectory: true)
    }

    private func runGit(_ arguments: [String], repoURL: URL, timeout: TimeInterval) throws -> String {
        let result = try runGitAllowingFailure(arguments, repoURL: repoURL, timeout: timeout)
        guard result.exitCode == 0 else {
            throw CompanionGitRegistryError.gitCommandFailed(result.output)
        }
        return result.output
    }

    private func runGitAllowingFailure(_ arguments: [String], repoURL: URL, timeout: TimeInterval) throws -> (output: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-C", repoURL.path] + arguments
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = environment

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
            if process.isRunning {
                process.terminate()
                throw CompanionGitRegistryError.gitCommandFailed("git \(arguments.joined(separator: " ")) timed out.")
            }
            let out = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let output = err.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? out : [out, err].joined(separator: "\n")
            return (output.trimmedOutput, process.terminationStatus)
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
