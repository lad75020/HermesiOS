//
//  HermesProvidersPanel.swift
//  HermesiOS
//

import Observation
import SwiftUI
import UniformTypeIdentifiers

struct HermesProvidersPanel: View {
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession

    @State private var modelProvider = "auto"
    @State private var modelName = ""
    @State private var modelBaseURL = ""
    @State private var savedEnvKey: String?
    @State private var modelSaved = false
    @State private var visibleKeys: Set<String> = []
    @State private var poolProvider = ""
    @State private var poolNewKey = ""
    @State private var poolNewLabel = ""

    private var providerOptions: [HermesCompanionProviderOption] {
        if companionRuntime.providerOptions.isEmpty {
            return [
                .init(value: "auto", label: "Auto-detect"),
                .init(value: "openrouter", label: "OpenRouter"),
                .init(value: "anthropic", label: "Anthropic"),
                .init(value: "openai", label: "OpenAI"),
                .init(value: "google", label: "Google"),
                .init(value: "xai", label: "xAI"),
                .init(value: "nous", label: "Nous"),
                .init(value: "qwen", label: "Qwen"),
                .init(value: "minimax", label: "MiniMax"),
                .init(value: "custom", label: "Local / Custom")
            ]
        }
        return companionRuntime.providerOptions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if companionEnrollment.identityState.isEnrolled == false {
                ContentUnavailableView(
                    "Authentication Required",
                    systemImage: "person.badge.key",
                    description: Text("Use Settings → Host Companion to authenticate this iOS device before editing Hermes provider keys, default model configuration, or credential pools on the macOS host.")
                )
            } else {
                HermesSectionCard("Provider Model") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Mirrors the desktop Providers screen: edits `provider`, `default`, and `base_url` in the live Hermes `config.yaml`, enables streaming, and saves the model to the workspace inventory.")
                            .font(.subheadline)
                            .foregroundStyle(.hermesSecondaryText)

                        companionSummaryRow(label: "Workspace", value: companionRuntime.resolvedHermesWorkspacePath.isEmpty ? companionSettings.hermesWorkspacePath : companionRuntime.resolvedHermesWorkspacePath)
                        companionSummaryRow(label: "Config", value: companionRuntime.providerConfigPath.isEmpty ? "\(companionSettings.hermesWorkspacePath)/config.yaml" : companionRuntime.providerConfigPath)

                        if modelSaved {
                            Label("Saved", systemImage: "checkmark.circle.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.igOnlineGreen)
                        }

                        Picker("Provider", selection: $modelProvider) {
                            ForEach(providerOptions) { option in
                                Text(option.label).tag(option.value)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: modelProvider) { _, newValue in
                            if newValue == "custom" && modelBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                modelBaseURL = "http://localhost:1234/v1"
                            }
                        }

                        Text(modelProvider == "custom" ? "Use a local or OpenAI-compatible custom provider endpoint." : "Choose which provider Hermes should use by default, or keep auto-detect.")
                            .font(.caption)
                            .foregroundStyle(.hermesSecondaryText)

                        TextField("Model name, e.g. anthropic/claude-sonnet-4", text: $modelName)
                            .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        if modelProvider == "custom" {
                            TextField("Base URL, e.g. http://localhost:1234/v1", text: $modelBaseURL)
                                .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }

                        Button("Save Model Configuration") {
                            companionRuntime.saveProviderModelConfig(
                                provider: modelProvider.trimmingCharacters(in: .whitespacesAndNewlines),
                                model: modelName.trimmingCharacters(in: .whitespacesAndNewlines),
                                baseUrl: modelBaseURL.trimmingCharacters(in: .whitespacesAndNewlines),
                                settings: companionSettings,
                                identityState: companionEnrollment.identityState
                            )
                            modelSaved = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { modelSaved = false }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                HermesSectionCard("Credential Pool") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Stores multiple API keys per provider in `auth.json`, matching the desktop credential pool.")
                            .font(.subheadline)
                            .foregroundStyle(.hermesSecondaryText)
                        companionSummaryRow(label: "Auth Store", value: companionRuntime.providerAuthFilePath.isEmpty ? "\(companionSettings.hermesWorkspacePath)/auth.json" : companionRuntime.providerAuthFilePath)

                        Picker("Provider", selection: $poolProvider) {
                            Text("Provider").tag("")
                            ForEach(providerOptions.filter { $0.value != "auto" }) { option in
                                Text(option.label).tag(option.value)
                            }
                        }
                        .pickerStyle(.menu)

                        SecureField("API key", text: $poolNewKey)
                            .hermesRuntimeInput(background: Color.igOnlineGreen.opacity(0.08), border: Color.igOnlineGreen.opacity(0.28))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("Label (optional)", text: $poolNewLabel)
                            .hermesRuntimeInput(background: Color.igOnlineGreen.opacity(0.08), border: Color.igOnlineGreen.opacity(0.28))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        Button("Add Pool Key") {
                            addPoolKey()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(poolProvider.isEmpty || poolNewKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        ForEach(companionRuntime.providerCredentialPool.keys.sorted(), id: \.self) { provider in
                            if let entries = companionRuntime.providerCredentialPool[provider], entries.isEmpty == false {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(label(for: provider))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.hermesSecondaryText)
                                    ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                                        HStack(alignment: .center, spacing: 10) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(entry.label.isEmpty ? "Key \(index + 1)" : entry.label)
                                                    .font(.subheadline.weight(.semibold))
                                                Text(masked(entry.key))
                                                    .font(.caption.monospaced())
                                                    .foregroundStyle(.hermesSecondaryText)
                                            }
                                            Spacer()
                                            Button(role: .destructive) {
                                                removePoolKey(provider: provider, index: index)
                                            } label: {
                                                Image(systemName: "trash")
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                        .padding(12)
                                        .background(Color.hermesSurfaceInput)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    }
                                }
                            }
                        }
                    }
                }

                HermesSectionCard("Environment") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Edits the same provider and tool API keys as desktop Providers, writing to `.env` on the macOS host via the token-authenticated WebSocket companion.")
                            .font(.subheadline)
                            .foregroundStyle(.hermesSecondaryText)
                        companionSummaryRow(label: "Env File", value: companionRuntime.providerEnvFilePath.isEmpty ? "\(companionSettings.hermesWorkspacePath)/.env" : companionRuntime.providerEnvFilePath)

                        if !companionRuntime.lastErrorMessage.isEmpty {
                            Text(companionRuntime.lastErrorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.igDestructive)
                        }

                        ForEach(companionRuntime.providerSections) { section in
                            DisclosureGroup(section.title) {
                                VStack(alignment: .leading, spacing: 12) {
                                    ForEach(section.items) { field in
                                        providerField(field)
                                    }
                                }
                                .padding(.top, 10)
                            }
                            .font(.subheadline.weight(.semibold))
                            .tint(.igActionBlue)
                            .padding(12)
                            .background(Color.hermesSurfaceInput)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                }
            }
        }
        .task(id: companionEnrollment.identityState.deviceID) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            companionRuntime.refreshProvidersConfig(settings: companionSettings, identityState: companionEnrollment.identityState)
        }
        .task(id: companionSettings.hermesWorkspacePath) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            companionRuntime.refreshProvidersConfig(settings: companionSettings, identityState: companionEnrollment.identityState)
        }
        .onChange(of: companionRuntime.providerModelConfig) { _, newValue in
            syncModelState(newValue)
        }
        .onAppear {
            syncModelState(companionRuntime.providerModelConfig)
        }
    }

    @ViewBuilder
    private func providerField(_ field: HermesCompanionProviderEnvField) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(field.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.hermesSecondaryText)
                if savedEnvKey == field.key {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.igOnlineGreen)
                }
            }

            HStack(spacing: 8) {
                let binding = Binding<String>(
                    get: { companionRuntime.providerEnv[field.key] ?? "" },
                    set: { companionRuntime.providerEnv[field.key] = $0 }
                )
                if field.type == "password" && visibleKeys.contains(field.key) == false {
                    SecureField(field.label, text: binding)
                        .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    TextField(field.label, text: binding)
                        .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                if field.type == "password" {
                    Button(visibleKeys.contains(field.key) ? "Hide" : "Show") {
                        if visibleKeys.contains(field.key) { visibleKeys.remove(field.key) } else { visibleKeys.insert(field.key) }
                    }
                    .buttonStyle(.bordered)
                }
            }

            Text(field.hint)
                .font(.caption)
                .foregroundStyle(.hermesSecondaryText)

            Button("Save \(field.label)") {
                companionRuntime.setProviderEnvValue(
                    key: field.key,
                    value: companionRuntime.providerEnv[field.key] ?? "",
                    settings: companionSettings,
                    identityState: companionEnrollment.identityState
                )
                savedEnvKey = field.key
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { savedEnvKey = nil }
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(Color.hermesSurfaceInput)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func syncModelState(_ config: HermesCompanionProviderModelConfig) {
        modelProvider = config.provider
        modelName = config.model
        modelBaseURL = config.baseUrl
    }

    private func addPoolKey() {
        let provider = poolProvider.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = poolNewKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !provider.isEmpty, !key.isEmpty else { return }
        let existing = companionRuntime.providerCredentialPool[provider] ?? []
        let label = poolNewLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Key \(existing.count + 1)" : poolNewLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        companionRuntime.setProviderCredentialPool(
            provider: provider,
            entries: existing + [HermesCompanionProviderCredentialEntry(key: key, label: label)],
            settings: companionSettings,
            identityState: companionEnrollment.identityState
        )
        poolNewKey = ""
        poolNewLabel = ""
    }

    private func removePoolKey(provider: String, index: Int) {
        var entries = companionRuntime.providerCredentialPool[provider] ?? []
        guard entries.indices.contains(index) else { return }
        entries.remove(at: index)
        companionRuntime.setProviderCredentialPool(
            provider: provider,
            entries: entries,
            settings: companionSettings,
            identityState: companionEnrollment.identityState
        )
    }

    private func label(for provider: String) -> String {
        providerOptions.first(where: { $0.value == provider })?.label ?? provider
    }

    private func masked(_ value: String) -> String {
        guard value.count > 12 else { return value.isEmpty ? "Empty" : "••••" }
        return "\(value.prefix(8))…\(value.suffix(4))"
    }

    private func companionSummaryRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .fontWeight(.semibold)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.hermesSecondaryText)
                .textSelection(.enabled)
        }
        .font(.subheadline)
    }
}
