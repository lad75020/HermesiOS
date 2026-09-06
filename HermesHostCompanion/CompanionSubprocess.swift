import Darwin
import Foundation

/// Runs each child in its own process group. stdout and stderr are drained
/// concurrently into bounded memory so neither pipes nor disk can grow without
/// limit. Only immutable request values cross executors.
enum CompanionSubprocess {
    static let defaultMaxOutputBytes = 1_048_576
    private static let readBufferBytes = 64 * 1_024

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
                    currentDirectoryURL: URL? = nil, input: Data = Data(), timeout: TimeInterval = 30,
                    maxOutputBytes: Int = defaultMaxOutputBytes,
                    terminationGrace: TimeInterval = 0.5) async throws -> Output {
        try Task.checkCancellation()

        var ownedDescriptors = Set<Int32>()
        defer {
            for descriptor in ownedDescriptors {
                Darwin.close(descriptor)
            }
        }
        let stdinPipe = try makePipe(suppressBrokenPipeSignal: true)
        ownedDescriptors.formUnion([stdinPipe.read, stdinPipe.write])
        let stdoutPipe = try makePipe()
        ownedDescriptors.formUnion([stdoutPipe.read, stdoutPipe.write])
        let stderrPipe = try makePipe()
        ownedDescriptors.formUnion([stderrPipe.read, stderrPipe.write])

        var fileActions: posix_spawn_file_actions_t?
        try checkPOSIX(posix_spawn_file_actions_init(&fileActions), operation: "initialize spawn file actions")
        defer { posix_spawn_file_actions_destroy(&fileActions) }

        try checkPOSIX(posix_spawn_file_actions_adddup2(&fileActions, stdinPipe.read, STDIN_FILENO),
                       operation: "configure child stdin")
        try checkPOSIX(posix_spawn_file_actions_adddup2(&fileActions, stdoutPipe.write, STDOUT_FILENO),
                       operation: "configure child stdout")
        try checkPOSIX(posix_spawn_file_actions_adddup2(&fileActions, stderrPipe.write, STDERR_FILENO),
                       operation: "configure child stderr")
        for descriptor in ownedDescriptors {
            try checkPOSIX(posix_spawn_file_actions_addclose(&fileActions, descriptor),
                           operation: "close inherited subprocess descriptor")
        }
        if let currentDirectoryURL {
            try checkPOSIX(
                currentDirectoryURL.withUnsafeFileSystemRepresentation { path in
                    guard let path else { return EINVAL }
                    return posix_spawn_file_actions_addchdir(&fileActions, path)
                },
                operation: "configure child working directory"
            )
        }

        var attributes: posix_spawnattr_t?
        try checkPOSIX(posix_spawnattr_init(&attributes), operation: "initialize spawn attributes")
        defer { posix_spawnattr_destroy(&attributes) }
        try checkPOSIX(posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP)),
                       operation: "configure child process group")
        try checkPOSIX(posix_spawnattr_setpgroup(&attributes, 0),
                       operation: "configure child process group identifier")

        let executablePath = executableURL.path
        let argumentValues = [executablePath] + arguments
        let environmentValues = (environment ?? ProcessInfo.processInfo.environment)
            .map { "\($0.key)=\($0.value)" }
            .sorted()
        var childPID: pid_t = 0
        let spawnResult = withMutableCStringArray(argumentValues) { argumentPointers in
            withMutableCStringArray(environmentValues) { environmentPointers in
                executablePath.withCString { executablePointer in
                    posix_spawn(
                        &childPID,
                        executablePointer,
                        &fileActions,
                        &attributes,
                        argumentPointers,
                        environmentPointers
                    )
                }
            }
        }
        try checkPOSIX(spawnResult, operation: "launch subprocess")

        closeOwned(stdinPipe.read, ownedDescriptors: &ownedDescriptors)
        closeOwned(stdoutPipe.write, ownedDescriptors: &ownedDescriptors)
        closeOwned(stderrPipe.write, ownedDescriptors: &ownedDescriptors)

        let stdinWriter = transfer(stdinPipe.write, ownedDescriptors: &ownedDescriptors)
        let stdoutReader = transfer(stdoutPipe.read, ownedDescriptors: &ownedDescriptors)
        let stderrReader = transfer(stderrPipe.read, ownedDescriptors: &ownedDescriptors)
        let outputLimit = max(0, maxOutputBytes)

        async let inputWrite: Void = writeAndClose(input, to: stdinWriter)
        async let stdoutCapture: Data = drainAndClose(stdoutReader, retainingAtMost: outputLimit)
        async let stderrCapture: Data = drainAndClose(stderrReader, retainingAtMost: outputLimit)

        let deadline = ProcessInfo.processInfo.systemUptime + max(0, timeout)
        var waitStatus: Int32 = 0
        var wasReaped = false
        var wasCancelled = false

        while !wasReaped && ProcessInfo.processInfo.systemUptime < deadline {
            wasReaped = try reapIfExited(childPID, status: &waitStatus)
            if wasReaped { break }
            do {
                try await Task.sleep(for: .milliseconds(10))
            } catch {
                wasCancelled = true
                break
            }
        }

        let timedOut = !wasReaped && !wasCancelled
        if !wasReaped {
            signalProcessGroup(childPID, signal: SIGTERM)
            let graceDeadline = ProcessInfo.processInfo.systemUptime + max(0, terminationGrace)
            while processGroupExists(childPID), ProcessInfo.processInfo.systemUptime < graceDeadline {
                if !wasReaped {
                    wasReaped = try reapIfExited(childPID, status: &waitStatus)
                }
                await pauseForCleanup()
            }
            if processGroupExists(childPID) {
                signalProcessGroup(childPID, signal: SIGKILL)
            }
            if !wasReaped {
                waitStatus = try await reap(childPID)
                wasReaped = true
            }
        } else {
            // A command that exits after starting background descendants must not
            // leave those processes holding capture descriptors indefinitely.
            signalProcessGroup(childPID, signal: SIGKILL)
        }

        _ = try await inputWrite
        let stdout = try await stdoutCapture
        let stderr = try await stderrCapture

        if wasCancelled { throw CancellationError() }
        if timedOut { throw Failure.timedOut }
        try Task.checkCancellation()
        return Output(status: terminationStatus(from: waitStatus), stdout: stdout, stderr: stderr)
    }

    private struct PipeDescriptors {
        let read: Int32
        let write: Int32
    }

    private static func makePipe(suppressBrokenPipeSignal: Bool = false) throws -> PipeDescriptors {
        var descriptors: [Int32] = [0, 0]
        guard Darwin.pipe(&descriptors) == 0 else { throw posixError(errno, operation: "create subprocess pipe") }
        let pair = PipeDescriptors(read: descriptors[0], write: descriptors[1])
        do {
            try setCloseOnExec(pair.read)
            try setCloseOnExec(pair.write)
            if suppressBrokenPipeSignal, Darwin.fcntl(pair.write, F_SETNOSIGPIPE, 1) == -1 {
                throw posixError(errno, operation: "configure subprocess input pipe")
            }
            return pair
        } catch {
            Darwin.close(pair.read)
            Darwin.close(pair.write)
            throw error
        }
    }

    private static func setCloseOnExec(_ descriptor: Int32) throws {
        let flags = Darwin.fcntl(descriptor, F_GETFD)
        guard flags != -1, Darwin.fcntl(descriptor, F_SETFD, flags | FD_CLOEXEC) != -1 else {
            throw posixError(errno, operation: "protect subprocess descriptor")
        }
    }

    private static func closeOwned(_ descriptor: Int32, ownedDescriptors: inout Set<Int32>) {
        guard ownedDescriptors.remove(descriptor) != nil else { return }
        Darwin.close(descriptor)
    }

    private static func transfer(_ descriptor: Int32, ownedDescriptors: inout Set<Int32>) -> Int32 {
        ownedDescriptors.remove(descriptor)
        return descriptor
    }

    @concurrent
    private static func writeAndClose(_ data: Data, to descriptor: Int32) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                defer { Darwin.close(descriptor) }
                let result: Result<Void, Error> = data.withUnsafeBytes { bytes in
                    guard let baseAddress = bytes.baseAddress else { return .success(()) }
                    var offset = 0
                    while offset < bytes.count {
                        let written = Darwin.write(descriptor, baseAddress.advanced(by: offset), bytes.count - offset)
                        if written > 0 {
                            offset += written
                        } else if written == -1, errno == EINTR {
                            continue
                        } else if written == -1, errno == EPIPE {
                            return .success(())
                        } else {
                            return .failure(posixError(errno, operation: "write subprocess input"))
                        }
                    }
                    return .success(())
                }
                continuation.resume(with: result)
            }
        }
    }

    @concurrent
    private static func drainAndClose(_ descriptor: Int32, retainingAtMost limit: Int) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                defer { Darwin.close(descriptor) }
                var retained = Data()
                retained.reserveCapacity(min(limit, readBufferBytes))
                var buffer = [UInt8](repeating: 0, count: readBufferBytes)

                while true {
                    let count = buffer.withUnsafeMutableBytes { bytes in
                        Darwin.read(descriptor, bytes.baseAddress, bytes.count)
                    }
                    if count == 0 {
                        continuation.resume(returning: retained)
                        return
                    }
                    if count == -1 {
                        if errno == EINTR { continue }
                        continuation.resume(throwing: posixError(errno, operation: "read subprocess output"))
                        return
                    }
                    let remaining = limit - retained.count
                    if remaining > 0 {
                        retained.append(contentsOf: buffer.prefix(min(count, remaining)))
                    }
                }
            }
        }
    }

    private static func reapIfExited(_ pid: pid_t, status: inout Int32) throws -> Bool {
        while true {
            let result = Darwin.waitpid(pid, &status, WNOHANG)
            if result == pid { return true }
            if result == 0 { return false }
            if result == -1, errno == EINTR { continue }
            throw posixError(errno, operation: "wait for subprocess")
        }
    }

    @concurrent
    private static func reap(_ pid: pid_t) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var status: Int32 = 0
                while true {
                    let result = Darwin.waitpid(pid, &status, 0)
                    if result == pid {
                        continuation.resume(returning: status)
                        return
                    }
                    if result == -1, errno == EINTR { continue }
                    continuation.resume(throwing: posixError(errno, operation: "reap subprocess"))
                    return
                }
            }
        }
    }

    private static func signalProcessGroup(_ pid: pid_t, signal: Int32) {
        _ = Darwin.kill(-pid, signal)
    }

    private static func processGroupExists(_ pid: pid_t) -> Bool {
        Darwin.kill(-pid, 0) == 0 || errno == EPERM
    }

    private static func terminationStatus(from waitStatus: Int32) -> Int32 {
        let signal = waitStatus & 0x7f
        return signal == 0 ? (waitStatus >> 8) & 0xff : signal
    }

    private static func checkPOSIX(_ result: Int32, operation: String) throws {
        guard result == 0 else { throw posixError(result, operation: operation) }
    }

    private static func posixError(_ code: Int32, operation: String) -> NSError {
        NSError(
            domain: NSPOSIXErrorDomain,
            code: Int(code),
            userInfo: [NSLocalizedDescriptionKey: "Unable to \(operation): \(String(cString: strerror(code)))"]
        )
    }

    private static func withMutableCStringArray<Result>(
        _ strings: [String],
        body: (UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) throws -> Result
    ) rethrows -> Result {
        let storage = strings.map { $0 as NSString }
        var pointers = storage.map { UnsafeMutablePointer(mutating: $0.utf8String) }
        pointers.append(nil)
        return try pointers.withUnsafeMutableBufferPointer { buffer in
            try body(buffer.baseAddress!)
        }
    }

    private static func pauseForCleanup() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(10)) {
                continuation.resume()
            }
        }
    }
}
