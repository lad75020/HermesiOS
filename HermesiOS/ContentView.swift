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
    @AppStorage("hermes.appTheme") private var appTheme: HermesAppTheme = .system

    @State private var selectedWorkspace: WorkspaceSection? = .responses
    @State private var apiSettings: HermesAPISettings
    @State private var companionSettings: HermesCompanionSettings
    @State private var agentConfiguration = HermesAgentConfiguration()
    @State private var responsesDraft: HermesRequestDraft
    @State private var responseSession = HermesResponsesSession()
    @State private var chatDraft: HermesChatDraft
    @State private var chatSession = HermesChatSession()
    @State private var historyStore = HermesHistoryStore()
    @State private var companionEnrollment = HermesCompanionEnrollmentSession()
    @State private var companionRuntime = HermesCompanionRuntimeSession()
    @State private var statusMonitor = HermesStatusMonitor()
    @State private var isShowingSplash = true

    init() {
        HermesAppearance.configureGlobalAppearance()
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
        .task(id: statusRefreshKey) {
            await statusMonitor.runStatusLoop(
                apiSettings: apiSettings,
                companionSettings: companionSettings,
                identityState: companionEnrollment.identityState
            )
        }
    }


    private var apiChannelActive: Bool {
        responseSession.isSending || chatSession.isSending
    }

    private var companionChannelActive: Bool {
        companionEnrollment.isEnrolling || companionRuntime.isBusy
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
                apiChannelActive: apiChannelActive,
                companionChannelActive: companionChannelActive
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
                companionChannelActive: companionChannelActive
            )

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
}
