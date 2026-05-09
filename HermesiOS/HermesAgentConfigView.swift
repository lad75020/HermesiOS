//
//  HermesAgentConfigView.swift
//  HermesiOS
//

import Observation
import SwiftUI

struct HermesAgentConfigView: View {
    @Binding var agentConfiguration: HermesAgentConfiguration
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

    private var profilesSummary: String {
        if companionEnrollment.identityState.isEnrolled == false {
            return "Enroll companion to manage host profiles"
        }
        if companionRuntime.profiles.isEmpty {
            return "Default and named Hermes profiles"
        }
        return "\(companionRuntime.profiles.count) profiles · active \(companionRuntime.activeProfileName)"
    }

    private var gatewaySummary: String {
        if companionEnrollment.identityState.isEnrolled == false {
            return "Enroll companion to manage messaging credentials"
        }
        let enabled = companionRuntime.gatewayPlatformEnabled.values.filter { $0 }.count
        let total = companionRuntime.gatewayPlatforms.count
        if total == 0 {
            return "Messaging platform credentials and enablement"
        }
        return "\(enabled)/\(total) messaging platforms enabled"
    }

    private var mcpServersSummary: String {
        if companionEnrollment.identityState.isEnrolled == false {
            return "Enroll companion to list, add, or remove MCP servers"
        }
        if companionRuntime.hermesMCPServers.isEmpty {
            return "No MCP servers loaded from hermes mcp list"
        }
        return "\(companionRuntime.hermesMCPServers.count) configured via hermes mcp list"
    }

    private var observabilitySummary: String {
        if companionEnrollment.identityState.isEnrolled == false {
            return "Enroll companion to read host Hermes logs"
        }
        return "\(companionRuntime.observabilityLogKind.label) · last \(companionRuntime.observabilityLineCount) lines"
    }

    private var runtimeHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "server.rack")
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.igActionBlue)
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)

            Text("Hermes Agent Runtime")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private func runtimeSectionLoaded(_ id: String) -> Bool {
        companionRuntime.hasRuntimeSectionLoaded(id)
    }

    var body: some View {
        ScrollView {
            HermesGlassEffectContainer(spacing: 28) {
                VStack(alignment: .leading, spacing: 18) {
                runtimeHeader

                HermesRuntimeAccordionPanel(
                    title: "Skills",
                    subtitle: "\(companionRuntime.hermesSkills.filter(\.isEnabled).count) enabled, \(companionRuntime.hermesSkills.count) visible in workspace",
                    systemImage: "square.stack.3d.up.fill",
                    isLoaded: runtimeSectionLoaded("skills"),
                    isExpanded: Binding(
                        get: { agentConfiguration.activeRuntimePanel == .skills },
                        set: { isExpanded in
                            agentConfiguration.activeRuntimePanel = isExpanded ? .skills : nil
                        }
                    )
                ) {
                    HermesSkillsPanel(
                        agentConfiguration: $agentConfiguration,
                        companionSettings: companionSettings,
                        companionEnrollment: companionEnrollment,
                        companionRuntime: companionRuntime
                    )
                }

                HermesRuntimeAccordionPanel(
                    title: "Companion",
                    subtitle: companionEnrollment.identityState.isEnrolled ? companionRuntime.connectionStatus : "Authenticate with the 4096-character companion token to unlock host operations",
                    systemImage: "lock.laptopcomputer",
                    isLoaded: runtimeSectionLoaded("companion"),
                    isExpanded: Binding(
                        get: { agentConfiguration.activeRuntimePanel == .companion },
                        set: { isExpanded in
                            agentConfiguration.activeRuntimePanel = isExpanded ? .companion : nil
                        }
                    )
                ) {
                    HermesCompanionPanel(
                        companionSettings: companionSettings,
                        companionEnrollment: companionEnrollment,
                        companionRuntime: companionRuntime
                    )
                }

                HermesRuntimeAccordionPanel(
                    title: "Profiles",
                    subtitle: profilesSummary,
                    systemImage: "person.crop.rectangle.stack",
                    isLoaded: runtimeSectionLoaded("profiles"),
                    isExpanded: Binding(
                        get: { agentConfiguration.activeRuntimePanel == .profiles },
                        set: { isExpanded in
                            agentConfiguration.activeRuntimePanel = isExpanded ? .profiles : nil
                        }
                    )
                ) {
                    HermesProfilesPanel(
                        companionSettings: companionSettings,
                        companionEnrollment: companionEnrollment,
                        companionRuntime: companionRuntime
                    )
                }

                HermesRuntimeAccordionPanel(
                    title: "Messaging",
                    subtitle: gatewaySummary,
                    systemImage: "antenna.radiowaves.left.and.right",
                    isLoaded: runtimeSectionLoaded("gateway"),
                    isExpanded: Binding(
                        get: { agentConfiguration.activeRuntimePanel == .gateway },
                        set: { isExpanded in
                            agentConfiguration.activeRuntimePanel = isExpanded ? .gateway : nil
                        }
                    )
                ) {
                    HermesGatewayPanel(
                        companionSettings: companionSettings,
                        companionEnrollment: companionEnrollment,
                        companionRuntime: companionRuntime
                    )
                }

                HermesRuntimeAccordionPanel(
                    title: "Tools",
                    subtitle: "\(companionRuntime.hermesToolsets.filter(\.enabled).count) enabled, \(companionRuntime.hermesToolsets.count) available",
                    systemImage: "wrench.and.screwdriver",
                    isLoaded: runtimeSectionLoaded("tools"),
                    isExpanded: Binding(
                        get: { agentConfiguration.activeRuntimePanel == .tools },
                        set: { isExpanded in
                            agentConfiguration.activeRuntimePanel = isExpanded ? .tools : nil
                        }
                    )
                ) {
                    HermesToolsPanel(
                        companionSettings: companionSettings,
                        companionEnrollment: companionEnrollment,
                        companionRuntime: companionRuntime
                    )
                }

                HermesRuntimeAccordionPanel(
                    title: "MCP Servers",
                    subtitle: mcpServersSummary,
                    systemImage: "point.3.connected.trianglepath.dotted",
                    isLoaded: runtimeSectionLoaded("mcpServers"),
                    isExpanded: Binding(
                        get: { agentConfiguration.activeRuntimePanel == .mcpServers },
                        set: { isExpanded in
                            agentConfiguration.activeRuntimePanel = isExpanded ? .mcpServers : nil
                        }
                    )
                ) {
                    HermesMCPServersPanel(
                        companionSettings: companionSettings,
                        companionEnrollment: companionEnrollment,
                        companionRuntime: companionRuntime
                    )
                }


                HermesRuntimeAccordionPanel(
                    title: "Providers",
                    subtitle: providerSummary,
                    systemImage: "key.horizontal",
                    isLoaded: runtimeSectionLoaded("providers"),
                    isExpanded: Binding(
                        get: { agentConfiguration.activeRuntimePanel == .providers },
                        set: { isExpanded in
                            agentConfiguration.activeRuntimePanel = isExpanded ? .providers : nil
                        }
                    )
                ) {
                    HermesProvidersPanel(
                        companionSettings: companionSettings,
                        companionEnrollment: companionEnrollment,
                        companionRuntime: companionRuntime
                    )
                }

                HermesRuntimeAccordionPanel(
                    title: "Memory",
                    subtitle: memorySummary,
                    systemImage: "brain.head.profile",
                    isLoaded: runtimeSectionLoaded("memory"),
                    isExpanded: Binding(
                        get: { agentConfiguration.activeRuntimePanel == .memory },
                        set: { isExpanded in
                            agentConfiguration.activeRuntimePanel = isExpanded ? .memory : nil
                        }
                    )
                ) {
                    HermesMemoryPanel(
                        companionSettings: companionSettings,
                        companionEnrollment: companionEnrollment,
                        companionRuntime: companionRuntime
                    )
                }

                HermesRuntimeAccordionPanel(
                    title: "Knowledge Eraser",
                    subtitle: companionRuntime.knowledgeEraserItems.isEmpty ? "Find, review, archive, and erase topic-related knowledge" : "\(companionRuntime.knowledgeEraserItems.count) candidates · \(companionRuntime.knowledgeEraserSelectedItemIDs.count) selected",
                    systemImage: "eraser.line.dashed.fill",
                    isLoaded: runtimeSectionLoaded("knowledgeEraser"),
                    isExpanded: Binding(
                        get: { agentConfiguration.activeRuntimePanel == .knowledgeEraser },
                        set: { isExpanded in
                            agentConfiguration.activeRuntimePanel = isExpanded ? .knowledgeEraser : nil
                        }
                    )
                ) {
                    HermesKnowledgeEraserPanel(
                        companionSettings: companionSettings,
                        companionEnrollment: companionEnrollment,
                        companionRuntime: companionRuntime
                    )
                }

                HermesRuntimeAccordionPanel(
                    title: "Schedules",
                    subtitle: schedulesSummary,
                    systemImage: "calendar.badge.clock",
                    isLoaded: runtimeSectionLoaded("schedules"),
                    isExpanded: Binding(
                        get: { agentConfiguration.activeRuntimePanel == .schedules },
                        set: { isExpanded in
                            agentConfiguration.activeRuntimePanel = isExpanded ? .schedules : nil
                        }
                    )
                ) {
                    HermesSchedulesPanel(
                        companionSettings: companionSettings,
                        companionEnrollment: companionEnrollment,
                        companionRuntime: companionRuntime
                    )
                }

                HermesRuntimeAccordionPanel(
                    title: "Models",
                    subtitle: "Main, delegation, and auxiliary runtime model routing",
                    systemImage: "cpu",
                    isLoaded: runtimeSectionLoaded("models"),
                    isExpanded: Binding(
                        get: { agentConfiguration.activeRuntimePanel == .models },
                        set: { isExpanded in
                            agentConfiguration.activeRuntimePanel = isExpanded ? .models : nil
                        }
                    )
                ) {
                    HermesModelsPanel(
                        companionSettings: companionSettings,
                        companionEnrollment: companionEnrollment,
                        companionRuntime: companionRuntime
                    )
                }

                HermesRuntimeAccordionPanel(
                    title: "Observability",
                    subtitle: observabilitySummary,
                    systemImage: "waveform.and.magnifyingglass",
                    isLoaded: runtimeSectionLoaded("observability"),
                    isExpanded: Binding(
                        get: { agentConfiguration.activeRuntimePanel == .observability },
                        set: { isExpanded in
                            agentConfiguration.activeRuntimePanel = isExpanded ? .observability : nil
                        }
                    )
                ) {
                    HermesObservabilityPanel(
                        companionSettings: companionSettings,
                        companionEnrollment: companionEnrollment,
                        companionRuntime: companionRuntime
                    )
                }

                }
                .padding()
            }
        }
        .background(Color.hermesCanvas)
        .toolbar(.hidden, for: .navigationBar)
    }
}
