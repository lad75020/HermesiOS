//
//  HermesResponsesAPI.swift
//  HermesiOS
//
//  Created by Codex on 04/05/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class HermesResponsesSession {
    var entries: [HermesResponseEntry] = []
    var streamedText = ""
    var isSending = false
    var connectionStatus = "Idle"
    var latestResponseID = ""
    var lastErrorMessage = ""
    var eventCount = 0

    private var requestTask: Task<Void, Never>?

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

    private func runRequest(apiSettings: HermesAPISettings, draft: HermesRequestDraft) async {
        resetForRequest()
        isSending = true
        connectionStatus = draft.stream ? "Connecting to SSE stream" : "Sending request"

        do {
            if draft.stream {
                try await streamResponse(apiSettings: apiSettings, draft: draft)
            } else {
                try await fetchResponse(apiSettings: apiSettings, draft: draft)
            }
            if !Task.isCancelled {
                connectionStatus = "Completed"
            }
        } catch is CancellationError {
            connectionStatus = "Cancelled"
        } catch {
            lastErrorMessage = error.localizedDescription
            connectionStatus = "Failed"
            entries.insert(
                HermesResponseEntry(
                    title: "Request Error",
                    status: "Failed",
                    summary: error.localizedDescription,
                    metadata: []
                ),
                at: 0
            )
        }

        isSending = false
    }

    private func resetForRequest() {
        entries = []
        streamedText = ""
        latestResponseID = ""
        lastErrorMessage = ""
        eventCount = 0
    }

    private func streamResponse(apiSettings: HermesAPISettings, draft: HermesRequestDraft) async throws {
        let request = try buildRequest(apiSettings: apiSettings, draft: draft, stream: true)
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
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

    private func fetchResponse(apiSettings: HermesAPISettings, draft: HermesRequestDraft) async throws {
        let request = try buildRequest(apiSettings: apiSettings, draft: draft, stream: false)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response)

        let envelope = try JSONDecoder().decode(HermesResponseEnvelope.self, from: data)
        latestResponseID = envelope.id ?? ""
        streamedText = envelope.assistantText
        eventCount = 1
        entries = [
            HermesResponseEntry(
                title: "response.completed",
                status: envelope.status?.capitalized ?? "Completed",
                summary: envelope.assistantText.isEmpty ? "No assistant text returned." : envelope.assistantText,
                metadata: compactMetadata([
                    envelope.id.map { "Response ID: \($0)" },
                    "Mode: Non-streaming"
                ])
            )
        ]
    }

    private func buildRequest(apiSettings: HermesAPISettings, draft: HermesRequestDraft, stream: Bool) throws -> URLRequest {
        guard let url = HermesAPISettings.responseURL(from: apiSettings.baseURL) else {
            throw HermesResponsesError.invalidURL
        }

        let payload = HermesResponsesRequestBody(
            model: draft.model,
            input: draft.userPrompt,
            instructions: draft.instructions,
            stream: stream,
            store: true
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
        if event.data == "[DONE]" {
            connectionStatus = "Completed"
            return
        }

        eventCount += 1
        let summary = HermesEventSummaryBuilder.summary(for: event)

        if let responseID = summary.responseID, !responseID.isEmpty {
            latestResponseID = responseID
        }

        if let delta = summary.outputDelta, !delta.isEmpty {
            streamedText += delta
            connectionStatus = "Streaming output"
        } else {
            connectionStatus = "Processing \(summary.title)"
        }

        entries.insert(
            HermesResponseEntry(
                title: summary.title,
                status: summary.status,
                summary: summary.detail,
                metadata: summary.metadata
            ),
            at: 0
        )
    }

    private func compactMetadata(_ values: [String?]) -> [String] {
        values.compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
    }
}

struct HermesResponseEntry: Identifiable {
    let id = UUID()
    let title: String
    let status: String
    let summary: String
    let metadata: [String]
}

struct HermesAPISettings {
    var baseURL = "http://127.0.0.1:8642/v1"
    var apiKey = ""

    static func responseURL(from baseURL: String) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasSuffix("/responses") {
            return URL(string: trimmed)
        }

        if trimmed.hasSuffix("/") {
            return URL(string: trimmed + "responses")
        }

        return URL(string: trimmed + "/responses")
    }
}

struct HermesRequestDraft {
    var model = "hermes-agent"
    var instructions = "You are a helpful coding assistant."
    var userPrompt = "Summarize the current project layout and recommend the next integration step."
    var stream = true
}

private struct HermesResponsesRequestBody: Encodable {
    let model: String
    let input: String
    let instructions: String
    let stream: Bool
    let store: Bool
}

private struct HermesResponseEnvelope: Decodable {
    let id: String?
    let status: String?
    let output: [HermesResponseOutputItem]?

    var assistantText: String {
        guard let output else { return "" }
        return output.compactMap(\.assistantText).joined(separator: "\n\n")
    }
}

private struct HermesResponseOutputItem: Decodable {
    let type: String
    let content: [HermesResponseContent]?
    let output: [HermesResponseContent]?

    var assistantText: String? {
        let text = (content ?? output ?? []).compactMap(\.text).joined()
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
    let status: String
    let detail: String
    let metadata: [String]
    let responseID: String?
    let outputDelta: String?
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
                status: status.capitalized,
                detail: responseID.map { "Started response \($0)." } ?? "Response created.",
                metadata: compactMetadata([
                    responseID.map { "Response ID: \($0)" }
                ]),
                responseID: responseID,
                outputDelta: nil
            )

        case "response.output_text.delta":
            let delta = payload.string(at: ["delta"]) ?? ""
            return HermesEventSummary(
                title: title,
                status: "Streaming",
                detail: delta.isEmpty ? "Received output delta." : delta,
                metadata: compactMetadata([
                    payload.string(at: ["item_id"]).map { "Item ID: \($0)" },
                    payload.string(at: ["output_index"]).map { "Output Index: \($0)" }
                ]),
                responseID: payload.string(at: ["response_id"]),
                outputDelta: delta
            )

        case "response.output_item.added", "response.output_item.done":
            let itemType = payload.string(at: ["item", "type"]) ?? payload.string(at: ["type"]) ?? "item"
            let name = payload.string(at: ["item", "name"]) ?? payload.string(at: ["name"])
            let detail = name.map { "\(itemType) \($0)" } ?? "Received \(itemType)."
            return HermesEventSummary(
                title: title,
                status: title.hasSuffix("done") ? "Done" : "Update",
                detail: detail,
                metadata: compactMetadata([
                    payload.string(at: ["item", "call_id"]).map { "Call ID: \($0)" },
                    payload.string(at: ["output_index"]).map { "Output Index: \($0)" }
                ]),
                responseID: payload.string(at: ["response_id"]),
                outputDelta: nil
            )

        case "response.completed":
            let responseID = payload.string(at: ["response", "id"]) ?? payload.string(at: ["id"])
            let status = payload.string(at: ["response", "status"]) ?? payload.string(at: ["status"]) ?? "Completed"
            return HermesEventSummary(
                title: title,
                status: status.capitalized,
                detail: "Hermes finished the streamed response.",
                metadata: compactMetadata([
                    responseID.map { "Response ID: \($0)" }
                ]),
                responseID: responseID,
                outputDelta: nil
            )

        default:
            return HermesEventSummary(
                title: title,
                status: "Event",
                detail: payload.primaryDescription ?? event.data,
                metadata: [],
                responseID: payload.string(at: ["response_id"]),
                outputDelta: nil
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

private struct HermesLooseJSON {
    private let object: Any?

    init(json: String) {
        guard let data = json.data(using: .utf8) else {
            object = nil
            return
        }

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

    var primaryDescription: String? {
        if let message = string(at: ["message"]) {
            return message
        }

        if let error = string(at: ["error", "message"]) {
            return error
        }

        return nil
    }

    private func value(at path: [String]) -> Any? {
        var current = object

        for key in path {
            guard let dictionary = current as? [String: Any] else {
                return nil
            }
            current = dictionary[key]
        }

        return current
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
