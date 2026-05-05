//
//  CompanionToolsetRegistry.swift
//  HermesHostCompanion
//
//  Created by Codex on 05/05/2026.
//

import Foundation

struct CompanionToolsetDefinition {
    let key: String
    let label: String
    let description: String
}

enum CompanionToolsetRegistryError: LocalizedError {
    case invalidWorkspacePath(String)
    case configNotFound(String)
    case unsupportedToolset(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidWorkspacePath(let path):
            "The Hermes workspace path '\(path)' is invalid."
        case .configNotFound(let path):
            "No Hermes config.yaml exists at '\(path)'."
        case .unsupportedToolset(let key):
            "The Hermes toolset '\(key)' is not supported by the companion."
        case .writeFailed(let path):
            "The companion could not write the Hermes config at '\(path)'."
        }
    }
}

final class CompanionToolsetRegistry {
    static let shared = CompanionToolsetRegistry()

    private static let definitions: [CompanionToolsetDefinition] = [
        .init(key: "web", label: "Web", description: "Allow web search and retrieval tools."),
        .init(key: "browser", label: "Browser", description: "Allow browser automation and interactive page control."),
        .init(key: "terminal", label: "Terminal", description: "Allow terminal command execution on the agent host."),
        .init(key: "file", label: "File", description: "Allow reading and writing files inside the workspace."),
        .init(key: "code_execution", label: "Code Execution", description: "Allow running code snippets and execution helpers."),
        .init(key: "vision", label: "Vision", description: "Allow image understanding and visual analysis."),
        .init(key: "image_gen", label: "Image Generation", description: "Allow image generation tools."),
        .init(key: "tts", label: "Text to Speech", description: "Allow speech synthesis output."),
        .init(key: "skills", label: "Skills", description: "Allow loading and applying Hermes skills."),
        .init(key: "memory", label: "Memory", description: "Allow persistent memory and workspace note tools."),
        .init(key: "session_search", label: "Session Search", description: "Allow searching prior sessions and stored traces."),
        .init(key: "clarify", label: "Clarify", description: "Allow clarification workflows before acting."),
        .init(key: "delegation", label: "Delegation", description: "Allow delegation or sub-agent workflows."),
        .init(key: "cronjob", label: "Cronjob", description: "Allow scheduled background jobs."),
        .init(key: "moa", label: "MOA", description: "Allow mixture-of-agents style orchestration."),
        .init(key: "todo", label: "Todo", description: "Allow task-list and todo management tools.")
    ]

    func listToolsets(workspacePath: String) throws -> ListToolsetsResult {
        let configURL = try resolvedConfigURL(from: workspacePath)
        let content = try String(contentsOf: configURL, encoding: .utf8)
        let enabledSet = Self.parseEnabledToolsets(configContent: content)
        let hasPlatformToolsets = content.contains("platform_toolsets")

        return ListToolsetsResult(
            workspacePath: workspacePath,
            resolvedWorkspacePath: configURL.deletingLastPathComponent().path,
            configPath: configURL.path,
            toolsets: Self.definitions.map { definition in
                CompanionToolsetInfo(
                    key: definition.key,
                    label: definition.label,
                    description: definition.description,
                    enabled: hasPlatformToolsets ? enabledSet.contains(definition.key) : true
                )
            }
        )
    }

    func setToolsetEnabled(
        workspacePath: String,
        key: String,
        enabled: Bool
    ) throws -> SetToolsetEnabledResult {
        guard Self.definitions.contains(where: { $0.key == key }) else {
            throw CompanionToolsetRegistryError.unsupportedToolset(key)
        }

        let configURL = try resolvedConfigURL(from: workspacePath)
        let content = try String(contentsOf: configURL, encoding: .utf8)
        var currentEnabled = Self.parseEnabledToolsets(configContent: content)
        let hasPlatformToolsets = content.contains("platform_toolsets")

        if hasPlatformToolsets == false {
            currentEnabled = Set(Self.definitions.map(\.key))
        }

        if enabled {
            currentEnabled.insert(key)
        } else {
            currentEnabled.remove(key)
        }

        let newContent = Self.rewritePlatformToolsetsCLI(in: content, enabledToolsets: currentEnabled.sorted())
        do {
            try newContent.write(to: configURL, atomically: true, encoding: .utf8)
        } catch {
            throw CompanionToolsetRegistryError.writeFailed(configURL.path)
        }

        let refreshed = try listToolsets(workspacePath: workspacePath)
        guard let updated = refreshed.toolsets.first(where: { $0.key == key }) else {
            throw CompanionToolsetRegistryError.unsupportedToolset(key)
        }

        return SetToolsetEnabledResult(
            workspacePath: workspacePath,
            resolvedWorkspacePath: refreshed.resolvedWorkspacePath,
            configPath: refreshed.configPath,
            toolset: updated
        )
    }

    private func resolvedConfigURL(from workspacePath: String) throws -> URL {
        let trimmedPath = workspacePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let expandedPath = NSString(string: trimmedPath.isEmpty ? "~/.hermes" : trimmedPath).expandingTildeInPath
        let workspaceURL = URL(fileURLWithPath: expandedPath, isDirectory: true)

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: workspaceURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw CompanionToolsetRegistryError.invalidWorkspacePath(expandedPath)
        }

        let configURL = workspaceURL.appendingPathComponent("config.yaml")
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            throw CompanionToolsetRegistryError.configNotFound(configURL.path)
        }

        return configURL
    }

    private static func parseEnabledToolsets(configContent: String) -> Set<String> {
        let lines = configContent.components(separatedBy: .newlines)
        var enabled = Set<String>()
        var inPlatformToolsets = false
        var inCLI = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .newlines)

            if trimmed.range(of: #"^\s*platform_toolsets\s*:"# , options: .regularExpression) != nil {
                inPlatformToolsets = true
                inCLI = false
                continue
            }

            if inPlatformToolsets, trimmed.range(of: #"^\s+cli\s*:"# , options: .regularExpression) != nil {
                inCLI = true
                continue
            }

            if inPlatformToolsets, trimmed.range(of: #"^\S"#, options: .regularExpression) != nil, trimmed.isEmpty == false {
                inPlatformToolsets = false
                inCLI = false
                continue
            }

            if inCLI, trimmed.range(of: #"^\s{4}\S"#, options: .regularExpression) != nil,
               trimmed.range(of: #"^\s{4,}-"#, options: .regularExpression) == nil {
                inCLI = false
                continue
            }

            if inCLI {
                if let range = trimmed.range(of: #"^\s*-\s+["']?([A-Za-z0-9_]+)["']?"#, options: .regularExpression) {
                    let item = String(trimmed[range]).replacingOccurrences(of: "-", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                    let normalized = item.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                    enabled.insert(normalized)
                }
            }
        }

        return enabled
    }

    private static func rewritePlatformToolsetsCLI(in content: String, enabledToolsets: [String]) -> String {
        let newSection = [
            "platform_toolsets:",
            "  cli:"
        ] + enabledToolsets.map { "      - \($0)" }

        let lines = content.components(separatedBy: .newlines)
        var result: [String] = []
        var inPlatformToolsets = false
        var skippingExistingSection = false
        var inserted = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .newlines)

            if trimmed.range(of: #"^\s*platform_toolsets\s*:"# , options: .regularExpression) != nil {
                inPlatformToolsets = true
                skippingExistingSection = true
                if inserted == false {
                    result.append(contentsOf: newSection)
                    inserted = true
                }
                continue
            }

            if inPlatformToolsets, trimmed.range(of: #"^\S"#, options: .regularExpression) != nil, trimmed.isEmpty == false {
                inPlatformToolsets = false
                skippingExistingSection = false
                result.append(line)
                continue
            }

            if skippingExistingSection {
                continue
            }

            result.append(line)
        }

        if inserted == false {
            let trimmedResult = result.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedResult + "\n\n" + newSection.joined(separator: "\n") + "\n"
        }

        return result.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }
}
