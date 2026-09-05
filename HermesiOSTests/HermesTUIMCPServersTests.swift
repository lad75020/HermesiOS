import XCTest
@testable import HermesiOS

@MainActor
final class HermesTUIMCPServersTests: XCTestCase {
    func testProfileScopedMCPTestSendsExactProfileAndDecodesEveryTool() async throws {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        var requests: [(String, [String: JSONValue])] = []
        store.requestOverride = { method, params in
            requests.append((method, params))
            return .object([
                "ok": .bool(true),
                "tools": .array([
                    .object(["name": .string("first"), "description": .string("First tool")]),
                    .object(["name": .string("second"), "description": .string("Second tool")]),
                    .object(["name": .string("third"), "description": .string("Third tool")])
                ]),
                "prompts": .number(4),
                "resources": .number(2)
            ])
        }

        let result = try await store.testMCPServer(name: "fixture", profileName: "research")

        XCTAssertEqual(requests.map(\.0), ["mcp.servers.test"])
        XCTAssertEqual(requests.first?.1, ["name": .string("fixture"), "profile": .string("research")])
        XCTAssertTrue(result.ok)
        XCTAssertNil(result.error)
        XCTAssertEqual(result.tools, [
            HermesTUIMCPServerTool(name: "first", description: "First tool"),
            HermesTUIMCPServerTool(name: "second", description: "Second tool"),
            HermesTUIMCPServerTool(name: "third", description: "Third tool")
        ])
    }

    func testProfileScopedMCPTestDecodesReportedFailure() throws {
        let result = try HermesTUIMCPServerTestResult.decode(.object([
            "ok": .bool(false),
            "error": .string("Connection timed out"),
            "tools": .array([])
        ]))

        XCTAssertFalse(result.ok)
        XCTAssertEqual(result.error, "Connection timed out")
        XCTAssertTrue(result.tools.isEmpty)
    }

    func testProfileScopedMCPTestRejectsMalformedResponse() {
        let malformed: [JSONValue] = [
            .null,
            .object(["ok": .bool(true)]),
            .object(["ok": .bool(true), "tools": .array([.object(["name": .string("tool")])])]),
            .object(["ok": .bool(false), "tools": .array([])]),
            .object(["ok": .bool(true), "tools": .array([.object(["name": .string(" "), "description": .string("description")])])]),
            .object(["ok": .bool(true), "tools": .array([
                .object(["name": .string("duplicate"), "description": .string("First")]),
                .object(["name": .string("duplicate"), "description": .string("Second")])
            ])])
        ]

        for payload in malformed {
            XCTAssertThrowsError(try HermesTUIMCPServerTestResult.decode(payload))
        }
    }

    func testProfileScopedMCPTestRejectsLateCompletionAfterDisconnect() async {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        var resume: CheckedContinuation<JSONValue, Never>?
        store.requestOverride = { _, _ in
            await withCheckedContinuation { continuation in resume = continuation }
        }

        let request = Task { () -> Error? in
            do {
                _ = try await store.testMCPServer(name: "fixture", profileName: "research")
                return nil
            } catch {
                return error
            }
        }
        while resume == nil { await Task.yield() }
        store.disconnect()
        resume?.resume(returning: .object([
            "ok": .bool(true),
            "tools": .array([.object(["name": .string("late"), "description": .string("Late tool")])])
        ]))

        let error = await request.value
        XCTAssertNotNil(error)
        XCTAssertEqual(store.sessionID, "")
        XCTAssertTrue(store.messages.isEmpty)
    }
}
