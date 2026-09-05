//
//  HermesGatewayPanel.swift
//  HermesiOS
//

import Observation
import SwiftUI

struct HermesGatewayPanel: View {
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession

    @State private var expandedPlatforms: Set<String> = []
    @State private var gatewayEnvDrafts: [String: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if companionEnrollment.identityState.isEnrolled == false {
                ContentUnavailableView(
                    "Host Companion Required",
                    systemImage: "lock.laptopcomputer",
                    description: Text("Authenticate the macOS companion before editing messaging credentials.")
                )
            } else {
                HermesSectionCard("Platforms") {
                    VStack(alignment: .leading, spacing: 12) {
                        if companionRuntime.gatewayPlatforms.isEmpty {
                            ContentUnavailableView(
                                "Messaging Settings Not Loaded",
                                systemImage: "antenna.radiowaves.left.and.right.slash",
                                description: Text("Messaging platform definitions could not be loaded from the Host Companion.")
                            )
                        } else {
                            ForEach(companionRuntime.gatewayPlatforms) { platform in
                                GatewayPlatformCard(
                                    platform: platform,
                                    fields: fields(for: platform),
                                    isConfigured: { key in
                                        (companionRuntime.gatewayEnv[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                                    },
                                    isEnabled: companionRuntime.gatewayPlatformEnabled[platform.key] ?? false,
                                    isExpanded: expandedPlatforms.contains(platform.key),
                                    isBusy: companionRuntime.isBusy,
                                    onToggleEnabled: { enabled in
                                        companionRuntime.setGatewayPlatformEnabled(platform: platform.key, enabled: enabled, settings: companionSettings, identityState: companionEnrollment.identityState)
                                        if enabled { expandedPlatforms.insert(platform.key) }
                                    },
                                    onToggleExpanded: {
                                        if expandedPlatforms.contains(platform.key) {
                                            expandedPlatforms.remove(platform.key)
                                        } else {
                                            expandedPlatforms.insert(platform.key)
                                        }
                                    },
                                    draft: { key in
                                        gatewayEnvDraftBinding(for: key)
                                    },
                                    onSave: { key in
                                        saveGatewayEnvDraft(for: key)
                                    }
                                )
                            }
                        }
                    }
                }

                let otherFields = companionRuntime.gatewayFields.filter { field in
                    platformFieldKeys.contains(field.key) == false
                }
                if otherFields.isEmpty == false {
                    HermesSectionCard("Other Settings") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(otherFields) { field in
                                GatewayEnvFieldRow(
                                    field: field,
                                    value: gatewayEnvDraftBinding(for: field.key),
                                    isConfigured: isGatewayEnvConfigured(field.key),
                                    onSave: {
                                        saveGatewayEnvDraft(for: field.key)
                                    }
                                )
                            }
                        }
                    }
                }

            }
        }
        .task(id: companionEnrollment.identityState.deviceID) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            companionRuntime.refreshGatewayConfig(settings: companionSettings, identityState: companionEnrollment.identityState)
        }
        .task(id: companionRuntime.activeProfileName) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            companionRuntime.refreshGatewayConfig(settings: companionSettings, identityState: companionEnrollment.identityState)
        }
        .onDisappear {
            gatewayEnvDrafts.removeAll()
        }
    }

    private var platformFieldKeys: Set<String> {
        Set(companionRuntime.gatewayPlatforms.flatMap(\.fields))
    }

    private func fields(for platform: HermesCompanionGatewayPlatformDefinition) -> [HermesCompanionGatewayEnvFieldDefinition] {
        platform.fields.compactMap { key in companionRuntime.gatewayFields.first(where: { $0.key == key }) }
    }

    private func gatewayEnvDraftBinding(for key: String) -> Binding<String> {
        Binding(get: { gatewayEnvDrafts[key] ?? "" }, set: { gatewayEnvDrafts[key] = $0 })
    }

    private func isGatewayEnvConfigured(_ key: String) -> Bool {
        (companionRuntime.gatewayEnv[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private func saveGatewayEnvDraft(for key: String) {
        let value = (gatewayEnvDrafts[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        companionRuntime.setGatewayEnvValue(key: key, value: value, settings: companionSettings, identityState: companionEnrollment.identityState)
        gatewayEnvDrafts[key] = nil
    }
}

private struct GatewayPlatformCard: View {
    let platform: HermesCompanionGatewayPlatformDefinition
    let fields: [HermesCompanionGatewayEnvFieldDefinition]
    let isConfigured: (String) -> Bool
    let isEnabled: Bool
    let isExpanded: Bool
    let isBusy: Bool
    let onToggleEnabled: (Bool) -> Void
    let onToggleExpanded: () -> Void
    let draft: (String) -> Binding<String>
    let onSave: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Button(action: onToggleExpanded) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.hermesSecondaryText)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(platform.label)
                        .font(.headline)
                    Text(platform.description)
                        .font(.caption)
                        .foregroundStyle(.hermesSecondaryText)
                }
                Spacer()
                Toggle("", isOn: Binding(get: { isEnabled }, set: onToggleEnabled))
                    .labelsHidden()
                    .disabled(isBusy)
            }

            if isEnabled && isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(fields) { field in
                        GatewayEnvFieldRow(
                            field: field,
                            value: draft(field.key),
                            isConfigured: isConfigured(field.key),
                            onSave: { onSave(field.key) }
                        )
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .hermesLiquidGlass(cornerRadius: 18, tint: isEnabled ? Color.igActionBlue.opacity(0.08) : .white.opacity(0.04), interactive: true)
    }
}

private struct GatewayEnvFieldRow: View {
    let field: HermesCompanionGatewayEnvFieldDefinition
    @Binding var value: String
    let isConfigured: Bool
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(field.label)
                    .font(.subheadline.weight(.semibold))
                Text(field.key)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.hermesSecondaryText)
                if isConfigured {
                    Text("Configured")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.green)
                }
                Spacer()
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    inputAndSaveAction
                }
                VStack(alignment: .leading, spacing: 8) {
                    inputAndSaveAction
                }
            }

            Text(field.hint)
                .font(.caption)
                .foregroundStyle(.hermesSecondaryText)
        }
    }

    @ViewBuilder
    private var inputAndSaveAction: some View {
        if field.isSecret {
                    SecureField(field.label, text: $value)
                        .hermesRuntimeInput()
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
        } else {
                    TextField(field.label, text: $value)
                        .hermesRuntimeInput()
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
        }
        Button("Save", action: onSave)
            .hermesGlassProminentButton()
            .disabled(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
}
