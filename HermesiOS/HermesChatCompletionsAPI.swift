//
//  HermesChatCompletionsAPI.swift
//  HermesiOS
//
//  Created by Codex on 04/05/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class HermesChatSession {
    var entries: [HermesChatMessage] = []
    var streamedText = ""
    var isSending = false
    var activeProfile = ""
    var connectionStatus = "Idle"
    var activeChatSessionID = ""
    var lastKnownChatSessionID = ""
    var lastErrorMessage = ""
    var eventCount = 0
    var rawStreamedJSON = ""

    private var requestTask: Task<Void, Never>?
    private var activeAssistantEntryID: UUID?

    init() {
        lastKnownChatSessionID = HermesSettingsPersistence.loadLastChatSessionID()
    }

    func submit(apiSettings: HermesAPISettings, draft: HermesChatDraft, attachment: HermesPromptAttachment? = nil) {
        requestTask?.cancel()
        let requestedProfile = draft.profile.trimmingCharacters(in: .whitespacesAndNewlines)
        if activeProfile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            activeProfile = requestedProfile.isEmpty ? "default" : requestedProfile
        }
        if activeChatSessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            persistLastChatSessionID(Self.makeChatSessionID())
        }
        let lockedDraft = draft.locked(toProfile: activeProfile)
        requestTask = Task {
            await runRequest(apiSettings: apiSettings, draft: lockedDraft, attachment: attachment)
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
        activeProfile = ""
        activeChatSessionID = ""
        connectionStatus = "Idle"
        lastErrorMessage = ""
        eventCount = 0
        rawStreamedJSON = ""
    }

    func resumeLastKnownChatSession() {
        let sessionID = lastKnownChatSessionID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sessionID.isEmpty else {
            connectionStatus = "No previous chat"
            return
        }

        requestTask?.cancel()
        requestTask = nil
        entries = [HermesChatMessage(role: "assistant", content: "Resumed last Chat Completions session \(Self.shortSessionID(sessionID)). Send a new prompt to continue.")]
        streamedText = ""
        activeAssistantEntryID = nil
        isSending = false
        activeChatSessionID = sessionID
        lastErrorMessage = ""
        eventCount = 0
        rawStreamedJSON = ""
        connectionStatus = "Resumed last chat"
    }

    private static func makeChatSessionID() -> String {
        "hermes-ios-chat-\(UUID().uuidString.lowercased())"
    }

    private static func shortSessionID(_ sessionID: String) -> String {
        guard sessionID.count > 24 else { return sessionID }
        return String(sessionID.prefix(24)) + "…"
    }

    private func persistLastChatSessionID(_ sessionID: String) {
        let trimmed = sessionID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        activeChatSessionID = trimmed
        lastKnownChatSessionID = trimmed
        HermesSettingsPersistence.saveLastChatSessionID(trimmed)
    }

    private func runRequest(apiSettings: HermesAPISettings, draft: HermesChatDraft, attachment: HermesPromptAttachment?) async {
        let history = entries
        let prompt = draft.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayPrompt = displayPrompt(prompt, attachment: attachment)
        resetForRequest()
        appendExchange(prompt: displayPrompt)
        isSending = true
        connectionStatus = draft.stream ? "Connecting to chat stream" : "Sending chat request"

        do {
            try await HermesBackgroundActivity.run(named: "Hermes Chat Request") {
                if draft.stream {
                    try await streamResponse(apiSettings: apiSettings, draft: draft, attachment: attachment, history: history)
                } else {
                    try await fetchResponse(apiSettings: apiSettings, draft: draft, attachment: attachment, history: history)
                }
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
        lastErrorMessage = ""
        eventCount = 0
        rawStreamedJSON = ""
        activeAssistantEntryID = nil
    }

    private func appendExchange(prompt: String) {
        guard !prompt.isEmpty else { return }
        entries.append(.init(role: "user", content: prompt))
        let assistant = HermesChatMessage(role: "assistant", content: "")
        activeAssistantEntryID = assistant.id
        entries.append(assistant)
    }

    private func displayPrompt(_ prompt: String, attachment: HermesPromptAttachment?) -> String {
        guard let attachment else { return prompt }
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = "Attached: \(attachment.filename) (\(attachment.mimeType), \(attachment.formattedByteCount))"
        return trimmedPrompt.isEmpty ? label : "\(trimmedPrompt)\n\n\(label)"
    }

    private func updateActiveAssistantEntry(with content: String) {
        guard let activeAssistantEntryID,
              let index = entries.firstIndex(where: { $0.id == activeAssistantEntryID })
        else { return }
        var updatedEntries = entries
        updatedEntries[index].content = content
        entries = updatedEntries
    }

    private func streamResponse(apiSettings: HermesAPISettings, draft: HermesChatDraft, attachment: HermesPromptAttachment?, history: [HermesChatMessage]) async throws {
        let request = try buildRequest(apiSettings: apiSettings, draft: draft, attachment: attachment, history: history, stream: true)
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (bytes, response) = try await session.bytes(for: request)
        try validate(response: response)
        persistChatSessionID(from: response)

        var parser = HermesChatSSEParser()
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

    private func fetchResponse(apiSettings: HermesAPISettings, draft: HermesChatDraft, attachment: HermesPromptAttachment?, history: [HermesChatMessage]) async throws {
        let request = try buildRequest(apiSettings: apiSettings, draft: draft, attachment: attachment, history: history, stream: false)
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        persistChatSessionID(from: response)
        rawStreamedJSON = Self.prettyPrintedJSON(from: data)

        if let envelope = try? JSONDecoder().decode(HermesChatCompletionEnvelope.self, from: data) {
            persistLastChatSessionID(envelope.resolvedSessionID)
            streamedText = envelope.assistantText
        }
        eventCount = 1
        if streamedText.isEmpty {
            let payload = HermesLooseJSON(data: data)
            streamedText = extractChatText(from: payload)
        }
        updateActiveAssistantEntry(with: streamedText)
    }

    private func buildRequest(
        apiSettings: HermesAPISettings,
        draft: HermesChatDraft,
        attachment: HermesPromptAttachment?,
        history: [HermesChatMessage],
        stream: Bool
    ) throws -> URLRequest {
        guard let url = HermesAPISettings.chatCompletionsURL(from: apiSettings.baseURL) else {
            throw HermesResponsesError.invalidURL
        }

        let historyMessages = history.map { HermesChatRequestMessage(role: $0.role, content: .text($0.content)) }
        let userMessage = HermesChatRequestMessage(role: "user", content: HermesChatMessageContentPayload(prompt: draft.userPrompt, attachment: attachment))
        let requestMessages = draft.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? historyMessages + [userMessage]
            : [HermesChatRequestMessage(role: "system", content: .text(draft.systemPrompt))] + historyMessages + [userMessage]

        let payload = HermesChatCompletionsRequestBody(
            model: "hermes-agent",
            messages: requestMessages,
            stream: stream,
            user: activeChatSessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : activeChatSessionID
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(stream ? "text/event-stream" : "application/json", forHTTPHeaderField: "Accept")

        if stream {
            request.timeoutInterval = 0
        }

        let chatSessionID = activeChatSessionID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !chatSessionID.isEmpty {
            request.setValue(chatSessionID, forHTTPHeaderField: "x-hermes-session-id")
            request.setValue(chatSessionID, forHTTPHeaderField: "x-openclaw-session-key")
        }

        let profile = draft.profile.trimmingCharacters(in: .whitespacesAndNewlines)
        request.setValue(profile.isEmpty ? "default" : profile, forHTTPHeaderField: "X-Hermes-Profile")

        if !apiSettings.apiKey.isEmpty {
            request.setValue("Bearer \(apiSettings.apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONEncoder().encode(payload)
        return request
    }


    private func extractChatText(from payload: HermesLooseJSON, eventName: String? = nil) -> String {
        if let eventName {
            switch eventName {
            case "response.output_text.delta":
                return payload.string(at: ["delta"]) ?? ""
            case "response.output_text.done":
                return payload.string(at: ["text"]) ?? ""
            case "response.completed":
                return preferredText(from: [
                    payload.messageOutputTexts(at: ["response", "output"]),
                    payload.messageOutputTexts(at: ["output"]),
                    payload.texts(at: ["response", "output_text"]),
                    payload.texts(at: ["output_text"]),
                    payload.texts(at: ["choices", "0", "message", "content"]),
                    payload.texts(at: ["choices", "0", "delta", "content"]),
                    payload.texts(at: ["choices", "0", "text"])
                ])
            case "message", "completion", "chat.completion.chunk":
                break
            default:
                // The Hermes agent can emit Responses-style events for
                // reasoning, tool calls, tool results, and output-item state while
                // the Chat Completions tab is streaming. Those chunks are useful
                // for diagnostics, but assistant bubbles should only show the
                // final assistant text.
                if eventName.hasPrefix("response.") {
                    return ""
                }
            }
        }

        let candidates = [
            // OpenAI-compatible streaming and non-streaming shapes. Keep this
            // intentionally narrow so generic `content`/`text` fields from tool
            // or reasoning payloads never leak into assistant bubbles.
            payload.texts(at: ["choices", "0", "delta", "content"]),
            payload.texts(at: ["choices", "0", "message", "content"]),
            payload.texts(at: ["choices", "0", "text"]),
            payload.texts(at: ["delta", "content"]),
            payload.texts(at: ["message", "content"]),
            // Some Hermes/OpenAI-compatible gateways return a Responses-style
            // final envelope even from the chat endpoint. Extract only message
            // output so tool/reasoning items are ignored.
            payload.messageOutputTexts(at: ["output"]),
            payload.messageOutputTexts(at: ["response", "output"]),
            payload.texts(at: ["output_text"]),
            payload.texts(at: ["response", "output_text"]),
            payload.texts(at: ["response", "message", "content"])
        ]

        return preferredText(from: candidates)
    }

    private func preferredText(from candidates: [[String]]) -> String {
        candidates
            .map { $0.joined() }
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? ""
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HermesResponsesError.invalidResponse
        }

        guard 200 ..< 300 ~= httpResponse.statusCode else {
            throw HermesResponsesError.httpError(httpResponse.statusCode)
        }
    }

    private func persistChatSessionID(from response: URLResponse) {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        let candidates = [
            httpResponse.value(forHTTPHeaderField: "x-hermes-session-id"),
            httpResponse.value(forHTTPHeaderField: "x-openclaw-session-key")
        ]

        for candidate in candidates {
            if let value = candidate, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                persistLastChatSessionID(value)
                return
            }
        }
    }

    private func handle(event: HermesChatSSEEvent) {
        appendRawStreamedJSON(event)

        if event.data == "[DONE]" {
            connectionStatus = "Completed"
            return
        }

        var didExtractText = false
        for payloadString in Self.jsonPayloadStrings(from: event.data) {
            eventCount += 1
            let payload = HermesLooseJSON(json: payloadString)
            if let sessionID = payload.string(at: ["session_id"]) ?? payload.string(at: ["session", "id"]) {
                persistLastChatSessionID(sessionID)
            }
            let delta = extractChatText(from: payload, eventName: event.name)

            guard !delta.isEmpty else { continue }
            didExtractText = true

            switch event.name {
            case "response.output_text.done", "response.completed":
                if streamedText.isEmpty {
                    streamedText = delta
                } else if delta.hasPrefix(streamedText) {
                    streamedText = delta
                }
            default:
                streamedText += delta
            }
            updateActiveAssistantEntry(with: streamedText)
        }

        connectionStatus = didExtractText ? "Streaming output" : "Processing chat chunks"
    }

    private static func jsonPayloadStrings(from data: String) -> [String] {
        let trimmed = data.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var payloads: [String] = []
        var startIndex: String.Index?
        var depth = 0
        var isInsideString = false
        var isEscaped = false

        var index = trimmed.startIndex
        while index < trimmed.endIndex {
            let character = trimmed[index]

            if isInsideString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    isInsideString = false
                }
            } else {
                switch character {
                case "\"":
                    isInsideString = true
                case "{", "[":
                    if depth == 0 {
                        startIndex = index
                    }
                    depth += 1
                case "}", "]":
                    if depth > 0 {
                        depth -= 1
                    }
                    if depth == 0, let payloadStartIndex = startIndex {
                        let endIndex = trimmed.index(after: index)
                        payloads.append(String(trimmed[payloadStartIndex..<endIndex]))
                        startIndex = nil
                    }
                default:
                    break
                }
            }

            index = trimmed.index(after: index)
        }

        return payloads.isEmpty ? [trimmed] : payloads
    }

    private func appendRawStreamedJSON(_ event: HermesChatSSEEvent) {
        let eventName = event.name ?? "message"
        let payload = event.data == "[DONE]" ? "[DONE]" : Self.prettyPrintedJSON(from: event.data)
        let block = "event: \(eventName)\n\(payload)"

        if rawStreamedJSON.isEmpty {
            rawStreamedJSON = block
        } else {
            rawStreamedJSON += "\n\n\(block)"
        }
    }

    private static func prettyPrintedJSON(from string: String) -> String {
        prettyPrintedJSON(from: Data(string.utf8))
    }

    private static func prettyPrintedJSON(from data: Data) -> String {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            JSONSerialization.isValidJSONObject(object),
            let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
            let prettyString = String(data: prettyData, encoding: .utf8)
        else {
            return String(data: data, encoding: .utf8) ?? ""
        }
        return prettyString
    }
}

struct HermesChatDraft: Codable, Equatable {
    var profile = "default"
    var systemPrompt = "You are a helpful coding assistant."
    var userPrompt = "Summarize the current project layout."
    var stream = true

    enum CodingKeys: String, CodingKey {
        case profile
        case systemPrompt
        case userPrompt
        case stream
        case legacyModel = "model"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profile = try container.decodeIfPresent(String.self, forKey: .profile) ?? "default"
        _ = try container.decodeIfPresent(String.self, forKey: .legacyModel)
        systemPrompt = try container.decodeIfPresent(String.self, forKey: .systemPrompt) ?? systemPrompt
        userPrompt = try container.decodeIfPresent(String.self, forKey: .userPrompt) ?? userPrompt
        stream = try container.decodeIfPresent(Bool.self, forKey: .stream) ?? stream
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(profile, forKey: .profile)
        try container.encode(systemPrompt, forKey: .systemPrompt)
        try container.encode(userPrompt, forKey: .userPrompt)
        try container.encode(stream, forKey: .stream)
    }

    func locked(toProfile profile: String) -> HermesChatDraft {
        var copy = self
        let trimmedProfile = profile.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.profile = trimmedProfile.isEmpty ? "default" : trimmedProfile
        return copy
    }
}

struct HermesChatMessage: Identifiable {
    let id = UUID()
    let role: String
    var content: String
}

private struct HermesChatCompletionsRequestBody: Encodable {
    let model: String
    let messages: [HermesChatRequestMessage]
    let stream: Bool
    let user: String?
}

private enum HermesChatMessageContentPayload: Encodable {
    case text(String)
    case parts([HermesChatRequestContentPart])

    init(prompt: String, attachment: HermesPromptAttachment?) {
        guard let attachment else {
            self = .text(prompt)
            return
        }

        if attachment.isImage {
            let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Please inspect the attached image." : prompt
            self = .parts([
                .text(text),
                .imageURL(attachment.base64DataURL)
            ])
        } else {
            let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            let basePrompt = trimmedPrompt.isEmpty ? "Please inspect the attached file." : trimmedPrompt
            self = .text(basePrompt + attachment.textAttachmentBlock)
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let text):
            var container = encoder.singleValueContainer()
            try container.encode(text)
        case .parts(let parts):
            var container = encoder.singleValueContainer()
            try container.encode(parts)
        }
    }
}

private enum HermesChatRequestContentPart: Encodable {
    case text(String)
    case imageURL(String)

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
    }

    enum ImageURLKeys: String, CodingKey {
        case url
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .imageURL(let dataURL):
            try container.encode("image_url", forKey: .type)
            var imageContainer = container.nestedContainer(keyedBy: ImageURLKeys.self, forKey: .imageURL)
            try imageContainer.encode(dataURL, forKey: .url)
        }
    }
}

private struct HermesChatRequestMessage: Encodable {
    let role: String
    let content: HermesChatMessageContentPayload
}

private struct HermesChatCompletionEnvelope: Decodable {
    let id: String?
    let sessionID: String?
    let choices: [HermesChatChoice]

    var assistantText: String {
        choices.compactMap(\.message?.text).filter { !$0.isEmpty }.joined(separator: "\n\n")
    }

    var resolvedSessionID: String {
        sessionID ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case id
        case sessionID = "session_id"
        case choices
    }
}

private struct HermesChatChoice: Decodable {
    let message: HermesChatChoiceMessage?
}

private struct HermesChatChoiceMessage: Decodable {
    let content: HermesChatMessageContent?

    var text: String {
        content?.text ?? ""
    }
}

private struct HermesChatMessageContent: Decodable {
    let text: String

    init(from decoder: Decoder) throws {
        if let value = try? decoder.singleValueContainer(), let string = try? value.decode(String.self) {
            text = string
            return
        }

        if let parts = try? [HermesChatContentPart](from: decoder) {
            text = parts.compactMap(\.textValue).joined()
            return
        }

        text = ""
    }
}

private struct HermesChatContentPart: Decodable {
    let text: String?
    let outputText: String?

    var textValue: String? {
        text ?? outputText
    }

    enum CodingKeys: String, CodingKey {
        case text
        case outputText = "output_text"
    }
}

private struct HermesChatSSEEvent {
    let name: String?
    let data: String
}

private struct HermesChatSSEParser {
    private var eventName: String?
    private var dataLines: [String] = []

    mutating func consume(line: String) -> HermesChatSSEEvent? {
        if line.isEmpty {
            return flush()
        }

        if line.hasPrefix("event:") {
            eventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
        } else if line.hasPrefix("data:") {
            let value = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            dataLines.append(value)
        }

        return nil
    }

    mutating func finish() -> HermesChatSSEEvent? {
        flush()
    }

    private mutating func flush() -> HermesChatSSEEvent? {
        guard !dataLines.isEmpty else {
            eventName = nil
            return nil
        }
        let event = HermesChatSSEEvent(name: eventName, data: dataLines.joined(separator: "\n"))
        eventName = nil
        dataLines.removeAll(keepingCapacity: true)
        return event
    }
}
