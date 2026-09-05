import Foundation
import XCTest
@testable import HermesHostCompanion

final class CompanionRuntimeSafetyTests: XCTestCase {
    private func fixture(_ body: (URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "model: {provider: auto}\n".write(to: root.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)
        try body(root)
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
}
