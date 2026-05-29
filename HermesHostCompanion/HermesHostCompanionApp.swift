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
                .frame(width: 760, height: 560)
        }
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

                        HStack {
                            Button("Apply Network Target") {
                                controller.applyNetworkConfiguration()
                            }
                            .buttonStyle(.borderedProminent)

                            Text("The listener binds to local loopback. Tailscale's IPN extension forwards the tailnet port to this local listener; only non-Tailscale remote hosts need an HTTPS/WSS reverse proxy.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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

                        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
                            GridRow {
                                Text("API gateway")
                                    .fontWeight(.semibold)
                                TextField("8642", text: $controller.apiGatewayPort)
                                    .frame(width: 120)
                            }
                            GridRow {
                                Text("Hermes Dashboard")
                                    .fontWeight(.semibold)
                                TextField("9120", text: $controller.dashboardPort)
                                    .frame(width: 120)
                            }
                            GridRow {
                                Text("Hermes Office")
                                    .fontWeight(.semibold)
                                TextField("9116", text: $controller.officePort)
                                    .frame(width: 120)
                            }
                        }

                        HStack {
                            Button("Save Service Ports") {
                                controller.applyServicePorts()
                            }
                            .buttonStyle(.borderedProminent)

                            Text("Saving is immediate; restart HermesiOS or check device approval again to refresh cached ports on iOS.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Hermes Service Ports", systemImage: "number.square")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Onboard a HermesiOS device")
                            .font(.headline)
                        Text("Scan this QR code from HermesiOS Settings. The device receives a unique ID, appears below as pending, and can use host operations only after you approve it here.")
                            .foregroundStyle(.secondary)

                        statusRow("API URL", controller.apiURL)

                        HStack(alignment: .top, spacing: 18) {
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

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Current code")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(controller.onboardingCodePreview)
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                                Button {
                                    controller.rotateOnboardingCode()
                                } label: {
                                    Label("Rotate QR Code", systemImage: "qrcode")
                                }
                                .buttonStyle(.bordered)
                                Text("Rotating expires the displayed QR code. Already approved devices keep working until revoked.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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


private struct CompanionDeviceRow: View {
    let device: CompanionAuthorizedDeviceRecord
    let approve: () -> Void
    let revoke: () -> Void
    let forget: () -> Void

    var body: some View {
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

            Spacer()

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
        .padding(10)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
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
    nonisolated(unsafe) private var deviceChangeObserver: NSObjectProtocol?

    init() {
        advertisedHost = server.currentConfiguration.host
        apiPort = String(server.currentConfiguration.port.rawValue)
        let servicePorts = CompanionServicePortsStore.load()
        apiGatewayPort = servicePorts.apiGatewayPort
        dashboardPort = servicePorts.dashboardPort
        officePort = servicePorts.officePort

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
        let payload = CompanionDeviceAuthorizationStore.shared.qrPayload(endpoint: apiURL)
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
