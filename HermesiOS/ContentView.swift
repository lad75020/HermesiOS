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
    @AppStorage("hermes.utilities.clipboardHistoryMonitoringEnabled") private var isClipboardHistoryMonitoringEnabled = false

    @State private var selectedWorkspace: WorkspaceSection? = .responses
    @State private var selectedPhoneSection: WorkspaceSection = .responses
    @State private var apiSettings: HermesAPISettings
    @State private var companionSettings: HermesCompanionSettings
    @State private var agentConfiguration = HermesAgentConfiguration()
    @State private var responsesDraft: HermesRequestDraft
    @State private var responseWorkspaces: [HermesResponsesWorkspace]
    @State private var selectedResponseWorkspaceID: HermesResponsesWorkspace.ID
    @State private var tuiWorkspaces: [HermesTUIWorkspace]
    @State private var selectedTUIWorkspaceID: HermesTUIWorkspace.ID
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
        let initialTUIWorkspace = HermesTUIWorkspace(number: 1)
        _apiSettings = State(initialValue: HermesSettingsPersistence.loadAPISettings())
        _companionSettings = State(initialValue: HermesSettingsPersistence.loadCompanionSettings())
        _responsesDraft = State(initialValue: loadedResponsesDraft)
        _responseWorkspaces = State(initialValue: [initialResponseWorkspace])
        _selectedResponseWorkspaceID = State(initialValue: initialResponseWorkspace.id)
        _tuiWorkspaces = State(initialValue: [initialTUIWorkspace])
        _selectedTUIWorkspaceID = State(initialValue: initialTUIWorkspace.id)
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
        .overlay {
            if shouldShowPhoneConnectionIssueOverlay {
                phoneConnectionIssueOverlay
                    .transition(.scale(scale: 0.96).combined(with: .opacity))
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
        #if DEBUG
        .onAppear {
            installGstackSnapshotAccessors()
        }
        #endif
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
            guard !isShowingSplash, scenePhase == .active, isClipboardHistoryMonitoringEnabled else { return }
            await clipboardHistory.runMonitoringLoop(isEnabled: isClipboardHistoryMonitoringEnabled)
        }
        .task(id: statusLoopKey) {
            guard !isShowingSplash, scenePhase == .active else { return }
            await statusMonitor.runStatusLoop(
                apiSettings: apiSettings,
                companionSettings: companionSettings,
                dashboardURLString: dashboardURLString,
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
                    dashboardURLString: dashboardURLString,
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

    private var activeTUIWorkspace: HermesTUIWorkspace {
        if let workspace = tuiWorkspaces.first(where: { $0.id == selectedTUIWorkspaceID }) {
            return workspace
        }
        if let workspace = tuiWorkspaces.first {
            return workspace
        }
        return HermesTUIWorkspace(number: 1)
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

    private var isAnyTUIWorkspaceBusy: Bool {
        tuiWorkspaces.contains { $0.store.isConnecting || $0.store.isStreaming || $0.store.isResumingSession || $0.store.isRefreshingSessions }
    }

    private var isAnyTUIWorkspaceStreaming: Bool {
        tuiWorkspaces.contains { $0.store.isStreaming }
    }

    private var apiChannelActive: Bool {
        isAnyResponseWorkspaceStreaming || chatSession.isSending
    }

    private var companionChannelActive: Bool {
        companionEnrollment.isEnrolling || companionRuntime.isBusy
    }

    private var dashboardChannelActive: Bool {
        dashboardHistorySearchSession.isDashboardHTTPActive || isAnyTUIWorkspaceBusy
    }

    private var isAnyHermesStreamActive: Bool {
        isAnyResponseWorkspaceActivelyStreaming || chatSession.isStreaming || isAnyTUIWorkspaceStreaming
    }

    private var shouldShowPhoneConnectionIssueOverlay: Bool {
        !isShowingSplash
            && horizontalSizeClass == .compact
            && (statusMonitor.apiServerStatus == .down
                || statusMonitor.companionStatus == .down
                || statusMonitor.dashboardStatus == .down)
    }

    private var phoneConnectionIssueOverlay: some View {
        Text("Connection issue : Check settings")
            .font(.title2.weight(.heavy))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.igDestructive.opacity(0.94))
                    .shadow(color: Color.igDestructive.opacity(0.42), radius: 24, y: 12)
            )
            .padding(.horizontal, 28)
            .allowsHitTesting(false)
            .accessibilityLabel("Connection issue. Check settings")
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
            companionEnrollment.identityState.deviceSecretFingerprint,
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
            companionEnrollment.identityState.deviceSecretFingerprint.isEmpty ? "no-device-secret" : "device-secret-set"
        ].joined(separator: "|")
    }

    private var clipboardMonitoringKey: String {
        "scenePhase=\(scenePhase)|splash=\(isShowingSplash)|clipboard=\(isClipboardHistoryMonitoringEnabled)"
    }

    private var statusRefreshKey: String {
        [
            apiSettings.baseURL,
            apiSettings.apiKey.isEmpty ? "no-api-key" : "api-key-set",
            String(apiSettings.allowSelfSignedCertificates),
            companionSettings.apiURL,
            companionEnrollment.identityState.deviceSecretFingerprint.isEmpty ? "no-device-secret" : "device-secret-set",
            companionEnrollment.identityState.deviceID,
            companionEnrollment.identityState.serverEndpoint,
            dashboardURLString
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
                isTUIGatewayActive: isAnyTUIWorkspaceBusy,
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
            TabView(selection: $selectedPhoneSection) {
                NavigationStack {
                    responsesConsoleView(isPhoneLayout: true)
                }
                .tabItem {
                    Image(systemName: "dot.radiowaves.left.and.right")
                }
                .tag(WorkspaceSection.responses)

                NavigationStack {
                    HermesChatConsoleView(
                        apiSettings: $apiSettings,
                        chatDraft: $chatDraft,
                        dashboardURLString: dashboardURLString,
                        companionSettings: companionSettings,
                        companionEnrollment: companionEnrollment,
                        companionRuntime: companionRuntime,
                        chatSession: chatSession,
                        promptHistory: promptHistory,
                        isPhoneLayout: true
                    )
                }
                .tabItem {
                    Image(systemName: "text.bubble")
                }
                .tag(WorkspaceSection.chat)

                NavigationStack {
                    HermesTUIGatewayWorkspacesView(
                        apiSettings: $apiSettings,
                        dashboardURLString: dashboardURLString,
                        workspaces: tuiWorkspaces,
                        selectedWorkspaceID: selectedTUIWorkspaceBinding,
                        onSelectWorkspace: selectTUIWorkspace,
                        onAddWorkspace: createTUIWorkspace,
                        onDeleteWorkspace: deleteTUIWorkspace
                    )
                }
                .tabItem {
                    Image(systemName: "terminal.fill")
                }
                .tag(WorkspaceSection.tuiGateway)

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
                    Image(systemName: "clock.arrow.circlepath")
                }
                .tag(WorkspaceSection.history)

                NavigationStack {
                    HermesWebBrowserView(deckStore: webBrowserStore, dashboardURLString: dashboardURLString, officeURLString: officeURLString)
                }
                .tabItem {
                    Image(systemName: "globe")
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
                    Image(systemName: "terminal")
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
                    Image(systemName: "wrench.and.screwdriver")
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
                    Image(systemName: "slider.horizontal.3")
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
                        Image(systemName: "server.rack")
                    }
                    .tag(WorkspaceSection.runtime)
                }
            }
        }
    }

    @ViewBuilder
    private func responsesConsoleView(isPhoneLayout: Bool = false) -> some View {
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
            dashboardURLString: dashboardURLString,
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
            onSelectWorkspace: selectResponseWorkspace(number:),
            isPhoneLayout: isPhoneLayout
        )
    }

    private var selectedTUIWorkspaceBinding: Binding<HermesTUIWorkspace.ID> {
        Binding(
            get: { selectedTUIWorkspaceID },
            set: { selectedTUIWorkspaceID = $0 }
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

    private func createTUIWorkspace() {
        let nextNumber = (tuiWorkspaces.map(\.number).max() ?? 0) + 1
        let workspace = HermesTUIWorkspace(number: nextNumber)
        tuiWorkspaces.append(workspace)
        selectedTUIWorkspaceID = workspace.id
    }

    private func selectTUIWorkspace(_ workspace: HermesTUIWorkspace) {
        workspace.acknowledgeCurrentStatus()
        selectedTUIWorkspaceID = workspace.id
    }

    private func deleteTUIWorkspace(_ workspace: HermesTUIWorkspace) {
        guard !workspace.store.isStreaming,
              !workspace.store.isConnecting,
              !workspace.store.isResumingSession,
              let deletedIndex = tuiWorkspaces.firstIndex(where: { $0.id == workspace.id }) else { return }

        let wasSelected = selectedTUIWorkspaceID == workspace.id
        workspace.store.disconnect()
        tuiWorkspaces.remove(at: deletedIndex)

        if tuiWorkspaces.isEmpty {
            let replacement = HermesTUIWorkspace(number: 1)
            tuiWorkspaces = [replacement]
            selectedTUIWorkspaceID = replacement.id
        } else if wasSelected {
            let replacementIndex = min(deletedIndex, tuiWorkspaces.count - 1)
            selectedTUIWorkspaceID = tuiWorkspaces[replacementIndex].id
        }
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
                dashboardURLString: dashboardURLString,
                companionSettings: companionSettings,
                companionEnrollment: companionEnrollment,
                companionRuntime: companionRuntime,
                chatSession: chatSession,
                promptHistory: promptHistory
            )
        case .tuiGateway:
            HermesTUIGatewayWorkspacesView(
                apiSettings: $apiSettings,
                dashboardURLString: dashboardURLString,
                workspaces: tuiWorkspaces,
                selectedWorkspaceID: selectedTUIWorkspaceBinding,
                onSelectWorkspace: selectTUIWorkspace,
                onAddWorkspace: createTUIWorkspace,
                onDeleteWorkspace: deleteTUIWorkspace
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
        openChatWorkspace()
    }

    private func openChatWorkspace() {
        selectedWorkspace = .chat
        selectedPhoneSection = .chat
    }

    #if DEBUG
    @MainActor
    private func installGstackSnapshotAccessors() {
        let server = StateServer.shared
        server.register(buildId: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "debug", accessorHash: "hermesios-contentview-v1") { keys in
            if let raw = keys["ui.selected_workspace"] as? String, let section = WorkspaceSection(rawValue: raw) {
                selectedWorkspace = section
            } else if keys["ui.selected_workspace"] != nil {
                return .typeMismatch("ui.selected_workspace")
            }

            if let raw = keys["ui.selected_phone_section"] as? String, let section = WorkspaceSection(rawValue: raw) {
                selectedPhoneSection = section
            } else if keys["ui.selected_phone_section"] != nil {
                return .typeMismatch("ui.selected_phone_section")
            }

            if let raw = keys["settings.app_theme"] as? String, let theme = HermesAppTheme(rawValue: raw) {
                appTheme = theme
            } else if keys["settings.app_theme"] != nil {
                return .typeMismatch("settings.app_theme")
            }

            if let value = keys["settings.runtime_tab_enabled"] as? Bool {
                isRuntimeTabEnabled = value
            } else if keys["settings.runtime_tab_enabled"] != nil {
                return .typeMismatch("settings.runtime_tab_enabled")
            }

            if let value = keys["ui.is_splash_visible"] as? Bool {
                isShowingSplash = value
            } else if keys["ui.is_splash_visible"] != nil {
                return .typeMismatch("ui.is_splash_visible")
            }

            return .ok
        }

        server.registerAccessor(
            key: "ui.selected_workspace",
            type: "String<WorkspaceSection?>",
            read: { selectedWorkspace?.rawValue ?? NSNull() },
            write: { value in
                guard let raw = value as? String, let section = WorkspaceSection(rawValue: raw) else { return false }
                selectedWorkspace = section
                selectedPhoneSection = section
                return true
            }
        )
        server.registerAccessor(
            key: "ui.selected_phone_section",
            type: "String<WorkspaceSection>",
            read: { selectedPhoneSection.rawValue },
            write: { value in
                guard let raw = value as? String, let section = WorkspaceSection(rawValue: raw) else { return false }
                selectedPhoneSection = section
                selectedWorkspace = section
                return true
            }
        )
        server.registerAccessor(
            key: "ui.is_splash_visible",
            type: "Bool",
            read: { isShowingSplash },
            write: { value in
                guard let bool = value as? Bool else { return false }
                isShowingSplash = bool
                return true
            }
        )
        server.registerAccessor(
            key: "settings.runtime_tab_enabled",
            type: "Bool",
            read: { isRuntimeTabEnabled },
            write: { value in
                guard let bool = value as? Bool else { return false }
                isRuntimeTabEnabled = bool
                return true
            }
        )
        server.registerAccessor(
            key: "settings.app_theme",
            type: "String<HermesAppTheme>",
            read: { appTheme.rawValue },
            write: { value in
                guard let raw = value as? String, let theme = HermesAppTheme(rawValue: raw) else { return false }
                appTheme = theme
                return true
            }
        )
        server.registerAccessor(
            key: "settings.mac_host",
            type: "String",
            read: { macHost },
            write: { value in
                guard let string = value as? String, !string.isEmpty else { return false }
                macHost = string
                return true
            }
        )
        server.registerAccessor(
            key: "settings.dashboard_port",
            type: "String",
            read: { dashboardPort },
            write: { value in
                guard let string = value as? String, !string.isEmpty else { return false }
                dashboardPort = string
                return true
            }
        )
        server.registerAccessor(
            key: "settings.office_port",
            type: "String",
            read: { officePort },
            write: { value in
                guard let string = value as? String, !string.isEmpty else { return false }
                officePort = string
                return true
            }
        )
        server.registerAccessor(
            key: "responses.workspace_count",
            type: "Int(readonly)",
            read: { responseWorkspaces.count },
            write: { _ in false }
        )
        server.registerAccessor(
            key: "status.any_stream_active",
            type: "Bool(readonly)",
            read: { isAnyHermesStreamActive },
            write: { _ in false }
        )
    }
    #endif
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
