//
//  ContentView.swift
//  HermesiOS
//
//  Instagram-inspired UI. Visual layer follows DESIGN.md.
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
        .background(Color.hermesCanvas.ignoresSafeArea())
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
        .tint(.igActionBlue)
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
            .tabItem { Image(systemName: "bolt.horizontal.circle") }

            NavigationStack {
                HermesChatConsoleView(
                    apiSettings: $apiSettings,
                    chatDraft: $chatDraft,
                    chatSession: chatSession,
                    historyStore: historyStore
                )
            }
            .tabItem { Image(systemName: "paperplane") }

            NavigationStack {
                HermesHistoryView(historyStore: historyStore)
            }
            .tabItem { Image(systemName: "clock.arrow.circlepath") }

            NavigationStack {
                HermesAgentConfigView(agentConfiguration: $agentConfiguration)
            }
            .tabItem { Image(systemName: "square.stack.3d.up") }

            NavigationStack {
                HermesSettingsView(
                    apiSettings: $apiSettings,
                    responsesDraft: $responsesDraft,
                    chatDraft: $chatDraft
                )
            }
            .tabItem { Image(systemName: "person.circle") }
        }
        .tint(.primary)
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

// MARK: - Workspace section enum

private enum WorkspaceSection: String, CaseIterable, Identifiable {
    case responses, chat, history, settings, runtime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .responses: "Responses"
        case .chat:      "Direct Messages"
        case .history:   "Activity"
        case .settings:  "Profile"
        case .runtime:   "Runtime"
        }
    }

    var subtitle: String {
        switch self {
        case .responses: "Streaming `/v1/responses` with SSE and chained replies."
        case .chat:      "`/v1/chat/completions` with an independent transcript."
        case .history:   "Saved sessions and final exchanges."
        case .settings:  "Gateway, prompts, models, streaming."
        case .runtime:   "Skills, backends, and agent runtime."
        }
    }

    var systemImage: String {
        switch self {
        case .responses: "bolt.horizontal.circle"
        case .chat:      "paperplane"
        case .history:   "clock.arrow.circlepath"
        case .settings:  "person.circle"
        case .runtime:   "square.stack.3d.up"
        }
    }
}

private struct WorkspaceSidebar: View {
    @Binding var selection: WorkspaceSection?

    var body: some View {
        List(WorkspaceSection.allCases, selection: $selection) { section in
            NavigationLink(value: section) {
                HStack(spacing: 12) {
                    StoryRing(systemImage: section.systemImage, isActive: true, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.title).font(.igUsername)
                        Text(section.subtitle)
                            .font(.igTimestamp)
                            .foregroundStyle(.hermesSecondaryText)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.sidebar)
    }
}

// MARK: - Responses console (Instagram "feed"-style scroller)

private struct HermesResponsesConsoleView: View {
    @Binding var apiSettings: HermesAPISettings
    @Binding var requestDraft: HermesRequestDraft
    @Bindable var responseSession: HermesResponsesSession
    @Bindable var historyStore: HermesHistoryStore

    var body: some View {
        VStack(spacing: 0) {
            HermesBrandBar(title: "Hermes", trailing: AnyView(
                HStack(spacing: 4) {
                    IGIconButton(systemImage: "heart") {}
                    IGIconButton(systemImage: "paperplane") {}
                }
            ))

            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    storyStrip

                    IGBrandHero(
                        title: "Hermes Gateway",
                        subtitle: "Stream `/v1/responses` with SSE, chain follow-ups, and inspect every tool event Hermes produces.",
                        systemImage: "bolt.horizontal.circle.fill"
                    )

                    statusStrip
                        .padding(.horizontal, 16)
                        .padding(.top, 14)

                    IGSectionHeader(title: "Compose")
                    composer

                    IGSectionHeader(title: "Assistant", trailing: responseSession.latestResponseID.isEmpty ? nil : "id \(responseSession.latestResponseID.prefix(8))")
                    assistantOutput

                    IGSectionHeader(title: "Event Timeline", trailing: "\(responseSession.eventCount) events")
                    eventTimeline
                        .padding(.bottom, 24)
                }
            }
            .background(Color.hermesCanvas)
        }
        .navigationBarHidden(true)
        .background(Color.hermesCanvas)
    }

    private var storyStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                storyTile(symbol: "bolt.horizontal.circle.fill", label: "Thread", subtitle: responseSession.previousResponseID.isEmpty ? "new" : "chained", active: !responseSession.previousResponseID.isEmpty)
                storyTile(symbol: "waveform.path.ecg", label: "Status", subtitle: responseSession.connectionStatus, active: responseSession.isSending)
                storyTile(symbol: "timeline.selection", label: "Events", subtitle: "\(responseSession.eventCount)", active: responseSession.eventCount > 0)
                storyTile(symbol: "link", label: "Resume", subtitle: responseSession.previousResponseID.isEmpty ? "—" : String(responseSession.previousResponseID.prefix(6)), active: !responseSession.previousResponseID.isEmpty)
                storyTile(symbol: "trash", label: "New", subtitle: "reset", active: false)
                    .onTapGesture { responseSession.resetConversation() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private func storyTile(symbol: String, label: String, subtitle: String, active: Bool) -> some View {
        VStack(spacing: 6) {
            StoryRing(systemImage: symbol, isActive: active, size: 64)
            Text(label).font(.igUsername)
            Text(subtitle)
                .font(.igTimestamp)
                .foregroundStyle(.hermesSecondaryText)
                .lineLimit(1)
        }
        .frame(width: 78)
    }

    private var statusStrip: some View {
        HStack(spacing: 10) {
            IGStatusPill(
                label: "Thread",
                value: responseSession.previousResponseID.isEmpty ? "New" : "Chained",
                tint: responseSession.previousResponseID.isEmpty ? .igActionBlue : .igGradPurple
            )
            IGStatusPill(
                label: "Status",
                value: responseSession.connectionStatus.isEmpty ? "Idle" : responseSession.connectionStatus,
                tint: responseSession.isSending ? .igGradOrange : .igOnlineGreen
            )
            Spacer(minLength: 0)
        }
    }

    private var composer: some View {
        IGCard {
            VStack(alignment: .leading, spacing: 14) {
                if !responseSession.previousResponseID.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.branch")
                            .foregroundStyle(.igGradPurple)
                        Text(responseSession.previousResponseID)
                            .font(.igTimestamp.monospaced())
                            .foregroundStyle(.hermesSecondaryText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                ZStack(alignment: .topLeading) {
                    if requestDraft.userPrompt.isEmpty {
                        Text("Ask Hermes to inspect files, run tools, or explain context…")
                            .font(.igDMBubble)
                            .foregroundStyle(.hermesSecondaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $requestDraft.userPrompt)
                        .font(.igDMBubble)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .frame(minHeight: 140)
                }
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.hermesSurfaceInput)
                )

                HStack(spacing: 10) {
                    if !responseSession.previousResponseID.isEmpty && !responseSession.isSending {
                        IGPrimaryButton(title: "New Thread", icon: "plus.circle", variant: .outlined) {
                            responseSession.resetConversation()
                        }
                    }
                    if responseSession.isSending {
                        IGPrimaryButton(title: "Cancel", icon: "xmark", variant: .destructive) {
                            responseSession.cancel()
                        }
                    }
                    IGPrimaryButton(
                        title: responseSession.isSending ? "Sending…" : "Send",
                        icon: "paperplane.fill",
                        variant: .primary,
                        isLoading: responseSession.isSending
                    ) {
                        responseSession.submit(apiSettings: apiSettings, draft: requestDraft, historyStore: historyStore)
                    }
                }
                .disabled(requestDraft.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !responseSession.isSending)
            }
        }
    }

    private var assistantOutput: some View {
        IGCard {
            VStack(alignment: .leading, spacing: 12) {
                if !responseSession.lastErrorMessage.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.igDestructive)
                        Text(responseSession.lastErrorMessage)
                            .font(.igCaption)
                            .foregroundStyle(.igDestructive)
                    }
                }

                if responseSession.streamedText.isEmpty {
                    HStack(spacing: 10) {
                        StoryRing(systemImage: "bolt.horizontal", isActive: false, size: 36)
                        Text("Send a `/v1/responses` request to populate streamed output here.")
                            .font(.igCaption)
                            .foregroundStyle(.hermesSecondaryText)
                    }
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        StoryRing(systemImage: "sparkles", isActive: responseSession.isSending, size: 36, tint: .igGradPurple)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("hermes")
                                .font(.igUsername)
                            Text(responseSession.streamedText)
                                .font(.igDMBubble)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
        }
    }

    private var eventTimeline: some View {
        Group {
            if responseSession.entries.isEmpty {
                IGCard {
                    Text("The SSE event stream will appear here — `response.created`, text deltas, tool events, and completion.")
                        .font(.igCaption)
                        .foregroundStyle(.hermesSecondaryText)
                }
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(responseSession.entries) { response in
                        HermesResponseCard(response: response)
                    }
                }
            }
        }
    }
}

// MARK: - Chat console (DM-style)

private struct HermesChatConsoleView: View {
    @Binding var apiSettings: HermesAPISettings
    @Binding var chatDraft: HermesChatDraft
    @Bindable var chatSession: HermesChatSession
    @Bindable var historyStore: HermesHistoryStore

    var body: some View {
        VStack(spacing: 0) {
            HermesBrandBar(title: "Direct", trailing: AnyView(
                HStack(spacing: 4) {
                    if !chatSession.entries.isEmpty {
                        IGIconButton(systemImage: "square.and.pencil") {
                            chatSession.resetConversation()
                        }
                    }
                }
            ))

            // Header pinned partner
            HStack(spacing: 12) {
                StoryRing(systemImage: "sparkles", isActive: chatSession.isSending, size: 44, tint: .igGradPurple)
                VStack(alignment: .leading, spacing: 2) {
                    Text("hermes")
                        .font(.igUsername)
                    Text(chatSession.connectionStatus.isEmpty ? "chat.completions" : chatSession.connectionStatus)
                        .font(.igTimestamp)
                        .foregroundStyle(.hermesSecondaryText)
                }
                Spacer()
                Text("\(chatSession.entries.count) msgs")
                    .font(.igTimestamp)
                    .foregroundStyle(.hermesSecondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .overlay(alignment: .bottom) { IGHairline() }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if chatSession.entries.isEmpty {
                            VStack(spacing: 10) {
                                StoryRing(systemImage: "sparkles", isActive: false, size: 80, tint: .igGradPurple)
                                Text("hermes").font(.igUsername)
                                Text("Start a chat — transcripts stay separate from `/v1/responses`.")
                                    .font(.igCaption)
                                    .foregroundStyle(.hermesSecondaryText)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        } else {
                            ForEach(chatSession.entries) { message in
                                IGChatBubble(
                                    text: message.content,
                                    isFromUser: message.role == "user"
                                )
                                .id(message.id)
                            }
                        }

                        if !chatSession.streamedText.isEmpty {
                            IGChatBubble(text: chatSession.streamedText, isFromUser: false, timestamp: "streaming")
                        }

                        if !chatSession.lastErrorMessage.isEmpty {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(chatSession.lastErrorMessage)
                                    .font(.igCaption)
                            }
                            .foregroundStyle(.igDestructive)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
                .onChange(of: chatSession.entries.count) { _, _ in
                    if let last = chatSession.entries.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            // Composer
            chatComposer
        }
        .navigationBarHidden(true)
        .background(Color.hermesCanvas)
    }

    private var chatComposer: some View {
        VStack(spacing: 0) {
            IGHairline()
            HStack(alignment: .bottom, spacing: 10) {
                Image(systemName: "camera")
                    .font(.system(size: 22))
                    .foregroundStyle(.igActionBlue)
                    .padding(8)
                    .background(Circle().fill(Color.igActionBlue.opacity(0.12)))

                ZStack(alignment: .topLeading) {
                    if chatDraft.userPrompt.isEmpty {
                        Text("Message…")
                            .font(.igDMBubble)
                            .foregroundStyle(.hermesSecondaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $chatDraft.userPrompt)
                        .font(.igDMBubble)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .frame(minHeight: 36, maxHeight: 120)
                }
                .background(
                    Capsule().stroke(Color.hermesDivider, lineWidth: 1)
                )

                Button {
                    if chatSession.isSending {
                        chatSession.cancel()
                    } else {
                        chatSession.submit(apiSettings: apiSettings, draft: chatDraft, historyStore: historyStore)
                    }
                } label: {
                    Text(chatSession.isSending ? "Stop" : "Send")
                        .font(.igButtonPrimary)
                        .foregroundStyle(.igActionBlue)
                }
                .disabled(!chatSession.isSending && chatDraft.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(!chatSession.isSending && chatDraft.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(Color.hermesCanvas)
    }
}

// MARK: - Settings ("Profile" pane)

private struct HermesSettingsView: View {
    @Binding var apiSettings: HermesAPISettings
    @Binding var responsesDraft: HermesRequestDraft
    @Binding var chatDraft: HermesChatDraft

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                profileHeader

                IGSectionHeader(title: "Gateway")
                IGCard {
                    VStack(alignment: .leading, spacing: 14) {
                        labeledField("Base URL") {
                            TextField("https://hermes.example/v1", text: $apiSettings.baseURL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .igFieldBackground()
                        }
                        labeledField("Bearer token") {
                            SecureField("sk-…", text: $apiSettings.apiKey)
                                .igFieldBackground()
                        }
                        Toggle("Allow self-signed HTTPS certificates", isOn: $apiSettings.allowSelfSignedCertificates)
                            .font(.igCaption)
                            .tint(.igActionBlue)
                        IGHairline()
                        readonlyRow("Responses URL", value: HermesAPISettings.responseURL(from: apiSettings.baseURL)?.absoluteString ?? "Invalid URL")
                        readonlyRow("Chat URL", value: HermesAPISettings.chatCompletionsURL(from: apiSettings.baseURL)?.absoluteString ?? "Invalid URL")
                    }
                }

                IGSectionHeader(title: "/v1/responses")
                IGCard {
                    VStack(alignment: .leading, spacing: 14) {
                        labeledField("Model") {
                            TextField("gpt-…", text: $responsesDraft.model)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .igFieldBackground()
                        }
                        Toggle("Streaming enabled", isOn: $responsesDraft.stream)
                            .font(.igCaption)
                            .tint(.igActionBlue)
                        labeledField("Instructions") {
                            TextField("System instructions…", text: $responsesDraft.instructions, axis: .vertical)
                                .lineLimit(4, reservesSpace: true)
                                .igFieldBackground()
                        }
                    }
                }

                IGSectionHeader(title: "/v1/chat/completions")
                IGCard {
                    VStack(alignment: .leading, spacing: 14) {
                        labeledField("Model") {
                            TextField("gpt-…", text: $chatDraft.model)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .igFieldBackground()
                        }
                        Toggle("Streaming enabled", isOn: $chatDraft.stream)
                            .font(.igCaption)
                            .tint(.igActionBlue)
                        labeledField("System prompt") {
                            TextField("You are Hermes…", text: $chatDraft.systemPrompt, axis: .vertical)
                                .lineLimit(4, reservesSpace: true)
                                .igFieldBackground()
                        }
                    }
                }

                IGSectionHeader(title: "Notes")
                IGCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Responses and Chat screens are limited to message exchange and output.")
                        Text("Use this screen for endpoint, auth, model, streaming, and prompt configuration.")
                        Text("Keep self-signed certificates off unless you trust the Hermes API server.")
                    }
                    .font(.igCaption)
                    .foregroundStyle(.hermesSecondaryText)
                }
                .padding(.bottom, 24)
            }
        }
        .background(Color.hermesCanvas)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var profileHeader: some View {
        HStack(spacing: 16) {
            StoryRing(systemImage: "person.fill", isActive: true, size: 86, tint: .igGradPurple)
            VStack(alignment: .leading, spacing: 4) {
                Text("hermes_gateway").font(.igUsernameLarge)
                Text(apiSettings.baseURL.isEmpty ? "Not configured" : apiSettings.baseURL)
                    .font(.igTimestamp)
                    .foregroundStyle(.hermesSecondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(apiSettings.apiKey.isEmpty ? "No bearer token" : "•••• •••• token saved")
                    .font(.igTimestamp)
                    .foregroundStyle(.hermesSecondaryText)
            }
            Spacer()
        }
        .padding(16)
    }

    private func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.igBadge)
                .tracking(0.6)
                .foregroundStyle(.hermesSecondaryText)
            content()
        }
    }

    private func readonlyRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).font(.igUsername)
            Spacer()
            Text(value)
                .font(.igTimestamp.monospaced())
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.hermesSecondaryText)
        }
    }
}

// MARK: - History ("Activity")

private struct HermesHistoryView: View {
    @Bindable var historyStore: HermesHistoryStore

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if historyStore.sessions.isEmpty {
                    VStack(spacing: 10) {
                        StoryRing(systemImage: "clock.arrow.circlepath", isActive: false, size: 86)
                        Text("No Activity Yet").font(.igUsernameLarge)
                        Text("Completed Responses and Chat exchanges will appear here.")
                            .font(.igCaption)
                            .foregroundStyle(.hermesSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 80)
                } else {
                    ForEach(historyStore.sessions) { session in
                        sessionHeader(session)
                        ForEach(session.exchanges) { exchange in
                            HermesHistoryExchangeCard(
                                exchange: exchange,
                                role: session.kind
                            )
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
                    }
                }
            }
        }
        .background(Color.hermesCanvas)
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sessionHeader(_ session: HermesHistorySessionRecord) -> some View {
        HStack(spacing: 12) {
            StoryRing(
                systemImage: session.kind == .responses ? "bolt.horizontal.circle.fill" : "paperplane.fill",
                isActive: true,
                size: 44,
                tint: session.kind == .responses ? .igGradPurple : .igActionBlue
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(session.kind.title).font(.igUsername)
                Text(session.id).font(.igTimestamp.monospaced())
                    .foregroundStyle(.hermesSecondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Text(session.updatedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.igTimestamp)
                .foregroundStyle(.hermesSecondaryText)
            Button {
                historyStore.deleteSession(session.id, kind: session.kind)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundStyle(.igDestructive)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .overlay(alignment: .top) { IGHairline() }
    }
}

// MARK: - Agent runtime

private struct HermesAgentConfigView: View {
    @Binding var agentConfiguration: HermesAgentConfiguration

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                IGBrandHero(
                    title: "Agent Runtime",
                    subtitle: "Skills, backends, and guardrails. Expand one panel at a time — the others collapse to keep things tidy.",
                    systemImage: "square.stack.3d.up.fill"
                )

                IGSectionHeader(title: "Skills", trailing: "\(agentConfiguration.installedSkills.count) installed")
                HermesRuntimeAccordionPanel(
                    title: "Skills",
                    subtitle: "\(agentConfiguration.installedSkills.count) installed • \(agentConfiguration.filteredCatalogSkills.count) in catalog",
                    systemImage: "square.stack.3d.up.fill",
                    isExpanded: Binding(
                        get: { agentConfiguration.activeRuntimePanel == .skills },
                        set: { agentConfiguration.activeRuntimePanel = $0 ? .skills : nil }
                    )
                ) {
                    HermesSkillsPanel(agentConfiguration: $agentConfiguration)
                }

                IGSectionHeader(title: "Backend")
                HermesRuntimeAccordionPanel(
                    title: "Backend",
                    subtitle: agentConfiguration.backend.displayName,
                    systemImage: agentConfiguration.backend.systemImage,
                    isExpanded: Binding(
                        get: { agentConfiguration.activeRuntimePanel == .backend },
                        set: { agentConfiguration.activeRuntimePanel = $0 ? .backend : nil }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("Terminal backend", selection: $agentConfiguration.backend) {
                            ForEach(HermesTerminalBackend.allCases) { backend in
                                Text(backend.displayName).tag(backend)
                            }
                        }
                        .pickerStyle(.segmented)

                        Toggle("Persistent shell", isOn: $agentConfiguration.persistentShell)
                            .font(.igCaption)
                            .tint(.igActionBlue)

                        TextField("Working directory", text: $agentConfiguration.workingDirectory)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .igFieldBackground()
                    }
                }

                HermesRuntimeAccordionPanel(
                    title: "SSH",
                    subtitle: agentConfiguration.backend == .ssh ? "Remote host" : "Hidden while local backend is active",
                    systemImage: "network.badge.shield.half.filled",
                    isExpanded: Binding(
                        get: { agentConfiguration.activeRuntimePanel == .ssh },
                        set: { agentConfiguration.activeRuntimePanel = $0 ? .ssh : nil }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Host", text: $agentConfiguration.sshHost)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .igFieldBackground()
                        TextField("User", text: $agentConfiguration.sshUser)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .igFieldBackground()
                        TextField("Port", text: $agentConfiguration.sshPort)
                            .keyboardType(.numberPad)
                            .igFieldBackground()
                        TextField("Private key path", text: $agentConfiguration.sshKeyPath)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .igFieldBackground()
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
                            set: { agentConfiguration.activeRuntimePanel = $0 ? panel.kind : nil }
                        )
                    ) {
                        Text(panel.placeholder)
                            .font(.igCaption)
                            .foregroundStyle(.hermesSecondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color.hermesCanvas)
        .navigationTitle("Runtime")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HermesSkillsPanel: View {
    @Binding var agentConfiguration: HermesAgentConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Source", selection: $agentConfiguration.skillsLibraryMode) {
                ForEach(HermesSkillsLibraryMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            if agentConfiguration.skillsLibraryMode == .browse {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.hermesSecondaryText)
                    TextField("Search skills", text: $agentConfiguration.skillSearchQuery)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .igFieldBackground()
            }

            let visibleSkills = agentConfiguration.visibleSkills
            if visibleSkills.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundStyle(.hermesSecondaryText)
                    Text("No Skills Found").font(.igUsername)
                    Text(agentConfiguration.skillsLibraryMode == .installed
                         ? "Install a bundled skill to populate this panel."
                         : "Adjust the search query to find another skill.")
                        .font(.igTimestamp)
                        .foregroundStyle(.hermesSecondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 10) {
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
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedSkill.name).font(.igUsername)
                            Text(selectedSkill.category)
                                .font(.igBadge)
                                .tracking(0.6)
                                .foregroundStyle(.hermesSecondaryText)
                        }
                        Spacer()
                        statusBadge(installed: selectedSkill.isInstalled, source: selectedSkill.source)
                    }

                    Text(selectedSkill.description)
                        .font(.igCaption)
                        .foregroundStyle(.hermesSecondaryText)

                    if let path = selectedSkill.path {
                        Text(path)
                            .font(.igTimestamp.monospaced())
                            .foregroundStyle(.hermesSecondaryText)
                            .textSelection(.enabled)
                    }

                    ScrollView {
                        Text(selectedSkill.detail)
                            .font(.igTimestamp.monospaced())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(minHeight: 160, maxHeight: 240)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.hermesSurfaceInput)
                    )

                    if selectedSkill.isInstalled {
                        IGPrimaryButton(title: "Uninstall Skill", icon: "trash", variant: .destructive) {
                            agentConfiguration.uninstallSkill(selectedSkill.id)
                        }
                    } else {
                        IGPrimaryButton(title: "Install Skill", icon: "arrow.down.circle.fill", variant: .primary) {
                            agentConfiguration.installSelectedSkill()
                        }
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.hermesSurfaceInput.opacity(0.6))
                )
            }
        }
    }

    private func statusBadge(installed: Bool, source: String) -> some View {
        Text(installed ? "Installed" : source.capitalized)
            .font(.igBadge)
            .tracking(0.6)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule().fill((installed ? Color.igOnlineGreen : Color.igGradOrange).opacity(0.16))
            )
            .foregroundStyle(installed ? Color.igCloseFriends : Color.igGradOrange)
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
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    StoryRing(systemImage: systemImage, isActive: isExpanded, size: 44, tint: .igGradPurple)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.igUsername)
                        Text(subtitle)
                            .font(.igTimestamp)
                            .foregroundStyle(.hermesSecondaryText)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.hermesSecondaryText)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.hermesCanvas)
            }
            .buttonStyle(IGPressableStyle())

            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    content
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.hermesElevated)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .overlay(alignment: .top) { IGHairline() }
        .overlay(alignment: .bottom) { IGHairline() }
    }
}

private struct HermesSkillRow: View {
    let skill: HermesSkillDescriptor
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            StoryRing(
                systemImage: skill.isInstalled ? "checkmark.circle.fill" : "square.stack.3d.up",
                isActive: skill.isInstalled,
                size: 44,
                tint: skill.isInstalled ? .igCloseFriends : .igActionBlue
            )
            VStack(alignment: .leading, spacing: 2) {
                Text(skill.name).font(.igUsername)
                Text(skill.description)
                    .font(.igTimestamp)
                    .foregroundStyle(.hermesSecondaryText)
                    .lineLimit(2)
            }
            Spacer()
            Text(skill.category)
                .font(.igBadge)
                .tracking(0.6)
                .foregroundStyle(.hermesSecondaryText)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.igActionBlue.opacity(0.10) : Color.hermesSurfaceInput.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isSelected ? Color.igActionBlue : Color.clear, lineWidth: 1.5)
        )
    }
}

// MARK: - Response card (feed-post style)

private struct HermesResponseCard: View {
    let response: HermesResponseEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                StoryRing(
                    systemImage: "bolt.horizontal",
                    isActive: statusColor == .igActionBlue,
                    size: 36,
                    tint: statusColor
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(response.title).font(.igUsername)
                    Text(response.status)
                        .font(.igTimestamp)
                        .foregroundStyle(statusColor)
                }
                Spacer()
                Image(systemName: "ellipsis")
                    .foregroundStyle(.hermesSecondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if !response.summary.isEmpty {
                Text(response.summary)
                    .font(.igCaption)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }

            if !response.metadata.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(response.metadata, id: \.self) { line in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 5, height: 5)
                                .padding(.top, 6)
                            Text(line)
                                .font(.igTimestamp)
                                .foregroundStyle(.hermesSecondaryText)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hermesElevated)
        .overlay(alignment: .bottom) { IGHairline() }
    }

    private var statusColor: Color {
        switch response.status.lowercased() {
        case "failed": .igDestructive
        case "streaming", "update": .igActionBlue
        case "done", "completed": .igCloseFriends
        default: .igGradOrange
        }
    }
}

// MARK: - History exchange card

private struct HermesHistoryExchangeCard: View {
    let exchange: HermesHistoryExchange
    let role: HermesHistoryKind

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exchange.completedAt.formatted(date: .abbreviated, time: .shortened).uppercased())
                .font(.igTimestamp)
                .tracking(0.6)
                .foregroundStyle(.hermesSecondaryText)
            IGChatBubble(text: exchange.requestText, isFromUser: true)
            IGChatBubble(text: exchange.responseText, isFromUser: false)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Helper types (unchanged from original)

private struct HermesStatusItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let accent: Color
}

private enum HermesTerminalBackend: String, CaseIterable, Identifiable {
    case local, ssh
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .local: "Local"
        case .ssh:   "SSH"
        }
    }
    var systemImage: String {
        switch self {
        case .local: "laptopcomputer"
        case .ssh:   "network.badge.shield.half.filled"
        }
    }
}

private enum HermesRuntimePanelKind: String, Identifiable {
    case skills, backend, ssh, profiles, permissions, tools, models, sandbox, memory, observability
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
        .init(kind: .profiles,      title: "Profiles",      subtitle: "Switch between runtime profiles and targets", systemImage: "person.crop.rectangle.stack", placeholder: "Profile routing, per-target overrides, and environment inheritance will live here."),
        .init(kind: .permissions,   title: "Permissions",   subtitle: "Approval policy and privileged operations", systemImage: "checkmark.shield", placeholder: "Approval policy, escalations, and audit-friendly permission controls can expand here."),
        .init(kind: .tools,         title: "Tools",         subtitle: "Enable and scope MCP servers and terminal tools", systemImage: "wrench.and.screwdriver", placeholder: "MCP server selection, shell tool policies, and tool-scoped access rules can be configured in this panel."),
        .init(kind: .models,        title: "Models",        subtitle: "Default model and routing behavior", systemImage: "cpu", placeholder: "Model defaults, failover routing, and provider-specific options can be surfaced in this panel."),
        .init(kind: .sandbox,       title: "Sandbox",       subtitle: "Filesystem and network boundaries", systemImage: "lock.square.stack", placeholder: "Workspace-write, read-only, and network isolation controls can be configured here."),
        .init(kind: .memory,        title: "Memory",        subtitle: "Persistent context and workspace notes", systemImage: "brain.head.profile", placeholder: "Persistent notes, workspace memory, and user-level memory toggles fit naturally in this section."),
        .init(kind: .observability, title: "Observability", subtitle: "Logs, traces, and runtime diagnostics", systemImage: "waveform.and.magnifyingglass", placeholder: "Runtime logs, traces, and environment diagnostics can be collected and displayed here.")
    ]
}

private enum HermesSkillsLibraryMode: String, CaseIterable, Identifiable {
    case installed, browse
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .installed: "Installed"
        case .browse:    "Browse"
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
        case .local: "Commands execute directly on the device host running Hermes."
        case .ssh:   "Commands execute on a remote server over SSH with a persistent shell."
        }
    }

    var skillCatalog: [HermesSkillDescriptor] {
        HermesSkillCatalog.seed.map { skill in
            var copy = skill
            copy.isInstalled = installedSkillIDs.contains(skill.id)
            return copy
        }
    }

    var installedSkills: [HermesSkillDescriptor] { skillCatalog.filter(\.isInstalled) }

    var filteredCatalogSkills: [HermesSkillDescriptor] {
        let query = skillSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return skillCatalog }
        return skillCatalog.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.category.localizedCaseInsensitiveContains(query) ||
            $0.description.localizedCaseInsensitiveContains(query)
        }
    }

    var visibleSkills: [HermesSkillDescriptor] {
        switch skillsLibraryMode {
        case .installed: installedSkills
        case .browse:    filteredCatalogSkills
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
            description: "Generate or refine frontend directions with AIDesigner, then port them into the repo UI.",
            detail: """
            ---
            name: \"aidesigner-frontend\"
            description: \"Create or redesign frontend surfaces with AIDesigner.\"
            ---

            Workflow:
            1. Inspect the repo and infer the existing visual system.
            2. Generate or refine an AIDesigner artifact.
            3. Capture the artifact locally for preview and adoption.
            4. Port the visual system into real app code instead of shipping raw HTML.
            """,
            source: "bundled",
            path: "~/.agents/skills/aidesigner-frontend",
            isInstalled: false
        ),
        HermesSkillDescriptor(
            id: "openai-playwright",
            name: "openai-playwright",
            category: "automation",
            description: "Automate a real browser from the terminal for navigation, screenshots, and UI-flow debugging.",
            detail: "# openai-playwright\n\nUse this skill for browser automation: snapshots, screenshots, data extraction, or reproducing interactive UI bugs.",
            source: "bundled",
            path: "~/.agents/skills/openai-playwright",
            isInstalled: false
        ),
        HermesSkillDescriptor(
            id: "skill-installer",
            name: "skill-installer",
            category: "system",
            description: "Install Codex skills from a curated list or a GitHub repo path into the active profile.",
            detail: "# skill-installer\n\n- list curated skills\n- install a skill into $CODEX_HOME/skills\n- install from a repo path, including private repos",
            source: "bundled",
            path: "~/Library/Developer/Xcode/CodingAssistant/codex/skills/.system/skill-installer",
            isInstalled: false
        ),
        HermesSkillDescriptor(
            id: "skill-creator",
            name: "skill-creator",
            category: "system",
            description: "Guide for creating or updating specialized skills that extend the coding agent.",
            detail: "# skill-creator\n\nUse when the user wants to create or update a specialized skill with workflow or tool integration.",
            source: "bundled",
            path: "~/Library/Developer/Xcode/CodingAssistant/codex/skills/.system/skill-creator",
            isInstalled: false
        ),
        HermesSkillDescriptor(
            id: "deploy-model",
            name: "deploy-model",
            category: "microsoft-foundry",
            description: "Unified Azure OpenAI model deployment: preset, customize, and capacity discovery.",
            detail: "# deploy-model\n\nQuick preset deployments, customized deployments, and capacity discovery across regions.",
            source: "bundled",
            path: "~/.agents/skills/microsoft-foundry/models/deploy-model",
            isInstalled: false
        )
    ]
}

#Preview("Default") {
    ContentView()
}
