//
//  HermesTUIGatewayView.swift
//  HermesiOS
//

import Foundation
import Observation
import SwiftUI
import UniformTypeIdentifiers

enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null; return }
        if let value = try? container.decode(Bool.self) { self = .bool(value); return }
        if let value = try? container.decode(Double.self) { self = .number(value); return }
        if let value = try? container.decode(String.self) { self = .string(value); return }
        if let value = try? container.decode([String: JSONValue].self) { self = .object(value); return }
        if let value = try? container.decode([JSONValue].self) { self = .array(value); return }
        self = .null
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var compactDescription: String {
        switch self {
        case .string(let value): value
        case .number(let value): String(value)
        case .bool(let value): value ? "true" : "false"
        case .null: ""
        case .array(let value): value.map(\.compactDescription).joined(separator: ", ")
        case .object(let value):
            value.keys.sorted().map { key in "\(key): \(value[key]?.compactDescription ?? "")" }.joined(separator: ", ")
        }
    }

    var stringValue: String? {
        switch self {
        case .string(let value): value
        case .number(let value): String(value)
        case .bool(let value): value ? "true" : "false"
        default: nil
        }
    }

    var boolValue: Bool? {
        switch self {
        case .bool(let value): value
        case .string(let value): ["1", "true", "yes", "on"].contains(value.lowercased())
        default: nil
        }
    }

    var objectValue: [String: JSONValue] {
        if case .object(let value) = self { return value }
        return [:]
    }

    var arrayValue: [JSONValue] {
        if case .array(let value) = self { return value }
        return []
    }
}

private enum HermesTUIGatewayError: LocalizedError {
    case invalidDashboardURL
    case invalidWebSocketURL
    case notConnected
    case requestFailed(String)
    case missingSession
    case blockedPlaintext(String)

    var errorDescription: String? {
        switch self {
        case .invalidDashboardURL:
            "The Hermes dashboard URL is invalid."
        case .invalidWebSocketURL:
            "The TUI Gateway WebSocket URL is invalid."
        case .notConnected:
            "The TUI Gateway WebSocket is not connected."
        case .requestFailed(let message):
            message.isEmpty ? "TUI Gateway request failed." : message
        case .missingSession:
            "Create or activate a TUI Gateway session first."
        case .blockedPlaintext(let message):
            message
        }
    }
}

private struct HermesTUIGatewayRPCRequest: Encodable {
    let jsonrpc = "2.0"
    let id: String
    let method: String
    let params: [String: JSONValue]
}

private struct HermesTUIGatewayRPCEnvelope: Decodable {
    let id: String?
    let method: String?
    let params: HermesTUIGatewayEvent?
    let result: JSONValue?
    let error: HermesTUIGatewayRPCError?
}

private struct HermesTUIGatewayRPCError: Decodable {
    let code: Int?
    let message: String?
}

private struct HermesTUIGatewayEvent: Decodable {
    let type: String
    let sessionID: String?
    let payload: JSONValue?

    enum CodingKeys: String, CodingKey {
        case type
        case sessionID = "session_id"
        case payload
    }
}

private struct HermesTUIGatewayWSTicketResponse: Decodable {
    let ticket: String
}

struct HermesTUIGatewayMessage: Identifiable, Equatable {
    enum Role: String, Equatable {
        case user
        case assistant
        case event
        case request
    }

    enum RequestKind: String, Equatable {
        case approval
        case clarify
        case sudo
        case secret
    }

    let id = UUID()
    var role: Role
    var title: String
    var content: String
    var eventType: String?
    var requestKind: RequestKind?
    var requestID: String?
    var isResolved = false
    var createdAt = Date()
}

struct HermesTUILiveSession: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let isCurrent: Bool
}

enum HermesTUIWorkspaceAttention {
    case streaming
    case completed
    case failed
}

@MainActor
@Observable
final class HermesTUIWorkspace: Identifiable {
    let id = UUID()
    let number: Int
    let store = HermesTUIGatewayStore()
    var promptText = ""
    var requestResponses: [UUID: String] = [:]
    var selectedAttachment: HermesPromptAttachment?
    private var acknowledgedCompletionToken = ""
    private var acknowledgedFailureToken = ""

    init(number: Int) {
        self.number = number
    }

    var attention: HermesTUIWorkspaceAttention? {
        if store.isStreaming || store.isConnecting || store.isResumingSession { return .streaming }
        if let token = failureToken, token != acknowledgedFailureToken { return .failed }
        if let token = completionToken, token != acknowledgedCompletionToken { return .completed }
        return nil
    }

    func acknowledgeCurrentStatus() {
        if let token = completionToken { acknowledgedCompletionToken = token }
        if let token = failureToken { acknowledgedFailureToken = token }
    }

    private var completionToken: String? {
        guard store.connectionStatus == "Completed", !store.messages.isEmpty else { return nil }
        let sessionPart = store.sessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "tui" : store.sessionID
        return "completed-\(sessionPart)-\(store.messages.count)-\(store.eventCount)"
    }

    private var failureToken: String? {
        let error = store.lastErrorMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if !error.isEmpty { return error }
        guard ["Error", "Connection failed", "Prompt failed", "Resume failed"].contains(store.connectionStatus) else { return nil }
        return "failed-\(store.messages.count)-\(store.eventCount)-\(store.connectionStatus)"
    }
}

@MainActor
@Observable
final class HermesTUIGatewayStore {
    var messages: [HermesTUIGatewayMessage] = []
    var activeSessions: [HermesTUILiveSession] = []
    var sessionID = ""
    var storedSessionID = ""
    var sessionTitle = "New TUI session"
    var connectionStatus = "Idle"
    var eventCount = 0
    var lastErrorMessage = ""
    var isConnecting = false
    var isConnected = false
    var isStreaming = false
    var isResumingSession = false
    var isRefreshingSessions = false

    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var requestCounter = 0
    private var pendingResponses: [String: CheckedContinuation<JSONValue, Error>] = [:]
    private var cachedTokenByBaseURL: [String: String] = [:]
    private var activeAssistantMessageID: UUID?
    private var activeStreamMessageID: UUID?
    private var activeStreamContentType: String?
    private var currentTurnReceivedMessageDelta = false
    private var currentTurnMessageDeltaSegmentCount = 0

    var canSendPrompt: Bool {
        isConnected && !isStreaming && !sessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func connect(dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        guard !isConnecting else { return }
        Task { await connectGateway(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings, createSessionIfMissing: true) }
    }

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
        isConnecting = false
        isStreaming = false
        isResumingSession = false
        connectionStatus = "Disconnected"
        failPending(HermesTUIGatewayError.notConnected)
    }

    func createSession() {
        Task { await createGatewaySession() }
    }

    func submitPrompt(_ prompt: String, attachment: HermesPromptAttachment? = nil) {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || attachment != nil else { return }
        Task { await submit(text, attachment: attachment) }
    }

    func interruptSession() {
        guard !sessionID.isEmpty else { return }
        Task {
            do {
                _ = try await request("session.interrupt", params: ["session_id": .string(sessionID)], timeoutSeconds: 20)
                isStreaming = false
                connectionStatus = "Interrupted"
                appendEvent(title: "Interrupted", content: "The active TUI Gateway turn was interrupted.", eventType: "session.interrupt")
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    func closeSession() {
        guard !sessionID.isEmpty else { return }
        Task {
            do {
                let closedID = sessionID
                _ = try await request("session.close", params: ["session_id": .string(sessionID)], timeoutSeconds: 20)
                appendEvent(title: "Session closed", content: shortSessionID(closedID), eventType: "session.close")
                sessionID = ""
                storedSessionID = ""
                sessionTitle = "New TUI session"
                isStreaming = false
                await refreshActiveSessions()
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    func refreshSessions() {
        Task { await refreshActiveSessions() }
    }

    func activateSession(_ liveSession: HermesTUILiveSession) {
        Task { await activate(sessionID: liveSession.id) }
    }

    func resumeStoredSession(_ storedSessionID: String, title: String = "", dashboardBaseURL: String, apiSettings: HermesAPISettings) {
        let target = storedSessionID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return }
        Task { await resumeStoredSession(target, title: title, dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings) }
    }

    func respondToApproval(messageID: UUID, choice: String, applyToAll: Bool = false) {
        guard !sessionID.isEmpty else { return }
        Task {
            do {
                _ = try await request(
                    "approval.respond",
                    params: ["session_id": .string(sessionID), "choice": .string(choice), "all": .bool(applyToAll)],
                    timeoutSeconds: 30
                )
                markRequestResolved(messageID, label: choice == "deny" ? "Denied" : "Approved")
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    func respondToPromptRequest(messageID: UUID, kind: HermesTUIGatewayMessage.RequestKind, requestID: String, value: String) {
        Task {
            do {
                let method: String
                let key: String
                switch kind {
                case .clarify:
                    method = "clarify.respond"
                    key = "answer"
                case .sudo:
                    method = "sudo.respond"
                    key = "password"
                case .secret:
                    method = "secret.respond"
                    key = "value"
                case .approval:
                    return
                }
                _ = try await request(method, params: ["request_id": .string(requestID), key: .string(value)], timeoutSeconds: 30)
                markRequestResolved(messageID, label: value.isEmpty ? "Skipped" : "Responded")
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    private func connectGateway(dashboardBaseURL: String, apiSettings: HermesAPISettings, createSessionIfMissing: Bool) async {
        guard !isConnecting else { return }
        isConnecting = true
        lastErrorMessage = ""
        connectionStatus = "Connecting"
        do {
            let baseURL = try resolvedDashboardBaseURL(from: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let wsURL = try await webSocketURL(baseURL: baseURL, apiSettings: apiSettings)
            let session = HermesNetworkSessionFactory.session(for: apiSettings)
            let task = session.webSocketTask(with: wsURL)
            webSocketTask = task
            task.resume()
            isConnected = true
            isConnecting = false
            connectionStatus = "Connected"
            receiveTask?.cancel()
            receiveTask = Task { await receiveLoop(task) }
            if createSessionIfMissing && sessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                await createGatewaySession()
            }
            await refreshActiveSessions()
        } catch {
            isConnecting = false
            isConnected = false
            lastErrorMessage = error.localizedDescription
            connectionStatus = "Connection failed"
        }
    }

    private func resumeStoredSession(_ target: String, title: String, dashboardBaseURL: String, apiSettings: HermesAPISettings) async {
        guard !isStreaming else {
            lastErrorMessage = "Wait for the active TUI Gateway turn to finish before resuming another session."
            return
        }
        if !isConnected {
            await connectGateway(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings, createSessionIfMissing: false)
        }
        guard isConnected else { return }

        isResumingSession = true
        lastErrorMessage = ""
        connectionStatus = "Resuming session"
        defer { isResumingSession = false }

        do {
            let result = try await request("session.resume", params: ["session_id": .string(target)], timeoutSeconds: 180)
            let object = result.objectValue
            sessionID = object["session_id"]?.stringValue ?? sessionID
            storedSessionID = object["resumed"]?.stringValue ?? object["stored_session_id"]?.stringValue ?? object["session_key"]?.stringValue ?? target
            let displayTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            sessionTitle = displayTitle.isEmpty ? "TUI session \(shortSessionID(storedSessionID.isEmpty ? sessionID : storedSessionID))" : displayTitle
            resetStreamGrouping(resetTurn: false)
            isStreaming = object["running"]?.boolValue ?? false
            restoreMessages(from: object["messages"]?.arrayValue ?? [])
            connectionStatus = isStreaming ? "Streaming" : "Session resumed"
            await refreshActiveSessions()
        } catch {
            lastErrorMessage = error.localizedDescription
            connectionStatus = "Resume failed"
        }
    }

    private func createGatewaySession() async {
        do {
            let result = try await request("session.create", params: [:], timeoutSeconds: 120)
            let object = result.objectValue
            sessionID = object["session_id"]?.stringValue ?? ""
            storedSessionID = object["stored_session_id"]?.stringValue ?? ""
            sessionTitle = "TUI session \(shortSessionID(sessionID))"
            messages.removeAll()
            resetStreamGrouping()
            isStreaming = false
            connectionStatus = sessionID.isEmpty ? "Session create failed" : "Session ready"
            appendEvent(title: "Session ready", content: "Created live TUI session \(shortSessionID(sessionID)).", eventType: "session.create")
            await refreshActiveSessions()
        } catch {
            lastErrorMessage = error.localizedDescription
            connectionStatus = "Session create failed"
        }
    }

    private func submit(_ text: String, attachment: HermesPromptAttachment? = nil) async {
        guard canSendPrompt else {
            lastErrorMessage = HermesTUIGatewayError.missingSession.localizedDescription
            return
        }

        let prepared: (payloadText: String, displayText: String, activity: String?)
        do {
            prepared = try promptPayload(text: text, attachment: attachment)
        } catch {
            lastErrorMessage = error.localizedDescription
            connectionStatus = "Attachment failed"
            return
        }

        let finalText = prepared.payloadText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !finalText.isEmpty else { return }
        if let activity = prepared.activity, !activity.isEmpty {
            appendEvent(title: "Attachment", content: activity, eventType: "input.attachment")
        }
        resetStreamGrouping()
        messages.append(HermesTUIGatewayMessage(role: .user, title: "You", content: prepared.displayText))
        isStreaming = true
        connectionStatus = "Sending prompt"
        do {
            _ = try await request("prompt.submit", params: ["session_id": .string(sessionID), "text": .string(finalText)], timeoutSeconds: 60)
            connectionStatus = "Streaming"
        } catch {
            isStreaming = false
            lastErrorMessage = error.localizedDescription
            connectionStatus = "Prompt failed"
            updateAssistantMessage(text: "Request failed: \(error.localizedDescription)")
        }
    }

    private func promptPayload(text: String, attachment: HermesPromptAttachment?) throws -> (payloadText: String, displayText: String, activity: String?) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let attachment else { return (trimmedText, trimmedText, nil) }

        let block: String
        if attachment.isUTF8Text {
            block = attachment.textAttachmentBlock
        } else if attachment.isImage {
            block = "Attached image: \(attachment.filename) (\(attachment.mimeType), \(attachment.formattedByteCount))\n\(attachment.base64DataURL)"
        } else {
            block = "Attached file: \(attachment.filename) (\(attachment.mimeType), \(attachment.formattedByteCount))\nThe file is provided as a base64 data URL. Decode it if you need to inspect or process the document bytes:\n\(attachment.base64DataURL)"
        }
        let payload = [trimmedText, block.trimmingCharacters(in: .whitespacesAndNewlines)]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        let display = [trimmedText, "Attached: \(attachment.filename) (\(attachment.formattedByteCount))"]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        return (payload, display, "Attached file: \(attachment.filename) (\(attachment.formattedByteCount))")
    }

    private func activate(sessionID target: String) async {
        do {
            let result = try await request("session.activate", params: ["session_id": .string(target)], timeoutSeconds: 60)
            let object = result.objectValue
            sessionID = object["session_id"]?.stringValue ?? target
            storedSessionID = object["stored_session_id"]?.stringValue ?? object["session_key"]?.stringValue ?? storedSessionID
            sessionTitle = activeSessions.first(where: { $0.id == target })?.title ?? "TUI session \(shortSessionID(target))"
            resetStreamGrouping(resetTurn: false)
            isStreaming = object["running"]?.boolValue ?? false
            connectionStatus = isStreaming ? "Streaming" : "Session active"
            restoreMessages(from: object["messages"]?.arrayValue ?? [])
            await refreshActiveSessions()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func refreshActiveSessions() async {
        guard isConnected else { return }
        isRefreshingSessions = true
        defer { isRefreshingSessions = false }
        do {
            let result = try await request("session.active_list", params: ["current_session_id": .string(sessionID)], timeoutSeconds: 30)
            activeSessions = (result.objectValue["sessions"]?.arrayValue ?? []).compactMap { value in
                let object = value.objectValue
                let id = object["session_id"]?.stringValue ?? object["id"]?.stringValue ?? ""
                guard !id.isEmpty else { return nil }
                let title = object["title"]?.stringValue ?? object["display_title"]?.stringValue ?? object["session_key"]?.stringValue ?? "TUI session \(shortSessionID(id))"
                let model = object["model"]?.stringValue ?? ""
                let running = object["running"]?.boolValue ?? false
                let subtitle = [model, running ? "running" : "idle"].filter { !$0.isEmpty }.joined(separator: " • ")
                return HermesTUILiveSession(id: id, title: title.isEmpty ? "TUI session \(shortSessionID(id))" : title, subtitle: subtitle, isCurrent: id == self.sessionID)
            }
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func receiveLoop(_ task: URLSessionWebSocketTask) async {
        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    await handleWebSocketText(text)
                case .data(let data):
                    await handleWebSocketText(String(decoding: data, as: UTF8.self))
                @unknown default:
                    break
                }
            } catch {
                if Task.isCancelled { return }
                isConnected = false
                isStreaming = false
                connectionStatus = "Disconnected"
                lastErrorMessage = error.localizedDescription
                failPending(error)
                return
            }
        }
    }

    private func handleWebSocketText(_ text: String) async {
        guard let data = text.data(using: .utf8), let envelope = try? JSONDecoder().decode(HermesTUIGatewayRPCEnvelope.self, from: data) else { return }
        if let id = envelope.id, let continuation = pendingResponses.removeValue(forKey: id) {
            if let error = envelope.error {
                continuation.resume(throwing: HermesTUIGatewayError.requestFailed(error.message ?? "JSON-RPC error \(error.code ?? -1)"))
            } else {
                continuation.resume(returning: envelope.result ?? .null)
            }
            return
        }
        guard envelope.method == "event", let event = envelope.params else { return }
        eventCount += 1
        handle(event)
    }

    private func handle(_ event: HermesTUIGatewayEvent) {
        let payload = event.payload?.objectValue ?? [:]
        if let eventSessionID = event.sessionID, !eventSessionID.isEmpty, sessionID.isEmpty {
            sessionID = eventSessionID
        }
        switch event.type {
        case "gateway.ready":
            connectionStatus = "Gateway ready"
        case "session.info":
            if let model = payload["model"]?.stringValue, !model.isEmpty {
                sessionTitle = "\(shortSessionID(event.sessionID ?? sessionID)) • \(model)"
            }
            connectionStatus = "Session info updated"
        case "message.start":
            isStreaming = true
            connectionStatus = "Hermes is responding"
            resetStreamGrouping()
        case "message.delta":
            let delta = payload["text"]?.stringValue ?? ""
            if !delta.isEmpty { appendAssistantDelta(delta) }
            connectionStatus = shortStatus("Receiving message")
        case "message.complete":
            let final = payload["text"]?.stringValue ?? ""
            let status = payload["status"]?.stringValue ?? "complete"
            if !final.isEmpty { completeAssistantMessage(text: final) }
            isStreaming = false
            resetStreamGrouping(resetTurn: true)
            connectionStatus = status == "complete" ? "Completed" : status.capitalized
        case "reasoning.delta", "thinking.delta":
            let text = payload["text"]?.stringValue ?? ""
            if !text.isEmpty {
                appendStreamContent(type: event.type, title: event.type == "thinking.delta" ? "Thinking" : "Reasoning", content: text, role: .event, eventType: event.type)
            }
            connectionStatus = shortStatus(event.type == "thinking.delta" ? "Thinking" : "Reasoning")
        case "tool.start":
            connectionStatus = shortStatus("Running \(payload["name"]?.stringValue ?? "tool")")
            appendEvent(title: "Tool started", content: toolSummary(payload: payload), eventType: event.type)
        case "tool.progress", "tool.generating":
            connectionStatus = shortStatus(payload["preview"]?.stringValue ?? payload["text"]?.stringValue ?? "Tool progress")
            appendEvent(title: "Tool progress", content: eventSummary(payload: payload), eventType: event.type)
        case "tool.complete":
            connectionStatus = shortStatus("Completed \(payload["name"]?.stringValue ?? "tool")")
            appendEvent(title: "Tool complete", content: toolSummary(payload: payload), eventType: event.type)
        case "approval.request":
            connectionStatus = "Approval requested"
            appendRequest(kind: .approval, title: "Approval required", payload: payload)
        case "clarify.request":
            connectionStatus = "Clarification requested"
            appendRequest(kind: .clarify, title: "Clarification requested", payload: payload)
        case "sudo.request":
            connectionStatus = "Sudo password requested"
            appendRequest(kind: .sudo, title: "Sudo password requested", payload: payload)
        case "secret.request":
            connectionStatus = "Secret requested"
            appendRequest(kind: .secret, title: "Secret requested", payload: payload)
        case "status.update":
            let text = payload["text"]?.stringValue ?? eventSummary(payload: payload)
            connectionStatus = shortStatus(text.isEmpty ? "Status update" : text)
            appendEvent(title: "Status", content: text, eventType: event.type)
        case "background.complete":
            appendEvent(title: "Background task complete", content: payload["text"]?.stringValue ?? eventSummary(payload: payload), eventType: event.type)
        case "error":
            isStreaming = false
            resetStreamGrouping(resetTurn: true)
            let message = payload["message"]?.stringValue ?? eventSummary(payload: payload)
            lastErrorMessage = message
            connectionStatus = "Error"
            appendEvent(title: "Gateway error", content: message, eventType: event.type)
        case let deltaType where deltaType.hasSuffix(".delta"):
            let text = payload["text"]?.stringValue ?? eventSummary(payload: payload)
            if !text.isEmpty {
                appendStreamContent(type: deltaType, title: streamTitle(for: deltaType), content: text, role: .event, eventType: deltaType)
            }
            connectionStatus = shortStatus(deltaType)
        default:
            connectionStatus = shortStatus(event.type)
            appendEvent(title: event.type, content: eventSummary(payload: payload), eventType: event.type)
        }
    }

    private func request(_ method: String, params: [String: JSONValue], timeoutSeconds: UInt64) async throws -> JSONValue {
        guard let task = webSocketTask, isConnected else { throw HermesTUIGatewayError.notConnected }
        requestCounter += 1
        let id = "ios-\(requestCounter)"
        let request = HermesTUIGatewayRPCRequest(id: id, method: method, params: params)
        let data = try JSONEncoder().encode(request)
        guard let text = String(data: data, encoding: .utf8) else { throw HermesTUIGatewayError.requestFailed("Could not encode JSON-RPC request.") }
        return try await withTaskCancellationHandler {
            try await withThrowingTaskGroup(of: JSONValue.self) { group in
                group.addTask { [weak self] in
                    guard let self else { throw HermesTUIGatewayError.notConnected }
                    return try await self.waitForResponse(id: id)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                    throw HermesTUIGatewayError.requestFailed("Timed out waiting for \(method).")
                }
                try await task.send(.string(text))
                guard let value = try await group.next() else { throw HermesTUIGatewayError.requestFailed("No response for \(method).") }
                group.cancelAll()
                return value
            }
        } onCancel: {
            Task { @MainActor in
                if let continuation = self.pendingResponses.removeValue(forKey: id) {
                    continuation.resume(throwing: CancellationError())
                }
            }
        }
    }

    private func waitForResponse(id: String) async throws -> JSONValue {
        try await withCheckedThrowingContinuation { continuation in
            pendingResponses[id] = continuation
        }
    }

    private func webSocketURL(baseURL: URL, apiSettings: HermesAPISettings) async throws -> URL {
        if !HermesEndpointSecurity.isPlaintextTransportAllowed(for: baseURL),
           let warning = HermesEndpointSecurity.plaintextTransportWarning(for: baseURL.absoluteString, endpointName: "TUI Gateway") {
            throw HermesTUIGatewayError.blockedPlaintext(warning)
        }
        let token = try await dashboardSessionToken(baseURL: baseURL, apiSettings: apiSettings)
        let ticket = try? await fetchWebSocketTicket(baseURL: baseURL, token: token, apiSettings: apiSettings)
        var url = baseURL
        url.appendPathComponent("api")
        url.appendPathComponent("ws")
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { throw HermesTUIGatewayError.invalidWebSocketURL }
        switch components.scheme?.lowercased() {
        case "http": components.scheme = "ws"
        case "https": components.scheme = "wss"
        default: throw HermesTUIGatewayError.invalidWebSocketURL
        }
        components.queryItems = [URLQueryItem(name: ticket?.isEmpty == false ? "ticket" : "token", value: ticket?.isEmpty == false ? ticket : token)]
        guard let finalURL = components.url else { throw HermesTUIGatewayError.invalidWebSocketURL }
        return finalURL
    }

    private func dashboardSessionToken(baseURL: URL, apiSettings: HermesAPISettings) async throws -> String {
        let cacheKey = baseURL.absoluteString
        if let cached = cachedTokenByBaseURL[cacheKey], !cached.isEmpty { return cached }
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (data, response) = try await session.data(from: baseURL)
        try validate(response: response)
        let html = String(decoding: data, as: UTF8.self)
        let pattern = #"window\.__HERMES_SESSION_TOKEN__=\"([^\"]+)\""#
        let regex = try NSRegularExpression(pattern: pattern)
        let nsRange = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: nsRange), let tokenRange = Range(match.range(at: 1), in: html) else {
            throw HermesTUIGatewayError.requestFailed("The dashboard session token was not found in the dashboard HTML.")
        }
        let token = String(html[tokenRange])
        cachedTokenByBaseURL[cacheKey] = token
        return token
    }

    private func fetchWebSocketTicket(baseURL: URL, token: String, apiSettings: HermesAPISettings) async throws -> String {
        var url = baseURL
        url.appendPathComponent("api")
        url.appendPathComponent("auth")
        url.appendPathComponent("ws-ticket")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")
        let (data, response) = try await HermesNetworkSessionFactory.session(for: apiSettings).data(for: request)
        try validate(response: response)
        return try JSONDecoder().decode(HermesTUIGatewayWSTicketResponse.self, from: data).ticket
    }

    private func resolvedDashboardBaseURL(from dashboardBaseURL: String, apiBaseURL: String) throws -> URL {
        let explicit = dashboardBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if !explicit.isEmpty, let url = normalizedBaseURL(from: explicit) { return url }
        var fallback = apiBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if fallback.hasSuffix("/v1") { fallback.removeLast(3) }
        guard let url = normalizedBaseURL(from: fallback) else { throw HermesTUIGatewayError.invalidDashboardURL }
        return url
    }

    private func normalizedBaseURL(from value: String) -> URL? {
        var trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") { trimmed.removeLast() }
        return URL(string: trimmed)
    }

    private func validate(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else { throw HermesTUIGatewayError.requestFailed("HTTP \(http.statusCode)") }
    }

    private func appendAssistantDelta(_ delta: String) {
        currentTurnReceivedMessageDelta = true
        let result = appendStreamContent(type: "message.delta", title: "Hermes", content: delta, role: .assistant)
        if result.created { currentTurnMessageDeltaSegmentCount += 1 }
        activeAssistantMessageID = result.id
    }

    private func updateAssistantMessage(text: String) {
        let result = appendStreamContent(type: "message.delta", title: "Hermes", content: text, role: .assistant)
        activeAssistantMessageID = result.id
    }

    private func completeAssistantMessage(text: String) {
        if !currentTurnReceivedMessageDelta {
            updateAssistantMessage(text: text)
            return
        }
        guard currentTurnMessageDeltaSegmentCount <= 1,
              let activeAssistantMessageID,
              let index = messages.firstIndex(where: { $0.id == activeAssistantMessageID }) else { return }
        messages[index].content = text
    }

    @discardableResult
    private func appendStreamContent(type: String, title: String, content: String, role: HermesTUIGatewayMessage.Role, eventType: String? = nil) -> (id: UUID?, created: Bool) {
        guard !content.isEmpty else { return (nil, false) }
        if activeStreamContentType == type,
           let activeStreamMessageID,
           let index = messages.firstIndex(where: { $0.id == activeStreamMessageID }) {
            messages[index].content += content
            return (messages[index].id, false)
        }
        let message = HermesTUIGatewayMessage(role: role, title: title, content: content, eventType: eventType)
        activeStreamContentType = type
        activeStreamMessageID = message.id
        if role == .assistant { activeAssistantMessageID = message.id }
        messages.append(message)
        return (message.id, true)
    }

    private func resetStreamGrouping(resetTurn: Bool = true) {
        activeAssistantMessageID = nil
        activeStreamMessageID = nil
        activeStreamContentType = nil
        if resetTurn {
            currentTurnReceivedMessageDelta = false
            currentTurnMessageDeltaSegmentCount = 0
        }
    }

    private func appendEvent(title: String, content: String, eventType: String) {
        resetStreamGrouping(resetTurn: false)
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        messages.append(HermesTUIGatewayMessage(role: .event, title: title, content: trimmed.isEmpty ? eventType : trimmed, eventType: eventType))
    }

    private func appendRequest(kind: HermesTUIGatewayMessage.RequestKind, title: String, payload: [String: JSONValue]) {
        resetStreamGrouping(resetTurn: false)
        let requestID = payload["request_id"]?.stringValue
        let content = requestText(kind: kind, payload: payload)
        messages.append(HermesTUIGatewayMessage(role: .request, title: title, content: content, eventType: "\(kind.rawValue).request", requestKind: kind, requestID: requestID))
    }

    private func markRequestResolved(_ messageID: UUID, label: String) {
        guard let index = messages.firstIndex(where: { $0.id == messageID }) else { return }
        messages[index].isResolved = true
        messages[index].content += "\n\n\(label)."
        connectionStatus = label
    }

    private func restoreMessages(from values: [JSONValue]) {
        let restored = values.compactMap { value -> HermesTUIGatewayMessage? in
            let object = value.objectValue
            let role = (object["role"]?.stringValue ?? "assistant").lowercased()
            let text = object["content"]?.stringValue ?? object["text"]?.stringValue ?? ""
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return HermesTUIGatewayMessage(role: role == "user" ? .user : .assistant, title: role == "user" ? "You" : "Hermes", content: text)
        }
        messages = restored
        resetStreamGrouping()
    }

    private func failPending(_ error: Error) {
        for continuation in pendingResponses.values { continuation.resume(throwing: error) }
        pendingResponses.removeAll()
    }

    private func requestText(kind: HermesTUIGatewayMessage.RequestKind, payload: [String: JSONValue]) -> String {
        switch kind {
        case .approval:
            return [payload["command"]?.stringValue, payload["description"]?.stringValue, payload["reason"]?.stringValue, payload["risk"]?.stringValue]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        case .clarify:
            let question = payload["question"]?.stringValue ?? "Hermes needs clarification."
            let choices = payload["choices"]?.arrayValue.map(\.compactDescription).filter { !$0.isEmpty }.joined(separator: ", ") ?? ""
            return choices.isEmpty ? question : "\(question)\nChoices: \(choices)"
        case .sudo:
            return "Hermes needs a sudo password to continue."
        case .secret:
            return [payload["prompt"]?.stringValue, payload["env_var"]?.stringValue.map { "Variable: \($0)" }]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }
    }

    private func toolSummary(payload: [String: JSONValue]) -> String {
        let name = payload["name"]?.stringValue ?? "tool"
        if let summary = payload["summary"]?.stringValue, !summary.isEmpty { return "\(name): \(summary)" }
        if let context = payload["context"]?.stringValue, !context.isEmpty { return "\(name): \(context)" }
        return eventSummary(payload: payload)
    }

    private func eventSummary(payload: [String: JSONValue]) -> String {
        let preferredKeys = ["text", "message", "preview", "summary", "label", "status", "name", "kind"]
        let values = preferredKeys.compactMap { payload[$0]?.compactDescription.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        if !values.isEmpty { return values.joined(separator: " • ") }
        return JSONValue.object(payload).compactDescription
    }

    private func streamTitle(for eventType: String) -> String {
        eventType.replacingOccurrences(of: ".delta", with: "").split(separator: ".").map { $0.capitalized }.joined(separator: " ")
    }

    private func shortStatus(_ value: String) -> String {
        let normalized = value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        guard normalized.count > 40 else { return normalized }
        return String(normalized.prefix(37)) + "…"
    }

    private func shortSessionID(_ value: String) -> String {
        guard value.count > 12 else { return value }
        return String(value.prefix(12)) + "…"
    }
}

struct HermesTUIGatewayWorkspacesView: View {
    @Binding var apiSettings: HermesAPISettings
    let dashboardURLString: String
    let workspaces: [HermesTUIWorkspace]
    @Binding var selectedWorkspaceID: HermesTUIWorkspace.ID
    let onSelectWorkspace: (HermesTUIWorkspace) -> Void
    let onAddWorkspace: () -> Void
    let onDeleteWorkspace: (HermesTUIWorkspace) -> Void

    private var selectedWorkspace: HermesTUIWorkspace {
        workspaces.first(where: { $0.id == selectedWorkspaceID }) ?? workspaces[0]
    }

    var body: some View {
        HermesTUIGatewayView(
            apiSettings: $apiSettings,
            dashboardURLString: dashboardURLString,
            workspace: selectedWorkspace,
            workspaceControls: workspaceControls
        )
        .id(selectedWorkspace.id)
    }

    private var workspaceControls: AnyView {
        AnyView(
            HStack(spacing: 8) {
                Button(action: onAddWorkspace) {
                    Image(systemName: "plus")
                        .font(.headline)
                        .frame(width: 34, height: 34)
                }
                .hermesGlassButton()
                .accessibilityLabel("Open a new TUI Gateway workspace")

                ForEach(workspaces) { workspace in
                    Button {
                        onSelectWorkspace(workspace)
                    } label: {
                        HermesTUIWorkspaceButtonLabel(
                            number: workspace.number,
                            isSelected: workspace.id == selectedWorkspaceID,
                            attention: workspace.attention
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            onDeleteWorkspace(workspace)
                        } label: {
                            Label("Delete Workspace", systemImage: "trash")
                        }
                        .disabled(workspace.store.isStreaming || workspace.store.isConnecting || workspace.store.isResumingSession)
                    }
                    .accessibilityLabel("TUI Gateway workspace \(workspace.number)")
                }
            }
        )
    }
}

private struct HermesTUIWorkspaceButtonLabel: View {
    let number: Int
    let isSelected: Bool
    let attention: HermesTUIWorkspaceAttention?

    var body: some View {
        Text("\(number)")
            .font(.caption.weight(.bold))
            .monospacedDigit()
            .foregroundStyle((attention != nil || isSelected) ? .white : .primary)
            .frame(width: 34, height: 34)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Color.white.opacity(0.18), lineWidth: 1))
    }

    private var backgroundColor: Color {
        switch attention {
        case .streaming: .igGradOrange
        case .completed: .igOnlineGreen
        case .failed: .igDestructive
        case nil: isSelected ? .igActionBlue : .hermesSurfaceInput
        }
    }
}

private struct HermesTUIGatewayView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Binding var apiSettings: HermesAPISettings
    let dashboardURLString: String
    @Bindable var workspace: HermesTUIWorkspace
    let workspaceControls: AnyView

    @State private var isImportingAttachment = false
    @State private var dashboardSkills = HermesDashboardSkillsStore()

    private var store: HermesTUIGatewayStore { workspace.store }
    private var isPhoneLayout: Bool { horizontalSizeClass == .compact }

    var body: some View {
        VStack(spacing: 0) {
            header
            transcript
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            composer
        }
        .background(HermesLiquidGlassCanvas().ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: workspace.promptText) { _, _ in handlePromptSkillQueryChange() }
        .fileImporter(isPresented: $isImportingAttachment, allowedContentTypes: HermesPromptAttachment.supportedContentTypes, allowsMultipleSelection: false) { result in
            handleAttachmentImport(result)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                HermesTabHeader("TUI Gateway", systemImage: "terminal.fill")
                Spacer(minLength: 8)
                if !isPhoneLayout { workspaceControls }
                if store.isConnecting || store.isStreaming || store.isResumingSession || store.isRefreshingSessions {
                    ProgressView().controlSize(.small)
                }
            }
            if isPhoneLayout { workspaceControls }

            HermesStatusRow(items: [
                HermesStatusItem(title: "Session", value: store.sessionTitle, accent: .igActionBlue, marqueeCharacterLimit: 28),
                HermesStatusItem(title: "Status", value: store.connectionStatus, accent: .igGradOrange, marqueeCharacterLimit: 24),
                HermesStatusItem(title: "Events", value: "\(store.eventCount)", accent: .igGradPurple)
            ])

            ViewThatFits {
                HStack(spacing: 10) { controls }
                VStack(alignment: .leading, spacing: 10) { controls }
            }

            if !store.lastErrorMessage.isEmpty {
                Label(store.lastErrorMessage, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(Color.igDestructive)
            }
        }
        .padding(.horizontal)
        .padding(.top, isPhoneLayout ? 10 : 16)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var controls: some View {
        Button(store.isConnected ? "Reconnect" : "Connect") {
            store.disconnect()
            store.connect(dashboardBaseURL: dashboardURLString, apiSettings: apiSettings)
        }
        .hermesGlassProminentButton()
        .disabled(store.isConnecting)

        Button("New session") { store.createSession() }
            .hermesGlassButton()
            .disabled(!store.isConnected || store.isStreaming || store.isResumingSession)

        Button("Interrupt") { store.interruptSession() }
            .hermesGlassButton()
            .disabled(!store.isStreaming)

        Button("Close") { store.closeSession() }
            .hermesGlassButton()
            .disabled(!store.isConnected || store.sessionID.isEmpty)

        Menu {
            if store.activeSessions.isEmpty {
                Text("No live sessions")
            } else {
                ForEach(store.activeSessions) { session in
                    Button {
                        store.activateSession(session)
                    } label: {
                        Label(session.title, systemImage: session.isCurrent ? "checkmark.circle.fill" : "circle")
                    }
                }
            }
            Divider()
            Button("Refresh live sessions") { store.refreshSessions() }
        } label: {
            Label("Live sessions", systemImage: "rectangle.stack.badge.person.crop")
        }
        .hermesGlassButton()
        .disabled(!store.isConnected)
    }

    private var transcript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if store.messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.messages) { message in
                            HermesTUIGatewayBubble(
                                message: message,
                                responseText: Binding(
                                    get: { workspace.requestResponses[message.id, default: ""] },
                                    set: { workspace.requestResponses[message.id] = $0 }
                                ),
                                onApproval: { choice, all in store.respondToApproval(messageID: message.id, choice: choice, applyToAll: all) },
                                onPromptResponse: { value in
                                    guard let kind = message.requestKind, let requestID = message.requestID else { return }
                                    store.respondToPromptRequest(messageID: message.id, kind: kind, requestID: requestID, value: value)
                                    workspace.requestResponses[message.id] = ""
                                }
                            )
                            .id(message.id)
                        }
                    }
                    Color.clear.frame(height: 1).id("tui-gateway-bottom")
                }
                .padding(.horizontal, isPhoneLayout ? 12 : 22)
                .padding(.vertical, 16)
            }
            .onAppear { scrollToBottom(proxy, animated: false) }
            .onChange(of: store.messages.count) { _, _ in scrollToBottom(proxy) }
            .onChange(of: store.messages.last?.content) { _, _ in scrollToBottom(proxy) }
        }
    }

    private var emptyState: some View {
        HermesSectionCard {
            Label("Talk to Hermes through the TUI Gateway", systemImage: "terminal.fill")
                .font(.headline)
            Text("Connect to the dashboard WebSocket, create a live TUI Gateway session, send prompts, and handle streamed messages, events, clarifications, secrets, sudo prompts, and approvals from this native tab.")
                .font(.subheadline)
                .foregroundStyle(.hermesSecondaryText)
            Text("Transport: dashboard /api/ws using the same JSON-RPC protocol as hermes --tui.")
                .font(.caption)
                .foregroundStyle(.hermesSecondaryText)
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let selectedAttachment = workspace.selectedAttachment {
                HermesTUIAttachmentChip(attachment: selectedAttachment) {
                    workspace.selectedAttachment = nil
                }
                .disabled(store.isStreaming)
            }

            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    if shouldShowSkillPicker {
                        HermesSkillSlashPicker(
                            skills: filteredSkillSuggestions,
                            isLoading: dashboardSkills.isLoading,
                            errorMessage: dashboardSkills.lastErrorMessage,
                            onSelect: selectSkillSuggestion
                        )
                    }

                    TextEditor(text: $workspace.promptText)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: isPhoneLayout ? 56 : 78, maxHeight: isPhoneLayout ? 90 : 150)
                        .igFieldBackground()
                        .disabled(!store.isConnected || store.isStreaming)
                        .overlay(alignment: .topLeading) {
                            if workspace.promptText.isEmpty {
                                Text(store.isConnected ? "Send a prompt through the TUI Gateway…" : "Connect to the TUI Gateway first…")
                                    .foregroundStyle(.hermesSecondaryText)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 8)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                VStack(spacing: 8) {
                    Button { isImportingAttachment = true } label: {
                        Image(systemName: workspace.selectedAttachment == nil ? "paperclip" : "paperclip.circle.fill")
                            .font(.headline)
                            .frame(width: 42, height: 42)
                    }
                    .hermesGlassButton()
                    .disabled(!store.isConnected || store.isStreaming)
                    .accessibilityLabel(workspace.selectedAttachment == nil ? "Attach file" : "Change attached file")

                    Button { submitPrompt() } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.headline)
                            .frame(width: 42, height: 42)
                    }
                    .hermesGlassProminentButton()
                    .disabled(!store.canSendPrompt || (workspace.promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && workspace.selectedAttachment == nil))
                    .accessibilityLabel("Send through TUI Gateway")
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
    }

    private var activeSkillQuery: String? { workspace.promptText.hermesActiveSlashSkillQuery }

    private var filteredSkillSuggestions: [HermesDashboardSkill] {
        guard let query = activeSkillQuery else { return [] }
        if query.isEmpty { return dashboardSkills.skills }
        return dashboardSkills.skills.filter { $0.name.range(of: query, options: [.caseInsensitive, .anchored]) != nil }
    }

    private var shouldShowSkillPicker: Bool {
        activeSkillQuery != nil && (dashboardSkills.isLoading || (!dashboardSkills.lastErrorMessage.isEmpty && dashboardSkills.skills.isEmpty) || !filteredSkillSuggestions.isEmpty)
    }

    private func handlePromptSkillQueryChange() {
        guard activeSkillQuery != nil else { return }
        dashboardSkills.refreshIfNeeded(dashboardBaseURL: dashboardURLString, apiSettings: apiSettings)
    }

    private func selectSkillSuggestion(_ skill: HermesDashboardSkill) {
        workspace.promptText = workspace.promptText.replacingActiveSlashSkillQuery(with: skill.name)
    }

    private func submitPrompt() {
        let text = workspace.promptText
        store.submitPrompt(text, attachment: workspace.selectedAttachment)
        workspace.promptText = ""
        workspace.selectedAttachment = nil
    }

    private func handleAttachmentImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                workspace.selectedAttachment = try HermesPromptAttachment.load(from: url)
                store.lastErrorMessage = ""
            } catch {
                store.lastErrorMessage = error.localizedDescription
            }
        case .failure(let error):
            store.lastErrorMessage = error.localizedDescription
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("tui-gateway-bottom", anchor: .bottom) }
            } else {
                proxy.scrollTo("tui-gateway-bottom", anchor: .bottom)
            }
        }
    }
}

private struct HermesTUIGatewayBubble: View {
    let message: HermesTUIGatewayMessage
    @Binding var responseText: String
    let onApproval: (String, Bool) -> Void
    let onPromptResponse: (String) -> Void

    var body: some View {
        HStack(alignment: .bottom) {
            if isUser { Spacer(minLength: 42) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(message.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.hermesSecondaryText)
                    if let eventType = message.eventType {
                        Text(eventType)
                            .font(.caption2.monospaced())
                            .foregroundStyle(Color.hermesSecondaryText.opacity(0.85))
                    }
                    if message.isResolved {
                        Text("Resolved")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.igOnlineGreen)
                    }
                }

                HermesTUICopyableBubbleContent(text: message.content.isEmpty ? "…" : message.content, copyText: message.content, isUser: isUser, rendersMarkdown: !isUser && message.role == .assistant)

                if message.role == .request && !message.isResolved { requestControls }
            }
            .frame(maxWidth: 720, alignment: isUser ? .trailing : .leading)
            if !isUser { Spacer(minLength: 42) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var isUser: Bool { message.role == .user }

    @ViewBuilder
    private var requestControls: some View {
        switch message.requestKind {
        case .approval:
            ViewThatFits {
                HStack(spacing: 8) { approvalButtons }
                VStack(alignment: .leading, spacing: 8) { approvalButtons }
            }
        case .clarify, .sudo, .secret:
            VStack(alignment: .leading, spacing: 8) {
                SecureOrPlainTUIRequestField(kind: message.requestKind, text: $responseText)
                HStack(spacing: 8) {
                    Button("Respond") { onPromptResponse(responseText) }
                        .hermesGlassProminentButton()
                    Button("Skip") { onPromptResponse("") }
                        .hermesGlassButton()
                }
            }
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private var approvalButtons: some View {
        Button("Run once") { onApproval("once", false) }
            .hermesGlassProminentButton()
        Button("Allow all") { onApproval("once", true) }
            .hermesGlassButton()
        Button("Deny") { onApproval("deny", false) }
            .hermesGlassButton()
    }
}

private struct SecureOrPlainTUIRequestField: View {
    let kind: HermesTUIGatewayMessage.RequestKind?
    @Binding var text: String

    var body: some View {
        if kind == .sudo || kind == .secret {
            SecureField("Response", text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 340)
        } else {
            TextField("Response", text: $text, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 420)
        }
    }
}

private struct HermesTUICopyableBubbleContent: View {
    let text: String
    let copyText: String
    let isUser: Bool
    var rendersMarkdown = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if rendersMarkdown, let attributed = try? AttributedString(markdown: text) {
                Text(attributed)
                    .textSelection(.enabled)
            } else {
                Text(text)
                    .textSelection(.enabled)
            }
        }
        .font(.body)
        .foregroundStyle(isUser ? .white : .primary)
        .padding(.leading, 14)
        .padding(.trailing, 32)
        .padding(.top, 11)
        .padding(.bottom, 24)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isUser ? Color.igActionBlue : Color.hermesSurfaceInput)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(isUser ? Color.igActionBlue.opacity(0.45) : Color.hermesDivider.opacity(0.7), lineWidth: 1)
        )
        .overlay(alignment: .bottomTrailing) {
            if !copyText.isEmpty {
                Button {
                    UIPasteboard.general.string = copyText
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption2.weight(.bold))
                        .padding(6)
                        .background(.thinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(isUser ? .white : .primary)
                .padding(.trailing, 8)
                .padding(.bottom, 6)
                .accessibilityLabel("Copy message")
            }
        }
    }
}

private struct HermesTUIAttachmentChip: View {
    let attachment: HermesPromptAttachment
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: attachment.isImage ? "photo" : "doc")
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.filename)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text("\(attachment.mimeType) • \(attachment.formattedByteCount)")
                    .font(.caption2)
                    .foregroundStyle(.hermesSecondaryText)
                    .lineLimit(1)
            }
            Button(action: remove) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove attachment")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.hermesSurfaceInput, in: Capsule())
    }
}
