import XCTest
@testable import HermesiOS

@MainActor
final class HermesTUICronTests: XCTestCase {
    func testLoadUsesExplicitDefaultAndNamedProfilesIncludingDisabledJobs() async {
        var requests: [[String: JSONValue]] = []
        let client = HermesTUICronClient(request: { params in
            requests.append(params)
            let profile = params["profile"]?.stringValue ?? ""
            return self.list(profile: profile, jobs: [self.job(id: profile)])
        }, generation: { UUID(uuidString: "00000000-0000-0000-0000-000000000001")! })

        await client.load(profile: "default")
        await client.load(profile: "research")

        XCTAssertEqual(requests.map { $0["profile"] }, [.string("default"), .string("research")])
        XCTAssertTrue(requests.allSatisfy { $0["action"] == .string("list") && $0["include_disabled"] == .bool(true) })
        XCTAssertEqual(client.jobs.map(\.id), ["research"])
        XCTAssertTrue(client.hasLoaded)
    }

    func testPauseUsesPreflightThenNameReceiptAndReadback() async {
        var requests: [[String: JSONValue]] = []
        var listCount = 0
        let client = HermesTUICronClient(request: { params in
            requests.append(params)
            if params["action"] == .string("pause") {
                return .object(["success": .bool(true), "job": self.job(id: "job-1")])
            }
            listCount += 1
            return self.list(profile: "default", jobs: [self.job(id: "job-1", state: listCount == 1 ? "scheduled" : "paused", enabled: listCount == 1)])
        }, generation: { UUID(uuidString: "00000000-0000-0000-0000-000000000001")! })

        await client.mutate(action: .pause, jobID: "job-1", profile: "default")

        XCTAssertEqual(requests.map { $0["action"] }, [.string("list"), .string("pause"), .string("list")])
        XCTAssertEqual(requests[1], ["action": .string("pause"), "name": .string("job-1"), "profile": .string("default")])
        XCTAssertFalse(client.jobs[0].enabled)
        XCTAssertEqual(client.jobs[0].state, "paused")
        XCTAssertTrue(client.hasLoaded)
    }

    func testResumeAndRemoveValidateReceiptsAndReadback() async {
        for action in [HermesTUICronAction.resume, .remove] {
            var listCount = 0
            let client = HermesTUICronClient(request: { params in
                if params["action"] == .string(action.rawValue) {
                    return action == .remove
                        ? .object(["success": .bool(true), "removed_job": .object(["id": .string("job-1")])])
                        : .object(["success": .bool(true), "job": self.job(id: "job-1")])
                }
                listCount += 1
                let first = action == .resume ? self.job(id: "job-1", state: "paused", enabled: false) : self.job(id: "job-1")
                let final = action == .resume ? self.job(id: "job-1", state: "scheduled", enabled: true) : nil
                return self.list(profile: "named", jobs: listCount == 1 ? [first] : final.map { [$0] } ?? [])
            }, generation: { UUID(uuidString: "00000000-0000-0000-0000-000000000001")! })

            await client.mutate(action: action, jobID: "job-1", profile: "named")

            XCTAssertTrue(client.hasLoaded, "\(action)")
            XCTAssertEqual(client.jobs.count, action == .remove ? 0 : 1)
        }
    }

    func testMalformedScopedTotalsDuplicatesAndMissingScopedDoNotReplacePriorJobs() async {
        let malformed: [JSONValue] = [
            .object(["success": .bool(true), "scoped": .string("default"), "count": .number(2), "jobs": .array([job(id: "one")])]),
            .object(["success": .bool(true), "scoped": .string("default"), "count": .number(2), "jobs": .array([job(id: "one"), job(id: "one")])]),
            .object(["success": .bool(true), "count": .number(0), "jobs": .array([])])
        ]
        for payload in malformed {
            var requests = 0
            let generation = UUID()
            let client = HermesTUICronClient(request: { _ in
                requests += 1
                return requests == 1 ? self.list(profile: "default", jobs: [self.job(id: "prior")]) : payload
            }, generation: { generation })
            await client.load(profile: "default")
            XCTAssertTrue(client.hasLoaded)
            await client.load(profile: "default")
            XCTAssertFalse(client.hasLoaded)
            XCTAssertEqual(requests, 2)
            XCTAssertEqual(client.jobs.map(\.id), ["prior"])
            XCTAssertFalse(client.errorMessage.isEmpty)
        }
    }

    func testSuccessFalseAndMissingScopedProofPreventMutation() async {
        var actions: [String] = []
        let client = HermesTUICronClient(request: { params in
            actions.append(params["action"]?.stringValue ?? "")
            return .object(["success": .bool(false), "scoped": .string("default"), "count": .number(1), "jobs": .array([self.job(id: "job-1")])])
        }, generation: { UUID(uuidString: "00000000-0000-0000-0000-000000000001")! })

        await client.mutate(action: .pause, jobID: "job-1", profile: "default")

        XCTAssertEqual(actions, ["list"])
        XCTAssertFalse(client.hasLoaded)
        XCTAssertFalse(client.errorMessage.isEmpty)
    }

    func testSuccessFalseMutationReceiptLeavesPriorListStale() async {
        var calls = 0
        let client = HermesTUICronClient(request: { params in
            calls += 1
            if params["action"] == .string("pause") { return .object(["success": .bool(false)]) }
            return self.list(profile: "default", jobs: [self.job(id: "job-1")])
        }, generation: { UUID(uuidString: "00000000-0000-0000-0000-000000000001")! })
        await client.load(profile: "default")
        await client.mutate(action: .pause, jobID: "job-1", profile: "default")

        XCTAssertEqual(calls, 3)
        XCTAssertEqual(client.jobs.map(\.id), ["job-1"])
        XCTAssertFalse(client.hasLoaded)
    }

    func testThrownRPCErrorPreservesPriorJobsAsStale() async {
        struct FixtureError: LocalizedError { var errorDescription: String? { "cron RPC failed" } }
        var fail = false
        let client = HermesTUICronClient(request: { _ in
            if fail { throw FixtureError() }
            return self.list(profile: "default", jobs: [self.job(id: "job-1")])
        }, generation: { UUID(uuidString: "00000000-0000-0000-0000-000000000001")! })

        await client.load(profile: "default")
        fail = true
        await client.load(profile: "default")

        XCTAssertEqual(client.jobs.map(\.id), ["job-1"])
        XCTAssertFalse(client.hasLoaded)
        XCTAssertTrue(client.errorMessage.contains("cron RPC failed"))
    }

    func testReadbackMismatchDoesNotClaimPauseSucceeded() async {
        var phase = 0
        let client = HermesTUICronClient(request: { params in
            if params["action"] == .string("pause") {
                return .object(["success": .bool(true), "job": self.job(id: "job-1")])
            }
            phase += 1
            return self.list(profile: "default", jobs: [self.job(id: "job-1")])
        }, generation: { UUID(uuidString: "00000000-0000-0000-0000-000000000001")! })

        await client.load(profile: "default")
        await client.mutate(action: .pause, jobID: "job-1", profile: "default")

        XCTAssertEqual(phase, 3)
        XCTAssertEqual(client.jobs.map(\.id), ["job-1"])
        XCTAssertTrue(client.jobs[0].enabled)
        XCTAssertFalse(client.hasLoaded)
    }

    func testCancellationAndGenerationChangesRejectLateLists() async {
        var continuation: CheckedContinuation<JSONValue, Never>?
        var connection = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let client = HermesTUICronClient(request: { _ in
            await withCheckedContinuation { continuation = $0 }
        }, generation: { connection })

        let task = Task { await client.load(profile: "default") }
        while continuation == nil { await Task.yield() }
        connection = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        continuation?.resume(returning: self.list(profile: "default", jobs: [self.job(id: "late")]))
        await task.value
        XCTAssertFalse(client.hasLoaded)
        XCTAssertTrue(client.jobs.isEmpty)

        var cancelled: CheckedContinuation<JSONValue, Never>?
        let cancellationClient = HermesTUICronClient(request: { _ in
            await withCheckedContinuation { cancelled = $0 }
        }, generation: { UUID(uuidString: "00000000-0000-0000-0000-000000000001")! })
        let cancelledTask = Task { await cancellationClient.load(profile: "default") }
        while cancelled == nil { await Task.yield() }
        cancelledTask.cancel()
        cancelled?.resume(returning: self.list(profile: "default", jobs: [self.job(id: "late")]))
        await cancelledTask.value
        XCTAssertFalse(cancellationClient.hasLoaded)
        XCTAssertTrue(cancellationClient.jobs.isEmpty)
    }

    func testGenerationABASpanningMutationPreflightPreventsWrite() async {
        let a = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let b = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        var sequence = [a, a, b, a]
        var actions: [String] = []
        let client = HermesTUICronClient(request: { params in
            actions.append(params["action"]?.stringValue ?? "")
            return self.list(profile: "default", jobs: [self.job(id: "job-1")])
        }, generation: { sequence.removeFirst() })

        await client.mutate(action: .pause, jobID: "job-1", profile: "default")

        XCTAssertEqual(actions, ["list"])
        XCTAssertFalse(client.hasLoaded)
    }

    func testMismatchedProfileAndMalformedJobPreventMutation() async {
        var malformed = job(id: "job-1").objectValue
        malformed["enabled"] = .string("true")
        let responses: [JSONValue] = [
            list(profile: "another-profile", jobs: [job(id: "job-1")]),
            list(profile: "default", jobs: [.object(malformed)]),
            .object(["success": .bool(true), "count": .number(1), "jobs": .array([job(id: "job-1")])])
        ]
        for response in responses {
            var actions: [JSONValue] = []
            let generation = UUID()
            let client = HermesTUICronClient(request: { params in
                actions.append(params["action"]!)
                return response
            }, generation: { generation })
            await client.mutate(action: .remove, jobID: "job-1", profile: "default")
            XCTAssertEqual(actions, [.string("list")])
            XCTAssertFalse(client.hasLoaded)
        }
    }

    func testCompletedPausedAndErrorJobsRemainVisibleWithWarning() async {
        let generation = UUID()
        let client = HermesTUICronClient(request: { _ in
            var response = self.list(profile: "default", jobs: [
                self.job(id: "done", state: "completed", enabled: false),
                self.job(id: "paused", state: "paused", enabled: false),
                self.job(id: "error", state: "error", enabled: true)
            ]).objectValue
            response["warning"] = .string("Scheduler is not running.")
            return .object(response)
        }, generation: { generation })
        await client.load(profile: "default")
        XCTAssertTrue(client.hasLoaded)
        XCTAssertEqual(client.jobs.map(\.state), ["completed", "paused", "error"])
        XCTAssertEqual(client.warning, "Scheduler is not running.")
    }

    func testMismatchedReceiptDoesNotClaimSuccessOrRetry() async {
        for action in [HermesTUICronAction.pause, .resume, .remove] {
            var calls = 0
            let generation = UUID()
            let client = HermesTUICronClient(request: { params in
                calls += 1
                if params["action"] == .string("list") {
                    return self.list(profile: "default", jobs: [self.job(id: "job-1", state: action == .resume ? "paused" : "scheduled", enabled: action != .resume)])
                }
                return .object(["success": .bool(true), "job": self.job(id: "wrong"), "removed_job": .object(["id": .string("wrong")])])
            }, generation: { generation })
            await client.mutate(action: action, jobID: "job-1", profile: "default")
            XCTAssertEqual(calls, 2)
            XCTAssertFalse(client.hasLoaded)
            XCTAssertFalse(client.errorMessage.isEmpty)
        }
    }

    func testConcurrentRefreshDoesNotIssueAnotherRequest() async {
        let generation = UUID()
        var pending: CheckedContinuation<JSONValue, Never>?
        var calls = 0
        let client = HermesTUICronClient(request: { _ in
            calls += 1
            return await withCheckedContinuation { pending = $0 }
        }, generation: { generation })
        let first = Task { await client.load(profile: "default") }
        while pending == nil { await Task.yield() }
        await client.load(profile: "default")
        XCTAssertEqual(calls, 1)
        pending?.resume(returning: list(profile: "default", jobs: []))
        await first.value
        XCTAssertTrue(client.hasLoaded)
        XCTAssertFalse(client.isBusy)
    }

    private func list(profile: String, jobs: [JSONValue]) -> JSONValue {
        .object(["success": .bool(true), "scoped": .string(profile), "count": .number(Double(jobs.count)), "jobs": .array(jobs)])
    }

    private func job(id: String, state: String = "scheduled", enabled: Bool = true) -> JSONValue {
        .object([
            "job_id": .string(id), "name": .string("Hourly brief"), "prompt_preview": .string("Summarize."),
            "schedule": .string("every hour"), "state": .string(state), "enabled": .bool(enabled),
            "deliver": .string("local"), "repeat": .string("forever"), "next_run_at": .null,
            "last_run_at": .null, "model": .null, "provider": .null
        ])
    }
}
