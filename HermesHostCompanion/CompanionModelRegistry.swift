//
//  CompanionModelRegistry.swift
//  HermesHostCompanion
//
//  Created by Codex on 05/05/2026.
//

import Foundation

struct CompanionSavedModel: Codable, Identifiable {
    let id: String
    let name: String
    let provider: String
    let model: String
    let baseURL: String
    let createdAt: Int64
}

struct CompanionDefaultModelSeed {
    let name: String
    let provider: String
    let model: String
    let baseURL: String
}

enum CompanionModelRegistryError: LocalizedError {
    case invalidWorkspacePath(String)
    case modelNotFound(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidWorkspacePath(let path):
            "The Hermes workspace path '\(path)' is invalid."
        case .modelNotFound(let id):
            "No Hermes model with ID '\(id)' exists."
        case .writeFailed(let path):
            "The companion could not write '\(path)'."
        }
    }
}

final class CompanionModelRegistry {
    static let shared = CompanionModelRegistry()

    private static let defaultModels: [CompanionDefaultModelSeed] = [
        .init(name: "Claude Sonnet 4", provider: "openrouter", model: "anthropic/claude-sonnet-4-20250514", baseURL: ""),
        .init(name: "Claude Sonnet 4", provider: "anthropic", model: "claude-sonnet-4-20250514", baseURL: ""),
        .init(name: "GPT-4.1", provider: "openai", model: "gpt-4.1", baseURL: "")
    ]

    func listModels(workspacePath: String) throws -> ListModelsResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let modelsFileURL = workspaceURL.appendingPathComponent("models.json")
        let models = loadModels(from: modelsFileURL) ?? seedDefaults(into: modelsFileURL)

        return ListModelsResult(
            workspacePath: workspacePath,
            resolvedWorkspacePath: workspaceURL.path,
            modelsFilePath: modelsFileURL.path,
            models: models.sorted { $0.createdAt > $1.createdAt }
        )
    }

    func addModel(
        workspacePath: String,
        name: String,
        provider: String,
        model: String,
        baseURL: String
    ) throws -> AddModelResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let modelsFileURL = workspaceURL.appendingPathComponent("models.json")
        var models = loadModels(from: modelsFileURL) ?? seedDefaults(into: modelsFileURL)

        if let existing = models.first(where: { $0.model == model && $0.provider == provider }) {
            return AddModelResult(
                workspacePath: workspacePath,
                resolvedWorkspacePath: workspaceURL.path,
                modelsFilePath: modelsFileURL.path,
                model: existing
            )
        }

        let entry = CompanionSavedModel(
            id: UUID().uuidString,
            name: name,
            provider: provider,
            model: model,
            baseURL: baseURL,
            createdAt: Int64(Date().timeIntervalSince1970 * 1000)
        )
        models.append(entry)
        try writeModels(models, to: modelsFileURL)

        return AddModelResult(
            workspacePath: workspacePath,
            resolvedWorkspacePath: workspaceURL.path,
            modelsFilePath: modelsFileURL.path,
            model: entry
        )
    }

    func updateModel(
        workspacePath: String,
        id: String,
        name: String,
        provider: String,
        model: String,
        baseURL: String
    ) throws -> UpdateModelResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let modelsFileURL = workspaceURL.appendingPathComponent("models.json")
        var models = loadModels(from: modelsFileURL) ?? seedDefaults(into: modelsFileURL)

        guard let index = models.firstIndex(where: { $0.id == id }) else {
            throw CompanionModelRegistryError.modelNotFound(id)
        }

        let updated = CompanionSavedModel(
            id: models[index].id,
            name: name,
            provider: provider,
            model: model,
            baseURL: baseURL,
            createdAt: models[index].createdAt
        )
        models[index] = updated
        try writeModels(models, to: modelsFileURL)

        return UpdateModelResult(
            workspacePath: workspacePath,
            resolvedWorkspacePath: workspaceURL.path,
            modelsFilePath: modelsFileURL.path,
            model: updated
        )
    }

    func removeModel(workspacePath: String, id: String) throws -> RemoveModelResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let modelsFileURL = workspaceURL.appendingPathComponent("models.json")
        let models = loadModels(from: modelsFileURL) ?? seedDefaults(into: modelsFileURL)
        let filtered = models.filter { $0.id != id }
        guard filtered.count != models.count else {
            throw CompanionModelRegistryError.modelNotFound(id)
        }

        try writeModels(filtered, to: modelsFileURL)
        return RemoveModelResult(
            workspacePath: workspacePath,
            resolvedWorkspacePath: workspaceURL.path,
            modelsFilePath: modelsFileURL.path,
            removedModelID: id
        )
    }

    private func resolvedWorkspaceURL(from workspacePath: String) throws -> URL {
        let trimmedPath = workspacePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let expandedPath = NSString(string: trimmedPath.isEmpty ? "~/.hermes" : trimmedPath).expandingTildeInPath
        let workspaceURL = URL(fileURLWithPath: expandedPath, isDirectory: true)

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: workspaceURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw CompanionModelRegistryError.invalidWorkspacePath(expandedPath)
        }
        return workspaceURL
    }

    private func loadModels(from url: URL) -> [CompanionSavedModel]? {
        guard
            let data = try? Data(contentsOf: url),
            let models = try? JSONDecoder().decode([CompanionSavedModel].self, from: data)
        else {
            return nil
        }
        return models
    }

    private func writeModels(_ models: [CompanionSavedModel], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(models)
            try data.write(to: url, options: [.atomic])
        } catch {
            throw CompanionModelRegistryError.writeFailed(url.path)
        }
    }

    private func seedDefaults(into url: URL) -> [CompanionSavedModel] {
        let seeded = Self.defaultModels.map { seed in
            CompanionSavedModel(
                id: UUID().uuidString,
                name: seed.name,
                provider: seed.provider,
                model: seed.model,
                baseURL: seed.baseURL,
                createdAt: Int64(Date().timeIntervalSince1970 * 1000)
            )
        }
        try? writeModels(seeded, to: url)
        return seeded
    }
}
