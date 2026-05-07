//
//  HermesSettingsView.swift
//  HermesiOS
//

import Observation
import SwiftUI

struct HermesSettingsView: View {
    @Binding var apiSettings: HermesAPISettings
    @Binding var companionSettings: HermesCompanionSettings
    @Binding var responsesDraft: HermesRequestDraft
    @Binding var chatDraft: HermesChatDraft
    @Binding var appTheme: HermesAppTheme
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession
    @AppStorage("hermes.history.dashboardURL") private var dashboardURL = ""

    private let macServices: [HermesSettingsMacService] = [
        .init(id: "hermes-dashboard", title: "Hermes Dashboard", subtitle: "Host-rewriting dashboard proxy", icon: "rectangle.on.rectangle.angled"),
        .init(id: "claw3d-adapter", title: "Claw3D Adapter", subtitle: "Hermes Office / Claw3D bridge", icon: "cube.transparent"),
        .init(id: "openclaw-gateway", title: "OpenClaw Gateway", subtitle: "Claw3D gateway service", icon: "point.3.connected.trianglepath.dotted")
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

                    Text("Choose System to follow the device appearance, or force Hermes to Light or Dark mode.")
                        .font(.caption)
                        .foregroundStyle(.hermesSecondaryText)
                }

                Section("Dashboard") {
                    TextField("URL, e.g. https://hermes-mac.example.ts.net", text: $dashboardURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .hermesRuntimeInput()
                }

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
                            output: companionRuntime.macServiceOutputs[service.id] ?? "",
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

                HermesOfficeSettingsSection()

                Section("Gateway") {
                TextField("Base URL", text: $apiSettings.baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Bearer token", text: $apiSettings.apiKey)

                Toggle("Allow self-signed HTTPS certificates", isOn: $apiSettings.allowSelfSignedCertificates)

                settingsRow(label: "Responses URL", value: HermesAPISettings.responseURL(from: apiSettings.baseURL)?.absoluteString ?? "Invalid URL")
                settingsRow(label: "Chat URL", value: HermesAPISettings.chatCompletionsURL(from: apiSettings.baseURL)?.absoluteString ?? "Invalid URL")

                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        companionRuntime.restartAPIService(
                            settings: companionSettings,
                            identityState: companionEnrollment.identityState
                        )
                    } label: {
                        Label("Restart API Server", systemImage: "arrow.clockwise.circle")
                    }
                    .hermesGlassProminentButton()
                    .disabled(companionEnrollment.identityState.isEnrolled == false || companionRuntime.isBusy)

                    Text(companionEnrollment.identityState.isEnrolled ? "Uses the authenticated Host Companion to restart the host-side Hermes API server service." : "Authenticate Host Companion before restarting the API server from iOS.")
                        .font(.caption)
                        .foregroundStyle(.hermesSecondaryText)

                    if companionRuntime.connectionStatus != "Idle" {
                        settingsRow(label: "Restart Status", value: companionRuntime.connectionStatus)
                    }

                    if !companionRuntime.lastErrorMessage.isEmpty {
                        Text(companionRuntime.lastErrorMessage)
                            .font(.caption)
                            .foregroundStyle(.igDestructive)
                    }
                }
                .padding(.vertical, 4)
                }

                Section("Host Companion") {
                TextField("API URL", text: $companionSettings.apiURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                SecureField("4096-character token", text: $companionSettings.authenticationToken)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("Hermes workspace path", text: $companionSettings.hermesWorkspacePath)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                settingsRow(label: "Authentication Status", value: companionEnrollment.connectionStatus)

                if companionEnrollment.identityState.isEnrolled {
                    settingsRow(label: "Companion Endpoint", value: companionEnrollment.identityState.serverEndpoint)
                }

                if !companionEnrollment.lastErrorMessage.isEmpty {
                    Text(companionEnrollment.lastErrorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.igDestructive)
                }

                HStack {
                    Button(companionEnrollment.identityState.isEnrolled ? "Verify Token Again" : "Verify Token") {
                        companionEnrollment.enroll(settings: companionSettings)
                    }
                    .hermesGlassProminentButton()
                    .disabled(
                        companionEnrollment.isEnrolling ||
                        companionSettings.apiURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                        companionSettings.authenticationToken.trimmingCharacters(in: .whitespacesAndNewlines).count != 4096
                    )

                    if companionEnrollment.identityState.isEnrolled {
                        Button("Clear Authentication", role: .destructive) {
                            companionEnrollment.clearIdentity()
                        }
                        .hermesGlassButton()
                    }
                }
                }


                Section("/v1/responses") {
                Toggle("Streaming enabled", isOn: $responsesDraft.stream)

                TextField("Instructions", text: $responsesDraft.instructions, axis: .vertical)
                    .lineLimit(4, reservesSpace: true)
                }

                Section("/v1/chat/completions") {
                Toggle("Streaming enabled", isOn: $chatDraft.stream)

                TextField("System prompt", text: $chatDraft.systemPrompt, axis: .vertical)
                    .lineLimit(4, reservesSpace: true)
                }

            }
            .scrollContentBackground(.hidden)
        }
        .background(Color.hermesCanvas)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: companionEnrollment.identityState.deviceID) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            companionRuntime.refreshMacServices(
                macServices.map(\.id),
                settings: companionSettings,
                identityState: companionEnrollment.identityState
            )
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

private struct HermesSettingsMacService: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
}

private struct HermesSettingsMacServiceRow: View {
    let service: HermesSettingsMacService
    let status: HermesCompanionManagedServiceStatus?
    let output: String
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

            let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedOutput.isEmpty {
                Text(trimmedOutput)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.hermesSecondaryText)
                    .lineLimit(3)
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
