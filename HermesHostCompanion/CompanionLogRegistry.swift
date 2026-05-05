//
//  CompanionLogRegistry.swift
//  HermesHostCompanion
//

import Foundation

enum CompanionLogKind: String, Codable, CaseIterable {
    case errors
    case gateway
    case agent

    var label: String {
        switch self {
        case .errors: "ERRORS"
        case .gateway: "GATEWAY"
        case .agent: "AGENT"
        }
    }

    var path: String {
        switch self {
        case .errors: "/Users/laurent/.hermes/logs/errors.log"
        case .gateway: "/Users/laurent/.hermes/logs/gateway.log"
        case .agent: "/Users/laurent/.hermes/logs/agent.log"
        }
    }
}

struct ReadHermesLogPayload: Codable {
    let log: CompanionLogKind
    let lineCount: Int
}

struct ReadHermesLogResult: Codable {
    let log: CompanionLogKind
    let label: String
    let path: String
    let requestedLineCount: Int
    let loadedLineCount: Int
    let content: String
    let fileExists: Bool
    let updatedAt: Date
}

enum CompanionLogRegistryError: LocalizedError {
    case invalidLineCount(Int)
    case tailFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidLineCount(let lineCount):
            "Log line count must be between 10 and 10000; received \(lineCount)."
        case .tailFailed(let message):
            "Unable to read Hermes log: \(message)"
        }
    }
}

final class CompanionLogRegistry {
    func readLog(_ payload: ReadHermesLogPayload) throws -> ReadHermesLogResult {
        let lineCount = min(max(payload.lineCount, 10), 10_000)
        let path = payload.log.path
        let exists = FileManager.default.fileExists(atPath: path)

        guard exists else {
            return ReadHermesLogResult(
                log: payload.log,
                label: payload.log.label,
                path: path,
                requestedLineCount: lineCount,
                loadedLineCount: 0,
                content: "Log file does not exist yet: \(path)",
                fileExists: false,
                updatedAt: Date()
            )
        }

        let content = try tail(path: path, lineCount: lineCount)
        let loaded = content.isEmpty ? 0 : content.split(separator: "\n", omittingEmptySubsequences: false).count
        return ReadHermesLogResult(
            log: payload.log,
            label: payload.log.label,
            path: path,
            requestedLineCount: lineCount,
            loadedLineCount: loaded,
            content: content,
            fileExists: true,
            updatedAt: Date()
        )
    }

    private func tail(path: String, lineCount: Int) throws -> String {
        let url = URL(fileURLWithPath: path)
        let handle: FileHandle
        do {
            handle = try FileHandle(forReadingFrom: url)
        } catch {
            throw CompanionLogRegistryError.tailFailed(error.localizedDescription)
        }
        defer {
            try? handle.close()
        }

        do {
            let fileSize = try handle.seekToEnd()
            guard fileSize > 0 else { return "" }

            let chunkSize: UInt64 = 64 * 1024
            var offset = fileSize
            var buffer = Data()
            var newlineCount = 0

            while offset > 0 && newlineCount <= lineCount {
                let bytesToRead = min(chunkSize, offset)
                offset -= bytesToRead
                try handle.seek(toOffset: offset)
                let chunk = try handle.read(upToCount: Int(bytesToRead)) ?? Data()
                buffer.insert(contentsOf: chunk, at: 0)
                newlineCount += chunk.reduce(0) { count, byte in
                    count + (byte == 0x0A ? 1 : 0)
                }
            }

            let text = String(decoding: buffer, as: UTF8.self)
            let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
            let tailLines = lines.suffix(lineCount)
            return tailLines.joined(separator: "\n")
        } catch {
            throw CompanionLogRegistryError.tailFailed(error.localizedDescription)
        }
    }
}
