//
//  HermesHostCompanionApp.swift
//  HermesHostCompanion
//
//  Created by Codex on 05/05/2026.
//

import SwiftUI
import Network
import CoreImage
import CoreImage.CIFilterBuiltins
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
                    Text("Minimal V1 companion daemon shell for mTLS WebSocket access, allowlisted filesystem operations, validation, backups, and service restarts.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        statusRow("State", controller.server.state.displayName)
                        statusRow("Endpoint", controller.server.listenerDescription)
                        statusRow("Enrollment", controller.server.enrollmentListenerDescription)
                        statusRow("Server Fingerprint", controller.serverFingerprint.isEmpty ? "Bootstraps on launch" : controller.serverFingerprint)
                        statusRow("Last Error", controller.server.lastErrorMessage.isEmpty ? "None" : controller.server.lastErrorMessage)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Server Status", systemImage: "network")
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Use your Tailscale hostname or stable IP here so enrollment and API endpoints target the right machine from elsewhere on the same Tailnet.")
                            .foregroundStyle(.secondary)

                        TextField("Advertised host or IP", text: $controller.advertisedHost)
                            .autocorrectionDisabled()

                        HStack {
                            TextField("API port", text: $controller.apiPort)
                            TextField("Enrollment port", text: $controller.enrollmentPort)
                        }

                        HStack {
                            Button("Apply Network Target") {
                                controller.applyNetworkConfiguration()
                            }
                            .buttonStyle(.borderedProminent)

                            Text("The listener binds to local loopback; this advertised value controls the endpoints shown to iOS clients and may be served through Tailscale.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(controller.server.state == .running ? "Applying host or port changes will restart the running companion server automatically." : "Apply the network target before creating pairings for remote devices.")
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
                        Text("The companion bootstraps a local CA and server identity on first launch, exposes an authenticated API listener on port 9443, and a dedicated enrollment listener on port 9444 for CSR signing with a one-time pairing code.")
                            .foregroundStyle(.secondary)

                        HStack {
                            Button("Create Pairing") {
                                controller.createPairing()
                            }
                            .buttonStyle(.borderedProminent)

                            if controller.activePairings.isEmpty == false {
                                Text("\(controller.activePairings.count) active")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if controller.activePairings.isEmpty {
                            Text("No active pairings")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            if let qrImage = controller.pairingQRCodeImage {
                                VStack(alignment: .leading, spacing: 8) {
                                    Image(nsImage: qrImage)
                                        .interpolation(.none)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 180, height: 180)
                                        .padding(12)
                                        .background(Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    Text("Scan this QR code from the iOS app to populate enrollment URL, API URL, fingerprint, pairing ID, and secret. If scanning is flaky, copy the fields below into the iOS enrollment form.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            ForEach(controller.activePairings.prefix(3)) { pairing in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(pairing.displayCode)
                                        .font(.headline.monospaced())
                                        .textSelection(.enabled)
                                    Text("Pairing ID: \(pairing.id)")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                    Text("Secret: \(pairing.secret)")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                    Text("Expires \(pairing.expiresAt.formatted(date: .omitted, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Enrollment", systemImage: "person.badge.key")
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
    private(set) var activePairings: [CompanionPairingSummary] = []
    private(set) var serverFingerprint = ""
    private let qrContext = CIContext()
    var advertisedHost: String
    var apiPort: String
    var enrollmentPort: String

    init() {
        advertisedHost = server.currentConfiguration.host
        apiPort = String(server.currentConfiguration.port.rawValue)
        enrollmentPort = String(server.currentConfiguration.enrollmentPort.rawValue)

        // Start even if SwiftUI restores the app without immediately mounting the
        // root view's `.task`; the view task remains as an idempotent fallback.
        Task { @MainActor [weak self] in
            self?.startServerIfNeeded()
        }
    }

    var pairingQRCodeImage: NSImage? {
        guard let pairing = activePairings.first else { return nil }
        let payload = CompanionPairingQRCodePayload(
            version: 1,
            enrollmentURL: "wss://\(server.currentConfiguration.host):\(server.currentConfiguration.enrollmentPort.rawValue)/enroll",
            apiURL: "wss://\(server.currentConfiguration.host):\(server.currentConfiguration.port.rawValue)/ws",
            serverFingerprint: serverFingerprint,
            pairingID: pairing.id,
            pairingSecret: pairing.secret
        )
        guard
            let data = try? JSONEncoder().encode(payload),
            let qrFilter = CIFilter(name: "CIQRCodeGenerator")
        else {
            return nil
        }

        qrFilter.setValue(data, forKey: "inputMessage")
        qrFilter.setValue("M", forKey: "inputCorrectionLevel")
        guard
            let outputImage = qrFilter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
            let cgImage = qrContext.createCGImage(outputImage, from: outputImage.extent)
        else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: 180, height: 180))
    }

    func startServerIfNeeded() {
        guard server.state == .stopped else { return }
        applyNetworkConfiguration()
        refreshFingerprint()
        refreshPairings()
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

    func createPairing() {
        do {
            _ = try CompanionAuthenticationStore.shared.createPairing()
            refreshPairings()
        } catch {
            server.lastErrorMessage = error.localizedDescription
        }
    }

    func applyNetworkConfiguration() {
        let trimmedHost = advertisedHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = trimmedHost.isEmpty ? CompanionServerConfiguration.default.host : trimmedHost
        let resolvedAPIPort = UInt16(apiPort) ?? CompanionServerConfiguration.default.port.rawValue
        let resolvedEnrollmentPort = UInt16(enrollmentPort) ?? CompanionServerConfiguration.default.enrollmentPort.rawValue
        let shouldRestart = server.state == .running

        advertisedHost = host
        apiPort = String(resolvedAPIPort)
        enrollmentPort = String(resolvedEnrollmentPort)
        server.updateConfiguration(
            CompanionServerConfiguration(
                host: host,
                port: NWEndpoint.Port(rawValue: resolvedAPIPort) ?? CompanionServerConfiguration.default.port,
                enrollmentPort: NWEndpoint.Port(rawValue: resolvedEnrollmentPort) ?? CompanionServerConfiguration.default.enrollmentPort
            )
        )
        refreshFingerprint()

        if shouldRestart {
            stopServer()
            startServer()
        }
    }

    private func refreshPairings() {
        activePairings = CompanionAuthenticationStore.shared.listActivePairings()
    }

    private func refreshFingerprint() {
        serverFingerprint = (try? CompanionTLSIdentityStore.shared.loadServerIdentity(host: server.currentConfiguration.host).serverCertificateFingerprint) ?? ""
    }
}

private struct CompanionPairingQRCodePayload: Codable {
    let version: Int
    let enrollmentURL: String
    let apiURL: String
    let serverFingerprint: String
    let pairingID: String
    let pairingSecret: String
}
