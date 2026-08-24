//
//  HermesHostCompanionApp.swift
//  HermesHostCompanion
//
//  Created by Codex on 05/05/2026.
//

import SwiftUI
import Network
import AppKit
import CoreImage.CIFilterBuiltins
import Security

@main
struct HermesHostCompanionApp: App {
    @State private var serverController = CompanionServerController()

    var body: some Scene {
        MenuBarExtra {
            SettingsLink {
                Text("Settings")
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            Image("MenuBarIcon")
                .renderingMode(.template)
                .accessibilityLabel("Hermes Host Companion")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            HermesHostCompanionRootView(controller: serverController)
                .frame(
                    minWidth: 520,
                    idealWidth: 760,
                    maxWidth: .infinity,
                    minHeight: 460,
                    idealHeight: 560,
                    maxHeight: .infinity
                )
        }
        .windowResizability(.contentSize)
    }
}

private struct HermesHostCompanionRootView: View {
    @Bindable var controller: CompanionServerController

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hermes Host Companion")
                            .font(.largeTitle.bold())
                        Text("Minimal V1 companion daemon shell for QR-based HermesiOS device onboarding and revokable device approval.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        statusRow("State", controller.server.state.displayName)
                        statusRow("Endpoint", controller.server.listenerDescription)
                        statusRow("Last Error", controller.server.lastErrorMessage.isEmpty ? "None" : controller.server.lastErrorMessage)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Server Status", systemImage: "network")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Use your Tailscale hostname or stable IP here so the API endpoint targets the right machine from elsewhere on the same Tailnet. Localhost and Tailscale endpoints are advertised as WS over the encrypted Tailnet; other non-local hosts are advertised as WSS.")
                            .foregroundStyle(.secondary)

                        TextField("Advertised host or IP", text: $controller.advertisedHost)
                            .autocorrectionDisabled()

                        TextField("API port", text: $controller.apiPort)

                        adaptiveAction("Apply Network Target") {
                            controller.applyNetworkConfiguration()
                        } description: {
                            Text("The listener binds to local loopback. Tailscale's IPN extension forwards the tailnet port to this local listener; only non-Tailscale remote hosts need an HTTPS/WSS reverse proxy.")
                        }

                        Text(controller.server.state == .running ? "Applying host or port changes will restart the running companion server automatically." : "Apply the network target before copying the endpoint to iOS.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Network Target", systemImage: "point.3.connected.trianglepath.dotted")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("These service ports are the source of truth for HermesiOS. The iOS app fetches them from this companion after device approval and derives API, Dashboard, and Office URLs from its configured Mac host.")
                            .foregroundStyle(.secondary)

                        ViewThatFits(in: .horizontal) {
                            servicePortsGrid
                            VStack(alignment: .leading, spacing: 10) {
                                servicePortField("API gateway", placeholder: "8642", text: $controller.apiGatewayPort)
                                servicePortField("Hermes Dashboard", placeholder: "9120", text: $controller.dashboardPort)
                                servicePortField("Hermes Office", placeholder: "9116", text: $controller.officePort)
                            }
                        }

                        adaptiveAction("Save Service Ports") {
                            controller.applyServicePorts()
                        } description: {
                            Text("Saving is immediate; restart HermesiOS or check device approval again to refresh cached ports on iOS.")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Hermes Service Ports", systemImage: "number.square")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("These values are embedded in the onboarding QR code so HermesiOS can prefill its Hermes agent folder and API gateway credentials immediately after scanning.")
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Hermes agent config folder")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("/path/to/.hermes", text: $controller.hermesConfigFolderPath)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Hermes API gateway API key")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            SecureField("API key (Bearer optional)", text: $controller.apiGatewayAPIKey)
                                .textFieldStyle(.roundedBorder)
                        }

                        adaptiveAction("Save QR Settings") {
                            controller.applyOnboardingSettings()
                        } description: {
                            Text(controller.apiGatewayAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "QR contains no API key until one is set." : "API key is stored in Keychain and only shown through the QR code.")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Hermes Agent QR Settings", systemImage: "gearshape.2")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Onboard a HermesiOS device")
                            .font(.headline)
                        Text("Scan this QR code from HermesiOS Settings. The device receives a unique ID, appears below as pending, and can use host operations only after you approve it here.")
                            .foregroundStyle(.secondary)

                        statusRow("API URL", controller.apiURL)

                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .top, spacing: 18) {
                                onboardingQRCode
                                onboardingCodeDetails
                            }
                            VStack(alignment: .leading, spacing: 14) {
                                onboardingQRCode
                                onboardingCodeDetails
                            }
                        }

                        Divider()

                        HStack {
                            Text("Devices")
                                .font(.headline)
                            Spacer()
                            Button {
                                controller.refreshDevices()
                            } label: {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.borderless)
                        }

                        if controller.devices.isEmpty {
                            Text("No devices have requested onboarding yet.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(controller.devices) { device in
                                    CompanionDeviceRow(
                                        device: device,
                                        approve: { controller.approveDevice(device.id) },
                                        revoke: { controller.revokeDevice(device.id) },
                                        forget: { controller.forgetDevice(device.id) }
                                    )
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("QR Device Onboarding", systemImage: "qrcode.viewfinder")
                }

                HStack {
                    Button(controller.server.state == .running ? "Restart Server" : "Start Server") {
                        controller.startServer()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Stop Server") {
                        controller.stopServer()
                    }
                    .buttonStyle(.bordered)
                    .disabled(controller.server.state == .stopped)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle("Companion")
        }
        .task {
            controller.startServerIfNeeded()
            while !Task.isCancelled {
                controller.refreshDevices()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func statusRow(_ label: String, _ value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top) {
                Text(label).fontWeight(.semibold)
                Spacer()
                Text(value)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(label).fontWeight(.semibold)
                Text(value)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .font(.subheadline)
    }

    private var servicePortsGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
            GridRow { Text("API gateway").fontWeight(.semibold); TextField("8642", text: $controller.apiGatewayPort).frame(width: 120) }
            GridRow { Text("Hermes Dashboard").fontWeight(.semibold); TextField("9120", text: $controller.dashboardPort).frame(width: 120) }
            GridRow { Text("Hermes Office").fontWeight(.semibold); TextField("9116", text: $controller.officePort).frame(width: 120) }
        }
    }

    private func servicePortField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).fontWeight(.semibold)
            TextField(placeholder, text: text)
        }
    }

    private func adaptiveAction<Description: View>(
        _ title: String,
        action: @escaping () -> Void,
        @ViewBuilder description: () -> Description
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Button(title, action: action).buttonStyle(.borderedProminent)
                description().font(.caption).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Button(title, action: action).buttonStyle(.borderedProminent)
                description().font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var onboardingQRCode: some View {
        if let qrImage = controller.onboardingQRCodeImage {
            Image(nsImage: qrImage)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)
                .padding(10)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityLabel("HermesiOS onboarding QR code")
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(.quaternary)
                .frame(width: 180, height: 180)
                .overlay(Text("QR unavailable"))
        }
    }

    private var onboardingCodeDetails: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Current code").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(controller.onboardingCodePreview).font(.caption.monospaced()).textSelection(.enabled)
            Button("Rotate QR Code", systemImage: "qrcode", action: controller.rotateOnboardingCode)
                .buttonStyle(.bordered)
            Text("Rotating expires the displayed QR code. Already approved devices keep working until revoked.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}


private struct CompanionDeviceRow: View {
    let device: CompanionAuthorizedDeviceRecord
    let approve: () -> Void
    let revoke: () -> Void
    let forget: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                deviceSummary
                Spacer()
                deviceActions
            }
            VStack(alignment: .leading, spacing: 10) {
                deviceSummary
                deviceActions
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }

    private var deviceSummary: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.deviceName)
                    .font(.subheadline.weight(.semibold))
                Text(device.id)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                Text(device.statusLabel)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }
        }
    }

    @ViewBuilder
    private var deviceActions: some View {
        HStack(spacing: 8) {
            if device.approvedAt == nil && device.revokedAt == nil {
                Button("Approve", action: approve)
                    .buttonStyle(.borderedProminent)
            }

            if device.revokedAt == nil {
                Button("Revoke", role: .destructive, action: revoke)
                    .buttonStyle(.bordered)
            } else {
                Button("Forget", role: .destructive, action: forget)
                    .buttonStyle(.bordered)
            }
        }
    }

    private var statusIcon: String {
        if device.revokedAt != nil { return "xmark.circle.fill" }
        if device.approvedAt != nil { return "checkmark.circle.fill" }
        return "clock.badge.questionmark"
    }

    private var statusColor: Color {
        if device.revokedAt != nil { return .red }
        if device.approvedAt != nil { return .green }
        return .orange
    }
}

@MainActor
@Observable
final class CompanionServerController {
    let server = CompanionServer()
    var devices: [CompanionAuthorizedDeviceRecord] = CompanionDeviceAuthorizationStore.shared.devices
    var advertisedHost: String
    var apiPort: String
    var apiGatewayPort: String
    var dashboardPort: String
    var officePort: String
    var hermesConfigFolderPath: String
    var apiGatewayAPIKey: String
    nonisolated(unsafe) private var deviceChangeObserver: NSObjectProtocol?

    init() {
        advertisedHost = server.currentConfiguration.host
        apiPort = String(server.currentConfiguration.port.rawValue)
        let servicePorts = CompanionServicePortsStore.load()
        apiGatewayPort = servicePorts.apiGatewayPort
        dashboardPort = servicePorts.dashboardPort
        officePort = servicePorts.officePort
        let onboardingSettings = CompanionOnboardingSettingsStore.load()
        hermesConfigFolderPath = onboardingSettings.hermesConfigFolderPath
        apiGatewayAPIKey = onboardingSettings.apiGatewayAPIKey

        deviceChangeObserver = NotificationCenter.default.addObserver(
            forName: CompanionDeviceAuthorizationStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshDevices()
            }
        }

        // Start even if SwiftUI restores the app without immediately mounting the
        // root view's `.task`; the view task remains as an idempotent fallback.
        Task { @MainActor [weak self] in
            self?.startServerIfNeeded()
        }
    }

    var apiURL: String {
        server.currentConfiguration.webSocketURLString
    }

    deinit {
        if let deviceChangeObserver {
            NotificationCenter.default.removeObserver(deviceChangeObserver)
        }
    }

    var onboardingCodePreview: String {
        let code = CompanionDeviceAuthorizationStore.shared.onboardingCode
        return "\(code.prefix(8))…\(code.suffix(8))"
    }

    var onboardingQRCodeImage: NSImage? {
        let sanitizedSettings = CompanionOnboardingSettingsStore.sanitize(
            hermesConfigFolderPath: hermesConfigFolderPath,
            apiGatewayAPIKey: apiGatewayAPIKey
        )
        let payload = CompanionDeviceAuthorizationStore.shared.qrPayload(
            endpoint: apiURL,
            hermesConfigFolderPath: sanitizedSettings.hermesConfigFolderPath,
            apiGatewayAPIKey: sanitizedSettings.apiGatewayAPIKey
        )
        guard let data = try? JSONEncoder().encode(payload),
              let text = String(data: data, encoding: .utf8)
        else { return nil }
        return Self.makeQRCode(from: text)
    }

    func startServerIfNeeded() {
        guard server.state == .stopped else { return }
        applyNetworkConfiguration()
        startServer()
    }

    func startServer() {
        Task {
            do {
                try await server.start()
            } catch {
                server.lastErrorMessage = error.localizedDescription
            }
        }
    }

    func stopServer() {
        server.stop()
    }

    func rotateOnboardingCode() {
        CompanionDeviceAuthorizationStore.shared.rotateOnboardingCode()
        refreshDevices()
    }

    func refreshDevices() {
        devices = CompanionDeviceAuthorizationStore.shared.devices
    }

    func approveDevice(_ id: String) {
        CompanionDeviceAuthorizationStore.shared.approveDevice(id: id)
        refreshDevices()
    }

    func revokeDevice(_ id: String) {
        CompanionDeviceAuthorizationStore.shared.revokeDevice(id: id)
        refreshDevices()
    }

    func forgetDevice(_ id: String) {
        CompanionDeviceAuthorizationStore.shared.forgetDevice(id: id)
        refreshDevices()
    }

    private static func makeQRCode(from text: String) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let transformed = output.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let representation = NSCIImageRep(ciImage: transformed)
        let image = NSImage(size: representation.size)
        image.addRepresentation(representation)
        return image
    }

    func applyServicePorts() {
        let ports = CompanionServicePortsStore.sanitize(
            apiGatewayPort: apiGatewayPort,
            dashboardPort: dashboardPort,
            officePort: officePort
        )
        apiGatewayPort = ports.apiGatewayPort
        dashboardPort = ports.dashboardPort
        officePort = ports.officePort
        CompanionServicePortsStore.save(ports)
    }

    func applyOnboardingSettings() {
        let settings = CompanionOnboardingSettingsStore.sanitize(
            hermesConfigFolderPath: hermesConfigFolderPath,
            apiGatewayAPIKey: apiGatewayAPIKey
        )
        hermesConfigFolderPath = settings.hermesConfigFolderPath
        apiGatewayAPIKey = settings.apiGatewayAPIKey
        CompanionOnboardingSettingsStore.save(settings)
        refreshDevices()
    }

    func applyNetworkConfiguration() {
        let rawHost = advertisedHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = CompanionServerConfiguration.sanitizedHost(rawHost)
        let resolvedPort = CompanionServerConfiguration.port(
            from: apiPort.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? rawHost : apiPort,
            fallback: CompanionServerConfiguration.default.port
        )
        let shouldRestart = server.state == .running

        advertisedHost = host
        apiPort = String(resolvedPort.rawValue)
        server.updateConfiguration(
            CompanionServerConfiguration(
                host: host,
                port: resolvedPort
            )
        )

        if shouldRestart {
            stopServer()
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 300_000_000)
                self?.startServer()
            }
        }
    }
}


struct CompanionOnboardingSettings: Equatable {
    var hermesConfigFolderPath: String
    var apiGatewayAPIKey: String
}

enum CompanionOnboardingSettingsStore {
    private static let hermesConfigFolderPathKey = "hermes.onboarding.configFolderPath"
    private static let apiGatewayAPIKeyService = "com.nous.HermesHostCompanion.gateway"
    private static let apiGatewayAPIKeyAccount = "apiGatewayAPIKey"

    static let defaultConfigFolderPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".hermes")
        .path

    static func load() -> CompanionOnboardingSettings {
        let hermesConfigFolderPath = UserDefaults.standard.string(forKey: hermesConfigFolderPathKey) ?? defaultConfigFolderPath
        let savedAPIKey = loadKeychainString(service: apiGatewayAPIKeyService, account: apiGatewayAPIKeyAccount)
        let effectiveAPIKey = savedAPIKey.isEmpty ? loadAPIKeyFromEnv(hermesConfigFolderPath: hermesConfigFolderPath) : savedAPIKey
        return sanitize(
            hermesConfigFolderPath: hermesConfigFolderPath,
            apiGatewayAPIKey: effectiveAPIKey
        )
    }

    static func save(_ settings: CompanionOnboardingSettings) {
        let sanitized = sanitize(
            hermesConfigFolderPath: settings.hermesConfigFolderPath,
            apiGatewayAPIKey: settings.apiGatewayAPIKey
        )
        if sanitized.hermesConfigFolderPath.isEmpty {
            UserDefaults.standard.removeObject(forKey: hermesConfigFolderPathKey)
        } else {
            UserDefaults.standard.set(sanitized.hermesConfigFolderPath, forKey: hermesConfigFolderPathKey)
        }
        saveKeychainString(sanitized.apiGatewayAPIKey, service: apiGatewayAPIKeyService, account: apiGatewayAPIKeyAccount)
    }

    static func sanitize(hermesConfigFolderPath: String, apiGatewayAPIKey: String) -> CompanionOnboardingSettings {
        CompanionOnboardingSettings(
            hermesConfigFolderPath: hermesConfigFolderPath.trimmingCharacters(in: .whitespacesAndNewlines),
            apiGatewayAPIKey: normalizeAPIKey(apiGatewayAPIKey)
        )
    }

    private static func normalizeAPIKey(_ value: String) -> String {
        var token = value.trimmingCharacters(in: .whitespacesAndNewlines)
        while token.range(of: "Bearer ", options: [.caseInsensitive, .anchored]) != nil {
            token = String(token.dropFirst("Bearer ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return token
    }

    private static func loadAPIKeyFromEnv(hermesConfigFolderPath: String) -> String {
        let folder = hermesConfigFolderPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !folder.isEmpty else { return "" }
        let envURL = URL(fileURLWithPath: folder, isDirectory: true).appendingPathComponent(".env")
        guard let content = try? String(contentsOf: envURL, encoding: .utf8) else { return "" }
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("API_SERVER_KEY=") else { continue }
            let rawValue = String(trimmed.dropFirst("API_SERVER_KEY=".count))
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            return normalizeAPIKey(rawValue)
        }
        return ""
    }

    private static func loadKeychainString(service: String, account: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else { return "" }
        return value
    }

    private static func saveKeychainString(_ value: String, service: String, account: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if trimmed.isEmpty {
            SecItemDelete(baseQuery as CFDictionary)
            return
        }
        let data = Data(trimmed.utf8)
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        if status == errSecSuccess { return }
        var addQuery = baseQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(addQuery as CFDictionary, nil)
    }
}


enum CompanionServicePortsStore {
    private static let apiGatewayPortKey = "hermes.servicePorts.apiGateway"
    private static let dashboardPortKey = "hermes.servicePorts.dashboard"
    private static let officePortKey = "hermes.servicePorts.office"

    static let defaultPorts = CompanionServicePortsResult(
        apiGatewayPort: "8642",
        dashboardPort: "9120",
        officePort: "9116"
    )

    static func load() -> CompanionServicePortsResult {
        let defaults = UserDefaults.standard
        return sanitize(
            apiGatewayPort: defaults.string(forKey: apiGatewayPortKey) ?? defaultPorts.apiGatewayPort,
            dashboardPort: defaults.string(forKey: dashboardPortKey) ?? defaultPorts.dashboardPort,
            officePort: defaults.string(forKey: officePortKey) ?? defaultPorts.officePort
        )
    }

    static func save(_ ports: CompanionServicePortsResult) {
        let sanitized = sanitize(
            apiGatewayPort: ports.apiGatewayPort,
            dashboardPort: ports.dashboardPort,
            officePort: ports.officePort
        )
        let defaults = UserDefaults.standard
        defaults.set(sanitized.apiGatewayPort, forKey: apiGatewayPortKey)
        defaults.set(sanitized.dashboardPort, forKey: dashboardPortKey)
        defaults.set(sanitized.officePort, forKey: officePortKey)
    }

    static func sanitize(apiGatewayPort: String, dashboardPort: String, officePort: String) -> CompanionServicePortsResult {
        CompanionServicePortsResult(
            apiGatewayPort: sanitizedPort(apiGatewayPort, fallback: defaultPorts.apiGatewayPort),
            dashboardPort: sanitizedPort(dashboardPort, fallback: defaultPorts.dashboardPort),
            officePort: sanitizedPort(officePort, fallback: defaultPorts.officePort)
        )
    }

    private static func sanitizedPort(_ value: String, fallback: String) -> String {
        let digits = value.trimmingCharacters(in: .whitespacesAndNewlines).filter(\.isNumber)
        guard let port = UInt16(digits), port > 0 else { return fallback }
        return String(port)
    }
}
