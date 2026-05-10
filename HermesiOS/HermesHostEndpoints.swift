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
