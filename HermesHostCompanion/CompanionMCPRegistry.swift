//
//  CompanionMCPRegistry.swift
//  HermesHostCompanion
//

import Foundation

struct CompanionMCPCommandResult: Codable {
    let output: String
}

enum CompanionMCPRegistryError: LocalizedError {
    case invalidName
    case invalidTransport
    case invalidURL
    case missingCommand
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidName:
            "Enter an MCP server name."
        case .invalidTransport:
            "Choose either stdio or streamable HTTP transport."
        case .invalidURL:
            "Enter a valid HTTP MCP URL."
        case .missingCommand:
            "Enter the stdio command to launch the MCP server."
        case .commandFailed(let message):
            message
        }
    }
}

final class CompanionMCPRegistry {
    func listServers() throws -> ListMCPServersResult {
        let output = try run(arguments: ["mcp", "list"])
        return ListMCPServersResult(servers: parseServers(from: output), output: output)
    }

    func addServer(_ payload: AddMCPServerPayload) throws -> MCPServerOperationResult {
        let name = payload.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw CompanionMCPRegistryError.invalidName }

        var arguments = ["mcp", "add", name]
        var stdinLines: [String] = ["y"] // overwrite if prompted

        switch payload.transport {
        case .stdio:
            let command = payload.command.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !command.isEmpty else { throw CompanionMCPRegistryError.missingCommand }
            arguments += ["--command", command]
            let serverArgs = splitShellWords(payload.arguments)
            if !serverArgs.isEmpty {
                arguments.append("--args")
                arguments.append(contentsOf: serverArgs)
            }
            stdinLines.append("y") // enable all discovered tools
        case .streamableHTTP:
            let url = payload.url.trimmingCharacters(in: .whitespacesAndNewlines)
            guard url.lowercased().hasPrefix("http://") || url.lowercased().hasPrefix("https://") else {
                throw CompanionMCPRegistryError.invalidURL
            }
            arguments += ["--url", url]
            let token = payload.bearerToken.trimmingCharacters(in: .whitespacesAndNewlines)
            if token.isEmpty {
                stdinLines += ["n", "y"] // no auth, enable all tools
            } else {
                arguments += ["--auth", "header"]
                stdinLines += ["y", token, "y"] // auth required, token, enable all tools
            }
        }

        let output = try run(arguments: arguments, stdin: stdinLines.joined(separator: "\n") + "\n")
        let updated = try listServers()
        return MCPServerOperationResult(serverName: name, output: output, servers: updated.servers)
    }

    func removeServer(name rawName: String) throws -> MCPServerOperationResult {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw CompanionMCPRegistryError.invalidName }
        let output = try run(arguments: ["mcp", "remove", name])
        let updated = try listServers()
        return MCPServerOperationResult(serverName: name, output: output, servers: updated.servers)
    }

    private func run(arguments: [String], stdin: String? = nil) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["hermes"] + arguments
        process.environment = Self.commandEnvironment()

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let inputPipe = stdin == nil ? nil : Pipe()
        if let inputPipe {
            process.standardInput = inputPipe
        }

        do {
            try process.run()
            if let stdin, let inputPipe {
                inputPipe.fileHandleForWriting.write(Data(stdin.utf8))
                try? inputPipe.fileHandleForWriting.close()
            }
            process.waitUntilExit()
        } catch {
            throw CompanionMCPRegistryError.commandFailed(error.localizedDescription)
        }

        let stdout = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let combined = [stdout, stderr]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: "\n")

        guard process.terminationStatus == 0 else {
            throw CompanionMCPRegistryError.commandFailed(
                combined.isEmpty ? "hermes mcp command failed with exit code \(process.terminationStatus)." : combined
            )
        }

        return combined.isEmpty ? "Command completed successfully." : combined
    }

    private func parseServers(from output: String) -> [CompanionMCPServerSummary] {
        output.components(separatedBy: .newlines).compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  !trimmed.contains("MCP Servers:"),
                  !trimmed.hasPrefix("Name"),
                  !trimmed.hasPrefix("─")
            else { return nil }

            let columns = trimmed.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard columns.count >= 4 else { return nil }
            return CompanionMCPServerSummary(
                id: columns[0],
                name: columns[0],
                transport: columns[1],
                tools: columns[2],
                status: columns[3]
            )
        }
    }

    private func splitShellWords(_ text: String) -> [String] {
        var words: [String] = []
        var current = ""
        var quote: Character?
        var escaping = false

        for character in text {
            if escaping {
                current.append(character)
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                } else {
                    current.append(character)
                }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character.isWhitespace {
                if !current.isEmpty {
                    words.append(current)
                    current = ""
                }
            } else {
                current.append(character)
            }
        }

        if !current.isEmpty { words.append(current) }
        return words
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
}
