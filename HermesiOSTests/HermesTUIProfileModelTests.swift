import XCTest
@testable import HermesiOS

@MainActor
final class HermesTUIProfileModelTests: XCTestCase {
    private let version = UUID()
    private func snapshot(_ profile: String = "default", provider: String = "ollama", model: String = "fixture-model") -> JSONValue {
        .object(["name": .string(profile), "model": .object(["provider": .string(provider), "default": .string(model)]), "soul": .string("ignored")])
    }
    private var receipt: JSONValue { .object(["ok": .bool(true), "applied": .object(["model": .bool(true)])]) }
    private var warning: JSONValue { .object(["ok": .bool(true), "applied": .object([:]), "confirm_required": .bool(true), "confirm_message": .string("Fixture cost warning")]) }

    func testDecodeRequiresExactProfileAndTypedModelButAllowsUnsetFields() throws {
        XCTAssertThrowsError(try HermesTUIProfileModel.decode(snapshot("research"), profile: "Research"))
        for value in [JSONValue.null, .object(["name": .string("default")]), .object(["name": .string("default"), "model": .object(["provider": .bool(true), "default": .string("x")])])] {
            XCTAssertThrowsError(try HermesTUIProfileModel.decode(value, profile: "default"))
        }
        let empty = try HermesTUIProfileModel.decode(snapshot(provider: "", model: ""), profile: "default")
        XCTAssertEqual(empty.model, "")
    }

    func testSaveUsesOnlyExplicitProfileDescribeConfigureReadback() async {
        for profile in ["default", "research"] {
            var calls: [(String, [String: JSONValue])] = []
            let client = HermesTUIProfileModelClient(request: { method, params in
                calls.append((method, params))
                return method == "profiles.describe" ? self.snapshot(profile) : self.receipt
            }, generation: { self.version })
            await client.save(profile: profile, provider: "ollama", model: "fixture-model")
            XCTAssertTrue(client.saved)
            XCTAssertEqual(calls.map(\.0), ["profiles.describe", "profiles.configure", "profiles.describe"])
            XCTAssertEqual(calls[1].1, ["name": .string(profile), "provider": .string("ollama"), "model": .string("fixture-model"), "confirm_expensive_model": .bool(false)])
            XCTAssertEqual(calls[0].1, ["name": .string(profile)])
            XCTAssertEqual(calls[2].1, calls[0].1)
        }
    }

    func testInvalidDraftAndWrongPreflightNeverWrite() async {
        var calls: [String] = []
        let client = HermesTUIProfileModelClient(request: { method, _ in calls.append(method); return self.snapshot("other") }, generation: { self.version })
        for profile in ["", " default", "default\n"] {
            await client.save(profile: profile, provider: "ollama", model: "fixture-model")
        }
        for model in ["", " fixture-model"] {
            await client.save(profile: "default", provider: "ollama", model: model)
        }
        XCTAssertTrue(calls.isEmpty)
        await client.save(profile: "default", provider: "ollama", model: "fixture-model")
        XCTAssertEqual(calls, ["profiles.describe"])
        XCTAssertFalse(client.saved)
    }

    func testWarningRequiresExplicitMatchingConfirmationAndVerifiedReadback() async {
        var writes: [[String: JSONValue]] = []
        let client = HermesTUIProfileModelClient(request: { method, params in
            if method == "profiles.describe" { return self.snapshot() }
            writes.append(params)
            return params["confirm_expensive_model"] == .bool(true) ? self.receipt : self.warning
        }, generation: { self.version })
        await client.save(profile: "default", provider: "ollama", model: "fixture-model")
        XCTAssertFalse(client.saved)
        XCTAssertEqual(client.confirmationMessage, "Fixture cost warning")
        XCTAssertEqual(writes.count, 1)
        await client.save(profile: "default", provider: "ollama", model: "fixture-model", confirmWarning: true)
        XCTAssertTrue(client.saved)
        XCTAssertEqual(writes.count, 2)
        XCTAssertEqual(writes.last?["confirm_expensive_model"], .bool(true))
    }

    func testConfirmationCannotBeReusedForDifferentDraftOrConnection() async {
        for changeConnection in [false, true] {
            var generation = version
            var writes = 0
            let client = HermesTUIProfileModelClient(request: { method, _ in
                if method == "profiles.describe" { return self.snapshot() }
                writes += 1
                return self.warning
            }, generation: { generation })
            await client.save(profile: "default", provider: "ollama", model: "fixture-model")
            if changeConnection { generation = UUID() }
            await client.save(profile: "default", provider: "ollama", model: changeConnection ? "fixture-model" : "other", confirmWarning: true)
            XCTAssertEqual(writes, 1)
            XCTAssertFalse(client.saved)
            XCTAssertTrue(client.confirmationMessage.isEmpty)
        }
    }

    func testFalseMalformedReceiptAndDifferentReadbackNeverClaimSuccessOrRetry() async {
        for badReceipt in [JSONValue.null, .object(["ok": .bool(false)]), .object(["ok": .bool(true), "applied": .object([:])]), receipt] {
            var writes = 0
            let client = HermesTUIProfileModelClient(request: { method, _ in
                if method == "profiles.describe" { return self.snapshot(model: "different") }
                writes += 1
                return badReceipt
            }, generation: { self.version })
            await client.save(profile: "default", provider: "ollama", model: "fixture-model")
            XCTAssertFalse(client.saved)
            XCTAssertEqual(writes, 1)
            XCTAssertTrue(client.errorMessage.contains("may already have been saved"))
        }
    }

    func testGenerationChangeOrCancellationAtEveryPhaseRejectsLateResponse() async {
        for phase in 1...3 {
            for cancel in [false, true] {
                var generation = version
                var calls = 0
                var pending: CheckedContinuation<JSONValue, Never>?
                let client = HermesTUIProfileModelClient(request: { method, _ in
                    calls += 1
                    if calls == phase { return await withCheckedContinuation { pending = $0 } }
                    return method == "profiles.describe" ? self.snapshot() : self.receipt
                }, generation: { generation })
                let task = Task { await client.save(profile: "default", provider: "ollama", model: "fixture-model") }
                while pending == nil { await Task.yield() }
                if cancel { task.cancel() } else { generation = UUID() }
                pending?.resume(returning: phase == 2 ? receipt : snapshot())
                await task.value
                XCTAssertEqual(calls, phase)
                XCTAssertFalse(client.saved)
                XCTAssertFalse(client.isBusy)
                XCTAssertFalse(client.errorMessage.isEmpty)
            }
        }
    }

    func testConcurrentSaveDoesNotDispatchSecondWriteAndThrownErrorIsNotRetried() async {
        var writes = 0
        var pending: CheckedContinuation<JSONValue, Never>?
        let client = HermesTUIProfileModelClient(request: { method, _ in
            if method == "profiles.describe" { return self.snapshot() }
            writes += 1
            return await withCheckedContinuation { pending = $0 }
        }, generation: { self.version })
        let first = Task { await client.save(profile: "default", provider: "ollama", model: "fixture-model") }
        while pending == nil { await Task.yield() }
        await client.save(profile: "default", provider: "ollama", model: "other")
        XCTAssertEqual(writes, 1)
        pending?.resume(returning: receipt)
        await first.value
        XCTAssertTrue(client.saved)
        let failing = HermesTUIProfileModelClient(request: { method, _ in
            if method == "profiles.describe" { return self.snapshot() }
            throw HermesTUIGatewayError.notConnected
        }, generation: { self.version })
        await failing.save(profile: "default", provider: "ollama", model: "fixture-model")
        XCTAssertFalse(failing.saved)
        XCTAssertTrue(failing.errorMessage.contains("may already have been saved"))
    }

    func testLoadIsReadOnlyAndFailedReloadClearsSnapshot() async {
        var fail = false
        var calls: [String] = []
        let client = HermesTUIProfileModelClient(request: { method, _ in
            calls.append(method)
            if fail { throw HermesTUIGatewayError.notConnected }
            return self.snapshot()
        }, generation: { self.version })
        await client.load(profile: "default")
        XCTAssertNotNil(client.snapshot)
        fail = true
        await client.load(profile: "default")
        XCTAssertNil(client.snapshot)
        XCTAssertFalse(client.saved)
        XCTAssertEqual(calls, ["profiles.describe", "profiles.describe"])
    }

    func testStoreBridgeDoesNotCreateChatAndRejectsDisconnectAndUnsupportedRPC() async throws {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        var calls: [String] = []
        store.requestOverride = { method, params in
            calls.append(method)
            XCTAssertEqual(params, ["name": .string("default")])
            return self.snapshot()
        }
        _ = try await store.runtimeProfileModelRequest(method: "profiles.describe", params: ["name": .string("default")])
        do {
            _ = try await store.runtimeProfileModelRequest(method: "profiles.activate", params: ["name": .string("default")])
            XCTFail("Unsupported RPC")
        } catch { }
        store.disconnect()
        do {
            _ = try await store.runtimeProfileModelRequest(method: "profiles.describe", params: ["name": .string("default")])
            XCTFail("Disconnected RPC")
        } catch { }
        XCTAssertEqual(calls, ["profiles.describe"])
        XCTAssertTrue(store.sessionID.isEmpty)
        XCTAssertTrue(store.messages.isEmpty)
    }
}
