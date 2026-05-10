//
//  CompanionSSHTerminalRegistry.swift
//  HermesHostCompanion
//

import Foundation

enum CompanionSSHTerminalError: LocalizedError {
    case missingHost
    case missingUsername
    case missingPrivateKey
    case missingCommand
    case invalidPort
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingHost:
            "Enter a Mac host name or IP address."
        case .missingUsername:
            "Enter an SSH username in Settings."
        case .missingPrivateKey:
            "Paste an RSA or ED25519 private key in Settings."
        case .missingCommand:
            "Enter a terminal command to run."
        case .invalidPort:
            "Enter a valid SSH port between 1 and 65535."
        case .commandFailed(let message):
            message
        }
    }
}

final class CompanionSSHTerminalRegistry {
    private let maxCommandLength = 8_192
    private let timeoutSeconds: TimeInterval = 60

    func run(_ payload: SSHTerminalPayload) throws -> SSHTerminalResult {
        let host = payload.host.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = payload.username.trimmingCharacters(in: .whitespacesAndNewlines)
        let privateKey = normalizedPrivateKey(payload.privateKey)
        let command = payload.command.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !host.isEmpty else { throw CompanionSSHTerminalError.missingHost }
        guard !username.isEmpty else { throw CompanionSSHTerminalError.missingUsername }
        guard !privateKey.isEmpty else { throw CompanionSSHTerminalError.missingPrivateKey }
        guard !command.isEmpty else { throw CompanionSSHTerminalError.missingCommand }
        guard (1...65_535).contains(payload.port) else { throw CompanionSSHTerminalError.invalidPort }

        let trimmedCommand = String(command.prefix(maxCommandLength))
        let keyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("hermesios-ssh-")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: keyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try privateKey.data(using: .utf8)?.write(to: keyURL, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyURL.path)
        defer { try? FileManager.default.removeItem(at: keyURL) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = [
            "-i", keyURL.path,
            "-p", String(payload.port),
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=10",
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "IdentitiesOnly=yes",
            "\(username)@\(host)",
            trimmedCommand
        ]
        process.environment = Self.commandEnvironment()

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw CompanionSSHTerminalError.commandFailed(error.localizedDescription)
        }

        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
            throw CompanionSSHTerminalError.commandFailed("SSH command timed out after \(Int(timeoutSeconds)) seconds.")
        }

        let stdout = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let combined = [stdout, stderr]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
        let output = combined.isEmpty ? "Command completed with no output." : combined

        return SSHTerminalResult(
            host: host,
            username: username,
            command: trimmedCommand,
            exitCode: process.terminationStatus,
            output: output
        )
    }

    private func normalizedPrivateKey(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return trimmed + (trimmed.hasSuffix("\n") ? "" : "\n")
    }

    private static func commandEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let supplementalPaths = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]
        let existingPath = environment["PATH"] ?? ""
        environment["PATH"] = (supplementalPaths + [existingPath])
            .filter { !$0.isEmpty }
            .joined(separator: ":")
        return environment
    }
}
