//
//  HermesSettingsView.swift
//  HermesiOS
//

import AVFoundation
import Observation
import SwiftUI
import UIKit
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
    let canSwitchHosts: Bool

    @AppStorage(hermesMacHostStorageKey) private var macHost = defaultHermesMacHost
    @AppStorage(hermesDashboardPortStorageKey) private var dashboardPort = defaultHermesDashboardPort
    @AppStorage(hermesOfficePortStorageKey) private var officePort = defaultHermesOfficePort
    @AppStorage(hermesRuntimeTabEnabledStorageKey) private var isRuntimeTabEnabled = false
    @AppStorage(hermesAskTabEnabledStorageKey) private var isAskHermesTabEnabled = true
    @AppStorage(hermesChatTabEnabledStorageKey) private var isChatWithHermesTabEnabled = true
    @AppStorage("hermes.history.dashboardURL") private var legacyDashboardURL = ""
    @AppStorage("hermes.office.url") private var legacyOfficeURL = ""

    @State private var dashboardGatewayRestart = HermesDashboardGatewayRestartSession()
    @State private var isImportingTerminalPrivateKey = false
    @State private var terminalPrivateKeyStatus = ""
    @State private var isScanningCompanionQRCode = false
    @State private var isConfirmingForgetActiveHost = false

    private let macServices: [HermesSettingsMacService] = [
        .init(id: "hermes-dashboard", title: "Hermes Dashboard Proxy", subtitle: "Host-rewriting dashboard proxy", icon: "rectangle.on.rectangle.angled"),
        .init(id: "hermes-dashboard-app", title: "Hermes Dashboard App", subtitle: "Dashboard web application", icon: "chart.bar.doc.horizontal"),
        .init(id: "claw3d-adapter", title: "Claw3D Adapter", subtitle: "Hermes Office / Claw3D bridge", icon: "cube.transparent"),
        .init(id: "hermes3d", title: "Hermes 3D / Office", subtitle: "Hermes Office web app", icon: "cube"),
        .init(id: "hermes-claude-bridge", title: "Hermes Claude Bridge", subtitle: "Claude CLI model bridge", icon: "arrow.triangle.branch"),
        .init(id: "hindsight-daemon", title: "Hindsight Daemon", subtitle: "Long-term memory daemon", icon: "brain")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HermesTabHeader("Settings", systemImage: "slider.horizontal.3")
                .padding(.horizontal)
                .padding(.top)

            Form {
                HermesSettingsConnectionSection(
                    macHost: $macHost,
                    companionSettings: $companionSettings,
                    companionEnrollment: companionEnrollment,
                    canSwitchHosts: canSwitchHosts,
                    companionPortBinding: companionPortBinding,
                    activeCompanionConnectionBinding: activeCompanionConnectionBinding,
                    onScanQRCode: { isScanningCompanionQRCode = true },
                    onForgetConnection: { connectionID in
                        companionEnrollment.forgetConnection(id: connectionID)
                        syncActiveCompanionConnectionToSettings()
                    }
                )

                HermesSettingsGatewaySection(
                    apiSettings: $apiSettings,
                    dashboardGatewayRestart: dashboardGatewayRestart,
                    dashboardURL: dashboardURL
                )

                HermesSettingsAssistantsSection(
                    responsesDraft: $responsesDraft,
                    chatDraft: $chatDraft
                )

                HermesSettingsTabsSection(
                    isAskHermesTabEnabled: $isAskHermesTabEnabled,
                    isChatWithHermesTabEnabled: $isChatWithHermesTabEnabled,
                    isRuntimeTabEnabled: $isRuntimeTabEnabled
                )

                HermesSettingsTerminalSection(
                    terminalSettings: $terminalSettings,
                    privateKeyStatus: $terminalPrivateKeyStatus,
                    onImportPrivateKey: { isImportingTerminalPrivateKey = true }
                )

                HermesOfficeSettingsSection()

                HermesSettingsMacServicesSection(
                    services: macServices,
                    companionRuntime: companionRuntime,
                    isEnrolled: companionEnrollment.identityState.isEnrolled,
                    onStart: { serviceID in
                        companionRuntime.startMacService(
                            serviceID,
                            settings: companionSettings,
                            identityState: companionEnrollment.identityState
                        )
                    },
                    onStop: { serviceID in
                        companionRuntime.stopMacService(
                            serviceID,
                            settings: companionSettings,
                            identityState: companionEnrollment.identityState
                        )
                    },
                    onRefresh: {
                        companionRuntime.refreshMacServices(
                            macServices.map(\.id),
                            settings: companionSettings,
                            identityState: companionEnrollment.identityState
                        )
                    }
                )

                Section("Appearance") {
                    Picker("App Theme", selection: $appTheme) {
                        ForEach(HermesAppTheme.allCases) { theme in
                            Text(theme.title).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if companionEnrollment.identityState.hasPairing {
                    Section {
                        Button(role: .destructive) {
                            isConfirmingForgetActiveHost = true
                        } label: {
                            Label("Forget Active Host", systemImage: "trash")
                        }
                        .hermesGlassButton()
                        .disabled(!canSwitchHosts)
                    } header: {
                        Text("Danger zone")
                    } footer: {
                        Text("Removes this device's pairing with the active Mac. You will need to scan its QR code and approve the device again.")
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
        .onAppear {
            migrateLegacyURLPortsIfNeeded()
            applyMacHostToServiceURLs()
        }
        .onChange(of: macHost) { _, _ in
            applyMacHostToServiceURLs()
            companionEnrollment.invalidateIfSettingsChanged(settings: companionSettings)
        }
        .onChange(of: companionSettings.apiURL) { _, _ in
            companionEnrollment.invalidateIfSettingsChanged(settings: companionSettings)
        }
        .onChange(of: companionEnrollment.activeConnectionID) { _, _ in
            syncActiveCompanionConnectionToSettings()
        }
        .fileImporter(
            isPresented: $isImportingTerminalPrivateKey,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false,
            onCompletion: importTerminalPrivateKey
        )
        .sheet(isPresented: $isScanningCompanionQRCode) {
            HermesCompanionQRScannerView { scannedText in
                isScanningCompanionQRCode = false
                handleCompanionQRCode(scannedText)
            }
        }
        .confirmationDialog(
            "Forget the active host?",
            isPresented: $isConfirmingForgetActiveHost,
            titleVisibility: .visible
        ) {
            Button("Forget Active Host", role: .destructive) {
                companionEnrollment.clearIdentity()
                companionSettings.deviceSecret = HermesSettingsPersistence.loadCompanionDeviceSecret()
                syncActiveCompanionConnectionToSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This device's pairing with the active Mac will be removed.")
        }
    }

    private var companionPortBinding: Binding<String> {
        Binding(
            get: { HermesHostEndpoints.tcpPort(from: companionSettings.apiURL, fallback: defaultHermesCompanionPort) },
            set: { newPort in
                companionSettings.apiURL = HermesHostEndpoints.webSocketURLString(host: macHost, port: newPort)
            }
        )
    }

    private var activeCompanionConnectionBinding: Binding<String> {
        Binding(
            get: { companionEnrollment.activeConnectionID },
            set: { newConnectionID in
                guard canSwitchHosts else { return }
                companionEnrollment.activateConnection(id: newConnectionID)
                syncActiveCompanionConnectionToSettings()
            }
        )
    }

    private var dashboardURL: String {
        HermesHostEndpoints.dashboardURLString(host: macHost, port: dashboardPort)
    }

    private var hostDefinedServicePorts: HermesCompanionServicePortsResult {
        companionRuntime.servicePorts
    }

    private func applyMacHostToServiceURLs(preserveCompanionEndpoint: Bool = false) {
        let apiPort = HermesHostEndpoints.tcpPort(from: hostDefinedServicePorts.apiGatewayPort, fallback: HermesHostEndpoints.tcpPort(from: apiSettings.baseURL, fallback: defaultHermesAPIPort))
        apiSettings.baseURL = HermesHostEndpoints.httpURLString(host: macHost, port: apiPort, path: "/v1")
        if preserveCompanionEndpoint == false {
            companionSettings.apiURL = HermesHostEndpoints.webSocketURLString(host: macHost, port: companionPortBinding.wrappedValue)
        }
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

    private func syncActiveCompanionConnectionToSettings() {
        guard let connection = companionEnrollment.connection(for: companionEnrollment.activeConnectionID) else {
            companionSettings.deviceSecret = ""
            return
        }
        companionSettings.apiURL = connection.identityState.serverEndpoint
        companionSettings.deviceSecret = HermesSettingsPersistence.loadCompanionDeviceSecret(deviceID: connection.id)
        if let host = URL(string: connection.identityState.serverEndpoint)?.host, host.isEmpty == false {
            macHost = host
            applyMacHostToServiceURLs(preserveCompanionEndpoint: true)
        }
    }

    private func handleCompanionQRCode(_ scannedText: String) {
        isScanningCompanionQRCode = false
        do {
            let payload = try HermesCompanionOnboardingPayload.decode(from: scannedText)
            let shouldActivate = canSwitchHosts || companionEnrollment.identityState.hasPairing == false
            if shouldActivate {
                companionSettings.apiURL = payload.endpoint
                if let host = URL(string: payload.endpoint)?.host, host.isEmpty == false {
                    macHost = host
                    applyMacHostToServiceURLs(preserveCompanionEndpoint: true)
                }
                if let hermesConfigFolderPath = payload.hermesConfigFolderPath?.trimmingCharacters(in: .whitespacesAndNewlines),
                   hermesConfigFolderPath.isEmpty == false {
                    companionSettings.hermesWorkspacePath = hermesConfigFolderPath
                }
                if let apiGatewayAPIKey = payload.apiGatewayAPIKey {
                    apiSettings.apiKey = HermesAPISettings.normalizedAPIKey(apiGatewayAPIKey)
                }
            }
            companionEnrollment.enroll(onboarding: payload, deviceName: UIDevice.current.name, activateWhenFinished: shouldActivate)
        } catch {
            companionEnrollment.resetAfterPairingFailure(message: error.localizedDescription)
        }
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
}

// MARK: - Connection

private struct HermesSettingsConnectionSection: View {
    @Binding var macHost: String
    @Binding var companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    let canSwitchHosts: Bool
    let companionPortBinding: Binding<String>
    let activeCompanionConnectionBinding: Binding<String>
    let onScanQRCode: () -> Void
    let onForgetConnection: (String) -> Void

    var body: some View {
        Section {
            TextField("Hostname or IP, e.g. .ts.net", text: $macHost)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .hermesRuntimeInput()

            TextField("Host Companion TCP port", text: companionPortBinding)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.numberPad)

            HermesSettingsValueRow(label: "WebSocket URL", value: companionSettings.apiURL)

            if let warning = HermesEndpointSecurity.plaintextTransportWarning(for: companionSettings.apiURL, endpointName: "Host Companion") {
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.igDestructive)
            }
        } header: {
            Text("Mac host")
        } footer: {
            Text("Used with the service TCP ports to build the HTTPS and WSS URLs, and as the SSH host for the Terminal tab.")
        }

        Section {
            if companionEnrollment.connections.isEmpty == false {
                Picker("Active Host", selection: activeCompanionConnectionBinding) {
                    ForEach(companionEnrollment.connections) { connection in
                        Text("\(connection.displayName) — \(connection.statusLabel)").tag(connection.id)
                    }
                }
                .pickerStyle(.menu)
                .disabled(companionEnrollment.isEnrolling || !canSwitchHosts)

                if !canSwitchHosts {
                    Text("Host switching is disabled while any Ask Hermes, Chat with Hermes, or TUI Gateway response is streaming.")
                        .font(.caption)
                        .foregroundStyle(.igGradOrange)
                }
            }

            HStack(alignment: .center, spacing: 10) {
                HermesSettingsStatusLED(
                    isOn: companionEnrollment.identityState.isEnrolled,
                    label: companionEnrollment.identityState.isEnrolled ? "Device approved" : "Device not approved"
                )

                VStack(alignment: .leading, spacing: 3) {
                    Text(deviceStatusTitle)
                        .font(.subheadline.weight(.semibold))
                    if companionEnrollment.identityState.deviceID.isEmpty == false {
                        Text(companionEnrollment.identityState.deviceID)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.hermesSecondaryText)
                            .textSelection(.enabled)
                    }
                }

                Spacer()

                Button(action: onScanQRCode) {
                    Label("Scan QR", systemImage: "qrcode.viewfinder")
                }
                .hermesGlassProminentButton()
                .disabled(companionEnrollment.isEnrolling)

                if companionEnrollment.identityState.hasPairing {
                    Button("Check Approval") {
                        companionEnrollment.checkApproval(settings: companionSettings)
                    }
                    .hermesGlassButton()
                    .disabled(companionEnrollment.isEnrolling)
                }
            }
            .accessibilityElement(children: .combine)

            if companionEnrollment.connections.isEmpty == false {
                ForEach(companionEnrollment.connections) { connection in
                    HermesCompanionSavedHostRow(
                        connection: connection,
                        isActive: connection.id == companionEnrollment.activeConnectionID,
                        isBusy: companionEnrollment.isEnrolling,
                        canForget: canSwitchHosts || connection.id != companionEnrollment.activeConnectionID,
                        onCheckApproval: {
                            companionEnrollment.checkApproval(settings: companionSettings, connectionID: connection.id)
                        },
                        onForget: { onForgetConnection(connection.id) }
                    )
                }
            }

            if !companionEnrollment.lastErrorMessage.isEmpty {
                Text(companionEnrollment.lastErrorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.igDestructive)
            }
        } header: {
            Text("Host Companion")
        } footer: {
            Text("Open HermesHostCompanion on each Mac, scan each QR code, then approve this iOS device in every companion app you want to use. Saved hosts keep independent device approval state.")
        }

        Section {
            TextField("Hermes workspace path", text: $companionSettings.hermesWorkspacePath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("Hermes agent root folder")
        }
    }

    private var deviceStatusTitle: String {
        if companionEnrollment.identityState.revokedAt != nil { return "Device revoked" }
        if companionEnrollment.identityState.isEnrolled { return "Device approved" }
        if companionEnrollment.identityState.isPendingApproval { return "Waiting for Mac approval" }
        return "No device paired"
    }
}

// MARK: - API Gateway

private struct HermesSettingsGatewaySection: View {
    @Binding var apiSettings: HermesAPISettings
    @Bindable var dashboardGatewayRestart: HermesDashboardGatewayRestartSession
    let dashboardURL: String

    var body: some View {
        Section {
            SecureField("API key (Bearer optional)", text: $apiSettings.apiKey)

            Toggle("Allow self-signed HTTPS certificates", isOn: $apiSettings.allowSelfSignedCertificates)

            if let warning = HermesEndpointSecurity.plaintextTransportWarning(for: apiSettings.baseURL, endpointName: "Hermes API") {
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.igDestructive)
            }

            if apiSettings.allowSelfSignedCertificates {
                Text("Self-signed certificates are only accepted for localhost or .ts.net hosts, and the first certificate fingerprint is pinned. A changed fingerprint is rejected until the saved connection is reset.")
                    .font(.caption)
                    .foregroundStyle(.igGradOrange)
            }

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

            if dashboardGatewayRestart.status != "Idle" {
                HermesSettingsValueRow(label: "Status", value: dashboardGatewayRestart.status)
            }

            if !dashboardGatewayRestart.lastErrorMessage.isEmpty {
                Text(dashboardGatewayRestart.lastErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.igDestructive)
            }
        } header: {
            Text("API Gateway")
        } footer: {
            Text("The API gateway TCP port is configured in HermesHostCompanion and fetched automatically after device approval. Restart posts to /api/gateway/restart on the dashboard URL.")
        }
    }
}

// MARK: - Assistants

private struct HermesSettingsAssistantsSection: View {
    @Binding var responsesDraft: HermesRequestDraft
    @Binding var chatDraft: HermesChatDraft

    var body: some View {
        Section {
            Toggle("Streaming enabled", isOn: $chatDraft.stream)

            VStack(alignment: .leading, spacing: 6) {
                Text("Common system prompt (optional)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.hermesSecondaryText)

                TextField("System prompt", text: $chatDraft.systemPrompt, axis: .vertical)
                    .lineLimit(4, reservesSpace: true)
            }
        } header: {
            Text("Chat with Hermes")
        }

        Section {
            Toggle("Streaming enabled", isOn: $responsesDraft.stream)
        } header: {
            Text("Ask Hermes")
        }
    }
}

// MARK: - Tabs

private struct HermesSettingsTabsSection: View {
    @Binding var isAskHermesTabEnabled: Bool
    @Binding var isChatWithHermesTabEnabled: Bool
    @Binding var isRuntimeTabEnabled: Bool

    var body: some View {
        Section {
            Toggle("Ask Hermes", isOn: $isAskHermesTabEnabled)
            Toggle("Chat with Hermes", isOn: $isChatWithHermesTabEnabled)
            Toggle("Hermes Agent Runtime", isOn: $isRuntimeTabEnabled)
        } header: {
            Text("Tabs")
        } footer: {
            Text("Ask Hermes and Chat with Hermes are enabled by default. Agent Runtime is off by default; enable it only when you need the runtime management panels in the tab bar and iPad sidebar.")
        }
    }
}

// MARK: - Terminal

private struct HermesSettingsTerminalSection: View {
    @Binding var terminalSettings: HermesTerminalSettings
    @Binding var privateKeyStatus: String
    let onImportPrivateKey: () -> Void

    var body: some View {
        Section {
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

                Button(action: onImportPrivateKey) {
                    Label("Choose Private Key", systemImage: "doc.badge.plus")
                }
                .hermesGlassButton()

                if terminalSettings.hasPrivateKey {
                    Button(role: .destructive) {
                        HermesSettingsPersistence.deleteTerminalPrivateKey()
                        terminalSettings.hasPrivateKey = false
                        privateKeyStatus = "Private key removed from Keychain."
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    .hermesGlassButton()
                }
            }

            if !privateKeyStatus.isEmpty {
                Text(privateKeyStatus)
                    .font(.caption)
                    .foregroundStyle(privateKeyStatus.hasPrefix("Failed") ? .igDestructive : .hermesSecondaryText)
            }
        } header: {
            Text("Terminal")
        } footer: {
            Text("The selected key file is imported into Keychain and is not stored in Settings. Terminal connections require Face ID to retrieve it.")
        }
    }
}

// MARK: - Mac services

private struct HermesSettingsMacServicesSection: View {
    let services: [HermesSettingsMacService]
    @Bindable var companionRuntime: HermesCompanionRuntimeSession
    let isEnrolled: Bool
    let onStart: (String) -> Void
    let onStop: (String) -> Void
    let onRefresh: () -> Void

    var body: some View {
        Section {
            if isEnrolled == false {
                Text("Approve this device in Host Companion before controlling Mac services from iOS.")
                    .font(.caption)
                    .foregroundStyle(.hermesSecondaryText)
            }

            ForEach(services) { service in
                HermesSettingsMacServiceRow(
                    service: service,
                    status: companionRuntime.macServiceStatuses[service.id]?.status,
                    isEnabled: isEnrolled && !companionRuntime.isBusy,
                    onStart: { onStart(service.id) },
                    onStop: { onStop(service.id) }
                )
            }

            Button(action: onRefresh) {
                Label("Refresh Service Status", systemImage: "arrow.clockwise")
            }
            .hermesGlassButton()
            .disabled(isEnrolled == false || companionRuntime.isBusy)
        } header: {
            Text("Mac Services")
        }
    }
}

// MARK: - Shared rows

private struct HermesSettingsValueRow: View {
    let label: String
    let value: String

    var body: some View {
        LabeledContent(label) {
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

private struct HermesCompanionSavedHostRow: View {
    let connection: HermesCompanionSavedConnection
    let isActive: Bool
    let isBusy: Bool
    let canForget: Bool
    let onCheckApproval: () -> Void
    let onForget: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(connection.displayName)
                        .font(.subheadline.weight(.semibold))
                    if isActive {
                        Text("Active")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.igActionBlue))
                    }
                }
                Text(connection.identityState.serverEndpoint)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.hermesSecondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(connection.statusLabel)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }

            Spacer()

            Button("Check") {
                onCheckApproval()
            }
            .buttonStyle(.bordered)
            .disabled(isBusy)

            Button(role: .destructive) {
                onForget()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(isBusy || !canForget)
            .accessibilityLabel("Forget \(connection.displayName)")
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.hermesSurfaceInput.opacity(0.72))
        )
    }

    private var statusIcon: String {
        if connection.identityState.revokedAt != nil { return "xmark.circle.fill" }
        if connection.identityState.isEnrolled { return "checkmark.circle.fill" }
        if connection.identityState.isPendingApproval { return "clock.fill" }
        return "questionmark.circle"
    }

    private var statusColor: Color {
        if connection.identityState.revokedAt != nil { return .igDestructive }
        if connection.identityState.isEnrolled { return .igOnlineGreen }
        if connection.identityState.isPendingApproval { return .igGradOrange }
        return .hermesSecondaryText
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

// MARK: - QR scanning

private struct HermesCompanionQRScannerView: UIViewRepresentable {
    let onCode: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode)
    }

    func makeUIView(context: Context) -> QRScannerPreviewView {
        let view = QRScannerPreviewView()
        let session = AVCaptureSession()
        context.coordinator.session = session

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else {
            return view
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return view }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(context.coordinator, queue: .main)
        output.metadataObjectTypes = [.qr]

        view.previewLayer.session = session
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
        return view
    }

    func updateUIView(_ uiView: QRScannerPreviewView, context: Context) {}

    static func dismantleUIView(_ uiView: QRScannerPreviewView, coordinator: Coordinator) {
        coordinator.session?.stopRunning()
        coordinator.session = nil
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onCode: (String) -> Void
        var session: AVCaptureSession?
        private var didScan = false

        init(onCode: @escaping (String) -> Void) {
            self.onCode = onCode
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard didScan == false,
                  let object = metadataObjects.compactMap({ $0 as? AVMetadataMachineReadableCodeObject }).first,
                  object.type == .qr,
                  let value = object.stringValue
            else { return }
            didScan = true
            session?.stopRunning()
            onCode(value)
        }
    }
}

private final class QRScannerPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.videoGravity = .resizeAspectFill
    }
}
