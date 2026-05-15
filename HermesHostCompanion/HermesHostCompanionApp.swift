//
//  HermesHostCompanionApp.swift
//  HermesHostCompanion
//
//  Created by Codex on 05/05/2026.
//

import SwiftUI
import Network
import AppKit

@main
struct HermesHostCompanionApp: App {
    @State private var serverController = CompanionServerController()

    var body: some Scene {
        WindowGroup {
            HermesHostCompanionRootView(controller: serverController)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 760, height: 560)
    }
}

private struct HermesHostCompanionRootView: View {
    @Bindable var controller: CompanionServerController

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hermes Host Companion")
                        .font(.largeTitle.bold())
                    Text("Minimal V1 companion daemon shell for plain HTTP WebSocket access protected by one 256-character API key.")
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
                        Text("Use your Tailscale hostname or stable IP here so the API endpoint targets the right machine from elsewhere on the same Tailnet.")
                            .foregroundStyle(.secondary)

                        TextField("Advertised host or IP", text: $controller.advertisedHost)
                            .autocorrectionDisabled()

                        TextField("API port", text: $controller.apiPort)

                        HStack {
                            Button("Apply Network Target") {
                                controller.applyNetworkConfiguration()
                            }
                            .buttonStyle(.borderedProminent)

                            Text("The listener binds to local loopback; this advertised value controls the endpoint shown to iOS clients and may be served through Tailscale.")
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
                        Text("These service ports are the source of truth for HermesiOS. The iOS app fetches them from this companion after API-key verification and derives API, Dashboard, and Office URLs from its configured Mac host.")
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

                            Text("Saving is immediate; restart HermesiOS or tap Verify API Key again to refresh cached ports on iOS.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Hermes Service Ports", systemImage: "number.square")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Authentication")
                            .font(.headline)
                        Text("The companion uses a single 256-character API key over plain HTTP WebSocket. Copy this key into HermesiOS settings. No TLS, certificates, QR codes, enrollment ports, pairing IDs, or CA material are used.")
                            .foregroundStyle(.secondary)

                        statusRow("API URL", controller.apiURL)

                        Text("API Key")
                            .font(.subheadline.bold())
                        HStack(alignment: .top, spacing: 8) {
                            Text(controller.authenticationToken)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                                .lineLimit(6)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                controller.copyAuthenticationToken()
                            } label: {
                                Image(systemName: "doc.on.doc")
                                    .accessibilityLabel("Copy API key")
                            }
                            .buttonStyle(.borderless)
                            .help("Copy API key")
                        }

                        HStack {
                            Button("Regenerate 256-character API Key", role: .destructive) {
                                controller.regenerateToken()
                            }
                            .buttonStyle(.borderedProminent)

                            Text("Regenerating invalidates every iOS device until the new API key is copied into settings.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("API Key Authentication", systemImage: "key")
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

                Spacer()
            }
            .padding(24)
            .navigationTitle("Companion")
        }
        .task {
            controller.startServerIfNeeded()
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

@MainActor
@Observable
final class CompanionServerController {
    let server = CompanionServer()
    private(set) var authenticationToken: String
    var advertisedHost: String
    var apiPort: String
    var apiGatewayPort: String
    var dashboardPort: String
    var officePort: String

    init() {
        advertisedHost = server.currentConfiguration.host
        apiPort = String(server.currentConfiguration.port.rawValue)
        let servicePorts = CompanionServicePortsStore.load()
        apiGatewayPort = servicePorts.apiGatewayPort
        dashboardPort = servicePorts.dashboardPort
        officePort = servicePorts.officePort
        authenticationToken = CompanionAuthenticationTokenStore.shared.token

        // Start even if SwiftUI restores the app without immediately mounting the
        // root view's `.task`; the view task remains as an idempotent fallback.
        Task { @MainActor [weak self] in
            self?.startServerIfNeeded()
        }
    }

    var apiURL: String {
        "ws://\(server.currentConfiguration.host):\(server.currentConfiguration.port.rawValue)/ws"
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

    func copyAuthenticationToken() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(authenticationToken, forType: .string)
    }

    func regenerateToken() {
        authenticationToken = CompanionAuthenticationTokenStore.shared.regenerateToken()
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
        let trimmedHost = advertisedHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = trimmedHost.isEmpty ? CompanionServerConfiguration.default.host : trimmedHost
        let resolvedAPIPort = UInt16(apiPort) ?? CompanionServerConfiguration.default.port.rawValue
        let shouldRestart = server.state == .running

        advertisedHost = host
        apiPort = String(resolvedAPIPort)
        server.updateConfiguration(
            CompanionServerConfiguration(
                host: host,
                port: NWEndpoint.Port(rawValue: resolvedAPIPort) ?? CompanionServerConfiguration.default.port
            )
        )

        if shouldRestart {
            stopServer()
            startServer()
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
