//
//  HermesToolsPanel.swift
//  HermesiOS
//

import Observation
import SwiftUI
import UniformTypeIdentifiers

struct HermesToolsPanel: View {
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession

    private var providerSummary: String {
        if companionEnrollment.identityState.isEnrolled == false {
            return "Authenticate companion to edit provider keys and model defaults"
        }
        let configuredKeys = companionRuntime.providerEnv.filter { !$0.value.isEmpty }.count
        let provider = companionRuntime.providerModelConfig.provider
        let model = companionRuntime.providerModelConfig.model
        if model.isEmpty {
            return "\(configuredKeys) environment values, provider \(provider)"
        }
        return "\(provider) · \(model) · \(configuredKeys) environment values"
    }

    private var memorySummary: String {
        if companionEnrollment.identityState.isEnrolled == false {
            return "Authenticate companion to manage host memory"
        }
        if let config = companionRuntime.memoryConfig {
            let provider = config.provider.isEmpty ? "local" : config.provider
            return "\(companionRuntime.memoryEntries.count) memories · \(provider) · \(config.stats.totalSessions) sessions"
        }
        return "Agent memory, user profile, and memory providers"
    }

    private var schedulesSummary: String {
        if companionEnrollment.identityState.isEnrolled == false {
            return "Authenticate companion to manage scheduled jobs"
        }
        let active = companionRuntime.schedules.filter { $0.state == "active" }.count
        let paused = companionRuntime.schedules.filter { $0.state == "paused" }.count
        return "\(active) active, \(paused) paused, \(companionRuntime.schedules.count) total"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if companionEnrollment.identityState.isEnrolled == false {
                ContentUnavailableView(
                    "Authentication Required",
                    systemImage: "person.badge.key",
                    description: Text("Use Settings → Host Companion to authenticate this iOS device before editing Hermes toolsets.")
                )
            } else {
                HermesSectionCard("Hermes Toolsets") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("This panel mirrors the desktop toolset editor and writes `platform_toolsets.cli` in the live Hermes `config.yaml` for the configured workspace.")
                            .font(.subheadline)
                            .foregroundStyle(.hermesSecondaryText)

                        companionSummaryRow(label: "Workspace", value: companionRuntime.resolvedHermesWorkspacePath.isEmpty ? companionSettings.hermesWorkspacePath : companionRuntime.resolvedHermesWorkspacePath)
                        companionSummaryRow(label: "Config", value: companionRuntime.toolsetsConfigPath.isEmpty ? "\(companionSettings.hermesWorkspacePath)/config.yaml" : companionRuntime.toolsetsConfigPath)

                        if !companionRuntime.lastErrorMessage.isEmpty {
                            Text(companionRuntime.lastErrorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.igDestructive)
                        }

                        if companionRuntime.hermesToolsets.isEmpty {
                            Text("Open this panel after Host Companion authentication to load the toolsets declared by Hermes desktop semantics.")
                                .font(.subheadline)
                                .foregroundStyle(.hermesSecondaryText)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(companionRuntime.hermesToolsets) { toolset in
                                    HermesToolsetToggleRow(
                                        toolset: toolset,
                                        isEnabled: Binding(
                                            get: {
                                                companionRuntime.hermesToolsets.first(where: { $0.key == toolset.key })?.enabled ?? toolset.enabled
                                            },
                                            set: { isEnabled in
                                                companionRuntime.setHermesToolsetEnabled(
                                                    key: toolset.key,
                                                    enabled: isEnabled,
                                                    settings: companionSettings,
                                                    identityState: companionEnrollment.identityState
                                                )
                                            }
                                        )
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        .task(id: companionEnrollment.identityState.deviceID) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            companionRuntime.refreshHermesToolsets(settings: companionSettings, identityState: companionEnrollment.identityState)
        }
        .task(id: companionSettings.hermesWorkspacePath) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            companionRuntime.refreshHermesToolsets(settings: companionSettings, identityState: companionEnrollment.identityState)
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
}
