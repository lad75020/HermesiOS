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
        HermesAppearance.configureGlobalAppearance()
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
        .background(Color.hermesCanvas)
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
                        .foregroundStyle(.hermesSecondaryText)
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(Color.hermesCanvas)
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
                        .init(title: "Thread", value: responseSession.previousResponseID.isEmpty ? "New response" : "Continuing thread", accent: .igGradPurple),
                        .init(title: "Status", value: responseSession.connectionStatus, accent: .igGradOrange)
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
                                    .foregroundStyle(.hermesSecondaryText)
                                    .textSelection(.enabled)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        TextEditor(text: $requestDraft.userPrompt)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 160)
                            .igFieldBackground()
                            .overlay(alignment: .topLeading) {
                                if requestDraft.userPrompt.isEmpty {
                                    Text("Ask Hermes to inspect files, run tools, or explain context...")
                                        .foregroundStyle(.hermesSecondaryText)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 8)
                                        .allowsHitTesting(false)
                                }
                            }

                        HStack {
                            Label("Send a prompt and inspect Hermes events", systemImage: "waveform.path.ecg")
                                .font(.footnote)
                                .foregroundStyle(.hermesSecondaryText)
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
                                .foregroundStyle(.hermesSecondaryText)
                        }

                        if !responseSession.latestResponseID.isEmpty {
                            Label("Response ID: \(responseSession.latestResponseID)", systemImage: "number")
                                .font(.caption)
                                .foregroundStyle(.hermesSecondaryText)
                        }

                        if !responseSession.lastErrorMessage.isEmpty {
                            Text(responseSession.lastErrorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.igDestructive)
                        }

                        Group {
                            if responseSession.streamedText.isEmpty {
                                Text("Send a `/v1/responses` request to populate streamed assistant output here.")
                                    .foregroundStyle(.hermesSecondaryText)
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
                            .foregroundStyle(.hermesSecondaryText)

                        if responseSession.entries.isEmpty {
                            Text("The SSE event stream will appear here, including `response.created`, text deltas, tool events, and completion.")
                                .font(.subheadline)
                                .foregroundStyle(.hermesSecondaryText)
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
        .background(Color.hermesCanvas)
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
                        .init(title: "History", value: "\(chatSession.entries.count) messages", accent: .igGradPurple),
                        .init(title: "Status", value: chatSession.connectionStatus, accent: .igGradOrange)
                    ]
                )

                HermesSectionCard("Message Draft") {
                    VStack(alignment: .leading, spacing: 14) {
                        TextEditor(text: $chatDraft.userPrompt)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 160)
                            .igFieldBackground()
                            .overlay(alignment: .topLeading) {
                                if chatDraft.userPrompt.isEmpty {
                                    Text("Send a message to Hermes using the chat completions format...")
                                        .foregroundStyle(.hermesSecondaryText)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 8)
                                        .allowsHitTesting(false)
                                }
                            }

                        HStack {
                            Label("Chat transcript stays separate from `/v1/responses`", systemImage: "rectangle.split.3x1")
                                .font(.footnote)
                                .foregroundStyle(.hermesSecondaryText)
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
                                .foregroundStyle(.igDestructive)
                        }

                        Group {
                            if chatSession.streamedText.isEmpty {
                                Text("Send a `/v1/chat/completions` message to populate assistant output here.")
                                    .foregroundStyle(.hermesSecondaryText)
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
                            .foregroundStyle(.hermesSecondaryText)

                        if chatSession.entries.isEmpty {
                            Text("User and assistant messages from the chat completions session will accumulate here.")
                                .font(.subheadline)
                                .foregroundStyle(.hermesSecondaryText)
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
        .background(Color.hermesCanvas)
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
                        .foregroundStyle(.igDestructive)
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
            .foregroundStyle(.hermesSecondaryText)
        }
        .navigationTitle("Settings")
        .scrollContentBackground(.hidden)
        .background(Color.hermesCanvas)
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
                .foregroundStyle(.hermesSecondaryText)
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
                        .foregroundStyle(.igDestructive)
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
                                .foregroundStyle(.hermesSecondaryText)
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .scrollContentBackground(.hidden)
        .background(Color.hermesCanvas)
    }
}

private struct HermesAgentConfigView: View {
    @Binding var agentConfiguration: HermesAgentConfiguration
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession

    private var providerSummary: String {
        if companionEnrollment.identityState.isEnrolled == false {
            return "Enroll companion to edit provider keys and model defaults"
        }
        let configuredKeys = companionRuntime.providerEnv.filter { !$0.value.isEmpty }.count
        let provider = companionRuntime.providerModelConfig.provider
        let model = companionRuntime.providerModelConfig.model
        if model.isEmpty {
            return "\(configuredKeys) environment values, provider \(provider)"
        }
        return "\(provider) · \(model) · \(configuredKeys) environment values"
    }

    private var memorySummary: String {
        if companionEnrollment.identityState.isEnrolled == false {
            return "Enroll companion to manage host memory"
        }
        if let config = companionRuntime.memoryConfig {
            let provider = config.provider.isEmpty ? "local" : config.provider
            return "\(companionRuntime.memoryEntries.count) memories · \(provider) · \(config.stats.totalSessions) sessions"
        }
        return "Agent memory, user profile, and memory providers"
    }

    private var schedulesSummary: String {
        if companionEnrollment.identityState.isEnrolled == false {
            return "Enroll companion to manage scheduled jobs"
        }
        let active = companionRuntime.schedules.filter { $0.state == "active" }.count
        let paused = companionRuntime.schedules.filter { $0.state == "paused" }.count
        return "\(active) active, \(paused) paused, \(companionRuntime.schedules.count) total"
    }

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
                            .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
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
                            .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("User", text: $agentConfiguration.sshUser)
                            .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Port", text: $agentConfiguration.sshPort)
                            .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
                            .keyboardType(.numberPad)
                        TextField("Private key path", text: $agentConfiguration.sshKeyPath)
                            .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
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
                    title: "Providers",
                    subtitle: providerSummary,
                    systemImage: "key.horizontal",
                    isExpanded: Binding(
                        get: { agentConfiguration.activeRuntimePanel == .providers },
                        set: { isExpanded in
                            agentConfiguration.activeRuntimePanel = isExpanded ? .providers : nil
                        }
                    )
                ) {
                    HermesProvidersPanel(
                        companionSettings: companionSettings,
                        companionEnrollment: companionEnrollment,
                        companionRuntime: companionRuntime
                    )
                }

                HermesRuntimeAccordionPanel(
                    title: "Memory",
                    subtitle: memorySummary,
                    systemImage: "brain.head.profile",
                    isExpanded: Binding(
                        get: { agentConfiguration.activeRuntimePanel == .memory },
                        set: { isExpanded in
                            agentConfiguration.activeRuntimePanel = isExpanded ? .memory : nil
                        }
                    )
                ) {
                    HermesMemoryPanel(
                        companionSettings: companionSettings,
                        companionEnrollment: companionEnrollment,
                        companionRuntime: companionRuntime
                    )
                }

                HermesRuntimeAccordionPanel(
                    title: "Schedules",
                    subtitle: schedulesSummary,
                    systemImage: "calendar.badge.clock",
                    isExpanded: Binding(
                        get: { agentConfiguration.activeRuntimePanel == .schedules },
                        set: { isExpanded in
                            agentConfiguration.activeRuntimePanel = isExpanded ? .schedules : nil
                        }
                    )
                ) {
                    HermesSchedulesPanel(
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
                            .foregroundStyle(.hermesSecondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Agent Runtime")
        .background(Color.hermesCanvas)
    }
}

private struct HermesCompanionPanel: View {
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession

    private var providerSummary: String {
        if companionEnrollment.identityState.isEnrolled == false {
            return "Enroll companion to edit provider keys and model defaults"
        }
        let configuredKeys = companionRuntime.providerEnv.filter { !$0.value.isEmpty }.count
        let provider = companionRuntime.providerModelConfig.provider
        let model = companionRuntime.providerModelConfig.model
        if model.isEmpty {
            return "\(configuredKeys) environment values, provider \(provider)"
        }
        return "\(provider) · \(model) · \(configuredKeys) environment values"
    }

    private var memorySummary: String {
        if companionEnrollment.identityState.isEnrolled == false {
            return "Enroll companion to manage host memory"
        }
        if let config = companionRuntime.memoryConfig {
            let provider = config.provider.isEmpty ? "local" : config.provider
            return "\(companionRuntime.memoryEntries.count) memories · \(provider) · \(config.stats.totalSessions) sessions"
        }
        return "Agent memory, user profile, and memory providers"
    }

    private var schedulesSummary: String {
        if companionEnrollment.identityState.isEnrolled == false {
            return "Enroll companion to manage scheduled jobs"
        }
        let active = companionRuntime.schedules.filter { $0.state == "active" }.count
        let paused = companionRuntime.schedules.filter { $0.state == "paused" }.count
        return "\(active) active, \(paused) paused, \(companionRuntime.schedules.count) total"
    }

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
                        .init(title: "Companion", value: companionRuntime.connectionStatus, accent: .igActionBlue),
                        .init(title: "Service", value: companionRuntime.linkedServiceStatus.isEmpty ? "Unknown" : companionRuntime.linkedServiceStatus, accent: .igOnlineGreen)
                    ]
                )

                HermesSectionCard("Allowlisted Targets") {
                    VStack(alignment: .leading, spacing: 14) {
                        if !companionRuntime.lastErrorMessage.isEmpty {
                            Text(companionRuntime.lastErrorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.igDestructive)
                        }

                        if companionRuntime.targets.isEmpty {
                            Text("Fetch the host companion target registry to begin editing allowlisted files.")
                                .font(.subheadline)
                                .foregroundStyle(.hermesSecondaryText)
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
                                    .foregroundStyle(.hermesSecondaryText)
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
                                    .foregroundStyle(.hermesSecondaryText)
                            }

                            TextEditor(text: $companionRuntime.targetContent)
                                .scrollContentBackground(.hidden)
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
                                .foregroundStyle(.hermesSecondaryText)
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
                                                .foregroundStyle(.hermesSecondaryText)
                                        }
                                        Text(diagnostic.message)
                                            .font(.subheadline)
                                            .foregroundStyle(.hermesSecondaryText)
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.hermesSurfaceInput)
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
                                    .foregroundStyle(.hermesSecondaryText)
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
                                    .foregroundStyle(.hermesSecondaryText)
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
            .igDestructive
        case .warning:
            .igGradOrange
        case .info:
            .igActionBlue
        }
    }
}

private struct HermesToolsPanel: View {
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession

    private var providerSummary: String {
        if companionEnrollment.identityState.isEnrolled == false {
            return "Enroll companion to edit provider keys and model defaults"
        }
        let configuredKeys = companionRuntime.providerEnv.filter { !$0.value.isEmpty }.count
        let provider = companionRuntime.providerModelConfig.provider
        let model = companionRuntime.providerModelConfig.model
        if model.isEmpty {
            return "\(configuredKeys) environment values, provider \(provider)"
        }
        return "\(provider) · \(model) · \(configuredKeys) environment values"
    }

    private var memorySummary: String {
        if companionEnrollment.identityState.isEnrolled == false {
            return "Enroll companion to manage host memory"
        }
        if let config = companionRuntime.memoryConfig {
            let provider = config.provider.isEmpty ? "local" : config.provider
            return "\(companionRuntime.memoryEntries.count) memories · \(provider) · \(config.stats.totalSessions) sessions"
        }
        return "Agent memory, user profile, and memory providers"
    }

    private var schedulesSummary: String {
        if companionEnrollment.identityState.isEnrolled == false {
            return "Enroll companion to manage scheduled jobs"
        }
        let active = companionRuntime.schedules.filter { $0.state == "active" }.count
        let paused = companionRuntime.schedules.filter { $0.state == "paused" }.count
        return "\(active) active, \(paused) paused, \(companionRuntime.schedules.count) total"
    }

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
                            .foregroundStyle(.hermesSecondaryText)

                        companionSummaryRow(label: "Workspace", value: companionRuntime.resolvedHermesWorkspacePath.isEmpty ? companionSettings.hermesWorkspacePath : companionRuntime.resolvedHermesWorkspacePath)
                        companionSummaryRow(label: "Config", value: companionRuntime.toolsetsConfigPath.isEmpty ? "\(companionSettings.hermesWorkspacePath)/config.yaml" : companionRuntime.toolsetsConfigPath)

                        if !companionRuntime.lastErrorMessage.isEmpty {
                            Text(companionRuntime.lastErrorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.igDestructive)
                        }

                        if companionRuntime.hermesToolsets.isEmpty {
                            Text("Open this panel after enrollment to load the toolsets declared by Hermes desktop semantics.")
                                .font(.subheadline)
                                .foregroundStyle(.hermesSecondaryText)
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
                .foregroundStyle(.hermesSecondaryText)
                .textSelection(.enabled)
        }
        .font(.subheadline)
    }
}


private struct HermesProvidersPanel: View {
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession

    @State private var modelProvider = "auto"
    @State private var modelName = ""
    @State private var modelBaseURL = ""
    @State private var savedEnvKey: String?
    @State private var modelSaved = false
    @State private var visibleKeys: Set<String> = []
    @State private var poolProvider = ""
    @State private var poolNewKey = ""
    @State private var poolNewLabel = ""

    private var providerOptions: [HermesCompanionProviderOption] {
        if companionRuntime.providerOptions.isEmpty {
            return [
                .init(value: "auto", label: "Auto-detect"),
                .init(value: "openrouter", label: "OpenRouter"),
                .init(value: "anthropic", label: "Anthropic"),
                .init(value: "openai", label: "OpenAI"),
                .init(value: "google", label: "Google"),
                .init(value: "xai", label: "xAI"),
                .init(value: "nous", label: "Nous"),
                .init(value: "qwen", label: "Qwen"),
                .init(value: "minimax", label: "MiniMax"),
                .init(value: "custom", label: "Local / Custom")
            ]
        }
        return companionRuntime.providerOptions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if companionEnrollment.identityState.isEnrolled == false {
                ContentUnavailableView(
                    "Enrollment Required",
                    systemImage: "person.badge.key",
                    description: Text("Use Settings → Host Companion to enroll this iOS device before editing Hermes provider keys, default model configuration, or credential pools on the macOS host.")
                )
            } else {
                HermesSectionCard("Provider Model") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Mirrors the desktop Providers screen: edits `provider`, `default`, and `base_url` in the live Hermes `config.yaml`, enables streaming, and saves the model to the workspace inventory.")
                            .font(.subheadline)
                            .foregroundStyle(.hermesSecondaryText)

                        companionSummaryRow(label: "Workspace", value: companionRuntime.resolvedHermesWorkspacePath.isEmpty ? companionSettings.hermesWorkspacePath : companionRuntime.resolvedHermesWorkspacePath)
                        companionSummaryRow(label: "Config", value: companionRuntime.providerConfigPath.isEmpty ? "\(companionSettings.hermesWorkspacePath)/config.yaml" : companionRuntime.providerConfigPath)

                        if modelSaved {
                            Label("Saved", systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.igOnlineGreen)
                        }

                        Picker("Provider", selection: $modelProvider) {
                            ForEach(providerOptions) { option in
                                Text(option.label).tag(option.value)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: modelProvider) { _, newValue in
                            if newValue == "custom" && modelBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                modelBaseURL = "http://localhost:1234/v1"
                            }
                        }

                        Text(modelProvider == "custom" ? "Use a local or OpenAI-compatible custom provider endpoint." : "Choose which provider Hermes should use by default, or keep auto-detect.")
                            .font(.caption)
                            .foregroundStyle(.hermesSecondaryText)

                        TextField("Model name, e.g. anthropic/claude-sonnet-4", text: $modelName)
                            .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        if modelProvider == "custom" {
                            TextField("Base URL, e.g. http://localhost:1234/v1", text: $modelBaseURL)
                                .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }

                        Button("Save Model Configuration") {
                            companionRuntime.saveProviderModelConfig(
                                provider: modelProvider.trimmingCharacters(in: .whitespacesAndNewlines),
                                model: modelName.trimmingCharacters(in: .whitespacesAndNewlines),
                                baseUrl: modelBaseURL.trimmingCharacters(in: .whitespacesAndNewlines),
                                settings: companionSettings,
                                identityState: companionEnrollment.identityState
                            )
                            modelSaved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { modelSaved = false }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                HermesSectionCard("Credential Pool") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Stores multiple API keys per provider in `auth.json`, matching the desktop credential pool.")
                            .font(.subheadline)
                            .foregroundStyle(.hermesSecondaryText)
                        companionSummaryRow(label: "Auth Store", value: companionRuntime.providerAuthFilePath.isEmpty ? "\(companionSettings.hermesWorkspacePath)/auth.json" : companionRuntime.providerAuthFilePath)

                        Picker("Provider", selection: $poolProvider) {
                            Text("Provider").tag("")
                            ForEach(providerOptions.filter { $0.value != "auto" }) { option in
                                Text(option.label).tag(option.value)
                            }
                        }
                        .pickerStyle(.menu)

                        SecureField("API key", text: $poolNewKey)
                            .hermesRuntimeInput(background: Color.igOnlineGreen.opacity(0.08), border: Color.igOnlineGreen.opacity(0.28))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Label (optional)", text: $poolNewLabel)
                            .hermesRuntimeInput(background: Color.igOnlineGreen.opacity(0.08), border: Color.igOnlineGreen.opacity(0.28))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        Button("Add Pool Key") {
                            addPoolKey()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(poolProvider.isEmpty || poolNewKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        ForEach(companionRuntime.providerCredentialPool.keys.sorted(), id: \.self) { provider in
                            if let entries = companionRuntime.providerCredentialPool[provider], entries.isEmpty == false {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(label(for: provider))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.hermesSecondaryText)
                                    ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                                        HStack(alignment: .center, spacing: 10) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(entry.label.isEmpty ? "Key \(index + 1)" : entry.label)
                                                    .font(.subheadline.weight(.semibold))
                                                Text(masked(entry.key))
                                                    .font(.caption.monospaced())
                                                    .foregroundStyle(.hermesSecondaryText)
                                            }
                                            Spacer()
                                            Button(role: .destructive) {
                                                removePoolKey(provider: provider, index: index)
                                            } label: {
                                                Image(systemName: "trash")
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                        .padding(12)
                                        .background(Color.hermesSurfaceInput)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    }
                                }
                            }
                        }
                    }
                }

                HermesSectionCard("Environment") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Edits the same provider and tool API keys as desktop Providers, writing to `.env` on the macOS host via the enrolled WebSocket companion.")
                            .font(.subheadline)
                            .foregroundStyle(.hermesSecondaryText)
                        companionSummaryRow(label: "Env File", value: companionRuntime.providerEnvFilePath.isEmpty ? "\(companionSettings.hermesWorkspacePath)/.env" : companionRuntime.providerEnvFilePath)

                        if !companionRuntime.lastErrorMessage.isEmpty {
                            Text(companionRuntime.lastErrorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.igDestructive)
                        }

                        ForEach(companionRuntime.providerSections) { section in
                            DisclosureGroup(section.title) {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(section.items) { field in
                                        providerField(field)
                                    }
                                }
                                .padding(.top, 10)
                            }
                            .font(.subheadline.weight(.semibold))
                            .tint(.igActionBlue)
                            .padding(12)
                            .background(Color.hermesSurfaceInput)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                }
            }
        }
        .task(id: companionEnrollment.identityState.deviceID) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            companionRuntime.refreshProvidersConfig(settings: companionSettings, identityState: companionEnrollment.identityState)
        }
        .task(id: companionSettings.hermesWorkspacePath) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            companionRuntime.refreshProvidersConfig(settings: companionSettings, identityState: companionEnrollment.identityState)
        }
        .onChange(of: companionRuntime.providerModelConfig) { _, newValue in
            syncModelState(newValue)
        }
        .onAppear {
            syncModelState(companionRuntime.providerModelConfig)
        }
    }

    @ViewBuilder
    private func providerField(_ field: HermesCompanionProviderEnvField) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(field.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.hermesSecondaryText)
                if savedEnvKey == field.key {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.igOnlineGreen)
                }
            }

            HStack(spacing: 8) {
                let binding = Binding<String>(
                    get: { companionRuntime.providerEnv[field.key] ?? "" },
                    set: { companionRuntime.providerEnv[field.key] = $0 }
                )
                if field.type == "password" && visibleKeys.contains(field.key) == false {
                    SecureField(field.label, text: binding)
                        .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    TextField(field.label, text: binding)
                        .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if field.type == "password" {
                    Button(visibleKeys.contains(field.key) ? "Hide" : "Show") {
                        if visibleKeys.contains(field.key) { visibleKeys.remove(field.key) } else { visibleKeys.insert(field.key) }
                    }
                    .buttonStyle(.bordered)
                }
            }

            Text(field.hint)
                .font(.caption)
                .foregroundStyle(.hermesSecondaryText)

            Button("Save \(field.label)") {
                companionRuntime.setProviderEnvValue(
                    key: field.key,
                    value: companionRuntime.providerEnv[field.key] ?? "",
                    settings: companionSettings,
                    identityState: companionEnrollment.identityState
                )
                savedEnvKey = field.key
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedEnvKey = nil }
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(Color.hermesSurfaceInput)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func syncModelState(_ config: HermesCompanionProviderModelConfig) {
        modelProvider = config.provider
        modelName = config.model
        modelBaseURL = config.baseUrl
    }

    private func addPoolKey() {
        let provider = poolProvider.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = poolNewKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !provider.isEmpty, !key.isEmpty else { return }
        let existing = companionRuntime.providerCredentialPool[provider] ?? []
        let label = poolNewLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Key \(existing.count + 1)" : poolNewLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        companionRuntime.setProviderCredentialPool(
            provider: provider,
            entries: existing + [HermesCompanionProviderCredentialEntry(key: key, label: label)],
            settings: companionSettings,
            identityState: companionEnrollment.identityState
        )
        poolNewKey = ""
        poolNewLabel = ""
    }

    private func removePoolKey(provider: String, index: Int) {
        var entries = companionRuntime.providerCredentialPool[provider] ?? []
        guard entries.indices.contains(index) else { return }
        entries.remove(at: index)
        companionRuntime.setProviderCredentialPool(
            provider: provider,
            entries: entries,
            settings: companionSettings,
            identityState: companionEnrollment.identityState
        )
    }

    private func label(for provider: String) -> String {
        providerOptions.first(where: { $0.value == provider })?.label ?? provider
    }

    private func masked(_ value: String) -> String {
        guard value.count > 12 else { return value.isEmpty ? "Empty" : "••••" }
        return "\(value.prefix(8))…\(value.suffix(4))"
    }

    private func companionSummaryRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .fontWeight(.semibold)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.hermesSecondaryText)
                .textSelection(.enabled)
        }
        .font(.subheadline)
    }
}


private enum HermesMemoryTab: String, CaseIterable, Identifiable {
    case entries = "Agent Memory"
    case profile = "User Profile"
    case providers = "Providers"

    var id: String { rawValue }
}

private struct HermesMemoryPanel: View {
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession

    @State private var selectedTab: HermesMemoryTab = .entries
    @State private var showAddEntry = false
    @State private var newEntry = ""
    @State private var editingIndex: Int?
    @State private var editContent = ""
    @State private var confirmDeleteIndex: Int?
    @State private var userDraft = ""
    @State private var userSaved = false
    @State private var savedEnvKey: String?
    @State private var visibleKeys: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if companionEnrollment.identityState.isEnrolled == false {
                ContentUnavailableView(
                    "Enrollment Required",
                    systemImage: "person.badge.key",
                    description: Text("Use Settings → Host Companion to enroll this iOS device before editing Hermes memory files and provider configuration on the macOS host.")
                )
            } else {
                HermesSectionCard("Memory Overview") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Mirrors the desktop Memory screen: reads and writes `memories/MEMORY.md`, `memories/USER.md`, memory provider config, and memory provider env keys through HermesHostCompanion.")
                            .font(.subheadline)
                            .foregroundStyle(.hermesSecondaryText)

                        HermesStatusRow(
                            items: [
                                .init(title: "Sessions", value: "\(companionRuntime.memoryConfig?.stats.totalSessions ?? 0)", accent: .igActionBlue),
                                .init(title: "Messages", value: "\(companionRuntime.memoryConfig?.stats.totalMessages ?? 0)", accent: .igGradPurple),
                                .init(title: "Memories", value: "\(companionRuntime.memoryEntries.count)", accent: .igOnlineGreen)
                            ]
                        )

                        memoryCapacityBar(label: "Agent Memory", used: companionRuntime.memoryConfig?.memory.charCount ?? 0, limit: companionRuntime.memoryConfig?.memory.charLimit ?? 2_200)
                        memoryCapacityBar(label: "User Profile", used: companionRuntime.memoryConfig?.user.charCount ?? 0, limit: companionRuntime.memoryConfig?.user.charLimit ?? 1_375)

                        companionSummaryRow(label: "Workspace", value: companionRuntime.resolvedHermesWorkspacePath.isEmpty ? companionSettings.hermesWorkspacePath : companionRuntime.resolvedHermesWorkspacePath)
                        companionSummaryRow(label: "Memory File", value: companionRuntime.memoryFilePath.isEmpty ? "\(companionSettings.hermesWorkspacePath)/memories/MEMORY.md" : companionRuntime.memoryFilePath)
                        companionSummaryRow(label: "User File", value: companionRuntime.memoryUserFilePath.isEmpty ? "\(companionSettings.hermesWorkspacePath)/memories/USER.md" : companionRuntime.memoryUserFilePath)

                        if !companionRuntime.lastErrorMessage.isEmpty {
                            Text(companionRuntime.lastErrorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.igDestructive)
                        }

                        Button("Refresh Memory") {
                            companionRuntime.refreshMemoryConfig(settings: companionSettings, identityState: companionEnrollment.identityState)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Picker("Memory tab", selection: $selectedTab) {
                    ForEach(HermesMemoryTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                switch selectedTab {
                case .entries:
                    memoryEntriesSection
                case .profile:
                    userProfileSection
                case .providers:
                    memoryProvidersSection
                }
            }
        }
        .task(id: companionEnrollment.identityState.deviceID) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            companionRuntime.refreshMemoryConfig(settings: companionSettings, identityState: companionEnrollment.identityState)
        }
        .task(id: companionSettings.hermesWorkspacePath) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            companionRuntime.refreshMemoryConfig(settings: companionSettings, identityState: companionEnrollment.identityState)
        }
        .onChange(of: companionRuntime.memoryUserContent) { _, newValue in
            userDraft = newValue
        }
        .onAppear {
            userDraft = companionRuntime.memoryUserContent
        }
    }

    private var memoryEntriesSection: some View {
        HermesSectionCard("Agent Memory") {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("\(companionRuntime.memoryEntries.count) entries")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button(showAddEntry ? "Cancel" : "Add Memory") {
                        showAddEntry.toggle()
                        if showAddEntry == false { newEntry = "" }
                    }
                    .buttonStyle(.borderedProminent)
                }

                if showAddEntry {
                    VStack(alignment: .leading, spacing: 10) {
                        TextEditor(text: $newEntry)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 92)
                            .padding(8)
                            .background(Color.hermesSurfaceInput)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        HStack {
                            Text("\(newEntry.count) chars")
                                .font(.caption)
                                .foregroundStyle(.hermesSecondaryText)
                            Spacer()
                            Button("Save") {
                                let trimmed = newEntry.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard trimmed.isEmpty == false else { return }
                                companionRuntime.addMemoryEntry(content: trimmed, settings: companionSettings, identityState: companionEnrollment.identityState)
                                newEntry = ""
                                showAddEntry = false
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding(12)
                    .background(Color.hermesSurfaceInput.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                if companionRuntime.memoryEntries.isEmpty {
                    ContentUnavailableView(
                        "No Memories Yet",
                        systemImage: "brain",
                        description: Text("Add stable facts or workflow notes that Hermes should keep across sessions.")
                    )
                } else {
                    ForEach(companionRuntime.memoryEntries) { entry in
                        memoryEntryRow(entry)
                    }
                }
            }
        }
    }

    private var userProfileSection: some View {
        HermesSectionCard("User Profile") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Edit the user-level profile exactly as desktop Memory writes `USER.md`.")
                    .font(.subheadline)
                    .foregroundStyle(.hermesSecondaryText)

                TextEditor(text: $userDraft)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 180)
                    .padding(8)
                    .background(Color.hermesSurfaceInput)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                HStack {
                    Text("\(userDraft.count) / \(companionRuntime.memoryConfig?.user.charLimit ?? 1_375) chars")
                        .font(.caption)
                        .foregroundStyle(.hermesSecondaryText)
                    Spacer()
                    if userSaved {
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.igOnlineGreen)
                    }
                    Button("Save Profile") {
                        companionRuntime.writeUserProfile(content: userDraft, settings: companionSettings, identityState: companionEnrollment.identityState)
                        userSaved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { userSaved = false }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(userDraft.count > (companionRuntime.memoryConfig?.user.charLimit ?? 1_375))
                }
            }
        }
    }

    private var memoryProvidersSection: some View {
        HermesSectionCard("Memory Providers") {
            VStack(alignment: .leading, spacing: 14) {
                Text(companionRuntime.memoryProvider.isEmpty ? "No external memory provider is active. Hermes will use local memory files." : "Active provider: \(companionRuntime.memoryProvider)")
                    .font(.subheadline)
                    .foregroundStyle(.hermesSecondaryText)

                companionSummaryRow(label: "Config", value: companionRuntime.memoryConfigPath.isEmpty ? "\(companionSettings.hermesWorkspacePath)/config.yaml" : companionRuntime.memoryConfigPath)
                companionSummaryRow(label: "Env File", value: companionRuntime.memoryEnvFilePath.isEmpty ? "\(companionSettings.hermesWorkspacePath)/.env" : companionRuntime.memoryEnvFilePath)

                if companionRuntime.memoryProviders.isEmpty {
                    Text("Refresh memory to discover memory providers from the host Hermes installation.")
                        .font(.subheadline)
                        .foregroundStyle(.hermesSecondaryText)
                } else {
                    ForEach(companionRuntime.memoryProviders) { provider in
                        memoryProviderCard(provider)
                    }
                }
            }
        }
    }

    private func memoryEntryRow(_ entry: HermesCompanionMemoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if editingIndex == entry.index {
                TextEditor(text: $editContent)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 92)
                    .padding(8)
                    .background(Color.hermesSurfaceInput)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                HStack {
                    Text("\(editContent.count) chars")
                        .font(.caption)
                        .foregroundStyle(.hermesSecondaryText)
                    Spacer()
                    Button("Cancel") {
                        editingIndex = nil
                        editContent = ""
                    }
                    .buttonStyle(.bordered)
                    Button("Save") {
                        companionRuntime.updateMemoryEntry(index: entry.index, content: editContent.trimmingCharacters(in: .whitespacesAndNewlines), settings: companionSettings, identityState: companionEnrollment.identityState)
                        editingIndex = nil
                        editContent = ""
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Text(entry.content)
                    .font(.subheadline)
                    .textSelection(.enabled)
                HStack {
                    Button("Edit") {
                        editingIndex = entry.index
                        editContent = entry.content
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    if confirmDeleteIndex == entry.index {
                        Button("Cancel") { confirmDeleteIndex = nil }
                            .buttonStyle(.bordered)
                        Button("Delete", role: .destructive) {
                            companionRuntime.removeMemoryEntry(index: entry.index, settings: companionSettings, identityState: companionEnrollment.identityState)
                            confirmDeleteIndex = nil
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button(role: .destructive) { confirmDeleteIndex = entry.index } label: { Image(systemName: "trash") }
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hermesSurfaceInput)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func memoryProviderCard(_ provider: HermesCompanionMemoryProviderInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(provider.name)
                            .font(.headline)
                        if provider.active {
                            Label("Active", systemImage: "checkmark.circle.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.igOnlineGreen)
                        }
                        if provider.installed == false {
                            Text("Not installed")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.hermesSecondaryText)
                        }
                    }
                    Text(provider.description)
                        .font(.caption)
                        .foregroundStyle(.hermesSecondaryText)
                }
                Spacer()
                if provider.active {
                    Button("Deactivate") {
                        companionRuntime.setMemoryProvider("", settings: companionSettings, identityState: companionEnrollment.identityState)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button("Activate") {
                        companionRuntime.setMemoryProvider(provider.name, settings: companionSettings, identityState: companionEnrollment.identityState)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if provider.envVars.isEmpty == false {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(provider.envVars, id: \.self) { key in
                        memoryEnvField(key)
                    }
                }
            }
        }
        .padding(14)
        .background(provider.active ? Color.igActionBlue.opacity(0.10) : Color.hermesSurfaceInput)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(provider.active ? Color.igActionBlue.opacity(0.45) : Color.clear, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func memoryEnvField(_ key: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(key)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.hermesSecondaryText)
                if savedEnvKey == key {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.igOnlineGreen)
                }
            }
            HStack(spacing: 8) {
                let binding = Binding<String>(
                    get: { companionRuntime.memoryEnv[key] ?? "" },
                    set: { companionRuntime.memoryEnv[key] = $0 }
                )
                if key.localizedCaseInsensitiveContains("KEY") && visibleKeys.contains(key) == false {
                    SecureField(key, text: binding)
                        .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    TextField(key, text: binding)
                        .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                if key.localizedCaseInsensitiveContains("KEY") {
                    Button(visibleKeys.contains(key) ? "Hide" : "Show") {
                        if visibleKeys.contains(key) { visibleKeys.remove(key) } else { visibleKeys.insert(key) }
                    }
                    .buttonStyle(.bordered)
                }
            }
            Button("Save \(key)") {
                companionRuntime.setMemoryEnvValue(key: key, value: companionRuntime.memoryEnv[key] ?? "", settings: companionSettings, identityState: companionEnrollment.identityState)
                savedEnvKey = key
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedEnvKey = nil }
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(Color.hermesCanvas.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func memoryCapacityBar(label: String, used: Int, limit: Int) -> some View {
        let percentage = limit > 0 ? min(1.0, Double(used) / Double(limit)) : 0
        let tint: Color = percentage > 0.9 ? .igDestructive : (percentage > 0.7 ? .igGradOrange : .igOnlineGreen)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.hermesSecondaryText)
                Spacer()
                Text("\(used) / \(limit) chars")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.hermesSecondaryText)
            }
            GeometryReader { proxy in
                Capsule()
                    .fill(Color.hermesSurfaceInput)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(tint)
                            .frame(width: proxy.size.width * percentage)
                    }
            }
            .frame(height: 8)
        }
    }

    private func companionSummaryRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .fontWeight(.semibold)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.hermesSecondaryText)
                .textSelection(.enabled)
        }
        .font(.subheadline)
    }
}


private struct HermesSchedulesPanel: View {
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession

    @State private var showCreateForm = false
    @State private var confirmDeleteJobID: String?
    @State private var newName = ""
    @State private var newPrompt = ""
    @State private var newDeliver = "local"
    @State private var frequency: ScheduleFrequency = .daily
    @State private var minutesInterval = "30"
    @State private var hourlyInterval = "1"
    @State private var dailyTime = "09:00"
    @State private var weeklyDay = "1"
    @State private var weeklyTime = "09:00"
    @State private var customCron = ""

    private let deliverTargets: [(String, String)] = [
        ("local", "Local"), ("origin", "Origin"), ("telegram", "Telegram"), ("discord", "Discord"),
        ("slack", "Slack"), ("whatsapp", "WhatsApp"), ("signal", "Signal"), ("matrix", "Matrix"),
        ("mattermost", "Mattermost"), ("email", "Email"), ("webhook", "Webhook"), ("sms", "SMS"),
        ("homeassistant", "Home Assistant"), ("dingtalk", "DingTalk"), ("feishu", "Feishu"), ("wecom", "WeCom")
    ]

    private var builtSchedule: String {
        switch frequency {
        case .minutes:
            return "\(minutesInterval)m"
        case .hourly:
            return "\(hourlyInterval)h"
        case .daily:
            let parts = dailyTime.split(separator: ":")
            let hour = parts.first.map(String.init) ?? "09"
            let minute = parts.dropFirst().first.map(String.init) ?? "00"
            return "\(minute) \(hour) * * *"
        case .weekly:
            let parts = weeklyTime.split(separator: ":")
            let hour = parts.first.map(String.init) ?? "09"
            let minute = parts.dropFirst().first.map(String.init) ?? "00"
            return "\(minute) \(hour) * * \(weeklyDay)"
        case .custom:
            return customCron.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private var isScheduleValid: Bool {
        switch frequency {
        case .custom:
            return customCron.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        case .minutes:
            return (Int(minutesInterval) ?? 0) > 0
        case .hourly:
            return (Int(hourlyInterval) ?? 0) > 0
        default:
            return true
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if companionEnrollment.identityState.isEnrolled == false {
                ContentUnavailableView(
                    "Enrollment Required",
                    systemImage: "person.badge.key",
                    description: Text("Enroll this iOS device with HermesHostCompanion before listing or editing scheduled jobs on the macOS host.")
                )
            } else {
                HermesStatusRow(items: [
                    .init(title: "Jobs", value: "\(companionRuntime.schedules.count)", accent: .igActionBlue),
                    .init(title: "Active", value: "\(companionRuntime.schedules.filter { $0.state == "active" }.count)", accent: .igOnlineGreen),
                    .init(title: "Paused", value: "\(companionRuntime.schedules.filter { $0.state == "paused" }.count)", accent: .igGradOrange)
                ])

                if !companionRuntime.lastErrorMessage.isEmpty {
                    Text(companionRuntime.lastErrorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.igDestructive)
                }

                HermesSectionCard("Schedule Controls") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Create, pause, resume, trigger, and delete Hermes cron jobs stored on the macOS host.")
                            .font(.subheadline)
                            .foregroundStyle(.hermesSecondaryText)
                        if !companionRuntime.schedulesFilePath.isEmpty {
                            Text(companionRuntime.schedulesFilePath)
                                .font(.caption.monospaced())
                                .foregroundStyle(.hermesSecondaryText)
                                .textSelection(.enabled)
                        }
                        HStack {
                            Button {
                                companionRuntime.refreshSchedules(settings: companionSettings, identityState: companionEnrollment.identityState)
                            } label: {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.borderedProminent)

                            Button {
                                showCreateForm.toggle()
                            } label: {
                                Label(showCreateForm ? "Hide Form" : "New Task", systemImage: showCreateForm ? "xmark" : "plus")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                if showCreateForm {
                    HermesSectionCard("New Scheduled Task") {
                        createForm
                    }
                }

                HermesSectionCard("Scheduled Jobs") {
                    if companionRuntime.schedules.isEmpty {
                        ContentUnavailableView(
                            "No Scheduled Jobs",
                            systemImage: "calendar.badge.plus",
                            description: Text("Create the first task or refresh from the host cron registry.")
                        )
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(companionRuntime.schedules) { job in
                                scheduleCard(job)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            if companionEnrollment.identityState.isEnrolled, companionRuntime.schedules.isEmpty {
                companionRuntime.refreshSchedules(settings: companionSettings, identityState: companionEnrollment.identityState)
            }
        }
    }

    private var createForm: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Name", text: $newName)
                .hermesRuntimeInput(background: Color.igOnlineGreen.opacity(0.08), border: Color.igOnlineGreen.opacity(0.28))
                .textInputAutocapitalization(.sentences)
            Picker("Frequency", selection: $frequency) {
                ForEach(ScheduleFrequency.allCases) { item in
                    Text(item.label).tag(item)
                }
            }
            .pickerStyle(.segmented)

            Group {
                switch frequency {
                case .minutes:
                    Picker("Interval", selection: $minutesInterval) {
                        ForEach(["5", "10", "15", "30", "45"], id: \.self) { value in
                            Text("Every \(value) minutes").tag(value)
                        }
                    }
                case .hourly:
                    Picker("Interval", selection: $hourlyInterval) {
                        ForEach(["1", "2", "3", "4", "6", "8", "12"], id: \.self) { value in
                            Text("Every \(value) hour\(value == "1" ? "" : "s")").tag(value)
                        }
                    }
                case .daily:
                    TextField("Execution time (HH:mm)", text: $dailyTime)
                        .hermesRuntimeInput(background: Color.igOnlineGreen.opacity(0.08), border: Color.igOnlineGreen.opacity(0.28))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                case .weekly:
                    Picker("Weekday", selection: $weeklyDay) {
                        Text("Monday").tag("1")
                        Text("Tuesday").tag("2")
                        Text("Wednesday").tag("3")
                        Text("Thursday").tag("4")
                        Text("Friday").tag("5")
                        Text("Saturday").tag("6")
                        Text("Sunday").tag("0")
                    }
                    TextField("Execution time (HH:mm)", text: $weeklyTime)
                        .hermesRuntimeInput(background: Color.igOnlineGreen.opacity(0.08), border: Color.igOnlineGreen.opacity(0.28))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                case .custom:
                    TextField("Cron expression, e.g. 0 9 * * *", text: $customCron)
                        .hermesRuntimeInput(background: Color.igOnlineGreen.opacity(0.08), border: Color.igOnlineGreen.opacity(0.28))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Use 5-field cron syntax, or Hermes expressions like 30m / 2h when supported by the CLI.")
                        .font(.caption)
                        .foregroundStyle(.hermesSecondaryText)
                }
            }

            Text("Schedule: \(builtSchedule.isEmpty ? "—" : builtSchedule)")
                .font(.caption.monospaced())
                .foregroundStyle(.hermesSecondaryText)
                .textSelection(.enabled)

            TextEditor(text: $newPrompt)
                .frame(minHeight: 92)
                .scrollContentBackground(.hidden)
                .background(Color.hermesSurfaceInput)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            Text("Prompt to run when this schedule fires.")
                .font(.caption)
                .foregroundStyle(.hermesSecondaryText)

            Picker("Deliver to", selection: $newDeliver) {
                ForEach(deliverTargets, id: \.0) { target in
                    Text(target.1).tag(target.0)
                }
            }
            .pickerStyle(.menu)

            HStack {
                Button {
                    let prompt = newPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                    companionRuntime.createSchedule(
                        schedule: builtSchedule,
                        prompt: prompt.isEmpty ? nil : prompt,
                        name: name.isEmpty ? nil : name,
                        deliver: newDeliver == "local" ? nil : newDeliver,
                        settings: companionSettings,
                        identityState: companionEnrollment.identityState
                    )
                    resetForm()
                    showCreateForm = false
                } label: {
                    Label("Create", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isScheduleValid)

                Button("Reset") { resetForm() }
                    .buttonStyle(.bordered)
            }
        }
    }

    private func scheduleCard(_ job: HermesCompanionScheduleCronJob) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(job.name)
                        .font(.headline)
                    Text(job.schedule)
                        .font(.caption.monospaced())
                        .foregroundStyle(.hermesSecondaryText)
                        .textSelection(.enabled)
                }
                Spacer()
                Text(job.state.capitalized)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusColor(for: job).opacity(0.18))
                    .foregroundStyle(statusColor(for: job))
                    .clipShape(Capsule())
            }

            if !job.prompt.isEmpty {
                Text(job.prompt)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.hermesSurfaceInput)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("Next: \(formatScheduleTime(job.nextRunAt))", systemImage: "calendar.badge.clock")
                if let lastRunAt = job.lastRunAt {
                    Label("Last: \(formatScheduleTime(lastRunAt))", systemImage: "clock.arrow.circlepath")
                }
                if let repeatInfo = job.repeatInfo, let times = repeatInfo.times {
                    Label("Runs: \(repeatInfo.completed)/\(times)", systemImage: "repeat")
                }
                if job.deliver.isEmpty == false && !(job.deliver.count == 1 && job.deliver[0] == "local") {
                    Label("Deliver: \(job.deliver.joined(separator: ", "))", systemImage: "paperplane")
                }
                if job.skills.isEmpty == false {
                    Label("Skills: \(job.skills.joined(separator: ", "))", systemImage: "square.stack.3d.up")
                }
            }
            .font(.caption)
            .foregroundStyle(.hermesSecondaryText)

            if let lastError = job.lastError, !lastError.isEmpty {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.igDestructive)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.igDestructive.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            HStack {
                if job.state != "completed" {
                    Button {
                        if job.state == "paused" {
                            companionRuntime.resumeSchedule(jobID: job.id, settings: companionSettings, identityState: companionEnrollment.identityState)
                        } else {
                            companionRuntime.pauseSchedule(jobID: job.id, settings: companionSettings, identityState: companionEnrollment.identityState)
                        }
                    } label: {
                        Label(job.state == "paused" ? "Resume" : "Pause", systemImage: job.state == "paused" ? "play.fill" : "pause.fill")
                    }
                    .buttonStyle(.bordered)
                }

                if job.state == "active" {
                    Button {
                        companionRuntime.triggerSchedule(jobID: job.id, settings: companionSettings, identityState: companionEnrollment.identityState)
                    } label: {
                        Label("Run Now", systemImage: "bolt.fill")
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Button(role: .destructive) {
                    confirmDeleteJobID = job.id
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(Color.hermesSurfaceInput)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .confirmationDialog("Delete scheduled task?", isPresented: Binding(get: { confirmDeleteJobID == job.id }, set: { if !$0 { confirmDeleteJobID = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                companionRuntime.removeSchedule(jobID: job.id, settings: companionSettings, identityState: companionEnrollment.identityState)
                confirmDeleteJobID = nil
            }
            Button("Cancel", role: .cancel) { confirmDeleteJobID = nil }
        } message: {
            Text("This removes the cron job from the host Hermes scheduler.")
        }
    }

    private func statusColor(for job: HermesCompanionScheduleCronJob) -> Color {
        switch job.state {
        case "active": return .igOnlineGreen
        case "paused": return .igGradOrange
        case "completed": return .hermesSecondaryText
        default: return .igActionBlue
        }
    }

    private func formatScheduleTime(_ value: String?) -> String {
        guard let value, value.isEmpty == false else { return "—" }
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return value
    }

    private func resetForm() {
        newName = ""
        newPrompt = ""
        newDeliver = "local"
        frequency = .daily
        minutesInterval = "30"
        hourlyInterval = "1"
        dailyTime = "09:00"
        weeklyDay = "1"
        weeklyTime = "09:00"
        customCron = ""
    }

    private enum ScheduleFrequency: String, CaseIterable, Identifiable {
        case minutes
        case hourly
        case daily
        case weekly
        case custom

        var id: String { rawValue }
        var label: String {
            switch self {
            case .minutes: return "Minutes"
            case .hourly: return "Hourly"
            case .daily: return "Daily"
            case .weekly: return "Weekly"
            case .custom: return "Custom"
            }
        }
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
                            .foregroundStyle(.hermesSecondaryText)

                        companionSummaryRow(label: "Workspace", value: companionRuntime.resolvedHermesWorkspacePath.isEmpty ? companionSettings.hermesWorkspacePath : companionRuntime.resolvedHermesWorkspacePath)
                        companionSummaryRow(label: "Models File", value: companionRuntime.modelsFilePath.isEmpty ? "\(companionSettings.hermesWorkspacePath)/models.json" : companionRuntime.modelsFilePath)

                        if !companionRuntime.lastErrorMessage.isEmpty {
                            Text(companionRuntime.lastErrorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.igDestructive)
                        }

                        HermesSectionCard("Add Model") {
                            VStack(alignment: .leading, spacing: 12) {
                                TextField("Display name", text: $newModelName)
                                    .hermesRuntimeInput(background: Color.igOnlineGreen.opacity(0.08), border: Color.igOnlineGreen.opacity(0.28))
                                TextField("Provider", text: $newModelProvider)
                                    .hermesRuntimeInput(background: Color.igOnlineGreen.opacity(0.08), border: Color.igOnlineGreen.opacity(0.28))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                TextField("Model ID", text: $newModelID)
                                    .hermesRuntimeInput(background: Color.igOnlineGreen.opacity(0.08), border: Color.igOnlineGreen.opacity(0.28))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                TextField("Base URL", text: $newModelBaseURL)
                                    .hermesRuntimeInput(background: Color.igOnlineGreen.opacity(0.08), border: Color.igOnlineGreen.opacity(0.28))
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
                                .foregroundStyle(.hermesSecondaryText)
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
                .foregroundStyle(.hermesSecondaryText)
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
                            .foregroundStyle(.hermesSecondaryText)

                        settingsSummaryRow(label: "Workspace", value: companionRuntime.resolvedHermesWorkspacePath.isEmpty ? companionSettings.hermesWorkspacePath : companionRuntime.resolvedHermesWorkspacePath)

                        Text(companionRuntime.isBusy ? "Syncing…" : "\(companionRuntime.hermesSkills.filter(\.isEnabled).count) enabled")
                            .font(.caption)
                            .foregroundStyle(.hermesSecondaryText)
                    }
                }
            }

            TextField("Start with", text: $agentConfiguration.skillSearchQuery)
                .hermesRuntimeInput(background: Color.igOnlineGreen.opacity(0.08), border: Color.igOnlineGreen.opacity(0.28))
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
                            .foregroundStyle(.hermesSecondaryText)

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
                .foregroundStyle(.hermesSecondaryText)
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
                        .foregroundStyle(.igActionBlue)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.hermesSecondaryText)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.hermesSecondaryText)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.hermesElevated)
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
        .background(Color.hermesElevated)
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
                            .foregroundStyle(isEnabled ? .igOnlineGreen : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background((isEnabled ? Color.igOnlineGreen : Color.secondary).opacity(0.12))
                            .clipShape(Capsule())
                    }

                    Text(skill.description)
                        .font(.subheadline)
                        .foregroundStyle(.hermesSecondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        Text(skill.category.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.hermesSecondaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.igActionBlue.opacity(0.08))
                            .clipShape(Capsule())
                    }

                    Text(skill.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.hermesSecondaryText)
                        .textSelection(.enabled)
                }

                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hermesSurfaceInput)
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
                        .foregroundStyle(toolset.enabled ? .igOnlineGreen : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background((toolset.enabled ? Color.igOnlineGreen : Color.secondary).opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(toolset.description)
                    .font(.subheadline)
                    .foregroundStyle(.hermesSecondaryText)

                Text(toolset.key)
                    .font(.caption.monospaced())
                    .foregroundStyle(.hermesSecondaryText)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 12)

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hermesSurfaceInput)
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
                .foregroundStyle(.hermesSecondaryText)

            TextField("Display name", text: $name)
                .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
            TextField("Provider", text: $provider)
                .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Model ID", text: $modelID)
                .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            TextField("Base URL", text: $baseURL)
                .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
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
        .background(Color.hermesSurfaceInput)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct HermesHeroCard: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient.instagramBrand

            Circle()
                .fill(.white.opacity(0.16))
                .frame(width: 180, height: 180)
                .offset(x: 160, y: -80)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    StoryRing(systemImage: systemImage, isActive: true, size: 54, tint: .white)
                    Text(title)
                        .font(.igUsernameLarge)
                        .foregroundStyle(.white)
                }

                Text(detail)
                    .font(.igBio)
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .bottomLeading)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: Color.igGradPurple.opacity(0.16), radius: 12, y: 6)
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
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title.uppercased())
                    .font(.igSecondaryMeta.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(.hermesSecondaryText)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            IGHairline()

            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hermesElevated)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.hermesDivider.opacity(0.65), lineWidth: 0.5)
        )
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
        HStack(spacing: 10) {
            Circle()
                .fill(item.accent)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title.uppercased())
                    .font(.igBadge)
                    .tracking(0.6)
                    .foregroundStyle(.hermesSecondaryText)
                Text(item.value)
                    .font(.igUsername)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Capsule().fill(Color.hermesSurfaceInput))
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
                .foregroundStyle(.hermesSecondaryText)

            ForEach(response.metadata, id: \.self) { line in
                Label(line, systemImage: "circle.fill")
                    .font(.caption)
                    .foregroundStyle(.hermesSecondaryText)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hermesSurfaceInput)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var statusColor: Color {
        switch response.status.lowercased() {
        case "failed":
            .igDestructive
        case "streaming", "update":
            .igActionBlue
        case "done", "completed":
            .igOnlineGreen
        default:
            .igGradOrange
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
                .foregroundStyle(.hermesSecondaryText)
                .textSelection(.enabled)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hermesSurfaceInput)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var roleColor: Color {
        message.role == "user" ? .igActionBlue : .igOnlineGreen
    }
}

private struct HermesHistoryExchangeCard: View {
    let exchange: HermesHistoryExchange

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(exchange.completedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(.hermesSecondaryText)

            VStack(alignment: .leading, spacing: 8) {
                Text("Request")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.hermesSecondaryText)
                Text(exchange.requestText)
                    .font(.subheadline)
                    .textSelection(.enabled)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Final Response")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.hermesSecondaryText)
                Text(exchange.responseText)
                    .font(.subheadline)
                    .foregroundStyle(.hermesSecondaryText)
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
    case providers
    case models
    case sandbox
    case memory
    case schedules
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

private extension View {
    func hermesRuntimeInput(
        background: Color = Color.igActionBlue.opacity(0.08),
        border: Color = Color.igActionBlue.opacity(0.28)
    ) -> some View {
        self
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            )
            .shadow(color: border.opacity(0.18), radius: 8, y: 3)
    }
}
