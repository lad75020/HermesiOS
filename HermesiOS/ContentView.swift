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
    @AppStorage(hermesOfficeURLStorageKey) private var officeURLString = defaultHermesOfficeURL

    @State private var selectedWorkspace: WorkspaceSection? = .responses
    @State private var selectedPhoneSection: WorkspaceSection = .responses
    @State private var apiSettings: HermesAPISettings
    @State private var companionSettings: HermesCompanionSettings
    @State private var agentConfiguration = HermesAgentConfiguration()
    @State private var responsesDraft: HermesRequestDraft
    @State private var responseSession = HermesResponsesSession()
    @State private var chatDraft: HermesChatDraft
    @State private var chatSession = HermesChatSession()
    @State private var companionEnrollment = HermesCompanionEnrollmentSession()
    @State private var companionRuntime = HermesCompanionRuntimeSession()
    @State private var statusMonitor = HermesStatusMonitor()
    @State private var dashboardHistorySearchSession = HermesDashboardHistorySearchSession()
    @State private var clipboardHistory = HermesClipboardHistoryStore()
    @StateObject private var officeWebViewStore = HermesOfficeWebViewStore()
    @State private var officeReloadID = UUID()
    @State private var isShowingSplash = true
    @State private var isResponsesCompletionUnread = false
    @State private var isChatCompletionUnread = false
    @State private var isHistorySearchCompletionUnread = false
    @State private var isResponsesFailureUnread = false
    @State private var isChatFailureUnread = false
    @State private var isHistorySearchFailureUnread = false

    init() {
        HermesAppearance.configureGlobalAppearance()
        HermesSettingsPersistence.removeLegacyLocalHistoryFile()
        _apiSettings = State(initialValue: HermesSettingsPersistence.loadAPISettings())
        _companionSettings = State(initialValue: HermesSettingsPersistence.loadCompanionSettings())
        _responsesDraft = State(initialValue: HermesSettingsPersistence.loadResponsesDraft())
        _chatDraft = State(initialValue: HermesSettingsPersistence.loadChatDraft())
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
        .background(Color.hermesCanvas)
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
        .task {
            guard isShowingSplash else { return }
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeOut(duration: 0.25)) {
                isShowingSplash = false
            }
        }
        .task(id: officePreloadKey) {
            guard !isShowingSplash else { return }
            officeWebViewStore.preload(urlString: officeURLString, reloadID: officeReloadID)
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
            guard newValue == .active else { return }
            Task {
                await statusMonitor.refresh(
                    apiSettings: apiSettings,
                    companionSettings: companionSettings,
                    identityState: companionEnrollment.identityState
                )
            }
        }
        .onChange(of: responseSession.connectionStatus) { _, newValue in
            if newValue == "Completed" {
                isResponsesFailureUnread = false
                isResponsesCompletionUnread = true
            } else if newValue == "Failed" {
                isResponsesCompletionUnread = false
                isResponsesFailureUnread = responseSession.lastErrorWasTimeoutOrNetworkLoss
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
    }


    private var apiChannelActive: Bool {
        responseSession.isSending || chatSession.isSending
    }

    private var companionChannelActive: Bool {
        companionEnrollment.isEnrolling || companionRuntime.isBusy
    }

    private var dashboardChannelActive: Bool {
        dashboardHistorySearchSession.isDashboardHTTPActive
    }

    private var statusLoopKey: String {
        statusRefreshKey + "|scenePhase=\(scenePhase)|splash=\(isShowingSplash)"
    }

    private var officePreloadKey: String {
        officeURLString + "|reload=\(officeReloadID.uuidString)|splash=\(isShowingSplash)"
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

    private var iPadLayout: some View {
        NavigationSplitView {
            WorkspaceSidebar(
                selection: $selectedWorkspace,
                statusMonitor: statusMonitor,
                responseSession: responseSession,
                chatSession: chatSession,
                apiChannelActive: apiChannelActive,
                companionChannelActive: companionChannelActive,
                dashboardChannelActive: dashboardChannelActive,
                isHistorySearchActive: dashboardHistorySearchSession.isSearching,
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
                    HermesResponsesConsoleView(
                        apiSettings: $apiSettings,
                        requestDraft: $responsesDraft,
                        companionSettings: companionSettings,
                        companionEnrollment: companionEnrollment,
                        companionRuntime: companionRuntime,
                        responseSession: responseSession
                    )
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
                        chatSession: chatSession
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
                        isResponsesStreaming: responseSession.isSending,
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
                    HermesUtilitiesView(
                        clipboardHistory: clipboardHistory,
                        responseSession: responseSession,
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
                        appTheme: $appTheme,
                        companionEnrollment: companionEnrollment,
                        companionRuntime: companionRuntime
                    )
                }
                .tabItem {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
                .tag(WorkspaceSection.settings)

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

    @ViewBuilder
    private func workspaceDetail(for section: WorkspaceSection) -> some View {
        switch section {
        case .responses:
            HermesResponsesConsoleView(
                apiSettings: $apiSettings,
                requestDraft: $responsesDraft,
                companionSettings: companionSettings,
                companionEnrollment: companionEnrollment,
                companionRuntime: companionRuntime,
                responseSession: responseSession
            )
        case .chat:
            HermesChatConsoleView(
                apiSettings: $apiSettings,
                chatDraft: $chatDraft,
                companionSettings: companionSettings,
                companionEnrollment: companionEnrollment,
                companionRuntime: companionRuntime,
                chatSession: chatSession
            )
        case .history:
            HermesHistoryView(
                apiSettings: $apiSettings,
                searchSession: dashboardHistorySearchSession,
                isResponsesStreaming: responseSession.isSending,
                isChatStreaming: chatSession.isSending,
                onResumeResponses: resumeConversationInResponses,
                onResumeChat: resumeConversationInChat
            )
        case .office:
            HermesOfficeView(webViewStore: officeWebViewStore, reloadID: $officeReloadID)
        case .utilities:
            HermesUtilitiesView(
                clipboardHistory: clipboardHistory,
                responseSession: responseSession,
                chatSession: chatSession,
                companionSettings: companionSettings,
                companionEnrollment: companionEnrollment,
                companionRuntime: companionRuntime
            )
        case .settings:
            HermesSettingsView(
                apiSettings: $apiSettings,
                companionSettings: $companionSettings,
                responsesDraft: $responsesDraft,
                chatDraft: $chatDraft,
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
        guard !responseSession.isSending else { return }
        responseSession.resumeConversation(from: result)
        selectedWorkspace = .responses
        selectedPhoneSection = .responses
    }

    private func resumeConversationInChat(_ result: HermesDashboardConversationResult) {
        guard !chatSession.isSending else { return }
        chatSession.resumeConversation(from: result)
        selectedWorkspace = .chat
        selectedPhoneSection = .chat
    }
}
