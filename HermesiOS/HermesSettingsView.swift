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
                TextField("Model", text: $responsesDraft.model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Toggle("Streaming enabled", isOn: $responsesDraft.stream)

                TextField("Instructions", text: $responsesDraft.instructions, axis: .vertical)
                    .lineLimit(4, reservesSpace: true)
                }

                Section("/v1/chat/completions") {
                TextField("Model", text: $chatDraft.model)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Toggle("Streaming enabled", isOn: $chatDraft.stream)

                TextField("System prompt", text: $chatDraft.systemPrompt, axis: .vertical)
                    .lineLimit(4, reservesSpace: true)
                }

                Section("Notes") {
                    Text("Responses and Chat screens are now limited to message exchange and output.")
                    Text("Use this screen for endpoint, auth, model, streaming, and prompt configuration.")
                    Text("Keep self-signed certificate support off unless you trust the Hermes API server.")
                    Text("For the host companion, copy the HTTP API URL and 4096-character token from the macOS app. No TLS certificate, QR code, or enrollment flow is required.")
                    Text("Set the Hermes workspace path to the host-side `.hermes` directory you want the Skills panel to manage.")
                }
                .foregroundStyle(.hermesSecondaryText)
            }
            .scrollContentBackground(.hidden)
        }
        .background(Color.hermesCanvas)
        .toolbar(.hidden, for: .navigationBar)
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
