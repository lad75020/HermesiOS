import XCTest
@testable import HermesiOS

@MainActor
final class HermesRuntimeConnectionTests: XCTestCase {
    func testRuntimeReconnectsForEndpointCredentialAndTLSChangesWithoutChatRPCs() async throws {
        let store = HermesTUIGatewayStore()
        var connections = 0
        store.runtimeConnectOverride = {
            connections += 1
            store.isConnected = true
        }
        store.requestOverride = { method, _ in
            XCTFail("Runtime connection must not create chat RPCs: \(method)")
            return .null
        }
        var settings = HermesAPISettings()
        settings.baseURL = "http://first.invalid/v1"
        settings.apiKey = String(repeating: "a", count: 12)
        let dashboard = "http://first.invalid:9119"
        try await store.connectForRuntime(dashboardBaseURL: dashboard, apiSettings: settings)
        try await store.connectForRuntime(dashboardBaseURL: dashboard, apiSettings: settings)
        XCTAssertEqual(connections, 1)
        settings.apiKey = String(repeating: "b", count: 12)
        try await store.connectForRuntime(dashboardBaseURL: dashboard, apiSettings: settings)
        XCTAssertEqual(connections, 2)
        settings.baseURL = "http://second.invalid/v1"
        try await store.connectForRuntime(dashboardBaseURL: dashboard, apiSettings: settings)
        XCTAssertEqual(connections, 3)
        settings.allowSelfSignedCertificates = true
        try await store.connectForRuntime(dashboardBaseURL: dashboard, apiSettings: settings)
        XCTAssertEqual(connections, 4)
        try await store.connectForRuntime(dashboardBaseURL: "http://second.invalid:9119", apiSettings: settings)
        XCTAssertEqual(connections, 5)
        XCTAssertEqual(store.sessionID, "")
        XCTAssertTrue(store.messages.isEmpty)
    }

    func testRuntimeRejectsConnectionCompletionAfterDisconnect() async {
        let store = HermesTUIGatewayStore()
        var continuation: CheckedContinuation<Void, Never>?
        store.runtimeConnectOverride = {
            await withCheckedContinuation { continuation = $0 }
            store.isConnected = true
        }
        let task = Task {
            do {
                try await store.connectForRuntime(dashboardBaseURL: "http://example.invalid", apiSettings: HermesAPISettings())
                return false
            } catch { return true }
        }
        while continuation == nil { await Task.yield() }
        store.disconnect()
        continuation?.resume()
        let rejected = await task.value
        XCTAssertTrue(rejected)
    }

    func testRuntimeIdentityTracksKeyRotationWithoutIncludingRawCredential() {
        var settings = HermesAPISettings()
        settings.apiKey = String(repeating: "x", count: 24)
        let first = HermesRuntimeConnectionIdentity(dashboardURL: "http://example.invalid", apiSettings: settings)
        XCTAssertNotEqual(first.credentialFingerprint, settings.apiKey)
        settings.apiKey = String(repeating: "y", count: 24)
        XCTAssertNotEqual(first, HermesRuntimeConnectionIdentity(dashboardURL: "http://example.invalid", apiSettings: settings))
    }
}
