//
//  HermesSettingsView.swift
//  HermesiOS
//

import Observation
import SwiftUI
import UniformTypeIdentifiers

struct HermesSettingsView: View {
    @Binding var apiSettings: HermesAPISettings
    @Binding var companionSettings: HermesCompanionSettings
    @Binding var responsesDraft: HermesRequestDraft
    @Binding var chatDraft: HermesChatDraft
    @Binding var terminalSettings: HermesTerminalSettings
    @Binding var appTheme: HermesAppTheme
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession
    @AppStorage(hermesMacHostStorageKey) private var macHost = defaultHermesMacHost
    @AppStorage(hermesDashboardPortStorageKey) private var dashboardPort = defaultHermesDashboardPort
    @AppStorage(hermesOfficePortStorageKey) private var officePort = defaultHermesOfficePort
    @AppStorage(hermesTailscaleServePortStorageKey) private var selectedTailscaleServePort = defaultHermesAPIPort
    @AppStorage(hermesRuntimeTabEnabledStorageKey) private var isRuntimeTabEnabled = false
    @AppStorage("hermes.history.dashboardURL") private var legacyDashboardURL = ""
    @AppStorage("hermes.office.url") private var legacyOfficeURL = ""
    @State private var dashboardGatewayRestart = HermesDashboardGatewayRestartSession()
    @State private var isImportingTerminalPrivateKey = false
    @State private var terminalPrivateKeyStatus = ""

    private let macServices: [HermesSettingsMacService] = [
        .init(id: "hermes-dashboard", title: "Hermes Dashboard", subtitle: "Host-rewriting dashboard proxy", icon: "rectangle.on.rectangle.angled"),
        .init(id: "claw3d-adapter", title: "Claw3D Adapter", subtitle: "Hermes Office / Claw3D bridge", icon: "cube.transparent")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HermesTabHeader("Settings", systemImage: "slider.horizontal.3")
                .padding(.horizontal)
                .padding(.top)

            Form {
                Section("Appearance") {
                    Picker("App Theme", selection: $appTheme) {
                        ForEach(HermesAppTheme.allCases) { theme in
                            Text(theme.title).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)

                }

                Section("Mac host") {
                    TextField("Hostname or IP, e.g. .ts.net", text: $macHost)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .hermesRuntimeInput()

                    Text("Used with the service TCP ports below to build the HTTPS and WSS URLs, and as the SSH host for the Terminal tab.")
                        .font(.caption)
                        .foregroundStyle(.hermesSecondaryText)
                }

                Section("Chat with Hermes") {
                Toggle("Streaming enabled", isOn: $chatDraft.stream)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Common system prompt (optional)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.hermesSecondaryText)

                    TextField("System prompt", text: $chatDraft.systemPrompt, axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                }
                }

                Section("Ask Hermes") {
                Toggle("Streaming enabled", isOn: $responsesDraft.stream)
                }

                Section("Hermes Installation") {
                    if companionEnrollment.identityState.isEnrolled == false {
                        Text("Authenticate Host Companion before checking the host Hermes Agent checkout.")
                            .font(.caption)
                            .foregroundStyle(.hermesSecondaryText)
                    }

                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: companionRuntime.hermesInstallationStatus?.behindBy == 0 ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(hermesInstallationStatusColor)
                            .frame(width: 28)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(companionRuntime.hermesInstallationStatusMessage)
                                .font(.subheadline.weight(.semibold))
                            Text("Compared with official Hermes Agent main. Refreshes hourly.")
                                .font(.caption)
                                .foregroundStyle(.hermesSecondaryText)
                        }

                        Spacer()

                        if companionRuntime.isCheckingHermesInstallation {
                            ProgressView()
                        }
                    }

                    if let status = companionRuntime.hermesInstallationStatus {
                        settingsRow(label: "Repository", value: status.repositoryPath)

                        HStack(alignment: .center) {
                            Text("Current Local Branch")
                                .fontWeight(.semibold)
                            TextField(
                                "Unknown",
                                text: Binding(
                                    get: { status.branch.isEmpty ? "Unknown" : status.branch },
                                    set: { _ in }
                                )
                            )
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .multilineTextAlignment(.trailing)
                        }
                        .font(.subheadline)

                        settingsRow(label: "Local / official main", value: "\(status.currentCommit) / \(status.upstreamCommit)")
                        settingsRow(label: "Last Checked", value: status.checkedAt.formatted(date: .abbreviated, time: .shortened))

                        if status.isUpdateBlocked {
                            settingsRow(label: "Pending Update", value: "\(status.pendingUpdateBranch ?? "local branch") → \(status.pendingUpdateCommit ?? status.upstreamCommit)")
                        }

                        if status.conflictFiles.isEmpty == false {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Files to review")
                                    .font(.caption.weight(.semibold))
                                Text(status.conflictFiles.joined(separator: "\n"))
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.hermesSecondaryText)
                            }
                        }
                    }

                    let trimmedOperationOutput = companionRuntime.hermesInstallationOperationOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmedOperationOutput.isEmpty == false {
                        Text(trimmedOperationOutput)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.hermesSecondaryText)
                            .lineLimit(8)
                    }

                    if !companionRuntime.hermesInstallationStatusError.isEmpty {
                        Text(companionRuntime.hermesInstallationStatusError)
                            .font(.caption)
                            .foregroundStyle(.igDestructive)
                    }

                    HStack(spacing: 10) {
                        Button {
                            Task {
                                await companionRuntime.refreshHermesInstallationStatus(
                                    settings: companionSettings,
                                    identityState: companionEnrollment.identityState
                                )
                            }
                        } label: {
                            Label("Refresh Hermes Version", systemImage: "arrow.clockwise")
                        }
                        .hermesGlassButton()
                        .disabled(companionEnrollment.identityState.isEnrolled == false || companionRuntime.isCheckingHermesInstallation || companionRuntime.isUpdatingHermesInstallation)

                        Button {
                            companionRuntime.updateHermesInstallation(
                                settings: companionSettings,
                                identityState: companionEnrollment.identityState
                            )
                        } label: {
                            Label("Hermes Update", systemImage: "arrow.down.circle")
                        }
                        .hermesGlassProminentButton()
                        .disabled(hermesUpdateDisabled)

                        Button {
                            companionRuntime.reviewHermesInstallationConflicts(
                                settings: companionSettings,
                                identityState: companionEnrollment.identityState
                            )
                        } label: {
                            Label("Review Conflicts with Hermes", systemImage: "wand.and.stars")
                        }
                        .hermesGlassProminentButton()
                        .disabled(reviewHermesConflictsDisabled)

                        Button {
                            companionRuntime.mergeReviewedHermesInstallationUpdate(
                                settings: companionSettings,
                                identityState: companionEnrollment.identityState
                            )
                        } label: {
                            Label("Merge Reviewed Update", systemImage: "arrow.triangle.merge")
                        }
                        .hermesGlassButton()
                        .disabled(mergeReviewedHermesUpdateDisabled)
                    }
                }

                Section("Host Companion") {
                TextField("TCP port", text: companionPortBinding)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numberPad)

                settingsRow(label: "WebSocket URL", value: companionSettings.apiURL)

                HStack(alignment: .center, spacing: 10) {
                    HermesSettingsStatusLED(
                        isOn: companionAPIKeyVerified,
                        label: companionAPIKeyVerified ? "API key verified" : "API key not verified"
                    )

                    SecureField("256-character API key", text: $companionSettings.authenticationToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button(companionAPIKeyVerified ? "Verify API Key Again" : "Verify API Key") {
                        companionEnrollment.enroll(settings: companionSettings)
                    }
                    .hermesGlassProminentButton()
                    .disabled(
                        companionEnrollment.isEnrolling ||
                        companionSettings.apiURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        companionSettings.authenticationToken.trimmingCharacters(in: .whitespacesAndNewlines).count != HermesCompanionSessionFactory.expectedAPIKeyLength
                    )
                }

                Text("Paste the 256-character API key from the macOS Host Companion, then tap Verify API Key. Changing this field marks the companion as unverified until the key is verified again.")
                    .font(.caption)
                    .foregroundStyle(.hermesSecondaryText)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Hermes agent root folder")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.hermesSecondaryText)

                    TextField("Hermes workspace path", text: $companionSettings.hermesWorkspacePath)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if !companionEnrollment.lastErrorMessage.isEmpty {
                    Text(companionEnrollment.lastErrorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.igDestructive)
                }
                }

                Section("Gateway") {
                SecureField("Bearer token", text: $apiSettings.apiKey)

                Toggle("Allow self-signed HTTPS certificates", isOn: $apiSettings.allowSelfSignedCertificates)

                Text("The API gateway TCP port is configured in HermesHostCompanion and fetched automatically by HermesiOS after Host Companion verification.")
                    .font(.caption)
                    .foregroundStyle(.hermesSecondaryText)

                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        dashboardGatewayRestart.restart(
                            dashboardBaseURL: dashboardURL,
                            apiSettings: apiSettings
                        )
                    } label: {
                        Label("Restart API Server", systemImage: "arrow.clockwise.circle")
                    }
                    .hermesGlassProminentButton()
                    .disabled(dashboardGatewayRestart.isRestarting)

                    Text("Uses the Hermes dashboard URL to POST /api/gateway/restart.")
                        .font(.caption)
                        .foregroundStyle(.hermesSecondaryText)

                    if dashboardGatewayRestart.status != "Idle" {
                        Text(dashboardGatewayRestart.status)
                            .font(.caption)
                            .foregroundStyle(.hermesSecondaryText)
                    }

                    if !dashboardGatewayRestart.lastErrorMessage.isEmpty {
                        Text(dashboardGatewayRestart.lastErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.igDestructive)
                    }
                }
                .padding(.vertical, 4)
                }

                HermesOfficeSettingsSection()

                Section("Mac Services") {
                    if companionEnrollment.identityState.isEnrolled == false {
                        Text("Authenticate Host Companion before controlling Mac services from iOS.")
                            .font(.caption)
                            .foregroundStyle(.hermesSecondaryText)
                    }

                    ForEach(macServices) { service in
                        HermesSettingsMacServiceRow(
                            service: service,
                            status: companionRuntime.macServiceStatuses[service.id]?.status,
                            isEnabled: companionEnrollment.identityState.isEnrolled && !companionRuntime.isBusy,
                            onStart: {
                                companionRuntime.startMacService(
                                    service.id,
                                    settings: companionSettings,
                                    identityState: companionEnrollment.identityState
                                )
                            },
                            onStop: {
                                companionRuntime.stopMacService(
                                    service.id,
                                    settings: companionSettings,
                                    identityState: companionEnrollment.identityState
                                )
                            }
                        )
                    }

                    Button {
                        companionRuntime.refreshMacServices(
                            macServices.map(\.id),
                            settings: companionSettings,
                            identityState: companionEnrollment.identityState
                        )
                    } label: {
                        Label("Refresh Service Status", systemImage: "arrow.clockwise")
                    }
                    .hermesGlassButton()
                    .disabled(companionEnrollment.identityState.isEnrolled == false || companionRuntime.isBusy)
                }

                Section("Tabs") {
                    Toggle("Hermes Agent Runtime", isOn: $isRuntimeTabEnabled)

                    Text("Off by default. Enable only when you need the runtime management panels in the tab bar and iPad sidebar.")
                        .font(.caption)
                        .foregroundStyle(.hermesSecondaryText)
                }

                Section("Terminal") {
                    TextField("SSH username", text: $terminalSettings.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .hermesRuntimeInput()

                    TextField("SSH port", text: $terminalSettings.port)
                        .keyboardType(.numberPad)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .hermesRuntimeInput()

                    HStack(spacing: 10) {
                        Label(
                            terminalSettings.hasPrivateKey ? "Private key stored in Keychain" : "No private key stored",
                            systemImage: terminalSettings.hasPrivateKey ? "key.fill" : "key"
                        )
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(terminalSettings.hasPrivateKey ? .igOnlineGreen : .hermesSecondaryText)

                        Spacer()

                        Button {
                            isImportingTerminalPrivateKey = true
                        } label: {
                            Label("Choose Private Key", systemImage: "doc.badge.plus")
                        }
                        .hermesGlassButton()

                        if terminalSettings.hasPrivateKey {
                            Button(role: .destructive) {
                                HermesSettingsPersistence.deleteTerminalPrivateKey()
                                terminalSettings.hasPrivateKey = false
                                terminalPrivateKeyStatus = "Private key removed from Keychain."
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                            .hermesGlassButton()
                        }
                    }

                    Text("The selected key file is imported into Keychain and is not stored in Settings. Terminal connections require Face ID to retrieve it.")
                        .font(.caption)
                        .foregroundStyle(.hermesSecondaryText)

                    if !terminalPrivateKeyStatus.isEmpty {
                        Text(terminalPrivateKeyStatus)
                            .font(.caption)
                            .foregroundStyle(terminalPrivateKeyStatus.hasPrefix("Failed") ? .igDestructive : .hermesSecondaryText)
                    }
                }

                Section("Tailscale Serve") {
                    if companionEnrollment.identityState.isEnrolled == false {
                        Text("Authenticate Host Companion before controlling Tailscale Serve from iOS.")
                            .font(.caption)
                            .foregroundStyle(.hermesSecondaryText)
                    }

                    HStack(spacing: 12) {
                        Picker("TCP port", selection: $selectedTailscaleServePort) {
                            ForEach(tailscaleServePorts, id: \.self) { port in
                                Text(tailscaleServePortLabel(port)).tag(port)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .disabled(tailscaleServePorts.isEmpty || companionRuntime.isSettingTailscaleServe)
                        .accessibilityLabel("Tailscale Serve TCP port")

                        Toggle("Serve selected port", isOn: tailscaleServeToggleBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .tint(.igOnlineGreen)
                            .disabled(companionEnrollment.identityState.isEnrolled == false || companionRuntime.isCheckingTailscaleServe || companionRuntime.isSettingTailscaleServe)
                            .accessibilityLabel("Tailscale Serve for port \(selectedTailscaleServePort)")

                        if companionRuntime.isCheckingTailscaleServe || companionRuntime.isSettingTailscaleServe {
                            ProgressView()
                        }
                    }

                    Text("Runs tailscale serve --bg --https=<TCP_PORT> http://localhost:<TCP_PORT> when enabled, and tailscale serve --https=<TCP_PORT> off when disabled. The Host Companion port is intentionally excluded.")
                        .font(.caption)
                        .foregroundStyle(.hermesSecondaryText)

                    if let status = companionRuntime.tailscaleServeStatus, status.port == selectedTailscaleServePort {
                        settingsRow(label: "Status", value: status.isEnabled ? "On" : "Off")
                        settingsRow(label: "Last Checked", value: status.checkedAt.formatted(date: .omitted, time: .shortened))
                    }

                    let trimmedOutput = companionRuntime.tailscaleServeOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedOutput.isEmpty {
                        Text(trimmedOutput)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.hermesSecondaryText)
                            .lineLimit(5)
                    }

                    if !companionRuntime.tailscaleServeError.isEmpty {
                        Text(companionRuntime.tailscaleServeError)
                            .font(.caption)
                            .foregroundStyle(.igDestructive)
                    }
                }

            }
            .scrollContentBackground(.hidden)
        }
        .background(HermesLiquidGlassCanvas().ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task(id: companionEnrollment.identityState.deviceID) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            companionRuntime.refreshMacServices(
                macServices.map(\.id),
                settings: companionSettings,
                identityState: companionEnrollment.identityState
            )
        }
        .task(id: tailscaleServeRefreshKey) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            normalizeSelectedTailscaleServePort()
            companionRuntime.refreshTailscaleServeStatus(
                port: selectedTailscaleServePort,
                settings: companionSettings,
                identityState: companionEnrollment.identityState
            )
        }
        .task(id: hermesInstallationRefreshKey) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            await companionRuntime.refreshHermesInstallationStatusLoop(
                settings: companionSettings,
                identityState: companionEnrollment.identityState
            )
        }
        .onAppear {
            migrateLegacyURLPortsIfNeeded()
            applyMacHostToServiceURLs()
            normalizeSelectedTailscaleServePort()
        }
        .onChange(of: macHost) { _, _ in
            applyMacHostToServiceURLs()
            companionEnrollment.invalidateIfSettingsChanged(settings: companionSettings)
        }
        .onChange(of: companionSettings.authenticationToken) { _, _ in
            companionEnrollment.invalidateIfSettingsChanged(settings: companionSettings)
        }
        .onChange(of: companionSettings.apiURL) { _, _ in
            companionEnrollment.invalidateIfSettingsChanged(settings: companionSettings)
        }
        .fileImporter(
            isPresented: $isImportingTerminalPrivateKey,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false,
            onCompletion: importTerminalPrivateKey
        )
    }

    private var companionPortBinding: Binding<String> {
        Binding(
            get: { HermesHostEndpoints.tcpPort(from: companionSettings.apiURL, fallback: defaultHermesCompanionPort) },
            set: { newPort in
                companionSettings.apiURL = HermesHostEndpoints.webSocketURLString(host: macHost, port: newPort)
            }
        )
    }

    private var dashboardURL: String {
        HermesHostEndpoints.httpURLString(host: macHost, port: dashboardPort)
    }

    private var companionAPIKeyVerified: Bool {
        companionEnrollment.identityState.matches(settings: companionSettings)
    }

    private var hostDefinedServicePorts: HermesCompanionServicePortsResult {
        companionRuntime.servicePorts
    }

    private var tailscaleServePorts: [String] {
        let companionPort = HermesHostEndpoints.tcpPort(from: companionSettings.apiURL, fallback: defaultHermesCompanionPort)
        return [
            HermesHostEndpoints.tcpPort(from: hostDefinedServicePorts.apiGatewayPort, fallback: HermesHostEndpoints.tcpPort(from: apiSettings.baseURL, fallback: defaultHermesAPIPort)),
            HermesHostEndpoints.tcpPort(from: hostDefinedServicePorts.dashboardPort, fallback: dashboardPort),
            HermesHostEndpoints.tcpPort(from: hostDefinedServicePorts.officePort, fallback: officePort)
        ]
        .filter { $0 != companionPort }
        .reduce(into: [String]()) { ports, port in
            if ports.contains(port) == false {
                ports.append(port)
            }
        }
    }

    private var tailscaleServeToggleBinding: Binding<Bool> {
        Binding(
            get: {
                companionRuntime.tailscaleServeStatus?.port == selectedTailscaleServePort &&
                companionRuntime.tailscaleServeStatus?.isEnabled == true
            },
            set: { isEnabled in
                companionRuntime.setTailscaleServe(
                    isEnabled,
                    port: selectedTailscaleServePort,
                    settings: companionSettings,
                    identityState: companionEnrollment.identityState
                )
            }
        )
    }

    private var tailscaleServeRefreshKey: String {
        [
            companionEnrollment.identityState.isEnrolled ? "enrolled" : "not-enrolled",
            companionEnrollment.identityState.serverEndpoint,
            selectedTailscaleServePort,
            hostDefinedServicePorts.apiGatewayPort,
            hostDefinedServicePorts.dashboardPort,
            hostDefinedServicePorts.officePort,
            companionPortBinding.wrappedValue
        ].joined(separator: "|")
    }

    private func tailscaleServePortLabel(_ port: String) -> String {
        switch port {
        case HermesHostEndpoints.tcpPort(from: hostDefinedServicePorts.apiGatewayPort, fallback: HermesHostEndpoints.tcpPort(from: apiSettings.baseURL, fallback: defaultHermesAPIPort)):
            "API Server (\(port))"
        case HermesHostEndpoints.tcpPort(from: hostDefinedServicePorts.dashboardPort, fallback: dashboardPort):
            "Dashboard (\(port))"
        case HermesHostEndpoints.tcpPort(from: hostDefinedServicePorts.officePort, fallback: officePort):
            "Office (\(port))"
        default:
            "TCP \(port)"
        }
    }

    private func normalizeSelectedTailscaleServePort() {
        let ports = tailscaleServePorts
        guard ports.isEmpty == false else { return }
        if ports.contains(selectedTailscaleServePort) == false {
            selectedTailscaleServePort = ports[0]
        }
    }

    private func applyMacHostToServiceURLs() {
        let apiPort = HermesHostEndpoints.tcpPort(from: hostDefinedServicePorts.apiGatewayPort, fallback: HermesHostEndpoints.tcpPort(from: apiSettings.baseURL, fallback: defaultHermesAPIPort))
        apiSettings.baseURL = HermesHostEndpoints.httpURLString(host: macHost, port: apiPort, path: "/v1")
        companionSettings.apiURL = HermesHostEndpoints.webSocketURLString(host: macHost, port: companionPortBinding.wrappedValue)
        dashboardPort = HermesHostEndpoints.tcpPort(from: hostDefinedServicePorts.dashboardPort, fallback: dashboardPort)
        officePort = HermesHostEndpoints.tcpPort(from: hostDefinedServicePorts.officePort, fallback: officePort)
    }

    private func migrateLegacyURLPortsIfNeeded() {
        if !legacyDashboardURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            dashboardPort = HermesHostEndpoints.tcpPort(from: legacyDashboardURL, fallback: dashboardPort)
            legacyDashboardURL = ""
        }
        if !legacyOfficeURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            officePort = HermesHostEndpoints.tcpPort(from: legacyOfficeURL, fallback: officePort)
            legacyOfficeURL = ""
        }
    }

    private var hermesInstallationRefreshKey: String {
        [
            companionEnrollment.identityState.isEnrolled ? "enrolled" : "not-enrolled",
            companionEnrollment.identityState.serverEndpoint,
            companionSettings.hermesWorkspacePath
        ].joined(separator: "|")
    }

    private var hermesUpdateDisabled: Bool {
        companionEnrollment.identityState.isEnrolled == false ||
        companionRuntime.isCheckingHermesInstallation ||
        companionRuntime.isUpdatingHermesInstallation ||
        (companionRuntime.hermesInstallationStatus?.isUpdateBlocked ?? false)
    }

    private var mergeReviewedHermesUpdateDisabled: Bool {
        companionEnrollment.identityState.isEnrolled == false ||
        companionRuntime.isCheckingHermesInstallation ||
        companionRuntime.isUpdatingHermesInstallation ||
        (companionRuntime.hermesInstallationStatus?.isUpdateBlocked ?? false) == false ||
        (companionRuntime.hermesInstallationStatus?.conflictFiles.isEmpty ?? true) == false
    }

    private var reviewHermesConflictsDisabled: Bool {
        companionEnrollment.identityState.isEnrolled == false ||
        companionRuntime.isCheckingHermesInstallation ||
        companionRuntime.isUpdatingHermesInstallation ||
        (companionRuntime.hermesInstallationStatus?.isUpdateBlocked ?? false) == false ||
        (companionRuntime.hermesInstallationStatus?.conflictFiles.isEmpty ?? true)
    }

    private var hermesInstallationStatusColor: Color {
        if companionRuntime.hermesInstallationStatusError.isEmpty == false {
            return .igDestructive
        }
        guard let status = companionRuntime.hermesInstallationStatus else {
            return .hermesSecondaryText
        }
        if status.isUpdateBlocked {
            return .igGradOrange
        }
        return status.behindBy == 0 ? .igOnlineGreen : .igGradOrange
    }

    private func importTerminalPrivateKey(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            let privateKey = try String(contentsOf: url, encoding: .utf8)
            try HermesSettingsPersistence.saveTerminalPrivateKey(privateKey)
            terminalSettings.hasPrivateKey = true
            terminalPrivateKeyStatus = "Private key imported into Keychain."
        } catch {
            terminalSettings.hasPrivateKey = HermesSettingsPersistence.hasTerminalPrivateKey()
            terminalPrivateKeyStatus = "Failed to import private key: \(error.localizedDescription)"
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
}

struct HermesSettingsStatusLED: View {
    let isOn: Bool
    let label: String

    var body: some View {
        Circle()
            .fill(isOn ? Color.igOnlineGreen : Color.igDestructive)
            .frame(width: 12, height: 12)
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.75), lineWidth: 1)
            }
            .shadow(color: (isOn ? Color.igOnlineGreen : Color.igDestructive).opacity(0.6), radius: 4)
            .accessibilityLabel(label)
            .help(label)
    }
}

private struct HermesSettingsMacService: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
}

private struct HermesSettingsMacServiceRow: View {
    let service: HermesSettingsMacService
    let status: HermesCompanionManagedServiceStatus?
    let isEnabled: Bool
    let onStart: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: service.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text(service.title)
                        .font(.subheadline.weight(.semibold))
                    Text(service.subtitle)
                        .font(.caption)
                        .foregroundStyle(.hermesSecondaryText)
                }

                Spacer()

                Label(statusLabel, systemImage: statusIcon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
            }

            HStack(spacing: 10) {
                Button {
                    onStart()
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .hermesGlassProminentButton()
                .disabled(!isEnabled || status == .running)

                Button(role: .destructive) {
                    onStop()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .hermesGlassButton()
                .disabled(!isEnabled || status == .stopped)
            }

        }
        .padding(.vertical, 6)
    }

    private var statusLabel: String {
        switch status {
        case .running: "Running"
        case .stopped: "Stopped"
        case .restarted: "Restarted"
        case .started: "Started"
        case .unknown: "Unknown"
        case nil: "Not checked"
        }
    }

    private var statusIcon: String {
        switch status {
        case .running, .started, .restarted: "checkmark.circle.fill"
        case .stopped: "stop.circle"
        case .unknown, nil: "questionmark.circle"
        }
    }

    private var statusColor: Color {
        switch status {
        case .running, .started, .restarted: .igOnlineGreen
        case .stopped: .igDestructive
        case .unknown, nil: .hermesSecondaryText
        }
    }
}
