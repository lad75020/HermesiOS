//
//  ContentView.swift
//  HermesiOS
//
//  Created by Laurent Dubertrand on 04/05/2026.
//

import Observation
import SwiftUI

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedWorkspace: WorkspaceSection? = .responses
    @State private var apiSettings: HermesAPISettings
    @State private var agentConfiguration = HermesAgentConfiguration()
    @State private var responsesDraft: HermesRequestDraft
    @State private var responseSession = HermesResponsesSession()
    @State private var chatDraft: HermesChatDraft
    @State private var chatSession = HermesChatSession()
    @State private var historyStore = HermesHistoryStore()

    init() {
        _apiSettings = State(initialValue: HermesSettingsPersistence.loadAPISettings())
        _responsesDraft = State(initialValue: HermesSettingsPersistence.loadResponsesDraft())
        _chatDraft = State(initialValue: HermesSettingsPersistence.loadChatDraft())
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                iPhoneLayout
            } else {
                iPadLayout
            }
        }
        .background(Color(.systemGroupedBackground))
        .onChange(of: apiSettings) { _, newValue in
            HermesSettingsPersistence.saveAPISettings(newValue)
        }
        .onChange(of: responsesDraft) { _, newValue in
            HermesSettingsPersistence.saveResponsesDraft(newValue)
        }
        .onChange(of: chatDraft) { _, newValue in
            HermesSettingsPersistence.saveChatDraft(newValue)
        }
    }

    private var iPadLayout: some View {
        NavigationSplitView {
            WorkspaceSidebar(selection: $selectedWorkspace)
                .navigationTitle("Hermes")
                .navigationSplitViewColumnWidth(min: 260, ideal: 280, max: 320)
        } detail: {
            workspaceDetail(for: selectedWorkspace ?? .responses)
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var iPhoneLayout: some View {
        TabView {
            NavigationStack {
                HermesResponsesConsoleView(
                    apiSettings: $apiSettings,
                    requestDraft: $responsesDraft,
                    responseSession: responseSession,
                    historyStore: historyStore
                )
            }
            .tabItem {
                Label("Responses", systemImage: "dot.radiowaves.left.and.right")
            }

            NavigationStack {
                HermesChatConsoleView(
                    apiSettings: $apiSettings,
                    chatDraft: $chatDraft,
                    chatSession: chatSession,
                    historyStore: historyStore
                )
            }
            .tabItem {
                Label("Chat", systemImage: "text.bubble")
            }

            NavigationStack {
                HermesHistoryView(historyStore: historyStore)
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }

            NavigationStack {
                HermesSettingsView(
                    apiSettings: $apiSettings,
                    responsesDraft: $responsesDraft,
                    chatDraft: $chatDraft
                )
            }
            .tabItem {
                Label("Settings", systemImage: "slider.horizontal.3")
            }

            NavigationStack {
                HermesAgentConfigView(agentConfiguration: $agentConfiguration)
            }
            .tabItem {
                Label("Runtime", systemImage: "server.rack")
            }
        }
    }

    @ViewBuilder
    private func workspaceDetail(for section: WorkspaceSection) -> some View {
        switch section {
        case .responses:
            HermesResponsesConsoleView(
                apiSettings: $apiSettings,
                requestDraft: $responsesDraft,
                responseSession: responseSession,
                historyStore: historyStore
            )
        case .chat:
            HermesChatConsoleView(
                apiSettings: $apiSettings,
                chatDraft: $chatDraft,
                chatSession: chatSession,
                historyStore: historyStore
            )
        case .history:
            HermesHistoryView(historyStore: historyStore)
        case .settings:
            HermesSettingsView(
                apiSettings: $apiSettings,
                responsesDraft: $responsesDraft,
                chatDraft: $chatDraft
            )
        case .runtime:
            HermesAgentConfigView(agentConfiguration: $agentConfiguration)
        }
    }
}

private enum WorkspaceSection: String, CaseIterable, Identifiable {
    case responses
    case chat
    case history
    case settings
    case runtime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .responses:
            "Responses API"
        case .chat:
            "Chat Completions"
        case .history:
            "History"
        case .settings:
            "Settings"
        case .runtime:
            "Agent Runtime"
        }
    }

    var subtitle: String {
        switch self {
        case .responses:
            "Use `/v1/responses` with SSE and response chaining."
        case .chat:
            "Use `/v1/chat/completions` with an independent transcript."
        case .history:
            "Review saved requests and final responses grouped by session."
        case .settings:
            "Configure gateway, prompts, models, and streaming behavior."
        case .runtime:
            "Model local and SSH-backed agent environments."
        }
    }

    var systemImage: String {
        switch self {
        case .responses:
            "dot.radiowaves.left.and.right"
        case .chat:
            "text.bubble"
        case .history:
            "clock.arrow.circlepath"
        case .settings:
            "slider.horizontal.3"
        case .runtime:
            "server.rack"
        }
    }
}

private struct WorkspaceSidebar: View {
    @Binding var selection: WorkspaceSection?

    var body: some View {
        List(WorkspaceSection.allCases, selection: $selection) { section in
            NavigationLink(value: section) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(section.title, systemImage: section.systemImage)
                        .font(.headline)
                    Text(section.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.sidebar)
    }
}

private struct HermesResponsesConsoleView: View {
    @Binding var apiSettings: HermesAPISettings
    @Binding var requestDraft: HermesRequestDraft
    @Bindable var responseSession: HermesResponsesSession
    @Bindable var historyStore: HermesHistoryStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HermesHeroCard(
                    title: "Hermes Gateway API",
                    detail: "This first implementation targets `/v1/responses` and uses SSE so the app can render incremental output and tool events as Hermes works.",
                    systemImage: "bolt.horizontal.circle.fill"
                )

                HermesStatusRow(
                    items: [
                        .init(title: "Thread", value: responseSession.previousResponseID.isEmpty ? "New response" : "Continuing thread", accent: .purple),
                        .init(title: "Status", value: responseSession.connectionStatus, accent: .orange)
                    ]
                )

                HermesSectionCard("Request Draft") {
                    VStack(alignment: .leading, spacing: 14) {
                        if !responseSession.previousResponseID.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Next request resumes a stored Hermes thread.", systemImage: "arrow.triangle.branch")
                                    .font(.caption.weight(.semibold))
                                Text(responseSession.previousResponseID)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        TextEditor(text: $requestDraft.userPrompt)
                            .frame(minHeight: 160)
                            .overlay(alignment: .topLeading) {
                                if requestDraft.userPrompt.isEmpty {
                                    Text("Ask Hermes to inspect files, run tools, or explain context...")
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 8)
                                        .allowsHitTesting(false)
                                }
                            }

                        HStack {
                            Label("Send a prompt and inspect Hermes events", systemImage: "waveform.path.ecg")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Spacer()

                            if !responseSession.previousResponseID.isEmpty && !responseSession.isSending {
                                Button("New Thread") {
                                    responseSession.resetConversation()
                                }
                                .buttonStyle(.bordered)
                            }

                            if responseSession.isSending {
                                Button("Cancel") {
                                    responseSession.cancel()
                                }
                                .buttonStyle(.bordered)
                            }

                            Button("Send Request") {
                                responseSession.submit(apiSettings: apiSettings, draft: requestDraft, historyStore: historyStore)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(requestDraft.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }

                HermesSectionCard("Assistant Output") {
                    VStack(alignment: .leading, spacing: 12) {
                        if !responseSession.previousResponseID.isEmpty {
                            Label("Continuing from: \(responseSession.previousResponseID)", systemImage: "link")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if !responseSession.latestResponseID.isEmpty {
                            Label("Response ID: \(responseSession.latestResponseID)", systemImage: "number")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if !responseSession.lastErrorMessage.isEmpty {
                            Text(responseSession.lastErrorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }

                        Group {
                            if responseSession.streamedText.isEmpty {
                                Text("Send a `/v1/responses` request to populate streamed assistant output here.")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(responseSession.streamedText)
                                    .textSelection(.enabled)
                            }
                        }
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                HermesSectionCard("Event Timeline") {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("\(responseSession.eventCount) events received", systemImage: "timeline.selection")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if responseSession.entries.isEmpty {
                            Text("The SSE event stream will appear here, including `response.created`, text deltas, tool events, and completion.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(responseSession.entries) { response in
                                    HermesResponseCard(response: response)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Responses API")
    }
}

private struct HermesChatConsoleView: View {
    @Binding var apiSettings: HermesAPISettings
    @Binding var chatDraft: HermesChatDraft
    @Bindable var chatSession: HermesChatSession
    @Bindable var historyStore: HermesHistoryStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HermesHeroCard(
                    title: "Hermes Chat Completions",
                    detail: "This surface uses `/v1/chat/completions` independently from the Responses API, with its own transcript and streaming lifecycle.",
                    systemImage: "text.bubble.fill"
                )

                HermesStatusRow(
                    items: [
                        .init(title: "History", value: "\(chatSession.entries.count) messages", accent: .purple),
                        .init(title: "Status", value: chatSession.connectionStatus, accent: .orange)
                    ]
                )

                HermesSectionCard("Message Draft") {
                    VStack(alignment: .leading, spacing: 14) {
                        TextEditor(text: $chatDraft.userPrompt)
                            .frame(minHeight: 160)
                            .overlay(alignment: .topLeading) {
                                if chatDraft.userPrompt.isEmpty {
                                    Text("Send a message to Hermes using the chat completions format...")
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 8)
                                        .allowsHitTesting(false)
                                }
                            }

                        HStack {
                            Label("Chat transcript stays separate from `/v1/responses`", systemImage: "rectangle.split.3x1")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Spacer()

                            if !chatSession.entries.isEmpty && !chatSession.isSending {
                                Button("New Chat") {
                                    chatSession.resetConversation()
                                }
                                .buttonStyle(.bordered)
                            }

                            if chatSession.isSending {
                                Button("Cancel") {
                                    chatSession.cancel()
                                }
                                .buttonStyle(.bordered)
                            }

                            Button("Send Message") {
                                chatSession.submit(apiSettings: apiSettings, draft: chatDraft, historyStore: historyStore)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(chatDraft.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }

                HermesSectionCard("Assistant Output") {
                    VStack(alignment: .leading, spacing: 12) {
                        if !chatSession.lastErrorMessage.isEmpty {
                            Text(chatSession.lastErrorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }

                        Group {
                            if chatSession.streamedText.isEmpty {
                                Text("Send a `/v1/chat/completions` message to populate assistant output here.")
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(chatSession.streamedText)
                                    .textSelection(.enabled)
                            }
                        }
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                HermesSectionCard("Transcript") {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("\(chatSession.eventCount) stream events received", systemImage: "timeline.selection")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if chatSession.entries.isEmpty {
                            Text("User and assistant messages from the chat completions session will accumulate here.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(chatSession.entries) { message in
                                    HermesChatMessageCard(message: message)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Chat Completions")
    }
}

private struct HermesSettingsView: View {
    @Binding var apiSettings: HermesAPISettings
    @Binding var responsesDraft: HermesRequestDraft
    @Binding var chatDraft: HermesChatDraft

    var body: some View {
        Form {
            Section("Gateway") {
                TextField("Base URL", text: $apiSettings.baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Bearer token", text: $apiSettings.apiKey)

                Toggle("Allow self-signed HTTPS certificates", isOn: $apiSettings.allowSelfSignedCertificates)

                settingsRow(label: "Responses URL", value: HermesAPISettings.responseURL(from: apiSettings.baseURL)?.absoluteString ?? "Invalid URL")
                settingsRow(label: "Chat URL", value: HermesAPISettings.chatCompletionsURL(from: apiSettings.baseURL)?.absoluteString ?? "Invalid URL")
            }

            Section("/v1/responses") {
                TextField("Model", text: $responsesDraft.model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Toggle("Streaming enabled", isOn: $responsesDraft.stream)

                TextField("Instructions", text: $responsesDraft.instructions, axis: .vertical)
                    .lineLimit(4, reservesSpace: true)
            }

            Section("/v1/chat/completions") {
                TextField("Model", text: $chatDraft.model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Toggle("Streaming enabled", isOn: $chatDraft.stream)

                TextField("System prompt", text: $chatDraft.systemPrompt, axis: .vertical)
                    .lineLimit(4, reservesSpace: true)
            }

            Section("Notes") {
                Text("Responses and Chat screens are now limited to message exchange and output.")
                Text("Use this screen for endpoint, auth, model, streaming, and prompt configuration.")
                Text("Keep self-signed certificate support off unless you trust the Hermes API server.")
            }
            .foregroundStyle(.secondary)
        }
        .navigationTitle("Settings")
    }

    private func settingsRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .fontWeight(.semibold)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}

private struct HermesHistoryView: View {
    @Bindable var historyStore: HermesHistoryStore

    var body: some View {
        List {
            if historyStore.sessions.isEmpty {
                ContentUnavailableView(
                    "No History Yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Completed Responses and Chat exchanges will be stored here by session ID.")
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
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
    }
}

private struct HermesAgentConfigView: View {
    @Binding var agentConfiguration: HermesAgentConfiguration

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HermesHeroCard(
                    title: "Agent Runtime",
                    detail: "This area is structured as an accordion so one operational panel can stay expanded while the others collapse into quick section headers.",
                    systemImage: "server.rack"
                )

                HermesRuntimeAccordionPanel(
                    title: "Skills",
                    subtitle: "\(agentConfiguration.installedSkills.count) installed, \(agentConfiguration.filteredCatalogSkills.count) visible in catalog",
                    systemImage: "square.stack.3d.up.fill",
                    isExpanded: Binding(
                        get: { agentConfiguration.activeRuntimePanel == .skills },
                        set: { isExpanded in
                            agentConfiguration.activeRuntimePanel = isExpanded ? .skills : nil
                        }
                    )
                ) {
                    HermesSkillsPanel(agentConfiguration: $agentConfiguration)
                }

                HermesRuntimeAccordionPanel(
                    title: "Backend",
                    subtitle: agentConfiguration.backend.displayName,
                    systemImage: agentConfiguration.backend.systemImage,
                    isExpanded: Binding(
                        get: { agentConfiguration.activeRuntimePanel == .backend },
                        set: { isExpanded in
                            agentConfiguration.activeRuntimePanel = isExpanded ? .backend : nil
                        }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("Terminal backend", selection: $agentConfiguration.backend) {
                            ForEach(HermesTerminalBackend.allCases) { backend in
                                Text(backend.displayName).tag(backend)
                            }
                        }

                        Toggle("Persistent shell", isOn: $agentConfiguration.persistentShell)

                        TextField("Working directory", text: $agentConfiguration.workingDirectory)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                }

                HermesRuntimeAccordionPanel(
                    title: "SSH",
                    subtitle: agentConfiguration.backend == .ssh ? "Remote host configuration" : "Hidden while local backend is active",
                    systemImage: "network.badge.shield.half.filled",
                    isExpanded: Binding(
                        get: { agentConfiguration.activeRuntimePanel == .ssh },
                        set: { isExpanded in
                            agentConfiguration.activeRuntimePanel = isExpanded ? .ssh : nil
                        }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        TextField("Host", text: $agentConfiguration.sshHost)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("User", text: $agentConfiguration.sshUser)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Port", text: $agentConfiguration.sshPort)
                            .keyboardType(.numberPad)
                        TextField("Private key path", text: $agentConfiguration.sshKeyPath)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .opacity(agentConfiguration.backend == .ssh ? 1 : 0.45)
                }

                ForEach(HermesRuntimePanel.placeholderPanels) { panel in
                    HermesRuntimeAccordionPanel(
                        title: panel.title,
                        subtitle: panel.subtitle,
                        systemImage: panel.systemImage,
                        isExpanded: Binding(
                            get: { agentConfiguration.activeRuntimePanel == panel.kind },
                            set: { isExpanded in
                                agentConfiguration.activeRuntimePanel = isExpanded ? panel.kind : nil
                            }
                        )
                    ) {
                        Text(panel.placeholder)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Agent Runtime")
    }
}

private struct HermesSkillsPanel: View {
    @Binding var agentConfiguration: HermesAgentConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Picker("Source", selection: $agentConfiguration.skillsLibraryMode) {
                ForEach(HermesSkillsLibraryMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if agentConfiguration.skillsLibraryMode == .browse {
                TextField("Search skills", text: $agentConfiguration.skillSearchQuery)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            let visibleSkills = agentConfiguration.visibleSkills
            if visibleSkills.isEmpty {
                ContentUnavailableView(
                    "No Skills Found",
                    systemImage: "magnifyingglass",
                    description: Text(agentConfiguration.skillsLibraryMode == .installed ? "Install a bundled skill to populate this panel." : "Adjust the search query to find another skill.")
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(visibleSkills) { skill in
                        Button {
                            agentConfiguration.selectedSkillID = skill.id
                        } label: {
                            HermesSkillRow(skill: skill, isSelected: agentConfiguration.selectedSkillID == skill.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let selectedSkill = agentConfiguration.selectedSkill {
                HermesSectionCard("Skill Details") {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(selectedSkill.name)
                                    .font(.headline)
                                Text(selectedSkill.category)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(selectedSkill.isInstalled ? "Installed" : selectedSkill.source.capitalized)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background((selectedSkill.isInstalled ? Color.green : Color.orange).opacity(0.12))
                                .clipShape(Capsule())
                        }

                        Text(selectedSkill.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if let path = selectedSkill.path {
                            Text(path)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }

                        ScrollView {
                            Text(selectedSkill.detail)
                                .font(.caption.monospaced())
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                        }
                        .frame(minHeight: 180, maxHeight: 240)
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        HStack {
                            Spacer()
                            if selectedSkill.isInstalled {
                                Button("Uninstall Skill") {
                                    agentConfiguration.uninstallSkill(selectedSkill.id)
                                }
                                .buttonStyle(.bordered)
                            } else {
                                Button("Install Skill") {
                                    agentConfiguration.installSelectedSkill()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct HermesRuntimeAccordionPanel<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: systemImage)
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                    VStack(alignment: .leading, spacing: 16) {
                        content
                    }
                    .padding(20)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct HermesSkillRow: View {
    let skill: HermesSkillDescriptor
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(skill.name)
                    .font(.headline)
                Spacer()
                Text(skill.isInstalled ? "Installed" : skill.source.capitalized)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background((skill.isInstalled ? Color.green : Color.orange).opacity(0.12))
                    .clipShape(Capsule())
            }

            Text(skill.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(skill.category)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.blue.opacity(0.08) : Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct HermesHeroCard: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color.blue.opacity(0.9), Color.cyan.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.largeTitle)
                Text(title)
                    .font(.title2.bold())
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .foregroundStyle(.white)
            .padding(24)
        }
        .frame(maxWidth: .infinity, minHeight: 180)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .blue.opacity(0.18), radius: 16, y: 10)
    }
}

private struct HermesSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct HermesStatusRow: View {
    let items: [HermesStatusItem]

    var body: some View {
        ViewThatFits {
            HStack(spacing: 12) {
                ForEach(items) { item in
                    HermesStatusPill(item: item)
                }
            }

            VStack(spacing: 12) {
                ForEach(items) { item in
                    HermesStatusPill(item: item)
                }
            }
        }
    }
}

private struct HermesStatusPill: View {
    let item: HermesStatusItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(item.accent)
            Text(item.value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(item.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct HermesResponseCard: View {
    let response: HermesResponseEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(response.title)
                    .font(.headline)
                Spacer()
                Text(response.status)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text(response.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(response.metadata, id: \.self) { line in
                Label(line, systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var statusColor: Color {
        switch response.status.lowercased() {
        case "failed":
            .red
        case "streaming", "update":
            .blue
        case "done", "completed":
            .green
        default:
            .orange
        }
    }
}

private struct HermesChatMessageCard: View {
    let message: HermesChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(message.role.capitalized)
                    .font(.headline)
                Spacer()
                Text(message.role == "user" ? "Prompt" : "Reply")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(roleColor.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text(message.content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var roleColor: Color {
        message.role == "user" ? .blue : .green
    }
}

private struct HermesHistoryExchangeCard: View {
    let exchange: HermesHistoryExchange

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(exchange.completedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Request")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(exchange.requestText)
                    .font(.subheadline)
                    .textSelection(.enabled)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Final Response")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(exchange.responseText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct HermesStatusItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let accent: Color
}

private enum HermesTerminalBackend: String, CaseIterable, Identifiable {
    case local
    case ssh

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .local:
            "Local"
        case .ssh:
            "SSH"
        }
    }

    var systemImage: String {
        switch self {
        case .local:
            "laptopcomputer"
        case .ssh:
            "network.badge.shield.half.filled"
        }
    }
}

private enum HermesRuntimePanelKind: String, Identifiable {
    case skills
    case backend
    case ssh
    case profiles
    case permissions
    case tools
    case models
    case sandbox
    case memory
    case observability

    var id: String { rawValue }
}

private struct HermesRuntimePanel: Identifiable {
    let kind: HermesRuntimePanelKind
    let title: String
    let subtitle: String
    let systemImage: String
    let placeholder: String

    var id: HermesRuntimePanelKind { kind }

    static let placeholderPanels: [HermesRuntimePanel] = [
        .init(kind: .profiles, title: "Profiles", subtitle: "Switch between runtime profiles and targets", systemImage: "person.crop.rectangle.stack", placeholder: "Profile routing, per-target overrides, and environment inheritance will live here."),
        .init(kind: .permissions, title: "Permissions", subtitle: "Approval policy and privileged operations", systemImage: "checkmark.shield", placeholder: "Approval policy, escalations, and audit-friendly permission controls can expand here."),
        .init(kind: .tools, title: "Tools", subtitle: "Enable and scope MCP servers and terminal tools", systemImage: "wrench.and.screwdriver", placeholder: "MCP server selection, shell tool policies, and tool-scoped access rules can be configured in this panel."),
        .init(kind: .models, title: "Models", subtitle: "Default model and routing behavior", systemImage: "cpu", placeholder: "Model defaults, failover routing, and provider-specific options can be surfaced in this panel."),
        .init(kind: .sandbox, title: "Sandbox", subtitle: "Filesystem and network boundaries", systemImage: "lock.square.stack", placeholder: "Workspace-write, read-only, and network isolation controls can be configured here."),
        .init(kind: .memory, title: "Memory", subtitle: "Persistent context and workspace notes", systemImage: "brain.head.profile", placeholder: "Persistent notes, workspace memory, and user-level memory toggles fit naturally in this section."),
        .init(kind: .observability, title: "Observability", subtitle: "Logs, traces, and runtime diagnostics", systemImage: "waveform.and.magnifyingglass", placeholder: "Runtime logs, traces, and environment diagnostics can be collected and displayed here.")
    ]
}

private enum HermesSkillsLibraryMode: String, CaseIterable, Identifiable {
    case installed
    case browse

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .installed:
            "Installed"
        case .browse:
            "Browse"
        }
    }
}

private struct HermesSkillDescriptor: Identifiable, Equatable {
    let id: String
    let name: String
    let category: String
    let description: String
    let detail: String
    let source: String
    let path: String?
    var isInstalled: Bool
}

private struct HermesAgentConfiguration {
    var backend: HermesTerminalBackend = .local
    var persistentShell = true
    var workingDirectory = "."
    var sshHost = ""
    var sshUser = ""
    var sshPort = "22"
    var sshKeyPath = "~/.ssh/id_rsa"
    var activeRuntimePanel: HermesRuntimePanelKind? = .skills
    var skillsLibraryMode: HermesSkillsLibraryMode = .installed
    var skillSearchQuery = ""
    var selectedSkillID: String? = "aidesigner-frontend"
    var installedSkillIDs: Set<String> = ["aidesigner-frontend", "skill-installer"]

    var backendSummary: String {
        switch backend {
        case .local:
            "Commands execute directly on the device host running Hermes. This is the fastest path for initial gateway integration."
        case .ssh:
            "Commands execute on a remote server over SSH with a persistent shell, which is the right fit once the app starts managing remote agents."
        }
    }

    var skillCatalog: [HermesSkillDescriptor] {
        HermesSkillCatalog.seed.map { skill in
            var copy = skill
            copy.isInstalled = installedSkillIDs.contains(skill.id)
            return copy
        }
    }

    var installedSkills: [HermesSkillDescriptor] {
        skillCatalog.filter(\.isInstalled)
    }

    var filteredCatalogSkills: [HermesSkillDescriptor] {
        let query = skillSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return skillCatalog }
        return skillCatalog.filter { skill in
            skill.name.localizedCaseInsensitiveContains(query) ||
            skill.category.localizedCaseInsensitiveContains(query) ||
            skill.description.localizedCaseInsensitiveContains(query)
        }
    }

    var visibleSkills: [HermesSkillDescriptor] {
        switch skillsLibraryMode {
        case .installed:
            installedSkills
        case .browse:
            filteredCatalogSkills
        }
    }

    var selectedSkill: HermesSkillDescriptor? {
        if let selectedSkillID {
            return skillCatalog.first(where: { $0.id == selectedSkillID })
        }
        return visibleSkills.first
    }

    mutating func installSelectedSkill() {
        guard let selectedSkill else { return }
        installedSkillIDs.insert(selectedSkill.id)
        selectedSkillID = selectedSkill.id
        skillsLibraryMode = .installed
    }

    mutating func uninstallSkill(_ skillID: String) {
        installedSkillIDs.remove(skillID)
        if selectedSkillID == skillID {
            selectedSkillID = installedSkills.first?.id ?? filteredCatalogSkills.first?.id
        }
    }
}

private enum HermesSkillCatalog {
    static let seed: [HermesSkillDescriptor] = [
        HermesSkillDescriptor(
            id: "aidesigner-frontend",
            name: "aidesigner-frontend",
            category: "design",
            description: "Use AIDesigner to generate or refine frontend directions, capture artifacts, and port them into the repo UI.",
            detail: """
            ---
            name: "aidesigner-frontend"
            description: "Create or redesign frontend surfaces with AIDesigner, then adopt them into the repo."
            ---

            Workflow:
            1. Inspect the repo and infer the existing visual system.
            2. Generate or refine an AIDesigner artifact.
            3. Capture the artifact locally for preview and adoption.
            4. Port the visual system into the real app code instead of shipping raw HTML.
            """,
            source: "bundled",
            path: "~/.agents/skills/aidesigner-frontend",
            isInstalled: false
        ),
        HermesSkillDescriptor(
            id: "openai-playwright",
            name: "openai-playwright",
            category: "automation",
            description: "Automate a real browser from the terminal for navigation, form fill, screenshots, and UI-flow debugging.",
            detail: """
            # openai-playwright

            Use this skill when a task requires browser automation from the terminal, including snapshots, screenshots, data extraction, or reproducing interactive UI bugs.
            """,
            source: "bundled",
            path: "~/.agents/skills/openai-playwright",
            isInstalled: false
        ),
        HermesSkillDescriptor(
            id: "skill-installer",
            name: "skill-installer",
            category: "system",
            description: "Install Codex skills from a curated list or a GitHub repo path into the active profile.",
            detail: """
            # skill-installer

            Mirrors the desktop skills install flow:
            - list curated skills
            - install a skill into $CODEX_HOME/skills
            - install from a repo path, including private repos
            """,
            source: "bundled",
            path: "~/Library/Developer/Xcode/CodingAssistant/codex/skills/.system/skill-installer",
            isInstalled: false
        ),
        HermesSkillDescriptor(
            id: "skill-creator",
            name: "skill-creator",
            category: "system",
            description: "Guide for creating or updating specialized skills that extend the coding agent.",
            detail: """
            # skill-creator

            Use this when the user wants to create a new skill or update an existing skill with specialized knowledge, workflow, or tool integration.
            """,
            source: "bundled",
            path: "~/Library/Developer/Xcode/CodingAssistant/codex/skills/.system/skill-creator",
            isInstalled: false
        ),
        HermesSkillDescriptor(
            id: "deploy-model",
            name: "deploy-model",
            category: "microsoft-foundry",
            description: "Unified Azure OpenAI model deployment flow with routing between preset, customize, and capacity discovery.",
            detail: """
            # deploy-model

            Handles quick preset deployments, customized deployments, and capacity discovery across regions and projects.
            """,
            source: "bundled",
            path: "~/.agents/skills/microsoft-foundry/models/deploy-model",
            isInstalled: false
        )
    ]
}

#Preview("Default") {
    ContentView()
}
