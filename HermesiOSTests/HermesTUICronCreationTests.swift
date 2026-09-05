import XCTest
@testable import HermesiOS

@MainActor
final class HermesTUICronCreationTests: XCTestCase {
    private let stableGeneration = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    func testCreateUsesExactDraftPromptAndExpectedParametersForDefaultAndNamedProfiles() async {
        let prompt = "  Résumé ‘équipe’\n" + String(repeating: "x", count: 128) + "  "
        for profile in ["default", "équipe \"night\""] {
            var calls: [[String: JSONValue]] = []
            var lists = 0
            let client = HermesTUICronClient(request: { parameters in
                calls.append(parameters)
                if parameters["action"] == .string("add") {
                    return self.receipt(id: "new-1")
                }
                lists += 1
                return self.list(profile: profile, jobs: lists == 1 ? [] : [self.job(id: "new-1")])
            }, generation: { self.stableGeneration })
            let draft = HermesTUICronDraft(name: "  Morning  ", prompt: prompt, schedule: "  0 9 * * *  ", deliver: " local ")

            let created = await client.create(draft: draft, profile: profile)
            XCTAssertTrue(created)
            XCTAssertEqual(calls.map { $0["action"] }, [.string("list"), .string("add"), .string("list")])
            XCTAssertEqual(calls[0], ["action": .string("list"), "profile": .string(profile), "include_disabled": .bool(true)])
            XCTAssertEqual(calls[1], [
                "action": .string("add"), "name": .string("Morning"), "prompt": .string(prompt),
                "schedule": .string("0 9 * * *"), "profile": .string(profile), "deliver": .string("local"),
                "continuity": .bool(false)
            ])
            XCTAssertEqual(calls[2], calls[0])
        }
    }

    func testCreateRepeatIsOmittedForDefaultAndSentAsDigitStringIncludingZero() async {
        for repeatLimit in ["", "0", "12", String(Int.max)] {
            var add: [String: JSONValue] = [:]
            var lists = 0
            let client = HermesTUICronClient(request: { parameters in
                if parameters["action"] == .string("add") {
                    add = parameters
                    return self.receipt(id: "new-1")
                }
                lists += 1
                return self.list(profile: "default", jobs: lists == 1 ? [] : [self.job(id: "new-1")])
            }, generation: { self.stableGeneration })

            let created = await client.create(draft: .init(prompt: "Run", repeatLimit: repeatLimit, continuity: !repeatLimit.isEmpty), profile: "default")
            XCTAssertTrue(created)
            XCTAssertEqual(add["repeat"], repeatLimit.isEmpty ? nil : .string(repeatLimit))
            XCTAssertEqual(add["continuity"], .bool(!repeatLimit.isEmpty))
        }
    }

    func testBlankNameIsAllowed() async {
        var add: [String: JSONValue] = [:]
        var lists = 0
        let client = HermesTUICronClient(request: { parameters in
            if parameters["action"] == .string("add") { add = parameters; return self.receipt(id: "new-1") }
            lists += 1
            return self.list(profile: "default", jobs: lists == 1 ? [] : [self.job(id: "new-1")])
        }, generation: { self.stableGeneration })

        let created = await client.create(draft: .init(prompt: "Run"), profile: "default")
        XCTAssertTrue(created)
        XCTAssertEqual(add["name"], .string(""))
    }

    func testInvalidDraftNeverReachesRPC() async {
        let invalid = [
            HermesTUICronDraft(),
            HermesTUICronDraft(prompt: "  "),
            HermesTUICronDraft(prompt: "Run", schedule: " "),
            HermesTUICronDraft(prompt: "Run", deliver: "\n"),
            HermesTUICronDraft(prompt: "Run", repeatLimit: "-1"),
            HermesTUICronDraft(prompt: "Run", repeatLimit: "١"),
            HermesTUICronDraft(prompt: "Run", repeatLimit: String(repeating: "9", count: 100))
        ]
        for draft in invalid {
            var calls = 0
            let client = HermesTUICronClient(request: { _ in calls += 1; return .null }, generation: { self.stableGeneration })
            let created = await client.create(draft: draft, profile: "default")
            XCTAssertFalse(created)
            XCTAssertEqual(calls, 0)
            XCTAssertFalse(client.errorMessage.isEmpty)
        }
    }

    func testMissingOrWrongPreflightScopePreventsAdd() async {
        let badLists: [JSONValue] = [
            .object(["success": .bool(true), "count": .number(0), "jobs": .array([])]),
            list(profile: "other", jobs: [])
        ]
        for response in badLists {
            var actions: [JSONValue] = []
            let client = HermesTUICronClient(request: { parameters in
                actions.append(parameters["action"]!)
                return response
            }, generation: { self.stableGeneration })
            let created = await client.create(draft: .init(prompt: "Run"), profile: "default")
            XCTAssertFalse(created)
            XCTAssertEqual(actions, [.string("list")])
        }
    }

    func testMalformedOrUnsuccessfulReceiptDoesNotRetry() async {
        let receipts: [JSONValue] = [
            .object(["success": .bool(false)]),
            .object(["success": .bool(true), "job_id": .string("new-1")]),
            .object(["success": .bool(true), "job_id": .string("new-1"), "job": .object(["job_id": .string("other")])])
        ]
        for receipt in receipts {
            var actions: [JSONValue] = []
            let client = HermesTUICronClient(request: { parameters in
                actions.append(parameters["action"]!)
                return parameters["action"] == .string("add") ? receipt : self.list(profile: "default", jobs: [])
            }, generation: { self.stableGeneration })
            let created = await client.create(draft: .init(prompt: "Run"), profile: "default")
            XCTAssertFalse(created)
            XCTAssertEqual(actions, [.string("list"), .string("add")])
            XCTAssertTrue(client.errorMessage.contains("may have succeeded"))
        }
    }

    func testGatewayCreationErrorIsVisibleWithoutAutomaticRetry() async {
        var calls = 0
        let client = HermesTUICronClient(request: { parameters in
            calls += 1
            if parameters["action"] == .string("add") {
                return .object(["success": .bool(false), "error": .string("Invalid schedule expression")])
            }
            return self.list(profile: "default", jobs: [])
        }, generation: { self.stableGeneration })
        let created = await client.create(draft: .init(prompt: "Run", schedule: "invalid"), profile: "default")
        XCTAssertFalse(created)
        XCTAssertEqual(calls, 2)
        XCTAssertTrue(client.errorMessage.contains("Invalid schedule expression"))
        XCTAssertFalse(client.hasLoaded)
    }

    func testExistingReceiptIDAndWrongReadbackScopeCannotClaimCreation() async {
        for existingID in [false, true] {
            var calls = 0
            let client = HermesTUICronClient(request: { parameters in
                calls += 1
                if parameters["action"] == .string("add") { return self.receipt(id: "new-1") }
                if calls == 1 {
                    return self.list(profile: "default", jobs: existingID ? [self.job(id: "new-1")] : [])
                }
                return self.list(profile: "other", jobs: [self.job(id: "new-1")])
            }, generation: { self.stableGeneration })
            let created = await client.create(draft: .init(prompt: "Run"), profile: "default")
            XCTAssertFalse(created)
            XCTAssertEqual(calls, existingID ? 2 : 3)
            XCTAssertFalse(client.hasLoaded)
            XCTAssertTrue(client.errorMessage.contains("may have succeeded"))
        }
    }

    func testReadbackMustContainNewIDAndCreationWarningIsPreserved() async {
        var calls = 0
        let client = HermesTUICronClient(request: { parameters in
            calls += 1
            if parameters["action"] == .string("add") { return self.receipt(id: "new-1", warning: "Gateway is not running.") }
            return self.list(profile: "default", jobs: calls == 1 ? [] : [self.job(id: "new-1")])
        }, generation: { self.stableGeneration })
        let created = await client.create(draft: .init(prompt: "Run"), profile: "default")
        XCTAssertTrue(created)
        XCTAssertEqual(client.warning, "Gateway is not running.")

        var missingCalls = 0
        let missing = HermesTUICronClient(request: { parameters in
            missingCalls += 1
            return parameters["action"] == .string("add") ? self.receipt(id: "new-1") : self.list(profile: "default", jobs: [])
        }, generation: { self.stableGeneration })
        let missingCreated = await missing.create(draft: .init(prompt: "Run"), profile: "default")
        XCTAssertFalse(missingCreated)
        XCTAssertEqual(missingCalls, 3)
        XCTAssertTrue(missing.errorMessage.contains("may have succeeded"))
    }

    func testGenerationAndCancellationAtEachPhasePreventPublishing() async {
        enum Phase: Equatable { case preflight, add, readback }
        for phase in [Phase.preflight, .add, .readback] {
            var generation = stableGeneration
            var calls = 0
            var actions: [String] = []
            let changed = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
            let client = HermesTUICronClient(request: { parameters in
                calls += 1
                actions.append(parameters["action"]?.stringValue ?? "")
                if (phase == .preflight && calls == 1) || (phase == .add && parameters["action"] == .string("add")) || (phase == .readback && calls == 3) {
                    generation = changed
                }
                return parameters["action"] == .string("add") ? self.receipt(id: "new-1") : self.list(profile: "default", jobs: calls == 1 ? [] : [self.job(id: "new-1")])
            }, generation: { generation })
            let created = await client.create(draft: .init(prompt: "Run"), profile: "default")
            XCTAssertFalse(created)
            XCTAssertFalse(client.hasLoaded)
            XCTAssertEqual(calls, phase == .preflight ? 1 : phase == .add ? 2 : 3)
            XCTAssertEqual(actions, phase == .preflight ? ["list"] : phase == .add ? ["list", "add"] : ["list", "add", "list"])
        }
    }

    func testCancellationAtEachPhasePreventsPublishing() async {
        enum Phase: Equatable { case preflight, add, readback }
        for phase in [Phase.preflight, .add, .readback] {
            var calls = 0
            var actions: [String] = []
            var pending: CheckedContinuation<JSONValue, Never>?
            let client = HermesTUICronClient(request: { parameters in
                calls += 1
                actions.append(parameters["action"]?.stringValue ?? "")
                let shouldPause = (phase == .preflight && calls == 1)
                    || (phase == .add && parameters["action"] == .string("add"))
                    || (phase == .readback && calls == 3)
                if shouldPause {
                    return await withCheckedContinuation { pending = $0 }
                }
                return parameters["action"] == .string("add")
                    ? self.receipt(id: "new-1")
                    : self.list(profile: "default", jobs: calls == 1 ? [] : [self.job(id: "new-1")])
            }, generation: { self.stableGeneration })
            let task = Task { await client.create(draft: .init(prompt: "Run"), profile: "default") }
            while pending == nil { await Task.yield() }
            task.cancel()
            pending?.resume(returning: phase == .add ? receipt(id: "new-1") : list(profile: "default", jobs: []))
            let created = await task.value
            XCTAssertFalse(created)
            XCTAssertFalse(client.hasLoaded)
            XCTAssertFalse(client.isBusy)
            XCTAssertEqual(actions, phase == .preflight ? ["list"] : phase == .add ? ["list", "add"] : ["list", "add", "list"])
        }
    }

    func testDoubleSubmitWhileAddIsPendingSendsOnlyOneAdd() async {
        var addContinuation: CheckedContinuation<JSONValue, Never>?
        var calls: [[String: JSONValue]] = []
        var lists = 0
        let client = HermesTUICronClient(request: { parameters in
            calls.append(parameters)
            if parameters["action"] == .string("add") {
                return await withCheckedContinuation { addContinuation = $0 }
            }
            lists += 1
            return self.list(profile: "default", jobs: lists == 1 ? [] : [self.job(id: "new-1")])
        }, generation: { self.stableGeneration })
        let first = Task { await client.create(draft: .init(prompt: "Run"), profile: "default") }
        while addContinuation == nil { await Task.yield() }
        let second = await client.create(draft: .init(prompt: "Run"), profile: "default")
        XCTAssertFalse(second)
        XCTAssertEqual(calls.filter { $0["action"] == .string("add") }.count, 1)
        addContinuation?.resume(returning: receipt(id: "new-1"))
        let firstResult = await first.value
        XCTAssertTrue(firstResult)
    }

    private func list(profile: String, jobs: [JSONValue]) -> JSONValue {
        .object(["success": .bool(true), "scoped": .string(profile), "count": .number(Double(jobs.count)), "jobs": .array(jobs)])
    }

    private func receipt(id: String, warning: String? = nil) -> JSONValue {
        var value: [String: JSONValue] = ["success": .bool(true), "job_id": .string(id), "job": .object(["job_id": .string(id)])]
        if let warning { value["warning"] = .string(warning) }
        return .object(value)
    }

    private func job(id: String) -> JSONValue {
        .object(["job_id": .string(id), "name": .string("Hourly"), "prompt_preview": .string("Run"), "schedule": .string("hourly"), "state": .string("scheduled"), "enabled": .bool(true), "deliver": .string("local"), "repeat": .string("forever"), "next_run_at": .null, "last_run_at": .null, "model": .null, "provider": .null])
    }
}
