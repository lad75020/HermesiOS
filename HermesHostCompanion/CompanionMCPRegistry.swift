import Foundation

enum CompanionMCPRegistryError: LocalizedError {
    case invalidName, invalidURL, insecureHTTPURL, missingCommand, commandFailed(String)
    var errorDescription: String? {
        switch self {
        case .invalidName: "Enter an MCP server name."
        case .invalidURL: "Enter a valid HTTPS MCP URL, or a localhost HTTP URL for local development."
        case .insecureHTTPURL: "HTTP MCP servers must use HTTPS unless the host is localhost, 127.0.0.1, or ::1."
        case .missingCommand: "Enter the stdio command to launch the MCP server."
        case .commandFailed(let message): message
        }
    }
}

/// Runs Hermes' own config APIs with HERMES_HOME bound to the selected profile.
/// Requests, including bearer tokens, travel over stdin only. The bridge returns a
/// deliberately sanitized inventory: name, transport kind, tool selection and status.
@MainActor
final class CompanionMCPRegistry {
    func listServers(workspacePath: String) async throws -> ListMCPServersResult {
        let result = try await bridge(workspacePath: workspacePath, request: ["action": "list"])
        return ListMCPServersResult(workspacePath: workspacePath, resolvedWorkspacePath: result.workspacePath, servers: result.servers, output: "Loaded selected Hermes profile.")
    }

    func addServer(_ payload: AddMCPServerPayload) async throws -> MCPServerOperationResult {
        let name = payload.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw CompanionMCPRegistryError.invalidName }
        var request: [String: Any] = ["action": "add", "name": name, "transport": payload.transport.rawValue]
        switch payload.transport {
        case .stdio:
            let command = payload.command.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !command.isEmpty else { throw CompanionMCPRegistryError.missingCommand }
            request["command"] = command
            request["args"] = splitShellWords(payload.arguments)
        case .streamableHTTP, .openAPI:
            request["url"] = try validatedURL(payload.url).absoluteString
            let token = payload.bearerToken.trimmingCharacters(in: .whitespacesAndNewlines)
            if !token.isEmpty { request["bearerToken"] = token }
        }
        let result = try await bridge(workspacePath: payload.workspacePath, request: request)
        return MCPServerOperationResult(workspacePath: payload.workspacePath, resolvedWorkspacePath: result.workspacePath, serverName: name, output: "Saved MCP server in selected Hermes profile.", servers: result.servers)
    }

    func removeServer(workspacePath: String, name rawName: String) async throws -> MCPServerOperationResult {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw CompanionMCPRegistryError.invalidName }
        let result = try await bridge(workspacePath: workspacePath, request: ["action": "remove", "name": name])
        return MCPServerOperationResult(workspacePath: workspacePath, resolvedWorkspacePath: result.workspacePath, serverName: name, output: "Removed MCP server from selected Hermes profile.", servers: result.servers)
    }

    private func validatedURL(_ raw: String) throws -> URL {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), let host = url.host?.lowercased(), ["https", "http"].contains(scheme) else { throw CompanionMCPRegistryError.invalidURL }
        guard scheme == "https" || host == "localhost" || host == "127.0.0.1" || host == "::1" || host.hasSuffix(".localhost") else { throw CompanionMCPRegistryError.insecureHTTPURL }
        return url
    }

    private struct BridgeResult: Decodable { let workspacePath: String; let servers: [CompanionMCPServerSummary] }
    private func bridge(workspacePath: String, request: [String: Any]) async throws -> BridgeResult {
        guard let context = CompanionWorkspaceSecurity.resolvedHermesCLIContext(from: workspacePath) else { throw CompanionMCPRegistryError.commandFailed("The selected Hermes profile is not inside a trusted Hermes CLI root.") }
        let venvPython = context.cliRootURL.appendingPathComponent("hermes-agent/venv/bin/python").path
        let executableURL = FileManager.default.isExecutableFile(atPath: venvPython) ? URL(fileURLWithPath: venvPython) : URL(fileURLWithPath: "/usr/bin/python3")
        var environment = ProcessInfo.processInfo.environment
        environment["HERMES_HOME"] = context.selectedHomeURL.path
        environment["PYTHONPATH"] = context.cliRootURL.appendingPathComponent("hermes-agent").path
        let output = try await CompanionSubprocess.run(
            executableURL: executableURL, arguments: ["-c", Self.bridgeScript],
            environment: environment, input: JSONSerialization.data(withJSONObject: request))
        guard output.status == 0, let decoded = try? JSONDecoder().decode(BridgeResult.self, from: output.stdout) else {
            // Never expose stderr: it can contain a header, URL query, or environment value.
            throw CompanionMCPRegistryError.commandFailed("Hermes could not update the selected profile configuration.")
        }
        return decoded
    }

    private func splitShellWords(_ text: String) -> [String] {
        var words: [String] = []; var current = ""; var quote: Character?; var escaping = false
        for character in text {
            if escaping { current.append(character); escaping = false }
            else if character == "\\" { escaping = true }
            else if let activeQuote = quote { if character == activeQuote { quote = nil } else { current.append(character) } }
            else if character == "\"" || character == "'" { quote = character }
            else if character.isWhitespace { if !current.isEmpty { words.append(current); current = "" } }
            else { current.append(character) }
        }
        if !current.isEmpty { words.append(current) }; return words
    }

    private static let bridgeScript = #"""
import json, os, sys
from hermes_cli.config import load_config, save_config
from hermes_cli.mcp_config import _save_bearer_auth_token
from hermes_cli.mcp_security import validate_mcp_server_entry
r = json.load(sys.stdin); cfg = load_config(); servers = cfg.get("mcp_servers") if isinstance(cfg.get("mcp_servers"), dict) else {}; action = r.get("action"); name = str(r.get("name", "")).strip()
if action == "add":
    transport = r.get("transport")
    if transport == "stdio": entry = {"command": str(r.get("command", "")).strip(), "args": list(r.get("args") or []), "enabled": True}
    elif transport in ("streamableHTTP", "openAPI"):
        entry = {"url": str(r.get("url", "")).strip(), "enabled": True}
        if transport == "openAPI": entry["transport"] = "openapi"
        token = str(r.get("bearerToken", "")).strip()
        if token: entry["headers"] = _save_bearer_auth_token(name, token)
    else: raise ValueError("Unsupported MCP transport")
    if validate_mcp_server_entry(name, entry): raise ValueError("MCP configuration was rejected by Hermes validation")
    servers[name] = entry
elif action == "remove":
    if name not in servers: raise ValueError("MCP server does not exist in the selected profile")
    del servers[name]
elif action != "list": raise ValueError("Unsupported MCP operation")
if action != "list":
    if servers: cfg["mcp_servers"] = servers
    else: cfg.pop("mcp_servers", None)
    save_config(cfg)
def summary(n, c):
    kind = "OpenAPI" if str(c.get("transport", "")).lower() == "openapi" else ("Streamable HTTP" if "url" in c else "Stdio")
    tools = c.get("tools") if isinstance(c.get("tools"), dict) else {}; include, exclude = tools.get("include"), tools.get("exclude")
    selected = f"{len(include)} selected" if isinstance(include, list) and include else (f"{len(exclude)} excluded" if isinstance(exclude, list) and exclude else "all")
    enabled = c.get("enabled", True); enabled = str(enabled).lower() in ("true", "1", "yes") if isinstance(enabled, str) else bool(enabled)
    return {"id": n, "name": n, "transport": kind, "tools": selected, "status": "enabled" if enabled else "disabled"}
print(json.dumps({"workspacePath": os.environ["HERMES_HOME"], "servers": [summary(n, c) for n, c in sorted(servers.items()) if isinstance(c, dict)]}))
"""#
}
