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
    func hermesInstallationStatus(workspacePath: String) throws -> HermesInstallationStatusResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let repoURL = workspaceURL.appendingPathComponent("hermes-agent", isDirectory: true)
        guard FileManager.default.fileExists(atPath: repoURL.appendingPathComponent(".git").path) else {
            throw CompanionGitRegistryError.missingHermesRepository(repoURL.path)
        }

        _ = try runGit(["fetch", "--quiet", "origin", "main"], repoURL: repoURL, timeout: 45)
        let branch = try runGit(["branch", "--show-current"], repoURL: repoURL, timeout: 10).trimmedOutput
        let currentCommit = try runGit(["rev-parse", "--short", "HEAD"], repoURL: repoURL, timeout: 10).trimmedOutput
        let upstreamCommit = try runGit(["rev-parse", "--short", "origin/main"], repoURL: repoURL, timeout: 10).trimmedOutput
        let behindOutput = try runGit(["rev-list", "--count", "HEAD..origin/main"], repoURL: repoURL, timeout: 10).trimmedOutput
        let remoteURL = (try? runGit(["remote", "get-url", "origin"], repoURL: repoURL, timeout: 10).trimmedOutput) ?? ""

        return HermesInstallationStatusResult(
            workspacePath: workspacePath,
            resolvedWorkspacePath: workspaceURL.path,
            repositoryPath: repoURL.path,
            remoteURL: remoteURL,
            branch: branch,
            currentCommit: currentCommit,
            upstreamCommit: upstreamCommit,
            behindBy: Int(behindOutput) ?? 0,
            checkedAt: Date()
        )
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
            guard process.terminationStatus == 0 else {
                let message = err.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? out : err
                throw CompanionGitRegistryError.gitCommandFailed(message.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            return out
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
