//
//  ContentView.swift
//  HermesiOS
//
//  Created by Laurent Dubertrand on 04/05/2026.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var selectedWorkspace: WorkspaceSection? = .apiConsole
    @State private var apiSettings = HermesAPISettings()
    @State private var agentConfiguration = HermesAgentConfiguration()
    @State private var requestDraft = HermesRequestDraft()
    @State private var mockResponses = HermesResponseSample.samples

    var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                iPhoneLayout
            } else {
                iPadLayout
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    private var iPadLayout: some View {
        NavigationSplitView {
            WorkspaceSidebar(selection: $selectedWorkspace)
                .navigationTitle("Hermes")
                .navigationSplitViewColumnWidth(min: 260, ideal: 280, max: 320)
        } detail: {
            workspaceDetail(for: selectedWorkspace ?? .apiConsole)
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var iPhoneLayout: some View {
        TabView {
            NavigationStack {
                HermesAPIConsoleView(
                    apiSettings: $apiSettings,
                    requestDraft: $requestDraft,
                    responses: $mockResponses
                )
            }
            .tabItem {
                Label("API", systemImage: "network")
            }

            NavigationStack {
                HermesConnectionsView(
                    apiSettings: $apiSettings,
                    agentConfiguration: $agentConfiguration
                )
            }
            .tabItem {
                Label("Connect", systemImage: "antenna.radiowaves.left.and.right")
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
        case .apiConsole:
            HermesAPIConsoleView(
                apiSettings: $apiSettings,
                requestDraft: $requestDraft,
                responses: $mockResponses
            )
        case .connections:
            HermesConnectionsView(
                apiSettings: $apiSettings,
                agentConfiguration: $agentConfiguration
            )
        case .runtime:
            HermesAgentConfigView(agentConfiguration: $agentConfiguration)
        }
    }
}

private enum WorkspaceSection: String, CaseIterable, Identifiable {
    case apiConsole
    case connections
    case runtime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .apiConsole:
            "API Console"
        case .connections:
            "Connections"
        case .runtime:
            "Agent Runtime"
        }
    }

    var subtitle: String {
        switch self {
        case .apiConsole:
            "Compose requests and inspect Hermes responses."
        case .connections:
            "Track gateway health and authentication details."
        case .runtime:
            "Model local and SSH-backed agent environments."
        }
    }

    var systemImage: String {
        switch self {
        case .apiConsole:
            "network"
        case .connections:
            "point.3.connected.trianglepath.dotted"
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

private struct HermesAPIConsoleView: View {
    @Binding var apiSettings: HermesAPISettings
    @Binding var requestDraft: HermesRequestDraft
    @Binding var responses: [HermesResponseSample]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HermesHeroCard(
                    title: "Hermes Gateway API",
                    detail: "Target the OpenAI-compatible `/v1` interface first, then layer in local and SSH agent management around the same workspace.",
                    systemImage: "bolt.horizontal.circle.fill"
                )

                HermesStatusRow(
                    items: [
                        .init(title: "Endpoint", value: apiSettings.baseURL, accent: .blue),
                        .init(title: "Protocol", value: requestDraft.endpoint.displayName, accent: .green),
                        .init(title: "Auth", value: apiSettings.apiKey.isEmpty ? "Missing bearer key" : "Bearer token configured", accent: .orange)
                    ]
                )

                HermesSectionCard("Gateway Settings") {
                    VStack(spacing: 14) {
                        TextField("Base URL", text: $apiSettings.baseURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        SecureField("Bearer token", text: $apiSettings.apiKey)

                        Toggle("Streaming enabled", isOn: $requestDraft.stream)

                        Picker("API surface", selection: $requestDraft.endpoint) {
                            ForEach(HermesEndpoint.allCases) { endpoint in
                                Text(endpoint.displayName).tag(endpoint)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                HermesSectionCard("Request Draft") {
                    VStack(alignment: .leading, spacing: 14) {
                        TextField("Model", text: $requestDraft.model)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        TextField("System / instructions", text: $requestDraft.instructions, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)

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
                            Label("Tools stream inline over SSE", systemImage: "waveform.path.ecg")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Queue Request") {
                                enqueuePreviewResponse()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }

                HermesSectionCard("Response Preview") {
                    LazyVStack(spacing: 12) {
                        ForEach(responses) { response in
                            HermesResponseCard(response: response)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("API Console")
    }

    private func enqueuePreviewResponse() {
        let preview = HermesResponseSample(
            title: requestDraft.endpoint.displayName,
            status: requestDraft.stream ? "Streaming" : "Ready",
            summary: requestDraft.userPrompt.isEmpty ? "Draft request is ready to send to Hermes." : requestDraft.userPrompt,
            metadata: [
                "Model: \(requestDraft.model)",
                "Base URL: \(apiSettings.baseURL)",
                requestDraft.stream ? "SSE stream enabled" : "One-shot response"
            ]
        )

        responses.insert(preview, at: 0)
    }
}

private struct HermesConnectionsView: View {
    @Binding var apiSettings: HermesAPISettings
    @Binding var agentConfiguration: HermesAgentConfiguration

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HermesHeroCard(
                    title: "Connection Topology",
                    detail: "Keep the API gateway and the execution backend visible together so users understand whether Hermes is acting locally or over SSH.",
                    systemImage: "point.3.filled.connected.trianglepath.dotted"
                )

                HermesSectionCard("Gateway") {
                    VStack(alignment: .leading, spacing: 12) {
                        gatewayRow(label: "Base URL", value: apiSettings.baseURL)
                        gatewayRow(label: "Chat Completions", value: "\(apiSettings.baseURL)/chat/completions")
                        gatewayRow(label: "Responses", value: "\(apiSettings.baseURL)/responses")
                        gatewayRow(label: "Authorization", value: apiSettings.apiKey.isEmpty ? "Bearer token required" : "Bearer token ready")
                    }
                }

                HermesSectionCard("Execution Backend") {
                    VStack(alignment: .leading, spacing: 16) {
                        Label(agentConfiguration.backend.displayName, systemImage: agentConfiguration.backend.systemImage)
                            .font(.headline)

                        Text(agentConfiguration.backendSummary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if agentConfiguration.backend == .ssh {
                            VStack(alignment: .leading, spacing: 10) {
                                gatewayRow(label: "Host", value: agentConfiguration.sshHost.isEmpty ? "Set TERMINAL_SSH_HOST" : agentConfiguration.sshHost)
                                gatewayRow(label: "User", value: agentConfiguration.sshUser.isEmpty ? "Set TERMINAL_SSH_USER" : agentConfiguration.sshUser)
                                gatewayRow(label: "Port", value: agentConfiguration.sshPort)
                            }
                        } else {
                            gatewayRow(label: "Working Directory", value: agentConfiguration.workingDirectory)
                        }
                    }
                }

                HermesSectionCard("Next Integration Pass") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("1. Add real networking for `/v1/responses` and streamed SSE updates.")
                        Text("2. Persist multiple Hermes profiles and gateway presets.")
                        Text("3. Surface remote-host trust and key management before enabling SSH writes.")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .navigationTitle("Connections")
    }

    private func gatewayRow(label: String, value: String) -> some View {
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

private struct HermesAgentConfigView: View {
    @Binding var agentConfiguration: HermesAgentConfiguration

    var body: some View {
        Form {
            Section("Backend") {
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

            if agentConfiguration.backend == .ssh {
                Section("SSH") {
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
            }

            Section("Planned Controls") {
                Label("Profile switching", systemImage: "person.2.crop.square.stack")
                Label("Gateway start / stop", systemImage: "playpause")
                Label("Remote health checks", systemImage: "stethoscope")
            }
            .foregroundStyle(.secondary)
        }
        .navigationTitle("Agent Runtime")
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
    let response: HermesResponseSample

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
                    .background(Color.green.opacity(0.12))
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
}

private struct HermesStatusItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let accent: Color
}

private enum HermesEndpoint: String, CaseIterable, Identifiable {
    case chatCompletions
    case responses

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chatCompletions:
            "/v1/chat/completions"
        case .responses:
            "/v1/responses"
        }
    }
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

private struct HermesAPISettings {
    var baseURL = "http://127.0.0.1:8642/v1"
    var apiKey = ""
}

private struct HermesAgentConfiguration {
    var backend: HermesTerminalBackend = .local
    var persistentShell = true
    var workingDirectory = "."
    var sshHost = ""
    var sshUser = ""
    var sshPort = "22"
    var sshKeyPath = "~/.ssh/id_rsa"

    var backendSummary: String {
        switch backend {
        case .local:
            "Commands execute directly on the device host running Hermes. This is the fastest path for initial gateway integration."
        case .ssh:
            "Commands execute on a remote server over SSH with a persistent shell, which is the right fit once the app starts managing remote agents."
        }
    }
}

private struct HermesRequestDraft {
    var endpoint: HermesEndpoint = .responses
    var model = "hermes-agent"
    var instructions = "You are a helpful coding assistant."
    var userPrompt = "Summarize the current project layout and recommend the next integration step."
    var stream = true
}

private struct HermesResponseSample: Identifiable {
    let id = UUID()
    let title: String
    let status: String
    let summary: String
    let metadata: [String]

    static let samples: [HermesResponseSample] = [
        HermesResponseSample(
            title: "/v1/responses",
            status: "Streaming",
            summary: "Hermes can store previous response state server-side, which is a better fit for a mobile client than resending the full transcript every turn.",
            metadata: ["Supports `previous_response_id`", "SSE emits tool calls inline", "Good default for multi-turn sessions"]
        ),
        HermesResponseSample(
            title: "/v1/chat/completions",
            status: "Available",
            summary: "Chat Completions remains useful for compatibility with existing OpenAI-style request pipelines and frontend tooling.",
            metadata: ["Stateless `messages` array", "Standard chunk events", "Hermes adds tool-progress SSE events"]
        )
    ]
}

#Preview("iPhone") {
    ContentView()
        .previewDevice("iPhone 16 Pro")
}

#Preview("iPad") {
    ContentView()
        .previewDevice("iPad Pro (13-inch) (M4)")
}
