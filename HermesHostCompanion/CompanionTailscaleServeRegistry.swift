//
//  CompanionTailscaleServeRegistry.swift
//  HermesHostCompanion
//

import Foundation

enum CompanionTailscaleServeRegistryError: LocalizedError {
    case invalidPort(String)
    case companionPortNotAllowed(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidPort(let port):
            "Invalid TCP port: \(port)."
        case .companionPortNotAllowed(let port):
            "Tailscale Serve control for the Host Companion port is intentionally disabled: \(port)."
        case .commandFailed(let message):
            message
        }
    }
}

final class CompanionTailscaleServeRegistry {
    private let companionPorts = Set(["9112", "9212", "9312"])

    func status(port rawPort: String) async throws -> TailscaleServeStatusResult {
        let port = try normalizedPort(rawPort)
        let output = try await runTailscale(arguments: ["serve", "status", "--json"], allowNonZero: true)
        let fallbackOutput: String
        if output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || output.localizedLowercase.contains("unknown flag") {
            fallbackOutput = try await runTailscale(arguments: ["serve", "status"], allowNonZero: true)
        } else {
            fallbackOutput = output
        }
        return TailscaleServeStatusResult(
            port: port,
            isEnabled: Self.output(fallbackOutput, containsServeFor: port),
            output: fallbackOutput.isEmpty ? "No Tailscale Serve status output." : fallbackOutput,
            checkedAt: Date()
        )
    }

    func set(port rawPort: String, enabled: Bool) async throws -> TailscaleServeStatusResult {
        let port = try normalizedPort(rawPort)
        let arguments: [String]
        if enabled {
            arguments = ["serve", "--bg", "--https=\(port)", "http://localhost:\(port)"]
        } else {
            arguments = ["serve", "--https=\(port)", "off"]
        }
        let operationOutput = try await runTailscale(arguments: arguments, allowNonZero: false)
        let refreshed = try await status(port: port)
        let combinedOutput = [operationOutput, refreshed.output]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        return TailscaleServeStatusResult(
            port: refreshed.port,
            isEnabled: refreshed.isEnabled,
            output: combinedOutput.isEmpty ? refreshed.output : combinedOutput,
            checkedAt: refreshed.checkedAt
        )
    }

    private func normalizedPort(_ rawPort: String) throws -> String {
        let digits = rawPort.trimmingCharacters(in: .whitespacesAndNewlines).filter(\.isNumber)
        guard let value = Int(digits), value > 0, value < 65536 else {
            throw CompanionTailscaleServeRegistryError.invalidPort(rawPort)
        }
        let port = String(value)
        if companionPorts.contains(port) {
            throw CompanionTailscaleServeRegistryError.companionPortNotAllowed(port)
        }
        return port
    }

    private func runTailscale(arguments: [String], allowNonZero: Bool) async throws -> String {
        let result: CompanionSubprocess.Output
        do {
            result = try await CompanionSubprocess.run(
                executableURL: URL(fileURLWithPath: "/usr/bin/env"),
                arguments: ["tailscale"] + arguments,
                environment: Self.commandEnvironment(),
                timeout: 15
            )
        } catch {
            throw CompanionTailscaleServeRegistryError.commandFailed(error.localizedDescription)
        }

        let stdout = String(data: result.stdout, encoding: .utf8) ?? ""
        let stderr = String(data: result.stderr, encoding: .utf8) ?? ""
        let combined = [stdout, stderr]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if result.status != 0 && allowNonZero == false {
            throw CompanionTailscaleServeRegistryError.commandFailed(
                combined.isEmpty ? "tailscale command failed with exit code \(result.status)." : combined
            )
        }
        return combined
    }

    private static func output(_ output: String, containsServeFor port: String) -> Bool {
        let normalized = output.localizedLowercase
        let portMarkers = [":\(port)", "https=\(port)", "\"\(port)\""]
        guard portMarkers.contains(where: { normalized.contains($0) }) else { return false }
        guard normalized.contains("off") == false || normalized.contains("localhost:\(port)") else { return false }
        return normalized.contains("localhost:\(port)")
            || normalized.contains("127.0.0.1:\(port)")
            || normalized.contains("https://")
            || normalized.contains("https")
    }

    private static func commandEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        let supplementalPaths = [
            "\(homeDirectory)/.local/bin",
            "/Applications/Tailscale.app/Contents/MacOS",
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
