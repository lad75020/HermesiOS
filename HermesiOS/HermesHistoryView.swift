//
//  HermesHistoryView.swift
//  HermesiOS
//

import Observation
import SwiftUI

struct HermesHistoryView: View {
    @Bindable var historyStore: HermesHistoryStore
    @Binding var apiSettings: HermesAPISettings

    @AppStorage("hermes.history.dashboardURL") private var dashboardURL = ""
    @State private var searchSession = HermesDashboardHistorySearchSession()
    @State private var expandedConversationIDs: Set<String> = []

    var body: some View {
        VStack(spacing: 0) {
            HermesTabHeader("History", systemImage: "clock.arrow.circlepath")
                .padding(.horizontal)
                .padding(.top)

            List {
                dashboardSearchSection

                if searchSession.hasActiveSearch {
                    dashboardSearchResultsSection
                } else {
                    localHistorySection
                }
            }
            .scrollContentBackground(.hidden)
        }
        .background(Color.hermesCanvas)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var dashboardSearchSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Search all Hermes conversations", text: $searchSession.query, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .lineLimit(1...3)
                    .submitLabel(.search)
                    .onSubmit(runDashboardSearch)
                    .hermesRuntimeInput()

                HStack(spacing: 10) {
                    Button(action: runDashboardSearch) {
                        Label(searchSession.isSearching ? "Searching…" : "Search", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(searchSession.isSearching || searchSession.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if searchSession.isSearching {
                        Button("Cancel") {
                            searchSession.cancel()
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    if searchSession.hasActiveSearch {
                        Button("Clear") {
                            searchSession.query = ""
                            searchSession.results = []
                            searchSession.status = "Idle"
                            searchSession.lastErrorMessage = ""
                            searchSession.matchedMessages = 0
                            searchSession.matchedSessions = 0
                            expandedConversationIDs.removeAll()
                        }
                        .buttonStyle(.bordered)
                    }
                }

                TextField("Dashboard URL, e.g. https://hermes-mac.example.ts.net", text: $dashboardURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .hermesRuntimeInput()

                VStack(alignment: .leading, spacing: 4) {
                    Text(searchSession.status)
                        .font(.caption)
                        .foregroundStyle(.hermesSecondaryText)

                    if searchSession.matchedMessages > 0 || searchSession.matchedSessions > 0 {
                        Text("\(searchSession.matchedMessages) matching messages across \(searchSession.matchedSessions) conversations")
                            .font(.caption2)
                            .foregroundStyle(.hermesSecondaryText)
                    }

                    if !searchSession.lastErrorMessage.isEmpty {
                        Text(searchSession.lastErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.igDestructive)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            Label("Full-text search", systemImage: "text.magnifyingglass")
        } footer: {
            Text("Searches the Mac dashboard server through the protected /api/sessions/search/conversations endpoint. Natural words and SQLite FTS-style queries are accepted; matching sessions are returned as full conversations.")
        }
    }

    private var dashboardSearchResultsSection: some View {
        Section {
            if searchSession.isSearching && searchSession.results.isEmpty {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("Searching conversations…")
                        .foregroundStyle(.hermesSecondaryText)
                }
                .padding(.vertical, 8)
            } else if searchSession.results.isEmpty {
                ContentUnavailableView(
                    "No Matching Conversations",
                    systemImage: "magnifyingglass",
                    description: Text("Try fewer words, a quoted phrase, or a broader FTS query.")
                )
            } else {
                ForEach(searchSession.results) { result in
                    HermesDashboardConversationDisclosure(
                        result: result,
                        isExpanded: bindingForConversation(result.id)
                    )
                }
            }
        } header: {
            Label("Search results", systemImage: "bubble.left.and.text.bubble.right")
        }
    }

    private var localHistorySection: some View {
        Group {
            if historyStore.sessions.isEmpty {
                ContentUnavailableView(
                    "No History Yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Completed Responses and Chat exchanges will be stored here by session ID. Use full-text search above to query the Mac dashboard history across all channels.")
                )
            } else {
                ForEach(historyStore.sessions) { session in
                    Section {
                        ForEach(session.exchanges) { exchange in
                            HermesHistoryExchangeCard(exchange: exchange)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        historyStore.deleteExchange(
                                            sessionID: session.id,
                                            kind: session.kind,
                                            exchangeID: exchange.id
                                        )
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label(session.kind.title, systemImage: session.kind == .responses ? "dot.radiowaves.left.and.right" : "text.bubble")
                                Spacer()
                                Button(role: .destructive) {
                                    historyStore.deleteSession(session.id, kind: session.kind)
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.plain)
                            }
                            Text("Session ID: \(session.id)")
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                            Text(session.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.hermesSecondaryText)
                        }
                    }
                }
            }
        }
    }

    private func runDashboardSearch() {
        expandedConversationIDs.removeAll()
        searchSession.search(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
    }

    private func bindingForConversation(_ id: String) -> Binding<Bool> {
        Binding(
            get: { expandedConversationIDs.contains(id) },
            set: { isExpanded in
                if isExpanded {
                    expandedConversationIDs.insert(id)
                } else {
                    expandedConversationIDs.remove(id)
                }
            }
        )
    }
}

private extension HermesDashboardHistorySearchSession {
    var hasActiveSearch: Bool {
        isSearching || !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !results.isEmpty || !lastErrorMessage.isEmpty
    }
}

private struct HermesDashboardConversationDisclosure: View {
    let result: HermesDashboardConversationResult
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                if !result.matches.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Matches")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.hermesSecondaryText)
                        ForEach(result.matches.prefix(3)) { match in
                            HermesDashboardMatchSnippet(match: match)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(result.messages) { message in
                        HermesDashboardConversationMessageRow(message: message)
                    }
                }
            }
            .padding(.top, 10)
        } label: {
            HermesDashboardConversationSummary(result: result)
        }
    }
}

private struct HermesDashboardConversationSummary: View {
    let result: HermesDashboardConversationResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label(result.session.displayTitle, systemImage: result.session.sourceIconName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Text("\(result.matches.count) hit\(result.matches.count == 1 ? "" : "s")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.igActionBlue)
            }

            HStack(spacing: 8) {
                Text(result.session.source?.uppercased() ?? "HERMES")
                if let model = result.session.model, !model.isEmpty {
                    Text(model)
                }
                Text("\(result.messages.count) messages")
            }
            .font(.caption)
            .foregroundStyle(.hermesSecondaryText)
            .lineLimit(1)

            if let startedAt = result.session.startedAtDate {
                Text(startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.hermesSecondaryText)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct HermesDashboardMatchSnippet: View {
    let match: HermesDashboardMessageMatch

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(match.role?.capitalized ?? "Message")
                    .font(.caption2.weight(.semibold))
                if let timestamp = match.timestampDate {
                    Text(timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                }
            }
            .foregroundStyle(.hermesSecondaryText)

            Text(match.displaySnippet)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .textSelection(.enabled)
        }
        .padding(10)
        .background(Color.hermesSurfaceInput, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct HermesDashboardConversationMessageRow: View {
    let message: HermesDashboardConversationMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(message.role.capitalized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(roleColor)
                if let timestamp = message.timestampDate {
                    Text(timestamp.formatted(date: .omitted, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.hermesSecondaryText)
                }
                if let toolName = message.toolName, !toolName.isEmpty {
                    Text(toolName)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.hermesSecondaryText)
                }
            }

            Text(message.content.isEmpty ? "—" : message.content)
                .font(.callout)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hermesSurfaceInput.opacity(0.65), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var roleColor: Color {
        switch message.role.lowercased() {
        case "user":
            .igActionBlue
        case "assistant":
            .igOnlineGreen
        case "tool":
            .igGradOrange
        default:
            .hermesSecondaryText
        }
    }
}

private extension HermesDashboardSessionInfo {
    var displayTitle: String {
        if let title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return title
        }
        return id
    }

    var startedAtDate: Date? {
        guard let startedAt else { return nil }
        return Date(timeIntervalSince1970: startedAt)
    }

    var sourceIconName: String {
        switch source?.lowercased() {
        case "telegram", "whatsapp", "signal", "discord", "slack", "matrix":
            "message"
        case "cli":
            "terminal"
        case "cron":
            "calendar.badge.clock"
        case "api", "api_server":
            "network"
        default:
            "bubble.left.and.text.bubble.right"
        }
    }
}

private extension HermesDashboardMessageMatch {
    var timestampDate: Date? {
        guard let timestamp else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }

    var displaySnippet: String {
        let raw = snippet ?? ""
        return raw
            .replacingOccurrences(of: "<mark>", with: "")
            .replacingOccurrences(of: "</mark>", with: "")
            .replacingOccurrences(of: "<b>", with: "")
            .replacingOccurrences(of: "</b>", with: "")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}

private extension HermesDashboardConversationMessage {
    var timestampDate: Date? {
        guard let timestamp else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }
}
