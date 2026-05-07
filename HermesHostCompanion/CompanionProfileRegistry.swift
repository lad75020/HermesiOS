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
    case cannotEditDefaultName
    case profileAlreadyExists(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidWorkspace(let path):
            return "The Hermes workspace path '\(path)' is invalid."
        case .invalidProfileName:
            return "Enter a valid profile name."
        case .cannotDeleteDefault:
            return "Cannot delete the default profile."
        case .cannotEditDefaultName:
            return "Cannot rename the default profile."
        case .profileAlreadyExists(let name):
            return "A profile named '\(name)' already exists."
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

    func create(workspacePath: String, name: String, provider: String, model: String, baseUrl: String, createEnv: Bool, createSoul: Bool, cloneSkills: Bool) throws -> ProfileOperationResult {
        let trimmedName = try normalizedProfileName(name)
        guard trimmedName != "default" else { throw CompanionProfileRegistryError.profileAlreadyExists(trimmedName) }
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let profileURL = profileURL(for: trimmedName, workspaceURL: workspaceURL)
        var isDirectory: ObjCBool = false
        guard !FileManager.default.fileExists(atPath: profileURL.path, isDirectory: &isDirectory) else {
            throw CompanionProfileRegistryError.profileAlreadyExists(trimmedName)
        }
        try FileManager.default.createDirectory(at: profileURL, withIntermediateDirectories: true)
        try seedProfileFiles(profileURL: profileURL, workspaceURL: workspaceURL, provider: provider, model: model, baseUrl: baseUrl, createEnv: createEnv, createSoul: createSoul)
        if cloneSkills { try cloneDefaultSkills(profileURL: profileURL, workspaceURL: workspaceURL) }
        return operationResult(workspacePath: workspacePath, workspaceURL: workspaceURL, success: true, output: "Created profile \(trimmedName) at \(profileURL.path)", error: nil)
    }

    func edit(workspacePath: String, originalName: String, name: String, provider: String, model: String, baseUrl: String, createEnv: Bool, createSoul: Bool) throws -> ProfileOperationResult {
        let oldName = try normalizedProfileName(originalName)
        let newName = try normalizedProfileName(name)
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        var currentProfileURL = profileURL(for: oldName, workspaceURL: workspaceURL)
        if oldName == "default" && newName != "default" { throw CompanionProfileRegistryError.cannotEditDefaultName }
        if oldName != newName {
            let destinationURL = profileURL(for: newName, workspaceURL: workspaceURL)
            guard !FileManager.default.fileExists(atPath: destinationURL.path) else { throw CompanionProfileRegistryError.profileAlreadyExists(newName) }
            try FileManager.default.moveItem(at: currentProfileURL, to: destinationURL)
            currentProfileURL = destinationURL
            if activeProfileName(workspaceURL: workspaceURL) == oldName {
                try newName.write(to: workspaceURL.appendingPathComponent("active_profile"), atomically: true, encoding: .utf8)
            }
        }
        try seedProfileFiles(profileURL: currentProfileURL, workspaceURL: workspaceURL, provider: provider, model: model, baseUrl: baseUrl, createEnv: createEnv, createSoul: createSoul)
        return operationResult(workspacePath: workspacePath, workspaceURL: workspaceURL, success: true, output: "Saved profile \(newName) at \(currentProfileURL.path)", error: nil)
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
        let configURL = profileURL.appendingPathComponent("config.yaml")
        let config = readProfileConfig(profileURL: profileURL)
        return ProfileInfo(
            id: name,
            name: name,
            path: profileURL.path,
            isDefault: isDefault,
            isActive: isActive,
            model: config.model,
            provider: config.provider,
            baseUrl: config.baseUrl,
            hasConfig: FileManager.default.fileExists(atPath: configURL.path),
            hasEnv: FileManager.default.fileExists(atPath: profileURL.appendingPathComponent(".env").path),
            hasSoul: FileManager.default.fileExists(atPath: profileURL.appendingPathComponent("SOUL.md").path),
            skillCount: countSkills(profileURL: profileURL),
            gatewayRunning: isGatewayRunning(profileURL: profileURL)
        )
    }

    private func readProfileConfig(profileURL: URL) -> (model: String, provider: String, baseUrl: String) {
        let configURL = profileURL.appendingPathComponent("config.yaml")
        guard let content = try? String(contentsOf: configURL, encoding: .utf8) else { return ("", "", "") }
        return (
            readYAMLScalar(content: content, section: "model", key: "default") ?? firstTopLevelYAMLScalar(named: "default", in: content) ?? "",
            readYAMLScalar(content: content, section: "model", key: "provider") ?? firstTopLevelYAMLScalar(named: "provider", in: content) ?? "auto",
            readYAMLScalar(content: content, section: "model", key: "base_url") ?? firstTopLevelYAMLScalar(named: "base_url", in: content) ?? ""
        )
    }

    private func firstTopLevelYAMLScalar(named key: String, in content: String) -> String? {
        firstMatch(in: content, pattern: #"^\#(key):\s*["']?([^"'\n#]+)["']?"#)
    }

    private func readYAMLScalar(content: String, section: String, key: String) -> String? {
        let lines = content.components(separatedBy: "\n")
        guard let sectionIndex = lines.firstIndex(where: { $0.range(of: #"^\#(section):\s*(#.*)?$"#, options: .regularExpression) != nil }) else { return nil }
        let sectionIndent = indentation(of: lines[sectionIndex])
        var index = sectionIndex + 1
        while index < lines.count {
            let line = lines[index]
            if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && indentation(of: line) <= sectionIndent { break }
            if indentation(of: line) == sectionIndent + 2, let value = scalarValue(from: line, key: key) { return value }
            index += 1
        }
        return nil
    }

    private func scalarValue(from line: String, key: String) -> String? {
        firstMatch(in: line, pattern: #"^\s*\#(key):\s*["']?([^"'\n#]+)["']?"#)
    }

    private func firstMatch(in content: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        guard let match = regex.firstMatch(in: content, range: range), match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: content) else { return nil }
        return String(content[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func indentation(of line: String) -> Int {
        line.prefix { $0 == " " }.count
    }

    private func profileURL(for name: String, workspaceURL: URL) -> URL {
        name == "default" ? workspaceURL : workspaceURL.appendingPathComponent("profiles", isDirectory: true).appendingPathComponent(name, isDirectory: true)
    }

    private func seedProfileFiles(profileURL: URL, workspaceURL: URL, provider: String, model: String, baseUrl: String, createEnv: Bool, createSoul: Bool) throws {
        try FileManager.default.createDirectory(at: profileURL, withIntermediateDirectories: true)
        let defaultConfigURL = workspaceURL.appendingPathComponent("config.yaml")
        let configURL = profileURL.appendingPathComponent("config.yaml")
        if !FileManager.default.fileExists(atPath: configURL.path), FileManager.default.fileExists(atPath: defaultConfigURL.path) {
            try FileManager.default.copyItem(at: defaultConfigURL, to: configURL)
        }
        try writeModelFields(configURL: configURL, provider: provider, model: model, baseUrl: baseUrl)
        try syncOptionalFile(fileName: ".env", enabled: createEnv, profileURL: profileURL, workspaceURL: workspaceURL)
        try syncOptionalFile(fileName: "SOUL.md", enabled: createSoul, profileURL: profileURL, workspaceURL: workspaceURL)
    }

    private func syncOptionalFile(fileName: String, enabled: Bool, profileURL: URL, workspaceURL: URL) throws {
        let destinationURL = profileURL.appendingPathComponent(fileName)
        if enabled {
            if !FileManager.default.fileExists(atPath: destinationURL.path) {
                let sourceURL = workspaceURL.appendingPathComponent(fileName)
                if FileManager.default.fileExists(atPath: sourceURL.path) {
                    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                } else {
                    try "".write(to: destinationURL, atomically: true, encoding: .utf8)
                }
            }
        } else if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
    }

    private func cloneDefaultSkills(profileURL: URL, workspaceURL: URL) throws {
        let sourceURL = workspaceURL.appendingPathComponent("skills", isDirectory: true)
        let destinationURL = profileURL.appendingPathComponent("skills", isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory), isDirectory.boolValue else { return }
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }

    private func writeModelFields(configURL: URL, provider: String, model: String, baseUrl: String) throws {
        var content = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        content = setYAMLScalar(content: content, section: "model", key: "provider", value: provider)
        content = setYAMLScalar(content: content, section: "model", key: "default", value: model)
        content = setYAMLScalar(content: content, section: "model", key: "base_url", value: baseUrl)
        try content.write(to: configURL, atomically: true, encoding: .utf8)
    }

    private func setYAMLScalar(content: String, section: String, key: String, value: String) -> String {
        var lines = content.components(separatedBy: "\n")
        if lines == [""] { lines = [] }
        let sectionLine = "\(section):"
        let keyLine = "  \(key): \(quotedYAML(value))"
        guard let sectionIndex = lines.firstIndex(where: { $0.range(of: #"^\#(section):\s*(#.*)?$"#, options: .regularExpression) != nil }) else {
            lines.append(sectionLine)
            lines.append(keyLine)
            return lines.joined(separator: "\n")
        }
        let sectionIndent = indentation(of: lines[sectionIndex])
        var insertIndex = sectionIndex + 1
        var index = sectionIndex + 1
        while index < lines.count {
            let line = lines[index]
            if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && indentation(of: line) <= sectionIndent { break }
            if indentation(of: line) == sectionIndent + 2, scalarValue(from: line, key: key) != nil {
                lines[index] = keyLine
                return lines.joined(separator: "\n")
            }
            insertIndex = index + 1
            index += 1
        }
        lines.insert(keyLine, at: insertIndex)
        return lines.joined(separator: "\n")
    }

    private func quotedYAML(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
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
