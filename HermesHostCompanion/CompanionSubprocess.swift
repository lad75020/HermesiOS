import Darwin
import Foundation

/// No pipes: even simultaneous large stdin/stdout/stderr cannot deadlock. Only
/// immutable request values cross executors; Process and file handles stay local.
enum CompanionSubprocess {
    struct Output: Sendable {
        let status: Int32
        let stdout: Data
        let stderr: Data
    }
    enum Failure: LocalizedError {
        case timedOut
        var errorDescription: String? { "Hermes subprocess timed out." }
    }

    @concurrent
    static func run(executableURL: URL, arguments: [String], environment: [String: String]? = nil,
                    input: Data = Data(), timeout: TimeInterval = 30,
                    terminationGrace: TimeInterval = 0.5) async throws -> Output {
        try Task.checkCancellation()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("companion-process-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                                              attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        func file(_ name: String, data: Data = Data()) throws -> FileHandle {
            let url = directory.appendingPathComponent(name)
            guard FileManager.default.createFile(atPath: url.path, contents: data, attributes: [.posixPermissions: 0o600]) else {
                throw CocoaError(.fileWriteUnknown)
            }
            let handle = try FileHandle(forUpdating: url)
            // Unlink immediately: request secrets never remain at a named path,
            // and abnormal exits cannot leave credential-bearing temp files.
            try FileManager.default.removeItem(at: url)
            return handle
        }
        let stdin = try file("stdin", data: input)
        defer { try? stdin.close() }
        let stdout = try file("stdout")
        defer { try? stdout.close() }
        let stderr = try file("stderr")
        defer { try? stderr.close() }
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.environment = environment
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        let deadline = ProcessInfo.processInfo.systemUptime + max(0, timeout)
        var cancelled = false
        while process.isRunning && ProcessInfo.processInfo.systemUptime < deadline {
            do { try await Task.sleep(for: .milliseconds(10)) }
            catch { cancelled = true; break }
        }
        if process.isRunning {
            process.terminate()
            let graceDeadline = ProcessInfo.processInfo.systemUptime + max(0, terminationGrace)
            // Cancellation must not skip cleanup or turn into a busy wait.
            while process.isRunning && ProcessInfo.processInfo.systemUptime < graceDeadline {
                await pauseForCleanup()
            }
            if process.isRunning { Darwin.kill(process.processIdentifier, SIGKILL) }
            let killDeadline = ProcessInfo.processInfo.systemUptime + max(0.1, terminationGrace)
            while process.isRunning && ProcessInfo.processInfo.systemUptime < killDeadline {
                await pauseForCleanup()
            }
            if cancelled { throw CancellationError() }
            throw Failure.timedOut
        }
        try Task.checkCancellation()
        try stdout.seek(toOffset: 0)
        try stderr.seek(toOffset: 0)
        return Output(status: process.terminationStatus,
                      stdout: try stdout.readToEnd() ?? Data(), stderr: try stderr.readToEnd() ?? Data())
    }

    private static func pauseForCleanup() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(10)) {
                continuation.resume()
            }
        }
    }
}
