import Foundation
import XCTest
@testable import HermesHostCompanion

final class CompanionSubprocessTests: XCTestCase {
    func testLargeStdoutAndStderrDoNotDeadlock() async throws {
        let result = try await CompanionSubprocess.run(
            executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
            arguments: ["-c", "import sys; sys.stdout.write('o'*1048576); sys.stdout.flush(); sys.stderr.write('e'*1048576); sys.stderr.flush(); assert len(sys.stdin.buffer.read()) == 1048576"],
            input: Data(repeating: 120, count: 1_048_576), timeout: 10)
        XCTAssertEqual(result.status, 0)
        XCTAssertEqual(result.stdout, Data(repeating: 111, count: 1_048_576))
        XCTAssertEqual(result.stderr, Data(repeating: 101, count: 1_048_576))
    }

    func testTimeoutKillsChildIgnoringTermination() async throws {
        let start = ProcessInfo.processInfo.systemUptime
        do {
            _ = try await CompanionSubprocess.run(
                executableURL: URL(fileURLWithPath: "/bin/sh"),
                arguments: ["-c", "trap '' TERM; while :; do :; done"],
                timeout: 0.2, terminationGrace: 0.1)
            XCTFail("Expected timeout")
        } catch CompanionSubprocess.Failure.timedOut { }
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - start, 3)
    }

    @MainActor
    func testWaitingForChildDoesNotBlockMainActor() async throws {
        let child = Task { @MainActor in
            try await CompanionSubprocess.run(executableURL: URL(fileURLWithPath: "/bin/sleep"), arguments: ["1"], timeout: 5)
        }
        let start = ProcessInfo.processInfo.systemUptime
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertLessThan(ProcessInfo.processInfo.systemUptime - start, 0.8)
        let result = try await child.value
        XCTAssertEqual(result.status, 0)
    }
}
