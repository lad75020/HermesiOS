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
    var connectionStatus = "Idle"
    var lastErrorMessage = ""
    var eventCount = 0
    var rawStreamedJSON = ""
    var activeModel = ""

    private var requestTask: Task<Void, Never>?
    private var activeAssistantEntryID: UUID?

    func submit(apiSettings: HermesAPISettings, draft: HermesChatDraft) {
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
        lastErrorMessage = ""
        eventCount = 0
        rawStreamedJSON = ""
        activeModel = ""
    }

    private func runRequest(apiSettings: HermesAPISettings, draft: HermesChatDraft) async {
        let history = entries
        let prompt = draft.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let sessionDraft = draft.locked(to: activeModel.isEmpty ? draft.model : activeModel)
        if activeModel.isEmpty {
            activeModel = sessionDraft.model
        }
        resetForRequest()
        appendExchange(prompt: prompt)
        isSending = true
        connectionStatus = draft.stream ? "Connecting to chat stream" : "Sending chat request"

        do {
            try await HermesBackgroundActivity.run(named: "Hermes Chat Request") {
                if draft.stream {
                    try await streamResponse(apiSettings: apiSettings, draft: sessionDraft, history: history)
                } else {
                    try await fetchResponse(apiSettings: apiSettings, draft: sessionDraft, history: history)
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

    private func updateActiveAssistantEntry(with content: String) {
        guard let activeAssistantEntryID,
              let index = entries.firstIndex(where: { $0.id == activeAssistantEntryID })
        else { return }
        var updatedEntries = entries
        updatedEntries[index].content = content
        entries = updatedEntries
    }

    private func streamResponse(apiSettings: HermesAPISettings, draft: HermesChatDraft, history: [HermesChatMessage]) async throws {
        let request = try buildRequest(apiSettings: apiSettings, draft: draft, history: history, stream: true)
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (bytes, response) = try await session.bytes(for: request)
        try validate(response: response)

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

    private func fetchResponse(apiSettings: HermesAPISettings, draft: HermesChatDraft, history: [HermesChatMessage]) async throws {
        let request = try buildRequest(apiSettings: apiSettings, draft: draft, history: history, stream: false)
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        rawStreamedJSON = Self.prettyPrintedJSON(from: data)

        if let envelope = try? JSONDecoder().decode(HermesChatCompletionEnvelope.self, from: data) {
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
        history: [HermesChatMessage],
        stream: Bool
    ) throws -> URLRequest {
        guard let url = HermesAPISettings.chatCompletionsURL(from: apiSettings.baseURL) else {
            throw HermesResponsesError.invalidURL
        }

        let historyMessages = history.map { HermesChatRequestMessage(role: $0.role, content: $0.content) }
        let requestMessages = draft.systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? historyMessages + [HermesChatRequestMessage(role: "user", content: draft.userPrompt)]
            : [HermesChatRequestMessage(role: "system", content: draft.systemPrompt)] + historyMessages + [HermesChatRequestMessage(role: "user", content: draft.userPrompt)]

        let payload = HermesChatCompletionsRequestBody(
            model: draft.model,
            messages: requestMessages,
            stream: stream
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(stream ? "text/event-stream" : "application/json", forHTTPHeaderField: "Accept")

        if stream {
            request.timeoutInterval = 0
        }

        if !apiSettings.apiKey.isEmpty {
            request.setValue("Bearer \(apiSettings.apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONEncoder().encode(payload)
        return request
    }


    private func extractChatText(from payload: HermesLooseJSON, eventName: String? = nil) -> String {
        switch eventName {
        case "response.output_text.delta":
            return payload.string(at: ["delta"]) ?? ""
        case "response.output_text.done":
            return payload.string(at: ["text"]) ?? ""
        default:
            break
        }

        let candidates = [
            // OpenAI-compatible streaming and non-streaming shapes.
            payload.texts(at: ["choices", "0", "delta", "content"]),
            payload.texts(at: ["choices", "0", "message", "content"]),
            payload.texts(at: ["choices", "0", "text"]),
            payload.texts(at: ["delta", "content"]),
            payload.texts(at: ["delta"]),
            payload.texts(at: ["message", "content"]),
            payload.texts(at: ["content"]),
            payload.texts(at: ["text"]),
            // Some Hermes/OpenAI-compatible gateways return a Responses-style
            // envelope even from the chat endpoint, especially for final SSE
            // events. Extract only message output first to avoid tool/reasoning
            // chatter, then fall back to text-like output fields.
            payload.messageOutputTexts(at: ["output"]),
            payload.messageOutputTexts(at: ["response", "output"]),
            payload.texts(at: ["output_text"]),
            payload.texts(at: ["response", "output_text"]),
            payload.texts(at: ["response", "message", "content"])
        ]

        if let preferred = candidates
            .map({ $0.joined() })
            .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            return preferred
        }

        return payload.chatCompletionFallbackText
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HermesResponsesError.invalidResponse
        }

        guard 200 ..< 300 ~= httpResponse.statusCode else {
            throw HermesResponsesError.httpError(httpResponse.statusCode)
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
    var model = "hermes-agent"
    var systemPrompt = "You are a helpful coding assistant."
    var userPrompt = "Summarize the current project layout."
    var stream = true

    func locked(to model: String) -> HermesChatDraft {
        var copy = self
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedModel.isEmpty {
            copy.model = trimmedModel
        }
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
}

private struct HermesChatRequestMessage: Encodable {
    let role: String
    let content: String
}

private struct HermesChatCompletionEnvelope: Decodable {
    let choices: [HermesChatChoice]

    var assistantText: String {
        choices.compactMap(\.message?.text).filter { !$0.isEmpty }.joined(separator: "\n\n")
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
