import Foundation
import XCTest
@testable import HermesiOS

final class HermesHostEndpointsTests: XCTestCase {
    func testNormalizedHostStripsSchemePortAndPath() {
        XCTAssertEqual(
            HermesHostEndpoints.normalizedHost("  https://macbook.example.ts.net:9112/ws  "),
            "macbook.example.ts.net"
        )
        XCTAssertEqual(HermesHostEndpoints.normalizedHost("example.com:8642/v1"), "example.com")
        XCTAssertEqual(HermesHostEndpoints.normalizedHost("   "), defaultHermesMacHost)
    }

    func testRemoteEndpointsUseTLSAndRemoteDashboardPortMigration() {
        XCTAssertEqual(
            HermesHostEndpoints.webSocketURLString(host: "companion.example.com", port: "9112"),
            "wss://companion.example.com:9112/ws"
        )
        XCTAssertEqual(
            HermesHostEndpoints.remoteDashboardPort(from: legacyLocalHermesDashboardPort, host: "companion.example.com"),
            defaultHermesDashboardPort
        )
        XCTAssertEqual(
            HermesHostEndpoints.remoteDashboardPort(from: legacyLocalHermesDashboardPort, host: "localhost"),
            legacyLocalHermesDashboardPort
        )
    }

    func testPlaintextSensitiveEndpointsAreLimitedToLoopbackAndTailnet() throws {
        let remote = try XCTUnwrap(URL(string: "http://example.com/v1"))
        let loopback = try XCTUnwrap(URL(string: "http://127.0.0.1:8642/v1"))
        let tailnet = try XCTUnwrap(URL(string: "ws://macbook.example.ts.net:9112/ws"))

        XCTAssertFalse(HermesEndpointSecurity.isPlaintextTransportAllowed(for: remote))
        XCTAssertTrue(HermesEndpointSecurity.isPlaintextTransportAllowed(for: loopback))
        XCTAssertTrue(HermesEndpointSecurity.isPlaintextTransportAllowed(for: tailnet))
        XCTAssertNotNil(HermesEndpointSecurity.plaintextTransportWarning(for: remote.absoluteString, endpointName: "Hermes API"))
        XCTAssertNil(HermesEndpointSecurity.plaintextTransportWarning(for: loopback.absoluteString, endpointName: "Hermes API"))
        XCTAssertThrowsError(try HermesEndpointSecurity.validateSensitiveURL(remote))
        XCTAssertNoThrow(try HermesEndpointSecurity.validateSensitiveURL(tailnet))
    }
}

final class HermesPhonePrimaryTabTests: XCTestCase {
    func testPrimaryTabsExcludeAskAndChatDestinations() {
        XCTAssertEqual(HermesPhonePrimaryTab.allCases.map(\.title), ["TUI", "Approvals", "More"])
        XCTAssertFalse(HermesPhonePrimaryTab.allCases.map(\.systemImage).contains("dot.radiowaves.left.and.right"))
        XCTAssertFalse(HermesPhonePrimaryTab.allCases.map(\.systemImage).contains("text.bubble"))
    }

    func testRemovedConsoleSectionsResolveToTUIGateway() {
        XCTAssertEqual(HermesPhonePrimaryTab.resolve(for: .responses), .tuiGateway)
        XCTAssertEqual(HermesPhonePrimaryTab.resolve(for: .chat), .tuiGateway)
        XCTAssertEqual(HermesPhonePrimaryTab.resolve(for: .history), .more)
    }
}
