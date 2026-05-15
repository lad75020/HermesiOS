//
//  ContentView.swift
//  HermesiOS
//
//  Created by Laurent Dubertrand on 04/05/2026.
//

import Observation
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import Vision
import VisionKit


struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hermes.appTheme") private var appTheme: HermesAppTheme = .system
    @AppStorage(hermesMacHostStorageKey) private var macHost = defaultHermesMacHost
    @AppStorage(hermesDashboardPortStorageKey) private var dashboardPort = defaultHermesDashboardPort
    @AppStorage(hermesOfficePortStorageKey) private var officePort = defaultHermesOfficePort
    @AppStorage(hermesRuntimeTabEnabledStorageKey) private var isRuntimeTabEnabled = false

    @State private var selectedWorkspace: WorkspaceSection? = .responses
    @State private var selectedPhoneSection: WorkspaceSection = .responses
    @State private var apiSettings: HermesAPISettings
    @State private var companionSettings: HermesCompanionSettings
    @State private var agentConfiguration = HermesAgentConfiguration()
    @State private var responsesDraft: HermesRequestDraft
    @State private var responseWorkspaces: [HermesResponsesWorkspace]
    @State private var selectedResponseWorkspaceID: HermesResponsesWorkspace.ID
    @State private var chatDraft: HermesChatDraft
    @State private var terminalSettings: HermesTerminalSettings
    @State private var chatSession = HermesChatSession()
    @State private var companionEnrollment = HermesCompanionEnrollmentSession()
    @State private var companionRuntime = HermesCompanionRuntimeSession()
    @State private var statusMonitor = HermesStatusMonitor()
    @State private var dashboardHistorySearchSession = HermesDashboardHistorySearchSession()
    @State private var clipboardHistory = HermesClipboardHistoryStore()
    @State private var promptHistory = HermesPromptHistoryStore()
    @StateObject private var webBrowserStore = HermesWebBrowserDeckStore()
    @State private var isShowingSplash = true
    @State private var didKickstartRuntimeSectionsAfterLoad = false
    @State private var isResponsesCompletionUnread = false
    @State private var isChatCompletionUnread = false
    @State private var isHistorySearchCompletionUnread = false
    @State private var isResponsesFailureUnread = false
    @State private var isChatFailureUnread = false
    @State private var isHistorySearchFailureUnread = false
    @State private var askHermesBusyToastID: UUID?
    @State private var busyStreamingCloseToastID: UUID?
    @State private var isTerminalAuthenticationInProgress = false

    init() {
        HermesAppearance.configureGlobalAppearance()
        HermesSettingsPersistence.removeLegacyLocalHistoryFile()
        let loadedResponsesDraft = HermesSettingsPersistence.loadResponsesDraft()
        let initialResponseWorkspace = HermesResponsesWorkspace(number: 1, draft: loadedResponsesDraft, session: HermesResponsesSession())
        _apiSettings = State(initialValue: HermesSettingsPersistence.loadAPISettings())
        _companionSettings = State(initialValue: HermesSettingsPersistence.loadCompanionSettings())
        _responsesDraft = State(initialValue: loadedResponsesDraft)
        _responseWorkspaces = State(initialValue: [initialResponseWorkspace])
        _selectedResponseWorkspaceID = State(initialValue: initialResponseWorkspace.id)
        _chatDraft = State(initialValue: HermesSettingsPersistence.loadChatDraft())
        _terminalSettings = State(initialValue: HermesSettingsPersistence.loadTerminalSettings())
    }

    var body: some View {
        ZStack {
            if isShowingSplash {
                HermesSplashView()
                    .transition(.opacity)
                    .zIndex(1)
            } else {
                Group {
                    if horizontalSizeClass == .compact {
                        iPhoneLayout
                    } else {
                        iPadLayout
                    }
                }
                .transition(.opacity)
            }
        }
        .background(HermesLiquidGlassCanvas().ignoresSafeArea())
        .overlay(alignment: .top) {
            if busyStreamingCloseToastID != nil {
                HermesTransientToast(
                    message: "Busy streaming",
                    buttonTitle: "STOP",
                    action: stopBusyStreamingCloseAttempt
                )
                .padding(.top, 18)
                .padding(.horizontal, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(3)
            } else if askHermesBusyToastID != nil {
                HermesTransientToast(message: "Ask Hermes is busy")
                    .padding(.top, 18)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
            }
        }
        .preferredColorScheme(appTheme.colorScheme)
        .tint(.igActionBlue)
        .onChange(of: apiSettings) { _, newValue in
            HermesSettingsPersistence.saveAPISettings(newValue)
        }
        .onChange(of: companionSettings) { _, newValue in
            HermesSettingsPersistence.saveCompanionSettings(newValue)
        }
        .onChange(of: responsesDraft) { _, newValue in
            HermesSettingsPersistence.saveResponsesDraft(newValue)
        }
        .onChange(of: chatDraft) { _, newValue in
            HermesSettingsPersistence.saveChatDraft(newValue)
        }
        .onChange(of: terminalSettings) { _, newValue in
            HermesSettingsPersistence.saveTerminalSettings(newValue)
        }
        .task {
            webBrowserStore.loadAllUnloadedWebPages()
        }
        .task {
            guard isShowingSplash else { return }
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut(duration: 0.25)) {
                isShowingSplash = false
            }
        }
        .task(id: companionServicePortsLoadKey) {
            guard !isShowingSplash else { return }
            guard companionEnrollment.identityState.isEnrolled else { return }
            await refreshServicePortsFromCompanion()
        }
        .task(id: runtimeInitialLoadKey) {
            guard !isShowingSplash else { return }
            guard isRuntimeTabEnabled else { return }
            guard !didKickstartRuntimeSectionsAfterLoad else { return }
            guard companionEnrollment.identityState.isEnrolled else { return }
            didKickstartRuntimeSectionsAfterLoad = true
            try? await Task.sleep(for: .milliseconds(300))
            companionRuntime.kickstartRuntimeSections(
                settings: companionSettings,
                identityState: companionEnrollment.identityState
            )
        }
        .task(id: clipboardMonitoringKey) {
            guard !isShowingSplash, scenePhase == .active else { return }
            await clipboardHistory.runMonitoringLoop()
        }
        .task(id: statusLoopKey) {
            guard !isShowingSplash, scenePhase == .active else { return }
            await statusMonitor.runStatusLoop(
                apiSettings: apiSettings,
                companionSettings: companionSettings,
                identityState: companionEnrollment.identityState
            )
        }
        .onChange(of: scenePhase) { _, newValue in
            if newValue != .active, isAnyHermesStreamActive, !isTerminalAuthenticationInProgress {
                showBusyStreamingCloseToast()
            }
            guard newValue == .active else { return }
            Task {
                await statusMonitor.refresh(
                    apiSettings: apiSettings,
                    companionSettings: companionSettings,
                    identityState: companionEnrollment.identityState
                )
            }
        }
        .onChange(of: activeResponseSession.connectionStatus) { _, newValue in
            if newValue == "Completed" {
                isResponsesFailureUnread = false
                isResponsesCompletionUnread = true
            } else if newValue == "Failed" {
                isResponsesCompletionUnread = false
                isResponsesFailureUnread = activeResponseSession.lastErrorWasTimeoutOrNetworkLoss
            }
        }
        .onChange(of: chatSession.connectionStatus) { _, newValue in
            if newValue == "Completed" {
                isChatFailureUnread = false
                isChatCompletionUnread = true
            } else if newValue == "Failed" {
                isChatCompletionUnread = false
                isChatFailureUnread = chatSession.lastErrorWasTimeoutOrNetworkLoss
            }
        }
        .onChange(of: dashboardHistorySearchSession.isSearching) { oldValue, newValue in
            guard oldValue, !newValue, dashboardHistorySearchSession.status != "Cancelled" else { return }
            isHistorySearchFailureUnread = false
            isHistorySearchCompletionUnread = true
        }
        .onChange(of: isRuntimeTabEnabled) { _, isEnabled in
            guard !isEnabled else { return }
            if selectedWorkspace == .runtime {
                selectedWorkspace = .responses
            }
            if selectedPhoneSection == .runtime {
                selectedPhoneSection = .responses
            }
        }
    }


    private var activeResponseWorkspace: HermesResponsesWorkspace {
        if let workspace = responseWorkspaces.first(where: { $0.id == selectedResponseWorkspaceID }) {
            return workspace
        }
        if let workspace = responseWorkspaces.first {
            return workspace
        }
        return HermesResponsesWorkspace(number: 1, draft: responsesDraft, session: HermesResponsesSession())
    }

    private var activeResponseSession: HermesResponsesSession {
        activeResponseWorkspace.session
    }

    private var isAnyResponseWorkspaceStreaming: Bool {
        responseWorkspaces.contains { $0.session.isSending }
    }

    private var isAnyResponseWorkspaceActivelyStreaming: Bool {
        responseWorkspaces.contains { $0.session.isStreaming }
    }

    private var hasUnreadResponseWorkspaceCompletion: Bool {
        responseWorkspaces.contains { $0.attention == .completed }
    }

    private var hasUnreadResponseWorkspaceFailure: Bool {
        responseWorkspaces.contains { workspace in
            workspace.attention == .failed && workspace.session.lastErrorWasTimeoutOrNetworkLoss
        }
    }

    private var apiChannelActive: Bool {
        isAnyResponseWorkspaceStreaming || chatSession.isSending
    }

    private var companionChannelActive: Bool {
        companionEnrollment.isEnrolling || companionRuntime.isBusy
    }

    private var dashboardChannelActive: Bool {
        dashboardHistorySearchSession.isDashboardHTTPActive
    }

    private var isAnyHermesStreamActive: Bool {
        isAnyResponseWorkspaceActivelyStreaming || chatSession.isStreaming
    }

    private var visibleWorkspaceSections: [WorkspaceSection] {
        WorkspaceSection.allCases.filter { section in
            section != .runtime || isRuntimeTabEnabled
        }
    }

    private var statusLoopKey: String {
        statusRefreshKey + "|scenePhase=\(scenePhase)|splash=\(isShowingSplash)"
    }

    private var officeURLString: String {
        HermesHostEndpoints.httpURLString(host: macHost, port: officePort)
    }

    private var dashboardURLString: String {
        HermesHostEndpoints.httpURLString(host: macHost, port: dashboardPort)
    }

    private var companionServicePortsLoadKey: String {
        [
            "splash=\(isShowingSplash)",
            companionEnrollment.identityState.isEnrolled ? "enrolled" : "not-enrolled",
            companionEnrollment.identityState.serverEndpoint,
            companionEnrollment.identityState.authenticationTokenFingerprint,
            companionSettings.apiURL
        ].joined(separator: "|")
    }

    private var runtimeInitialLoadKey: String {
        [
            "splash=\(isShowingSplash)",
            isRuntimeTabEnabled ? "runtime-enabled" : "runtime-disabled",
            companionEnrollment.identityState.isEnrolled ? "enrolled" : "not-enrolled",
            companionEnrollment.identityState.deviceID,
            companionEnrollment.identityState.serverEndpoint,
            companionSettings.apiURL,
            companionSettings.authenticationToken.isEmpty ? "no-companion-token" : "companion-token-set"
        ].joined(separator: "|")
    }

    private var clipboardMonitoringKey: String {
        "scenePhase=\(scenePhase)|splash=\(isShowingSplash)"
    }

    private var statusRefreshKey: String {
        [
            apiSettings.baseURL,
            apiSettings.apiKey.isEmpty ? "no-api-key" : "api-key-set",
            String(apiSettings.allowSelfSignedCertificates),
            companionSettings.apiURL,
            companionSettings.authenticationToken.isEmpty ? "no-companion-token" : "companion-token-set",
            companionEnrollment.identityState.deviceID,
            companionEnrollment.identityState.serverEndpoint
        ].joined(separator: "|")
    }

    private func refreshServicePortsFromCompanion() async {
        do {
            let ports = try await companionRuntime.refreshServicePorts(
                settings: companionSettings,
                identityState: companionEnrollment.identityState
            )
            let apiPort = HermesHostEndpoints.tcpPort(from: ports.apiGatewayPort, fallback: HermesHostEndpoints.tcpPort(from: apiSettings.baseURL, fallback: defaultHermesAPIPort))
            let fetchedDashboardPort = HermesHostEndpoints.tcpPort(from: ports.dashboardPort, fallback: dashboardPort)
            let fetchedOfficePort = HermesHostEndpoints.tcpPort(from: ports.officePort, fallback: officePort)
            apiSettings.baseURL = HermesHostEndpoints.httpURLString(host: macHost, port: apiPort, path: "/v1")
            dashboardPort = fetchedDashboardPort
            officePort = fetchedOfficePort
        } catch {
            companionRuntime.servicePortsError = error.localizedDescription
        }
    }

    private var iPadLayout: some View {
        NavigationSplitView {
            WorkspaceSidebar(
                selection: $selectedWorkspace,
                sections: visibleWorkspaceSections,
                statusMonitor: statusMonitor,
                responseSession: activeResponseSession,
                chatSession: chatSession,
                companionRuntime: companionRuntime,
                webBrowserStore: webBrowserStore,
                apiChannelActive: apiChannelActive,
                companionChannelActive: companionChannelActive,
                dashboardChannelActive: dashboardChannelActive,
                isResponsesStreamingActive: isAnyResponseWorkspaceStreaming,
                isHistorySearchActive: dashboardHistorySearchSession.isSearching,
                hasUnreadResponsesCompletion: hasUnreadResponseWorkspaceCompletion,
                hasUnreadResponsesFailure: hasUnreadResponseWorkspaceFailure,
                isResponsesCompletionUnread: $isResponsesCompletionUnread,
                isChatCompletionUnread: $isChatCompletionUnread,
                isHistorySearchCompletionUnread: $isHistorySearchCompletionUnread,
                isResponsesFailureUnread: $isResponsesFailureUnread,
                isChatFailureUnread: $isChatFailureUnread,
                isHistorySearchFailureUnread: $isHistorySearchFailureUnread
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationSplitViewColumnWidth(min: 72, ideal: 84, max: 96)
        } detail: {
            workspaceDetail(for: selectedWorkspace ?? .responses)
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var iPhoneLayout: some View {
        VStack(spacing: 0) {
            HermesStatusBand(
                statusMonitor: statusMonitor,
                apiChannelActive: apiChannelActive,
                companionChannelActive: companionChannelActive,
                dashboardChannelActive: dashboardChannelActive
            )

            TabView(selection: $selectedPhoneSection) {
                NavigationStack {
                    responsesConsoleView()
                }
                .tabItem {
                    Label("Ask Hermes", systemImage: "dot.radiowaves.left.and.right")
                }
                .tag(WorkspaceSection.responses)

                NavigationStack {
                    HermesChatConsoleView(
                        apiSettings: $apiSettings,
                        chatDraft: $chatDraft,
                        companionSettings: companionSettings,
                        companionEnrollment: companionEnrollment,
                        companionRuntime: companionRuntime,
                        chatSession: chatSession,
                        promptHistory: promptHistory
                    )
                }
                .tabItem {
                    Label("Chat with Hermes", systemImage: "text.bubble")
                }
                .tag(WorkspaceSection.chat)

                NavigationStack {
                    HermesHistoryView(
                        apiSettings: $apiSettings,
                        searchSession: dashboardHistorySearchSession,
                        isResponsesStreaming: !responseWorkspaces.contains { !$0.session.isSending },
                        isChatStreaming: chatSession.isSending,
                        onResumeResponses: resumeConversationInResponses,
                        onResumeChat: resumeConversationInChat
                    )
                }
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(WorkspaceSection.history)

                NavigationStack {
                    HermesWebBrowserView(deckStore: webBrowserStore, dashboardURLString: dashboardURLString, officeURLString: officeURLString)
                }
                .tabItem {
                    Label("Web", systemImage: "globe")
                }
                .tag(WorkspaceSection.web)

                NavigationStack {
                    HermesTerminalView(
                        host: macHost,
                        terminalSettings: $terminalSettings,
                        isAuthenticating: $isTerminalAuthenticationInProgress
                    )
                }
                .tabItem {
                    Label("Terminal", systemImage: "terminal")
                }
                .tag(WorkspaceSection.terminal)

                NavigationStack {
                    HermesUtilitiesView(
                        clipboardHistory: clipboardHistory,
                        promptHistory: promptHistory,
                        responseSession: activeResponseSession,
                        chatSession: chatSession,
                        companionSettings: companionSettings,
                        companionEnrollment: companionEnrollment,
                        companionRuntime: companionRuntime
                    )
                }
                .tabItem {
                    Label("Utilities", systemImage: "wrench.and.screwdriver")
                }
                .tag(WorkspaceSection.utilities)

                NavigationStack {
                    HermesSettingsView(
                        apiSettings: $apiSettings,
                        companionSettings: $companionSettings,
                        responsesDraft: $responsesDraft,
                        chatDraft: $chatDraft,
                        terminalSettings: $terminalSettings,
                        appTheme: $appTheme,
                        companionEnrollment: companionEnrollment,
                        companionRuntime: companionRuntime
                    )
                }
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
                .tag(WorkspaceSection.settings)

                if isRuntimeTabEnabled {
                    NavigationStack {
                        HermesAgentConfigView(
                            agentConfiguration: $agentConfiguration,
                            companionSettings: companionSettings,
                            companionEnrollment: companionEnrollment,
                            companionRuntime: companionRuntime
                        )
                    }
                    .tabItem {
                        Label("Runtime", systemImage: "server.rack")
                    }
                    .tag(WorkspaceSection.runtime)
                }
            }
        }
    }

    @ViewBuilder
    private func responsesConsoleView() -> some View {
        let workspace = activeResponseWorkspace
        HermesResponsesConsoleView(
            apiSettings: $apiSettings,
            requestDraft: Binding(
                get: { workspace.draft },
                set: { newValue in
                    workspace.draft = newValue
                    responsesDraft = newValue
                }
            ),
            companionSettings: companionSettings,
            companionEnrollment: companionEnrollment,
            companionRuntime: companionRuntime,
            responseSession: workspace.session,
            promptHistory: promptHistory,
            responseWorkspaces: responseWorkspaces,
            workspaceNumber: workspace.number,
            workspaceCount: responseWorkspaces.count,
            canCreateWorkspace: responseWorkspaces.count < 4,
            onCreateWorkspace: createResponseWorkspace,
            onSelectWorkspace: selectResponseWorkspace(number:)
        )
    }

    private func createResponseWorkspace() {
        guard responseWorkspaces.count < 4 else { return }
        let nextNumber = (1...4).first { number in
            !responseWorkspaces.contains { $0.number == number }
        } ?? (responseWorkspaces.count + 1)
        let workspace = HermesResponsesWorkspace(number: nextNumber, draft: responsesDraft, session: HermesResponsesSession())
        responseWorkspaces.append(workspace)
        responseWorkspaces.sort { $0.number < $1.number }
    }

    private func selectResponseWorkspace(number: Int) {
        guard let workspace = responseWorkspaces.first(where: { $0.number == number }) else { return }
        workspace.acknowledgeCurrentStatus()
        selectedResponseWorkspaceID = workspace.id
        responsesDraft = workspace.draft
    }

    @ViewBuilder
    private func workspaceDetail(for section: WorkspaceSection) -> some View {
        switch section {
        case .responses:
            responsesConsoleView()
        case .chat:
            HermesChatConsoleView(
                apiSettings: $apiSettings,
                chatDraft: $chatDraft,
                companionSettings: companionSettings,
                companionEnrollment: companionEnrollment,
                companionRuntime: companionRuntime,
                chatSession: chatSession,
                promptHistory: promptHistory
            )
        case .history:
            HermesHistoryView(
                apiSettings: $apiSettings,
                searchSession: dashboardHistorySearchSession,
                isResponsesStreaming: !responseWorkspaces.contains { !$0.session.isSending },
                isChatStreaming: chatSession.isSending,
                onResumeResponses: resumeConversationInResponses,
                onResumeChat: resumeConversationInChat
            )
        case .web:
            HermesWebBrowserView(deckStore: webBrowserStore, dashboardURLString: dashboardURLString, officeURLString: officeURLString)
        case .terminal:
            HermesTerminalView(
                host: macHost,
                terminalSettings: $terminalSettings,
                isAuthenticating: $isTerminalAuthenticationInProgress
            )
        case .utilities:
            HermesUtilitiesView(
                clipboardHistory: clipboardHistory,
                promptHistory: promptHistory,
                responseSession: activeResponseSession,
                chatSession: chatSession,
                companionSettings: companionSettings,
                companionEnrollment: companionEnrollment,
                companionRuntime: companionRuntime
            )
        case .settings:
            HermesSettingsView(
                apiSettings: $apiSettings,
                companionSettings: $companionSettings,
                responsesDraft: Binding(
                    get: { activeResponseWorkspace.draft },
                    set: { newValue in
                        activeResponseWorkspace.draft = newValue
                        responsesDraft = newValue
                    }
                ),
                chatDraft: $chatDraft,
                terminalSettings: $terminalSettings,
                appTheme: $appTheme,
                companionEnrollment: companionEnrollment,
                companionRuntime: companionRuntime
            )
        case .runtime:
            HermesAgentConfigView(
                agentConfiguration: $agentConfiguration,
                companionSettings: companionSettings,
                companionEnrollment: companionEnrollment,
                companionRuntime: companionRuntime
            )
        }
    }

    private func resumeConversationInResponses(_ result: HermesDashboardConversationResult) {
        guard let workspace = responseWorkspaces.first(where: { !$0.session.isSending }) else {
            showAskHermesBusyToast()
            return
        }
        workspace.session.resumeConversation(from: result)
        workspace.acknowledgeCurrentStatus()
        selectedResponseWorkspaceID = workspace.id
        responsesDraft = workspace.draft
        selectedWorkspace = .responses
        selectedPhoneSection = .responses
    }

    private func showAskHermesBusyToast() {
        let toastID = UUID()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            askHermesBusyToastID = toastID
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard askHermesBusyToastID == toastID else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                askHermesBusyToastID = nil
            }
        }
    }

    private func showBusyStreamingCloseToast() {
        let toastID = UUID()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            busyStreamingCloseToastID = toastID
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard busyStreamingCloseToastID == toastID else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                busyStreamingCloseToastID = nil
            }
        }
    }

    private func stopBusyStreamingCloseAttempt() {
        withAnimation(.easeOut(duration: 0.2)) {
            busyStreamingCloseToastID = nil
        }
    }

    private func resumeConversationInChat(_ result: HermesDashboardConversationResult) {
        guard !chatSession.isSending else { return }
        chatSession.resumeConversation(from: result)
        selectedWorkspace = .chat
        selectedPhoneSection = .chat
    }
}

private struct HermesTransientToast: View {
    let message: String
    var buttonTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            if let buttonTitle, let action {
                Button(buttonTitle, action: action)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white, in: Capsule())
                    .buttonStyle(.plain)
                    .accessibilityLabel(buttonTitle)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.hermesSurfaceInput.opacity(0.92), in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 16, x: 0, y: 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}
