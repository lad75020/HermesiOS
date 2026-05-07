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
    @StateObject private var officeWebViewStore = HermesOfficeWebViewStore()
    @State private var isShowingSplash = true
    @State private var isShowingStreamDebugJSON = false

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
            Group {
                if horizontalSizeClass == .compact {
                    iPhoneLayout
                } else {
                    iPadLayout
                }
            }

            if isShowingSplash {
                HermesSplashView()
                    .transition(.opacity)
                    .zIndex(1)
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
        .task(id: statusLoopKey) {
            guard scenePhase == .active else { return }
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
        statusRefreshKey + "|scenePhase=\(scenePhase)"
    }

    private var statusRefreshKey: String {
        [
            apiSettings.baseURL,
            apiSettings.apiKey.isEmpty ? "no-api-key" : "api-key-set",
            String(apiSettings.allowSelfSignedCertificates),
            companionSettings.apiURL,
            companionSettings.expectedServerFingerprint,
            companionEnrollment.identityState.deviceID,
            companionEnrollment.identityState.serverEndpoint,
            companionEnrollment.identityState.serverCertificateFingerprint
        ].joined(separator: "|")
    }

    private var iPadLayout: some View {
        NavigationSplitView {
            WorkspaceSidebar(
                selection: $selectedWorkspace,
                statusMonitor: statusMonitor,
                responseSession: responseSession,
                chatSession: chatSession,
                isShowingStreamDebugJSON: $isShowingStreamDebugJSON,
                selectedDebugStreamSource: selectedWorkspace == .chat ? .chat : .responses,
                apiChannelActive: apiChannelActive,
                companionChannelActive: companionChannelActive,
                dashboardChannelActive: dashboardChannelActive
            )
            .navigationTitle("Hermes")
                .navigationSplitViewColumnWidth(min: 260, ideal: 280, max: 320)
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
                        responseSession: responseSession
                    )
                }
                .tabItem {
                    Label("Responses", systemImage: "dot.radiowaves.left.and.right")
                }
                .tag(WorkspaceSection.responses)

                NavigationStack {
                    HermesChatConsoleView(
                        apiSettings: $apiSettings,
                        chatDraft: $chatDraft,
                        chatSession: chatSession
                    )
                }
                .tabItem {
                    Label("Chat", systemImage: "text.bubble")
                }
                .tag(WorkspaceSection.chat)

                NavigationStack {
                    HermesHistoryView(
                        apiSettings: $apiSettings,
                        searchSession: dashboardHistorySearchSession,
                        onResumeConversation: resumeConversationInResponses
                    )
                }
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(WorkspaceSection.history)

                NavigationStack {
                    HermesOfficeView(webViewStore: officeWebViewStore)
                }
                .tabItem {
                    Label("Office", systemImage: "building.2.crop.circle")
                }
                .tag(WorkspaceSection.office)

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
                responseSession: responseSession
            )
        case .chat:
            HermesChatConsoleView(
                apiSettings: $apiSettings,
                chatDraft: $chatDraft,
                chatSession: chatSession
            )
        case .history:
            HermesHistoryView(
                apiSettings: $apiSettings,
                searchSession: dashboardHistorySearchSession,
                onResumeConversation: resumeConversationInResponses
            )
        case .office:
            HermesOfficeView(webViewStore: officeWebViewStore)
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
        responseSession.resumeConversation(from: result)
        selectedWorkspace = .responses
        selectedPhoneSection = .responses
    }
}
