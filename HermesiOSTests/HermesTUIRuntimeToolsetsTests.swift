import XCTest
@testable import HermesiOS

@MainActor
final class HermesTUIRuntimeToolsetsTests: XCTestCase {
    private func profiles(_ values: [(String, String)]) -> JSONValue {
        .object(["profiles": .array(values.map { name, path in
            .object([
                "name": .string(name), "path": .string(path), "display_name": .string(name),
                "provider": .string("openai"), "model": .string("gpt-5")
            ])
        })])
    }

    private func toolsets(enabled: Bool = true) -> JSONValue {
        .object(["toolsets": .array([
            .object([
                "name": .string("terminal"), "description": .string("Run local commands"),
                "tool_count": .number(3), "enabled": .bool(enabled)
            ])
        ])])
    }

    private func assertThrows(_ operation: () async throws -> Void) async {
        do {
            try await operation()
            XCTFail("Expected operation to throw")
        } catch {
            // Expected: each caller verifies any additional safety invariant.
        }
    }

    func testRuntimeToolsetsAllowsDefaultWhenLaunchHomeMatchesAuthenticatedPath() async throws {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        store.requestOverride = { method, _ in
            switch method {
            case "config.get": return .object(["home": .string("/profiles/default")])
            case "profiles.list": return self.profiles([("default", "/profiles/default")])
            case "toolsets.list": return self.toolsets()
            default: return .object([:])
            }
        }

        let toolsets = try await store.runtimeToolsets(profileName: "default", authenticatedProfilePath: "/profiles/default")

        XCTAssertEqual(toolsets.map(\.name), ["terminal"])
        XCTAssertEqual(toolsets.first?.toolCount, 3)
        XCTAssertTrue(toolsets.first?.enabled == true)
    }

    func testRuntimeToolsetsAllowsNamedGatewayWhenLaunchHomeMatchesAuthenticatedPath() async throws {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        store.requestOverride = { method, _ in
            switch method {
            case "config.get": return .object(["home": .string("/profiles/research")])
            case "profiles.list": return self.profiles([("default", "/profiles/default"), ("research", "/profiles/research")])
            case "toolsets.list": return self.toolsets()
            default: return .object([:])
            }
        }

        do {
            _ = try await store.runtimeToolsets(profileName: "research", authenticatedProfilePath: "/profiles/research")
        } catch {
            XCTFail("Expected named launch-profile match: \(error)")
        }
    }

    func testSelectedDefaultRejectsNamedGatewayMismatchWithoutToolsetRPCOrChatCreation() async throws {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        var requests: [String] = []
        store.requestOverride = { method, _ in
            requests.append(method)
            switch method {
            case "config.get": return .object(["home": .string("/profiles/research")])
            case "profiles.list": return self.profiles([("default", "/profiles/default"), ("research", "/profiles/research")])
            default: return .object([:])
            }
        }

        do {
            _ = try await store.runtimeToolsets(profileName: "default", authenticatedProfilePath: "/profiles/default")
            XCTFail("Expected scope mismatch")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("does not match"))
        }
        await assertThrows {
            _ = try await store.setRuntimeToolsetEnabled(name: "terminal", enabled: false, profileName: "default", authenticatedProfilePath: "/profiles/default")
        }
        XCTAssertFalse(requests.contains("toolsets.list"))
        XCTAssertFalse(requests.contains("tools.configure"))
        XCTAssertFalse(requests.contains("session.create"))
    }

    func testRuntimeToolsetToggleUsesGatewayThenRefreshesGatewayState() async throws {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        var requests: [(method: String, params: [String: JSONValue])] = []
        store.requestOverride = { method, params in
            requests.append((method, params))
            if method == "config.get" {
                return .object(["home": .string("/profiles/default")])
            }
            if method == "profiles.list" {
                return self.profiles([("default", "/profiles/default")])
            }
            if method == "tools.configure" {
                return .object(["changed": .array([.string("terminal")]), "unknown": .array([]), "missing_servers": .array([])])
            }
            return self.toolsets(enabled: false)
        }

        let toolsets = try await store.setRuntimeToolsetEnabled(name: "terminal", enabled: false, profileName: "default", authenticatedProfilePath: "/profiles/default")

        XCTAssertEqual(requests.filter { $0.method == "tools.configure" }.count, 1)
        let configure = try XCTUnwrap(requests.first { $0.method == "tools.configure" })
        XCTAssertEqual(configure.params["action"], .string("disable"))
        XCTAssertEqual(configure.params["names"], .array([.string("terminal")]))
        XCTAssertNil(configure.params["profile"])
        XCTAssertNil(configure.params["session_id"])
        XCTAssertEqual(toolsets, [
            HermesTUIRuntimeToolset(name: "terminal", description: "Run local commands", toolCount: 3, enabled: false)
        ])
    }

    func testMissingOrAmbiguousProfileRecordsRejectBeforeToolsetRPC() async throws {
        let cases: [JSONValue] = [
            profiles([]),
            profiles([("default", "/profiles/default"), ("default", "/profiles/other")]),
            profiles([("default", "/profiles/default"), ("other", "/profiles/default")])
        ]
        for inventory in cases {
            let store = HermesTUIGatewayStore()
            store.isConnected = true
            var methods: [String] = []
            store.requestOverride = { method, _ in
                methods.append(method)
                if method == "config.get" { return .object(["home": .string("/profiles/default")]) }
                if method == "profiles.list" { return inventory }
                return self.toolsets()
            }
            do {
                _ = try await store.runtimeToolsets(profileName: "default", authenticatedProfilePath: "/profiles/default")
                XCTFail("Expected strict inventory rejection")
            } catch {
                XCTAssertFalse(methods.contains("toolsets.list"))
            }
        }
    }

    func testLateProofAfterDisconnectRejectsBeforeToolsetRPC() async throws {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        var methods: [String] = []
        store.requestOverride = { method, _ in
            methods.append(method)
            if method == "config.get" {
                store.disconnect()
                return .object(["home": .string("/profiles/default")])
            }
            return self.profiles([("default", "/profiles/default")])
        }
        await assertThrows {
            _ = try await store.runtimeToolsets(profileName: "default", authenticatedProfilePath: "/profiles/default")
        }
        XCTAssertFalse(methods.contains("toolsets.list"))
    }

    func testMutationRejectsMissingChangedUnknownOrMissingServerAcknowledgements() async throws {
        let acknowledgements: [JSONValue] = [
            .object(["unknown": .array([]), "missing_servers": .array([])]),
            .object(["changed": .array([]), "unknown": .array([]), "missing_servers": .array([])]),
            .object(["changed": .array([.string("terminal")]), "missing_servers": .array([])]),
            .object(["changed": .array([.string("terminal")]), "unknown": .array([])]),
            .object(["changed": .array([.string("terminal")]), "unknown": .array([.string("terminal")]), "missing_servers": .array([])]),
            .object(["changed": .array([.string("terminal")]), "unknown": .array([]), "missing_servers": .array([.string("server")])])
        ]
        for acknowledgement in acknowledgements {
            let store = HermesTUIGatewayStore()
            store.isConnected = true
            store.requestOverride = { method, _ in
                switch method {
                case "config.get": return .object(["home": .string("/profiles/default")])
                case "profiles.list": return self.profiles([("default", "/profiles/default")])
                case "tools.configure": return acknowledgement
                default: return self.toolsets()
                }
            }
            await assertThrows {
                _ = try await store.setRuntimeToolsetEnabled(name: "terminal", enabled: false, profileName: "default", authenticatedProfilePath: "/profiles/default")
            }
        }
    }

    func testMalformedProofResponseRejectsWithoutToolsetRPC() async throws {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        var methods: [String] = []
        store.requestOverride = { method, _ in
            methods.append(method)
            if method == "config.get" { return .object(["display": .string("missing home")]) }
            return self.profiles([("default", "/profiles/default")])
        }
        await assertThrows {
            _ = try await store.runtimeToolsets(profileName: "default", authenticatedProfilePath: "/profiles/default")
        }
        XCTAssertFalse(methods.contains("toolsets.list"))
    }

    func testScopeChangeImmediatelyBeforeWriteBlocksMutation() async {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        var proofs = 0
        var configured = false
        store.requestOverride = { method, _ in
            switch method {
            case "config.get":
                proofs += 1
                return .object(["home": .string(proofs == 1 ? "/profiles/default" : "/profiles/research")])
            case "profiles.list": return self.profiles([("default", "/profiles/default"), ("research", "/profiles/research")])
            case "tools.configure": configured = true; return .null
            default: return self.toolsets()
            }
        }
        await assertThrows {
            _ = try await store.setRuntimeToolsetEnabled(name: "terminal", enabled: false, profileName: "default", authenticatedProfilePath: "/profiles/default")
        }
        XCTAssertFalse(configured)
    }

    func testAcknowledgementWithoutMatchingReadbackIsNotSuccess() async {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        store.requestOverride = { method, _ in
            switch method {
            case "config.get": return .object(["home": .string("/profiles/default")])
            case "profiles.list": return self.profiles([("default", "/profiles/default")])
            case "tools.configure": return .object(["changed": .array([.string("terminal")]), "unknown": .array([]), "missing_servers": .array([])])
            default: return self.toolsets(enabled: true)
            }
        }
        await assertThrows {
            _ = try await store.setRuntimeToolsetEnabled(name: "terminal", enabled: false, profileName: "default", authenticatedProfilePath: "/profiles/default")
        }
    }

    func testCancelledMutationAndConcurrentMutationCannotWrite() async {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        var proof: CheckedContinuation<JSONValue, Never>?
        var methods: [String] = []
        store.requestOverride = { method, _ in
            methods.append(method)
            return await withCheckedContinuation { proof = $0 }
        }
        let first = Task {
            await self.assertThrows {
                _ = try await store.setRuntimeToolsetEnabled(name: "terminal", enabled: false, profileName: "default", authenticatedProfilePath: "/profiles/default")
            }
        }
        while proof == nil { await Task.yield() }
        await assertThrows {
            _ = try await store.setRuntimeToolsetEnabled(name: "terminal", enabled: false, profileName: "default", authenticatedProfilePath: "/profiles/default")
        }
        first.cancel()
        proof?.resume(returning: .object(["home": .string("/profiles/default")]))
        await first.value
        XCTAssertEqual(methods, ["config.get"])
    }

    func testMalformedToolsetPayloadCannotAuthorizeWrite() async {
        for malformed in [JSONValue.null, .object(["toolsets": .array([.object(["name": .string("terminal")])])])] {
            let store = HermesTUIGatewayStore()
            store.isConnected = true
            var configured = false
            store.requestOverride = { method, _ in
                switch method {
                case "config.get": return .object(["home": .string("/profiles/default")])
                case "profiles.list": return self.profiles([("default", "/profiles/default")])
                case "tools.configure": configured = true; return .null
                default: return malformed
                }
            }
            await assertThrows {
                _ = try await store.setRuntimeToolsetEnabled(name: "terminal", enabled: false, profileName: "default", authenticatedProfilePath: "/profiles/default")
            }
            XCTAssertFalse(configured)
        }
    }

    func testRuntimeProfilesUseTheExistingProfileScopedGatewayCatalog() async throws {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        store.requestOverride = { method, params in
            XCTAssertEqual(method, "profiles.list")
            XCTAssertEqual(params["include_sessions"], .bool(false))
            return .object([
                "profiles": .array([
                    .object([
                        "name": .string("default"),
                        "path": .string("/profiles/default"),
                        "display_name": .string("Default workspace"),
                        "provider": .string("openai"),
                        "model": .string("gpt-5")
                    ]),
                    .object([
                        "name": .string("research"),
                        "path": .string("/profiles/research"),
                        "display_name": .string("Research"),
                        "provider": .string("ollama"),
                        "model": .string("gemma4:12b-mlx")
                    ])
                ])
            ])
        }

        let profiles = try await store.runtimeProfileOptions()

        XCTAssertEqual(profiles.map(\.name), ["default", "research"])
        XCTAssertEqual(profiles.last?.displayName, "Research")
        XCTAssertEqual(profiles.last?.provider, "ollama")
        XCTAssertEqual(profiles.last?.model, "gemma4:12b-mlx")
    }
}
