//
//  ContentView.swift
//  HermesiOS
//
//  Created by Laurent Dubertrand on 04/05/2026.
//

import Observation
import PhotosUI
import SwiftUI
import Vision
import VisionKit

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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

    init() {
        _apiSettings = State(initialValue: HermesSettingsPersistence.loadAPISettings())
        _companionSettings = State(initialValue: HermesSettingsPersistence.loadCompanionSettings())
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
        .onChange(of: companionSettings) { _, newValue in
            HermesSettingsPersistence.saveCompanionSettings(newValue)
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
                    companionSettings: $companionSettings,
                    responsesDraft: $responsesDraft,
                    chatDraft: $chatDraft,
                    companionEnrollment: companionEnrollment
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
                companionEnrollment: companionEnrollment
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
    @Binding var companionSettings: HermesCompanionSettings
    @Binding var responsesDraft: HermesRequestDraft
    @Binding var chatDraft: HermesChatDraft
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @State private var isPairingScannerPresented = false
    @State private var selectedPairingQRImage: PhotosPickerItem?

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

            Section("Host Companion") {
                TextField("Enrollment URL", text: $companionSettings.enrollmentURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("API URL", text: $companionSettings.apiURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Hermes workspace path", text: $companionSettings.hermesWorkspacePath)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Device name", text: $companionSettings.deviceName)

                TextField("Server fingerprint", text: $companionSettings.expectedServerFingerprint, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .lineLimit(3, reservesSpace: true)

                TextField("Pairing ID", text: $companionSettings.pairingID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Pairing secret", text: $companionSettings.pairingSecret)

                Button("Scan Pairing QR") {
                    isPairingScannerPresented = true
                }
                .disabled(HermesPairingQRScannerView.isSupported == false)

                PhotosPicker(selection: $selectedPairingQRImage, matching: .images) {
                    Label("Pick Pairing QR Image", systemImage: "photo")
                }

                settingsRow(label: "Enrollment Status", value: companionEnrollment.connectionStatus)

                if companionEnrollment.identityState.isEnrolled {
                    settingsRow(label: "Enrolled Device", value: companionEnrollment.identityState.deviceName)
                    settingsRow(label: "Device ID", value: companionEnrollment.identityState.deviceID)
                    settingsRow(label: "Pinned Fingerprint", value: companionEnrollment.identityState.serverCertificateFingerprint)
                    settingsRow(label: "Companion Endpoint", value: companionEnrollment.identityState.serverEndpoint)
                }

                if !companionEnrollment.lastErrorMessage.isEmpty {
                    Text(companionEnrollment.lastErrorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }

                HStack {
                    Button(companionEnrollment.identityState.isEnrolled ? "Re-enroll" : "Enroll Device") {
                        companionEnrollment.enroll(settings: companionSettings)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        companionEnrollment.isEnrolling ||
                        companionSettings.enrollmentURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        companionSettings.expectedServerFingerprint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        companionSettings.pairingID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        companionSettings.pairingSecret.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )

                    if companionEnrollment.identityState.isEnrolled {
                        Button("Clear Identity", role: .destructive) {
                            companionEnrollment.clearIdentity()
                        }
                        .buttonStyle(.bordered)
                    }
                }
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
                Text("For the host companion, copy the server fingerprint from the macOS app, create a pairing there, then enroll this device to import its client certificate.")
                Text("Set the Hermes workspace path to the host-side `.hermes` directory you want the Skills panel to manage.")
            }
            .foregroundStyle(.secondary)
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $isPairingScannerPresented) {
            HermesPairingQRScannerView { payload in
                applyPairingPayload(payload)
                isPairingScannerPresented = false
            }
        }
        .task(id: selectedPairingQRImage) {
            guard let selectedPairingQRImage else { return }
            do {
                guard let imageData = try await selectedPairingQRImage.loadTransferable(type: Data.self) else {
                    throw HermesCompanionClientError.invalidPairingQRCode
                }
                let payload = try HermesPairingImageDecoder.decode(from: imageData)
                applyPairingPayload(payload)
                self.selectedPairingQRImage = nil
            } catch {
                companionEnrollment.lastErrorMessage = error.localizedDescription
                self.selectedPairingQRImage = nil
            }
        }
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

    private func applyPairingPayload(_ payload: HermesCompanionPairingQRCodePayload) {
        companionSettings.enrollmentURL = payload.enrollmentURL
        companionSettings.apiURL = payload.apiURL
        companionSettings.expectedServerFingerprint = payload.serverFingerprint
        companionSettings.pairingID = payload.pairingID
        companionSettings.pairingSecret = payload.pairingSecret
    }
}

private struct HermesPairingQRScannerView: View {
    static var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    let onPayload: (HermesCompanionPairingQRCodePayload) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Group {
                if Self.isSupported {
                    HermesDataScannerContainer { scannedValue in
                        do {
                            let payload = try HermesCompanionPairingPayloadDecoder.decode(scannedValue)
                            onPayload(payload)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                } else {
                    ContentUnavailableView(
                        "Scanner Unavailable",
                        systemImage: "qrcode.viewfinder",
                        description: Text("QR scanning requires a real camera-backed iOS device. The simulator cannot scan pairing codes.")
                    )
                }
            }
            .navigationTitle("Scan Pairing QR")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding()
                }
            }
        }
    }
}

private struct HermesDataScannerContainer: UIViewControllerRepresentable {
    let onScannedValue: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScannedValue: onScannedValue)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        try? controller.startScanning()
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onScannedValue: (String) -> Void
        private var hasScanned = false

        init(onScannedValue: @escaping (String) -> Void) {
            self.onScannedValue = onScannedValue
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard hasScanned == false else { return }
            for item in addedItems {
                guard case .barcode(let barcode) = item else { continue }
                guard let payload = barcode.payloadStringValue, payload.isEmpty == false else { continue }
                hasScanned = true
                dataScanner.stopScanning()
                onScannedValue(payload)
                return
            }
        }
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
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession

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
                    subtitle: "\(companionRuntime.hermesSkills.filter(\.isEnabled).count) enabled, \(companionRuntime.hermesSkills.count) visible in workspace",
                    systemImage: "square.stack.3d.up.fill",
                    isExpanded: Binding(
                        get: { agentConfiguration.activeRuntimePanel == .skills },
                        set: { isExpanded in
                            agentConfiguration.activeRuntimePanel = isExpanded ? .skills : nil
                        }
                    )
                ) {
                    HermesSkillsPanel(
                        agentConfiguration: $agentConfiguration,
                        companionSettings: companionSettings,
                        companionEnrollment: companionEnrollment,
                        companionRuntime: companionRuntime
                    )
                }

                HermesRuntimeAccordionPanel(
                    title: "Companion",
                    subtitle: companionEnrollment.identityState.isEnrolled ? companionRuntime.connectionStatus : "Enroll an iOS client certificate to unlock host operations",
                    systemImage: "lock.laptopcomputer",
                    isExpanded: Binding(
                        get: { agentConfiguration.activeRuntimePanel == .companion },
                        set: { isExpanded in
                            agentConfiguration.activeRuntimePanel = isExpanded ? .companion : nil
                        }
                    )
                ) {
                    HermesCompanionPanel(
                        companionSettings: companionSettings,
                        companionEnrollment: companionEnrollment,
                        companionRuntime: companionRuntime
                    )
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

                HermesRuntimeAccordionPanel(
                    title: "Tools",
                    subtitle: "\(companionRuntime.hermesToolsets.filter(\.enabled).count) enabled, \(companionRuntime.hermesToolsets.count) available in config",
                    systemImage: "wrench.and.screwdriver",
                    isExpanded: Binding(
                        get: { agentConfiguration.activeRuntimePanel == .tools },
                        set: { isExpanded in
                            agentConfiguration.activeRuntimePanel = isExpanded ? .tools : nil
                        }
                    )
                ) {
                    HermesToolsPanel(
                        companionSettings: companionSettings,
                        companionEnrollment: companionEnrollment,
                        companionRuntime: companionRuntime
                    )
                }

                HermesRuntimeAccordionPanel(
                    title: "Models",
                    subtitle: "\(companionRuntime.hermesModels.count) saved in workspace inventory",
                    systemImage: "cpu",
                    isExpanded: Binding(
                        get: { agentConfiguration.activeRuntimePanel == .models },
                        set: { isExpanded in
                            agentConfiguration.activeRuntimePanel = isExpanded ? .models : nil
                        }
                    )
                ) {
                    HermesModelsPanel(
                        companionSettings: companionSettings,
                        companionEnrollment: companionEnrollment,
                        companionRuntime: companionRuntime
                    )
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

private struct HermesCompanionPanel: View {
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if companionEnrollment.identityState.isEnrolled == false {
                ContentUnavailableView(
                    "Enrollment Required",
                    systemImage: "person.badge.key",
                    description: Text("Use Settings → Host Companion to enroll this iOS device and import its client identity before attempting host configuration changes.")
                )
            } else {
                HermesStatusRow(
                    items: [
                        .init(title: "Companion", value: companionRuntime.connectionStatus, accent: .blue),
                        .init(title: "Service", value: companionRuntime.linkedServiceStatus.isEmpty ? "Unknown" : companionRuntime.linkedServiceStatus, accent: .green)
                    ]
                )

                HermesSectionCard("Allowlisted Targets") {
                    VStack(alignment: .leading, spacing: 14) {
                        if !companionRuntime.lastErrorMessage.isEmpty {
                            Text(companionRuntime.lastErrorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }

                        if companionRuntime.targets.isEmpty {
                            Text("Fetch the host companion target registry to begin editing allowlisted files.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Target", selection: $companionRuntime.selectedTargetID) {
                                ForEach(companionRuntime.targets) { target in
                                    Text(target.displayName).tag(target.id)
                                }
                            }
                            .pickerStyle(.menu)

                            if let selectedTarget = companionRuntime.selectedTarget {
                                Text(selectedTarget.path)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }

                        HStack {
                            Button("Refresh Targets") {
                                companionRuntime.refreshTargets(
                                    settings: companionSettings,
                                    identityState: companionEnrollment.identityState
                                )
                            }
                            .buttonStyle(.borderedProminent)

                            if !companionRuntime.selectedTargetID.isEmpty {
                                Button("Reload Target") {
                                    companionRuntime.loadSelectedTarget(
                                        settings: companionSettings,
                                        identityState: companionEnrollment.identityState
                                    )
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                if companionRuntime.selectedTarget != nil {
                    HermesSectionCard("Target Editor") {
                        VStack(alignment: .leading, spacing: 14) {
                            if !companionRuntime.currentRevision.isEmpty {
                                Label("Revision: \(companionRuntime.currentRevision)", systemImage: "number")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            TextEditor(text: $companionRuntime.targetContent)
                                .font(.system(.body, design: .monospaced))
                                .frame(minHeight: 240)

                            HStack {
                                Button("Validate") {
                                    companionRuntime.validateSelectedTarget(
                                        settings: companionSettings,
                                        identityState: companionEnrollment.identityState
                                    )
                                }
                                .buttonStyle(.bordered)

                                Button("Save with Backup") {
                                    companionRuntime.saveSelectedTarget(
                                        settings: companionSettings,
                                        identityState: companionEnrollment.identityState
                                    )
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }

                    HermesSectionCard("Validation") {
                        if companionRuntime.diagnostics.isEmpty {
                            Text("Run validation to inspect syntax and policy diagnostics before writing to the host.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(companionRuntime.diagnostics) { diagnostic in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(diagnostic.severity.rawValue.capitalized)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(severityColor(for: diagnostic.severity))
                                            Spacer()
                                            Text(diagnostic.validator)
                                                .font(.caption.monospaced())
                                                .foregroundStyle(.secondary)
                                        }
                                        Text(diagnostic.message)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                            }
                        }
                    }

                    HermesSectionCard("Linked Service") {
                        VStack(alignment: .leading, spacing: 14) {
                            if let serviceID = companionRuntime.selectedTarget?.serviceID, !serviceID.isEmpty {
                                Label("Service: \(serviceID)", systemImage: "server.rack")
                                    .font(.subheadline.weight(.semibold))
                                Text(companionRuntime.linkedServiceOutput.isEmpty ? "No service output returned yet." : companionRuntime.linkedServiceOutput)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)

                                HStack {
                                    Button("Refresh Service Status") {
                                        companionRuntime.refreshLinkedServiceStatus(
                                            settings: companionSettings,
                                            identityState: companionEnrollment.identityState
                                        )
                                    }
                                    .buttonStyle(.bordered)

                                    Button("Restart Service") {
                                        companionRuntime.restartLinkedService(
                                            settings: companionSettings,
                                            identityState: companionEnrollment.identityState
                                        )
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            } else {
                                Text("The selected target is not associated with a managed service.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .task(id: companionEnrollment.identityState.deviceID) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            if companionRuntime.targets.isEmpty {
                companionRuntime.refreshTargets(
                    settings: companionSettings,
                    identityState: companionEnrollment.identityState
                )
            }
        }
    }

    private func severityColor(for severity: HermesCompanionValidationSeverity) -> Color {
        switch severity {
        case .error:
            .red
        case .warning:
            .orange
        case .info:
            .blue
        }
    }
}

private struct HermesToolsPanel: View {
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if companionEnrollment.identityState.isEnrolled == false {
                ContentUnavailableView(
                    "Enrollment Required",
                    systemImage: "person.badge.key",
                    description: Text("Use Settings → Host Companion to enroll this iOS device before editing Hermes toolsets.")
                )
            } else {
                HermesSectionCard("Hermes Toolsets") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("This panel mirrors the desktop toolset editor and writes `platform_toolsets.cli` in the live Hermes `config.yaml` for the configured workspace.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        companionSummaryRow(label: "Workspace", value: companionRuntime.resolvedHermesWorkspacePath.isEmpty ? companionSettings.hermesWorkspacePath : companionRuntime.resolvedHermesWorkspacePath)
                        companionSummaryRow(label: "Config", value: companionRuntime.toolsetsConfigPath.isEmpty ? "\(companionSettings.hermesWorkspacePath)/config.yaml" : companionRuntime.toolsetsConfigPath)

                        if !companionRuntime.lastErrorMessage.isEmpty {
                            Text(companionRuntime.lastErrorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }

                        if companionRuntime.hermesToolsets.isEmpty {
                            Text("Open this panel after enrollment to load the toolsets declared by Hermes desktop semantics.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(companionRuntime.hermesToolsets) { toolset in
                                    HermesToolsetToggleRow(
                                        toolset: toolset,
                                        isEnabled: Binding(
                                            get: {
                                                companionRuntime.hermesToolsets.first(where: { $0.key == toolset.key })?.enabled ?? toolset.enabled
                                            },
                                            set: { isEnabled in
                                                companionRuntime.setHermesToolsetEnabled(
                                                    key: toolset.key,
                                                    enabled: isEnabled,
                                                    settings: companionSettings,
                                                    identityState: companionEnrollment.identityState
                                                )
                                            }
                                        )
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        .task(id: companionEnrollment.identityState.deviceID) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            companionRuntime.refreshHermesToolsets(settings: companionSettings, identityState: companionEnrollment.identityState)
        }
        .task(id: companionSettings.hermesWorkspacePath) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            companionRuntime.refreshHermesToolsets(settings: companionSettings, identityState: companionEnrollment.identityState)
        }
    }

    private func companionSummaryRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .fontWeight(.semibold)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .font(.subheadline)
    }
}

private struct HermesModelsPanel: View {
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession
    @State private var newModelName = ""
    @State private var newModelProvider = ""
    @State private var newModelID = ""
    @State private var newModelBaseURL = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if companionEnrollment.identityState.isEnrolled == false {
                ContentUnavailableView(
                    "Enrollment Required",
                    systemImage: "person.badge.key",
                    description: Text("Use Settings → Host Companion to enroll this iOS device before editing Hermes saved models.")
                )
            } else {
                HermesSectionCard("Saved Models") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("This panel mirrors the desktop models registry and edits the live `models.json` inventory in the configured Hermes workspace.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        companionSummaryRow(label: "Workspace", value: companionRuntime.resolvedHermesWorkspacePath.isEmpty ? companionSettings.hermesWorkspacePath : companionRuntime.resolvedHermesWorkspacePath)
                        companionSummaryRow(label: "Models File", value: companionRuntime.modelsFilePath.isEmpty ? "\(companionSettings.hermesWorkspacePath)/models.json" : companionRuntime.modelsFilePath)

                        if !companionRuntime.lastErrorMessage.isEmpty {
                            Text(companionRuntime.lastErrorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.red)
                        }

                        HermesSectionCard("Add Model") {
                            VStack(alignment: .leading, spacing: 12) {
                                TextField("Display name", text: $newModelName)
                                TextField("Provider", text: $newModelProvider)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                TextField("Model ID", text: $newModelID)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                TextField("Base URL", text: $newModelBaseURL)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()

                                Button("Add Model") {
                                    companionRuntime.addHermesModel(
                                        name: newModelName.trimmingCharacters(in: .whitespacesAndNewlines),
                                        provider: newModelProvider.trimmingCharacters(in: .whitespacesAndNewlines),
                                        model: newModelID.trimmingCharacters(in: .whitespacesAndNewlines),
                                        baseURL: newModelBaseURL.trimmingCharacters(in: .whitespacesAndNewlines),
                                        settings: companionSettings,
                                        identityState: companionEnrollment.identityState
                                    )
                                    newModelName = ""
                                    newModelProvider = ""
                                    newModelID = ""
                                    newModelBaseURL = ""
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(
                                    newModelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                    newModelProvider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                                    newModelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                )
                            }
                        }

                        if companionRuntime.hermesModels.isEmpty {
                            Text("Loading models will seed the default desktop model list if `models.json` does not already exist.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(companionRuntime.hermesModels) { model in
                                    HermesSavedModelEditorCard(
                                        model: model,
                                        onSave: { name, provider, modelID, baseURL in
                                            companionRuntime.updateHermesModel(
                                                id: model.id,
                                                name: name,
                                                provider: provider,
                                                model: modelID,
                                                baseURL: baseURL,
                                                settings: companionSettings,
                                                identityState: companionEnrollment.identityState
                                            )
                                        },
                                        onRemove: {
                                            companionRuntime.removeHermesModel(
                                                id: model.id,
                                                settings: companionSettings,
                                                identityState: companionEnrollment.identityState
                                            )
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        .task(id: companionEnrollment.identityState.deviceID) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            companionRuntime.refreshHermesModels(settings: companionSettings, identityState: companionEnrollment.identityState)
        }
        .task(id: companionSettings.hermesWorkspacePath) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            companionRuntime.refreshHermesModels(settings: companionSettings, identityState: companionEnrollment.identityState)
        }
    }

    private func companionSummaryRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .fontWeight(.semibold)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .font(.subheadline)
    }
}

private struct HermesSkillsPanel: View {
    @Binding var agentConfiguration: HermesAgentConfiguration
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession

    private var filteredHermesSkills: [HermesCompanionSkillSummary] {
        let query = agentConfiguration.skillSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return companionRuntime.hermesSkills }
        return companionRuntime.hermesSkills.filter { skill in
            skill.name.lowercased().hasPrefix(query.lowercased())
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if companionEnrollment.identityState.isEnrolled {
                HermesSectionCard("Companion Skills Store") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Skills are loaded from the configured Hermes workspace and toggles write the live `.hermes/skills/.usage.json` state on the host companion.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        settingsSummaryRow(label: "Workspace", value: companionRuntime.resolvedHermesWorkspacePath.isEmpty ? companionSettings.hermesWorkspacePath : companionRuntime.resolvedHermesWorkspacePath)

                        Text(companionRuntime.isBusy ? "Syncing…" : "\(companionRuntime.hermesSkills.filter(\.isEnabled).count) enabled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            TextField("Start with", text: $agentConfiguration.skillSearchQuery)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            let visibleSkills = filteredHermesSkills
            if visibleSkills.isEmpty {
                ContentUnavailableView(
                    "No Skills Found",
                    systemImage: "magnifyingglass",
                    description: Text(companionEnrollment.identityState.isEnrolled ? "Enter the beginning of a skill name or verify the Hermes workspace path in Settings." : "Enroll the host companion first, then load skills from the Hermes workspace.")
                )
            } else {
                HermesSectionCard("Skills Catalog") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Toggle any skill on to mark it active in Hermes, or off to archive it from the live workspace state.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ForEach(visibleSkills) { skill in
                            HermesSkillToggleRow(
                                skill: skill,
                                isEnabled: Binding(
                                    get: {
                                        companionRuntime.hermesSkills.first(where: { $0.id == skill.id })?.isEnabled ?? skill.isEnabled
                                    },
                                    set: { isEnabled in
                                        companionRuntime.setHermesSkillState(
                                            skillID: skill.id,
                                            isEnabled: isEnabled,
                                            settings: companionSettings,
                                            identityState: companionEnrollment.identityState
                                        )
                                    }
                                )
                            )
                        }
                    }
                }
            }
        }
        .task(id: companionEnrollment.identityState.deviceID) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            companionRuntime.refreshHermesSkills(settings: companionSettings, identityState: companionEnrollment.identityState)
        }
        .task(id: companionSettings.hermesWorkspacePath) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            companionRuntime.refreshHermesSkills(settings: companionSettings, identityState: companionEnrollment.identityState)
        }
    }

    private func settingsSummaryRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .fontWeight(.semibold)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .font(.subheadline)
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

private struct HermesSkillToggleRow: View {
    let skill: HermesCompanionSkillSummary
    @Binding var isEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(skill.name)
                            .font(.headline)
                        Text(isEnabled ? "On" : "Off")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isEnabled ? .green : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background((isEnabled ? Color.green : Color.secondary).opacity(0.12))
                            .clipShape(Capsule())
                    }

                    Text(skill.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        Text(skill.category.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.08))
                            .clipShape(Capsule())
                    }

                    Text(skill.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct HermesToolsetToggleRow: View {
    let toolset: HermesCompanionToolsetInfo
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(toolset.label)
                        .font(.headline)
                    Text(toolset.enabled ? "On" : "Off")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(toolset.enabled ? .green : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background((toolset.enabled ? Color.green : Color.secondary).opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(toolset.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(toolset.key)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 12)

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct HermesSavedModelEditorCard: View {
    let model: HermesCompanionSavedModel
    let onSave: (String, String, String, String) -> Void
    let onRemove: () -> Void
    @State private var name: String
    @State private var provider: String
    @State private var modelID: String
    @State private var baseURL: String

    init(
        model: HermesCompanionSavedModel,
        onSave: @escaping (String, String, String, String) -> Void,
        onRemove: @escaping () -> Void
    ) {
        self.model = model
        self.onSave = onSave
        self.onRemove = onRemove
        _name = State(initialValue: model.name)
        _provider = State(initialValue: model.provider)
        _modelID = State(initialValue: model.model)
        _baseURL = State(initialValue: model.baseURL)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.createdAtDate.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Display name", text: $name)
            TextField("Provider", text: $provider)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Model ID", text: $modelID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Base URL", text: $baseURL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            HStack {
                Button("Save") {
                    onSave(
                        name.trimmingCharacters(in: .whitespacesAndNewlines),
                        provider.trimmingCharacters(in: .whitespacesAndNewlines),
                        modelID.trimmingCharacters(in: .whitespacesAndNewlines),
                        baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    modelID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                )

                Button("Remove", role: .destructive) {
                    onRemove()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
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
    case companion
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
        .init(kind: .sandbox, title: "Sandbox", subtitle: "Filesystem and network boundaries", systemImage: "lock.square.stack", placeholder: "Workspace-write, read-only, and network isolation controls can be configured here."),
        .init(kind: .memory, title: "Memory", subtitle: "Persistent context and workspace notes", systemImage: "brain.head.profile", placeholder: "Persistent notes, workspace memory, and user-level memory toggles fit naturally in this section."),
        .init(kind: .observability, title: "Observability", subtitle: "Logs, traces, and runtime diagnostics", systemImage: "waveform.and.magnifyingglass", placeholder: "Runtime logs, traces, and environment diagnostics can be collected and displayed here.")
    ]
}

private struct HermesAgentConfiguration {
    var backend: HermesTerminalBackend = .local
    var persistentShell = true
    var workingDirectory = "."
    var sshHost = ""
    var sshUser = ""
    var sshPort = "22"
    var sshKeyPath = "~/.ssh/id_rsa"
    var activeRuntimePanel: HermesRuntimePanelKind? = .companion
    var skillSearchQuery = ""

    var backendSummary: String {
        switch backend {
        case .local:
            "Commands execute directly on the device host running Hermes. This is the fastest path for initial gateway integration."
        case .ssh:
            "Commands execute on a remote server over SSH with a persistent shell, which is the right fit once the app starts managing remote agents."
        }
    }

}

#Preview("Default") {
    ContentView()
}
