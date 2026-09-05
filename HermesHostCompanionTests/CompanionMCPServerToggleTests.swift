import Darwin
import Foundation
import XCTest
@testable import HermesHostCompanion

@MainActor
final class CompanionMCPServerToggleTests: XCTestCase {
    func testMCPServerTogglePayloadCarriesSelectedProfileWorkspaceAndDesiredState() throws {
        let payload = SetMCPServerEnabledPayload(
            workspacePath: "/tmp/hermes/profiles/research",
            name: "fixture",
            enabled: false
        )

        let decoded = try JSONDecoder().decode(
            SetMCPServerEnabledPayload.self,
            from: JSONEncoder().encode(payload)
        )
        XCTAssertEqual(decoded.workspacePath, "/tmp/hermes/profiles/research")
        XCTAssertEqual(decoded.name, "fixture")
        XCTAssertFalse(decoded.enabled)
    }

    func testMCPInventoryFixtureExposesCanonicalEnabledWithoutCredentials() throws {
        let fixture = Data(#"{"workspacePath":"/tmp/hermes","resolvedWorkspacePath":"/tmp/hermes","output":"Loaded selected Hermes profile.","servers":[{"id":"fixture","name":"fixture","transport":"Stdio","tools":"all","status":"disabled","enabled":false}]}"#.utf8)
        let decoded = try JSONDecoder().decode(ListMCPServersResult.self, from: fixture)

        XCTAssertFalse(try XCTUnwrap(decoded.servers.first).enabled)
        XCTAssertEqual(decoded.servers.first?.status, "disabled")
    }

    func testTogglePersistsOnlyCanonicalEnabledInSelectedProfileAndPreservesServerConfiguration() async throws {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .resolvingSymlinksInPath()
        let selected = root.appendingPathComponent("profiles/selected", isDirectory: true)
        let sibling = root.appendingPathComponent("profiles/sibling", isDirectory: true)
        let pythonPackage = root.appendingPathComponent("hermes-agent/hermes_cli", isDirectory: true)
        let pythonBin = root.appendingPathComponent("hermes-agent/venv/bin", isDirectory: true)
        for directory in [selected, sibling, pythonPackage, pythonBin] {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let previousHome = ProcessInfo.processInfo.environment["HERMES_HOME"]
        setenv("HERMES_HOME", root.path, 1)
        defer {
            if let previousHome { setenv("HERMES_HOME", previousHome, 1) } else { unsetenv("HERMES_HOME") }
            try? fileManager.removeItem(at: root)
        }

        try Data().write(to: root.appendingPathComponent("hermes-agent/hermes"))
        let launcher = pythonBin.appendingPathComponent("python")
        try "#!/bin/sh\nexec /usr/bin/python3 \"$@\"\n".write(to: launcher, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: launcher.path)
        try Data().write(to: pythonPackage.appendingPathComponent("__init__.py"))
        try Self.fixtureConfigModule.write(
            to: pythonPackage.appendingPathComponent("config.py"),
            atomically: true,
            encoding: .utf8
        )
        try Self.fixtureMCPConfigModule.write(
            to: pythonPackage.appendingPathComponent("mcp_config.py"),
            atomically: true,
            encoding: .utf8
        )
        try Self.fixtureMCPSecurityModule.write(
            to: pythonPackage.appendingPathComponent("mcp_security.py"),
            atomically: true,
            encoding: .utf8
        )

        let originalServer: [String: Any] = [
            "command": "fixture-command",
            "args": ["--fixture"],
            "enabled": true,
            "headers": ["Authorization": "Bearer fixture-secret-reference"],
            "tools": ["include": ["first", "second"]]
        ]
        let selectedConfig: [String: Any] = [
            "mcp_servers": ["fixture": originalServer],
            "model": ["default": "keep-me"]
        ]
        let siblingConfig: [String: Any] = [
            "mcp_servers": ["fixture": originalServer],
            "sibling": true
        ]
        try Self.writeJSON(selectedConfig, to: selected.appendingPathComponent("config.yaml"))
        try Self.writeJSON(siblingConfig, to: sibling.appendingPathComponent("config.yaml"))
        let siblingSnapshot = try Data(contentsOf: sibling.appendingPathComponent("config.yaml"))

        let result = try await CompanionMCPRegistry().setServerEnabled(
            SetMCPServerEnabledPayload(workspacePath: selected.path, name: "fixture", enabled: false)
        )

        XCTAssertEqual(result.resolvedWorkspacePath, selected.path)
        XCTAssertFalse(try XCTUnwrap(result.servers.first).enabled)
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(result), as: UTF8.self).contains("fixture-secret-reference"))
        let saved = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: selected.appendingPathComponent("config.yaml")))
                as? [String: Any]
        )
        let savedServers = try XCTUnwrap(saved["mcp_servers"] as? [String: Any])
        let savedServer = try XCTUnwrap(savedServers["fixture"] as? [String: Any])
        XCTAssertEqual(savedServer["enabled"] as? Bool, false)
        XCTAssertEqual(savedServer["command"] as? String, originalServer["command"] as? String)
        XCTAssertEqual(savedServer["args"] as? [String], originalServer["args"] as? [String])
        XCTAssertEqual(savedServer["headers"] as? [String: String], originalServer["headers"] as? [String: String])
        XCTAssertEqual(savedServer["tools"] as? [String: [String]], originalServer["tools"] as? [String: [String]])
        XCTAssertEqual((saved["model"] as? [String: String])?["default"], "keep-me")
        XCTAssertEqual(try Data(contentsOf: sibling.appendingPathComponent("config.yaml")), siblingSnapshot)
    }

    private static func writeJSON(_ object: [String: Any], to url: URL) throws {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]).write(to: url)
    }

    private static let fixtureConfigModule = #"""
import json, os
def _path(): return os.path.join(os.environ["HERMES_HOME"], "config.yaml")
def load_config():
    with open(_path(), "r", encoding="utf-8") as handle: return json.load(handle)
def save_config(config):
    with open(_path(), "w", encoding="utf-8") as handle: json.dump(config, handle, sort_keys=True)
"""#

    private static let fixtureMCPConfigModule = #"""
def _save_bearer_auth_token(name, token): return {"Authorization": "Bearer redacted-fixture"}
"""#

    private static let fixtureMCPSecurityModule = #"""
def validate_mcp_server_entry(name, entry): return []
"""#
}
