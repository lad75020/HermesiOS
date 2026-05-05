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
            return "Enroll companion to edit provider keys and model defaults"
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
            return "Enroll companion to manage host memory"
        }
        if let config = companionRuntime.memoryConfig {
            let provider = config.provider.isEmpty ? "local" : config.provider
            return "\(companionRuntime.memoryEntries.count) memories · \(provider) · \(config.stats.totalSessions) sessions"
        }
        return "Agent memory, user profile, and memory providers"
    }

    private var schedulesSummary: String {
        if companionEnrollment.identityState.isEnrolled == false {
            return "Enroll companion to manage scheduled jobs"
        }
        let active = companionRuntime.schedules.filter { $0.state == "active" }.count
        let paused = companionRuntime.schedules.filter { $0.state == "paused" }.count
        return "\(active) active, \(paused) paused, \(companionRuntime.schedules.count) total"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if companionEnrollment.identityState.isEnrolled == false {
                ContentUnavailableView(
                    "Enrollment Required",
                    systemImage: "person.badge.key",
                    description: Text("Use Settings → Host Companion to enroll this iOS device and import its client identity before attempting host configuration changes.")
                )
            } else {
                HermesStatusRow(
                    items: [
                        .init(title: "Companion", value: companionRuntime.connectionStatus, accent: .igActionBlue),
                        .init(title: "Service", value: companionRuntime.linkedServiceStatus.isEmpty ? "Unknown" : companionRuntime.linkedServiceStatus, accent: .igOnlineGreen)
                    ]
                )

                HermesSectionCard("Allowlisted Targets") {
                    VStack(alignment: .leading, spacing: 14) {
                        if !companionRuntime.lastErrorMessage.isEmpty {
                            Text(companionRuntime.lastErrorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.igDestructive)
                        }

                        if companionRuntime.targets.isEmpty {
                            Text("Fetch the host companion target registry to begin editing allowlisted files.")
                                .font(.subheadline)
                                .foregroundStyle(.hermesSecondaryText)
                        } else {
                            Picker("Target", selection: $companionRuntime.selectedTargetID) {
                                ForEach(companionRuntime.targets) { target in
                                    Text(target.displayName).tag(target.id)
                                }
                            }
                            .pickerStyle(.menu)

                            if let selectedTarget = companionRuntime.selectedTarget {
                                Text(selectedTarget.path)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.hermesSecondaryText)
                                    .textSelection(.enabled)
                            }
                        }

                        HStack {
                            Button("Refresh Targets") {
                                companionRuntime.refreshTargets(
                                    settings: companionSettings,
                                    identityState: companionEnrollment.identityState
                                )
                            }
                            .buttonStyle(.borderedProminent)

                            if !companionRuntime.selectedTargetID.isEmpty {
                                Button("Reload Target") {
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
                    HermesSectionCard("Target Editor") {
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
                                Button("Validate") {
                                    companionRuntime.validateSelectedTarget(
                                        settings: companionSettings,
                                        identityState: companionEnrollment.identityState
                                    )
                                }
                                .buttonStyle(.bordered)

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

                    HermesSectionCard("Validation") {
                        if companionRuntime.diagnostics.isEmpty {
                            Text("Run validation to inspect syntax and policy diagnostics before writing to the host.")
                                .font(.subheadline)
                                .foregroundStyle(.hermesSecondaryText)
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(companionRuntime.diagnostics) { diagnostic in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(diagnostic.severity.rawValue.capitalized)
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(severityColor(for: diagnostic.severity))
                                            Spacer()
                                            Text(diagnostic.validator)
                                                .font(.caption.monospaced())
                                                .foregroundStyle(.hermesSecondaryText)
                                        }
                                        Text(diagnostic.message)
                                            .font(.subheadline)
                                            .foregroundStyle(.hermesSecondaryText)
                                    }
                                    .padding(14)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.hermesSurfaceInput)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
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
            if companionRuntime.targets.isEmpty {
                companionRuntime.refreshTargets(
                    settings: companionSettings,
                    identityState: companionEnrollment.identityState
                )
            }
        }
    }

    private func severityColor(for severity: HermesCompanionValidationSeverity) -> Color {
        switch severity {
        case .error:
            .igDestructive
        case .warning:
            .igGradOrange
        case .info:
            .igActionBlue
        }
    }
}
