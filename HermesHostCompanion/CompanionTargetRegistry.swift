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
    let targetPath: String?
}

enum CompanionTargetRegistryError: LocalizedError {
    case targetNotFound(String)
    case fileReadFailed(String)
    case revisionMismatch(expected: String, actual: String)
    case validationFailed([CompanionValidationDiagnostic])
    case backupCreationFailed(String)
    case backupNotFound(String)
    case backupTargetUnavailable(String)
    case writeFailed(String)
    case invalidWorkspacePath(String)
    case invalidProfileName(String)
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
        case .backupTargetUnavailable(let id):
            "Backup '\(id)' is not bound to a valid original target path."
        case .writeFailed(let path):
            "Unable to write the target file at \(path)."
        case .invalidWorkspacePath(let path):
            "The Hermes workspace path '\(path)' is invalid or does not contain a skills directory."
        case .invalidProfileName(let name):
            "The Hermes profile name '\(name)' is invalid or does not identify an existing profile."
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

    private convenience init() {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directory = supportDirectory.appendingPathComponent("HermesHostCompanion", isDirectory: true)
        self.init(storageDirectoryURL: directory)
    }

    init(storageDirectoryURL directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("targets.json")
        backupsDirectoryURL = directory.appendingPathComponent("backups", isDirectory: true)
        backupsIndexURL = directory.appendingPathComponent("backups.json")
        try? FileManager.default.createDirectory(at: backupsDirectoryURL, withIntermediateDirectories: true)

        let loadedDocument: CompanionTargetRegistryDocument?
        if let data = try? Data(contentsOf: fileURL),
           let document = try? JSONDecoder().decode(CompanionTargetRegistryDocument.self, from: data) {
            loadedDocument = document
            self.document = Self.migratedDocument(from: document)
        } else {
            loadedDocument = nil
            let seeded = Self.seededDocument()
            self.document = seeded
            if let data = try? JSONEncoder().encode(seeded) {
                try? data.write(to: fileURL, options: [.atomic])
            }
        }

        if let data = try? Data(contentsOf: backupsIndexURL),
           let backups = try? JSONDecoder().decode([CompanionBackupRecord].self, from: data) {
            let loadedTargets = loadedDocument?.targets ?? []
            self.backups = backups.map { backup in
                guard backup.targetPath == nil,
                      let targetPath = Self.unambiguousLegacyTargetPath(
                          for: backup.targetID,
                          targets: loadedTargets
                      ) else {
                    return backup
                }
                return CompanionBackupRecord(
                    id: backup.id,
                    targetID: backup.targetID,
                    createdAt: backup.createdAt,
                    path: backup.path,
                    targetPath: targetPath
                )
            }
        } else {
            self.backups = []
        }

        persistBackups()
        ensureSeededTargetFilesExist()
    }

    func listTargets(workspacePath: String? = nil, profileName: String? = nil) throws -> [CompanionTargetSummary] {
        try targetRecords(workspacePath: workspacePath, profileName: profileName).map {
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

    func readTarget(id: String, workspacePath: String? = nil, profileName: String? = nil) throws -> ReadTargetResult {
        let target = try targetRecord(id: id, workspacePath: workspacePath, profileName: profileName)

        let url = URL(fileURLWithPath: target.path)
        guard let data = try? Data(contentsOf: url), let content = String(data: data, encoding: .utf8) else {
            if target.id == "hermes-config" {
                return ReadTargetResult(
                    targetID: target.id,
                    displayName: target.displayName,
                    path: target.path,
                    revision: Self.revision(for: Data()),
                    content: "",
                    format: target.format
                )
            }
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

    func validateTarget(id: String, proposedContent: String?, workspacePath: String? = nil, profileName: String? = nil) async throws -> ValidateTargetResult {
        let target = try targetRecord(id: id, workspacePath: workspacePath, profileName: profileName)

        let content: String
        let revision: String?

        if let proposedContent {
            content = proposedContent
            revision = Self.revision(for: Data(proposedContent.utf8))
        } else {
            let current = try readTarget(id: id, workspacePath: workspacePath, profileName: profileName)
            content = current.content
            revision = current.revision
        }

        var diagnostics: [CompanionValidationDiagnostic] = []
        for validator in target.validators {
            diagnostics.append(contentsOf: try await validate(
                validator: validator,
                format: target.format,
                content: content,
                targetPath: target.path
            ))
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
        createBackup shouldCreateBackup: Bool,
        workspacePath: String? = nil,
        profileName: String? = nil
    ) async throws -> WriteTargetResult {
        let target = try targetRecord(id: id, workspacePath: workspacePath, profileName: profileName)

        let current = try readTarget(id: id, workspacePath: workspacePath, profileName: profileName)
        guard current.revision == expectedRevision else {
            throw CompanionTargetRegistryError.revisionMismatch(expected: expectedRevision, actual: current.revision)
        }

        let validation = try await validateTarget(
            id: id,
            proposedContent: content,
            workspacePath: workspacePath,
            profileName: profileName
        )
        guard validation.valid else {
            throw CompanionTargetRegistryError.validationFailed(validation.diagnostics)
        }

        // Validation can suspend while an external parser runs. Re-resolve and
        // re-read the exact request-scoped target before creating a backup or
        // replacing the file so a stale revision cannot win after that await.
        let recheckedTarget = try targetRecord(id: id, workspacePath: workspacePath, profileName: profileName)
        let recheckedCurrent = try readTarget(id: id, workspacePath: workspacePath, profileName: profileName)
        let originalTargetPath = Self.canonicalPath(target.path)
        guard Self.canonicalPath(recheckedTarget.path) == originalTargetPath,
              Self.canonicalPath(recheckedCurrent.path) == originalTargetPath,
              recheckedCurrent.revision == expectedRevision else {
            throw CompanionTargetRegistryError.revisionMismatch(
                expected: expectedRevision,
                actual: recheckedCurrent.revision
            )
        }

        let targetURL = URL(fileURLWithPath: recheckedTarget.path)
        let targetDirectory = targetURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true, attributes: nil)

        var backupID: String?
        if shouldCreateBackup {
            backupID = try makeBackup(
                for: recheckedTarget,
                existingContent: recheckedCurrent.content,
                targetPath: recheckedTarget.path
            )
        }

        let temporaryURL = uniqueTemporaryURL(for: targetURL, operation: "write")
        do {
            try content.write(to: temporaryURL, atomically: true, encoding: .utf8)
            _ = try FileManager.default.replaceItemAt(targetURL, withItemAt: temporaryURL)
        } catch {
            try? FileManager.default.removeItem(at: temporaryURL)
            throw CompanionTargetRegistryError.writeFailed(recheckedTarget.path)
        }

        return WriteTargetResult(
            targetID: id,
            revision: Self.revision(for: Data(content.utf8)),
            backupID: backupID,
            diagnostics: validation.diagnostics
        )
    }

    func restoreBackup(id backupID: String) async throws -> RestoreBackupResult {
        guard let backup = backups.first(where: { $0.id == backupID }) else {
            throw CompanionTargetRegistryError.backupNotFound(backupID)
        }

        guard let targetTemplate = document.targets.first(where: { $0.id == backup.targetID }) else {
            throw CompanionTargetRegistryError.targetNotFound(backup.targetID)
        }

        guard let storedTargetPath = backup.targetPath else {
            throw CompanionTargetRegistryError.backupTargetUnavailable(backupID)
        }
        let targetPath = Self.canonicalPath(storedTargetPath)
        if targetTemplate.id == "hermes-config" {
            guard isValidHermesConfigPath(targetPath) else {
                throw CompanionTargetRegistryError.backupTargetUnavailable(backupID)
            }
        } else {
            // Static legacy records are safe only when the decoded target had one
            // unambiguous path and that path is still the active allowlist entry.
            guard targetPath == Self.canonicalPath(targetTemplate.path) else {
                throw CompanionTargetRegistryError.backupTargetUnavailable(backupID)
            }
        }
        let target = CompanionTargetRecord(
            id: targetTemplate.id,
            displayName: targetTemplate.displayName,
            path: targetPath,
            format: targetTemplate.format,
            validators: targetTemplate.validators,
            serviceID: targetTemplate.serviceID,
            restartPolicy: targetTemplate.restartPolicy
        )

        let backupURL = URL(fileURLWithPath: backup.path)
        guard let data = try? Data(contentsOf: backupURL), let content = String(data: data, encoding: .utf8) else {
            throw CompanionTargetRegistryError.fileReadFailed(backup.path)
        }

        var diagnostics: [CompanionValidationDiagnostic] = []
        for validator in target.validators {
            diagnostics.append(contentsOf: try await validate(
                validator: validator,
                format: target.format,
                content: content,
                targetPath: target.path
            ))
        }
        guard diagnostics.contains(where: { $0.severity == .error }) == false else {
            throw CompanionTargetRegistryError.validationFailed(diagnostics)
        }

        let targetURL = URL(fileURLWithPath: target.path)
        let targetDirectory = targetURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true, attributes: nil)

        let temporaryURL = uniqueTemporaryURL(for: targetURL, operation: "restore")
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

    @MainActor
    func listHermesSkills(workspacePath: String) async throws -> ListHermesSkillsResult {
        let result = try await hermesSkillsBridge(workspacePath: workspacePath, request: ["action": "list"])
        return ListHermesSkillsResult(workspacePath: workspacePath, resolvedWorkspacePath: result.workspacePath, skills: result.skills)
    }

    @MainActor
    func setHermesSkillState(
        workspacePath: String,
        skillID: String,
        isEnabled: Bool
    ) async throws -> SetHermesSkillStateResult {
        let result = try await hermesSkillsBridge(workspacePath: workspacePath, request: ["action": "set", "skillID": skillID, "isEnabled": isEnabled])
        guard let skill = result.skills.first(where: { $0.id == skillID }) else { throw CompanionTargetRegistryError.skillNotFound(skillID) }
        return SetHermesSkillStateResult(workspacePath: workspacePath, resolvedWorkspacePath: result.workspacePath, skill: skill)
    }

    /// Hermes owns both discovery and the disabled-skills schema.  In particular,
    /// `_find_all_skills(skip_disabled: true)` covers a root SKILL.md and nested
    /// category trees, while get/save_disabled_skills preserves unrelated config.
    private struct HermesSkillsBridgeResult: Decodable {
        let workspacePath: String
        let skills: [CompanionHermesSkillSummary]
    }

    @MainActor
    private func hermesSkillsBridge(workspacePath: String, request: [String: Any]) async throws -> HermesSkillsBridgeResult {
        guard let context = CompanionWorkspaceSecurity.resolvedHermesCLIContext(from: workspacePath) else {
            throw CompanionTargetRegistryError.invalidWorkspacePath(workspacePath)
        }
        let venvPython = context.cliRootURL.appendingPathComponent("hermes-agent/venv/bin/python").path
        let executableURL = FileManager.default.isExecutableFile(atPath: venvPython) ? URL(fileURLWithPath: venvPython) : URL(fileURLWithPath: "/usr/bin/python3")
        var environment = ProcessInfo.processInfo.environment
        environment["HERMES_HOME"] = context.selectedHomeURL.path
        environment["PYTHONPATH"] = context.cliRootURL.appendingPathComponent("hermes-agent").path
        let output = try await CompanionSubprocess.run(
            executableURL: executableURL, arguments: ["-c", Self.hermesSkillsBridgeScript],
            environment: environment, input: JSONSerialization.data(withJSONObject: request))
        guard output.status == 0, let result = try? JSONDecoder().decode(HermesSkillsBridgeResult.self, from: output.stdout) else {
            throw CompanionTargetRegistryError.writeFailed("selected Hermes skills configuration")
        }
        return result
    }

    private static let hermesSkillsBridgeScript = #"""
import json, os, sys
from hermes_cli.config import load_config
from hermes_cli.skills_config import get_disabled_skills, save_disabled_skills
from tools.skills_tool import _find_all_skills
r = json.load(sys.stdin); config = load_config(); all_skills = _find_all_skills(skip_disabled=True)
by_id = {str(s.get("name", "")).strip(): s for s in all_skills if str(s.get("name", "")).strip()}
if r.get("action") == "set":
    skill_id = str(r.get("skillID", "")).strip()
    if skill_id not in by_id: raise ValueError("Skill not found")
    disabled = get_disabled_skills(config)
    if bool(r.get("isEnabled")): disabled.discard(skill_id)
    else: disabled.add(skill_id)
    save_disabled_skills(config, disabled)
elif r.get("action") != "list": raise ValueError("Unsupported skills operation")
disabled = get_disabled_skills(load_config())
def summary(skill_id, skill):
    category = str(skill.get("category") or "uncategorized")
    return {"id": skill_id, "name": skill_id, "category": category, "description": str(skill.get("description") or "Skill available in the Hermes workspace."), "path": "", "isEnabled": skill_id not in disabled}
print(json.dumps({"workspacePath": os.environ["HERMES_HOME"], "skills": [summary(k, v) for k, v in sorted(by_id.items(), key=lambda item: (str(item[1].get("category") or ""), item[0]))]}))
"""#

    private static func revision(for data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    private static func canonicalPath(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path
    }

    private static func unambiguousLegacyTargetPath(
        for targetID: String,
        targets: [CompanionTargetRecord]
    ) -> String? {
        // `hermes-config` used to be a mutable global selection. Its persisted
        // path cannot prove which profile produced an older backup, so keep such
        // records unbound and fail closed on restore.
        guard targetID != "hermes-config" else { return nil }
        let paths = Set(
            targets
                .filter { $0.id == targetID }
                .map { canonicalPath($0.path) }
        )
        guard paths.count == 1 else { return nil }
        return paths.first
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
                    path: "\(home)/.hermes/config.yaml",
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

    private func targetRecords(workspacePath: String?, profileName: String?) throws -> [CompanionTargetRecord] {
        try document.targets.map { target in
            guard target.id == "hermes-config",
                  let workspacePath,
                  workspacePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
                return target
            }
            let workspaceURL = try resolvedHermesWorkspaceURL(from: workspacePath)
            guard let profileURL = CompanionWorkspaceSecurity.resolvedProfileURL(workspaceURL: workspaceURL, profileName: profileName) else {
                throw CompanionTargetRegistryError.invalidProfileName(profileName ?? "")
            }
            return CompanionTargetRecord(
                id: target.id,
                displayName: target.displayName,
                path: profileURL.appendingPathComponent("config.yaml").path,
                format: .yaml,
                validators: [.yamlParse],
                serviceID: target.serviceID,
                restartPolicy: target.restartPolicy
            )
        }
    }

    private func targetRecord(id: String, workspacePath: String?, profileName: String?) throws -> CompanionTargetRecord {
        guard let target = try targetRecords(workspacePath: workspacePath, profileName: profileName).first(where: { $0.id == id }) else {
            throw CompanionTargetRegistryError.targetNotFound(id)
        }
        return target
    }

    private func isValidHermesConfigPath(_ rawPath: String) -> Bool {
        let configURL = URL(fileURLWithPath: rawPath).resolvingSymlinksInPath().standardizedFileURL
        guard configURL.lastPathComponent == "config.yaml" else { return false }
        let containerURL = configURL.deletingLastPathComponent()
        if CompanionWorkspaceSecurity.resolvedHermesWorkspaceURL(from: containerURL.path, requireSkillsDirectory: true) == containerURL {
            return true
        }
        let profilesURL = containerURL.deletingLastPathComponent()
        guard profilesURL.lastPathComponent == "profiles" else { return false }
        let workspaceURL = profilesURL.deletingLastPathComponent()
        guard CompanionWorkspaceSecurity.resolvedHermesWorkspaceURL(from: workspaceURL.path, requireSkillsDirectory: true) == workspaceURL else {
            return false
        }
        return CompanionWorkspaceSecurity.resolvedProfileURL(
            workspaceURL: workspaceURL,
            profileName: containerURL.lastPathComponent
        ) == containerURL
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
        guard let workspaceURL = CompanionWorkspaceSecurity.resolvedHermesWorkspaceURL(from: workspacePath, requireSkillsDirectory: true) else {
            throw CompanionTargetRegistryError.invalidWorkspacePath(workspacePath)
        }
        return workspaceURL
    }


    private func validate(
        validator: CompanionValidatorSpec,
        format: CompanionTargetFormat,
        content: String,
        targetPath: String
    ) async throws -> [CompanionValidationDiagnostic] {
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
            return try await validateYAML(content, targetPath: targetPath)
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

    private func validateYAML(_ content: String, targetPath: String) async throws -> [CompanionValidationDiagnostic] {
        let pythonDiagnostics = try await validateYAMLWithPython(content, targetPath: targetPath)
        if pythonDiagnostics.count == 1,
           let diagnostic = pythonDiagnostics.first,
           diagnostic.severity == .warning,
           diagnostic.message.hasPrefix("YAML parser unavailable:") {
            return []
        }
        return pythonDiagnostics
    }

    private func validateYAMLWithPython(_ content: String, targetPath: String) async throws -> [CompanionValidationDiagnostic] {
        let script = """
        import json
        import sys

        try:
            import yaml
        except Exception as exc:
            print(json.dumps({"ok": False, "parser_unavailable": True, "message": str(exc)}))
            sys.exit(0)

        content = sys.stdin.read()
        try:
            yaml.safe_load(content)
            print(json.dumps({"ok": True}))
        except yaml.YAMLError as exc:
            mark = getattr(exc, 'problem_mark', None)
            message = getattr(exc, 'problem', None) or str(exc)
            payload = {"ok": False, "message": message}
            if mark is not None:
                payload["line"] = int(mark.line) + 1
                payload["column"] = int(mark.column) + 1
            print(json.dumps(payload))
        """

        var parserUnavailableMessages: [String] = []

        for executable in yamlPythonExecutableCandidates(targetPath: targetPath) {
            let executableURL: URL
            let arguments: [String]
            if executable == "python3" {
                executableURL = URL(fileURLWithPath: "/usr/bin/env")
                arguments = ["python3", "-c", script]
            } else {
                executableURL = URL(fileURLWithPath: executable)
                arguments = ["-c", script]
            }

            let output: CompanionSubprocess.Output
            do {
                output = try await CompanionSubprocess.run(
                    executableURL: executableURL,
                    arguments: arguments,
                    environment: sanitizedSubprocessEnvironment(),
                    input: Data(content.utf8),
                    timeout: 10,
                    maxOutputBytes: 65_536
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                parserUnavailableMessages.append("\(executable): \(error.localizedDescription)")
                continue
            }

            guard output.status == 0 else {
                let stderr = String(data: output.stderr, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                return [
                    CompanionValidationDiagnostic(
                        id: UUID(),
                        severity: .error,
                        message: stderr?.isEmpty == false ? stderr! : "YAML parser failed with exit code \(output.status).",
                        validator: "yamlParse"
                    )
                ]
            }

            guard
                let object = try? JSONSerialization.jsonObject(with: output.stdout) as? [String: Any],
                let ok = object["ok"] as? Bool
            else {
                return [
                    CompanionValidationDiagnostic(
                        id: UUID(),
                        severity: .warning,
                        message: "YAML parser returned an unreadable response; skipping strict YAML validation.",
                        validator: "yamlParse"
                    )
                ]
            }

            if ok {
                return []
            }

            if object["parser_unavailable"] as? Bool == true {
                let message = object["message"] as? String ?? "PyYAML is not available."
                parserUnavailableMessages.append("\(executable): \(message)")
                continue
            }

            let rawMessage = object["message"] as? String ?? "Invalid YAML."
            let line = object["line"] as? Int
            let column = object["column"] as? Int
            let location: String
            if let line, let column {
                location = "Line \(line), column \(column): "
            } else if let line {
                location = "Line \(line): "
            } else {
                location = ""
            }

            return [
                CompanionValidationDiagnostic(
                    id: UUID(),
                    severity: .error,
                    message: "\(location)\(rawMessage)",
                    validator: "yamlParse"
                )
            ]
        }

        let details = parserUnavailableMessages.isEmpty ? "No Python executable was found." : parserUnavailableMessages.joined(separator: "; ")
        return [
            CompanionValidationDiagnostic(
                id: UUID(),
                severity: .warning,
                message: "YAML parser unavailable: \(details)",
                validator: "yamlParse"
            )
        ]
    }

    private func yamlPythonExecutableCandidates(targetPath: String) -> [String] {
        let fileManager = FileManager.default
        let targetURL = URL(fileURLWithPath: targetPath)
        let targetDirectory = targetURL.deletingLastPathComponent()
        let candidates = [
            targetDirectory.appendingPathComponent("hermes-agent/venv/bin/python").path,
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".hermes/hermes-agent/venv/bin/python").path,
            "python3"
        ]

        var seen = Set<String>()
        return candidates.filter { candidate in
            guard seen.insert(candidate).inserted else { return false }
            return candidate == "python3" || fileManager.isExecutableFile(atPath: candidate)
        }
    }

    private func sanitizedSubprocessEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        environment.removeValue(forKey: "DYLD_INSERT_LIBRARIES")
        environment.removeValue(forKey: "DYLD_LIBRARY_PATH")
        environment.removeValue(forKey: "LD_PRELOAD")
        return environment
    }

    private func appendYAMLValueDiagnostics(
        _ value: String,
        lineNumber: Int,
        diagnostics: inout [CompanionValidationDiagnostic]
    ) {
        guard value.isEmpty == false else { return }

        var stack: [Character] = []
        var quote: Character?
        var escaped = false

        for character in value {
            if let activeQuote = quote {
                if escaped {
                    escaped = false
                    continue
                }
                if character == "\\" && activeQuote == "\"" {
                    escaped = true
                    continue
                }
                if character == activeQuote {
                    quote = nil
                }
                continue
            }

            if character == "\"" || character == "'" {
                quote = character
                continue
            }

            switch character {
            case "[":
                stack.append("]")
            case "{":
                stack.append("}")
            case "]", "}":
                if stack.popLast() != character {
                    diagnostics.append(yamlDiagnostic(lineNumber, "Unbalanced inline collection delimiter '\(character)' in YAML value."))
                    return
                }
            default:
                continue
            }
        }

        if quote != nil {
            diagnostics.append(yamlDiagnostic(lineNumber, "Unterminated quoted YAML scalar."))
        }
        if let expected = stack.last {
            diagnostics.append(yamlDiagnostic(lineNumber, "Unclosed inline YAML collection. Expected '\(expected)'."))
        }
    }

    private func firstUnquotedColon(in text: String) -> String.Index? {
        var quote: Character?
        var escaped = false

        for index in text.indices {
            let character = text[index]
            if let activeQuote = quote {
                if escaped {
                    escaped = false
                    continue
                }
                if character == "\\" && activeQuote == "\"" {
                    escaped = true
                    continue
                }
                if character == activeQuote {
                    quote = nil
                }
                continue
            }

            if character == "\"" || character == "'" {
                quote = character
                continue
            }
            if character == ":" {
                let nextIndex = text.index(after: index)
                if nextIndex == text.endIndex || text[nextIndex].isWhitespace {
                    return index
                }
            }
        }

        return nil
    }

    private func stripYAMLComment(from text: String) -> String {
        var quote: Character?
        var escaped = false
        var previous: Character?

        for index in text.indices {
            let character = text[index]
            if let activeQuote = quote {
                if escaped {
                    escaped = false
                } else if character == "\\" && activeQuote == "\"" {
                    escaped = true
                } else if character == activeQuote {
                    quote = nil
                }
                previous = character
                continue
            }

            if character == "\"" || character == "'" {
                quote = character
            } else if character == "#", previous == nil || previous?.isWhitespace == true {
                return String(text[..<index])
            }
            previous = character
        }

        return text
    }

    private func yamlDiagnostic(_ lineNumber: Int, _ message: String) -> CompanionValidationDiagnostic {
        CompanionValidationDiagnostic(
            id: UUID(),
            severity: .error,
            message: "Line \(lineNumber): \(message)",
            validator: "yamlParse"
        )
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
        let createdAt = Date()
        let timestamp = ISO8601DateFormatter().string(from: createdAt).replacingOccurrences(of: ":", with: "-")
        let canonicalTargetPath = Self.canonicalPath(targetPath)
        let targetBinding = Self.revision(for: Data(canonicalTargetPath.utf8)).prefix(16)
        var backupID: String
        var backupURL: URL
        repeat {
            backupID = "\(target.id)-\(targetBinding)-\(timestamp)-\(UUID().uuidString.lowercased())"
            backupURL = backupsDirectoryURL.appendingPathComponent("\(backupID).bak")
        } while backups.contains(where: { $0.id == backupID })
            || FileManager.default.fileExists(atPath: backupURL.path)

        do {
            try existingContent.write(to: backupURL, atomically: true, encoding: .utf8)
            backups.append(
                CompanionBackupRecord(
                    id: backupID,
                    targetID: target.id,
                    createdAt: createdAt,
                    path: backupURL.path,
                    targetPath: canonicalTargetPath
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

    private func uniqueTemporaryURL(for targetURL: URL, operation: String) -> URL {
        targetURL.deletingLastPathComponent().appendingPathComponent(
            ".\(targetURL.lastPathComponent).\(operation).\(UUID().uuidString).tmp"
        )
    }
}
