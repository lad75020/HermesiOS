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

    var integerValue: Int? {
        switch self {
        case .number(let value): Int(exactly: value)
        case .string(let value): Int(value)
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

enum HermesTUIGatewayError: LocalizedError {
    case invalidDashboardURL
    case invalidWebSocketURL
    case notConnected
    case requestFailed(String)
    case missingSession
    case blockedPlaintext(String)
    case runtimeScopeMismatch(String)

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
        case .runtimeScopeMismatch(let message):
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

struct HermesTUIModelOption: Identifiable, Equatable {
    let provider: String
    let providerName: String
    let model: String
    let supportsReasoning: Bool
    let supportsFast: Bool

    var id: String { "\(provider)::\(model)" }
}

/// A toolset reported by the existing TUI Gateway `toolsets.list` RPC. This is
/// separate from Host Companion's file-backed toolset model because the gateway
/// owns both the configuration semantics and the active runtime scope.
struct HermesTUIRuntimeToolset: Identifiable, Equatable {
    let name: String
    let description: String
    let toolCount: Int
    let enabled: Bool

    var id: String { name }
}

/// The gateway's `skills.manage` list response is a process-wide, cached catalog.
/// It deliberately carries only the categories and skill names reported by Hermes.
struct HermesTUIGatewaySkillsCatalog: Equatable {
    let categories: [String: [String]]

    var skillCount: Int {
        categories.values.reduce(0) { $0 + $1.count }
    }
}

struct HermesTUIProfileOption: Identifiable, Equatable {
    let name: String
    /// This is an opaque remote path.  It must never be canonicalized on iOS.
    let path: String
    let displayName: String
    let provider: String
    let model: String

    init(name: String, path: String = "", displayName: String, provider: String, model: String) {
        self.name = name
        self.path = path
        self.displayName = displayName
        self.provider = provider
        self.model = model
    }

    var id: String { name }
}

struct HermesTUIInferenceSelection: Equatable {
    static let reasoningEfforts = ["none", "minimal", "low", "medium", "high", "xhigh", "max", "ultra"]

    var profile = "default"
    var provider = ""
    var model = ""
    var reasoningEffort = "medium"
    var fast = false
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
    var profileOptions: [HermesTUIProfileOption] = []
    var modelOptions: [HermesTUIModelOption] = []
    var inference = HermesTUIInferenceSelection() {
        didSet {
            if oldValue != inference { modelOptionsRequestID = UUID() }
        }
    }
    // Invalidates catalog completions even for A → B → A or an explicit draft Save.
    var modelOptionsRequestID = UUID()
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
enum HermesTUIHistoryResumeCoordinator {
    static func destination(
        in workspaces: inout [HermesTUIWorkspace],
        selectedWorkspaceID: HermesTUIWorkspace.ID,
        isBusy: (HermesTUIWorkspace) -> Bool,
        makeWorkspace: () -> HermesTUIWorkspace
    ) -> HermesTUIWorkspace {
        if let inactiveWorkspace = workspaces.first(where: {
            $0.id != selectedWorkspaceID && !isBusy($0)
        }) {
            return inactiveWorkspace
        }

        let workspace = makeWorkspace()
        workspaces.append(workspace)
        return workspace
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
    private var connectionGeneration = UUID()
    private var pendingResponses: [String: CheckedContinuation<JSONValue, Error>] = [:]
    private var activeAssistantMessageID: UUID?
    private var activeStreamMessageID: UUID?
    private var activeStreamContentType: String?
    private var currentTurnReceivedMessageDelta = false
    private var currentTurnMessageDeltaSegmentCount = 0

#if DEBUG
    // Test transport seam: exercise the real submit/session parameter path without a host.
    @ObservationIgnored var requestOverride: ((String, [String: JSONValue]) async throws -> JSONValue)?
    @ObservationIgnored var runtimeConnectOverride: (() async -> Void)?
#endif

    var canSendPrompt: Bool {
        isConnected && !isStreaming && !sessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func connect(dashboardBaseURL: String, apiSettings: HermesAPISettings, inference: HermesTUIInferenceSelection) {
        guard !isConnecting else { return }
        Task { await connectGateway(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings, createSessionIfMissing: true, inference: inference) }
    }

    /// Connect a dedicated Agent Runtime client without creating a chat session.
    /// The RPC surface and authentication remain entirely owned by the TUI Gateway.
    private var runtimeConnectionIdentity: HermesRuntimeConnectionIdentity?
    private var runtimeToolsetMutationInProgress = false

    func connectForRuntime(dashboardBaseURL: String, apiSettings: HermesAPISettings) async throws {
        let identity = HermesRuntimeConnectionIdentity(dashboardURL: dashboardBaseURL, apiSettings: apiSettings)
        if let previous = runtimeConnectionIdentity, previous != identity {
            disconnect()
        }
        runtimeConnectionIdentity = identity
        let generation = connectionGeneration
        if !isConnected {
            await connectRuntimeTransport(
                dashboardBaseURL: dashboardBaseURL,
                apiSettings: apiSettings
            )
        }
        guard generation == connectionGeneration, runtimeConnectionIdentity == identity, !Task.isCancelled else {
            throw HermesTUIGatewayError.notConnected
        }
        guard isConnected else {
            throw HermesTUIGatewayError.requestFailed(
                lastErrorMessage.isEmpty ? "Unable to connect to the TUI Gateway." : lastErrorMessage
            )
        }
    }

    /// Lists the launch-runtime toolsets only after proving that its home is the
    /// exact, authenticated path selected in Agent Runtime.  Toolset RPCs have
    /// no profile/session parameter because their scope is the gateway launch home.
    func runtimeToolsets(profileName: String, authenticatedProfilePath: String) async throws -> [HermesTUIRuntimeToolset] {
        let generation = try await proveRuntimeToolsetScope(
            profileName: profileName,
            authenticatedProfilePath: authenticatedProfilePath
        )
        let result = try await request("toolsets.list", params: [:], timeoutSeconds: 45)
        try validateRuntimeRequest(generation)
        return try Self.decodeRuntimeToolsets(result)
    }

    /// Reads Hermes' existing process-wide skills catalog without a profile or
    /// session. This does not create or mutate a chat session, and it is not a
    /// selected-profile inventory because the gateway cache is not profile-keyed.
    func runtimeSkillsCatalog() async throws -> HermesTUIGatewaySkillsCatalog {
        let generation = connectionGeneration
        let result = try await request(
            "skills.manage",
            params: ["action": .string("list")],
            timeoutSeconds: 45
        )
        guard connectionGeneration == generation, isConnected, !Task.isCancelled else {
            throw HermesTUIGatewayError.notConnected
        }
        return try Self.decodeRuntimeSkillsCatalog(result)
    }

    /// Reads installed names and enabled state from the selected profile, not the process cache.
    func runtimeProfileSkills(profileName: String) async throws -> HermesTUIProfileSkills {
        guard !profileName.isEmpty, profileName == profileName.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw HermesTUIGatewayError.requestFailed("An exact selected profile name is required.")
        }
        let generation = connectionGeneration
        try validateRuntimeRequest(generation)
        let result = try await request("profiles.describe", params: ["name": .string(profileName)], timeoutSeconds: 45)
        try validateRuntimeRequest(generation)
        return try HermesTUIProfileSkills.decode(result, profileName: profileName)
    }

    var runtimeConnectionVersion: UUID { connectionGeneration }

    /// Narrow bridge for the existing selected-profile main-model editor.
    func runtimeProfileModelRequest(method: String, params: [String: JSONValue]) async throws -> JSONValue {
        let allowedKeys: Set<String> = method == "profiles.describe" ? ["name"] : ["name", "model", "provider", "confirm_expensive_model"]
        guard ["profiles.describe", "profiles.configure"].contains(method),
              Set(params.keys).isSubset(of: allowedKeys),
              case .string(let profile)? = params["name"], !profile.isEmpty,
              profile == profile.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw HermesTUIGatewayError.requestFailed("Unsupported runtime model request.")
        }
        let generation = connectionGeneration
        try validateRuntimeRequest(generation)
        let result = try await request(method, params: params, timeoutSeconds: 45)
        try validateRuntimeRequest(generation)
        return result
    }

    /// Existing structured cron RPC; no conversation or sticky-profile changes.
    func runtimeCronRequest(params: [String: JSONValue]) async throws -> JSONValue {
        guard case .string(let profile)? = params["profile"], !profile.isEmpty,
              case .string(let action)? = params["action"],
              ["list", "add", "pause", "resume", "remove"].contains(action) else {
            throw HermesTUIGatewayError.requestFailed("Unsupported runtime schedule request.")
        }
        let generation = connectionGeneration
        try validateRuntimeRequest(generation)
        let result = try await request("cron.manage", params: params, timeoutSeconds: 45)
        try validateRuntimeRequest(generation)
        return result
    }

    func setRuntimeToolsetEnabled(
        name: String,
        enabled: Bool,
        profileName: String,
        authenticatedProfilePath: String
    ) async throws -> [HermesTUIRuntimeToolset] {
        guard !runtimeToolsetMutationInProgress else {
            throw HermesTUIGatewayError.requestFailed("A gateway toolset change is already in progress.")
        }
        runtimeToolsetMutationInProgress = true
        defer { runtimeToolsetMutationInProgress = false }
        let operationGeneration = connectionGeneration
        // Read before modifying so an unknown target cannot be reported as changed.
        let before = try await runtimeToolsets(
            profileName: profileName,
            authenticatedProfilePath: authenticatedProfilePath
        )
        try validateRuntimeRequest(operationGeneration)
        guard before.contains(where: { $0.name == name }) else {
            throw HermesTUIGatewayError.requestFailed("The requested TUI Gateway toolset is not available.")
        }
        // The read above may have taken time; prove the launch scope again directly
        // before the write, then use a fresh generation guard for the acknowledgement.
        let generation = try await proveRuntimeToolsetScope(
            profileName: profileName,
            authenticatedProfilePath: authenticatedProfilePath
        )
        try validateRuntimeRequest(operationGeneration)
        let acknowledgement = try await request(
            "tools.configure",
            params: [
                "action": .string(enabled ? "enable" : "disable"),
                "names": .array([.string(name)])
            ],
            timeoutSeconds: 45
        )
        try validateRuntimeRequest(generation)
        try Self.validateToolsetConfigurationAcknowledgement(acknowledgement, expectedName: name)
        // A successful write is not enough: a reconnect or scope change between
        // acknowledgement and refresh must not paint a different runtime as success.
        let refreshed = try await runtimeToolsets(
            profileName: profileName,
            authenticatedProfilePath: authenticatedProfilePath
        )
        try validateRuntimeRequest(operationGeneration)
        guard refreshed.first(where: { $0.name == name })?.enabled == enabled else {
            throw HermesTUIGatewayError.requestFailed("The gateway acknowledged the change, but its refreshed toolset state does not match. Reload before retrying.")
        }
        return refreshed
    }

    /// Profiles are listed without sessions.  Their opaque paths support the
    /// fail-closed proof used by the launch-scoped toolset RPCs.
    func runtimeProfileOptions() async throws -> [HermesTUIProfileOption] {
        let generation = connectionGeneration
        let result = try await request(
            "profiles.list",
            params: ["include_sessions": .bool(false)],
            timeoutSeconds: 45
        )
        try validateRuntimeRequest(generation)
        return try Self.decodeRuntimeProfileOptions(result)
    }

    func disconnect() {
        connectionGeneration = UUID()
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

    func createSession(inference: HermesTUIInferenceSelection) {
        Task { await createGatewaySession(inference: inference) }
    }

    func submitPrompt(_ prompt: String, attachment: HermesPromptAttachment? = nil, inference: HermesTUIInferenceSelection) {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || attachment != nil else { return }
        Task { await submit(text, attachment: attachment, inference: inference) }
    }

    func loadProfileOptions(into workspace: HermesTUIWorkspace) {
        guard isConnected else { return }
        let generation = connectionGeneration
        let selectionID = workspace.modelOptionsRequestID
        Task {
            do {
                let result = try await request("profiles.list", params: ["include_sessions": .bool(false)], timeoutSeconds: 45)
                guard connectionGeneration == generation, isConnected else { return }
                workspace.profileOptions = Self.decodeProfileOptions(result)
                guard workspace.modelOptionsRequestID == selectionID else { return }
                if !workspace.profileOptions.contains(where: { $0.name == workspace.inference.profile }) {
                    workspace.inference.profile = workspace.profileOptions.first?.name ?? "default"
                }
                await loadModelOptions(into: workspace, selectProfileDefault: workspace.inference.model.isEmpty)
            } catch {
                guard connectionGeneration == generation, workspace.modelOptionsRequestID == selectionID else { return }
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    func selectProfile(_ profile: HermesTUIProfileOption, in workspace: HermesTUIWorkspace) {
        guard !isStreaming, workspace.inference.profile != profile.name else { return }
        workspace.inference.profile = profile.name
        workspace.inference.provider = profile.provider
        workspace.inference.model = profile.model
        workspace.inference.reasoningEffort = "medium"
        workspace.inference.fast = false
        workspace.modelOptions = []
        let selectionID = workspace.modelOptionsRequestID
        Task {
            guard workspace.modelOptionsRequestID == selectionID else { return }
            guard await loadModelOptions(into: workspace, selectProfileDefault: true), isConnected else { return }
            await createGatewaySession(inference: workspace.inference)
        }
    }

    func modelOptions(for profile: String) async throws -> [HermesTUIModelOption] {
        guard isConnected else { throw HermesTUIGatewayError.notConnected }
        let generation = connectionGeneration
        var params: [String: JSONValue] = [:]
        let trimmedProfile = profile.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedProfile.isEmpty { params["profile"] = .string(trimmedProfile) }
        let result = try await request("model.options", params: params, timeoutSeconds: 45)
        guard connectionGeneration == generation, isConnected else { throw HermesTUIGatewayError.notConnected }
        return Self.decodeModelOptions(result)
    }

    @discardableResult
    func loadModelOptions(
        into workspace: HermesTUIWorkspace,
        selectProfileDefault: Bool,
        load: HermesTUIPhoneInferenceDraft.ModelLoader? = nil
    ) async -> Bool {
        let requestID = UUID()
        workspace.modelOptionsRequestID = requestID
        let generation = connectionGeneration
        let profile = workspace.inference.profile.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let options = try await (load ?? modelOptions)(profile)
            guard workspace.modelOptionsRequestID == requestID, connectionGeneration == generation, !Task.isCancelled else { return false }
            workspace.modelOptions = options
            if selectProfileDefault, let profileOption = workspace.profileOptions.first(where: { $0.name == profile }) {
                let defaultOption = options.first { $0.provider == profileOption.provider && $0.model == profileOption.model }
                    ?? options.first { $0.model == profileOption.model }
                if let defaultOption {
                    workspace.inference.provider = defaultOption.provider
                    workspace.inference.model = defaultOption.model
                } else {
                    workspace.inference.provider = profileOption.provider
                    workspace.inference.model = profileOption.model
                }
            } else if workspace.inference.model.isEmpty, let defaultOption = options.first {
                workspace.inference.provider = defaultOption.provider
                workspace.inference.model = defaultOption.model
                workspace.inference.fast = false
            }
            workspace.inference = Self.normalizedInference(workspace.inference, options: options)
            return true
        } catch {
            guard workspace.modelOptionsRequestID == requestID, connectionGeneration == generation, !Task.isCancelled else { return false }
            lastErrorMessage = error.localizedDescription
            return false
        }
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

    private func connectRuntimeTransport(dashboardBaseURL: String, apiSettings: HermesAPISettings) async {
#if DEBUG
        if let runtimeConnectOverride {
            await runtimeConnectOverride()
            return
        }
#endif
        await connectGateway(dashboardBaseURL: dashboardBaseURL, apiSettings: apiSettings, createSessionIfMissing: false)
    }

    private func connectGateway(dashboardBaseURL: String, apiSettings: HermesAPISettings, createSessionIfMissing: Bool, inference: HermesTUIInferenceSelection? = nil) async {
        guard !isConnecting else { return }
        let generation = connectionGeneration
        defer { if generation == connectionGeneration { isConnecting = false } }
        let inference = inference ?? HermesTUIInferenceSelection()
        isConnecting = true
        lastErrorMessage = ""
        connectionStatus = "Connecting"
        do {
            let baseURL = try resolvedDashboardBaseURL(from: dashboardBaseURL, apiBaseURL: apiSettings.baseURL)
            let candidateURLs = try await webSocketURLs(baseURL: baseURL, apiSettings: apiSettings)
            guard generation == connectionGeneration, !Task.isCancelled else { return }
            var lastConnectionError: Error?

            for wsURL in candidateURLs {
                do {
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
                        try await createGatewaySessionThrowing(inference: inference)
                    }
                    await refreshActiveSessions()
                    return
                } catch {
                    guard generation == connectionGeneration, !Task.isCancelled else { return }
                    lastConnectionError = error
                    closeFailedConnection(error)
                    isConnecting = true
                    connectionStatus = "Trying fallback"
                }
            }

            throw lastConnectionError ?? HermesTUIGatewayError.requestFailed("Unable to connect to the TUI Gateway WebSocket.")
        } catch {
            guard generation == connectionGeneration, !Task.isCancelled else { return }
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

    private func createGatewaySession(inference: HermesTUIInferenceSelection) async {
        do {
            try await createGatewaySessionThrowing(inference: inference)
        } catch {
            lastErrorMessage = error.localizedDescription
            connectionStatus = "Session create failed"
        }
    }

    private func createGatewaySessionThrowing(inference: HermesTUIInferenceSelection) async throws {
        let result = try await request("session.create", params: inferenceParams(inference), timeoutSeconds: 120)
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
    }

    func submit(_ text: String, attachment: HermesPromptAttachment? = nil, inference: HermesTUIInferenceSelection) async {
        guard canSendPrompt else {
            lastErrorMessage = HermesTUIGatewayError.missingSession.localizedDescription
            return
        }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachment != nil else { return }
        if let attachment, attachment.data.isEmpty || attachment.data.count > 25 * 1024 * 1024 {
            lastErrorMessage = "Attachments must be nonempty and at most 25 MiB."
            connectionStatus = "Attachment failed"
            return
        }
        let target = sessionID
        let generation = connectionGeneration
        // Reserve the turn before awaiting upload: no second send/profile change may
        // consume the session's queued image while this submit is preparing it.
        isStreaming = true
        lastErrorMessage = ""
        connectionStatus = attachment == nil ? "Sending prompt" : "Uploading attachment"
        let prepared: (payloadText: String, displayText: String, activity: String?)
        do {
            prepared = try await promptPayload(text: text, attachment: attachment, session: target)
        } catch {
            guard connectionGeneration == generation, sessionID == target else { return }
            isStreaming = false
            lastErrorMessage = attachment == nil ? error.localizedDescription : "Attachment upload failed. Check that the gateway supports image.attach_bytes and file.attach, then attach the file again."
            connectionStatus = "Attachment failed"
            return
        }
        guard connectionGeneration == generation, sessionID == target, isConnected else { return }
        if let activity = prepared.activity {
            appendEvent(title: "Attachment", content: activity, eventType: "input.attachment")
        }
        resetStreamGrouping()
        messages.append(HermesTUIGatewayMessage(role: .user, title: "You", content: prepared.displayText))
        connectionStatus = "Sending prompt"
        do {
            var params = inferenceParams(inference)
            params["session_id"] = .string(target)
            params["text"] = .string(prepared.payloadText)
            _ = try await request("prompt.submit", params: params, timeoutSeconds: 60)
            guard connectionGeneration == generation, sessionID == target else { return }
            connectionStatus = "Streaming"
        } catch {
            guard connectionGeneration == generation, sessionID == target else { return }
            // Do not detach after an ambiguous transport failure: an accepted turn
            // can still be waiting for its agent build to consume the queued image.
            isStreaming = false
            lastErrorMessage = error.localizedDescription
            connectionStatus = "Prompt failed"
            updateAssistantMessage(text: "Request failed: \(error.localizedDescription)")
        }
    }

    private func promptPayload(text: String, attachment: HermesPromptAttachment?, session: String) async throws -> (payloadText: String, displayText: String, activity: String?) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let attachment else { return (trimmedText, trimmedText, nil) }
        let block: String
        if attachment.isUTF8Text, attachment.data.count <= 32 * 1024, attachment.textContent != nil {
            // Bound inline context; larger text and undecodable text retain all bytes
            // through file.attach instead of truncation or the legacy base64 fallback.
            block = attachment.textAttachmentBlock
        } else if attachment.isImage {
            let mime = UTType(filenameExtension: attachment.fileExtension)?.preferredMIMEType ?? attachment.mimeType
            let result = try await request("image.attach_bytes", params: [
                "session_id": .string(session), "filename": .string(attachment.filename),
                "content_base64": .string("data:\(mime);base64,\(attachment.data.base64EncodedString())")
            ], timeoutSeconds: 120).objectValue
            guard result["attached"]?.boolValue == true,
                  let path = result["path"]?.stringValue, !path.isEmpty else {
                throw HermesTUIGatewayError.requestFailed("Gateway did not attach the image.")
            }
            block = trimmedText.isEmpty ? "What do you see in this image?" : ""
        } else {
            let result = try await request("file.attach", params: [
                "session_id": .string(session), "name": .string(attachment.filename),
                "data_url": .string(attachment.base64DataURL)
            ], timeoutSeconds: 120).objectValue
            guard result["attached"]?.boolValue == true,
                  let reference = result["ref_text"]?.stringValue,
                  reference.hasPrefix("@file:"), reference.utf8.count <= 4096,
                  !reference.contains(";base64,") else {
                throw HermesTUIGatewayError.requestFailed("Gateway did not return a file reference.")
            }
            block = reference
        }
        let payload = [trimmedText, block.trimmingCharacters(in: .whitespacesAndNewlines)]
            .filter { !$0.isEmpty }.joined(separator: "\n\n")
        let display = [trimmedText, "Attached: \(attachment.filename) (\(attachment.formattedByteCount))"]
            .filter { !$0.isEmpty }.joined(separator: "\n\n")
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
                guard task === webSocketTask, !Task.isCancelled else { return }
                switch message {
                case .string(let text):
                    await handleWebSocketText(text)
                case .data(let data):
                    await handleWebSocketText(String(decoding: data, as: UTF8.self))
                @unknown default:
                    break
                }
            } catch {
                if Task.isCancelled || task !== webSocketTask { return }
                isConnected = false
                isStreaming = false
                connectionStatus = "Disconnected"
                lastErrorMessage = error.localizedDescription
                failPending(error)
                return
            }
        }
    }

    func handleWebSocketText(_ text: String) async {
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
        case "sessions.changed", "cron.changed", "platforms.changed", "pairing.changed", "pet.changed", "skin.changed":
            // Global dashboard invalidations are not conversation activity. Keep
            // counting received events without changing the transcript or status.
            return
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

    private func inferenceParams(_ inference: HermesTUIInferenceSelection) -> [String: JSONValue] {
        let model = inference.model.trimmingCharacters(in: .whitespacesAndNewlines)
        var params: [String: JSONValue] = [:]
        let profile = inference.profile.trimmingCharacters(in: .whitespacesAndNewlines)
        if !profile.isEmpty { params["profile"] = .string(profile) }
        guard !model.isEmpty else { return params }
        params["model"] = .string(model)
        params["reasoning_effort"] = .string(inference.reasoningEffort)
        params["fast"] = .bool(inference.fast)
        let provider = inference.provider.trimmingCharacters(in: .whitespacesAndNewlines)
        if !provider.isEmpty { params["provider"] = .string(provider) }
        return params
    }

    private static func decodeModelOptions(_ result: JSONValue) -> [HermesTUIModelOption] {
        let providerRows = result.objectValue["providers"]?.arrayValue ?? []
        var options: [HermesTUIModelOption] = []
        for provider in providerRows {
            let row = provider.objectValue
            let slug = row["slug"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !slug.isEmpty else { continue }
            let name = row["name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            let providerName = (name?.isEmpty == false ? name! : slug)
            let capabilities = row["capabilities"]?.objectValue ?? [:]
            for value in row["models"]?.arrayValue ?? [] {
                guard let model = value.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !model.isEmpty else { continue }
                let modelCapabilities = capabilities[model]?.objectValue ?? [:]
                options.append(HermesTUIModelOption(
                    provider: slug,
                    providerName: providerName,
                    model: model,
                    supportsReasoning: modelCapabilities["reasoning"]?.boolValue ?? false,
                    supportsFast: modelCapabilities["fast"]?.boolValue ?? false
                ))
            }
        }
        return options.sorted {
            $0.providerName.localizedCaseInsensitiveCompare($1.providerName) == .orderedAscending
                || ($0.providerName.caseInsensitiveCompare($1.providerName) == .orderedSame
                    && $0.model.localizedCaseInsensitiveCompare($1.model) == .orderedAscending)
        }
    }

    private static func decodeRuntimeToolsets(_ result: JSONValue) throws -> [HermesTUIRuntimeToolset] {
        guard case .object(let payload) = result,
              case .array(let values)? = payload["toolsets"] else {
            throw HermesTUIGatewayError.requestFailed("Invalid TUI Gateway toolsets response.")
        }
        var names = Set<String>()
        let toolsets = try values.map { value -> HermesTUIRuntimeToolset in
            guard case .object(let row) = value,
                  case .string(let rawName)? = row["name"],
                  rawName.isEmpty == false,
                  case .string(let description)? = row["description"],
                  case .number(let rawCount)? = row["tool_count"],
                  let toolCount = Int(exactly: rawCount),
                  toolCount >= 0,
                  case .bool(let enabled)? = row["enabled"],
                  names.insert(rawName).inserted else {
                throw HermesTUIGatewayError.requestFailed("Invalid or ambiguous TUI Gateway toolset response.")
            }
            return HermesTUIRuntimeToolset(name: rawName, description: description, toolCount: toolCount, enabled: enabled)
        }
        return toolsets.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func decodeRuntimeSkillsCatalog(_ result: JSONValue) throws -> HermesTUIGatewaySkillsCatalog {
        guard case .object(let payload) = result,
              case .object(let rawCategories)? = payload["skills"] else {
            throw HermesTUIGatewayError.requestFailed("Invalid gateway skills catalog response.")
        }
        var categories: [String: [String]] = [:]
        for (category, rawNames) in rawCategories {
            guard case .array(let values) = rawNames else {
                throw HermesTUIGatewayError.requestFailed("Invalid gateway skills category response.")
            }
            let names = try values.map { value -> String in
                guard case .string(let name) = value else {
                    throw HermesTUIGatewayError.requestFailed("Invalid gateway skill name response.")
                }
                return name
            }
            categories[category] = names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        }
        return HermesTUIGatewaySkillsCatalog(categories: categories)
    }

    private static func decodeProfileOptions(_ result: JSONValue) -> [HermesTUIProfileOption] {
        // Preserve chat's tolerant catalog behavior; runtime proof is separate.
        var seen = Set<String>()
        let options = (result.objectValue["profiles"]?.arrayValue ?? []).compactMap { value -> HermesTUIProfileOption? in
            let row = value.objectValue
            let name = row["name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty, seen.insert(name).inserted else { return nil }
            let displayName = row["display_name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            return HermesTUIProfileOption(
                name: name,
                path: row["path"]?.stringValue ?? "",
                displayName: displayName?.isEmpty == false ? displayName! : name,
                provider: row["provider"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
                model: row["model"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            )
        }
        if options.isEmpty {
            return [HermesTUIProfileOption(name: "default", path: "", displayName: "default", provider: "", model: "")]
        }
        return options.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private static func decodeRuntimeProfileOptions(_ result: JSONValue) throws -> [HermesTUIProfileOption] {
        guard case .object(let payload) = result,
              case .array(let values)? = payload["profiles"],
              values.isEmpty == false else {
            throw HermesTUIGatewayError.requestFailed("Invalid TUI Gateway profile inventory response.")
        }
        var names = Set<String>()
        var paths = Set<String>()
        let options = try values.map { value -> HermesTUIProfileOption in
            guard case .object(let row) = value,
                  case .string(let name)? = row["name"], name.isEmpty == false,
                  case .string(let path)? = row["path"], path.isEmpty == false,
                  case .string(let displayName)? = row["display_name"],
                  case .string(let provider)? = row["provider"],
                  case .string(let model)? = row["model"],
                  names.insert(name).inserted,
                  paths.insert(path).inserted else {
                throw HermesTUIGatewayError.requestFailed("Invalid or ambiguous TUI Gateway profile inventory response.")
            }
            return HermesTUIProfileOption(name: name, path: path, displayName: displayName, provider: provider, model: model)
        }
        return options.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private func proveRuntimeToolsetScope(profileName: String, authenticatedProfilePath: String) async throws -> UUID {
        guard !profileName.isEmpty, !authenticatedProfilePath.isEmpty, isConnected, !Task.isCancelled else {
            throw HermesTUIGatewayError.notConnected
        }
        let generation = connectionGeneration
        let config = try await request("config.get", params: ["key": .string("profile")], timeoutSeconds: 45)
        try validateRuntimeRequest(generation)
        let profiles = try await runtimeProfileOptions()
        try validateRuntimeRequest(generation)
        guard case .object(let configPayload) = config,
              case .string(let launchHome)? = configPayload["home"],
              launchHome.isEmpty == false else {
            throw HermesTUIGatewayError.requestFailed("Invalid TUI Gateway launch-profile response.")
        }
        let selected = profiles.filter { $0.name == profileName && $0.path == authenticatedProfilePath }
        guard selected.count == 1 else {
            throw HermesTUIGatewayError.requestFailed("The selected authenticated profile is missing or ambiguous in the TUI Gateway inventory.")
        }
        guard launchHome == authenticatedProfilePath else {
            throw HermesTUIGatewayError.runtimeScopeMismatch("The TUI Gateway launch profile does not match the selected authenticated profile. Gateway toolset changes are blocked.")
        }
        return generation
    }

    private func validateRuntimeRequest(_ generation: UUID) throws {
        guard connectionGeneration == generation, isConnected, !Task.isCancelled else {
            throw HermesTUIGatewayError.notConnected
        }
    }

    private static func validateToolsetConfigurationAcknowledgement(_ result: JSONValue, expectedName: String) throws {
        guard case .object(let payload) = result,
              case .array(let changed)? = payload["changed"],
              case .array(let unknown)? = payload["unknown"], unknown.isEmpty,
              case .array(let missingServers)? = payload["missing_servers"], missingServers.isEmpty,
              changed.count == 1,
              changed.first == .string(expectedName) else {
            throw HermesTUIGatewayError.requestFailed("TUI Gateway did not acknowledge the requested toolset change.")
        }
    }

    private static func normalizedInference(_ inference: HermesTUIInferenceSelection, options: [HermesTUIModelOption]) -> HermesTUIInferenceSelection {
        var normalized = inference
        let selected = options.first { $0.provider == inference.provider && $0.model == inference.model }
        if selected?.supportsReasoning != true { normalized.reasoningEffort = "none" }
        if selected?.supportsFast != true { normalized.fast = false }
        return normalized
    }

    private func request(_ method: String, params: [String: JSONValue], timeoutSeconds: UInt64) async throws -> JSONValue {
#if DEBUG
        if let requestOverride { return try await requestOverride(method, params) }
#endif
        guard let task = webSocketTask, isConnected else { throw HermesTUIGatewayError.notConnected }
        requestCounter += 1
        let id = "ios-\(requestCounter)"
        let request = HermesTUIGatewayRPCRequest(id: id, method: method, params: params)
        let data = try JSONEncoder().encode(request)
        guard let text = String(data: data, encoding: .utf8) else { throw HermesTUIGatewayError.requestFailed("Could not encode JSON-RPC request.") }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                pendingResponses[id] = continuation
                Task {
                    do {
                        try await task.send(.string(text))
                    } catch {
                        resolvePendingResponse(id: id, result: .failure(error))
                    }
                }
                Task {
                    try? await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                    resolvePendingResponse(
                        id: id,
                        result: .failure(HermesTUIGatewayError.requestFailed("Timed out waiting for \(method)."))
                    )
                }
            }
        } onCancel: {
            Task { @MainActor in
                if let continuation = self.pendingResponses.removeValue(forKey: id) {
                    continuation.resume(throwing: CancellationError())
                }
            }
        }
    }

    private func resolvePendingResponse(id: String, result: Result<JSONValue, Error>) {
        guard let continuation = pendingResponses.removeValue(forKey: id) else { return }
        switch result {
        case .success(let value):
            continuation.resume(returning: value)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    private func closeFailedConnection(_ error: Error) {
        receiveTask?.cancel()
        receiveTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        isStreaming = false
        failPending(error)
    }

    private func webSocketURLs(baseURL: URL, apiSettings: HermesAPISettings) async throws -> [URL] {
        var urls: [URL] = []
        var lastError: Error?
        for candidate in dashboardBaseURLCandidates(from: baseURL) {
            do {
                let url = try await webSocketURL(baseURL: candidate, apiSettings: apiSettings)
                if !urls.contains(url) { urls.append(url) }
            } catch {
                lastError = error
            }
        }
        guard !urls.isEmpty else { throw lastError ?? HermesTUIGatewayError.invalidWebSocketURL }
        return urls
    }

    private func dashboardBaseURLCandidates(from baseURL: URL) -> [URL] {
        var candidates = [baseURL]
        guard baseURL.scheme?.lowercased() == "https",
              var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        else { return candidates }
        components.scheme = "http"
        guard let plaintextURL = components.url,
              HermesEndpointSecurity.isLoopbackHost(plaintextURL.host ?? ""),
              !candidates.contains(plaintextURL)
        else { return candidates }
        candidates.append(plaintextURL)
        return candidates
    }

    private func webSocketURL(baseURL: URL, apiSettings: HermesAPISettings) async throws -> URL {
        if baseURL.scheme?.lowercased() == "http",
           !HermesEndpointSecurity.isLoopbackHost(baseURL.host ?? "") {
            throw HermesTUIGatewayError.blockedPlaintext("Plaintext dashboard HTTP is blocked for remote TUI Gateway connections by iOS App Transport Security. Expose the dashboard through HTTPS/Tailscale Serve and retry.")
        }
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
        return String(html[tokenRange])
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

    func restoreMessages(from values: [JSONValue]) {
        let restored = values.compactMap { value -> HermesTUIGatewayMessage? in
            let object = value.objectValue
            let role = (object["role"]?.stringValue ?? "assistant").lowercased()
            let rawText = object["content"]?.stringValue ?? object["text"]?.stringValue ?? ""
            // Native-image history is flattened by the gateway for legacy clients.
            // Never turn that media sidecar back into a multi-MiB transcript string.
            let text = rawText.replacingOccurrences(
                of: #"data:[^\s;,]+;base64,[A-Za-z0-9+/=_-]+"#,
                with: "[Attached media]", options: [.regularExpression, .caseInsensitive])
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
    var onOpenMore: (() -> Void)? = nil

    private var selectedWorkspace: HermesTUIWorkspace {
        workspaces.first(where: { $0.id == selectedWorkspaceID }) ?? workspaces[0]
    }

    var body: some View {
        HermesTUIGatewayView(
            apiSettings: $apiSettings,
            dashboardURLString: dashboardURLString,
            workspace: selectedWorkspace,
            workspaceControls: workspaceControls,
            onOpenMore: onOpenMore
        )
        .id(selectedWorkspace.id)
    }

    private var workspaceControls: AnyView {
        AnyView(
            HStack(spacing: 8) {
                Button(action: onAddWorkspace) {
                    Image(systemName: "plus")
                        .font(.headline)
                        .frame(minWidth: 44, minHeight: 44)
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
            .frame(minWidth: 44, minHeight: 44)
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

/// One active panel prevents the two phone composer popovers competing.
struct HermesTUIPhoneComposerPresentation {
    enum Panel { case inference, actions }

    private(set) var activePanel: Panel?

    subscript(isPresented panel: Panel) -> Bool {
        get { activePanel == panel }
        set {
            if newValue {
                activePanel = panel
            } else if activePanel == panel {
                // A delayed dismissal of the previous panel must not close its replacement.
                activePanel = nil
            }
        }
    }
}

private struct HermesTUIPhoneComposerPopover<PanelContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    @ViewBuilder let panelContent: () -> PanelContent

    func body(content: Content) -> some View {
        // Both controls use the system's same anchored animation and tap-away dismissal.
        content.popover(isPresented: $isPresented, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            panelContent()
                .padding(16)
                .frame(width: 320, alignment: .leading)
                .presentationCompactAdaptation(.popover)
        }
    }
}

private struct HermesTUIGatewayView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var apiSettings: HermesAPISettings
    let dashboardURLString: String
    @Bindable var workspace: HermesTUIWorkspace
    let workspaceControls: AnyView
    var onOpenMore: (() -> Void)? = nil

    @State private var isImportingAttachment = false
    @State private var dashboardSkills = HermesDashboardSkillsStore()
    @State private var phoneComposerPresentation = HermesTUIPhoneComposerPresentation()
    @State private var isPhoneAttachmentImportPending = false
    @State private var isCompactPadComposerActionsExpanded = false
    @State private var phoneInference = HermesTUIPhoneInferenceDraft()
    @FocusState private var isPromptFocused: Bool

    private var store: HermesTUIGatewayStore { workspace.store }
    private var isPhoneLayout: Bool { horizontalSizeClass == .compact }
    private var usesPhoneComposerRail: Bool { UIDevice.current.userInterfaceIdiom == .phone }

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
        .onChange(of: store.isConnected) { _, isConnected in
            if isConnected { store.loadProfileOptions(into: workspace) }
        }
        .onChange(of: phoneComposerPresentation[isPresented: .inference]) { _, isPresented in
            if !isPresented { phoneInference.dismiss() }
        }
        .onDisappear { phoneInference.dismiss() }
        .fileImporter(isPresented: $isImportingAttachment, allowedContentTypes: HermesPromptAttachment.supportedContentTypes, allowsMultipleSelection: false) { result in
            handleAttachmentImport(result)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                if UIDevice.current.userInterfaceIdiom == .phone, let onOpenMore {
                    Button(action: onOpenMore) {
                        Label("More", systemImage: "ellipsis.circle")
                            .labelStyle(.iconOnly)
                            .font(.title2.weight(.bold))
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .hermesGlassButton()
                    .accessibilityLabel("More")
                    .accessibilityHint("Opens History, Web, Terminal, Utilities, Settings, and enabled Runtime settings.")
                    .accessibilityIdentifier("phone.more.open")
                    workspaceControls
                } else if isPhoneLayout {
                    Image(systemName: "terminal.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.igActionBlue)
                        .frame(width: 34, height: 34)
                        .accessibilityLabel("TUI Gateway")
                    workspaceControls
                } else {
                    HermesTabHeader("TUI Gateway", systemImage: "terminal.fill")
                    Spacer(minLength: 8)
                    workspaceControls
                }
                if store.isConnecting || store.isStreaming || store.isResumingSession || store.isRefreshingSessions {
                    ProgressView().controlSize(.small)
                }
                if isPhoneLayout { Spacer(minLength: 0) }
            }

            if isPhoneLayout {
                HStack(spacing: 8) { controls }
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ViewThatFits {
                    HStack(spacing: 10) { controls }
                    VStack(alignment: .leading, spacing: 10) { controls }
                }
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
        if isPhoneLayout {
            Button {
                store.disconnect()
                store.connect(dashboardBaseURL: dashboardURLString, apiSettings: apiSettings, inference: workspace.inference)
            } label: {
                phoneControlIcon(
                    store.isConnected ? "arrow.triangle.2.circlepath" : "antenna.radiowaves.left.and.right",
                    tint: .igActionBlue,
                    prominent: true
                )
            }
            .buttonStyle(.plain)
            .disabled(store.isConnecting)
            .accessibilityLabel(store.isConnected ? "Reconnect TUI Gateway" : "Connect TUI Gateway")

            Button { store.createSession(inference: workspace.inference) } label: {
                phoneControlIcon("plus.bubble")
            }
            .buttonStyle(.plain)
            .disabled(!store.isConnected || store.isStreaming || store.isResumingSession)
            .accessibilityLabel("New TUI Gateway session")

            Button { store.interruptSession() } label: {
                phoneControlIcon("stop.circle")
            }
            .buttonStyle(.plain)
            .disabled(!store.isStreaming)
            .accessibilityLabel("Interrupt TUI Gateway session")

            Button { store.closeSession() } label: {
                phoneControlIcon("checkmark.circle")
            }
            .buttonStyle(.plain)
            .disabled(!store.isConnected || store.sessionID.isEmpty)
            .accessibilityLabel("Done with TUI Gateway session")
        } else {
            Button(store.isConnected ? "Reconnect" : "Connect") {
                store.disconnect()
                store.connect(dashboardBaseURL: dashboardURLString, apiSettings: apiSettings, inference: workspace.inference)
            }
            .hermesGlassProminentButton()
            .disabled(store.isConnecting)

            Button("New session") { store.createSession(inference: workspace.inference) }
                .hermesGlassButton()
                .disabled(!store.isConnected || store.isStreaming || store.isResumingSession)

            Button("Interrupt") { store.interruptSession() }
                .hermesGlassButton()
                .disabled(!store.isStreaming)

            Button("Close") { store.closeSession() }
                .hermesGlassButton()
                .disabled(!store.isConnected || store.sessionID.isEmpty)
        }

        if isPhoneLayout {
            Menu {
                liveSessionsMenuContent
            } label: {
                phoneControlIcon("rectangle.stack.badge.person.crop")
            }
            .buttonStyle(.plain)
            .disabled(!store.isConnected)
            .accessibilityLabel("Live TUI Gateway sessions")
        } else {
            Menu {
                liveSessionsMenuContent
            } label: {
                Label("Live sessions", systemImage: "rectangle.stack.badge.person.crop")
            }
            .hermesGlassButton()
            .disabled(!store.isConnected)
            .accessibilityLabel("Live TUI Gateway sessions")
        }
    }

    @ViewBuilder
    private var liveSessionsMenuContent: some View {
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
    }

    private func phoneControlIcon(_ systemImage: String, tint: Color = .primary, prominent: Bool = false) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(prominent ? Color.white : tint)
            .frame(minWidth: 44, minHeight: 44)
            .background {
                Circle()
                    .fill(prominent ? Color.igActionBlue.opacity(0.92) : Color.hermesSurfaceInput.opacity(0.54))
            }
            .overlay {
                Circle()
                    .strokeBorder(Color.white.opacity(prominent ? 0.20 : 0.14), lineWidth: 1)
            }
            .hermesLiquidGlass(
                cornerRadius: 17,
                tint: prominent ? Color.igActionBlue.opacity(0.26) : Color.white.opacity(0.06),
                interactive: true
            )
            .contentShape(Circle())
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
            .tuiPhoneTranscriptTapToDismiss($isPromptFocused)
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

            if isPhoneLayout && !usesPhoneComposerRail {
                phoneInferenceButton
            } else if !usesPhoneComposerRail {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { inferenceControls }
                    VStack(alignment: .leading, spacing: 8) { inferenceControls }
                }
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
                        .tuiPhonePromptFocus($isPromptFocused)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: composerMinHeight, maxHeight: composerMaxHeight)
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

                if usesPhoneComposerRail {
                    VStack(spacing: 8) {
                        phoneInferenceButton
                        composerActions
                    }
                } else {
                    composerActions
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
    }

    private var phoneInferenceButton: some View {
        Button {
            phoneInference.open(workspace: workspace, load: store.modelOptions)
            phoneComposerPresentation[isPresented: .inference] = true
        } label: {
            phoneComposerTriggerIcon("slider.horizontal.3")
        }
        .hermesGlassButton()
        .disabled(!store.isConnected || store.isStreaming)
        .accessibilityLabel("Configure TUI Gateway inference")
        .accessibilityHint("Choose profile, model, reasoning effort, and inference speed")
        .modifier(HermesTUIPhoneComposerPopover(isPresented: $phoneComposerPresentation[isPresented: .inference]) {
            phoneInferencePopover
        })
    }

    private func phoneComposerTriggerIcon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.headline)
            .frame(width: 44, height: 44)
    }

    private var phoneInferencePopover: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Inference")
                    .font(.headline)
                Spacer()
                Button {
                    applyPhoneInferenceDraft()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.igActionBlue)
                .disabled(!phoneInference.canSave || !store.isConnected || store.isStreaming)
                .accessibilityLabel("Save inference settings")
            }

            VStack(alignment: .leading, spacing: 10) {
                phoneInferenceControls
            }
        }
    }

    @ViewBuilder
    private var phoneInferenceControls: some View {
        Menu {
            ForEach(profileOptions) { profile in
                Button(profile.displayName) { selectPhoneProfile(profile) }
            }
        } label: {
            inferenceControlLabel(title: "PROFILE", value: phoneSelectedProfile?.displayName ?? phoneInference.draft.profile)
        }
        .disabled(store.isStreaming || profileOptions.isEmpty)
        .accessibilityLabel("Choose Hermes profile")

        Menu {
            if phoneInference.modelOptions.isEmpty {
                Text(verbatim: "No models available")
            } else {
                ForEach(phoneModelProviderGroups, id: \.provider) { group in
                    Section(group.name) {
                        ForEach(group.options) { option in
                            Button(option.model) { selectPhoneModel(option) }
                        }
                    }
                }
            }
        } label: {
            inferenceControlLabel(title: "MODEL", value: phoneInference.modelLabel)
        }
        .disabled(store.isStreaming || phoneInference.isLoading || phoneInference.modelOptions.isEmpty)
        .accessibilityLabel("Choose Hermes Agent model")

        if phoneInference.isLoading {
            ProgressView("Loading models…")
                .font(.caption)
        } else if let errorMessage = phoneInference.errorMessage {
            Text(errorMessage)
                .font(.caption)
                .foregroundStyle(Color.igDestructive)
        }
        if !phoneInference.isLoading && (phoneInference.errorMessage != nil || phoneInference.modelOptions.isEmpty) {
            Button("Retry loading models") {
                phoneInference.reload(load: store.modelOptions)
            }
            .disabled(!store.isConnected || store.isStreaming)
        }

        if phoneSelectedModel?.supportsReasoning == true {
            Menu {
                ForEach(HermesTUIInferenceSelection.reasoningEfforts, id: \.self) { effort in
                    Button(reasoningLabel(for: effort)) { phoneInference.draft.reasoningEffort = effort }
                }
            } label: {
                inferenceControlLabel(title: "REASONING", value: reasoningLabel(for: phoneInference.draft.reasoningEffort))
            }
            .disabled(store.isStreaming)
            .accessibilityLabel("Choose model reasoning effort")
        }

        if phoneSelectedModel?.supportsFast == true {
            Menu {
                Button { phoneInference.draft.fast = false } label: { Text(verbatim: "Normal") }
                Button { phoneInference.draft.fast = true } label: { Text(verbatim: "Fast") }
            } label: {
                inferenceControlLabel(title: "SPEED", value: phoneInference.draft.fast ? "Fast" : "Normal")
            }
            .disabled(store.isStreaming)
            .accessibilityLabel("Choose model inference speed")
        }
    }

    @ViewBuilder
    private var inferenceControls: some View {
        Menu {
            ForEach(profileOptions) { profile in
                Button(profile.displayName) { store.selectProfile(profile, in: workspace) }
            }
        } label: {
            inferenceControlLabel(title: "PROFILE", value: selectedProfile?.displayName ?? workspace.inference.profile)
        }
        .disabled(!store.isConnected || store.isStreaming || profileOptions.isEmpty)
        .accessibilityLabel("Choose Hermes profile")

        Menu {
            if workspace.modelOptions.isEmpty {
                Text(verbatim: "No models available")
            } else {
                ForEach(modelProviderGroups, id: \.provider) { group in
                    Section(group.name) {
                        ForEach(group.options) { option in
                            Button(option.model) { selectModel(option) }
                        }
                    }
                }
            }
        } label: {
            inferenceControlLabel(title: "MODEL", value: selectedModel?.model ?? "Loading models…")
        }
        .disabled(!store.isConnected || store.isStreaming || workspace.modelOptions.isEmpty)
        .accessibilityLabel(Text(verbatim: "Choose Hermes Agent model"))

        if selectedModel?.supportsReasoning == true {
            Menu {
                ForEach(HermesTUIInferenceSelection.reasoningEfforts, id: \.self) { effort in
                    Button(reasoningLabel(for: effort)) { workspace.inference.reasoningEffort = effort }
                }
            } label: {
                inferenceControlLabel(title: "REASONING", value: reasoningLabel(for: workspace.inference.reasoningEffort))
            }
            .disabled(store.isStreaming)
            .accessibilityLabel("Choose model reasoning effort")
        }

        if selectedModel?.supportsFast == true {
            Menu {
                Button { workspace.inference.fast = false } label: { Text(verbatim: "Normal") }
                Button { workspace.inference.fast = true } label: { Text(verbatim: "Fast") }
            } label: {
                inferenceControlLabel(title: "SPEED", value: workspace.inference.fast ? "Fast" : "Normal")
            }
            .disabled(store.isStreaming)
            .accessibilityLabel(Text(verbatim: "Choose model inference speed"))
        }
    }

    private var selectedModel: HermesTUIModelOption? {
        workspace.modelOptions.first { $0.provider == workspace.inference.provider && $0.model == workspace.inference.model }
    }

    private var phoneSelectedModel: HermesTUIModelOption? {
        phoneInference.modelOptions.first { $0.provider == phoneInference.draft.provider && $0.model == phoneInference.draft.model }
    }

    private var selectedProfile: HermesTUIProfileOption? {
        profileOptions.first { $0.name == workspace.inference.profile }
    }

    private var phoneSelectedProfile: HermesTUIProfileOption? {
        profileOptions.first { $0.name == phoneInference.draft.profile }
    }

    private var profileOptions: [HermesTUIProfileOption] {
        workspace.profileOptions.isEmpty
            ? [HermesTUIProfileOption(name: "default", path: "", displayName: "default", provider: "", model: "")]
            : workspace.profileOptions
    }

    private var modelProviderGroups: [(provider: String, name: String, options: [HermesTUIModelOption])] {
        modelProviderGroups(for: workspace.modelOptions)
    }

    private var phoneModelProviderGroups: [(provider: String, name: String, options: [HermesTUIModelOption])] {
        modelProviderGroups(for: phoneInference.modelOptions)
    }

    private func modelProviderGroups(for options: [HermesTUIModelOption]) -> [(provider: String, name: String, options: [HermesTUIModelOption])] {
        Dictionary(grouping: options, by: \.provider)
            .compactMap { provider, options in
                guard let first = options.first else { return nil }
                return (provider, first.providerName, options.sorted { $0.model.localizedCaseInsensitiveCompare($1.model) == .orderedAscending })
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func inferenceControlLabel(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: title)
                .font(.hermesWebsiteLabel(size: 11))
                .tracking(0.7)
                .foregroundStyle(.hermesSecondaryText)
            HStack(spacing: 5) {
                Text(verbatim: value)
                    .font(.hermesWebsiteMono(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.hermesSecondaryText)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(minWidth: 112, alignment: .leading)
        .hermesLiquidGlass(cornerRadius: 14, tint: Color.igActionBlue.opacity(0.08), interactive: true)
    }

    private func selectPhoneProfile(_ profile: HermesTUIProfileOption) {
        if phoneInference.draft.profile == profile.name {
            phoneInference.reload(load: store.modelOptions)
        } else {
            phoneInference.selectProfile(profile, load: store.modelOptions)
        }
    }

    private func selectPhoneModel(_ option: HermesTUIModelOption) {
        phoneInference.selectModel(option)
    }

    private func applyPhoneInferenceDraft() {
        guard phoneInference.save() else { return }
        phoneComposerPresentation[isPresented: .inference] = false
    }

    private func selectModel(_ option: HermesTUIModelOption) {
        guard workspace.inference.provider != option.provider || workspace.inference.model != option.model else { return }
        workspace.inference.provider = option.provider
        workspace.inference.model = option.model
        if !option.supportsReasoning { workspace.inference.reasoningEffort = "none" }
        if !option.supportsFast { workspace.inference.fast = false }
        if store.isConnected && !store.isStreaming {
            store.createSession(inference: workspace.inference)
        }
    }

    private func reasoningLabel(for effort: String) -> String {
        effort == "none" ? "Off" : effort.capitalized
    }

    @ViewBuilder
    private var composerActions: some View {
        if usesPhoneComposerRail {
            Button {
                phoneComposerPresentation[isPresented: .actions] = true
            } label: {
                phoneComposerTriggerIcon("plus.circle.fill")
            }
            .hermesGlassButton()
            .disabled(!store.isConnected || store.isStreaming)
            .accessibilityLabel("Show TUI Gateway prompt actions")
            .modifier(HermesTUIPhoneComposerPopover(isPresented: $phoneComposerPresentation[isPresented: .actions]) {
                VStack(spacing: 8) {
                    attachButton(frame: 44)
                    sendButton(frame: 44)
                }
                .frame(maxWidth: .infinity)
                .onDisappear {
                    // Present Files only after the action popover relinquishes presentation.
                    if isPhoneAttachmentImportPending {
                        isPhoneAttachmentImportPending = false
                        isImportingAttachment = true
                    }
                }
            })
        } else if isPhoneLayout {
            // Keep the pre-existing narrow iPad layout; only iPhone adopts the rail.
            if isCompactPadComposerActionsExpanded {
                HStack(spacing: 8) {
                    attachButton(frame: 44)
                    sendButton(frame: 44)
                }
                .transition(.scale(scale: 0.82, anchor: .trailing).combined(with: .opacity))
            } else {
                Button {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                        isCompactPadComposerActionsExpanded = true
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.headline)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .hermesGlassProminentButton()
                .disabled(!store.isConnected || store.isStreaming)
                .accessibilityLabel("Show TUI Gateway prompt actions")
            }
        } else {
            VStack(spacing: 8) {
                attachButton(frame: 44)
                sendButton(frame: 44)
            }
        }
    }

    private func attachButton(frame: CGFloat) -> some View {
        Button {
            if usesPhoneComposerRail {
                isPhoneAttachmentImportPending = true
                phoneComposerPresentation[isPresented: .actions] = false
            } else {
                if isPhoneLayout {
                    withAnimation(.easeOut(duration: 0.16)) { isCompactPadComposerActionsExpanded = false }
                }
                isImportingAttachment = true
            }
        } label: {
            Image(systemName: workspace.selectedAttachment == nil ? "paperclip" : "paperclip.circle.fill")
                .font(.headline)
                .frame(width: frame, height: frame)
        }
        .hermesGlassButton()
        .disabled(!store.isConnected || store.isStreaming)
        .accessibilityLabel(workspace.selectedAttachment == nil ? "Attach file" : "Change attached file")
    }

    private func sendButton(frame: CGFloat) -> some View {
        Button {
            if usesPhoneComposerRail {
                phoneComposerPresentation[isPresented: .actions] = false
            } else if isPhoneLayout {
                withAnimation(.easeOut(duration: 0.16)) { isCompactPadComposerActionsExpanded = false }
            }
            submitPrompt()
        } label: {
            Image(systemName: "paperplane.fill")
                .font(.headline)
                .frame(width: frame, height: frame)
        }
        .hermesGlassProminentButton()
        .disabled(!store.canSendPrompt || (workspace.promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && workspace.selectedAttachment == nil))
        .accessibilityLabel("Send through TUI Gateway")
    }

    private var composerMinHeight: CGFloat {
        if dynamicTypeSize >= .accessibility1 { return isPhoneLayout ? 92 : 112 }
        return isPhoneLayout ? 60 : 78
    }

    private var composerMaxHeight: CGFloat {
        if dynamicTypeSize >= .accessibility1 { return isPhoneLayout ? 190 : 230 }
        return isPhoneLayout ? 120 : 160
    }

    private var activeSkillQuery: String? { workspace.promptText.hermesActiveSlashSkillQuery }

    private var filteredSkillSuggestions: [HermesDashboardSkill] {
        guard let query = activeSkillQuery else { return [] }
        if query.isEmpty { return dashboardSkills.skills }
        return dashboardSkills.skills.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    private var shouldShowSkillPicker: Bool {
        activeSkillQuery != nil
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
        store.submitPrompt(text, attachment: workspace.selectedAttachment, inference: workspace.inference)
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
                        .frame(minWidth: 44, minHeight: 44)
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
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove attachment")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.hermesSurfaceInput, in: Capsule())
    }
}
