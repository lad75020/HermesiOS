import XCTest
@testable import HermesiOS

@MainActor
final class HermesTUIProfileSkillsCompatibilityTests: XCTestCase {
    private func payload(profileName: String = "research", skills: [JSONValue]) -> JSONValue {
        .object([
            "name": .string(profileName),
            "skills": .array(skills),
            "model": .string("must-not-be-modelled"),
            "soul": .object(["private": .string("must-not-be-modelled")])
        ])
    }

    private func skill(_ name: String, enabled: Bool) -> JSONValue {
        .object(["name": .string(name), "enabled": .bool(enabled)])
    }

    private func assertRequestFails(_ operation: () throws -> Void) {
        XCTAssertThrowsError(try operation()) { error in
            guard case HermesTUIGatewayError.requestFailed(let message) = error else {
                return XCTFail("Expected requestFailed, got \(error)")
            }
            XCTAssertFalse(message.isEmpty)
        }
    }

    func testDecodeActualDescribePayloadAndSortsSkillNames() throws {
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(#"""
        {
          "name": "research",
          "skills": [
            {"name": "zeta", "enabled": false},
            {"name": "alpha", "enabled": true}
          ],
          "model": "not-for-this-view",
          "soul": {"private": "not-for-this-view"}
        }
        """#.utf8))

        let decoded = try HermesTUIProfileSkills.decode(value, profileName: "research")

        XCTAssertEqual(decoded.profileName, "research")
        XCTAssertEqual(decoded.skills, [
            HermesTUIProfileSkill(name: "alpha", isEnabled: true),
            HermesTUIProfileSkill(name: "zeta", isEnabled: false)
        ])
        XCTAssertEqual(decoded.skills.map(\.id), ["alpha", "zeta"])
    }

    func testDecodeRequiresExactCaseSensitiveProfileName() {
        let value = payload(profileName: "Research", skills: [])
        assertRequestFails { _ = try HermesTUIProfileSkills.decode(value, profileName: "research") }
        assertRequestFails { _ = try HermesTUIProfileSkills.decode(payload(skills: []), profileName: " research ") }
        assertRequestFails { _ = try HermesTUIProfileSkills.decode(payload(skills: []), profileName: "   ") }
    }

    func testDecodeRejectsMissingOrInvalidRowsFieldsAndArray() {
        let invalidPayloads: [JSONValue] = [
            .null,
            .object(["skills": .array([])]),
            .object(["name": .bool(true), "skills": .array([])]),
            .object(["name": .string("research")]),
            .object(["name": .string("research"), "skills": .object([:])]),
            payload(skills: [.string("not an object")]),
            payload(skills: [.object(["enabled": .bool(true)])]),
            payload(skills: [.object(["name": .string("   "), "enabled": .bool(true)])]),
            payload(skills: [.object(["name": .string("terminal")])]),
            payload(skills: [.object(["name": .string("terminal"), "enabled": .string("true")])]),
            payload(skills: [.object(["name": .string("terminal"), "enabled": .number(1)])])
        ]

        for value in invalidPayloads {
            assertRequestFails { _ = try HermesTUIProfileSkills.decode(value, profileName: "research") }
        }
    }

    func testDecodeAllowsEmptyInventory() throws {
        let decoded = try HermesTUIProfileSkills.decode(payload(skills: []), profileName: "research")
        XCTAssertEqual(decoded, HermesTUIProfileSkills(profileName: "research", skills: []))
    }

    func testDecodeRejectsConflictingStatesForRepeatedLeafName() {
        let value = payload(skills: [skill("terminal", enabled: true), skill("terminal", enabled: false)])
        assertRequestFails { _ = try HermesTUIProfileSkills.decode(value, profileName: "research") }
    }

    func testRepeatedLeafNamesKeepEntryTotalsAndStableUniqueRows() throws {
        let rows = [skill("review", enabled: true), skill("memory", enabled: false), skill("review", enabled: true)]
        let decoded = try HermesTUIProfileSkills.decode(payload(skills: rows), profileName: "research")
        let reordered = try HermesTUIProfileSkills.decode(payload(skills: Array(rows.reversed())), profileName: "research")
        XCTAssertEqual(decoded, reordered)
        XCTAssertEqual(decoded.skills.map(\.id), ["memory", "review"])
        XCTAssertEqual(decoded.skills.map(\.occurrenceCount), [1, 2])
        XCTAssertEqual(decoded.installedCount, 3)
        XCTAssertEqual(decoded.enabledCount, 2)
    }

    func testRuntimeProfileSkillsUsesOnlyDescribeForSelectedProfileWithoutSessionMutation() async throws {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        store.sessionID = "existing-session"
        var requests: [(String, [String: JSONValue])] = []
        store.requestOverride = { method, params in
            requests.append((method, params))
            return self.payload(skills: [self.skill("terminal", enabled: true)])
        }

        let result = try await store.runtimeProfileSkills(profileName: "research")

        XCTAssertEqual(requests.map(\.0), ["profiles.describe"])
        XCTAssertEqual(requests.first?.1, ["name": .string("research")])
        XCTAssertEqual(store.sessionID, "existing-session")
        XCTAssertTrue(store.messages.isEmpty)
        XCTAssertFalse(store.isStreaming)
        XCTAssertEqual(result.skills.map(\.name), ["terminal"])
    }

    func testDefaultProfileIsExplicitAndMalformedNamesNeverReachTransport() async throws {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        var calls = 0
        store.requestOverride = { method, params in
            calls += 1
            XCTAssertEqual(method, "profiles.describe")
            XCTAssertEqual(params, ["name": .string("default")])
            return self.payload(profileName: "default", skills: [])
        }
        let result = try await store.runtimeProfileSkills(profileName: "default")
        XCTAssertEqual(result.profileName, "default")
        for name in ["", " ", " default", "default\n"] {
            do {
                _ = try await store.runtimeProfileSkills(profileName: name)
                XCTFail("Expected invalid profile rejection")
            } catch { }
        }
        XCTAssertEqual(calls, 1)
        XCTAssertTrue(store.sessionID.isEmpty)
        XCTAssertTrue(store.messages.isEmpty)
    }

    func testRuntimeProfileSkillsPropagatesTransportError() async {
        struct FixtureError: LocalizedError { var errorDescription: String? { "describe failed" } }
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        store.requestOverride = { _, _ in throw FixtureError() }

        do {
            _ = try await store.runtimeProfileSkills(profileName: "research")
            XCTFail("Expected transport error")
        } catch {
            XCTAssertEqual(error.localizedDescription, "describe failed")
        }
    }

    func testRuntimeProfileSkillsDoesNotRequestWhenDisconnected() async {
        let store = HermesTUIGatewayStore()
        store.requestOverride = { _, _ in
            XCTFail("Disconnected request must not reach the transport")
            return .null
        }

        do {
            _ = try await store.runtimeProfileSkills(profileName: "research")
            XCTFail("Expected not connected error")
        } catch {
            XCTAssertEqual(error.localizedDescription, HermesTUIGatewayError.notConnected.localizedDescription)
        }
    }

    func testRuntimeProfileSkillsRejectsLateResponseAfterDisconnect() async {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        var pending: CheckedContinuation<JSONValue, Never>?
        store.requestOverride = { _, _ in
            await withCheckedContinuation { continuation in pending = continuation }
        }

        let request = Task { () -> Error? in
            do {
                _ = try await store.runtimeProfileSkills(profileName: "research")
                return nil
            } catch {
                return error
            }
        }
        while pending == nil { await Task.yield() }
        store.disconnect()
        pending?.resume(returning: payload(skills: []))

        let error = await request.value
        XCTAssertEqual(error?.localizedDescription, HermesTUIGatewayError.notConnected.localizedDescription)
    }

    func testRuntimeProfileSkillsRejectsResponseAfterCancellation() async {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        var pending: CheckedContinuation<JSONValue, Never>?
        store.requestOverride = { _, _ in
            await withCheckedContinuation { continuation in pending = continuation }
        }

        let request = Task { () -> Error? in
            do {
                _ = try await store.runtimeProfileSkills(profileName: "research")
                return nil
            } catch {
                return error
            }
        }
        while pending == nil { await Task.yield() }
        request.cancel()
        pending?.resume(returning: payload(skills: []))

        let error = await request.value
        XCTAssertEqual(error?.localizedDescription, HermesTUIGatewayError.notConnected.localizedDescription)
    }
}
