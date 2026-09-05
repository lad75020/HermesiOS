import Foundation
import XCTest
@testable import HermesHostCompanion

final class CompanionProtocolTests: XCTestCase {
    func testCronEditArgumentsOmitUnchangedPinsAndClearExplicitEmptyPins() throws {
        let args = try CompanionScheduleRegistry.editArguments(
            jobID: "job-1",
            schedule: nil,
            prompt: nil,
            name: nil,
            deliver: "",
            provider: nil,
            model: "",
            baseUrl: nil
        )

        XCTAssertEqual(args, ["edit", "job-1", "--deliver=", "--model="])
    }

    func testCronCreateArgumentsKeepHyphenPrefixedValuesAttachedToFlags() throws {
        let args = try CompanionScheduleRegistry.createArguments(
            schedule: "0 9 * * *",
            prompt: "Run the report",
            name: "-morning",
            deliver: "local",
            provider: "-custom",
            model: "-model",
            baseUrl: nil
        )

        XCTAssertEqual(args, [
            "create", "0 9 * * *", "Run the report",
            "--name=-morning", "--deliver=local", "--provider=-custom", "--model=-model"
        ])
    }

    func testCronArgumentsRejectBaseURLRatherThanInventingAnUnsupportedCLIFlag() {
        XCTAssertThrowsError(try CompanionScheduleRegistry.editArguments(
            jobID: "job-1", schedule: nil, prompt: nil, name: nil, deliver: nil,
            provider: nil, model: nil, baseUrl: "http://127.0.0.1:8000/v1"
        )) { error in
            guard case CompanionScheduleRegistryError.unsupportedBaseURLPin = error else {
                return XCTFail("Expected the unsupported base URL error, got \(error)")
            }
        }
    }

    func testScheduleNormalizationKeepsRawExpressionAndProviderPins() throws {
        let job = try XCTUnwrap(CompanionScheduleRegistry.normalizeJob([
            "id": "job-1",
            "name": "Morning report",
            "schedule": ["value": "0 9 * * *"],
            "schedule_display": "Every day at 09:00",
            "prompt": "Report",
            "provider": "ollama",
            "model": "qwen3",
            "base_url": "http://127.0.0.1:11434/v1",
            "deliver": "local"
        ], includeDisabled: true))

        XCTAssertEqual(job.schedule, "Every day at 09:00")
        XCTAssertEqual(job.rawSchedule, "0 9 * * *")
        XCTAssertEqual(job.provider, "ollama")
        XCTAssertEqual(job.model, "qwen3")
        XCTAssertEqual(job.baseUrl, "http://127.0.0.1:11434/v1")
    }

    func testRuntimeModelSlotPayloadPreservesBaseURL() throws {
        let payload = SetRuntimeModelSlotPayload(
            workspacePath: "/tmp/runtime",
            section: "auxiliary",
            key: "vision",
            provider: "custom",
            model: "local/vision",
            baseUrl: "http://127.0.0.1:8000/v1"
        )
        let decoded = try JSONDecoder().decode(SetRuntimeModelSlotPayload.self, from: JSONEncoder().encode(payload))
        XCTAssertEqual(decoded.baseUrl, "http://127.0.0.1:8000/v1")
    }

    func testOldRuntimeSlotAndSchedulePayloadsDecodeWithCompatibilityDefaults() throws {
        let oldSlot = try JSONDecoder().decode(RuntimeModelSlotConfig.self, from: Data(#"{"id":"delegation","label":"Delegation","section":"delegation","key":"delegation","provider":"custom","model":"local/model"}"#.utf8))
        XCTAssertEqual(oldSlot.baseUrl, "")

        let oldSchedule = try JSONDecoder().decode(ScheduleCronJob.self, from: Data(#"{"id":"job","name":"Job","schedule":"0 9 * * *","prompt":"run","state":"active","enabled":true}"#.utf8))
        XCTAssertEqual(oldSchedule.rawSchedule, "0 9 * * *")
    }

    func testOldSlotEditPayloadKeepsBaseURLOmitted() throws {
        let payload = try JSONDecoder().decode(SetRuntimeModelSlotPayload.self, from: Data(#"{"workspacePath":"/tmp/runtime","section":"delegation","key":"delegation","provider":"custom","model":"local/model"}"#.utf8))
        XCTAssertNil(payload.baseUrl)
    }

    func testMCPPayloadsCarryTheSelectedProfileWorkspace() throws {
        let add = AddMCPServerPayload(
            workspacePath: "/tmp/hermes/profiles/work",
            name: "fixture",
            transport: .openAPI,
            command: "",
            arguments: "",
            url: "https://example.test/openapi.json",
            bearerToken: "fixture-secret"
        )
        let decoded = try JSONDecoder().decode(AddMCPServerPayload.self, from: JSONEncoder().encode(add))
        XCTAssertEqual(decoded.workspacePath, "/tmp/hermes/profiles/work")
        XCTAssertEqual(decoded.transport, .openAPI)
    }

    func testMCPInventoryFixtureHasNoCredentialFields() throws {
        let fixture = Data(#"{"workspacePath":"/tmp/hermes","resolvedWorkspacePath":"/tmp/hermes","output":"Loaded selected Hermes profile.","servers":[{"id":"fixture","name":"fixture","transport":"Streamable HTTP","tools":"all","status":"enabled"}]}"#.utf8)
        let decoded = try JSONDecoder().decode(ListMCPServersResult.self, from: fixture)
        XCTAssertEqual(decoded.servers.first?.name, "fixture")
        XCTAssertEqual(decoded.servers.first?.tools, "all")
        XCTAssertEqual(decoded.servers.first?.status, "enabled")
    }
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
