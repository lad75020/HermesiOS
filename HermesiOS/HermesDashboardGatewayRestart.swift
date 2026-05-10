//
//  HermesDashboardGatewayRestart.swift
//  HermesiOS
//

import Foundation
import Observation

@MainActor
@Observable
final class HermesDashboardGatewayRestartSession {
    var isRestarting = false
    var status = "Idle"
    var lastErrorMessage = ""

    private var cachedTokenByBaseURL: [String: String] = [:]

    func restart(dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        guard !isRestarting else { return }
        isRestarting = true
        status = "Restarting gateway"
        lastErrorMessage = ""

        Task {
            defer { isRestarting = false }
            do {
                try await HermesBackgroundActivity.run(named: "Hermes Dashboard Gateway Restart") {
                    let baseURL = try resolvedDashboardBaseURL(from: dashboardBaseURL)
                    let token = try await dashboardSessionToken(baseURL: baseURL, apiSettings: apiSettings)

                    do {
                        try await postGatewayRestart(baseURL: baseURL, token: token, apiSettings: apiSettings)
                    } catch HermesResponsesError.httpError(401) {
                        cachedTokenByBaseURL.removeValue(forKey: baseURL.absoluteString)
                        status = "Refreshing dashboard session token"
                        let refreshedToken = try await dashboardSessionToken(baseURL: baseURL, apiSettings: apiSettings)
                        try await postGatewayRestart(baseURL: baseURL, token: refreshedToken, apiSettings: apiSettings)
                    }

                    status = "Gateway restart requested"
                }
            } catch {
                status = "Gateway restart failed"
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    private func dashboardSessionToken(baseURL: URL, apiSettings: HermesAPISettings) async throws -> String {
        let cacheKey = baseURL.absoluteString
        if let cached = cachedTokenByBaseURL[cacheKey], !cached.isEmpty {
            return cached
        }

        status = "Fetching dashboard session token"
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (data, response) = try await session.data(from: baseURL)
        try validate(response: response)

        let html = String(decoding: data, as: UTF8.self)
        let pattern = #"window\.__HERMES_SESSION_TOKEN__=\"([^\"]+)\""#
        let regex = try NSRegularExpression(pattern: pattern)
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)

        guard
            let match = regex.firstMatch(in: html, range: nsRange),
            let tokenRange = Range(match.range(at: 1), in: html)
        else {
            throw HermesDashboardGatewayRestartError.missingDashboardSessionToken
        }

        let token = String(html[tokenRange])
        cachedTokenByBaseURL[cacheKey] = token
        return token
    }

    private func postGatewayRestart(baseURL: URL, token: String, apiSettings: HermesAPISettings) async throws {
        status = "Posting dashboard restart request"
        let url = baseURL.appendingPathComponent("api/gateway/restart")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")
        request.httpBody = Data("{}".utf8)

        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (_, response) = try await session.data(for: request)
        try validate(response: response)
    }

    private func resolvedDashboardBaseURL(from dashboardBaseURL: String) throws -> URL {
        guard let url = normalizedBaseURL(from: dashboardBaseURL) else {
            throw HermesDashboardGatewayRestartError.invalidDashboardURL
        }
        return url
    }

    private func normalizedBaseURL(from value: String) -> URL? {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        return URL(string: trimmed)
    }

    private func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else {
            throw HermesResponsesError.invalidResponse
        }

        guard 200 ..< 300 ~= http.statusCode else {
            throw HermesResponsesError.httpError(http.statusCode)
        }
    }
}

enum HermesDashboardGatewayRestartError: LocalizedError {
    case invalidDashboardURL
    case missingDashboardSessionToken

    var errorDescription: String? {
        switch self {
        case .invalidDashboardURL:
            "The Hermes dashboard URL is invalid."
        case .missingDashboardSessionToken:
            "The dashboard session token was not found in the dashboard HTML."
        }
    }
}
