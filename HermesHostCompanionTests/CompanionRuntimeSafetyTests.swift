import Darwin
import Foundation
import XCTest
@testable import HermesHostCompanion

final class CompanionRuntimeSafetyTests: XCTestCase {
    private enum ProfileCommand {
        case remove
        case activate

        func run(registry: CompanionProfileRegistry, workspacePath: String) async throws {
            switch self {
            case .remove:
                _ = try await registry.remove(workspacePath: workspacePath, name: "selected")
            case .activate:
                _ = try await registry.activate(workspacePath: workspacePath, name: "selected")
            }
        }
    }

    private func fixture(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "model: {provider: auto}\n".write(to: root.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)
        try body(root)
    }

    private func transformToolsetFixture(_ content: String, action: String, enabled: Bool? = nil) async throws -> [String: Any] {
        let workspaces = CompanionWorkspaceSecurity.approvedHermesRoots(preferredWorkspacePath: nil)
        guard let workspace = workspaces.first(where: { CompanionWorkspaceSecurity.resolvedHermesCLIContext(from: $0.path) != nil }) else {
            throw XCTSkip("A Hermes CLI runtime with PyYAML is required for this host transformer fixture.")
        }
        var request: [String: Any] = ["action": action, "content": content]
        if action == "setTool" {
            request["key"] = "stt"
            request["enabled"] = try XCTUnwrap(enabled)
        }
        return try await CompanionRuntimeConfigSafety.transform(workspacePath: workspace.path, request: request)
    }

    private func assertProfileCommandRejectsSymlink(
        _ command: ProfileCommand,
        symlinkProfilesDirectory: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let fileManager = FileManager.default
        let container = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let workspace = container.appendingPathComponent("hermes", isDirectory: true)
        let profiles = workspace.appendingPathComponent("profiles", isDirectory: true)
        let outside = container.appendingPathComponent("outside", isDirectory: true)
        let escapedProfile = outside.appendingPathComponent("selected", isDirectory: true)
        let executableDirectory = workspace.appendingPathComponent("hermes-agent/venv/bin", isDirectory: true)
        let commandMarker = workspace.appendingPathComponent("hermes-agent/command-invoked")
        let oldHome = ProcessInfo.processInfo.environment["HERMES_HOME"]
        defer {
            if let oldHome { setenv("HERMES_HOME", oldHome, 1) } else { unsetenv("HERMES_HOME") }
            try? fileManager.removeItem(at: container)
        }

        try fileManager.createDirectory(at: executableDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: escapedProfile, withIntermediateDirectories: true)
        try "model: root\n".write(to: workspace.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)
        try "model: outside\n".write(to: escapedProfile.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)
        try Data().write(to: workspace.appendingPathComponent("hermes-agent/hermes"))
        let python = executableDirectory.appendingPathComponent("python")
        try "#!/bin/sh\ntouch \"\(commandMarker.path)\"\nexit 0\n".write(to: python, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: python.path)

        if symlinkProfilesDirectory {
            try fileManager.createSymbolicLink(at: profiles, withDestinationURL: outside)
        } else {
            try fileManager.createDirectory(at: profiles, withIntermediateDirectories: false)
            try fileManager.createSymbolicLink(
                at: profiles.appendingPathComponent("selected", isDirectory: true),
                withDestinationURL: escapedProfile
            )
        }
        setenv("HERMES_HOME", workspace.path, 1)

        do {
            try await command.run(registry: CompanionProfileRegistry(), workspacePath: workspace.path)
            XCTFail("A symlinked profile must be rejected before invoking Hermes CLI.", file: file, line: line)
        } catch CompanionProfileRegistryError.invalidProfileName {
            // Expected.
        } catch {
            XCTFail("Expected invalidProfileName, got \(error).", file: file, line: line)
        }
        XCTAssertFalse(fileManager.fileExists(atPath: commandMarker.path), file: file, line: line)
        XCTAssertEqual(
            try String(contentsOf: escapedProfile.appendingPathComponent("config.yaml"), encoding: .utf8),
            "model: outside\n",
            file: file,
            line: line
        )
    }

    func testCredentialPoolEndpointRejectsBeforeTouchingNativeAuthFixture() throws {
        try fixture { root in
            let auth = root.appendingPathComponent("auth.json")
            let original = Data(#"{"credential_pool":{"anthropic":[{"id":"opaque-1","access_token":"fixture-access","refresh_token":"fixture-refresh","auth_type":"oauth","priority":2,"source":"manual","last_status":"exhausted","future_field":{"keep":true}}],"openrouter":[{"id":"opaque-2","access_token":"fixture-other"}]},"providers":{"keep":"fixture-oauth"}}"#.utf8)
            try original.write(to: auth)
            XCTAssertThrowsError(try CompanionProviderRegistry().setCredentialPool(workspacePath: root.path, provider: "anthropic", entries: [])) { error in
                guard case CompanionProviderRegistryError.unsupportedCredentialPoolWrite = error else { return XCTFail("Wrong error: \(error)") }
            }
            XCTAssertEqual(try Data(contentsOf: auth), original)
        }
        // Reject unsupported controls even if no workspace can be resolved.
        XCTAssertThrowsError(try CompanionProviderRegistry().setCredentialPool(workspacePath: "/does-not-exist", provider: "openrouter", entries: [])) { error in
            guard case CompanionProviderRegistryError.unsupportedCredentialPoolWrite = error else { return XCTFail("Wrong error: \(error)") }
        }
    }

    func testProviderLoadSetAndRemoveResponsesContainOnlyEnvPresence() throws {
        try fixture { root in
            let env = root.appendingPathComponent(".env")
            try "OPENAI_API_KEY=fixture-old-secret\nPRIVATE_UNRELATED=fixture-private\nBROWSERBASE_PROJECT_ID=fixture-project\n".write(to: env, atomically: true, encoding: .utf8)
            let registry = CompanionProviderRegistry()
            let load = try registry.load(workspacePath: root.path)
            XCTAssertEqual(load.env, ["OPENAI_API_KEY": "[configured]", "BROWSERBASE_PROJECT_ID": "[configured]"])
            let saved = try registry.setEnv(workspacePath: root.path, key: "OPENAI_API_KEY", value: "fixture-new-secret")
            XCTAssertEqual(saved.value, "[configured]")
            let removed = try registry.removeEnv(workspacePath: root.path, key: "OPENAI_API_KEY")
            XCTAssertNil(removed.env["OPENAI_API_KEY"])
            XCTAssertEqual(removed.env["BROWSERBASE_PROJECT_ID"], "[configured]")
            for response in [try JSONEncoder().encode(load), try JSONEncoder().encode(saved), try JSONEncoder().encode(removed)] {
                XCTAssertFalse(String(decoding: response, as: UTF8.self).contains("fixture-"))
            }
            XCTAssertTrue(try String(contentsOf: env, encoding: .utf8).contains("PRIVATE_UNRELATED=fixture-private"))
        }
    }

    func testPresenceParserFiltersKeysAndNeverRevealsTextValues() {
        let metadata = CompanionRuntimeConfigSafety.envMetadata(content: """
        export TOKEN="fixture-secret"
        ADDRESS=fixture@example.test
        EMPTY=''
        TOKEN='replacement-secret'
        UNRELATED=private
        # TOKEN=disabled
        """, allowedKey: { ["TOKEN", "ADDRESS", "EMPTY"].contains($0) })
        XCTAssertEqual(metadata, ["TOKEN": "[configured]", "ADDRESS": "[configured]"])
    }

    func testBlankPresenceAndMultilineReplacementsAreRejected() {
        for value in ["", "  ", "[configured]", "secret\nINJECTED=yes", "secret\rINJECTED=yes", "secret\0"] {
            XCTAssertThrowsError(try CompanionRuntimeConfigSafety.validateEnvReplacement(value))
        }
        XCTAssertNoThrow(try CompanionRuntimeConfigSafety.validateEnvReplacement("fixture-secret"))
    }

    func testProfileOptionalFilesArePreservedForEitherToggleValue() throws {
        try fixture { root in
            for name in [".env", "SOUL.md"] {
                let file = root.appendingPathComponent(name)
                let original = Data("fixture-private-content".utf8)
                try original.write(to: file)
                for enabled in [false, true] {
                    try CompanionProfileRegistry.createOptionalFileIfMissing(fileName: name, enabled: enabled, profileURL: root)
                    XCTAssertEqual(try Data(contentsOf: file), original)
                }
            }
        }
    }

    func testProfileCreateOptionalFilesAreEmptyNotRootClones() throws {
        try fixture { root in
            let profile = root.appendingPathComponent("profiles/new")
            try FileManager.default.createDirectory(at: profile, withIntermediateDirectories: true)
            for name in [".env", "SOUL.md"] {
                let original = Data("fixture-root-private-content".utf8)
                try original.write(to: root.appendingPathComponent(name))
                try CompanionProfileRegistry.createOptionalFileIfMissing(fileName: name, enabled: false, profileURL: profile)
                XCTAssertFalse(FileManager.default.fileExists(atPath: profile.appendingPathComponent(name).path))
                try CompanionProfileRegistry.createOptionalFileIfMissing(fileName: name, enabled: true, profileURL: profile)
                XCTAssertEqual(try Data(contentsOf: profile.appendingPathComponent(name)), Data())
                XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(name)), original)
            }
        }
    }

    func testProfileCreateDoesNotFollowDanglingOptionalFileSymlinks() throws {
        try fixture { root in
            let target = root.appendingPathComponent("must-not-create")
            try FileManager.default.createSymbolicLink(at: root.appendingPathComponent(".env"), withDestinationURL: target)
            try CompanionProfileRegistry.createOptionalFileIfMissing(fileName: ".env", enabled: true, profileURL: root)
            XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
        }
    }

    func testConfigReadDoesNotTreatInvalidUTF8AsEmpty() throws {
        try fixture { root in
            let file = root.appendingPathComponent("config.yaml")
            try Data([0xFF, 0xFE, 0xFF]).write(to: file)
            XCTAssertThrowsError(try CompanionRuntimeConfigSafety.read(file))
            XCTAssertEqual(try Data(contentsOf: file), Data([0xFF, 0xFE, 0xFF]))
        }
    }

    @MainActor
    func testYAMLValidationDoesNotBlockMainActor() async throws {
        let container = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let targetDirectory = container.appendingPathComponent("target", isDirectory: true)
        let storage = container.appendingPathComponent("registry", isDirectory: true)
        let python = targetDirectory.appendingPathComponent("hermes-agent/venv/bin/python")
        defer { try? FileManager.default.removeItem(at: container) }
        try FileManager.default.createDirectory(at: python.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: storage, withIntermediateDirectories: true)
        try "#!/bin/sh\nsleep 0.5\nprintf '{\"ok\": true}\\n'\n".write(to: python, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: python.path)

        let target = CompanionTargetRecord(
            id: "yaml-fixture",
            displayName: "YAML Fixture",
            path: targetDirectory.appendingPathComponent("config.yaml").path,
            format: .yaml,
            validators: [.yamlParse],
            serviceID: nil,
            restartPolicy: .manual
        )
        try JSONEncoder().encode(CompanionTargetRegistryDocument(targets: [target]))
            .write(to: storage.appendingPathComponent("targets.json"), options: .atomic)
        let registry = CompanionTargetRegistry(storageDirectoryURL: storage)

        var heartbeatFired = false
        let heartbeat = Task { @MainActor in
            try await Task.sleep(nanoseconds: 50_000_000)
            heartbeatFired = true
        }

        let result = try await registry.validateTarget(id: target.id, proposedContent: "model: fixture\n")

        XCTAssertTrue(result.valid)
        XCTAssertTrue(heartbeatFired, "YAML validation blocked the MainActor while the parser subprocess ran.")
        _ = await heartbeat.result
    }

    func testTargetSelectionIsRequestScopedAndBackupRestoresOriginalProfile() async throws {
        let container = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let workspace = container.appendingPathComponent("hermes", isDirectory: true)
        let storage = container.appendingPathComponent("registry", isDirectory: true)
        let profiles = workspace.appendingPathComponent("profiles", isDirectory: true)
        let first = profiles.appendingPathComponent("first", isDirectory: true)
        let second = profiles.appendingPathComponent("second", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: container) }
        try FileManager.default.createDirectory(at: workspace.appendingPathComponent("skills"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
        try "model: original-first\n".write(to: first.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)
        try "model: original-second\n".write(to: second.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)

        let registry = CompanionTargetRegistry(storageDirectoryURL: storage)
        let firstRead = try registry.readTarget(id: "hermes-config", workspacePath: workspace.path, profileName: "first")
        let write = try await registry.writeTarget(
            id: "hermes-config",
            expectedRevision: firstRead.revision,
            content: "model: changed-first\n",
            createBackup: true,
            workspacePath: workspace.path,
            profileName: "first"
        )
        _ = try registry.readTarget(id: "hermes-config", workspacePath: workspace.path, profileName: "second")
        let unscopedPath = try XCTUnwrap(registry.listTargets().first(where: { $0.id == "hermes-config" })?.path)
        XCTAssertNotEqual(unscopedPath, second.appendingPathComponent("config.yaml").path)

        _ = try await registry.restoreBackup(id: try XCTUnwrap(write.backupID))
        XCTAssertEqual(try String(contentsOf: first.appendingPathComponent("config.yaml"), encoding: .utf8), "model: original-first\n")
        XCTAssertEqual(try String(contentsOf: second.appendingPathComponent("config.yaml"), encoding: .utf8), "model: original-second\n")
    }

    func testSymlinkedProfilesDirectoryCannotEscapeWorkspace() throws {
        let container = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let workspace = container.appendingPathComponent("hermes", isDirectory: true)
        let outside = container.appendingPathComponent("outside", isDirectory: true)
        let escapedProfile = outside.appendingPathComponent("selected", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: container) }
        try FileManager.default.createDirectory(at: workspace, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: escapedProfile, withIntermediateDirectories: true)
        try "model: root\n".write(to: workspace.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)
        try "model: outside\n".write(to: escapedProfile.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)
        try FileManager.default.createSymbolicLink(
            at: workspace.appendingPathComponent("profiles", isDirectory: true),
            withDestinationURL: outside
        )

        XCTAssertNil(CompanionWorkspaceSecurity.resolvedProfileURL(workspaceURL: workspace, profileName: "selected"))
        XCTAssertThrowsError(
            try CompanionProfileRegistry().edit(
                workspacePath: workspace.path,
                originalName: "selected",
                name: "selected",
                provider: "auto",
                model: "fixture",
                baseUrl: "",
                createEnv: false,
                createSoul: false
            )
        )
        XCTAssertEqual(try String(contentsOf: escapedProfile.appendingPathComponent("config.yaml"), encoding: .utf8), "model: outside\n")
    }

    func testProfileDeleteRejectsSymlinkedProfilesDirectoryAndNamedProfile() async throws {
        try await assertProfileCommandRejectsSymlink(.remove, symlinkProfilesDirectory: true)
        try await assertProfileCommandRejectsSymlink(.remove, symlinkProfilesDirectory: false)
    }

    func testProfileActivateRejectsSymlinkedProfilesDirectoryAndNamedProfile() async throws {
        try await assertProfileCommandRejectsSymlink(.activate, symlinkProfilesDirectory: true)
        try await assertProfileCommandRejectsSymlink(.activate, symlinkProfilesDirectory: false)
    }

    func testLegacyHermesBackupWithoutTargetPathCannotRestoreIntoPersistedSelectedProfile() async throws {
        let container = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let workspace = container.appendingPathComponent("hermes", isDirectory: true)
        let selected = workspace.appendingPathComponent("profiles/selected", isDirectory: true)
        let sibling = workspace.appendingPathComponent("profiles/sibling", isDirectory: true)
        let storage = container.appendingPathComponent("registry", isDirectory: true)
        let backupDirectory = storage.appendingPathComponent("backups", isDirectory: true)
        let backupID = "hermes-config-legacy"
        let backupURL = backupDirectory.appendingPathComponent("\(backupID).bak")
        defer { try? FileManager.default.removeItem(at: container) }
        try FileManager.default.createDirectory(at: workspace.appendingPathComponent("skills"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: selected, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        try "model: selected-current\n".write(to: selected.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)
        try "model: sibling-current\n".write(to: sibling.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)
        try "model: legacy\n".write(to: backupURL, atomically: true, encoding: .utf8)

        let target = CompanionTargetRecord(
            id: "hermes-config",
            displayName: "Hermes Config",
            path: selected.appendingPathComponent("config.yaml").path,
            format: .yaml,
            validators: [.yamlParse],
            serviceID: "hermesd",
            restartPolicy: .manual
        )
        try JSONEncoder().encode(CompanionTargetRegistryDocument(targets: [target]))
            .write(to: storage.appendingPathComponent("targets.json"), options: .atomic)
        let legacyBackup = CompanionBackupRecord(
            id: backupID,
            targetID: "hermes-config",
            createdAt: Date(),
            path: backupURL.path,
            targetPath: nil
        )
        try JSONEncoder().encode([legacyBackup])
            .write(to: storage.appendingPathComponent("backups.json"), options: .atomic)

        let registry = CompanionTargetRegistry(storageDirectoryURL: storage)
        let migratedBackups = try JSONDecoder().decode(
            [CompanionBackupRecord].self,
            from: Data(contentsOf: storage.appendingPathComponent("backups.json"))
        )
        XCTAssertNil(try XCTUnwrap(migratedBackups.first).targetPath)

        do {
            _ = try await registry.restoreBackup(id: backupID)
            XCTFail("An unbound legacy profile backup must be rejected instead of restoring to the last persisted profile.")
        } catch {
            guard let registryError = error as? CompanionTargetRegistryError,
                  case .backupTargetUnavailable(let rejectedID) = registryError else {
                return XCTFail("Wrong error: \(error)")
            }
            XCTAssertEqual(rejectedID, backupID)
        }
        XCTAssertEqual(try String(contentsOf: selected.appendingPathComponent("config.yaml"), encoding: .utf8), "model: selected-current\n")
        XCTAssertEqual(try String(contentsOf: sibling.appendingPathComponent("config.yaml"), encoding: .utf8), "model: sibling-current\n")
    }

    func testLegacyStaticTargetBackupStillRestoresWhenAssociationIsUnambiguous() async throws {
        let container = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = container.appendingPathComponent("registry", isDirectory: true)
        let backupDirectory = storage.appendingPathComponent("backups", isDirectory: true)
        let targetURL = container.appendingPathComponent("target/settings.txt")
        let backupID = "static-target-legacy"
        let backupURL = backupDirectory.appendingPathComponent("\(backupID).bak")
        defer { try? FileManager.default.removeItem(at: container) }
        try FileManager.default.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        try "current\n".write(to: targetURL, atomically: true, encoding: .utf8)
        try "legacy\n".write(to: backupURL, atomically: true, encoding: .utf8)

        let target = CompanionTargetRecord(
            id: "static-target",
            displayName: "Static Target",
            path: targetURL.path,
            format: .text,
            validators: [],
            serviceID: nil,
            restartPolicy: .manual
        )
        try JSONEncoder().encode(CompanionTargetRegistryDocument(targets: [target]))
            .write(to: storage.appendingPathComponent("targets.json"), options: .atomic)
        try JSONEncoder().encode([
            CompanionBackupRecord(
                id: backupID,
                targetID: target.id,
                createdAt: Date(),
                path: backupURL.path,
                targetPath: nil
            )
        ]).write(to: storage.appendingPathComponent("backups.json"), options: .atomic)

        let registry = CompanionTargetRegistry(storageDirectoryURL: storage)
        _ = try await registry.restoreBackup(id: backupID)

        XCTAssertEqual(try String(contentsOf: targetURL, encoding: .utf8), "legacy\n")
    }

    func testRapidProfileBackupsHaveUniqueTargetBoundIDsAndFiles() async throws {
        let container = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let workspace = container.appendingPathComponent("hermes", isDirectory: true)
        let storage = container.appendingPathComponent("registry", isDirectory: true)
        let profiles = ["first", "second"]
        defer { try? FileManager.default.removeItem(at: container) }
        try FileManager.default.createDirectory(at: workspace.appendingPathComponent("skills"), withIntermediateDirectories: true)

        for profile in profiles {
            let profileURL = workspace.appendingPathComponent("profiles/\(profile)", isDirectory: true)
            let python = profileURL.appendingPathComponent("hermes-agent/venv/bin/python")
            try FileManager.default.createDirectory(at: python.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "model: original-\(profile)\n".write(to: profileURL.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)
            try "#!/bin/sh\nprintf '{\"ok\": true}\\n'\n".write(to: python, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: python.path)
        }

        let registry = CompanionTargetRegistry(storageDirectoryURL: storage)
        var backupIDs: [String] = []
        for index in 0..<12 {
            let profile = profiles[index % profiles.count]
            let current = try registry.readTarget(id: "hermes-config", workspacePath: workspace.path, profileName: profile)
            let result = try await registry.writeTarget(
                id: "hermes-config",
                expectedRevision: current.revision,
                content: "model: changed-\(profile)-\(index)\n",
                createBackup: true,
                workspacePath: workspace.path,
                profileName: profile
            )
            backupIDs.append(try XCTUnwrap(result.backupID))
        }

        let summaries = registry.listBackups(targetID: "hermes-config").backups
        XCTAssertEqual(Set(backupIDs).count, backupIDs.count)
        XCTAssertEqual(Set(summaries.map(\.path)).count, summaries.count)

        _ = try await registry.restoreBackup(id: backupIDs[0])
        XCTAssertEqual(
            try String(contentsOf: workspace.appendingPathComponent("profiles/first/config.yaml"), encoding: .utf8),
            "model: original-first\n"
        )
        XCTAssertEqual(
            try String(contentsOf: workspace.appendingPathComponent("profiles/second/config.yaml"), encoding: .utf8),
            "model: changed-second-11\n"
        )
        _ = try await registry.restoreBackup(id: backupIDs[1])
        XCTAssertEqual(
            try String(contentsOf: workspace.appendingPathComponent("profiles/second/config.yaml"), encoding: .utf8),
            "model: original-second\n"
        )
    }

    func testWriteRechecksRevisionAfterAsyncValidation() async throws {
        let container = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = container.appendingPathComponent("registry", isDirectory: true)
        let targetDirectory = container.appendingPathComponent("target", isDirectory: true)
        let targetURL = targetDirectory.appendingPathComponent("config.yaml")
        let python = targetDirectory.appendingPathComponent("hermes-agent/venv/bin/python")
        let validationStarted = container.appendingPathComponent("validation-started")
        let releaseValidation = container.appendingPathComponent("release-validation")
        defer { try? FileManager.default.removeItem(at: container) }
        try FileManager.default.createDirectory(at: python.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: storage, withIntermediateDirectories: true)
        try "model: original\n".write(to: targetURL, atomically: true, encoding: .utf8)
        try """
        #!/bin/sh
        /usr/bin/touch '\(validationStarted.path)'
        while [ ! -e '\(releaseValidation.path)' ]; do /bin/sleep 0.01; done
        printf '{"ok": true}\\n'
        """.write(to: python, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: python.path)

        let target = CompanionTargetRecord(
            id: "async-yaml-target",
            displayName: "Async YAML Target",
            path: targetURL.path,
            format: .yaml,
            validators: [.yamlParse],
            serviceID: nil,
            restartPolicy: .manual
        )
        try JSONEncoder().encode(CompanionTargetRegistryDocument(targets: [target]))
            .write(to: storage.appendingPathComponent("targets.json"), options: .atomic)
        let registry = CompanionTargetRegistry(storageDirectoryURL: storage)
        let original = try registry.readTarget(id: target.id)

        let write = Task {
            try await registry.writeTarget(
                id: target.id,
                expectedRevision: original.revision,
                content: "model: proposed\n",
                createBackup: false
            )
        }
        var validationDidStart = false
        for _ in 0..<200 {
            if FileManager.default.fileExists(atPath: validationStarted.path) {
                validationDidStart = true
                break
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        XCTAssertTrue(validationDidStart, "The controlled validator did not start.")
        try "model: external-change\n".write(to: targetURL, atomically: true, encoding: .utf8)
        try Data().write(to: releaseValidation)

        do {
            _ = try await write.value
            XCTFail("A stale write must fail after validation instead of replacing a newer revision.")
        } catch {
            guard let registryError = error as? CompanionTargetRegistryError,
                  case .revisionMismatch = registryError else {
                return XCTFail("Wrong error: \(error)")
            }
        }
        XCTAssertEqual(try String(contentsOf: targetURL, encoding: .utf8), "model: external-change\n")
    }

    func testWriteDoesNotReuseFixedTemporaryFilename() async throws {
        let container = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storage = container.appendingPathComponent("registry", isDirectory: true)
        let targetURL = container.appendingPathComponent("target/settings.txt")
        defer { try? FileManager.default.removeItem(at: container) }
        try FileManager.default.createDirectory(at: targetURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: storage, withIntermediateDirectories: true)
        try "original\n".write(to: targetURL, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(
            at: targetURL.deletingLastPathComponent().appendingPathComponent(".settings.txt.tmp"),
            withIntermediateDirectories: false
        )

        let target = CompanionTargetRecord(
            id: "temporary-file-target",
            displayName: "Temporary File Target",
            path: targetURL.path,
            format: .text,
            validators: [],
            serviceID: nil,
            restartPolicy: .manual
        )
        try JSONEncoder().encode(CompanionTargetRegistryDocument(targets: [target]))
            .write(to: storage.appendingPathComponent("targets.json"), options: .atomic)
        let registry = CompanionTargetRegistry(storageDirectoryURL: storage)
        let original = try registry.readTarget(id: target.id)

        _ = try await registry.writeTarget(
            id: target.id,
            expectedRevision: original.revision,
            content: "updated\n",
            createBackup: false
        )

        XCTAssertEqual(try String(contentsOf: targetURL, encoding: .utf8), "updated\n")
    }

    func testSpeechToTextUsesConfigOnlyToggleAndPreservesOtherYAML() async throws {
        let fixture = """
        platform_toolsets:
          cli: [web, terminal]
        stt:
          enabled: false
          provider: local
        gateway:
          api:
            port: 8642
        unrelated:
          retained: [one, two]
        """

        let listedDisabled = try await transformToolsetFixture(fixture, action: "listTools")
        XCTAssertEqual(listedDisabled["enabledToolsets"] as? [String], ["web", "terminal"])
        XCTAssertEqual(listedDisabled["configOnlyEnabledToolsets"] as? [String], [])
        let disabledRows = CompanionToolsetRegistry.makeToolsetInfos(
            enabledToolsets: try XCTUnwrap(listedDisabled["enabledToolsets"] as? [String]),
            configOnlyEnabledToolsets: try XCTUnwrap(listedDisabled["configOnlyEnabledToolsets"] as? [String])
        )
        XCTAssertEqual(disabledRows.first(where: { $0.key == "stt" })?.enabled, false)

        let enabled = try await transformToolsetFixture(fixture, action: "setTool", enabled: true)
        XCTAssertEqual(enabled["enabledToolsets"] as? [String], ["web", "terminal"])
        XCTAssertEqual(enabled["configOnlyEnabledToolsets"] as? [String], ["stt"])
        let enabledRows = CompanionToolsetRegistry.makeToolsetInfos(
            enabledToolsets: try XCTUnwrap(enabled["enabledToolsets"] as? [String]),
            configOnlyEnabledToolsets: try XCTUnwrap(enabled["configOnlyEnabledToolsets"] as? [String])
        )
        XCTAssertEqual(enabledRows.first(where: { $0.key == "stt" })?.enabled, true)
        let enabledYAML = try XCTUnwrap(enabled["content"] as? String)
        XCTAssertFalse(enabledYAML.contains("- stt"))
        XCTAssertTrue(enabledYAML.contains("provider: local"))
        XCTAssertTrue(enabledYAML.contains("port: 8642"))
        XCTAssertTrue(enabledYAML.contains("retained:"))

        let disabled = try await transformToolsetFixture(enabledYAML, action: "setTool", enabled: false)
        XCTAssertEqual(disabled["enabledToolsets"] as? [String], ["web", "terminal"])
        XCTAssertEqual(disabled["configOnlyEnabledToolsets"] as? [String], [])
        let disabledYAML = try XCTUnwrap(disabled["content"] as? String)
        XCTAssertFalse(disabledYAML.contains("- stt"))
        XCTAssertTrue(disabledYAML.contains("provider: local"))
        XCTAssertTrue(disabledYAML.contains("port: 8642"))
        XCTAssertTrue(disabledYAML.contains("retained:"))
    }
}
