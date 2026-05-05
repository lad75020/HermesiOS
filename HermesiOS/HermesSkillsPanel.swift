//
//  HermesSkillsPanel.swift
//  HermesiOS
//

import Observation
import SwiftUI
import UniformTypeIdentifiers

struct HermesSkillsPanel: View {
    @Binding var agentConfiguration: HermesAgentConfiguration
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession

    private var filteredHermesSkills: [HermesCompanionSkillSummary] {
        let query = agentConfiguration.skillSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return companionRuntime.hermesSkills }
        return companionRuntime.hermesSkills.filter { skill in
            skill.name.lowercased().hasPrefix(query.lowercased())
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if companionEnrollment.identityState.isEnrolled {
                HermesSectionCard("Companion Skills Store") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Skills are loaded from the configured Hermes workspace and toggles write the live `.hermes/skills/.usage.json` state on the host companion.")
                            .font(.subheadline)
                            .foregroundStyle(.hermesSecondaryText)

                        settingsSummaryRow(label: "Workspace", value: companionRuntime.resolvedHermesWorkspacePath.isEmpty ? companionSettings.hermesWorkspacePath : companionRuntime.resolvedHermesWorkspacePath)

                        Text(companionRuntime.isBusy ? "Syncing…" : "\(companionRuntime.hermesSkills.filter(\.isEnabled).count) enabled")
                            .font(.caption)
                            .foregroundStyle(.hermesSecondaryText)
                    }
                }
            }

            TextField("Start with", text: $agentConfiguration.skillSearchQuery)
                .hermesRuntimeInput(background: Color.igOnlineGreen.opacity(0.08), border: Color.igOnlineGreen.opacity(0.28))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            let visibleSkills = filteredHermesSkills
            if visibleSkills.isEmpty {
                ContentUnavailableView(
                    "No Skills Found",
                    systemImage: "magnifyingglass",
                    description: Text(companionEnrollment.identityState.isEnrolled ? "Enter the beginning of a skill name or verify the Hermes workspace path in Settings." : "Enroll the host companion first, then load skills from the Hermes workspace.")
                )
            } else {
                HermesSectionCard("Skills Catalog") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Toggle any skill on to mark it active in Hermes, or off to archive it from the live workspace state.")
                            .font(.subheadline)
                            .foregroundStyle(.hermesSecondaryText)

                        ForEach(visibleSkills) { skill in
                            HermesSkillToggleRow(
                                skill: skill,
                                isEnabled: Binding(
                                    get: {
                                        companionRuntime.hermesSkills.first(where: { $0.id == skill.id })?.isEnabled ?? skill.isEnabled
                                    },
                                    set: { isEnabled in
                                        companionRuntime.setHermesSkillState(
                                            skillID: skill.id,
                                            isEnabled: isEnabled,
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
        .task(id: companionEnrollment.identityState.deviceID) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            companionRuntime.refreshHermesSkills(settings: companionSettings, identityState: companionEnrollment.identityState)
        }
        .task(id: companionSettings.hermesWorkspacePath) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            companionRuntime.refreshHermesSkills(settings: companionSettings, identityState: companionEnrollment.identityState)
        }
    }

    private func settingsSummaryRow(label: String, value: String) -> some View {
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
