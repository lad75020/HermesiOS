import Darwin
import Foundation
import XCTest
@testable import HermesHostCompanion

final class CompanionSubprocessTests: XCTestCase {
    func testOutputCaptureIsBoundedWithoutDiskBackedOutputFiles() async throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
        let existingCaptureDirectories = try captureDirectories(in: temporaryDirectory)

        let child = Task {
            try await CompanionSubprocess.run(
                executableURL: URL(fileURLWithPath: "/usr/bin/python3"),
                arguments: [
                    "-c",
                    "import sys,time; sys.stdout.write('o'*8388608); sys.stdout.flush(); sys.stderr.write('e'*8388608); sys.stderr.flush(); time.sleep(0.5)"
                ],
                timeout: 5,
                maxOutputBytes: 4_096
            )
        }

        var createdDiskCapture = false
        for _ in 0..<100 where !child.isCancelled {
            let current = try captureDirectories(in: temporaryDirectory)
            if !current.subtracting(existingCaptureDirectories).isEmpty {
                createdDiskCapture = true
                break
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        let result = try await child.value

        XCTAssertFalse(createdDiskCapture)
        XCTAssertEqual(result.stdout, Data(repeating: 111, count: 4_096))
        XCTAssertEqual(result.stderr, Data(repeating: 101, count: 4_096))
    }

    func testServiceStatusUsesBoundedAsyncSubprocess() async throws {
        let service = CompanionManagedServiceRecord(
            id: "test-service",
            displayName: "Test Service",
            statusCommand: [
                "/usr/bin/python3", "-c",
                "import sys; sys.stdout.write('running\\n' + 'o'*2097152); sys.stderr.write('e'*2097152)"
            ],
            restartCommand: ["/usr/bin/true"],
            startCommand: nil,
            stopCommand: nil
        )
        let registry = CompanionServiceRegistry(
            document: CompanionServiceRegistryDocument(services: [service])
        )

        let result = try await registry.status(for: service.id)

        XCTAssertEqual(result.status.rawValue, CompanionManagedServiceStatus.running.rawValue)
        XCTAssertLessThanOrEqual(result.output.utf8.count, 2_100_000)
    }

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

    func testTimeoutKillsDescendantsInChildProcessGroup() async throws {
        let pidFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("companion-descendant-\(UUID().uuidString).pid")
        defer { try? FileManager.default.removeItem(at: pidFileURL) }

        do {
            _ = try await CompanionSubprocess.run(
                executableURL: URL(fileURLWithPath: "/bin/sh"),
                arguments: [
                    "-c",
                    "trap '' TERM; (trap '' TERM; while :; do sleep 1; done) & child=$!; printf '%s' \"$child\" > \"$1\"; while :; do sleep 1; done",
                    "companion-descendant-test",
                    pidFileURL.path
                ],
                timeout: 0.4,
                terminationGrace: 0.1
            )
            XCTFail("Expected timeout")
        } catch CompanionSubprocess.Failure.timedOut { }

        let descendantPID = try XCTUnwrap(
            Int32(String(decoding: Data(contentsOf: pidFileURL), as: UTF8.self))
        )
        defer { Darwin.kill(descendantPID, SIGKILL) }

        for _ in 0..<100 where processExists(descendantPID) {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertFalse(processExists(descendantPID))
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

    private func captureDirectories(in temporaryDirectory: URL) throws -> Set<String> {
        Set(try FileManager.default.contentsOfDirectory(atPath: temporaryDirectory.path)
            .filter { $0.hasPrefix("companion-process-") })
    }

    private func processExists(_ pid: Int32) -> Bool {
        Darwin.kill(pid, 0) == 0 || errno == EPERM
    }
}
