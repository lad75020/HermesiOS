//
//  HermesDashboardProfileSkills.swift
//  HermesiOS
//

import Foundation
import Observation

struct HermesDashboardProfileSkill: Decodable, Equatable, Identifiable {
    let name: String
    let description: String?
    let category: String
    let isEnabled: Bool

    var id: String { name }

    private enum CodingKeys: String, CodingKey {
        case name, description, category, enabled
    }

    init(name: String, description: String? = nil, category: String = "Uncategorized", isEnabled: Bool) {
        self.name = name
        self.description = Self.nonempty(description)
        self.category = Self.nonempty(category, fallback: "Uncategorized")
        self.isEnabled = isEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        isEnabled = try container.decode(Bool.self, forKey: .enabled)
        description = Self.nonempty(try container.decodeIfPresent(String.self, forKey: .description))
        category = Self.nonempty(try container.decodeIfPresent(String.self, forKey: .category) ?? "", fallback: "Uncategorized")
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func nonempty(_ value: String, fallback: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : value
    }
}

private struct HermesDashboardSkillDescription: Decodable {
    let name: String
    let description: String
}

private struct HermesDashboardSkillToggleAcknowledgement: Decodable {
    let ok: Bool
    let name: String
    let enabled: Bool
}

private struct HermesDashboardSkillToggleRequest: Encodable {
    let name: String
    let enabled: Bool
    let profile: String
}

enum HermesDashboardProfileSkillsError: LocalizedError {
    case invalidDashboardURL
    case missingDashboardSessionToken
    case invalidProfile
    case invalidAcknowledgement
    case descriptionMismatch
    case readbackMismatch
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidDashboardURL: "The Hermes dashboard URL is invalid."
        case .missingDashboardSessionToken: "The dashboard session token was not found in the dashboard HTML."
        case .invalidProfile: "An exact selected profile name is required."
        case .invalidAcknowledgement: "The dashboard did not acknowledge the requested skill change."
        case .descriptionMismatch: "The dashboard returned a description for a different skill."
        case .readbackMismatch: "The dashboard acknowledgement did not match the refreshed selected-profile skill state."
        case .httpError(let statusCode): "HTTP \(statusCode)"
        }
    }
}

@MainActor
@Observable
final class HermesDashboardProfileSkillsStore {
    var isMutating = false

    private var cachedTokenByBaseURL: [String: String] = [:]

#if DEBUG
    @ObservationIgnored var transportOverride: ((URLRequest) async throws -> (Data, URLResponse))?
#endif

    func load(profile: String, dashboardBaseURL: String, apiSettings: HermesAPISettings) async throws -> [HermesDashboardProfileSkill] {
        let baseURL = try resolvedDashboardBaseURL(from: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
        let loaded = try await withFreshTokenRetry(baseURL: baseURL, apiSettings: apiSettings) { token in
            try await self.fetchSkills(baseURL: baseURL, profile: profile, token: token, apiSettings: apiSettings)
        }
        return loaded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func loadDescription(name: String, profile: String, dashboardBaseURL: String, apiSettings: HermesAPISettings) async throws -> String {
        guard isExactProfile(profile), !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HermesDashboardProfileSkillsError.invalidProfile
        }
        let baseURL = try resolvedDashboardBaseURL(from: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
        let response: HermesDashboardSkillDescription = try await withFreshTokenRetry(baseURL: baseURL, apiSettings: apiSettings) { token in
            try await self.fetchDescription(baseURL: baseURL, name: name, profile: profile, token: token, apiSettings: apiSettings)
        }
        guard response.name == name else { throw HermesDashboardProfileSkillsError.descriptionMismatch }
        let description = response.description.trimmingCharacters(in: .whitespacesAndNewlines)
        return description.isEmpty ? "No description provided by Hermes." : description
    }

    func setEnabled(name: String, enabled: Bool, profile: String, dashboardBaseURL: String, apiSettings: HermesAPISettings) async throws -> [HermesDashboardProfileSkill] {
        guard !isMutating else { throw HermesDashboardProfileSkillsError.invalidAcknowledgement }
        isMutating = true
        defer { isMutating = false }

        let baseURL = try resolvedDashboardBaseURL(from: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
        let acknowledgement: HermesDashboardSkillToggleAcknowledgement = try await withFreshTokenRetry(baseURL: baseURL, apiSettings: apiSettings) { token in
            try await self.toggleSkill(baseURL: baseURL, name: name, enabled: enabled, profile: profile, token: token, apiSettings: apiSettings)
        }
        guard acknowledgement.ok, acknowledgement.name == name, acknowledgement.enabled == enabled else {
            throw HermesDashboardProfileSkillsError.invalidAcknowledgement
        }

        // The UI changes only after the server acknowledgement AND a fresh GET
        // for the same exact selected profile.
        let readback = try await load(profile: profile, dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings)
        guard readback.first(where: { $0.name == name })?.isEnabled == enabled else {
            throw HermesDashboardProfileSkillsError.readbackMismatch
        }
        return readback
    }

    private func withFreshTokenRetry<T>(baseURL: URL, apiSettings: HermesAPISettings, operation: (String) async throws -> T) async throws -> T {
        let token = try await dashboardSessionToken(baseURL: baseURL, apiSettings: apiSettings)
        do {
            return try await operation(token)
        } catch HermesDashboardProfileSkillsError.httpError(401) {
            cachedTokenByBaseURL.removeValue(forKey: baseURL.absoluteString)
            let refreshedToken = try await dashboardSessionToken(baseURL: baseURL, apiSettings: apiSettings)
            return try await operation(refreshedToken)
        }
    }

    private func dashboardSessionToken(baseURL: URL, apiSettings: HermesAPISettings) async throws -> String {
        let cacheKey = baseURL.absoluteString
        if let cached = cachedTokenByBaseURL[cacheKey], !cached.isEmpty { return cached }
        let (data, response) = try await perform(URLRequest(url: baseURL), apiSettings: apiSettings)
        try validate(response: response)
        let html = String(decoding: data, as: UTF8.self)
        let regex = try NSRegularExpression(pattern: #"window\.__HERMES_SESSION_TOKEN__=\"([^\"]+)\""#)
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: range), let tokenRange = Range(match.range(at: 1), in: html) else {
            throw HermesDashboardProfileSkillsError.missingDashboardSessionToken
        }
        let token = String(html[tokenRange])
        cachedTokenByBaseURL[cacheKey] = token
        return token
    }

    private func fetchSkills(baseURL: URL, profile: String, token: String, apiSettings: HermesAPISettings) async throws -> [HermesDashboardProfileSkill] {
        guard isExactProfile(profile) else { throw HermesDashboardProfileSkillsError.invalidProfile }
        var components = URLComponents(url: baseURL.appendingPathComponent("api/skills"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "profile", value: profile),
            URLQueryItem(name: "include_descriptions", value: "false")
        ]
        guard let url = components?.url else { throw HermesDashboardProfileSkillsError.invalidDashboardURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")
        let (data, response) = try await perform(request, apiSettings: apiSettings)
        try validate(response: response)
        return try JSONDecoder().decode([HermesDashboardProfileSkill].self, from: data)
    }

    private func fetchDescription(baseURL: URL, name: String, profile: String, token: String, apiSettings: HermesAPISettings) async throws -> HermesDashboardSkillDescription {
        var components = URLComponents(url: baseURL.appendingPathComponent("api/skills/description"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "profile", value: profile)
        ]
        guard let url = components?.url else { throw HermesDashboardProfileSkillsError.invalidDashboardURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")
        let (data, response) = try await perform(request, apiSettings: apiSettings)
        try validate(response: response)
        return try JSONDecoder().decode(HermesDashboardSkillDescription.self, from: data)
    }

    private func toggleSkill(baseURL: URL, name: String, enabled: Bool, profile: String, token: String, apiSettings: HermesAPISettings) async throws -> HermesDashboardSkillToggleAcknowledgement {
        guard isExactProfile(profile), !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw HermesDashboardProfileSkillsError.invalidProfile
        }
        var request = URLRequest(url: baseURL.appendingPathComponent("api/skills/toggle"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")
        request.httpBody = try JSONEncoder().encode(HermesDashboardSkillToggleRequest(name: name, enabled: enabled, profile: profile))
        let (data, response) = try await perform(request, apiSettings: apiSettings)
        try validate(response: response)
        return try JSONDecoder().decode(HermesDashboardSkillToggleAcknowledgement.self, from: data)
    }

    private func perform(_ request: URLRequest, apiSettings: HermesAPISettings) async throws -> (Data, URLResponse) {
#if DEBUG
        if let transportOverride { return try await transportOverride(request) }
#endif
        return try await HermesNetworkSessionFactory.session(for: apiSettings).data(for: request)
    }

    private func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw HermesDashboardProfileSkillsError.invalidDashboardURL }
        guard (200..<300).contains(http.statusCode) else { throw HermesDashboardProfileSkillsError.httpError(http.statusCode) }
    }

    private func resolvedDashboardBaseURL(from dashboardBaseURL: String, apiBaseURL: String) throws -> URL {
        let explicit = dashboardBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicit.isEmpty, let url = normalizedBaseURL(from: explicit) { return url }
        var fallback = apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if fallback.hasSuffix("/v1") { fallback.removeLast(3) }
        guard let url = normalizedBaseURL(from: fallback) else { throw HermesDashboardProfileSkillsError.invalidDashboardURL }
        return url
    }

    private func normalizedBaseURL(from value: String) -> URL? {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        return URL(string: trimmed)
    }

    private func isExactProfile(_ value: String) -> Bool {
        !value.isEmpty && value == value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
