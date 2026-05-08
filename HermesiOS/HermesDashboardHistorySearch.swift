//
//  HermesDashboardHistorySearch.swift
//  HermesiOS
//

import Foundation
import Observation

struct HermesDashboardConversationSearchResponse: Decodable {
    let results: [HermesDashboardConversationResult]
    let limit: Int
    let offset: Int
    let matchedMessages: Int
    let matchedSessions: Int

    enum CodingKeys: String, CodingKey {
        case results
        case limit
        case offset
        case matchedMessages = "matched_messages"
        case matchedSessions = "matched_sessions"
    }
}

struct HermesDashboardConversationResult: Identifiable, Decodable {
    let sessionID: String
    let session: HermesDashboardSessionInfo
    let matches: [HermesDashboardMessageMatch]
    let messages: [HermesDashboardConversationMessage]
    let title: String?

    var id: String { sessionID }

    var sessionFriendlyName: String {
        for candidate in [title, session.title] {
            let normalized = Self.normalizedTitle(candidate ?? "")
            if !normalized.isEmpty {
                return normalized
            }
        }

        let firstUserPrompt = messages.first { $0.role.lowercased() == "user" }?.content ?? ""
        let normalizedPrompt = Self.normalizedTitle(firstUserPrompt)
        if !normalizedPrompt.isEmpty {
            return normalizedPrompt
        }

        let fallback = sessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? session.id : sessionID
        return Self.normalizedTitle(fallback)
    }

    private static func normalizedTitle(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case session
        case matches
        case messages
        case metadata
        case title
        case displayTitle = "display_title"
        case friendlyName = "friendly_name"
        case name
        case summary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionID = try container.decode(String.self, forKey: .sessionID)
        session = try container.decode(HermesDashboardSessionInfo.self, forKey: .session)
        matches = (try? container.decode([HermesDashboardMessageMatch].self, forKey: .matches)) ?? []
        messages = (try? container.decode([HermesDashboardConversationMessage].self, forKey: .messages)) ?? []

        let metadata = try? container.decode([String: HermesFlexibleJSONValue].self, forKey: .metadata)
        let directTitle = [
            try? container.decode(String.self, forKey: .title),
            try? container.decode(String.self, forKey: .displayTitle),
            try? container.decode(String.self, forKey: .friendlyName),
            try? container.decode(String.self, forKey: .name),
            try? container.decode(String.self, forKey: .summary)
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
        title = directTitle ?? Self.metadataTitle(metadata)
    }

    private static func metadataTitle(_ metadata: [String: HermesFlexibleJSONValue]?) -> String? {
        guard let metadata else { return nil }
        let titleKeys = ["title", "display_title", "friendly_name", "name", "summary", "session_title", "session_friendly_name"]
        if let title = titleKeys
            .compactMap({ metadata[$0]?.readableText.trimmingCharacters(in: .whitespacesAndNewlines) })
            .first(where: { !$0.isEmpty }) {
            return title
        }

        for nestedKey in ["session", "conversation"] {
            if let nested = metadata[nestedKey]?.objectValue,
               let title = titleKeys
                .compactMap({ nested[$0]?.readableText.trimmingCharacters(in: .whitespacesAndNewlines) })
                .first(where: { !$0.isEmpty }) {
                return title
            }
        }

        return nil
    }
}

struct HermesDashboardSessionInfo: Decodable {
    let id: String
    let source: String?
    let userID: String?
    let profile: String?
    let model: String?
    let title: String?
    let startedAt: Double?
    let endedAt: Double?
    let messageCount: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case source
        case userID = "user_id"
        case profile
        case profileName = "profile_name"
        case profileID = "profile_id"
        case hermesProfile = "hermes_profile"
        case metadata
        case model
        case title
        case displayTitle = "display_title"
        case friendlyName = "friendly_name"
        case name
        case summary
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case messageCount = "message_count"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        source = try? container.decode(String.self, forKey: .source)
        userID = try? container.decode(String.self, forKey: .userID)
        model = try? container.decode(String.self, forKey: .model)
        let metadata = try? container.decode([String: HermesFlexibleJSONValue].self, forKey: .metadata)
        let directTitle = [
            try? container.decode(String.self, forKey: .title),
            try? container.decode(String.self, forKey: .displayTitle),
            try? container.decode(String.self, forKey: .friendlyName),
            try? container.decode(String.self, forKey: .name),
            try? container.decode(String.self, forKey: .summary)
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
        if let directTitle {
            title = directTitle
        } else if let metadata {
            title = ["title", "display_title", "friendly_name", "name", "summary"]
                .compactMap { metadata[$0]?.readableText.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty }
        } else {
            title = nil
        }
        startedAt = try? container.decode(Double.self, forKey: .startedAt)
        endedAt = try? container.decode(Double.self, forKey: .endedAt)
        messageCount = try? container.decode(Int.self, forKey: .messageCount)

        let directProfile = [
            try? container.decode(String.self, forKey: .profile),
            try? container.decode(String.self, forKey: .profileName),
            try? container.decode(String.self, forKey: .profileID),
            try? container.decode(String.self, forKey: .hermesProfile)
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }

        if let directProfile {
            profile = directProfile
        } else if let metadata {
            profile = ["profile", "profile_name", "profile_id", "hermes_profile"]
                .compactMap { metadata[$0]?.readableText.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty }
        } else {
            profile = nil
        }
    }
}

struct HermesDashboardMessageMatch: Identifiable, Decodable {
    let id: Int
    let sessionID: String?
    let role: String?
    let snippet: String?
    let timestamp: Double?
    let source: String?
    let model: String?
    let toolName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case sessionID = "session_id"
        case role
        case snippet
        case timestamp
        case source
        case model
        case toolName = "tool_name"
    }
}

struct HermesDashboardConversationMessage: Identifiable, Decodable {
    let id: String
    let role: String
    let content: String
    let timestamp: Double?
    let toolName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case content
        case timestamp
        case toolName = "tool_name"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let intID = try? container.decode(Int.self, forKey: .id) {
            id = String(intID)
        } else if let stringID = try? container.decode(String.self, forKey: .id) {
            id = stringID
        } else {
            id = UUID().uuidString
        }

        role = (try? container.decode(String.self, forKey: .role)) ?? "message"
        content = HermesDashboardConversationMessage.decodeFlexibleContent(from: container) ?? ""
        timestamp = try? container.decode(Double.self, forKey: .timestamp)
        toolName = try? container.decode(String.self, forKey: .toolName)
    }

    private static func decodeFlexibleContent(from container: KeyedDecodingContainer<CodingKeys>) -> String? {
        if let string = try? container.decode(String.self, forKey: .content) {
            return string
        }

        if let array = try? container.decode([HermesFlexibleJSONValue].self, forKey: .content) {
            return array.map(\.readableText).filter { !$0.isEmpty }.joined(separator: "\n")
        }

        if let object = try? container.decode(HermesFlexibleJSONValue.self, forKey: .content) {
            return object.readableText
        }

        return nil
    }
}

private enum HermesFlexibleJSONValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([HermesFlexibleJSONValue])
    case object([String: HermesFlexibleJSONValue])
    case null

    var readableText: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return String(value)
        case .bool(let value):
            return String(value)
        case .array(let values):
            return values.map(\.readableText).filter { !$0.isEmpty }.joined(separator: "\n")
        case .object(let object):
            if let text = object["text"]?.readableText, !text.isEmpty {
                return text
            }
            if let content = object["content"]?.readableText, !content.isEmpty {
                return content
            }
            return object.values.map(\.readableText).filter { !$0.isEmpty }.joined(separator: "\n")
        case .null:
            return ""
        }
    }

    var objectValue: [String: HermesFlexibleJSONValue]? {
        if case .object(let object) = self {
            return object
        }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([HermesFlexibleJSONValue].self) {
            self = .array(value)
        } else {
            self = .object((try? container.decode([String: HermesFlexibleJSONValue].self)) ?? [:])
        }
    }
}

@MainActor
@Observable
final class HermesDashboardHistorySearchSession {
    var query = ""
    var results: [HermesDashboardConversationResult] = []
    var isSearching = false
    var status = "Idle"
    var lastErrorMessage = ""
    var matchedMessages = 0
    var matchedSessions = 0
    var isDashboardHTTPActive = false

    private var requestTask: Task<Void, Never>?
    private var cachedTokenByBaseURL: [String: String] = [:]

    func search(dashboardBaseURL: String, apiSettings: HermesAPISettings, profileFilter: String = "all", limit: Int = 25) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            results = []
            matchedMessages = 0
            matchedSessions = 0
            status = "Enter a search query"
            lastErrorMessage = ""
            return
        }

        requestTask?.cancel()
        requestTask = Task {
            await runSearch(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings, query: trimmedQuery, profileFilter: profileFilter, limit: limit)
        }
    }

    func cancel() {
        requestTask?.cancel()
        requestTask = nil
        isSearching = false
        isDashboardHTTPActive = false
        status = "Cancelled"
    }

    private func runSearch(dashboardBaseURL: String, apiSettings: HermesAPISettings, query: String, profileFilter: String, limit: Int) async {
        isSearching = true
        status = "Searching dashboard history"
        lastErrorMessage = ""

        do {
            try await HermesBackgroundActivity.run(named: "Hermes Dashboard History Search") {
                let baseURL = try resolvedDashboardBaseURL(from: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
                let token = try await dashboardSessionToken(baseURL: baseURL, apiSettings: apiSettings)
                let response: HermesDashboardConversationSearchResponse

                do {
                    response = try await fetchConversations(baseURL: baseURL, token: token, apiSettings: apiSettings, query: query, profileFilter: profileFilter, limit: limit)
                } catch HermesResponsesError.httpError(401) {
                    // Dashboard session tokens are ephemeral and change whenever the
                    // dashboard process restarts. If the simulator has a cached token
                    // from a previous server, refresh it once and retry automatically.
                    cachedTokenByBaseURL.removeValue(forKey: baseURL.absoluteString)
                    status = "Refreshing dashboard session token"
                    let refreshedToken = try await dashboardSessionToken(baseURL: baseURL, apiSettings: apiSettings)
                    response = try await fetchConversations(baseURL: baseURL, token: refreshedToken, apiSettings: apiSettings, query: query, profileFilter: profileFilter, limit: limit)
                }

                try Task.checkCancellation()
                let filteredResults = filter(response.results, profileFilter: profileFilter)
                results = filteredResults
                matchedMessages = filteredResults.reduce(0) { $0 + $1.matches.count }
                matchedSessions = filteredResults.count
                if profileFilter == "all" {
                    status = response.results.isEmpty ? "No matching conversations" : "Found \(response.matchedSessions) conversations"
                } else {
                    status = filteredResults.isEmpty ? "No matching conversations for \(displayProfileName(profileFilter))" : "Found \(filteredResults.count) conversations for \(displayProfileName(profileFilter))"
                }
            }
        } catch is CancellationError {
            status = "Cancelled"
        } catch {
            results = []
            matchedMessages = 0
            matchedSessions = 0
            lastErrorMessage = error.localizedDescription
            status = "Search failed"
        }

        isSearching = false
        isDashboardHTTPActive = false
    }

    private func filter(_ results: [HermesDashboardConversationResult], profileFilter: String) -> [HermesDashboardConversationResult] {
        let selected = normalizedProfileName(profileFilter)
        guard selected != "all" else { return results }
        return results.filter { result in
            let sessionProfile = normalizedProfileName(result.session.profile ?? "default")
            return sessionProfile == selected
        }
    }

    private func normalizedProfileName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "default" : trimmed.lowercased()
    }

    private func displayProfileName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Default" }
        return trimmed == "default" ? "Default" : trimmed
    }

    private func dashboardSessionToken(baseURL: URL, apiSettings: HermesAPISettings) async throws -> String {
        let cacheKey = baseURL.absoluteString
        if let cached = cachedTokenByBaseURL[cacheKey], !cached.isEmpty {
            return cached
        }

        status = "Fetching dashboard session token"
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        isDashboardHTTPActive = true
        defer { isDashboardHTTPActive = false }
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
            throw HermesDashboardHistorySearchError.missingDashboardSessionToken
        }

        let token = String(html[tokenRange])
        cachedTokenByBaseURL[cacheKey] = token
        return token
    }

    private func fetchConversations(
        baseURL: URL,
        token: String,
        apiSettings: HermesAPISettings,
        query: String,
        profileFilter: String,
        limit: Int
    ) async throws -> HermesDashboardConversationSearchResponse {
        status = "Fetching matching conversations"

        var components = URLComponents(url: baseURL.appendingPathComponent("api/sessions/search/conversations"), resolvingAgainstBaseURL: false)
        var queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "role", value: "user,assistant,tool")
        ]
        if normalizedProfileName(profileFilter) != "all" {
            queryItems.append(URLQueryItem(name: "profile", value: profileFilter))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw HermesDashboardHistorySearchError.invalidDashboardURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")

        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        isDashboardHTTPActive = true
        defer { isDashboardHTTPActive = false }
        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        return try JSONDecoder().decode(HermesDashboardConversationSearchResponse.self, from: data)
    }

    private func resolvedDashboardBaseURL(from dashboardBaseURL: String, apiBaseURL: String) throws -> URL {
        let explicit = dashboardBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicit.isEmpty, let url = normalizedBaseURL(from: explicit) {
            return url
        }

        var fallback = apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if fallback.hasSuffix("/v1") {
            fallback.removeLast(3)
        }
        guard let url = normalizedBaseURL(from: fallback) else {
            throw HermesDashboardHistorySearchError.invalidDashboardURL
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

enum HermesDashboardHistorySearchError: LocalizedError {
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
