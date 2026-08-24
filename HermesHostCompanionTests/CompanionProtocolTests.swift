import Foundation
import XCTest
@testable import HermesHostCompanion

final class CompanionProtocolTests: XCTestCase {
    private struct EchoPayload: Codable, Equatable {
        let message: String
        let count: Int
        let enabled: Bool
    }

    func testOutgoingSuccessEnvelopeRoundTripsTypedPayload() throws {
        let original = EchoPayload(message: "ready", count: 2, enabled: true)
        let outgoing = CompanionOutgoingEnvelope.success(id: "request-42", payload: original)
        let encoded = try JSONEncoder().encode(outgoing)
        let decoded = try JSONDecoder().decode(CompanionOutgoingEnvelope.self, from: encoded)

        XCTAssertEqual(decoded.id, "request-42")
        XCTAssertTrue(decoded.ok)
        XCTAssertNil(decoded.error)
        XCTAssertEqual(try XCTUnwrap(decoded.payload).decode(EchoPayload.self), original)
    }

    func testIncomingEnvelopeDecodesNestedJSONValue() throws {
        let data = Data(#"{"id":"request-7","type":"target.write","deviceID":"device-1","deviceSecret":"secret","payload":{"targetID":"hermes-config","flags":[true,false],"attempt":3}}"#.utf8)
        let envelope = try JSONDecoder().decode(CompanionIncomingEnvelope.self, from: data)

        XCTAssertEqual(envelope.id, "request-7")
        XCTAssertEqual(envelope.type, "target.write")
        XCTAssertEqual(envelope.deviceID, "device-1")
        let payload = try XCTUnwrap(envelope.payload)
        let decoded = try payload.decode([String: JSONValue].self)
        guard case .string(let targetID)? = decoded["targetID"],
              case .array(let flags)? = decoded["flags"],
              case .bool(true) = flags.first,
              case .number(let attempt)? = decoded["attempt"] else {
            return XCTFail("Expected the JSON payload to preserve nested value types")
        }
        XCTAssertEqual(targetID, "hermes-config")
        XCTAssertEqual(attempt, 3)
    }

    func testErrorEnvelopeEncodesProtocolFailureWithoutPayload() throws {
        let envelope = CompanionOutgoingEnvelope.error(id: nil, code: "not_authorized", message: "Approval required")
        let decoded = try JSONDecoder().decode(CompanionOutgoingEnvelope.self, from: JSONEncoder().encode(envelope))

        XCTAssertFalse(decoded.ok)
        XCTAssertNil(decoded.id)
        XCTAssertNil(decoded.payload)
        XCTAssertEqual(decoded.error?.code, "not_authorized")
        XCTAssertEqual(decoded.error?.message, "Approval required")
    }
}

final class CompanionConfigurationAndWorkspaceSecurityTests: XCTestCase {
    func testServerConfigurationNormalizesAddressAndSelectsTransport() {
        XCTAssertEqual(CompanionServerConfiguration.sanitizedHost(" https://macbook.example.ts.net:9112/ws "), "macbook.example.ts.net")
        XCTAssertEqual(CompanionServerConfiguration.sanitizedHost("[::1]"), "::1")

        let local = CompanionServerConfiguration(host: "localhost", port: 9112)
        let remote = CompanionServerConfiguration(host: "companion.example.com", port: 9112)
        let ipv6Remote = CompanionServerConfiguration(host: "2001:db8::1", port: 9112)
        XCTAssertEqual(local.webSocketURLString, "ws://localhost:9112/ws")
        XCTAssertEqual(remote.webSocketURLString, "wss://companion.example.com:9112/ws")
        XCTAssertEqual(ipv6Remote.webSocketURLString, "wss://[2001:db8::1]:9112/ws")
    }

    func testWorkspaceDescendantCheckRejectsPrefixLookalikes() {
        let root = URL(fileURLWithPath: "/tmp/hermes-workspace", isDirectory: true)
        XCTAssertTrue(CompanionWorkspaceSecurity.isDescendant(URL(fileURLWithPath: "/tmp/hermes-workspace/skills/demo", isDirectory: true), of: root))
        XCTAssertTrue(CompanionWorkspaceSecurity.isDescendant(root, of: root))
        XCTAssertFalse(CompanionWorkspaceSecurity.isDescendant(URL(fileURLWithPath: "/tmp/hermes-workspace-other", isDirectory: true), of: root))
    }
}
