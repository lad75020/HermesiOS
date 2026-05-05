//
//  CompanionProfileRegistry.swift
//  HermesHostCompanion
//

import Darwin
import Foundation

enum CompanionProfileRegistryError: LocalizedError {
    case invalidWorkspace(String)
    case invalidProfileName
    case cannotDeleteDefault
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidWorkspace(let path):
            return "The Hermes workspace path '\(path)' is invalid."
        case .invalidProfileName:
            return "Enter a valid profile name."
        case .cannotDeleteDefault:
            return "Cannot delete the default profile."
        case .commandFailed(let message):
            return message
        }
    }
}

final class CompanionProfileRegistry {
    func list(workspacePath: String) throws -> ListProfilesResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let activeName = activeProfileName(workspaceURL: workspaceURL)
        let defaultProfile = profileInfo(name: "default", profileURL: workspaceURL, workspaceURL: workspaceURL, isDefault: true, isActive: activeName == "default")
        var profiles = [defaultProfile]

        let profilesURL = workspaceURL.appendingPathComponent("profiles", isDirectory: true)
        if let names = try? FileManager.default.contentsOfDirectory(atPath: profilesURL.path) {
            let namedProfiles = names
                .filter { !$0.hasPrefix(".") }
                .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                .compactMap { name -> ProfileInfo? in
                    let profileURL = profilesURL.appendingPathComponent(name, isDirectory: true)
                    var isDirectory: ObjCBool = false
                    guard FileManager.default.fileExists(atPath: profileURL.path, isDirectory: &isDirectory), isDirectory.boolValue else { return nil }
                    return profileInfo(name: name, profileURL: profileURL, workspaceURL: workspaceURL, isDefault: false, isActive: activeName == name)
                }
            profiles.append(contentsOf: namedProfiles)
        }

        return ListProfilesResult(
            workspacePath: workspacePath,
            resolvedWorkspacePath: workspaceURL.path,
            profilesDirectoryPath: profilesURL.path,
            activeProfileName: activeName,
            profiles: profiles
        )
    }

    func create(workspacePath: String, name: String, clone: Bool) throws -> ProfileOperationResult {
        let trimmedName = try normalizedProfileName(name)
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let result = runProfileCommand(args: ["create", trimmedName] + (clone ? ["--clone"] : []), workspaceURL: workspaceURL)
        return operationResult(workspacePath: workspacePath, workspaceURL: workspaceURL, success: result.success, output: result.output, error: result.error)
    }

    func remove(workspacePath: String, name: String) throws -> ProfileOperationResult {
        let trimmedName = try normalizedProfileName(name)
        guard trimmedName != "default" else { throw CompanionProfileRegistryError.cannotDeleteDefault }
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let result = runProfileCommand(args: ["delete", trimmedName, "--yes"], workspaceURL: workspaceURL)
        return operationResult(workspacePath: workspacePath, workspaceURL: workspaceURL, success: result.success, output: result.output, error: result.error)
    }

    func activate(workspacePath: String, name: String) throws -> ProfileOperationResult {
        let trimmedName = try normalizedProfileName(name)
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let result = runProfileCommand(args: ["use", trimmedName], workspaceURL: workspaceURL)
        return operationResult(workspacePath: workspacePath, workspaceURL: workspaceURL, success: result.success, output: result.output, error: result.error)
    }

    private func operationResult(workspacePath: String, workspaceURL: URL, success: Bool, output: String, error: String?) -> ProfileOperationResult {
        let listed = (try? list(workspacePath: workspaceURL.path))
        return ProfileOperationResult(
            workspacePath: workspacePath,
            resolvedWorkspacePath: workspaceURL.path,
            success: success,
            output: output,
            error: error,
            activeProfileName: listed?.activeProfileName ?? activeProfileName(workspaceURL: workspaceURL),
            profiles: listed?.profiles ?? []
        )
    }

    private func profileInfo(name: String, profileURL: URL, workspaceURL: URL, isDefault: Bool, isActive: Bool) -> ProfileInfo {
        let config = readProfileConfig(profileURL: profileURL)
        return ProfileInfo(
            id: name,
            name: name,
            path: profileURL.path,
            isDefault: isDefault,
            isActive: isActive,
            model: config.model,
            provider: config.provider,
            hasEnv: FileManager.default.fileExists(atPath: profileURL.appendingPathComponent(".env").path),
            hasSoul: FileManager.default.fileExists(atPath: profileURL.appendingPathComponent("SOUL.md").path),
            skillCount: countSkills(profileURL: profileURL),
            gatewayRunning: isGatewayRunning(profileURL: profileURL)
        )
    }

    private func readProfileConfig(profileURL: URL) -> (model: String, provider: String) {
        let configURL = profileURL.appendingPathComponent("config.yaml")
        guard let content = try? String(contentsOf: configURL, encoding: .utf8) else { return ("", "") }
        return (firstYAMLScalar(named: "default", in: content) ?? "", firstYAMLScalar(named: "provider", in: content) ?? "auto")
    }

    private func firstYAMLScalar(named key: String, in content: String) -> String? {
        let pattern = #"(?m)^\s*\#(key):\s*["']?([^"'\n#]+)["']?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        guard let match = regex.firstMatch(in: content, range: range), match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: content) else { return nil }
        return String(content[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func countSkills(profileURL: URL) -> Int {
        let skillsURL = profileURL.appendingPathComponent("skills", isDirectory: true)
        guard let categories = try? FileManager.default.contentsOfDirectory(at: skillsURL, includingPropertiesForKeys: [.isDirectoryKey]) else { return 0 }
        var count = 0
        for categoryURL in categories {
            guard (try? categoryURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            guard let candidates = try? FileManager.default.contentsOfDirectory(at: categoryURL, includingPropertiesForKeys: [.isDirectoryKey]) else { continue }
            for candidateURL in candidates where FileManager.default.fileExists(atPath: candidateURL.appendingPathComponent("SKILL.md").path) {
                count += 1
            }
        }
        return count
    }

    private func isGatewayRunning(profileURL: URL) -> Bool {
        let pidURL = profileURL.appendingPathComponent("gateway.pid")
        guard let raw = try? String(contentsOf: pidURL, encoding: .utf8), let pid = Int32(raw.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
        return kill(pid, 0) == 0
    }

    private func activeProfileName(workspaceURL: URL) -> String {
        let activeURL = workspaceURL.appendingPathComponent("active_profile")
        guard let raw = try? String(contentsOf: activeURL, encoding: .utf8) else { return "default" }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "default" : trimmed
    }

    private func normalizedProfileName(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard !trimmed.isEmpty, trimmed.rangeOfCharacter(from: allowed.inverted) == nil else {
            throw CompanionProfileRegistryError.invalidProfileName
        }
        return trimmed
    }

    private func resolvedWorkspaceURL(from workspacePath: String) throws -> URL {
        let trimmedPath = workspacePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let expandedPath = (trimmedPath.isEmpty ? "~/.hermes" : trimmedPath as NSString).expandingTildeInPath
        let workspaceURL = URL(fileURLWithPath: expandedPath, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: workspaceURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw CompanionProfileRegistryError.invalidWorkspace(workspacePath)
        }
        return workspaceURL
    }

    private func runProfileCommand(args: [String], workspaceURL: URL) -> (success: Bool, output: String, error: String?) {
        let repoURL = workspaceURL.appendingPathComponent("hermes-agent")
        let scriptURL = repoURL.appendingPathComponent("hermes")
        let pythonURL = repoURL.appendingPathComponent("venv/bin/python")
        guard FileManager.default.fileExists(atPath: scriptURL.path) else {
            return (false, "", "Hermes CLI script not found at \(scriptURL.path)")
        }

        let process = Process()
        if FileManager.default.fileExists(atPath: pythonURL.path) {
            process.executableURL = pythonURL
            process.arguments = [scriptURL.path, "profile"] + args
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["python3", scriptURL.path, "profile"] + args
        }
        process.currentDirectoryURL = repoURL
        var env = ProcessInfo.processInfo.environment
        env["HERMES_HOME"] = workspaceURL.path
        env["HOME"] = NSHomeDirectory()
        env["PATH"] = enhancedPath(workspaceURL: workspaceURL, existing: env["PATH"] ?? "")
        process.environment = env

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
            process.waitUntilExit()
            let out = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let combined = [out, err].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: "\n")
            return (process.terminationStatus == 0, combined, process.terminationStatus == 0 ? nil : (combined.isEmpty ? "hermes profile command failed with exit code \(process.terminationStatus)." : combined))
        } catch {
            return (false, "", error.localizedDescription)
        }
    }

    private func enhancedPath(workspaceURL: URL, existing: String) -> String {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return [
            home.appendingPathComponent(".local/bin").path,
            home.appendingPathComponent(".cargo/bin").path,
            workspaceURL.appendingPathComponent("hermes-agent/venv/bin").path,
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            existing
        ].joined(separator: ":")
    }
}
