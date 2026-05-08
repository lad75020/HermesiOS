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

    var body: some View {
        ScrollView {
            HermesGlassEffectContainer(spacing: 28) {
                VStack(alignment: .leading, spacing: 18) {
                HermesTabHeader("Hermes Agent Runtime", systemImage: "server.rack")

                HermesRuntimeAccordionPanel(
                    title: "Skills",
                    subtitle: "\(companionRuntime.hermesSkills.filter(\.isEnabled).count) enabled, \(companionRuntime.hermesSkills.count) visible in workspace",
                    systemImage: "square.stack.3d.up.fill",
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
                    subtitle: "\(companionRuntime.hermesToolsets.filter(\.enabled).count) enabled, \(companionRuntime.hermesToolsets.count) available in config",
                    systemImage: "wrench.and.screwdriver",
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
                    title: "Knwoledge Eraser",
                    subtitle: companionRuntime.knowledgeEraserItems.isEmpty ? "Find, review, archive, and erase topic-related knowledge" : "\(companionRuntime.knowledgeEraserItems.count) candidates · \(companionRuntime.knowledgeEraserSelectedItemIDs.count) selected",
                    systemImage: "eraser.line.dashed.fill",
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
