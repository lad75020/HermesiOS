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

    init() {
        advertisedHost = server.currentConfiguration.host
        apiPort = String(server.currentConfiguration.port.rawValue)
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
