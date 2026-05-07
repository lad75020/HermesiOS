//
//  CompanionServiceRegistry.swift
//  HermesHostCompanion
//
//  Created by Codex on 05/05/2026.
//

import Foundation

struct CompanionManagedServiceRecord: Codable, Identifiable {
    let id: String
    let displayName: String
    let statusCommand: [String]
    let restartCommand: [String]
    let startCommand: [String]?
    let stopCommand: [String]?
}

struct CompanionServiceRegistryDocument: Codable {
    let services: [CompanionManagedServiceRecord]
}

enum CompanionServiceRegistryError: LocalizedError {
    case serviceNotFound(String)
    case commandMissing(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .serviceNotFound(let id):
            "No allowlisted service exists for identifier '\(id)'."
        case .commandMissing(let command):
            "The configured command is missing or invalid: \(command)."
        case .commandFailed(let message):
            message
        }
    }
}

final class CompanionServiceRegistry {
    static let shared = CompanionServiceRegistry()

    private let fileURL: URL
    private var document: CompanionServiceRegistryDocument

    private init() {
        let supportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directory = supportDirectory.appendingPathComponent("HermesHostCompanion", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("services.json")

        if let data = try? Data(contentsOf: fileURL),
           let document = try? JSONDecoder().decode(CompanionServiceRegistryDocument.self, from: data) {
            let migrated = Self.migratedDocument(from: document)
            self.document = migrated
            save(migrated)
        } else {
            let seeded = Self.seededDocument()
            self.document = seeded
            save(seeded)
        }
    }

    func status(for serviceID: String) throws -> ServiceStatusResult {
        let service = try serviceRecord(for: serviceID)
        let output = try runStatus(command: service.statusCommand)
        return ServiceStatusResult(
            serviceID: serviceID,
            status: inferStatus(from: output),
            output: output
        )
    }

    func start(serviceID: String) throws -> ServiceStartResult {
        let service = try serviceRecord(for: serviceID)
        let command = service.startCommand ?? service.restartCommand
        let output = try run(command: command)
        return ServiceStartResult(
            serviceID: serviceID,
            status: .started,
            output: output
        )
    }

    func stop(serviceID: String) throws -> ServiceStopResult {
        let service = try serviceRecord(for: serviceID)
        guard let command = service.stopCommand else {
            throw CompanionServiceRegistryError.commandMissing("No stop command configured for \(serviceID).")
        }
        let output = try run(command: command)
        return ServiceStopResult(
            serviceID: serviceID,
            status: .stopped,
            output: output
        )
    }

    func restart(serviceID: String) throws -> ServiceRestartResult {
        let service = try serviceRecord(for: serviceID)
        let output = try run(command: service.restartCommand)
        return ServiceRestartResult(
            serviceID: serviceID,
            status: .restarted,
            output: output
        )
    }

    private func serviceRecord(for serviceID: String) throws -> CompanionManagedServiceRecord {
        guard let service = document.services.first(where: { $0.id == serviceID }) else {
            throw CompanionServiceRegistryError.serviceNotFound(serviceID)
        }
        return service
    }

    private func run(command: [String]) throws -> String {
        guard let executable = command.first, !executable.isEmpty else {
            throw CompanionServiceRegistryError.commandMissing(command.joined(separator: " "))
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(command.dropFirst())
        process.environment = Self.commandEnvironment()

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw CompanionServiceRegistryError.commandFailed(error.localizedDescription)
        }

        let stdout = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let combined = [stdout, stderr]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")

        if process.terminationStatus != 0 {
            throw CompanionServiceRegistryError.commandFailed(
                combined.isEmpty ? "Service command failed with exit code \(process.terminationStatus)." : combined
            )
        }

        return combined.isEmpty ? "Command completed successfully." : combined
    }

    private func runStatus(command: [String]) throws -> String {
        guard let executable = command.first, !executable.isEmpty else {
            throw CompanionServiceRegistryError.commandMissing(command.joined(separator: " "))
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = Array(command.dropFirst())
        process.environment = Self.commandEnvironment()

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw CompanionServiceRegistryError.commandFailed(error.localizedDescription)
        }

        let stdout = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let combined = [stdout, stderr]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")

        if combined.isEmpty, process.terminationStatus != 0 {
            return "Service status command exited with code \(process.terminationStatus)."
        }
        return combined.isEmpty ? "Command completed successfully." : combined
    }

    private static func commandEnvironment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        let supplementalPaths = [
            "\(homeDirectory)/.local/bin",
            "\(homeDirectory)/.hermes/hermes-agent/venv/bin",
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

    private func inferStatus(from output: String) -> CompanionManagedServiceStatus {
        let normalized = output.localizedLowercase
        if normalized.contains("running")
            || normalized.contains("state = running")
            || normalized.contains("gateway service is loaded")
            || normalized.contains("pid") {
            return .running
        }
        if normalized.contains("stopped")
            || normalized.contains("could not find service")
            || normalized.contains("not running")
            || normalized.contains("service status command exited") {
            return .stopped
        }
        return .unknown
    }

    private func save(_ document: CompanionServiceRegistryDocument) {
        if let data = try? JSONEncoder().encode(document) {
            try? data.write(to: fileURL, options: [.atomic])
        }
    }

    private static func seededDocument() -> CompanionServiceRegistryDocument {
        return CompanionServiceRegistryDocument(services: knownServices())
    }

    private static func migratedDocument(from document: CompanionServiceRegistryDocument) -> CompanionServiceRegistryDocument {
        var merged: [CompanionManagedServiceRecord] = []
        let known = Dictionary(uniqueKeysWithValues: knownServices().map { ($0.id, $0) })
        let existingIDs = Set(document.services.map(\.id))

        for service in document.services {
            if let updatedKnownService = known[service.id] {
                merged.append(updatedKnownService)
            } else {
                merged.append(service)
            }
        }

        for service in knownServices() where existingIDs.contains(service.id) == false {
            merged.append(service)
        }

        return CompanionServiceRegistryDocument(services: merged)
    }

    private static func knownServices() -> [CompanionManagedServiceRecord] {
        return [
            CompanionManagedServiceRecord(
                id: "hermesd",
                displayName: "Hermes Gateway / API Server",
                statusCommand: ["/usr/bin/env", "hermes", "gateway", "status"],
                restartCommand: ["/usr/bin/env", "hermes", "gateway", "restart"],
                startCommand: ["/usr/bin/env", "hermes", "gateway", "start"],
                stopCommand: ["/usr/bin/env", "hermes", "gateway", "stop"]
            ),
            launchAgentService(
                id: "hermes-dashboard",
                displayName: "Hermes Dashboard",
                label: "fr.dubertrand.hermes-dashboard-host-proxy",
                plistPath: "~/Library/LaunchAgents/fr.dubertrand.hermes-dashboard-host-proxy.plist"
            ),
            launchAgentService(
                id: "claw3d-adapter",
                displayName: "Claw3D Hermes Adapter",
                label: "fr.dubertrand.hermes-office-adapter",
                plistPath: "~/Library/LaunchAgents/fr.dubertrand.hermes-office-adapter.plist"
            ),
            launchAgentService(
                id: "openclaw-gateway",
                displayName: "OpenClaw Gateway",
                label: "ai.openclaw.gateway",
                plistPath: "~/Library/LaunchAgents/ai.openclaw.gateway.plist"
            )
        ]
    }

    private static func launchAgentService(id: String, displayName: String, label: String, plistPath: String) -> CompanionManagedServiceRecord {
        let domain = "gui/$(id -u)"
        let service = "\(domain)/\(label)"
        let startScript = "label='\(label)'; plist=\(plistPath); test -f \"${plist/#\\~/$HOME}\" || { echo \"LaunchAgent plist not found: $plist\"; exit 1; }; launchctl enable \(domain)/$label 2>/dev/null || true; launchctl bootstrap \(domain) \"${plist/#\\~/$HOME}\" 2>/dev/null || true; launchctl kickstart -k \(service)"
        let stopScript = "launchctl bootout \(service) 2>/dev/null || true; echo 'Service stopped: \(label)'"
        return CompanionManagedServiceRecord(
            id: id,
            displayName: displayName,
            statusCommand: ["/bin/zsh", "-lc", "launchctl print \(service) 2>&1"],
            restartCommand: ["/bin/zsh", "-lc", startScript],
            startCommand: ["/bin/zsh", "-lc", startScript],
            stopCommand: ["/bin/zsh", "-lc", stopScript]
        )
    }
}
