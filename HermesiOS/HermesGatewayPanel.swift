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

    @State private var savedKey: String?
    @State private var visibleKeys: Set<String> = []
    @State private var expandedPlatforms: Set<String> = []

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
                                    env: companionRuntime.gatewayEnv,
                                    isEnabled: companionRuntime.gatewayPlatformEnabled[platform.key] ?? false,
                                    isExpanded: expandedPlatforms.contains(platform.key),
                                    visibleKeys: visibleKeys,
                                    savedKey: savedKey,
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
                                    onToggleVisibility: { key in
                                        if visibleKeys.contains(key) { visibleKeys.remove(key) } else { visibleKeys.insert(key) }
                                    },
                                    onChange: { key, value in
                                        companionRuntime.gatewayEnv[key] = value
                                    },
                                    onSave: { key in
                                        companionRuntime.setGatewayEnvValue(key: key, value: companionRuntime.gatewayEnv[key] ?? "", settings: companionSettings, identityState: companionEnrollment.identityState)
                                        savedKey = key
                                        Task { @MainActor in
                                            try? await Task.sleep(for: .seconds(2))
                                            if savedKey == key { savedKey = nil }
                                        }
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
                                    value: Binding(
                                        get: { companionRuntime.gatewayEnv[field.key] ?? "" },
                                        set: { companionRuntime.gatewayEnv[field.key] = $0 }
                                    ),
                                    isVisible: visibleKeys.contains(field.key),
                                    isSaved: savedKey == field.key,
                                    onToggleVisibility: {
                                        if visibleKeys.contains(field.key) { visibleKeys.remove(field.key) } else { visibleKeys.insert(field.key) }
                                    },
                                    onSave: {
                                        companionRuntime.setGatewayEnvValue(key: field.key, value: companionRuntime.gatewayEnv[field.key] ?? "", settings: companionSettings, identityState: companionEnrollment.identityState)
                                        savedKey = field.key
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
    }

    private var platformFieldKeys: Set<String> {
        Set(companionRuntime.gatewayPlatforms.flatMap(\.fields))
    }

    private func fields(for platform: HermesCompanionGatewayPlatformDefinition) -> [HermesCompanionGatewayEnvFieldDefinition] {
        platform.fields.compactMap { key in companionRuntime.gatewayFields.first(where: { $0.key == key }) }
    }
}

private struct GatewayPlatformCard: View {
    let platform: HermesCompanionGatewayPlatformDefinition
    let fields: [HermesCompanionGatewayEnvFieldDefinition]
    let env: [String: String]
    let isEnabled: Bool
    let isExpanded: Bool
    let visibleKeys: Set<String>
    let savedKey: String?
    let isBusy: Bool
    let onToggleEnabled: (Bool) -> Void
    let onToggleExpanded: () -> Void
    let onToggleVisibility: (String) -> Void
    let onChange: (String, String) -> Void
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
                            value: Binding(get: { env[field.key] ?? "" }, set: { onChange(field.key, $0) }),
                            isVisible: visibleKeys.contains(field.key),
                            isSaved: savedKey == field.key,
                            onToggleVisibility: { onToggleVisibility(field.key) },
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
    let isVisible: Bool
    let isSaved: Bool
    let onToggleVisibility: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                Text(field.label)
                    .font(.subheadline.weight(.semibold))
                Text(field.key)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.hermesSecondaryText)
                if isSaved {
                    Text("Saved")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.green)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                if field.isSecret && !isVisible {
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

                if field.isSecret {
                    Button(isVisible ? "Hide" : "Show", action: onToggleVisibility)
                        .hermesGlassButton()
                }

                Button("Save", action: onSave)
                    .hermesGlassProminentButton()
            }

            Text(field.hint)
                .font(.caption)
                .foregroundStyle(.hermesSecondaryText)
        }
    }
}
