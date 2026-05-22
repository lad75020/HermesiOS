//
//  HermesHostEndpoints.swift
//  HermesiOS
//

import Foundation

let hermesMacHostStorageKey = "hermes.mac.host"
let defaultHermesMacHost = ".ts.net"

let hermesDashboardPortStorageKey = "hermes.history.dashboard.port"
let defaultHermesDashboardPort = "9120"

let hermesOfficePortStorageKey = "hermes.office.port"
let defaultHermesOfficePort = "9116"

let hermesRuntimeTabEnabledStorageKey = "hermes.runtime.tab.enabled"
let hermesTailscaleServePortStorageKey = "hermes.tailscale.serve.selected.port"

let defaultHermesAPIPort = "8642"
let defaultHermesCompanionPort = "9112"

enum HermesHostEndpoints {
    static func normalizedHost(_ host: String) -> String {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return defaultHermesMacHost }

        if let components = URLComponents(string: trimmed), components.scheme != nil, let host = components.host, !host.isEmpty {
            return host
        }

        let withoutPath: String
        if let slashIndex = trimmed.firstIndex(of: "/") {
            withoutPath = String(trimmed[..<slashIndex])
        } else {
            withoutPath = trimmed
        }

        if withoutPath.filter({ $0 == ":" }).count == 1, let colonIndex = withoutPath.lastIndex(of: ":") {
            return String(withoutPath[..<colonIndex])
        }

        return withoutPath
    }

    static func tcpPort(from value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }

        if let components = URLComponents(string: trimmed), let port = components.port {
            return String(port)
        }

        let digits = trimmed.filter(\.isNumber)
        return digits.isEmpty ? fallback : String(digits.prefix(5))
    }

    static func httpURLString(host: String, port: String, path: String = "") -> String {
        urlString(scheme: "https", host: host, port: port, path: path)
    }

    static func webSocketURLString(host: String, port: String, path: String = "/ws") -> String {
        urlString(scheme: "wss", host: host, port: port, path: path)
    }

    private static func urlString(scheme: String, host: String, port: String, path: String) -> String {
        let normalizedHost = normalizedHost(host)
        let normalizedPort = tcpPort(from: port, fallback: scheme.hasPrefix("ws") ? defaultHermesCompanionPort : defaultHermesAPIPort)
        let normalizedPath: String
        if path.isEmpty {
            normalizedPath = ""
        } else if path.hasPrefix("/") {
            normalizedPath = path
        } else {
            normalizedPath = "/\(path)"
        }
        return "\(scheme)://\(normalizedHost):\(normalizedPort)\(normalizedPath)"
    }
}

enum HermesEndpointSecurity {
    static func isPlaintextTransportAllowed(for url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), ["http", "ws"].contains(scheme) else { return true }
        guard let host = url.host?.lowercased() else { return false }
        return isLoopbackHost(host)
    }

    static func plaintextTransportWarning(for urlString: String, endpointName: String) -> String? {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              ["http", "ws"].contains(scheme),
              !isPlaintextTransportAllowed(for: url) else { return nil }
        return "Plaintext \(scheme.uppercased()) is blocked for \(endpointName) unless the host is localhost or 127.0.0.1. Use HTTPS/WSS for remote or Tailscale endpoints."
    }

    static func isSelfSignedTrustAllowed(forHost host: String) -> Bool {
        let normalized = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        return isLoopbackHost(normalized) || normalized.hasSuffix(".ts.net")
    }

    private static func isLoopbackHost(_ host: String) -> Bool {
        let normalized = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        return normalized == "localhost" || normalized == "::1" || normalized == "0:0:0:0:0:0:0:1" || normalized.hasPrefix("127.")
    }
}

