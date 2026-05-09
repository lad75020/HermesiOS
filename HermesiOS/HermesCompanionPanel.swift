//
//  HermesCompanionPanel.swift
//  HermesiOS
//

import Observation
import SwiftUI
import UniformTypeIdentifiers

struct HermesCompanionPanel: View {
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
                    description: Text("Use Settings → Host Companion to authenticate this iOS device with the host token before attempting host configuration changes.")
                )
            } else {
                HermesStatusRow(
                    items: [
                        .init(title: "Companion", value: companionRuntime.connectionStatus, accent: .igActionBlue),
                        .init(title: "Service", value: companionRuntime.linkedServiceStatus.isEmpty ? "Unknown" : companionRuntime.linkedServiceStatus, accent: .igOnlineGreen)
                    ]
                )

                HermesSectionCard("PROFILE") {
                    VStack(alignment: .leading, spacing: 14) {
                        if !companionRuntime.lastErrorMessage.isEmpty {
                            Text(companionRuntime.lastErrorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.igDestructive)
                        }

                        if companionRuntime.profiles.isEmpty {
                            Text("Fetch the host profiles to begin editing a profile config.yaml.")
                                .font(.subheadline)
                                .foregroundStyle(.hermesSecondaryText)
                        } else {
                            Picker("Profile", selection: Binding(
                                get: { companionRuntime.companionConfigProfileName },
                                set: { newName in
                                    companionRuntime.selectCompanionProfile(
                                        name: newName,
                                        settings: companionSettings,
                                        identityState: companionEnrollment.identityState
                                    )
                                }
                            )) {
                                ForEach(companionRuntime.profiles) { profile in
                                    Text(profile.name).tag(profile.name)
                                }
                            }
                            .pickerStyle(.menu)

                            Text("Editing config.yaml for the selected profile.")
                                .font(.caption)
                                .foregroundStyle(.hermesSecondaryText)
                        }

                        HStack {
                            Button("Refresh Profiles") {
                                companionRuntime.refreshCompanionProfileConfig(
                                    settings: companionSettings,
                                    identityState: companionEnrollment.identityState
                                )
                            }
                            .buttonStyle(.borderedProminent)

                            if !companionRuntime.selectedTargetID.isEmpty {
                                Button("Reload Config") {
                                    companionRuntime.loadSelectedTarget(
                                        settings: companionSettings,
                                        identityState: companionEnrollment.identityState
                                    )
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                }

                if companionRuntime.selectedTarget != nil {
                    HermesSectionCard("Config Editor") {
                        VStack(alignment: .leading, spacing: 14) {
                            if !companionRuntime.currentRevision.isEmpty {
                                Label("Revision: \(companionRuntime.currentRevision)", systemImage: "number")
                                    .font(.caption)
                                    .foregroundStyle(.hermesSecondaryText)
                            }

                            TextEditor(text: $companionRuntime.targetContent)
                                .scrollContentBackground(.hidden)
                                .font(.system(.body, design: .monospaced))
                                .frame(minHeight: 220, idealHeight: 220, maxHeight: 220)

                            HStack {
                                Button("Save with Backup") {
                                    companionRuntime.saveSelectedTarget(
                                        settings: companionSettings,
                                        identityState: companionEnrollment.identityState
                                    )
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    }

                    HermesSectionCard("Linked Service") {
                        VStack(alignment: .leading, spacing: 14) {
                            if let serviceID = companionRuntime.selectedTarget?.serviceID, !serviceID.isEmpty {
                                Label("Service: \(serviceID)", systemImage: "server.rack")
                                    .font(.subheadline.weight(.semibold))
                                Text(companionRuntime.linkedServiceOutput.isEmpty ? "No service output returned yet." : companionRuntime.linkedServiceOutput)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.hermesSecondaryText)
                                    .textSelection(.enabled)

                                HStack {
                                    Button("Refresh Service Status") {
                                        companionRuntime.refreshLinkedServiceStatus(
                                            settings: companionSettings,
                                            identityState: companionEnrollment.identityState
                                        )
                                    }
                                    .buttonStyle(.bordered)

                                    Button("Restart Service") {
                                        companionRuntime.restartLinkedService(
                                            settings: companionSettings,
                                            identityState: companionEnrollment.identityState
                                        )
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                            } else {
                                Text("The selected target is not associated with a managed service.")
                                    .font(.subheadline)
                                    .foregroundStyle(.hermesSecondaryText)
                            }
                        }
                    }
                }
            }
        }
        .task(id: companionEnrollment.identityState.deviceID) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            if companionRuntime.selectedTargetID.isEmpty {
                companionRuntime.selectedTargetID = "hermes-config"
            }
            if companionRuntime.profiles.isEmpty || companionRuntime.targets.isEmpty || companionRuntime.targetContent.isEmpty {
                companionRuntime.refreshCompanionProfileConfig(
                    settings: companionSettings,
                    identityState: companionEnrollment.identityState
                )
            }
        }
    }
}
