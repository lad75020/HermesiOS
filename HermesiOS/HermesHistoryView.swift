//
//  HermesHistoryView.swift
//  HermesiOS
//

import Observation
import SwiftUI

struct HermesHistoryView: View {
    @Binding var apiSettings: HermesAPISettings
    @Bindable var searchSession: HermesDashboardHistorySearchSession
    let isResponsesStreaming: Bool
    let isChatStreaming: Bool
    let onResumeResponses: (HermesDashboardConversationResult) -> Void
    let onResumeChat: (HermesDashboardConversationResult) -> Void

    @AppStorage(hermesMacHostStorageKey) private var macHost = defaultHermesMacHost
    @AppStorage(hermesDashboardPortStorageKey) private var dashboardPort = defaultHermesDashboardPort
    @State private var expandedConversationIDs: Set<String> = []
    @State private var apiProfiles: [HermesAPIProfile] = []
    @State private var selectedProfileFilter = "all"

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
                    ContentUnavailableView(
                        "Search Hermes History",
                        systemImage: "text.magnifyingglass",
                        description: Text("Search the Mac dashboard history to query conversations across all Hermes channels.")
                    )
                }
            }
            .scrollContentBackground(.hidden)
        }
        .background(HermesLiquidGlassCanvas().ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task(id: apiSettings.baseURL) {
            await refreshProfileOptions()
        }
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
                    HStack(spacing: 6) {
                        Text("Profile")
                            .font(.subheadline)
                            .foregroundStyle(.primary)

                        Picker("Profile", selection: $selectedProfileFilter) {
                            ForEach(profileFilterOptions, id: \.value) { option in
                                Text(option.title).tag(option.value)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .controlSize(.small)
                        .disabled(searchSession.isSearching)
                    }
                    .fixedSize()
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("History profile filter")

                    Button(action: runDashboardSearch) {
                        Label(searchSession.isSearching ? "Searching…" : "Search", systemImage: "magnifyingglass")
                    }
                    .hermesGlassProminentButton()
                    .disabled(searchSession.isSearching || searchSession.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if searchSession.isSearching {
                        Button("Cancel") {
                            searchSession.cancel()
                        }
                        .hermesGlassButton()
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
                        .hermesGlassButton()
                    }
                }

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
                        isExpanded: bindingForConversation(result.id),
                        isResumeResponsesDisabled: isResponsesStreaming,
                        isResumeChatDisabled: isChatStreaming,
                        onResumeResponses: onResumeResponses,
                        onResumeChat: onResumeChat
                    )
                }
            }
        } header: {
            Label("Search results", systemImage: "bubble.left.and.text.bubble.right")
        }
    }


    private func runDashboardSearch() {
        expandedConversationIDs.removeAll()
        let limit = selectedProfileFilter == "all" ? 25 : 100
        searchSession.search(dashboardBaseURL: dashboardURL, apiSettings: apiSettings, profileFilter: selectedProfileFilter, limit: limit)
    }

    private var dashboardURL: String {
        HermesHostEndpoints.httpURLString(host: macHost, port: dashboardPort)
    }

    private var profileFilterOptions: [HermesHistoryProfileFilterOption] {
        var seen = Set(["all", "default"])
        var options: [HermesHistoryProfileFilterOption] = [
            HermesHistoryProfileFilterOption(title: "All", value: "all"),
            HermesHistoryProfileFilterOption(title: "Default", value: "default")
        ]

        let namedProfiles = apiProfiles
            .filter { !$0.isDefault }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        for profile in namedProfiles {
            let value = profile.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            let key = value.lowercased()
            guard !seen.contains(key) else { continue }
            let title = profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? value : profile.name
            options.append(HermesHistoryProfileFilterOption(title: title, value: value))
            seen.insert(key)
        }

        return options
    }

    private func refreshProfileOptions() async {
        do {
            apiProfiles = try await HermesAPIProfilesClient.fetchProfiles(apiSettings: apiSettings)
            let available = Set(profileFilterOptions.map { $0.value.lowercased() })
            if !available.contains(selectedProfileFilter.lowercased()) {
                selectedProfileFilter = "all"
            }
        } catch {
            apiProfiles = []
            if selectedProfileFilter != "all" && selectedProfileFilter != "default" {
                selectedProfileFilter = "all"
            }
        }
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

private struct HermesHistoryProfileFilterOption: Hashable {
    let title: String
    let value: String
}

private extension HermesDashboardHistorySearchSession {
    var hasActiveSearch: Bool {
        isSearching || !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !results.isEmpty || !lastErrorMessage.isEmpty
    }
}

private struct HermesDashboardConversationDisclosure: View {
    let result: HermesDashboardConversationResult
    @Binding var isExpanded: Bool
    let isResumeResponsesDisabled: Bool
    let isResumeChatDisabled: Bool
    let onResumeResponses: (HermesDashboardConversationResult) -> Void
    let onResumeChat: (HermesDashboardConversationResult) -> Void

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Button {
                        onResumeResponses(result)
                    } label: {
                        Label("Resume in Responses", systemImage: "arrow.uturn.forward.circle")
                    }
                    .hermesGlassProminentButton()
                    .tint(.igActionBlue)
                    .help(isResumeResponsesDisabled ? "All Ask Hermes screens are streaming; tapping shows a busy message" : "Resume this conversation in Ask Hermes")

                    Button {
                        onResumeChat(result)
                    } label: {
                        Label("Resume in Chat", systemImage: "text.bubble")
                    }
                    .hermesGlassButton()
                    .disabled(isResumeChatDisabled)
                    .help(isResumeChatDisabled ? "Chat with Hermes is streaming a response" : "Resume this conversation in Chat with Hermes")
                }

                ForEach(result.displayMessages) { message in
                    HermesDashboardConversationMessageRow(message: message)
                }
            }
            .padding(.top, 10)
        } label: {
            HStack(alignment: .center, spacing: 12) {
                HermesDashboardConversationSummary(result: result)

                Spacer(minLength: 8)

                Menu {
                    Button {
                        onResumeResponses(result)
                    } label: {
                        Label("Resume in Responses", systemImage: "arrow.uturn.forward.circle")
                    }

                    Button {
                        onResumeChat(result)
                    } label: {
                        Label("Resume in Chat", systemImage: "text.bubble")
                    }
                    .disabled(isResumeChatDisabled)
                } label: {
                    Label("Resume", systemImage: "arrow.uturn.forward")
                        .labelStyle(.titleAndIcon)
                }
                .hermesGlassButton()
                .controlSize(.small)
            }
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
                Text("\(result.displayMessages.count) shown")
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
                Text(displayRoleTitle)
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

    private var displayRoleTitle: String {
        switch message.role.lowercased() {
        case "user":
            "Initial prompt"
        case "assistant":
            "Final response"
        default:
            message.role.capitalized
        }
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

private extension HermesDashboardConversationResult {
    var displayMessages: [HermesDashboardConversationMessage] {
        let nonEmptyMessages = messages.filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let initialUserPrompt = nonEmptyMessages.first { $0.role.lowercased() == "user" }
        let finalAgentResponse = nonEmptyMessages.last { $0.role.lowercased() == "assistant" }

        switch (initialUserPrompt, finalAgentResponse) {
        case let (user?, assistant?) where user.id != assistant.id:
            return [user, assistant]
        case let (user?, nil):
            return [user]
        case let (nil, assistant?):
            return [assistant]
        case let (user?, assistant?):
            return [user, assistant]
        case (nil, nil):
            return []
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
