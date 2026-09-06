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
        .init(key: "stt", label: "Speech-to-Text", description: "Allow speech transcription for gateway voice messages and voice mode."),
        .init(key: "skills", label: "Skills", description: "Allow loading and applying Hermes skills."),
        .init(key: "memory", label: "Memory", description: "Allow persistent memory and workspace note tools."),
        .init(key: "session_search", label: "Session Search", description: "Allow searching prior sessions and stored traces."),
        .init(key: "clarify", label: "Clarify", description: "Allow clarification workflows before acting."),
        .init(key: "delegation", label: "Delegation", description: "Allow delegation or sub-agent workflows."),
        .init(key: "cronjob", label: "Cronjob", description: "Allow scheduled background jobs."),
        .init(key: "moa", label: "MOA", description: "Allow mixture-of-agents style orchestration."),
        .init(key: "todo", label: "Todo", description: "Allow task-list and todo management tools.")
    ]

    func listToolsets(workspacePath: String) async throws -> ListToolsetsResult {
        let configURL = try resolvedConfigURL(from: workspacePath)
        let result = try await CompanionRuntimeConfigSafety.apply(configURL: configURL, request: ["action": "listTools"])
        guard let enabled = result["enabledToolsets"] as? [String] else { throw CompanionRuntimeConfigSafety.Failure.rejected }
        let configOnlyEnabled = result["configOnlyEnabledToolsets"] as? [String] ?? []

        return ListToolsetsResult(
            workspacePath: workspacePath,
            resolvedWorkspacePath: configURL.deletingLastPathComponent().path,
            configPath: configURL.path,
            toolsets: Self.makeToolsetInfos(enabledToolsets: enabled, configOnlyEnabledToolsets: configOnlyEnabled)
        )
    }

    static func makeToolsetInfos(enabledToolsets: [String], configOnlyEnabledToolsets: [String]) -> [CompanionToolsetInfo] {
        let enabledSet = Set(enabledToolsets).union(configOnlyEnabledToolsets)
        return definitions.map { definition in
            CompanionToolsetInfo(
                key: definition.key,
                label: definition.label,
                description: definition.description,
                enabled: enabledSet.contains(definition.key)
            )
        }
    }

    func setToolsetEnabled(
        workspacePath: String,
        key: String,
        enabled: Bool
    ) async throws -> SetToolsetEnabledResult {
        guard Self.definitions.contains(where: { $0.key == key }) else {
            throw CompanionToolsetRegistryError.unsupportedToolset(key)
        }

        let configURL = try resolvedConfigURL(from: workspacePath)
        _ = try await CompanionRuntimeConfigSafety.apply(configURL: configURL,
            request: ["action": "setTool", "key": key, "enabled": enabled])

        let refreshed = try await listToolsets(workspacePath: workspacePath)
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

}
