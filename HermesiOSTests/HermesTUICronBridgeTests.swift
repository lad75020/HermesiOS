import XCTest
@testable import HermesiOS

@MainActor
final class HermesTUICronBridgeTests: XCTestCase {
    func testCronUsesOnlyStructuredRPCWithoutCreatingConversation() async throws {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        var methods: [String] = []
        store.requestOverride = { method, params in
            methods.append(method)
            XCTAssertEqual(params["profile"], .string("default"))
            XCTAssertNil(params["session_id"])
            return .object(["success": .bool(true), "scoped": .string("default"), "count": .number(0), "jobs": .array([])])
        }
        let client = HermesTUICronClient(request: { try await store.runtimeCronRequest(params: $0) }, generation: { store.runtimeConnectionVersion })
        await client.load(profile: "default")
        XCTAssertEqual(methods, ["cron.manage"])
        XCTAssertTrue(client.hasLoaded)
        XCTAssertTrue(store.sessionID.isEmpty)
        XCTAssertTrue(store.messages.isEmpty)
    }

    func testCreationUsesOnlyCronRPCAndDoesNotCreateConversation() async {
        for profile in ["default", "Research"] {
            let store = HermesTUIGatewayStore()
            store.isConnected = true
            var calls: [(String, [String: JSONValue])] = []
            let job: JSONValue = .object([
                "job_id": .string("created-job"), "name": .string("Morning task"),
                "prompt_preview": .string("Prompt preview"), "schedule": .string("daily at 09:00"),
                "state": .string("scheduled"), "enabled": .bool(true),
                "deliver": .string("local"), "repeat": .string("forever")
            ])
            store.requestOverride = { method, params in
                calls.append((method, params))
                XCTAssertEqual(params["profile"], .string(profile))
                XCTAssertNil(params["session_id"])
                if params["action"] == .string("add") {
                    return .object(["success": .bool(true), "job_id": .string("created-job"), "job": job])
                }
                let rows: [JSONValue] = calls.count == 1 ? [] : [job]
                return .object(["success": .bool(true), "scoped": .string(profile), "count": .number(Double(rows.count)), "jobs": .array(rows)])
            }
            let client = HermesTUICronClient(request: { try await store.runtimeCronRequest(params: $0) }, generation: { store.runtimeConnectionVersion })
            let draft = HermesTUICronDraft(name: "Morning task", prompt: "A full prompt", schedule: "0 9 * * *")
            let created = await client.create(draft: draft, profile: profile)
            XCTAssertTrue(created, client.errorMessage)
            XCTAssertEqual(calls.map(\.0), ["cron.manage", "cron.manage", "cron.manage"])
            XCTAssertEqual(calls.map { $0.1["action"] }, [.string("list"), .string("add"), .string("list")])
            XCTAssertEqual(calls[1].1["prompt"], .string(draft.prompt))
            XCTAssertTrue(store.sessionID.isEmpty)
            XCTAssertTrue(store.messages.isEmpty)
        }
    }

    func testDisconnectRejectsPendingCronResponse() async {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        var pending: CheckedContinuation<JSONValue, Never>?
        store.requestOverride = { _, _ in await withCheckedContinuation { pending = $0 } }
        let task = Task {
            do {
                _ = try await store.runtimeCronRequest(params: ["action": .string("list"), "profile": .string("default"), "include_disabled": .bool(true)])
                return false
            } catch { return true }
        }
        while pending == nil { await Task.yield() }
        let previousVersion = store.runtimeConnectionVersion
        store.disconnect()
        XCTAssertNotEqual(store.runtimeConnectionVersion, previousVersion)
        pending?.resume(returning: .object(["success": .bool(true), "scoped": .string("default"), "count": .number(0), "jobs": .array([])]))
        let rejected = await task.value
        XCTAssertTrue(rejected)
    }

    func testMissingProfileOrUnsupportedActionNeverReachesRPC() async {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        store.requestOverride = { _, _ in
            XCTFail("Invalid cron request must not reach the transport")
            return .null
        }
        for params: [String: JSONValue] in [
            ["action": .string("list")],
            ["action": .string("list"), "profile": .string("")],
            ["action": .string("run"), "profile": .string("default")]
        ] {
            do {
                _ = try await store.runtimeCronRequest(params: params)
                XCTFail("Expected request rejection")
            } catch { }
        }
    }
}
