//
//  HermesModelsPanel.swift
//  HermesiOS
//

import Observation
import SwiftUI
import UniformTypeIdentifiers

struct HermesModelsPanel: View {
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession

    private var providerOptions: [HermesCompanionProviderOption] {
        if companionRuntime.providerOptions.isEmpty {
            return [
                .init(value: "auto", label: "Auto-detect"),
                .init(value: "main", label: "Main model"),
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
        var options = companionRuntime.providerOptions
        if options.contains(where: { $0.value == "main" }) == false {
            options.insert(.init(value: "main", label: "Main model"), at: min(1, options.count))
        }
        return options
    }

    private var configPath: String {
        companionRuntime.providerConfigPath.isEmpty ? "\(companionSettings.hermesWorkspacePath)/config.yaml" : companionRuntime.providerConfigPath
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if companionEnrollment.identityState.isEnrolled == false {
                ContentUnavailableView(
                    "Authentication Required",
                    systemImage: "person.badge.key",
                    description: Text("Use Settings → Host Companion to verify the API key before editing Hermes runtime models.")
                )
            } else {
                HermesSectionCard("Runtime Model Routing") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Configure the provider and model that Hermes Agent uses for the main conversation, delegated sub-agents, and auxiliary runtime tasks. Changes are written to the live `config.yaml` on the macOS host.")
                            .font(.subheadline)
                            .foregroundStyle(.hermesSecondaryText)

                        companionSummaryRow(label: "Workspace", value: companionRuntime.resolvedHermesWorkspacePath.isEmpty ? companionSettings.hermesWorkspacePath : companionRuntime.resolvedHermesWorkspacePath)
                        companionSummaryRow(label: "Config", value: configPath)

                        if !companionRuntime.lastErrorMessage.isEmpty {
                            Text(companionRuntime.lastErrorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.igDestructive)
                        }

                        HermesRuntimeModelSlotEditorCard(
                            title: "Main Model",
                            subtitle: "Primary model for interactive Hermes Agent turns (`model.provider` and `model.default`).",
                            systemImage: "sparkles",
                            provider: companionRuntime.providerModelConfig.provider,
                            model: companionRuntime.providerModelConfig.model,
                            providerOptions: providerOptions.filter { $0.value != "main" },
                            onSave: { provider, model in
                                companionRuntime.saveProviderModelConfig(
                                    provider: provider,
                                    model: model,
                                    baseUrl: companionRuntime.providerModelConfig.baseUrl,
                                    settings: companionSettings,
                                    identityState: companionEnrollment.identityState
                                )
                            }
                        )

                        HermesRuntimeModelSlotEditorCard(
                            title: "Delegation Model",
                            subtitle: "Model used when Hermes spawns delegated sub-agents (`delegation.provider` and `delegation.model`). Leave blank to inherit defaults.",
                            systemImage: "person.2.wave.2",
                            provider: companionRuntime.delegationModelConfig.provider,
                            model: companionRuntime.delegationModelConfig.model,
                            providerOptions: providerOptions,
                            allowEmptyProvider: true,
                            onSave: { provider, model in
                                companionRuntime.saveRuntimeModelSlotConfig(
                                    slot: companionRuntime.delegationModelConfig,
                                    provider: provider,
                                    model: model,
                                    settings: companionSettings,
                                    identityState: companionEnrollment.identityState
                                )
                            }
                        )
                    }
                }

                HermesSectionCard("Auxiliary Models") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Each auxiliary slot can use its own provider and model. Use `auto` for Hermes automatic routing, `main` to explicitly inherit the main model, or leave the model empty to use that provider's default auxiliary model.")
                            .font(.subheadline)
                            .foregroundStyle(.hermesSecondaryText)

                        ForEach(companionRuntime.auxiliaryModelConfigs) { slot in
                            HermesRuntimeModelSlotEditorCard(
                                title: slot.label,
                                subtitle: "Writes `auxiliary.\(slot.key).provider` and `auxiliary.\(slot.key).model`.",
                                systemImage: auxiliaryIcon(for: slot.key),
                                provider: slot.provider,
                                model: slot.model,
                                providerOptions: providerOptions,
                                allowEmptyProvider: true,
                                onSave: { provider, model in
                                    companionRuntime.saveRuntimeModelSlotConfig(
                                        slot: slot,
                                        provider: provider,
                                        model: model,
                                        settings: companionSettings,
                                        identityState: companionEnrollment.identityState
                                    )
                                }
                            )
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

    private func auxiliaryIcon(for key: String) -> String {
        switch key {
        case "vision": "eye"
        case "web_extract": "doc.text.magnifyingglass"
        case "compression": "arrow.down.forward.and.arrow.up.backward"
        case "title_generation": "textformat"
        case "mcp": "point.3.connected.trianglepath.dotted"
        case "curator": "wand.and.stars"
        case "skills_hub": "square.stack.3d.up.fill"
        case "approval": "checkmark.shield"
        case "session_search": "magnifyingglass.circle"
        default: "cpu"
        }
    }
}

struct HermesRuntimeModelSlotEditorCard: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let provider: String
    let model: String
    let providerOptions: [HermesCompanionProviderOption]
    let allowEmptyProvider: Bool
    let onSave: (String, String) -> Void

    @State private var draftProvider: String
    @State private var draftModel: String
    @State private var saved = false

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        provider: String,
        model: String,
        providerOptions: [HermesCompanionProviderOption],
        allowEmptyProvider: Bool = false,
        onSave: @escaping (String, String) -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.provider = provider
        self.model = model
        self.providerOptions = providerOptions
        self.allowEmptyProvider = allowEmptyProvider
        self.onSave = onSave
        _draftProvider = State(initialValue: provider.isEmpty && allowEmptyProvider == false ? "auto" : provider)
        _draftModel = State(initialValue: model)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.igActionBlue)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.hermesSecondaryText)
                }
                Spacer()
                if saved {
                    Label("Saved", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.igOnlineGreen)
                }
            }

            Picker("Provider", selection: $draftProvider) {
                if allowEmptyProvider {
                    Text("Unset / inherit default").tag("")
                }
                ForEach(providerOptions) { option in
                    Text(option.label).tag(option.value)
                }
                if providerOptions.contains(where: { $0.value == provider }) == false && provider.isEmpty == false {
                    Text(provider).tag(provider)
                }
            }
            .pickerStyle(.menu)

            TextField("Model, e.g. anthropic/claude-sonnet-4", text: $draftModel)
                .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            HStack(spacing: 10) {
                Button("Save") {
                    onSave(
                        draftProvider.trimmingCharacters(in: .whitespacesAndNewlines),
                        draftModel.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    saved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
                }
                .hermesGlassProminentButton()

                Button("Reset Draft") {
                    draftProvider = provider.isEmpty && allowEmptyProvider == false ? "auto" : provider
                    draftModel = model
                }
                .hermesGlassButton()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hermesSurfaceInput)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onChange(of: provider) { _, newValue in
            draftProvider = newValue.isEmpty && allowEmptyProvider == false ? "auto" : newValue
        }
        .onChange(of: model) { _, newValue in
            draftModel = newValue
        }
    }
}
