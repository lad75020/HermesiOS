//
//  HermesHostCompanionApp.swift
//  HermesHostCompanion
//
//  Created by Codex on 05/05/2026.
//

import SwiftUI

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
                        statusRow("Last Error", controller.server.lastErrorMessage.isEmpty ? "None" : controller.server.lastErrorMessage)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    Label("Server Status", systemImage: "network")
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
                            ForEach(controller.activePairings.prefix(3)) { pairing in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(pairing.displayCode)
                                        .font(.headline.monospaced())
                                    Text("Pairing ID: \(pairing.id)")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                    Text("Secret: \(pairing.secret)")
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
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
        }
        .font(.subheadline)
    }
}

@MainActor
@Observable
final class CompanionServerController {
    let server = CompanionServer()
    private(set) var activePairings: [CompanionPairingSummary] = []

    func startServerIfNeeded() {
        guard server.state == .stopped else { return }
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

    private func refreshPairings() {
        activePairings = CompanionAuthenticationStore.shared.listActivePairings()
    }
}
