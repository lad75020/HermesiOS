import XCTest
@testable import HermesiOS

@MainActor
final class HermesTUIRuntimeToolsetsTests: XCTestCase {
    private func profiles(
        _ values: [(String, String)],
        identities: [String: String] = [:]
    ) -> JSONValue {
        .object(["profiles": .array(values.map { name, path in
            var row: [String: JSONValue] = [
                "name": .string(name), "path": .string(path), "display_name": .string(name),
                "provider": .string("openai"), "model": .string("gpt-5")
            ]
            if let identity = identities[name] {
                row["path_identity"] = .string(identity)
            }
            return .object(row)
        })])
    }

    private func toolsets(
        enabled: Bool = true,
        profileName: String = "default",
        pinned: Bool = false
    ) -> JSONValue {
        .object([
            "name": .string(profileName),
            "toolsets_pinned": .bool(pinned),
            "toolsets": .array([
            .object([
                "name": .string("terminal"), "description": .string("Run local commands"),
                "tool_count": .number(3), "enabled": .bool(enabled),
                "tools": .array([.string("terminal"), .string("process_manage"), .string("read_terminal")])
            ])
        ])])
    }

    private func toolsetRow(name: String, enabled: Bool, tools: [String]? = nil) -> JSONValue {
        let tools = tools ?? ["\(name)_tool"]
        return .object([
            "name": .string(name),
            "description": .string("\(name) tools"),
            "tool_count": .number(Double(tools.count)),
            "enabled": .bool(enabled),
            "tools": .array(tools.map(JSONValue.string))
        ])
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
            case "tools.list": return self.toolsets()
            case "profiles.describe": return self.toolsets()
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
            case "tools.list": return self.toolsets()
            case "profiles.describe": return self.toolsets(profileName: "research")
            default: return .object([:])
            }
        }

        do {
            _ = try await store.runtimeToolsets(profileName: "research", authenticatedProfilePath: "/profiles/research")
        } catch {
            XCTFail("Expected named launch-profile match: \(error)")
        }
    }

    func testRuntimeToolsetsAllowsServerVerifiedFilesystemAlias() async throws {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        store.requestOverride = { method, _ in
            switch method {
            case "config.get":
                return .object([
                    "home": .string("/Volumes/WDBlack4TB/.hermes"),
                    "home_identity": .string("/Volumes/WDBlack4TB/.hermes")
                ])
            case "profiles.list":
                return self.profiles(
                    [("default", "/Users/laurent/.hermes")],
                    identities: ["default": "/Volumes/WDBlack4TB/.hermes"]
                )
            case "tools.list":
                return self.toolsets()
            case "profiles.describe":
                return self.toolsets()
            default:
                return .object([:])
            }
        }

        let toolsets = try await store.runtimeToolsets(
            profileName: "default",
            authenticatedProfilePath: "/Users/laurent/.hermes"
        )

        XCTAssertEqual(toolsets.map(\.name), ["terminal"])
    }

    func testRuntimeToolsetsRejectsMismatchedServerIdentity() async throws {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        var methods: [String] = []
        store.requestOverride = { method, _ in
            methods.append(method)
            if method == "config.get" {
                return .object([
                    "home": .string("/profiles/default"),
                    "home_identity": .string("identity-default")
                ])
            }
            return self.profiles(
                [("default", "/profiles/default")],
                identities: ["default": "identity-other"]
            )
        }

        await assertThrows {
            _ = try await store.runtimeToolsets(
                profileName: "default",
                authenticatedProfilePath: "/profiles/default"
            )
        }

        XCTAssertFalse(methods.contains("tools.list"))
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
        XCTAssertFalse(requests.contains("tools.list"))
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

    func testHermesACPRuntimePresetRejectsBeforeToolsConfigure() async {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        var methods: [String] = []
        store.requestOverride = { method, _ in
            methods.append(method)
            switch method {
            case "config.get":
                return .object(["home": .string("/profiles/default")])
            case "profiles.list":
                return self.profiles([("default", "/profiles/default")])
            case "tools.list":
                return .object(["toolsets": .array([
                    .object([
                        "name": .string("hermes-acp"),
                        "description": .string("ACP editor launch preset"),
                        "tool_count": .number(5),
                        "enabled": .bool(false),
                        "tools": .array((1...5).map { .string("acp_tool_\($0)") })
                    ])
                ])])
            case "profiles.describe":
                return .object([
                    "name": .string("default"),
                    "toolsets_pinned": .bool(false),
                    "toolsets": .array([])
                ])
            default:
                return .object([:])
            }
        }

        do {
            _ = try await store.setRuntimeToolsetEnabled(
                name: "hermes-acp",
                enabled: true,
                profileName: "default",
                authenticatedProfilePath: "/profiles/default"
            )
            XCTFail("Expected the runtime preset mutation to be rejected")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("read-only runtime preset"))
        }

        XCTAssertFalse(methods.contains("tools.configure"))
    }

    func testMutabilityUsesCatalogIntersectionWithoutAppendingDescribeOnlyRows() async throws {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        store.requestOverride = { method, _ in
            switch method {
            case "config.get":
                return .object(["home": .string("/profiles/default")])
            case "profiles.list":
                return self.profiles([("default", "/profiles/default")])
            case "tools.list":
                return .object(["toolsets": .array([
                    self.toolsetRow(name: "hermes-acp", enabled: false),
                    self.toolsetRow(name: "debugging", enabled: false),
                    self.toolsetRow(name: "terminal", enabled: true),
                    self.toolsetRow(name: "example-plugin", enabled: true)
                ])])
            case "profiles.describe":
                return .object([
                    "name": .string("default"),
                    "toolsets_pinned": .bool(false),
                    "toolsets": .array([
                        self.toolsetRow(name: "terminal", enabled: true),
                        self.toolsetRow(name: "example-plugin", enabled: true),
                        self.toolsetRow(name: "stt", enabled: true)
                    ])
                ])
            default:
                return .object([:])
            }
        }

        let toolsets = try await store.runtimeToolsets(
            profileName: "default",
            authenticatedProfilePath: "/profiles/default"
        )

        XCTAssertEqual(toolsets.map(\.name), ["debugging", "example-plugin", "hermes-acp", "terminal"])
        XCTAssertEqual(toolsets.first(where: { $0.name == "debugging" })?.configuration, .runtimePreset)
        XCTAssertEqual(toolsets.first(where: { $0.name == "hermes-acp" })?.configuration, .runtimePreset)
        XCTAssertEqual(toolsets.first(where: { $0.name == "terminal" })?.configuration, .configurable)
        XCTAssertEqual(toolsets.first(where: { $0.name == "example-plugin" })?.configuration, .configurable)
        XCTAssertFalse(toolsets.contains(where: { $0.name == "stt" }))
    }

    func testRuntimeToolsExcludeMCPServerAliasesButKeepOrdinaryToolsets() async throws {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        store.requestOverride = { method, _ in
            switch method {
            case "config.get":
                return .object(["home": .string("/profiles/default")])
            case "profiles.list":
                return self.profiles([("default", "/profiles/default")])
            case "tools.list":
                return .object(["toolsets": .array([
                    self.toolsetRow(name: "terminal", enabled: true),
                    self.toolsetRow(
                        name: "XCodeMCP",
                        enabled: true,
                        tools: ["mcp__XCodeMCP__BuildProject", "mcp__XCodeMCP__RunAllTests"]
                    ),
                    self.toolsetRow(
                        name: "EdgeDriverMCP",
                        enabled: true,
                        tools: ["mcp__EdgeDriverMCP__edge_click"]
                    ),
                    self.toolsetRow(
                        name: "mixed-plugin",
                        enabled: true,
                        tools: ["mcp__shared__probe", "mixed_plugin_native"]
                    )
                ])])
            case "profiles.describe":
                return .object([
                    "name": .string("default"),
                    "toolsets_pinned": .bool(false),
                    "toolsets": .array([self.toolsetRow(name: "terminal", enabled: true)])
                ])
            default:
                return .object([:])
            }
        }

        let toolsets = try await store.runtimeToolsets(
            profileName: "default",
            authenticatedProfilePath: "/profiles/default"
        )

        XCTAssertEqual(toolsets.map(\.name), ["mixed-plugin", "terminal"])
        XCTAssertFalse(toolsets.contains(where: { $0.name == "XCodeMCP" }))
        XCTAssertFalse(toolsets.contains(where: { $0.name == "EdgeDriverMCP" }))
    }

    func testFilteredMCPServerAliasCannotBeConfiguredFromTools() async {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        var configured = false
        store.requestOverride = { method, _ in
            switch method {
            case "config.get":
                return .object(["home": .string("/profiles/default")])
            case "profiles.list":
                return self.profiles([("default", "/profiles/default")])
            case "tools.list":
                return .object(["toolsets": .array([
                    self.toolsetRow(
                        name: "XCodeMCP",
                        enabled: true,
                        tools: ["mcp__XCodeMCP__BuildProject"]
                    )
                ])])
            case "profiles.describe":
                return .object([
                    "name": .string("default"),
                    "toolsets_pinned": .bool(false),
                    "toolsets": .array([])
                ])
            case "tools.configure":
                configured = true
                return .object([:])
            default:
                return .object([:])
            }
        }

        await assertThrows {
            _ = try await store.setRuntimeToolsetEnabled(
                name: "XCodeMCP",
                enabled: false,
                profileName: "default",
                authenticatedProfilePath: "/profiles/default"
            )
        }

        XCTAssertFalse(configured)
    }

    func testPinnedProfileBlocksBeforeToolsConfigure() async {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        var methods: [String] = []
        store.requestOverride = { method, _ in
            methods.append(method)
            switch method {
            case "config.get":
                return .object(["home": .string("/profiles/default")])
            case "profiles.list":
                return self.profiles([("default", "/profiles/default")])
            case "tools.list":
                return self.toolsets()
            case "profiles.describe":
                return self.toolsets(pinned: true)
            default:
                return .object([:])
            }
        }

        do {
            _ = try await store.setRuntimeToolsetEnabled(
                name: "terminal",
                enabled: false,
                profileName: "default",
                authenticatedProfilePath: "/profiles/default"
            )
            XCTFail("Expected pinned profile toolsets to block mutation")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("pinned"))
        }

        XCTAssertFalse(methods.contains("tools.configure"))
    }

    func testRuntimeToolsetsRejectsMismatchedOrMalformedProfileMutabilityMetadata() async {
        let invalidResponses: [JSONValue] = [
            .object([
                "name": .string("research"),
                "toolsets_pinned": .bool(false),
                "toolsets": .array([toolsetRow(name: "terminal", enabled: true)])
            ]),
            .object([
                "name": .string("default"),
                "toolsets": .array([toolsetRow(name: "terminal", enabled: true)])
            ]),
            .object([
                "name": .string("default"),
                "toolsets_pinned": .string("false"),
                "toolsets": .array([toolsetRow(name: "terminal", enabled: true)])
            ])
        ]

        for invalidResponse in invalidResponses {
            let store = HermesTUIGatewayStore()
            store.isConnected = true
            store.requestOverride = { method, _ in
                switch method {
                case "config.get": return .object(["home": .string("/profiles/default")])
                case "profiles.list": return self.profiles([("default", "/profiles/default")])
                case "tools.list": return self.toolsets()
                case "profiles.describe": return invalidResponse
                default: return .object([:])
                }
            }

            do {
                _ = try await store.runtimeToolsets(
                    profileName: "default",
                    authenticatedProfilePath: "/profiles/default"
                )
                XCTFail("Expected invalid profile mutability metadata to be rejected")
            } catch {
                XCTAssertTrue(error.localizedDescription.contains("Invalid or mismatched"))
            }
        }
    }

    func testPinnedTransitionAfterAcknowledgementCannotBeReportedAsSuccess() async {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        var describeCount = 0
        var configureCount = 0
        store.requestOverride = { method, _ in
            switch method {
            case "config.get":
                return .object(["home": .string("/profiles/default")])
            case "profiles.list":
                return self.profiles([("default", "/profiles/default")])
            case "tools.list":
                return self.toolsets(enabled: describeCount == 0)
            case "profiles.describe":
                describeCount += 1
                return self.toolsets(enabled: describeCount == 1, pinned: describeCount > 1)
            case "tools.configure":
                configureCount += 1
                return .object([
                    "changed": .array([.string("terminal")]),
                    "unknown": .array([]),
                    "missing_servers": .array([])
                ])
            default:
                return .object([:])
            }
        }

        do {
            _ = try await store.setRuntimeToolsetEnabled(
                name: "terminal",
                enabled: false,
                profileName: "default",
                authenticatedProfilePath: "/profiles/default"
            )
            XCTFail("Expected a pinned readback to reject mutation success")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("refreshed toolset state does not match"))
        }

        XCTAssertEqual(configureCount, 1)
        XCTAssertEqual(describeCount, 2)
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
                XCTAssertFalse(methods.contains("tools.list"))
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
        XCTAssertFalse(methods.contains("tools.list"))
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
        XCTAssertFalse(methods.contains("tools.list"))
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
