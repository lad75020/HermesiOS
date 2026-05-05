//
//  CompanionTargetRegistry.swift
//  HermesHostCompanion
//
//  Created by Codex on 05/05/2026.
//

import CryptoKit
import Foundation

enum CompanionValidationError: LocalizedError {
    case yamlValidationUnavailable

    var errorDescription: String? {
        switch self {
        case .yamlValidationUnavailable:
            "YAML validation is not implemented in the minimal V1 companion."
        }
    }
}

struct CompanionTargetRecord: Codable, Identifiable {
    let id: String
    let displayName: String
    let path: String
    let format: CompanionTargetFormat
    let validators: [CompanionValidatorSpec]
    let serviceID: String?
    let restartPolicy: CompanionRestartPolicy
}

struct CompanionTargetRegistryDocument: Codable {
    let targets: [CompanionTargetRecord]
}

struct CompanionBackupRecord: Codable, Identifiable {
    let id: String
    let targetID: String
    let createdAt: Date
    let path: String
}

private struct CompanionHermesSkillUsageRecord: Codable {
    var archivedAt: String?
    var createdAt: String
    var createdBy: String?
    var lastPatchedAt: String?
    var lastUsedAt: String?
    var lastViewedAt: String?
    var patchCount: Int
    var pinned: Bool
    var state: String
    var useCount: Int
    var viewCount: Int
}

enum CompanionTargetRegistryError: LocalizedError {
    case targetNotFound(String)
    case fileReadFailed(String)
    case revisionMismatch(expected: String, actual: String)
    case validationFailed([CompanionValidationDiagnostic])
    case backupCreationFailed(String)
    case backupNotFound(String)
    case writeFailed(String)
    case invalidWorkspacePath(String)
    case skillNotFound(String)

    var errorDescription: String? {
        switch self {
        case .targetNotFound(let id):
            "No allowlisted target exists for identifier '\(id)'."
        case .fileReadFailed(let path):
            "Unable to read the target file at \(path)."
        case .revisionMismatch(let expected, let actual):
            "Revision mismatch. Expected \(expected), but current revision is \(actual)."
        case .validationFailed:
            "Target validation failed. Inspect diagnostics for details."
        case .backupCreationFailed(let path):
            "Unable to create a backup for \(path)."
        case .backupNotFound(let id):
            "No backup exists for identifier '\(id)'."
        case .writeFailed(let path):
            "Unable to write the target file at \(path)."
        case .invalidWorkspacePath(let path):
            "The Hermes workspace path '\(path)' is invalid or does not contain a skills directory."
        case .skillNotFound(let skillID):
            "No Hermes skill named '\(skillID)' exists in the configured workspace."
        }
    }
}

final class CompanionTargetRegistry {
    static let shared = CompanionTargetRegistry()

    private let fileURL: URL
    private let backupsDirectoryURL: URL
    private let backupsIndexURL: URL
    private var document: CompanionTargetRegistryDocument
    private var backups: [CompanionBackupRecord]

    private init() {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directory = supportDirectory.appendingPathComponent("HermesHostCompanion", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("targets.json")
        backupsDirectoryURL = directory.appendingPathComponent("backups", isDirectory: true)
        backupsIndexURL = directory.appendingPathComponent("backups.json")
        try? FileManager.default.createDirectory(at: backupsDirectoryURL, withIntermediateDirectories: true)

        if let data = try? Data(contentsOf: fileURL),
           let document = try? JSONDecoder().decode(CompanionTargetRegistryDocument.self, from: data) {
            self.document = Self.migratedDocument(from: document)
        } else {
            let seeded = Self.seededDocument()
            self.document = seeded
            if let data = try? JSONEncoder().encode(seeded) {
                try? data.write(to: fileURL, options: [.atomic])
            }
        }

        if let data = try? Data(contentsOf: backupsIndexURL),
           let backups = try? JSONDecoder().decode([CompanionBackupRecord].self, from: data) {
            self.backups = backups
        } else {
            self.backups = []
        }

        ensureSeededTargetFilesExist()
    }

    func listTargets(workspacePath: String? = nil) throws -> [CompanionTargetSummary] {
        try updateHermesConfigTargetIfNeeded(workspacePath: workspacePath)
        return document.targets.map {
            CompanionTargetSummary(
                id: $0.id,
                displayName: $0.displayName,
                format: $0.format,
                path: $0.path,
                serviceID: $0.serviceID,
                restartPolicy: $0.restartPolicy
            )
        }
    }

    func readTarget(id: String) throws -> ReadTargetResult {
        guard let target = document.targets.first(where: { $0.id == id }) else {
            throw CompanionTargetRegistryError.targetNotFound(id)
        }

        let url = URL(fileURLWithPath: target.path)
        guard let data = try? Data(contentsOf: url), let content = String(data: data, encoding: .utf8) else {
            throw CompanionTargetRegistryError.fileReadFailed(target.path)
        }

        return ReadTargetResult(
            targetID: target.id,
            displayName: target.displayName,
            path: target.path,
            revision: Self.revision(for: data),
            content: content,
            format: target.format
        )
    }

    func validateTarget(id: String, proposedContent: String?) throws -> ValidateTargetResult {
        guard let target = document.targets.first(where: { $0.id == id }) else {
            throw CompanionTargetRegistryError.targetNotFound(id)
        }

        let content: String
        let revision: String?

        if let proposedContent {
            content = proposedContent
            revision = Self.revision(for: Data(proposedContent.utf8))
        } else {
            let current = try readTarget(id: id)
            content = current.content
            revision = current.revision
        }

        let diagnostics = target.validators.flatMap { validator in
            validate(validator: validator, format: target.format, content: content)
        }

        return ValidateTargetResult(
            targetID: id,
            valid: !diagnostics.contains(where: { $0.severity == .error }),
            revision: revision,
            diagnostics: diagnostics
        )
    }

    func listBackups(targetID: String?) -> ListBackupsResult {
        let filtered = backups
            .filter { targetID == nil || $0.targetID == targetID }
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt {
                    return lhs.id > rhs.id
                }
                return lhs.createdAt > rhs.createdAt
            }

        return ListBackupsResult(
            backups: filtered.map {
                CompanionBackupSummary(
                    id: $0.id,
                    targetID: $0.targetID,
                    createdAt: $0.createdAt,
                    path: $0.path
                )
            }
        )
    }

    func writeTarget(
        id: String,
        expectedRevision: String,
        content: String,
        createBackup shouldCreateBackup: Bool
    ) throws -> WriteTargetResult {
        guard let target = document.targets.first(where: { $0.id == id }) else {
            throw CompanionTargetRegistryError.targetNotFound(id)
        }

        let current = try readTarget(id: id)
        guard current.revision == expectedRevision else {
            throw CompanionTargetRegistryError.revisionMismatch(expected: expectedRevision, actual: current.revision)
        }

        let validation = try validateTarget(id: id, proposedContent: content)
        guard validation.valid else {
            throw CompanionTargetRegistryError.validationFailed(validation.diagnostics)
        }

        let targetURL = URL(fileURLWithPath: target.path)
        let targetDirectory = targetURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true, attributes: nil)

        var backupID: String?
        if shouldCreateBackup {
            backupID = try makeBackup(for: target, existingContent: current.content, targetPath: target.path)
        }

        let temporaryURL = targetDirectory.appendingPathComponent(".\(targetURL.lastPathComponent).tmp")
        do {
            try content.write(to: temporaryURL, atomically: true, encoding: .utf8)
            _ = try FileManager.default.replaceItemAt(targetURL, withItemAt: temporaryURL)
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw CompanionTargetRegistryError.writeFailed(target.path)
        }

        return WriteTargetResult(
            targetID: id,
            revision: Self.revision(for: Data(content.utf8)),
            backupID: backupID,
            diagnostics: validation.diagnostics
        )
    }

    func restoreBackup(id backupID: String) throws -> RestoreBackupResult {
        guard let backup = backups.first(where: { $0.id == backupID }) else {
            throw CompanionTargetRegistryError.backupNotFound(backupID)
        }

        guard let target = document.targets.first(where: { $0.id == backup.targetID }) else {
            throw CompanionTargetRegistryError.targetNotFound(backup.targetID)
        }

        let backupURL = URL(fileURLWithPath: backup.path)
        guard let data = try? Data(contentsOf: backupURL), let content = String(data: data, encoding: .utf8) else {
            throw CompanionTargetRegistryError.fileReadFailed(backup.path)
        }

        let validation = try validateTarget(id: target.id, proposedContent: content)
        guard validation.valid else {
            throw CompanionTargetRegistryError.validationFailed(validation.diagnostics)
        }

        let targetURL = URL(fileURLWithPath: target.path)
        let targetDirectory = targetURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true, attributes: nil)

        let temporaryURL = targetDirectory.appendingPathComponent(".\(targetURL.lastPathComponent).restore.tmp")
        do {
            try data.write(to: temporaryURL, options: [.atomic])
            _ = try FileManager.default.replaceItemAt(targetURL, withItemAt: temporaryURL)
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw CompanionTargetRegistryError.writeFailed(target.path)
        }

        return RestoreBackupResult(
            backupID: backupID,
            targetID: target.id,
            revision: Self.revision(for: data)
        )
    }

    func listHermesSkills(workspacePath: String) throws -> ListHermesSkillsResult {
        let workspaceURL = try resolvedHermesWorkspaceURL(from: workspacePath)
        let skillsRootURL = workspaceURL.appendingPathComponent("skills", isDirectory: true)
        let usageRecords = loadHermesSkillUsageRecords(workspaceURL: workspaceURL)
        let skills = try enumerateHermesSkills(in: skillsRootURL, usageRecords: usageRecords)

        return ListHermesSkillsResult(
            workspacePath: workspacePath,
            resolvedWorkspacePath: workspaceURL.path,
            skills: skills
        )
    }

    func setHermesSkillState(
        workspacePath: String,
        skillID: String,
        isEnabled: Bool
    ) throws -> SetHermesSkillStateResult {
        let workspaceURL = try resolvedHermesWorkspaceURL(from: workspacePath)
        let skillsRootURL = workspaceURL.appendingPathComponent("skills", isDirectory: true)
        let usageFileURL = workspaceURL.appendingPathComponent("skills/.usage.json")
        let skills = try enumerateHermesSkills(in: skillsRootURL, usageRecords: loadHermesSkillUsageRecords(workspaceURL: workspaceURL))

        guard let matchedSkill = skills.first(where: { $0.id == skillID }) else {
            throw CompanionTargetRegistryError.skillNotFound(skillID)
        }

        var usageRecords = loadHermesSkillUsageRecords(workspaceURL: workspaceURL)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        var record = usageRecords[skillID] ?? CompanionHermesSkillUsageRecord(
            archivedAt: nil,
            createdAt: timestamp,
            createdBy: "HermesiOS",
            lastPatchedAt: nil,
            lastUsedAt: nil,
            lastViewedAt: nil,
            patchCount: 0,
            pinned: false,
            state: "active",
            useCount: 0,
            viewCount: 0
        )
        record.state = isEnabled ? "active" : "archived"
        record.archivedAt = isEnabled ? nil : timestamp
        record.lastPatchedAt = timestamp
        usageRecords[skillID] = record

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(usageRecords)
        try FileManager.default.createDirectory(at: usageFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: usageFileURL, options: [.atomic])

        return SetHermesSkillStateResult(
            workspacePath: workspacePath,
            resolvedWorkspacePath: workspaceURL.path,
            skill: CompanionHermesSkillSummary(
                id: matchedSkill.id,
                name: matchedSkill.name,
                category: matchedSkill.category,
                description: matchedSkill.description,
                path: matchedSkill.path,
                isEnabled: isEnabled
            )
        )
    }

    private static func revision(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private static func seededDocument() -> CompanionTargetRegistryDocument {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return CompanionTargetRegistryDocument(
            targets: [
                CompanionTargetRecord(
                    id: "hermes-config",
                    displayName: "Hermes Config",
                    path: "\(home)/.hermes/config.yaml",
                    format: .yaml,
                    validators: [.yamlParse],
                    serviceID: "hermesd",
                    restartPolicy: .manual
                ),
                CompanionTargetRecord(
                    id: "codex-skills",
                    displayName: "Skills Test Manifest",
                    path: "\(home)/HermesHostCompanionTest/skills/installed-skills.txt",
                    format: .text,
                    validators: [],
                    serviceID: nil,
                    restartPolicy: .manual
                )
            ]
        )
    }

    private static func migratedDocument(from document: CompanionTargetRegistryDocument) -> CompanionTargetRegistryDocument {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let expectedSkillsPath = "\(home)/HermesHostCompanionTest/skills/installed-skills.txt"

        let migratedTargets = document.targets.map { target in
            switch target.id {
            case "hermes-config":
                return CompanionTargetRecord(
                    id: target.id,
                    displayName: "Hermes Config",
                    path: target.path.hasSuffix("config.toml") ? "\(home)/.hermes/config.yaml" : target.path,
                    format: .yaml,
                    validators: [.yamlParse],
                    serviceID: target.serviceID,
                    restartPolicy: target.restartPolicy
                )
            case "codex-skills":
                return CompanionTargetRecord(
                    id: target.id,
                    displayName: "Skills Test Manifest",
                    path: expectedSkillsPath,
                    format: .text,
                    validators: target.validators,
                    serviceID: target.serviceID,
                    restartPolicy: target.restartPolicy
                )
            default:
                return target
            }
        }

        if migratedTargets.contains(where: { $0.id == "codex-skills" }) == false {
            var appendedTargets = migratedTargets
            appendedTargets.append(
                CompanionTargetRecord(
                    id: "codex-skills",
                    displayName: "Skills Test Manifest",
                    path: expectedSkillsPath,
                    format: .text,
                    validators: [],
                    serviceID: nil,
                    restartPolicy: .manual
                )
            )
            return CompanionTargetRegistryDocument(targets: appendedTargets)
        }

        return CompanionTargetRegistryDocument(targets: migratedTargets)
    }

    private func updateHermesConfigTargetIfNeeded(workspacePath: String?) throws {
        guard let workspacePath, workspacePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return
        }

        let workspaceURL = try resolvedHermesWorkspaceURL(from: workspacePath)
        let configURL = workspaceURL.appendingPathComponent("config.yaml")
        guard document.targets.contains(where: { $0.id == "hermes-config" }) else { return }

        var didChange = false
        let updatedTargets = document.targets.map { target -> CompanionTargetRecord in
            guard target.id == "hermes-config" else { return target }
            if target.path == configURL.path, target.format == .yaml, target.validators == [.yamlParse] {
                return target
            }
            didChange = true
            return CompanionTargetRecord(
                id: target.id,
                displayName: "Hermes Config",
                path: configURL.path,
                format: .yaml,
                validators: [.yamlParse],
                serviceID: target.serviceID,
                restartPolicy: target.restartPolicy
            )
        }

        if didChange {
            document = CompanionTargetRegistryDocument(targets: updatedTargets)
            if let data = try? JSONEncoder().encode(document) {
                try? data.write(to: fileURL, options: [.atomic])
            }
        }
    }

    private func ensureSeededTargetFilesExist() {
        for target in document.targets {
            guard target.id == "codex-skills" else { continue }
            let url = URL(fileURLWithPath: target.path)
            let directory = url.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: url.path) == false {
                let defaultManifest = """
                aidesigner-frontend
                skill-installer
                """
                try? defaultManifest.write(to: url, atomically: true, encoding: .utf8)
            }
        }

        if let data = try? JSONEncoder().encode(document) {
            try? data.write(to: fileURL, options: [.atomic])
        }
    }

    private func resolvedHermesWorkspaceURL(from workspacePath: String) throws -> URL {
        let trimmedPath = workspacePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let expandedPath = NSString(string: trimmedPath.isEmpty ? "~/.hermes" : trimmedPath).expandingTildeInPath
        let workspaceURL = URL(fileURLWithPath: expandedPath, isDirectory: true)
        var isDirectory: ObjCBool = false
        let hasWorkspace = FileManager.default.fileExists(atPath: workspaceURL.path, isDirectory: &isDirectory)
        let skillsRootURL = workspaceURL.appendingPathComponent("skills", isDirectory: true)
        let hasSkills = FileManager.default.fileExists(atPath: skillsRootURL.path, isDirectory: &isDirectory)
        guard hasWorkspace, hasSkills else {
            throw CompanionTargetRegistryError.invalidWorkspacePath(expandedPath)
        }
        return workspaceURL
    }

    private func loadHermesSkillUsageRecords(workspaceURL: URL) -> [String: CompanionHermesSkillUsageRecord] {
        let usageFileURL = workspaceURL.appendingPathComponent("skills/.usage.json")
        guard
            let data = try? Data(contentsOf: usageFileURL),
            let records = try? JSONDecoder().decode([String: CompanionHermesSkillUsageRecord].self, from: data)
        else {
            return [:]
        }
        return records
    }

    private func enumerateHermesSkills(
        in skillsRootURL: URL,
        usageRecords: [String: CompanionHermesSkillUsageRecord]
    ) throws -> [CompanionHermesSkillSummary] {
        let categoryURLs = try FileManager.default.contentsOfDirectory(
            at: skillsRootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var skills: [CompanionHermesSkillSummary] = []

        for categoryURL in categoryURLs.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let values = try categoryURL.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else { continue }

            let categoryName = categoryURL.lastPathComponent
            let skillURLs = try FileManager.default.contentsOfDirectory(
                at: categoryURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            for skillURL in skillURLs.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                let skillValues = try skillURL.resourceValues(forKeys: [.isDirectoryKey])
                guard skillValues.isDirectory == true else { continue }

                let skillID = skillURL.lastPathComponent
                let description = firstReadableSkillDescription(skillURL: skillURL, categoryURL: categoryURL)
                let usageState = usageRecords[skillID]?.state.lowercased()

                skills.append(
                    CompanionHermesSkillSummary(
                        id: skillID,
                        name: skillID,
                        category: categoryName,
                        description: description,
                        path: skillURL.path,
                        isEnabled: usageState != "archived"
                    )
                )
            }
        }

        return skills.sorted {
            if $0.category == $1.category {
                return $0.name < $1.name
            }
            return $0.category < $1.category
        }
    }

    private func firstReadableSkillDescription(skillURL: URL, categoryURL: URL) -> String {
        let candidateURLs = [
            skillURL.appendingPathComponent("DESCRIPTION.md"),
            skillURL.appendingPathComponent("SKILL.md"),
            categoryURL.appendingPathComponent("DESCRIPTION.md")
        ]

        for candidateURL in candidateURLs {
            guard let content = try? String(contentsOf: candidateURL, encoding: .utf8) else { continue }
            for line in content.components(separatedBy: .newlines) {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmedLine.isEmpty == false, trimmedLine != "---", trimmedLine.hasPrefix("name:") == false else {
                    continue
                }
                return trimmedLine
            }
        }

        return "Skill available in the Hermes workspace."
    }

    private func validate(
        validator: CompanionValidatorSpec,
        format: CompanionTargetFormat,
        content: String
    ) -> [CompanionValidationDiagnostic] {
        switch validator {
        case .tomlParse:
            if format != .toml {
                return []
            }
            return validateTOML(content)
        case .jsonParse:
            if format != .json {
                return []
            }
            return validateJSON(content)
        case .yamlParse:
            if format != .yaml {
                return []
            }
            return [
                CompanionValidationDiagnostic(
                    id: UUID(),
                    severity: .warning,
                    message: CompanionValidationError.yamlValidationUnavailable.localizedDescription,
                    validator: "yamlParse"
                )
            ]
        case .command(let command):
            return [
                CompanionValidationDiagnostic(
                    id: UUID(),
                    severity: .info,
                    message: "Command validator reserved for later implementation: \(command.joined(separator: " "))",
                    validator: "command"
                )
            ]
        }
    }

    private func validateJSON(_ content: String) -> [CompanionValidationDiagnostic] {
        do {
            _ = try JSONSerialization.jsonObject(with: Data(content.utf8))
            return []
        } catch {
            return [
                CompanionValidationDiagnostic(
                    id: UUID(),
                    severity: .error,
                    message: error.localizedDescription,
                    validator: "jsonParse"
                )
            ]
        }
    }

    private func validateTOML(_ content: String) -> [CompanionValidationDiagnostic] {
        var diagnostics: [CompanionValidationDiagnostic] = []
        var activeSection = ""

        for (lineIndex, rawLine) in content.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }

            if trimmed.hasPrefix("[") {
                guard trimmed.hasSuffix("]"), trimmed.count > 2 else {
                    diagnostics.append(
                        CompanionValidationDiagnostic(
                            id: UUID(),
                            severity: .error,
                            message: "Line \(lineIndex + 1): malformed TOML section header.",
                            validator: "tomlParse"
                        )
                    )
                    continue
                }
                activeSection = String(trimmed.dropFirst().dropLast())
                continue
            }

            guard let equalsIndex = trimmed.firstIndex(of: "=") else {
                diagnostics.append(
                    CompanionValidationDiagnostic(
                        id: UUID(),
                        severity: .error,
                        message: "Line \(lineIndex + 1): expected key/value pair.",
                        validator: "tomlParse"
                    )
                )
                continue
            }

            let key = trimmed[..<equalsIndex].trimmingCharacters(in: .whitespaces)
            let value = trimmed[trimmed.index(after: equalsIndex)...].trimmingCharacters(in: .whitespaces)

            if key.isEmpty || value.isEmpty {
                diagnostics.append(
                    CompanionValidationDiagnostic(
                        id: UUID(),
                        severity: .error,
                        message: "Line \(lineIndex + 1): empty key or value in \(activeSection.isEmpty ? "root" : activeSection).",
                        validator: "tomlParse"
                    )
                )
            }
        }

        return diagnostics
    }

    private func makeBackup(for target: CompanionTargetRecord, existingContent: String, targetPath: String) throws -> String {
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupID = "\(target.id)-\(timestamp)"
        let backupURL = backupsDirectoryURL.appendingPathComponent("\(backupID).bak")

        do {
            try existingContent.write(to: backupURL, atomically: true, encoding: .utf8)
            backups.append(
                CompanionBackupRecord(
                    id: backupID,
                    targetID: target.id,
                    createdAt: Date(),
                    path: backupURL.path
                )
            )
            persistBackups()
            return backupID
        } catch {
            throw CompanionTargetRegistryError.backupCreationFailed(targetPath)
        }
    }

    private func persistBackups() {
        guard let data = try? JSONEncoder().encode(backups) else { return }
        try? data.write(to: backupsIndexURL, options: [.atomic])
    }
}
