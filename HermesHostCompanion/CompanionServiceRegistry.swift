//
//  CompanionServiceRegistry.swift
//  HermesHostCompanion
//
//  Created by Codex on 05/05/2026.
//

import Foundation
import Darwin

struct CompanionManagedServiceRecord: Codable, Identifiable {
    let id: String
    let displayName: String
    let statusCommand: [String]
    let restartCommand: [String]
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
            if let data = try? JSONEncoder().encode(migrated) {
                try? data.write(to: fileURL, options: [.atomic])
            }
        } else {
            let seeded = Self.seededDocument()
            self.document = seeded
            if let data = try? JSONEncoder().encode(seeded) {
                try? data.write(to: fileURL, options: [.atomic])
            }
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

    private func inferStatus(from output: String) -> CompanionManagedServiceStatus {
        let normalized = output.localizedLowercase
        if normalized.contains("running") || normalized.contains("state = running") {
            return .running
        }
        if normalized.contains("stopped") || normalized.contains("could not find service") || normalized.contains("not running") {
            return .stopped
        }
        return .unknown
    }

    private static func seededDocument() -> CompanionServiceRegistryDocument {
        let launchctlService = "gui/\(getuid())/com.nous.hermesd"
        return CompanionServiceRegistryDocument(
            services: [
                CompanionManagedServiceRecord(
                    id: "hermesd",
                    displayName: "Hermes Daemon",
                    statusCommand: ["/bin/launchctl", "print", launchctlService],
                    restartCommand: ["/bin/launchctl", "kickstart", "-k", launchctlService]
                )
            ]
        )
    }

    private static func migratedDocument(from document: CompanionServiceRegistryDocument) -> CompanionServiceRegistryDocument {
        let launchctlService = "gui/\(getuid())/com.nous.hermesd"
        return CompanionServiceRegistryDocument(
            services: document.services.map { service in
                guard service.id == "hermesd" else { return service }
                return CompanionManagedServiceRecord(
                    id: service.id,
                    displayName: service.displayName,
                    statusCommand: ["/bin/launchctl", "print", launchctlService],
                    restartCommand: ["/bin/launchctl", "kickstart", "-k", launchctlService]
                )
            }
        )
    }
}
