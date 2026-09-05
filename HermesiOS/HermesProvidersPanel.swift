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

    @State private var keySearch = ""
    @State private var poolProvider = ""
    @State private var poolNewKey = ""
    @State private var poolNewLabel = ""
    @State private var newEnvKey = ""
    @State private var newEnvCustomKey = ""
    @State private var newEnvValue = ""
    @State private var providerEnvDrafts: [String: String] = [:]
    @State private var providerEnvKeyPendingRemoval: String?

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

    private var allProviderEnvFields: [HermesCompanionProviderEnvField] {
        var seen: Set<String> = []
        var fields: [HermesCompanionProviderEnvField] = []
        for field in companionRuntime.providerSections.flatMap({ $0.items }) {
            guard seen.insert(field.key).inserted else { continue }
            fields.append(field)
        }
        for key in companionRuntime.providerEnv.keys.sorted() where seen.insert(key).inserted && isProviderEnvKey(key) {
            fields.append(
                HermesCompanionProviderEnvField(
                    key: key,
                    label: humanizedEnvLabel(for: key),
                    type: key.hasSuffix("PROJECT_ID") ? "text" : "password",
                    hint: "Configured in .env."
                )
            )
        }
        return fields
    }

    private var configuredProviderEnvFields: [HermesCompanionProviderEnvField] {
        allProviderEnvFields
            .filter { (companionRuntime.providerEnv[$0.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            .filter { keySearch.isEmpty || $0.label.localizedCaseInsensitiveContains(keySearch) || $0.key.localizedCaseInsensitiveContains(keySearch) }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
    }

    private var availableProviderEnvFields: [HermesCompanionProviderEnvField] {
        allProviderEnvFields
            .filter { (companionRuntime.providerEnv[$0.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .filter { keySearch.isEmpty || $0.label.localizedCaseInsensitiveContains(keySearch) || $0.key.localizedCaseInsensitiveContains(keySearch) }
            .sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
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
                        .hermesGlassProminentButton()
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
                                            .hermesGlassButton()
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

                HermesSectionCard("Configured Providers") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Loaded from the configured keys currently present in `.env`. Edit values inline, add a new provider key, or remove a key from the host `.env` file.")
                            .font(.subheadline)
                            .foregroundStyle(.hermesSecondaryText)
                        companionSummaryRow(label: "Env File", value: companionRuntime.providerEnvFilePath.isEmpty ? "\(companionSettings.hermesWorkspacePath)/.env" : companionRuntime.providerEnvFilePath)

                        TextField("Search keys", text: $keySearch)
                            .hermesRuntimeInput()
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        if configuredProviderEnvFields.isEmpty {
                            ContentUnavailableView(
                                "No Configured Providers",
                                systemImage: "key.slash",
                                description: Text("Add a provider API key below to create it in `.env`.")
                            )
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(configuredProviderEnvFields) { field in
                                configuredProviderField(field)
                            }
                        }

                        Divider()
                            .overlay(Color.hermesSecondaryText.opacity(0.18))

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Add provider key")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.hermesSecondaryText)

                            Picker("Key", selection: $newEnvKey) {
                                Text("Choose a key").tag("")
                                ForEach(availableProviderEnvFields) { field in
                                    Text(field.label).tag(field.key)
                                }
                                Text("Custom env key…").tag("__custom__")
                            }
                            .pickerStyle(.menu)

                            if newEnvKey == "__custom__" {
                                TextField("CUSTOM_PROVIDER_API_KEY", text: $newEnvCustomKey)
                                    .hermesRuntimeInput(background: Color.igOnlineGreen.opacity(0.08), border: Color.igOnlineGreen.opacity(0.28))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                            }

                            SecureField("API key or token", text: $newEnvValue)
                                .hermesRuntimeInput(background: Color.igOnlineGreen.opacity(0.08), border: Color.igOnlineGreen.opacity(0.28))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                            Button("Add Provider") {
                                addProviderEnvKey()
                            }
                            .hermesGlassProminentButton()
                            .disabled(pendingNewEnvKey.isEmpty || newEnvValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }

                HermesSectionCard("Environment") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Edits the same provider and tool API keys as desktop Providers, writing to `.env` on the macOS host via the approved-device WebSocket companion.")
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
        .onDisappear {
            providerEnvDrafts.removeAll()
        }
        .alert(
            "Remove provider key?",
            isPresented: Binding(
                get: { providerEnvKeyPendingRemoval != nil },
                set: { if !$0 { providerEnvKeyPendingRemoval = nil } }
            ),
            presenting: providerEnvKeyPendingRemoval
        ) { key in
            Button("Remove", role: .destructive) {
                companionRuntime.removeProviderEnvValue(
                    key: key,
                    settings: companionSettings,
                    identityState: companionEnrollment.identityState
                )
                providerEnvDrafts[key] = nil
                providerEnvKeyPendingRemoval = nil
            }
            Button("Cancel", role: .cancel) {
                providerEnvKeyPendingRemoval = nil
            }
        } message: { key in
            Text("This removes \(key) from the host .env file.")
        }
    }

    private func isProviderEnvKey(_ key: String) -> Bool {
        key.range(of: #"^[A-Z][A-Z0-9_]*(API_KEY|TOKEN|KEY|PROJECT_ID)$"#, options: .regularExpression) != nil
    }

    private func humanizedEnvLabel(for key: String) -> String {
        key.split(separator: "_")
            .map { word in
                guard word.count > 2 else { return word.uppercased() }
                return word.prefix(1).uppercased() + word.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }

    @ViewBuilder
    private func configuredProviderField(_ field: HermesCompanionProviderEnvField) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(field.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.hermesSecondaryText)
                    Text(field.key)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.hermesSecondaryText.opacity(0.85))
                }
                Spacer()
                if isConfigured(field) {
                    Label("Configured", systemImage: "checkmark.circle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.igOnlineGreen)
                }
            }

            let binding = providerEnvDraftBinding(for: field.key)
            HStack(spacing: 8) {
                if field.type == "password" {
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
            }

            ViewThatFits(in: .horizontal) {
                HStack {
                    saveAndRemoveActions(for: field)
                }
                VStack(alignment: .leading) {
                    saveAndRemoveActions(for: field)
                }
            }
        }
        .padding(12)
        .background(Color.hermesSurfaceInput)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func providerField(_ field: HermesCompanionProviderEnvField) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(field.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.hermesSecondaryText)
                if isConfigured(field) {
                    Label("Configured", systemImage: "checkmark.circle.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.igOnlineGreen)
                }
            }

            let binding = providerEnvDraftBinding(for: field.key)
            HStack(spacing: 8) {
                if field.type == "password" {
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
            }

            Text(field.hint)
                .font(.caption)
                .foregroundStyle(.hermesSecondaryText)

            Button("Save \(field.label)") {
                saveProviderEnvField(field)
            }
            .hermesGlassButton()
            .disabled(providerEnvDraft(for: field.key).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(12)
        .background(Color.hermesSurfaceInput)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var pendingNewEnvKey: String {
        let key = newEnvKey == "__custom__" ? newEnvCustomKey : newEnvKey
        return key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func saveProviderEnvField(_ field: HermesCompanionProviderEnvField) {
        let value = providerEnvDraft(for: field.key).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        companionRuntime.setProviderEnvValue(
            key: field.key,
            value: value,
            settings: companionSettings,
            identityState: companionEnrollment.identityState
        )
        providerEnvDrafts[field.key] = nil
    }

    private func addProviderEnvKey() {
        let key = pendingNewEnvKey
        let value = newEnvValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !value.isEmpty else { return }
        companionRuntime.setProviderEnvValue(
            key: key,
            value: value,
            settings: companionSettings,
            identityState: companionEnrollment.identityState
        )
        newEnvKey = ""
        newEnvCustomKey = ""
        newEnvValue = ""
    }

    private func providerEnvDraft(for key: String) -> String {
        providerEnvDrafts[key] ?? ""
    }

    private func providerEnvDraftBinding(for key: String) -> Binding<String> {
        Binding(
            get: { providerEnvDraft(for: key) },
            set: { providerEnvDrafts[key] = $0 }
        )
    }

    private func isConfigured(_ field: HermesCompanionProviderEnvField) -> Bool {
        (companionRuntime.providerEnv[field.key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    @ViewBuilder
    private func saveAndRemoveActions(for field: HermesCompanionProviderEnvField) -> some View {
        Button("Save") { saveProviderEnvField(field) }
            .hermesGlassProminentButton()
            .disabled(providerEnvDraft(for: field.key).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        Button(role: .destructive) {
            providerEnvKeyPendingRemoval = field.key
        } label: {
            Label("Remove", systemImage: "trash")
        }
        .hermesGlassButton()
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
