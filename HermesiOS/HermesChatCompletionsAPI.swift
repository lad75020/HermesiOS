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
    var isStreaming = false
    var activeProfile = ""
    var connectionStatus = "Idle"
    var activeChatSessionID = ""
    var lastKnownChatSessionID = ""
    var lastKnownChatSessionTitle = ""
    var lastErrorMessage = ""
    var lastErrorWasTimeoutOrNetworkLoss = false
    var eventCount = 0
    var rawStreamedJSON = ""
    var debugEventText = ""
    var sessionTitle = ""

    var displaySessionTitle: String {
        let trimmedTitle = sessionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }
        return activeChatSessionID.isEmpty ? "New chat" : "Continuing chat"
    }

    private var requestTask: Task<Void, Never>?
    private var activeAssistantEntryID: UUID?

    init() {
        lastKnownChatSessionID = HermesSettingsPersistence.loadLastChatSessionID()
        lastKnownChatSessionTitle = HermesSettingsPersistence.loadLastChatSessionTitle()
    }

    func submit(apiSettings: HermesAPISettings, draft: HermesChatDraft, attachment: HermesPromptAttachment? = nil, messageHistory: HermesPromptHistoryStore? = nil) {
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
            await runRequest(apiSettings: apiSettings, draft: lockedDraft, attachment: attachment, messageHistory: messageHistory)
        }
    }

    func cancel() {
        requestTask?.cancel()
        requestTask = nil
        isSending = false
        isStreaming = false
        connectionStatus = "Cancelled"
    }

    func resetConversation() {
        requestTask?.cancel()
        requestTask = nil
        entries = []
        streamedText = ""
        activeAssistantEntryID = nil
        isSending = false
        isStreaming = false
        activeProfile = ""
        activeChatSessionID = ""
        connectionStatus = "Idle"
        lastErrorMessage = ""
        lastErrorWasTimeoutOrNetworkLoss = false
        eventCount = 0
        rawStreamedJSON = ""
        debugEventText = ""
        sessionTitle = ""
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
        isStreaming = false
        activeChatSessionID = sessionID
        lastErrorMessage = ""
        lastErrorWasTimeoutOrNetworkLoss = false
        eventCount = 0
        rawStreamedJSON = ""
        debugEventText = ""
        sessionTitle = Self.userFriendlySessionTitle(from: lastKnownChatSessionTitle, fallback: "Last chat")
        connectionStatus = "Resumed last chat"
    }

    func resumeConversation(from result: HermesDashboardConversationResult) {
        let sessionID = Self.hermesSessionID(from: result)
        requestTask?.cancel()
        requestTask = nil
        streamedText = ""
        activeAssistantEntryID = nil
        isSending = false
        isStreaming = false
        activeProfile = ""
        activeChatSessionID = sessionID
        if !sessionID.isEmpty {
            persistLastChatSessionID(sessionID)
        }
        lastErrorMessage = ""
        lastErrorWasTimeoutOrNetworkLoss = false
        eventCount = 0
        rawStreamedJSON = ""
        debugEventText = ""

        let restoredEntries = result.messages
            .filter { message in
                let role = message.role.lowercased()
                return (role == "user" || role == "assistant") && !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .map { message in
                HermesChatMessage(role: message.role.lowercased(), content: message.content)
            }

        let displayTitle = result.sessionFriendlyName
        sessionTitle = Self.userFriendlySessionTitle(from: displayTitle, fallback: sessionID.isEmpty ? "Loaded history" : sessionID)
        persistLastChatSessionTitle(sessionTitle)

        entries = restoredEntries.isEmpty
            ? [HermesChatMessage(role: "assistant", content: "Loaded session \(displayTitle). Send a new prompt to continue in Chat Completions.")]
            : restoredEntries
        connectionStatus = sessionID.isEmpty ? "Loaded history" : "Resumed chat"
    }

    private static func hermesSessionID(from result: HermesDashboardConversationResult) -> String {
        [result.sessionID, result.session.id]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""
    }

    private static func makeChatSessionID() -> String {
        "hermes-ios-chat-\(UUID().uuidString.lowercased())"
    }

    private static func shortSessionID(_ sessionID: String) -> String {
        guard sessionID.count > 24 else { return sessionID }
        return String(sessionID.prefix(24)) + "…"
    }

    private static func userFriendlySessionTitle(from title: String, fallback: String) -> String {
        let normalized = title
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !normalized.isEmpty {
            return normalized
        }

        let normalizedFallback = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedFallback.isEmpty ? "New chat" : normalizedFallback
    }

    private func persistLastChatSessionID(_ sessionID: String) {
        let trimmed = sessionID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        activeChatSessionID = trimmed
        lastKnownChatSessionID = trimmed
        HermesSettingsPersistence.saveLastChatSessionID(trimmed)
    }

    private func persistLastChatSessionTitle(_ title: String) {
        let normalized = Self.userFriendlySessionTitle(from: title, fallback: "")
        guard !normalized.isEmpty else { return }
        lastKnownChatSessionTitle = normalized
        HermesSettingsPersistence.saveLastChatSessionTitle(normalized)
    }

    private func runRequest(apiSettings: HermesAPISettings, draft: HermesChatDraft, attachment: HermesPromptAttachment?, messageHistory: HermesPromptHistoryStore?) async {
        let history = entries
        let prompt = draft.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayPrompt = displayPrompt(prompt, attachment: attachment)
        if sessionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sessionTitle = Self.userFriendlySessionTitle(from: prompt, fallback: attachment?.filename ?? "New chat")
        }
        persistLastChatSessionTitle(sessionTitle)
        resetForRequest()
        appendExchange(prompt: displayPrompt)
        isSending = true
        isStreaming = draft.stream
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
                messageHistory?.recordResponse(currentAssistantResponseText(), source: .chatWithHermes)
            }
        } catch is CancellationError {
            connectionStatus = "Cancelled"
            updateActiveAssistantEntry(with: streamedText.isEmpty ? "Cancelled." : streamedText)
        } catch {
            lastErrorMessage = error.localizedDescription
            lastErrorWasTimeoutOrNetworkLoss = HermesRequestFailureClassifier.isTimeoutOrNetworkLoss(error)
            connectionStatus = "Failed"
            updateActiveAssistantEntry(with: streamedText.isEmpty ? "Request failed: \(error.localizedDescription)" : streamedText)
        }

        isSending = false
        isStreaming = false
    }

    private func resetForRequest() {
        streamedText = ""
        lastErrorMessage = ""
        lastErrorWasTimeoutOrNetworkLoss = false
        eventCount = 0
        rawStreamedJSON = ""
        debugEventText = ""
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
        updatedEntries[index].content = HermesStreamTextFormatter.lineBreakAfterStatementDots(content)
        entries = updatedEntries
    }

    private func currentAssistantResponseText() -> String {
        if let activeAssistantEntryID,
           let entry = entries.first(where: { $0.id == activeAssistantEntryID }) {
            return entry.content
        }
        return entries.last(where: { $0.role.lowercased() == "assistant" })?.content ?? ""
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
                await handle(event: event)
            }
        }

        if let event = parser.finish() {
            await handle(event: event)
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

    private func handle(event: HermesChatSSEEvent) async {
        if event.data == "[DONE]" {
            connectionStatus = Self.shortStatus("Completed")
            await Task.yield()
            appendRawStreamedJSON(event)
            appendDebugEventText(event)
            return
        }

        let payloadStrings = Self.jsonPayloadStrings(from: event.data)
        let payloads = payloadStrings.map { HermesLooseJSON(json: $0) }
        var didExtractText = false
        var latestStatus = statusMessage(for: event, payload: nil, didExtractText: false)
        var extractedDeltas: [String] = []

        for payload in payloads {
            eventCount += 1
            if let sessionID = payload.string(at: ["session_id"]) ?? payload.string(at: ["session", "id"]) {
                persistLastChatSessionID(sessionID)
            }
            let delta = extractChatText(from: payload, eventName: event.name)
            let extractedTextFromPayload = !delta.isEmpty
            let eventStatus = statusMessage(for: event, payload: payload, didExtractText: extractedTextFromPayload)
            if !eventStatus.isEmpty {
                latestStatus = eventStatus
            }
            if extractedTextFromPayload {
                didExtractText = true
                extractedDeltas.append(delta)
            }
        }

        // Update the visible status pill before doing heavier debug-log work.
        // Tool/reasoning events intentionally stay out of the chat bubble.
        let fallbackStatus = didExtractText ? "Streaming output" : "Processing stream"
        connectionStatus = Self.shortStatus(latestStatus.isEmpty ? fallbackStatus : latestStatus)
        await Task.yield()

        appendRawStreamedJSON(event)
        appendDebugEventText(event)

        for delta in extractedDeltas {
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
    }

    private func statusMessage(for event: HermesChatSSEEvent, payload: HermesLooseJSON?, didExtractText: Bool) -> String {
        guard event.data != "[DONE]" else { return "Completed" }
        let eventName = event.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !eventName.isEmpty else {
            return didExtractText ? "Streaming output" : "Processing chat chunks"
        }

        switch eventName.lowercased() {
        case "hermes.tool.progress":
            let tool = payload?.string(at: ["tool"]) ?? "tool"
            let status = payload?.string(at: ["status"]) ?? "progress"
            return status == "running" ? "Running \(tool)" : "\(status.capitalized) \(tool)"
        case "hermes.tool.output":
            let tool = payload?.string(at: ["tool"]) ?? "tool"
            return "Output from \(tool)"
        case "hermes.reasoning.summary":
            return "Reasoning"
        case "response.created", "response.in_progress":
            return "Response in progress"
        case "response.output_item.added":
            return outputItemStatus(prefix: "Started", payload: payload)
        case "response.output_item.done":
            return outputItemStatus(prefix: "Finished", payload: payload)
        case "response.content_part.added", "response.content_part.done":
            return "Receiving content"
        case "response.output_text.delta":
            return didExtractText ? "Streaming output" : "Receiving text"
        case "response.output_text.done":
            return "Text complete"
        case "response.reasoning_summary_text.delta", "response.reasoning_summary_text.done", "response.reasoning.delta", "response.reasoning.done":
            return "Reasoning"
        case "response.function_call_arguments.delta", "response.function_call_arguments.done":
            let name = payload?.string(at: ["name"])
                ?? payload?.string(at: ["item", "name"])
                ?? payload?.string(at: ["output_item", "name"])
            return name.map { "Calling \($0)" } ?? "Preparing tool call"
        case "response.completed":
            return "Completed"
        case "response.failed", "response.incomplete":
            return eventName == "response.failed" ? "Failed" : "Incomplete"
        default:
            if didExtractText {
                return "Streaming output"
            }
            if eventName.lowercased().hasPrefix("response.") {
                return eventName
                    .replacingOccurrences(of: "response.", with: "")
                    .replacingOccurrences(of: "_", with: " ")
            }
            return eventName.replacingOccurrences(of: "_", with: " ")
        }
    }

    private func outputItemStatus(prefix: String, payload: HermesLooseJSON?) -> String {
        let type = payload?.string(at: ["item", "type"])
            ?? payload?.string(at: ["output_item", "type"])
            ?? payload?.string(at: ["type"])
        let name = payload?.string(at: ["item", "name"])
            ?? payload?.string(at: ["output_item", "name"])
            ?? payload?.string(at: ["name"])

        if let name, !name.isEmpty {
            return "\(prefix) \(name)"
        }
        if let type, !type.isEmpty {
            return "\(prefix) \(type.replacingOccurrences(of: "_", with: " "))"
        }
        return "\(prefix) output"
    }

    private static func shortStatus(_ status: String, maxCharacters: Int = 40) -> String {
        let normalized = status
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > maxCharacters else { return normalized }
        guard maxCharacters > 1 else { return String(normalized.prefix(maxCharacters)) }
        return String(normalized.prefix(maxCharacters - 1)) + "…"
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

    private func appendDebugEventText(_ event: HermesChatSSEEvent) {
        guard let eventName = event.name else { return }

        let payload = HermesLooseJSON(json: event.data)
        let block: String?
        switch eventName {
        case "hermes.tool.progress", "Hermes.tool.progress":
            let tool = payload.string(at: ["tool"]) ?? "tool"
            let status = payload.string(at: ["status"]) ?? "progress"
            let label = payload.string(at: ["label"])
            let toolCallID = payload.string(at: ["toolCallId"])
            block = Self.debugBlock(
                title: "Tool \(status): \(tool)",
                lines: [label, toolCallID.map { "id: \($0)" }]
            )
        case "Hermes.tool.output", "hermes.tool.output":
            let tool = payload.string(at: ["tool"]) ?? "tool"
            let output = payload.string(at: ["structured", "output"])
                ?? payload.string(at: ["output"])
                ?? Self.prettyPrintedJSON(from: event.data)
            block = Self.debugBlock(
                title: "Tool output: \(tool)",
                lines: [output]
            )
        case "Hermes.reasoning.summary", "hermes.reasoning.summary":
            let text = payload.string(at: ["delta"])
                ?? payload.string(at: ["summary"])
                ?? Self.prettyPrintedJSON(from: event.data)
            block = Self.debugBlock(
                title: "Reasoning",
                lines: [text]
            )
        default:
            block = nil
        }

        guard let block, !block.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        debugEventText = debugEventText.isEmpty ? block : debugEventText + "\n\n" + block
    }

    private static func debugBlock(title: String, lines: [String?]) -> String {
        let body = lines
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        return body.isEmpty ? "[\(title)]" : "[\(title)]\n\(body)"
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
    var systemPrompt = ""
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
        let decodedSystemPrompt = try container.decodeIfPresent(String.self, forKey: .systemPrompt) ?? systemPrompt
        systemPrompt = decodedSystemPrompt == "You are a helpful coding assistant." ? "" : decodedSystemPrompt
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

    enum CodingKeys: String, CodingKey {
        case model
        case messages
        case stream
        case user
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(messages, forKey: .messages)
        try container.encode(stream, forKey: .stream)
        try container.encodeIfPresent(user, forKey: .user)
    }
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
    let type: String?
    let text: String?
    let outputText: String?
    let imageURL: HermesChatImageURLPayload?
    let url: String?
    let b64JSON: String?
    let imageBase64: String?
    let mimeType: String?
    let originalMimeType: String?

    var textValue: String? {
        if let text { return HermesImageJSONFormatter.renderableImageMarkdown(from: text) ?? text }
        if let outputText { return HermesImageJSONFormatter.renderableImageMarkdown(from: outputText) ?? outputText }
        if let imageMarkdown { return imageMarkdown }
        return nil
    }

    var imageMarkdown: String? {
        let base64 = b64JSON ?? imageBase64
        let mimeCandidate = mimeType ?? originalMimeType
        let resolvedMimeType = mimeCandidate?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? mimeCandidate! : "image/png"
        let source = imageURL?.url ?? url ?? base64.map { "data:\(resolvedMimeType);base64,\($0)" }
        guard let source, !source.isEmpty else { return nil }
        return "\n\n![Hermes image](\(source))"
    }

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case outputText = "output_text"
        case imageURL = "image_url"
        case url
        case b64JSON = "b64_json"
        case imageBase64 = "image_base64"
        case mimeType = "mime_type"
        case originalMimeType = "original_mime_type"
    }
}

private struct HermesChatImageURLPayload: Decodable {
    let url: String?
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
