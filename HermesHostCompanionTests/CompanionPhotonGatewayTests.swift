import Darwin
import Foundation
import XCTest
@testable import HermesHostCompanion

final class CompanionPhotonGatewayTests: XCTestCase {
    private let keys = ["PHOTON_PROJECT_ID", "PHOTON_PROJECT_SECRET", "PHOTON_ALLOWED_USERS",
                        "PHOTON_HOME_CHANNEL", "PHOTON_HOME_CHANNEL_NAME", "PHOTON_SIDECAR_PORT",
                        "PHOTON_REQUIRE_MENTION", "PHOTON_MENTION_PATTERNS"]

    /// Only the Python executable is reused; -I imports PyYAML, never Hermes.
    /// Every config/env/auth path is under this temporary, approved fixture root.
    private func fixture(_ body: (URL, URL, CompanionGatewayRegistry) throws -> Void) throws {
        let fm = FileManager.default
        let python = ProcessInfo.processInfo.environment["HERMES_TEST_PYTHON"]
            ?? NSHomeDirectory() + "/.hermes/hermes-agent/venv/bin/python"
        guard fm.isExecutableFile(atPath: python) else { throw XCTSkip("Set HERMES_TEST_PYTHON to a Python with PyYAML") }
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString).resolvingSymlinksInPath()
        let selected = root.appendingPathComponent("profiles/selected")
        let sibling = root.appendingPathComponent("profiles/sibling")
        for directory in [selected, sibling, root.appendingPathComponent("hermes-agent/venv/bin")] {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let oldHome = ProcessInfo.processInfo.environment["HERMES_HOME"]
        setenv("HERMES_HOME", root.path, 1)
        defer {
            if let oldHome { setenv("HERMES_HOME", oldHome, 1) } else { unsetenv("HERMES_HOME") }
            try? fm.removeItem(at: root)
        }
        try Data().write(to: root.appendingPathComponent("hermes-agent/hermes"))
        // A symlink into a venv loses pyvenv.cfg discovery from this fixture path.
        // Exec the original interpreter so its PyYAML site-packages remain available.
        let launcher = root.appendingPathComponent("hermes-agent/venv/bin/python")
        let quotedPython = "'" + python.replacingOccurrences(of: "'", with: "'\\''") + "'"
        try "#!/bin/sh\nexec \(quotedPython) \"$@\"\n".write(to: launcher, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: launcher.path)
        for directory in [root, selected, sibling] {
            try "gateway:\n  platforms:\n    photon:\n      enabled: true\n      require_mention: true\n      extra: {keep: [1, true]}\nmodel: {default: fixture}\n".write(to: directory.appendingPathComponent("config.yaml"), atomically: true, encoding: .utf8)
            try "PHOTON_PROJECT_SECRET=fixture-original\nPRIVATE_UNRELATED=fixture-private\n".write(to: directory.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
            try "fixture-auth-untouched".write(to: directory.appendingPathComponent("auth.json"), atomically: true, encoding: .utf8)
        }
        let registry = CompanionGatewayRegistry { args, workspace, profile, _ in
            XCTAssertEqual(workspace.path, root.path)
            XCTAssertTrue(CompanionWorkspaceSecurity.isDescendant(profile, of: root))
            XCTAssertEqual(args, ["status"], "Fixture must never request a lifecycle action")
            return (true, "not running", nil)
        }
        try body(root, selected, registry)
    }

    func testCatalogListsPhotonWithAllowlistedWriteOnlyFields() throws {
        try fixture { root, _, registry in
            let loaded = try registry.config(workspacePath: root.path, profileName: "selected")
            let photon = try XCTUnwrap(loaded.platforms.first { $0.key == "photon" })
            XCTAssertEqual(photon.fields, keys)
            XCTAssertEqual(loaded.platforms.filter { $0.key == "photon" }.count, 1)
            XCTAssertTrue(loaded.platforms.contains { $0.key == "bluebubbles" })
            XCTAssertEqual(loaded.fields.first { $0.key == "PHOTON_PROJECT_SECRET" }?.type, "password")
            for key in keys {
                XCTAssertNotNil(loaded.fields.first { $0.key == key })
                let result = try registry.setEnv(workspacePath: root.path, profileName: "selected", key: key, value: "fixture-replacement")
                XCTAssertEqual(result.value, "[configured]")
                XCTAssertFalse(String(decoding: try JSONEncoder().encode(result), as: UTF8.self).contains("fixture-"))
            }
            XCTAssertEqual(loaded.env, ["PHOTON_PROJECT_SECRET": "[configured]"])
            XCTAssertFalse(String(decoding: try JSONEncoder().encode(loaded), as: UTF8.self).contains("fixture-original"))
            XCTAssertThrowsError(try registry.setEnv(workspacePath: root.path, profileName: "selected", key: "PHOTON_API_KEY", value: "fixture"))
            XCTAssertThrowsError(try registry.setEnv(workspacePath: root.path, profileName: "selected", key: "PHOTON_PROJECT_SECRET", value: "[configured]"))
        }
    }

    func testToggleAndSecretPersistenceAreRestrictedToSelectedProfile() throws {
        try fixture { root, selected, registry in
            let untouched = [root, root.appendingPathComponent("profiles/sibling")].flatMap { directory in
                ["config.yaml", ".env", "auth.json"].map { directory.appendingPathComponent($0) }
            } + [selected.appendingPathComponent("auth.json")]
            let snapshots = try untouched.map { try Data(contentsOf: $0) }
            for enabled in [false, true, false] {
                let result = try registry.setPlatformEnabled(workspacePath: root.path, profileName: "selected", platform: "photon", enabled: enabled)
                XCTAssertEqual(result.profilePath, selected.path)
                XCTAssertEqual(result.platformEnabled["photon"], enabled)
                let reloaded = try registry.config(workspacePath: root.path, profileName: "selected")
                XCTAssertEqual(reloaded.platformEnabled["photon"], enabled)
                let yaml = try String(contentsOf: selected.appendingPathComponent("config.yaml"), encoding: .utf8)
                XCTAssertTrue(yaml.contains("require_mention: true"))
                XCTAssertTrue(yaml.contains("default: fixture"))
                XCTAssertTrue(yaml.contains("keep:"))
                XCTAssertFalse(yaml.hasPrefix("platforms:"))
            }
            let replacement = "fixture-" + String(repeating: "x", count: 24)
            _ = try registry.setEnv(workspacePath: root.path, profileName: "selected", key: "PHOTON_PROJECT_SECRET", value: replacement)
            let saved = try String(contentsOf: selected.appendingPathComponent(".env"), encoding: .utf8)
            XCTAssertTrue(saved.contains("PHOTON_PROJECT_SECRET=\(replacement)"))
            XCTAssertTrue(saved.contains("PRIVATE_UNRELATED=fixture-private"))
            for (url, original) in zip(untouched, snapshots) { XCTAssertEqual(try Data(contentsOf: url), original) }
        }
    }

    func testTraversalAndSymlinkProfilesCannotWriteOutsideScope() throws {
        try fixture { root, selected, registry in
            let original = try Data(contentsOf: selected.appendingPathComponent(".env"))
            try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("profiles/escape"), withDestinationURL: root)
            for name in ["../selected", "selected/../../", "escape", "missing"] {
                XCTAssertThrowsError(try registry.setEnv(workspacePath: root.path, profileName: name, key: "PHOTON_PROJECT_SECRET", value: "fixture-new"))
                XCTAssertThrowsError(try registry.setPlatformEnabled(workspacePath: root.path, profileName: name, platform: "photon", enabled: false))
            }
            XCTAssertEqual(try Data(contentsOf: selected.appendingPathComponent(".env")), original)
        }
    }

    func testMalformedYAMLIsNeverReplacedByToggle() throws {
        try fixture { root, selected, registry in
            let config = selected.appendingPathComponent("config.yaml")
            for text in ["gateway: [broken", "gateway: {platforms: {photon: false}}", "platforms: &alias {photon: {enabled: true}}", "platforms: {}\nplatforms: {}"] {
                try text.write(to: config, atomically: true, encoding: .utf8)
                XCTAssertThrowsError(try registry.setPlatformEnabled(workspacePath: root.path, profileName: "selected", platform: "photon", enabled: false))
                XCTAssertEqual(try String(contentsOf: config, encoding: .utf8), text)
            }
        }
    }
}
