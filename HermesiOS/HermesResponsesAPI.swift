//
//  HermesResponsesAPI.swift
//  HermesiOS
//
//  Created by Codex on 04/05/2026.
//

import Foundation
import Observation

final class HermesNetworkSessionDelegate: NSObject, URLSessionDelegate {
    private let allowSelfSignedCertificates: Bool

    init(allowSelfSignedCertificates: Bool) {
        self.allowSelfSignedCertificates = allowSelfSignedCertificates
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard
            allowSelfSignedCertificates,
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let trust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

enum HermesNetworkSessionFactory {
    static func session(for apiSettings: HermesAPISettings) -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 3600

        if apiSettings.allowSelfSignedCertificates {
            let delegate = HermesNetworkSessionDelegate(
                allowSelfSignedCertificates: apiSettings.allowSelfSignedCertificates
            )
            return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        }

        return URLSession(configuration: configuration)
    }
}

@MainActor
@Observable
final class HermesResponsesSession {
    var entries: [HermesResponseMessage] = []
    var streamedText = ""
    var isSending = false
    var connectionStatus = "Idle"
    var latestResponseID = ""
    var previousResponseID = ""
    var lastErrorMessage = ""
    var latestMessageType = ""
    var eventCount = 0
    var rawStreamedJSON = ""

    var hasActiveConversation: Bool {
        !previousResponseID.isEmpty || !latestResponseID.isEmpty || !entries.isEmpty || isSending
    }

    private var requestTask: Task<Void, Never>?
    private var activeAssistantEntryID: UUID?

    func submit(apiSettings: HermesAPISettings, draft: HermesRequestDraft) {
        requestTask?.cancel()
        requestTask = Task {
            await runRequest(apiSettings: apiSettings, draft: draft)
        }
    }

    func cancel() {
        requestTask?.cancel()
        requestTask = nil
        isSending = false
        connectionStatus = "Cancelled"
    }

    func resetConversation() {
        requestTask?.cancel()
        requestTask = nil
        entries = []
        streamedText = ""
        activeAssistantEntryID = nil
        isSending = false
        connectionStatus = "Idle"
        latestResponseID = ""
        previousResponseID = ""
        lastErrorMessage = ""
        latestMessageType = ""
        eventCount = 0
        rawStreamedJSON = ""
    }

    func terminateAndStartNewSession() {
        resetConversation()
        connectionStatus = "New session ready"
    }

    func resumeConversation(from result: HermesDashboardConversationResult) {
        requestTask?.cancel()
        requestTask = nil
        streamedText = ""
        activeAssistantEntryID = nil
        isSending = false
        latestResponseID = ""
        let continuationID = Self.responseContinuationID(from: result)
        previousResponseID = continuationID
        lastErrorMessage = ""
        latestMessageType = continuationID.isEmpty ? "loaded history" : "resumed response"
        eventCount = 0
        rawStreamedJSON = ""

        let restoredEntries = result.messages
            .filter { message in
                let role = message.role.lowercased()
                return (role == "user" || role == "assistant") && !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .map { message in
                HermesResponseMessage(role: message.role.lowercased(), content: message.content)
            }

        let trimmedTitle = result.session.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let displayTitle = trimmedTitle.isEmpty ? continuationID : trimmedTitle

        entries = restoredEntries.isEmpty
            ? [HermesResponseMessage(role: "assistant", content: "Loaded session \(displayTitle). Send a new prompt to start a new Responses API turn.")]
            : restoredEntries
        connectionStatus = continuationID.isEmpty ? "Loaded history" : "Resumed response"
    }

    private static func responseContinuationID(from result: HermesDashboardConversationResult) -> String {
        [result.sessionID, result.session.id]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { $0.hasPrefix("resp_") } ?? ""
    }

    private func runRequest(apiSettings: HermesAPISettings, draft: HermesRequestDraft) async {
        let continuationID = previousResponseID
        let prompt = draft.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        resetForRequest()
        appendExchange(prompt: prompt)
        isSending = true
        connectionStatus = continuationID.isEmpty
            ? (draft.stream ? "Connecting to SSE stream" : "Sending request")
            : (draft.stream ? "Continuing SSE stream" : "Continuing request")

        do {
            try await HermesBackgroundActivity.run(named: "Hermes Responses Request") {
                if draft.stream {
                    try await streamResponse(apiSettings: apiSettings, draft: draft, previousResponseID: continuationID)
                } else {
                    try await fetchResponse(apiSettings: apiSettings, draft: draft, previousResponseID: continuationID)
                }
            }
            if !latestResponseID.isEmpty {
                previousResponseID = latestResponseID
            }
            if !Task.isCancelled {
                connectionStatus = "Completed"
            }
        } catch is CancellationError {
            connectionStatus = "Cancelled"
            updateActiveAssistantEntry(with: streamedText.isEmpty ? "Cancelled." : streamedText)
        } catch {
            lastErrorMessage = error.localizedDescription
            connectionStatus = "Failed"
            updateActiveAssistantEntry(with: streamedText.isEmpty ? "Request failed: \(error.localizedDescription)" : streamedText)
        }

        isSending = false
    }

    private func resetForRequest() {
        streamedText = ""
        latestResponseID = ""
        lastErrorMessage = ""
        latestMessageType = ""
        eventCount = 0
        rawStreamedJSON = ""
        activeAssistantEntryID = nil
    }

    private func appendExchange(prompt: String) {
        guard !prompt.isEmpty else { return }
        entries.append(HermesResponseMessage(role: "user", content: prompt))
        let assistant = HermesResponseMessage(role: "assistant", content: "")
        activeAssistantEntryID = assistant.id
        entries.append(assistant)
    }

    private func updateActiveAssistantEntry(with content: String) {
        guard let activeAssistantEntryID,
              let index = entries.firstIndex(where: { $0.id == activeAssistantEntryID })
        else { return }
        var updatedEntries = entries
        updatedEntries[index].content = content
        entries = updatedEntries
    }

    private func streamResponse(apiSettings: HermesAPISettings, draft: HermesRequestDraft, previousResponseID: String) async throws {
        let request = try buildRequest(
            apiSettings: apiSettings,
            draft: draft,
            stream: true,
            previousResponseID: previousResponseID
        )
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (bytes, response) = try await session.bytes(for: request)
        try validate(response: response)

        var parser = HermesSSEParser()
        for try await line in bytes.lines {
            try Task.checkCancellation()
            if let event = parser.consume(line: line) {
                handle(event: event)
            }
        }

        if let event = parser.finish() {
            handle(event: event)
        }
    }

    private func fetchResponse(apiSettings: HermesAPISettings, draft: HermesRequestDraft, previousResponseID: String) async throws {
        let request = try buildRequest(
            apiSettings: apiSettings,
            draft: draft,
            stream: false,
            previousResponseID: previousResponseID
        )
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (data, response) = try await session.data(for: request)
        try validate(response: response)

        let envelope = try JSONDecoder().decode(HermesResponseEnvelope.self, from: data)
        rawStreamedJSON = Self.prettyPrintedJSON(from: data)
        latestResponseID = envelope.id ?? ""
        streamedText = envelope.assistantText
        updateActiveAssistantEntry(with: streamedText)
        latestMessageType = envelope.outputMessageType
        eventCount = 1
    }

    private func buildRequest(
        apiSettings: HermesAPISettings,
        draft: HermesRequestDraft,
        stream: Bool,
        previousResponseID: String
    ) throws -> URLRequest {
        guard let url = HermesAPISettings.responseURL(from: apiSettings.baseURL) else {
            throw HermesResponsesError.invalidURL
        }

        let payload = HermesResponsesRequestBody(
            input: draft.userPrompt,
            instructions: draft.instructions,
            stream: stream,
            store: true,
            previousResponseID: previousResponseID.isEmpty ? nil : previousResponseID
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if stream {
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 0
        }

        if !apiSettings.apiKey.isEmpty {
            request.setValue("Bearer \(apiSettings.apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONEncoder().encode(payload)
        return request
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HermesResponsesError.invalidResponse
        }

        guard 200 ..< 300 ~= httpResponse.statusCode else {
            throw HermesResponsesError.httpError(httpResponse.statusCode)
        }
    }

    private func handle(event: HermesSSEEvent) {
        appendRawStreamedJSON(event)

        if event.data == "[DONE]" {
            connectionStatus = "Completed"
            return
        }

        eventCount += 1
        let summary = HermesEventSummaryBuilder.summary(for: event)
        latestMessageType = summary.messageType

        if let responseID = summary.responseID, !responseID.isEmpty {
            latestResponseID = responseID
        }

        if let delta = summary.outputDelta, !delta.isEmpty {
            if streamedText.isEmpty {
                streamedText = delta
            } else if summary.title == "response.completed" && streamedText.count >= delta.count {
                streamedText = streamedText
            } else if delta.hasPrefix(streamedText) {
                streamedText = delta
            } else if !streamedText.hasSuffix(delta) {
                streamedText += delta
            }
            updateActiveAssistantEntry(with: streamedText)
            connectionStatus = "Streaming output"
        } else if summary.title.hasPrefix("response.output_item.") {
            connectionStatus = summary.status
        } else {
            connectionStatus = "Processing \(summary.title)"
        }

    }

    private func appendRawStreamedJSON(_ event: HermesSSEEvent) {
        let eventName = event.event ?? "message"
        let payload = event.data == "[DONE]" ? "[DONE]" : Self.prettyPrintedJSON(from: event.data)
        let block = "event: \(eventName)\n\(payload)"
        rawStreamedJSON = rawStreamedJSON.isEmpty ? block : rawStreamedJSON + "\n\n" + block
    }

    private static func prettyPrintedJSON(from string: String) -> String {
        guard let data = string.data(using: .utf8) else { return string }
        return prettyPrintedJSON(from: data)
    }

    private static func prettyPrintedJSON(from data: Data) -> String {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let prettyData = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys]
            ),
            let pretty = String(data: prettyData, encoding: .utf8)
        else {
            return String(data: data, encoding: .utf8) ?? ""
        }
        return pretty
    }
}


struct HermesResponseMessage: Identifiable {
    let id = UUID()
    let role: String
    var content: String
}

struct HermesAPISettings: Codable, Equatable {
    var baseURL = "http://127.0.0.1:8642/v1"
    var apiKey = ""
    var allowSelfSignedCertificates = false

    static func responseURL(from baseURL: String) -> URL? {
        endpointURL(from: baseURL, suffix: "responses")
    }

    static func chatCompletionsURL(from baseURL: String) -> URL? {
        endpointURL(from: baseURL, suffix: "chat/completions")
    }

    private static func endpointURL(from baseURL: String, suffix: String) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasSuffix("/\(suffix)") {
            return URL(string: trimmed)
        }

        guard var components = URLComponents(string: trimmed) else { return nil }
        let normalizedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        // The Hermes API server is documented as an OpenAI-compatible `/v1` endpoint,
        // but it is easy to enter only the host/port in Settings (for example
        // `http://127.0.0.1:8642`).  Without this guard the Responses tab posts to
        // `/responses`, which the API server correctly reports as 404.  Treat a bare
        // origin as the Hermes API root and add `/v1` before the endpoint suffix.
        if normalizedPath.isEmpty {
            components.path = "/v1/\(suffix)"
            return components.url
        }

        if trimmed.hasSuffix("/") {
            return URL(string: trimmed + suffix)
        }

        return URL(string: trimmed + "/" + suffix)
    }
}

struct HermesRequestDraft: Codable, Equatable {
    var model = "hermes-agent"
    var instructions = "You are a helpful coding assistant."
    var userPrompt = "Summarize the current project layout and recommend the next integration step."
    var stream = true

    func locked(to model: String) -> HermesRequestDraft {
        var copy = self
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedModel.isEmpty {
            copy.model = trimmedModel
        }
        return copy
    }
}

private struct HermesResponsesRequestBody: Encodable {
    let input: String
    let instructions: String
    let stream: Bool
    let store: Bool
    let previousResponseID: String?

    enum CodingKeys: String, CodingKey {
        case input
        case instructions
        case stream
        case store
        case previousResponseID = "previous_response_id"
    }
}

private struct HermesResponseEnvelope: Decodable {
    let id: String?
    let status: String?
    let output: [HermesResponseOutputItem]?

    var assistantText: String {
        guard let output else { return "" }
        return output.compactMap(\.assistantText).joined(separator: "\n\n")
    }

    var outputMessageType: String {
        guard let output, let item = output.first(where: { $0.assistantText?.isEmpty == false }) else {
            return "message"
        }
        return item.type
    }
}

private struct HermesResponseOutputItem: Decodable {
    let type: String
    let content: [HermesResponseContent]?
    let output: [HermesResponseContent]?

    var assistantText: String? {
        guard type == "message" else { return nil }
        let text = (content ?? output ?? [])
            .filter { $0.type == "output_text" || $0.type == "text" || $0.type == "message" }
            .compactMap(\.text)
            .joined()
        return text.isEmpty ? nil : text
    }
}

private struct HermesResponseContent: Decodable {
    let type: String
    let text: String?
}

private struct HermesSSEEvent {
    let event: String?
    let data: String
}

private struct HermesSSEParser {
    private var eventName: String?
    private var dataLines: [String] = []

    mutating func consume(line: String) -> HermesSSEEvent? {
        if line.isEmpty {
            return flush()
        }

        if line.hasPrefix("event:") {
            if !dataLines.isEmpty || eventName != nil {
                let pending = flush()
                eventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                return pending
            }
            eventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
        } else if line.hasPrefix("data:") {
            let value = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            dataLines.append(value)
        }

        return nil
    }

    mutating func finish() -> HermesSSEEvent? {
        flush()
    }

    private mutating func flush() -> HermesSSEEvent? {
        guard !dataLines.isEmpty || eventName != nil else { return nil }
        let payload = dataLines.joined(separator: "\n")
        let event = HermesSSEEvent(event: eventName, data: payload)
        eventName = nil
        dataLines.removeAll(keepingCapacity: true)
        return event
    }
}

private struct HermesEventSummary {
    let title: String
    let messageType: String
    let status: String
    let detail: String
    let metadata: [String]
    let responseID: String?
    let outputDelta: String?
    let includeInTimeline: Bool
}

private enum HermesEventSummaryBuilder {
    static func summary(for event: HermesSSEEvent) -> HermesEventSummary {
        let title = event.event ?? "message"
        let payload = HermesLooseJSON(json: event.data)

        switch title {
        case "response.created":
            let responseID = payload.string(at: ["response", "id"]) ?? payload.string(at: ["id"])
            let status = payload.string(at: ["response", "status"]) ?? payload.string(at: ["status"]) ?? "Created"
            return HermesEventSummary(
                title: title,
                messageType: "response",
                status: status.capitalized,
                detail: responseID.map { "Started response \($0)." } ?? "Response created.",
                metadata: compactMetadata([
                    responseID.map { "Response ID: \($0)" }
                ]),
                responseID: responseID,
                outputDelta: nil,
                includeInTimeline: true
            )

        case "response.output_text.delta":
            let delta = payload.string(at: ["delta"]) ?? ""
            return HermesEventSummary(
                title: title,
                messageType: "message",
                status: "Streaming",
                detail: delta.isEmpty ? "Received output delta." : delta,
                metadata: compactMetadata([
                    payload.string(at: ["item_id"]).map { "Item ID: \($0)" },
                    payload.string(at: ["output_index"]).map { "Output Index: \($0)" }
                ]),
                responseID: payload.string(at: ["response_id"]),
                outputDelta: delta,
                includeInTimeline: false
            )

        case "response.output_text.done":
            let text = payload.string(at: ["text"]) ?? ""
            return HermesEventSummary(
                title: title,
                messageType: "message",
                status: "Completed",
                detail: text.isEmpty ? "Received finalized output text." : text,
                metadata: compactMetadata([
                    payload.string(at: ["item_id"]).map { "Item ID: \($0)" },
                    payload.string(at: ["output_index"]).map { "Output Index: \($0)" }
                ]),
                responseID: payload.string(at: ["response_id"]),
                outputDelta: text,
                includeInTimeline: true
            )

        case let eventName where eventName.hasPrefix("response.output_item."):
            let itemType = payload.string(at: ["item", "type"]) ?? payload.string(at: ["type"]) ?? "item"
            let name = payload.string(at: ["item", "name"]) ?? payload.string(at: ["name"])
            let itemStatus = payload.string(at: ["item", "status"])
                ?? payload.string(at: ["status"])
                ?? String(eventName.dropFirst("response.output_item.".count))
            let statusText = "\(name ?? itemType): \(itemStatus)"
            let detail = name.map { "\(itemType) \($0)" } ?? "Received \(itemType)."
            return HermesEventSummary(
                title: title,
                messageType: itemType,
                status: statusText,
                detail: detail,
                metadata: compactMetadata([
                    payload.string(at: ["item", "call_id"]).map { "Call ID: \($0)" },
                    payload.string(at: ["output_index"]).map { "Output Index: \($0)" }
                ]),
                responseID: payload.string(at: ["response_id"]),
                outputDelta: nil,
                includeInTimeline: itemType != "message"
            )

        case "response.completed":
            let responseID = payload.string(at: ["response", "id"]) ?? payload.string(at: ["id"])
            let status = payload.string(at: ["response", "status"]) ?? payload.string(at: ["status"]) ?? "Completed"
            let outputText = payload.messageOutputTexts(at: ["response", "output"]).joined(separator: "\n\n")
            return HermesEventSummary(
                title: title,
                messageType: "response",
                status: status.capitalized,
                detail: outputText.isEmpty ? "Hermes finished the streamed response." : outputText,
                metadata: compactMetadata([
                    responseID.map { "Response ID: \($0)" }
                ]),
                responseID: responseID,
                outputDelta: outputText.isEmpty ? nil : outputText,
                includeInTimeline: true
            )

        default:
            return HermesEventSummary(
                title: title,
                messageType: title,
                status: "Event",
                detail: payload.primaryDescription ?? event.data,
                metadata: [],
                responseID: payload.string(at: ["response_id"]),
                outputDelta: nil,
                includeInTimeline: false
            )
        }
    }

    private static func compactMetadata(_ values: [String?]) -> [String] {
        values.compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
    }
}

struct HermesLooseJSON {
    private let object: Any?

    init(json: String) {
        if let data = json.data(using: .utf8) {
            object = try? JSONSerialization.jsonObject(with: data)
        } else {
            object = nil
        }
    }

    init(data: Data) {
        object = try? JSONSerialization.jsonObject(with: data)
    }

    func string(at path: [String]) -> String? {
        guard let value = value(at: path) else { return nil }

        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    func texts(at path: [String]) -> [String] {
        guard let value = value(at: path) else { return [] }
        return extractTexts(from: value)
    }

    func messageOutputTexts(at path: [String]) -> [String] {
        guard let value = value(at: path) else { return [] }
        return extractMessageOutputTexts(from: value)
    }

    var primaryDescription: String? {
        if let message = string(at: ["message"]) {
            return message
        }

        if let error = string(at: ["error", "message"]) {
            return error
        }

        return nil
    }

    var chatCompletionFallbackText: String {
        guard let object else { return "" }
        return extractChatFallbackTexts(from: object).joined()
    }

    private func value(at path: [String]) -> Any? {
        var current = object

        for key in path {
            if let index = Int(key), let array = current as? [Any], array.indices.contains(index) {
                current = array[index]
            } else {
                guard let dictionary = current as? [String: Any] else {
                    return nil
                }
                current = dictionary[key]
            }
        }

        return current
    }

    private func extractMessageOutputTexts(from value: Any) -> [String] {
        if let array = value as? [Any] {
            return array.flatMap(extractMessageOutputTexts)
        }

        guard let dictionary = value as? [String: Any] else { return [] }

        if let type = dictionary["type"] as? String, type != "message" {
            return []
        }

        if let content = dictionary["content"] ?? dictionary["output"] {
            return extractTexts(from: content)
        }

        return extractTexts(from: dictionary)
    }

    private func extractTexts(from value: Any) -> [String] {
        if let string = value as? String {
            return [string]
        }

        if let dictionary = value as? [String: Any] {
            if let text = dictionary["text"] as? String {
                return [text]
            }

            if let outputText = dictionary["output_text"] as? String {
                return [outputText]
            }

            return dictionary.values.flatMap(extractTexts)
        }

        if let array = value as? [Any] {
            return array.flatMap(extractTexts)
        }

        return []
    }

    private func extractChatFallbackTexts(from value: Any) -> [String] {
        if let string = value as? String {
            return [string]
        }

        if let array = value as? [Any] {
            return array.flatMap(extractChatFallbackTexts)
        }

        guard let dictionary = value as? [String: Any] else { return [] }

        let directKeys = ["content", "text", "output_text"]
        let directTexts = directKeys.flatMap { key in
            dictionary[key].map(extractTexts(from:)) ?? []
        }
        if !directTexts.isEmpty {
            return directTexts
        }

        let metadataKeys: Set<String> = [
            "id", "object", "created", "created_at", "model", "system_fingerprint",
            "service_tier", "finish_reason", "index", "role", "type", "status",
            "usage", "prompt_tokens", "completion_tokens", "total_tokens"
        ]

        return dictionary
            .filter { !metadataKeys.contains($0.key) }
            .values
            .flatMap(extractChatFallbackTexts)
    }
}

enum HermesResponsesError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "The Hermes gateway URL is invalid."
        case .invalidResponse:
            "The Hermes gateway returned an invalid response."
        case .httpError(let statusCode):
            "The Hermes gateway returned HTTP \(statusCode)."
        }
    }
}
