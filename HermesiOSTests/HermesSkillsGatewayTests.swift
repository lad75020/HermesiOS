import XCTest
@testable import HermesiOS

@MainActor
final class HermesSkillsGatewayTests: XCTestCase {
    func testGatewaySkillsCatalogDecodesGenuineDictionaryPayload() throws {
        let payload = try JSONDecoder().decode(JSONValue.self, from: Data(#"""
        {"skills":{"coding":["refactor","swift"],"design":["ui-review"]}}
        """#.utf8))

        let catalog = try HermesTUIGatewayStore.decodeRuntimeSkillsCatalog(payload)

        XCTAssertEqual(catalog.categories, ["coding": ["refactor", "swift"], "design": ["ui-review"]])
        XCTAssertEqual(catalog.skillCount, 3)
    }

    func testGatewaySkillsCatalogUsesUnscopedListWithoutChatMutation() async throws {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        store.requestOverride = { method, params in
            XCTAssertEqual(method, "skills.manage")
            XCTAssertEqual(params, ["action": .string("list")])
            XCTAssertNil(params["profile"])
            XCTAssertNil(params["session_id"])
            return .object(["skills": .object(["general": .array([.string("inspect")])])])
        }

        let catalog = try await store.runtimeSkillsCatalog()

        XCTAssertEqual(catalog.categories, ["general": ["inspect"]])
        XCTAssertEqual(store.sessionID, "")
        XCTAssertTrue(store.messages.isEmpty)
        XCTAssertFalse(store.isStreaming)
    }

    func testMalformedCatalogIsNotReportedAsEmpty() throws {
        let payloads: [JSONValue] = [
            .object([:]),
            .object(["skills": .array([])]),
            .object(["skills": .object(["coding": .string("invalid")])]),
            .object(["skills": .object(["coding": .array([.number(1)])])])
        ]
        for payload in payloads {
            XCTAssertThrowsError(try HermesTUIGatewayStore.decodeRuntimeSkillsCatalog(payload))
        }
        let empty = try HermesTUIGatewayStore.decodeRuntimeSkillsCatalog(.object(["skills": .object([:])]))
        XCTAssertTrue(empty.categories.isEmpty)
    }

    func testGatewaySkillsCatalogPropagatesRPCFailure() async {
        struct FixtureError: LocalizedError { var errorDescription: String? { "skills RPC failed" } }
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        store.requestOverride = { _, _ in throw FixtureError() }

        do {
            _ = try await store.runtimeSkillsCatalog()
            XCTFail("Expected the RPC error")
        } catch {
            XCTAssertEqual(error.localizedDescription, "skills RPC failed")
        }
    }

    func testGatewaySkillsCatalogRejectsLateCompletionAfterDisconnect() async {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        var resume: CheckedContinuation<JSONValue, Never>?
        store.requestOverride = { _, _ in
            await withCheckedContinuation { continuation in resume = continuation }
        }

        let request = Task { () -> Error? in
            do {
                _ = try await store.runtimeSkillsCatalog()
                return nil
            } catch {
                return error
            }
        }
        while resume == nil { await Task.yield() }
        store.disconnect()
        resume?.resume(returning: .object(["skills": .object(["general": .array([.string("late")])])]))

        let error = await request.value
        XCTAssertNotNil(error)
        XCTAssertEqual(store.sessionID, "")
        XCTAssertTrue(store.messages.isEmpty)
    }

    func testFallbackPathPolicyRequiresExactAuthenticatedSelectedProfileIncludingDefault() {
        var settings = HermesCompanionSettings()
        settings.hermesWorkspacePath = "/untrusted/default"
        let profiles = [
            HermesCompanionProfileInfo(id: "default", name: "default", path: "/authenticated/default", isDefault: true, isActive: true, model: "", provider: "", baseUrl: "", hasConfig: true, hasEnv: false, hasSoul: false, skillCount: 0, gatewayRunning: false),
            HermesCompanionProfileInfo(id: "research", name: "research", path: "/authenticated/research", isDefault: false, isActive: false, model: "", provider: "", baseUrl: "", hasConfig: true, hasEnv: false, hasSoul: false, skillCount: 0, gatewayRunning: false)
        ]

        XCTAssertEqual(HermesSkillsFallbackPathPolicy.settings(selectedProfileName: "default", authenticatedProfiles: profiles, baseSettings: settings)?.hermesWorkspacePath, "/authenticated/default")
        XCTAssertEqual(HermesSkillsFallbackPathPolicy.settings(selectedProfileName: "research", authenticatedProfiles: profiles, baseSettings: settings)?.hermesWorkspacePath, "/authenticated/research")
        XCTAssertNil(HermesSkillsFallbackPathPolicy.settings(selectedProfileName: "missing", authenticatedProfiles: profiles, baseSettings: settings))
        XCTAssertNil(HermesSkillsFallbackPathPolicy.settings(selectedProfileName: " research ", authenticatedProfiles: profiles, baseSettings: settings))
        XCTAssertNil(HermesSkillsFallbackPathPolicy.settings(selectedProfileName: "default", authenticatedProfiles: [], baseSettings: settings))
    }
}
