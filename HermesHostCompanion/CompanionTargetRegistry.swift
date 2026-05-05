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

enum CompanionTargetRegistryError: LocalizedError {
    case targetNotFound(String)
    case fileReadFailed(String)
    case revisionMismatch(expected: String, actual: String)
    case validationFailed([CompanionValidationDiagnostic])
    case backupCreationFailed(String)
    case backupNotFound(String)
    case writeFailed(String)

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
            self.document = document
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
    }

    func listTargets() -> [CompanionTargetSummary] {
        document.targets.map {
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
                    path: "\(home)/.hermes/config.toml",
                    format: .toml,
                    validators: [.tomlParse],
                    serviceID: "hermesd",
                    restartPolicy: .manual
                ),
                CompanionTargetRecord(
                    id: "codex-skills",
                    displayName: "Codex Skills Directory",
                    path: "\(home)/.codex/skills/README.md",
                    format: .text,
                    validators: [],
                    serviceID: nil,
                    restartPolicy: .manual
                )
            ]
        )
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
