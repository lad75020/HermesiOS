//
//  HermesCommandCenterView.swift
//  HermesiOS
//

import Foundation
import Observation
import SwiftUI

struct HermesCommandCenterRunStatus: Identifiable, Decodable, Equatable {
    let runID: String
    var status: String
    var createdAt: Double?
    var updatedAt: Double?
    var sessionID: String?
    var model: String?
    var lastEvent: String?
    var error: String?
    var output: String?
    var usage: HermesCommandCenterUsage?

    var id: String { runID }

    enum CodingKeys: String, CodingKey {
        case runID = "run_id"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case sessionID = "session_id"
        case model
        case lastEvent = "last_event"
        case error
        case output
        case usage
    }

    var isActive: Bool {
        let normalized = status.lowercased()
        return normalized == "queued" || normalized == "running" || normalized == "waiting_for_approval" || normalized == "stopping"
    }

    var elapsedSeconds: Int {
        let start = createdAt ?? updatedAt ?? Date().timeIntervalSince1970
        let end = isActive ? Date().timeIntervalSince1970 : (updatedAt ?? Date().timeIntervalSince1970)
        return max(0, Int(end - start))
    }

    var displayStatus: String {
        switch status.lowercased() {
        case "waiting_for_approval": "Waiting for approval"
        default: status.split(separator: "_").map { $0.capitalized }.joined(separator: " ")
        }
    }

    var displayTask: String {
        let candidates = [sessionID, output, error, lastEvent, model]
        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
            .map(Self.compactText) ?? runID
    }

    var tokenCostText: String {
        guard let usage else { return "Tokens pending • Cost —" }
        let tokens = usage.totalTokens.map { "\($0) tokens" } ?? "Tokens —"
        let cost = usage.costText ?? "Cost —"
        return "\(tokens) • \(cost)"
    }

    static func placeholder(runID: String, status: String = "queued") -> HermesCommandCenterRunStatus {
        HermesCommandCenterRunStatus(
            runID: runID,
            status: status,
            createdAt: Date().timeIntervalSince1970,
            updatedAt: Date().timeIntervalSince1970,
            sessionID: nil,
            model: nil,
            lastEvent: nil,
            error: nil,
            output: nil,
            usage: nil
        )
    }

    nonisolated private static func compactText(_ value: String) -> String {
        let normalized = value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
        guard normalized.count > 96 else { return normalized }
        return String(normalized.prefix(93)) + "…"
    }
}

struct HermesCommandCenterUsage: Decodable, Equatable {
    var inputTokens: Int?
    var outputTokens: Int?
    var totalTokens: Int?
    var cost: Double?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case promptTokens = "prompt_tokens"
        case outputTokens = "output_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
        case cost
        case estimatedCost = "estimated_cost"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        inputTokens = try container.decodeFlexibleIntIfPresent(forKey: .inputTokens) ?? container.decodeFlexibleIntIfPresent(forKey: .promptTokens)
        outputTokens = try container.decodeFlexibleIntIfPresent(forKey: .outputTokens) ?? container.decodeFlexibleIntIfPresent(forKey: .completionTokens)
        totalTokens = try container.decodeFlexibleIntIfPresent(forKey: .totalTokens)
        cost = try container.decodeFlexibleDoubleIfPresent(forKey: .cost) ?? container.decodeFlexibleDoubleIfPresent(forKey: .estimatedCost)
    }

    var costText: String? {
        guard let cost else { return nil }
        return cost <= 0 ? "$0.00" : cost.formatted(.currency(code: "USD").precision(.fractionLength(4)))
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleIntIfPresent(forKey key: Key) throws -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return value }
        if let double = try? decodeIfPresent(Double.self, forKey: key) { return Int(double) }
        if let string = try? decodeIfPresent(String.self, forKey: key) { return Int(string.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }

    func decodeFlexibleDoubleIfPresent(forKey key: Key) throws -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) { return value }
        if let int = try? decodeIfPresent(Int.self, forKey: key) { return Double(int) }
        if let string = try? decodeIfPresent(String.self, forKey: key) { return Double(string.trimmingCharacters(in: .whitespacesAndNewlines)) }
        return nil
    }
}

struct HermesCommandCenterRunStartResponse: Decodable {
    let runID: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case runID = "run_id"
        case status
    }
}

struct HermesCommandCenterHealthResponse: Decodable {
    let gatewayState: String?
    let activeAgents: Int?
    let updatedAt: String?

    enum CodingKeys: String, CodingKey {
        case gatewayState = "gateway_state"
        case activeAgents = "active_agents"
        case updatedAt = "updated_at"
    }
}

struct HermesRunActivityEvent: Identifiable, Equatable {
    let id = UUID()
    let runID: String
    let name: String
    let timestamp: Double
    let tool: String?
    let preview: String?
    let detail: String?
    let isError: Bool

    var displayTitle: String {
        if let tool, !tool.isEmpty { return tool }
        return name.split(separator: ".").map { $0.capitalized }.joined(separator: " ")
    }

    var displayDetail: String {
        let value = [preview, detail]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? name
        guard value.count > 120 else { return value }
        return String(value.prefix(117)) + "…"
    }
}

@MainActor
@Observable
final class HermesCommandCenterStore {
    var trackedRuns: [HermesCommandCenterRunStatus] = []
    var eventsByRunID: [String: [HermesRunActivityEvent]] = [:]
    var gatewayState = "Unknown"
    var activeAgentsCount = 0
    var status = "Ready"
    var lastErrorMessage = ""
    var lastUpdated: Date?
    var isRefreshing = false
    var isStartingRun = false
    var commandInput = ""
    var selectedControlCommand = "/steer"

    private var streamTasks: [String: Task<Void, Never>] = [:]

    var activeTrackedRunsCount: Int {
        trackedRuns.filter(\.isActive).count
    }

    var recentEvents: [HermesRunActivityEvent] {
        eventsByRunID.values.flatMap { $0 }.sorted { $0.timestamp > $1.timestamp }.prefix(8).map { $0 }
    }

    func runStatusLoop(apiSettings: HermesAPISettings) async {
        await refresh(apiSettings: apiSettings)
        while !Task.isCancelled {
            do { try await Task.sleep(for: .seconds(3)) } catch { break }
            if Task.isCancelled { break }
            await refresh(apiSettings: apiSettings)
        }
    }

    func refresh(apiSettings: HermesAPISettings) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            async let health = fetchHealth(apiSettings: apiSettings)
            let statuses = await fetchTrackedRunStatuses(apiSettings: apiSettings)
            if let health = try await health {
                gatewayState = health.gatewayState?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? health.gatewayState! : "Online"
                activeAgentsCount = health.activeAgents ?? 0
            }
            for status in statuses {
                upsert(status)
            }
            lastUpdated = Date()
            status = "Command center refreshed"
            lastErrorMessage = ""
        } catch {
            lastErrorMessage = error.localizedDescription
            status = "Refresh failed"
        }
    }

    func startBackgroundRun(apiSettings: HermesAPISettings, input: String) async {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            status = "Enter a task, /queue, /steer, /goal, or /subgoal command."
            return
        }
        guard !isStartingRun else { return }
        isStartingRun = true
        status = "Starting background run"
        lastErrorMessage = ""
        defer { isStartingRun = false }

        do {
            guard let url = HermesAPISettings.runsURL(from: apiSettings.baseURL) else { throw HermesResponsesError.invalidURL }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 45
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if apiSettings.hasAuthorizationToken {
                try HermesEndpointSecurity.validateSensitiveURL(url)
                request.setHermesAuthorization(from: apiSettings)
            }
            request.httpBody = try JSONEncoder().encode(["input": trimmed])

            let session = HermesNetworkSessionFactory.session(for: apiSettings)
            let (data, response) = try await session.data(for: request)
            try HermesNetworkSessionFactory.validate(response: response)
            let startResponse = try JSONDecoder().decode(HermesCommandCenterRunStartResponse.self, from: data)
            let run = HermesCommandCenterRunStatus.placeholder(runID: startResponse.runID, status: startResponse.status)
            upsert(run)
            streamEvents(for: startResponse.runID, apiSettings: apiSettings)
            commandInput = ""
            status = "Run started"
            lastUpdated = Date()
        } catch {
            lastErrorMessage = error.localizedDescription
            status = "Run start failed"
        }
    }

    func submitControlInput(apiSettings: HermesAPISettings) async {
        let trimmed = commandInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let command = selectedControlCommand.trimmingCharacters(in: .whitespacesAndNewlines)

        if command == "/agents" {
            await refresh(apiSettings: apiSettings)
            return
        }

        if command == "/stop" {
            if let run = trackedRuns.first(where: { $0.runID == trimmed && $0.isActive })
                ?? (trimmed.isEmpty ? trackedRuns.first(where: \.isActive) : nil) {
                await stopRun(run, apiSettings: apiSettings)
            } else if !trimmed.isEmpty {
                await cancelRequest(apiSettings: apiSettings, requestID: trimmed)
            } else {
                status = "No active run to stop. Enter a run_id or X-Hermes-Request-Id."
            }
            return
        }

        let input: String
        if command == "/background" {
            input = trimmed
        } else {
            input = [command, trimmed].filter { !$0.isEmpty }.joined(separator: " ")
        }
        await startBackgroundRun(apiSettings: apiSettings, input: input)
    }

    func cancelRequest(apiSettings: HermesAPISettings, requestID: String) async {
        let trimmed = requestID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            guard let url = HermesAPISettings.requestCancelURL(from: apiSettings.baseURL, requestID: trimmed) else { throw HermesResponsesError.invalidURL }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 30
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            if apiSettings.hasAuthorizationToken {
                try HermesEndpointSecurity.validateSensitiveURL(url)
                request.setHermesAuthorization(from: apiSettings)
            }
            let session = HermesNetworkSessionFactory.session(for: apiSettings)
            let (_, response) = try await session.data(for: request)
            try HermesNetworkSessionFactory.validate(response: response)
            status = "Request cancellation sent"
            commandInput = ""
        } catch {
            lastErrorMessage = error.localizedDescription
            status = "Request cancel failed"
        }
    }

    func stopRun(_ run: HermesCommandCenterRunStatus, apiSettings: HermesAPISettings) async {
        guard run.isActive else { return }
        do {
            guard let url = HermesAPISettings.runStopURL(from: apiSettings.baseURL, runID: run.runID) else { throw HermesResponsesError.invalidURL }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 30
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            if apiSettings.hasAuthorizationToken {
                try HermesEndpointSecurity.validateSensitiveURL(url)
                request.setHermesAuthorization(from: apiSettings)
            }
            let session = HermesNetworkSessionFactory.session(for: apiSettings)
            let (_, response) = try await session.data(for: request)
            try HermesNetworkSessionFactory.validate(response: response)
            if let index = trackedRuns.firstIndex(where: { $0.runID == run.runID }) {
                trackedRuns[index].status = "stopping"
                trackedRuns[index].lastEvent = "run.stopping"
                trackedRuns[index].updatedAt = Date().timeIntervalSince1970
            }
            status = "Stop requested"
        } catch {
            lastErrorMessage = error.localizedDescription
            status = "Stop failed"
        }
    }

    func cancelAllEventStreams() {
        streamTasks.values.forEach { $0.cancel() }
        streamTasks.removeAll()
    }

    private func fetchHealth(apiSettings: HermesAPISettings) async throws -> HermesCommandCenterHealthResponse? {
        guard let url = HermesAPISettings.healthDetailedURL(from: apiSettings.baseURL) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if apiSettings.hasAuthorizationToken {
            try HermesEndpointSecurity.validateSensitiveURL(url)
            request.setHermesAuthorization(from: apiSettings)
        }
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (data, response) = try await session.data(for: request)
        try HermesNetworkSessionFactory.validate(response: response)
        return try JSONDecoder().decode(HermesCommandCenterHealthResponse.self, from: data)
    }

    private func fetchTrackedRunStatuses(apiSettings: HermesAPISettings) async -> [HermesCommandCenterRunStatus] {
        var statuses: [HermesCommandCenterRunStatus] = []
        for run in trackedRuns where run.isActive || run.updatedAt == nil {
            do {
                guard let url = HermesAPISettings.runStatusURL(from: apiSettings.baseURL, runID: run.runID) else { continue }
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.timeoutInterval = 20
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                if apiSettings.hasAuthorizationToken {
                    try HermesEndpointSecurity.validateSensitiveURL(url)
                    request.setHermesAuthorization(from: apiSettings)
                }
                let session = HermesNetworkSessionFactory.session(for: apiSettings)
                let (data, response) = try await session.data(for: request)
                try HermesNetworkSessionFactory.validate(response: response)
                statuses.append(try JSONDecoder().decode(HermesCommandCenterRunStatus.self, from: data))
            } catch {
                if let index = trackedRuns.firstIndex(where: { $0.runID == run.runID }) {
                    trackedRuns[index].lastEvent = "status.unavailable"
                    trackedRuns[index].updatedAt = Date().timeIntervalSince1970
                }
            }
        }
        return statuses
    }

    private func streamEvents(for runID: String, apiSettings: HermesAPISettings) {
        streamTasks[runID]?.cancel()
        streamTasks[runID] = Task { [weak self] in
            guard let self else { return }
            await self.consumeRunEvents(runID: runID, apiSettings: apiSettings)
        }
    }

    private func consumeRunEvents(runID: String, apiSettings: HermesAPISettings) async {
        do {
            guard let url = HermesAPISettings.runEventsURL(from: apiSettings.baseURL, runID: runID) else { throw HermesResponsesError.invalidURL }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 300
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            if apiSettings.hasAuthorizationToken {
                try HermesEndpointSecurity.validateSensitiveURL(url)
                request.setHermesAuthorization(from: apiSettings)
            }
            let session = HermesNetworkSessionFactory.session(for: apiSettings)
            let (bytes, response) = try await session.bytes(for: request)
            try HermesNetworkSessionFactory.validate(response: response)

            for try await line in bytes.lines {
                if Task.isCancelled { break }
                guard line.hasPrefix("data:") else { continue }
                let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
                guard !payload.isEmpty else { continue }
                ingestEventPayload(payload, runID: runID)
            }
        } catch {
            if !Task.isCancelled {
                lastErrorMessage = error.localizedDescription
                status = "Event stream failed"
            }
        }
        streamTasks.removeValue(forKey: runID)
    }

    private func ingestEventPayload(_ payload: String, runID: String) {
        guard let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        let eventName = object["event"] as? String ?? "event"
        let event = HermesRunActivityEvent(
            runID: runID,
            name: eventName,
            timestamp: (object["timestamp"] as? Double) ?? Date().timeIntervalSince1970,
            tool: object["tool"] as? String,
            preview: object["preview"] as? String,
            detail: (object["error"] as? String) ?? (object["output"] as? String) ?? (object["delta"] as? String),
            isError: (object["error"] as? Bool) ?? (object["error"] is String)
        )
        var events = eventsByRunID[runID] ?? []
        events.insert(event, at: 0)
        eventsByRunID[runID] = Array(events.prefix(20))

        if let index = trackedRuns.firstIndex(where: { $0.runID == runID }) {
            trackedRuns[index].lastEvent = eventName
            trackedRuns[index].updatedAt = Date().timeIntervalSince1970
            if eventName == "run.completed" { trackedRuns[index].status = "completed" }
            if eventName == "run.failed" { trackedRuns[index].status = "failed" }
            if eventName == "run.cancelled" { trackedRuns[index].status = "cancelled" }
        }
    }

    private func upsert(_ run: HermesCommandCenterRunStatus) {
        if let index = trackedRuns.firstIndex(where: { $0.runID == run.runID }) {
            trackedRuns[index] = run
        } else {
            trackedRuns.insert(run, at: 0)
        }
        trackedRuns.sort { lhs, rhs in
            (lhs.updatedAt ?? lhs.createdAt ?? 0) > (rhs.updatedAt ?? rhs.createdAt ?? 0)
        }
        trackedRuns = Array(trackedRuns.prefix(12))
    }
}

struct HermesCommandCenterPanel: View {
    @Bindable var store: HermesCommandCenterStore
    let apiSettings: HermesAPISettings
    @Bindable var responseSession: HermesResponsesSession
    @Bindable var chatSession: HermesChatSession

    private let controlCommands = ["/steer", "/queue", "/goal", "/subgoal", "/background", "/agents", "/stop"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HermesStatusRow(items: [
                HermesStatusItem(title: "Gateway", value: store.gatewayState, accent: gatewayAccent),
                HermesStatusItem(title: "Agents", value: "\(store.activeAgentsCount + foregroundRows.count) active", accent: .igActionBlue),
                HermesStatusItem(title: "Tracked runs", value: "\(store.activeTrackedRunsCount) running", accent: .igOnlineGreen)
            ])

            controlComposer

            if !foregroundRows.isEmpty {
                commandCenterGroupTitle("Foreground sessions")
                VStack(spacing: 12) {
                    ForEach(foregroundRows) { row in
                        HermesForegroundRunCard(row: row) {
                            switch row.kind {
                            case .responses: responseSession.cancel()
                            case .chat: chatSession.cancel()
                            }
                        }
                    }
                }
            }

            commandCenterGroupTitle("API background runs")
            if store.trackedRuns.isEmpty {
                emptyState
            } else {
                VStack(spacing: 12) {
                    ForEach(store.trackedRuns) { run in
                        HermesAPIRunCard(
                            run: run,
                            events: store.eventsByRunID[run.runID] ?? [],
                            onStop: { Task { await store.stopRun(run, apiSettings: apiSettings) } }
                        )
                    }
                }
            }

            if !store.recentEvents.isEmpty {
                commandCenterGroupTitle("Recent tool activity")
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(store.recentEvents) { event in
                        HermesRunActivityRow(event: event)
                    }
                }
            }

            if !store.lastErrorMessage.isEmpty {
                Label(store.lastErrorMessage, systemImage: "exclamationmark.triangle")
                    .font(.igSecondaryMeta)
                    .foregroundStyle(.igDestructive)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let lastUpdated = store.lastUpdated {
                Text("Last refreshed \(lastUpdated.formatted(date: .omitted, time: .standard)) • \(store.status)")
                    .font(.igSecondaryMeta)
                    .foregroundStyle(.hermesSecondaryText)
            } else {
                Text(store.status)
                    .font(.igSecondaryMeta)
                    .foregroundStyle(.hermesSecondaryText)
            }
        }
    }

    private var gatewayAccent: Color {
        store.gatewayState.lowercased().contains("error") || store.gatewayState.lowercased().contains("failed") ? .igDestructive : .igOnlineGreen
    }

    private var foregroundRows: [HermesForegroundRunRow] {
        var rows: [HermesForegroundRunRow] = []
        if responseSession.isSending || responseSession.isStreaming {
            rows.append(HermesForegroundRunRow(
                kind: .responses,
                title: "Responses foreground agent",
                task: responseSession.displaySessionTitle,
                status: responseSession.connectionStatus,
                elapsedSeconds: responseSession.activeResponseElapsedSeconds ?? 0,
                eventCount: responseSession.eventCount
            ))
        }
        if chatSession.isSending || chatSession.isStreaming {
            rows.append(HermesForegroundRunRow(
                kind: .chat,
                title: "Chat foreground agent",
                task: chatSession.displaySessionTitle,
                status: chatSession.connectionStatus,
                elapsedSeconds: chatSession.activeResponseElapsedSeconds ?? 0,
                eventCount: chatSession.eventCount
            ))
        }
        return rows
    }

    private var controlComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Picker("Command", selection: $store.selectedControlCommand) {
                    ForEach(controlCommands, id: \.self) { command in
                        Text(command).tag(command)
                    }
                }
                .pickerStyle(.menu)
                .frame(minWidth: 124)

                TextField("Queue/steer input or background task", text: $store.commandInput, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
            }

            HStack(spacing: 10) {
                Button {
                    Task { await store.submitControlInput(apiSettings: apiSettings) }
                } label: {
                    Label(store.selectedControlCommand == "/background" ? "Start run" : "Send command", systemImage: "paperplane")
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.isStartingRun)

                Button {
                    Task { await store.refresh(apiSettings: apiSettings) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(store.isRefreshing)

                if store.isStartingRun || store.isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Text("Use /background to start API runs. /stop stops the newest tracked run or cancels an entered run_id / X-Hermes-Request-Id; /agents refreshes runtime state; /steer, /queue, /goal and /subgoal preserve the Hermes gateway command vocabulary for queued control input.")
                .font(.igSecondaryMeta)
                .foregroundStyle(.hermesSecondaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hermesLiquidGlass(cornerRadius: 16, tint: .igActionBlue.opacity(0.07), interactive: false)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No API runs tracked yet")
                .font(.igUsername)
                .foregroundStyle(.primary)
            Text("Start a /background task above, or keep this panel open while foreground Responses and Chat sessions run.")
                .font(.igSecondaryMeta)
                .foregroundStyle(.hermesSecondaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hermesLiquidGlass(cornerRadius: 16, tint: .white.opacity(0.03), interactive: false)
    }

    private func commandCenterGroupTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.hermesWebsiteSectionTitle(size: 11))
            .tracking(1.2)
            .foregroundStyle(.hermesSecondaryText)
    }
}

private enum HermesForegroundRunKind {
    case responses
    case chat
}

private struct HermesForegroundRunRow: Identifiable {
    var id: String { title }
    let kind: HermesForegroundRunKind
    let title: String
    let task: String
    let status: String
    let elapsedSeconds: Int
    let eventCount: Int
}

private struct HermesForegroundRunCard: View {
    let row: HermesForegroundRunRow
    let onCancel: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: row.kind == .responses ? "dot.radiowaves.left.and.right" : "text.bubble")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.igActionBlue)
                .frame(width: 34, height: 34)
                .hermesLiquidGlass(cornerRadius: 11, tint: .igActionBlue.opacity(0.16), interactive: true)

            VStack(alignment: .leading, spacing: 6) {
                Text(row.title)
                    .font(.igUsername)
                Text(row.task)
                    .font(.igSecondaryMeta)
                    .foregroundStyle(.hermesSecondaryText)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    HermesMiniMetric(label: "Status", value: row.status)
                    HermesMiniMetric(label: "Elapsed", value: HermesCommandCenterTime.format(row.elapsedSeconds))
                    HermesMiniMetric(label: "Tool activity", value: "\(row.eventCount) events")
                    HermesMiniMetric(label: "Token/cost", value: "Pending / —")
                }
            }

            Spacer(minLength: 0)

            Button(role: .destructive, action: onCancel) {
                Label("Cancel", systemImage: "stop.circle")
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hermesLiquidGlass(cornerRadius: 16, tint: .igActionBlue.opacity(0.06), interactive: false)
    }
}

private struct HermesAPIRunCard: View {
    let run: HermesCommandCenterRunStatus
    let events: [HermesRunActivityEvent]
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: run.isActive ? "play.circle.fill" : "checkmark.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(run.isActive ? .igOnlineGreen : .hermesSecondaryText)
                    .frame(width: 34, height: 34)
                    .hermesLiquidGlass(cornerRadius: 11, tint: (run.isActive ? Color.igOnlineGreen : Color.white).opacity(0.14), interactive: true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(run.runID)
                        .font(.hermesWebsiteMono(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(run.displayTask)
                        .font(.igSecondaryMeta)
                        .foregroundStyle(.hermesSecondaryText)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        HermesMiniMetric(label: "Status", value: run.displayStatus)
                        HermesMiniMetric(label: "Elapsed", value: HermesCommandCenterTime.format(run.elapsedSeconds))
                        HermesMiniMetric(label: "Activity", value: run.lastEvent ?? "Waiting")
                        HermesMiniMetric(label: "Token/cost", value: run.tokenCostText)
                    }
                }

                Spacer(minLength: 0)

                if run.isActive {
                    Button(role: .destructive, action: onStop) {
                        Label("Stop", systemImage: "stop.circle")
                    }
                    .buttonStyle(.bordered)
                }
            }

            if !events.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(events.prefix(3)) { event in
                        HermesRunActivityRow(event: event)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hermesLiquidGlass(cornerRadius: 16, tint: run.isActive ? Color.igOnlineGreen.opacity(0.06) : Color.white.opacity(0.03), interactive: false)
    }
}

private struct HermesRunActivityRow: View {
    let event: HermesRunActivityEvent

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: event.isError ? "exclamationmark.triangle" : "hammer")
                .foregroundStyle(event.isError ? .igDestructive : .igActionBlue)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.displayTitle)
                    .font(.igSecondaryMeta.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(event.displayDetail)
                    .font(.igSecondaryMeta)
                    .foregroundStyle(.hermesSecondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

private struct HermesMiniMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.hermesWebsiteLabel(size: 9))
                .tracking(0.7)
                .foregroundStyle(.hermesSecondaryText)
            Text(value)
                .font(.hermesWebsiteMono(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .hermesLiquidGlass(cornerRadius: 10, tint: .white.opacity(0.03), interactive: false)
    }
}

private enum HermesCommandCenterTime {
    static func format(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m \(seconds % 60)s" }
        return "\(seconds / 3600)h \((seconds % 3600) / 60)m"
    }
}
