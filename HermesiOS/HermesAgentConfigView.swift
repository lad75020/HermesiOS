//
//  HermesAgentConfigView.swift
//  HermesiOS
//

import Observation
import SwiftUI
import UniformTypeIdentifiers

struct HermesAgentConfigView: View {
    @Binding var agentConfiguration: HermesAgentConfiguration
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession
    @State private var isSSHPrivateKeyImporterPresented = false
    @State private var sshPrivateKeyPickerError: String?

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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HermesHeroCard(
                    title: "Agent Runtime",
                    detail: "This area is structured as an accordion so one operational panel can stay expanded while the others collapse into quick section headers.",
                    systemImage: "server.rack"
                )

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
                    subtitle: companionEnrollment.identityState.isEnrolled ? companionRuntime.connectionStatus : "Enroll an iOS client certificate to unlock host operations",
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
                    title: "Backend",
                    subtitle: agentConfiguration.backend == .ssh ? "SSH remote host configuration" : agentConfiguration.backend.displayName,
                    systemImage: agentConfiguration.backend.systemImage,
                    isExpanded: Binding(
                        get: { agentConfiguration.activeRuntimePanel == .backend },
                        set: { isExpanded in
                            agentConfiguration.activeRuntimePanel = isExpanded ? .backend : nil
                        }
                    )
                ) {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("Terminal backend", selection: $agentConfiguration.backend) {
                            ForEach(HermesTerminalBackend.allCases) { backend in
                                Text(backend.displayName).tag(backend)
                            }
                        }

                        Toggle("Persistent shell", isOn: $agentConfiguration.persistentShell)

                        TextField("Working directory", text: $agentConfiguration.workingDirectory)
                            .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        if agentConfiguration.backend == .ssh {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("SSH")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                TextField("Host", text: $agentConfiguration.sshHost)
                                    .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                TextField("User", text: $agentConfiguration.sshUser)
                                    .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                TextField("Port", text: $agentConfiguration.sshPort)
                                    .hermesRuntimeInput(background: Color.igActionBlue.opacity(0.08), border: Color.igActionBlue.opacity(0.28))
                                    .keyboardType(.numberPad)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Private key")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)

                                    HStack(spacing: 10) {
                                        Text(agentConfiguration.sshKeyPath.isEmpty ? "No private key selected" : agentConfiguration.sshKeyPath)
                                            .font(.system(.footnote, design: .monospaced))
                                            .foregroundStyle(agentConfiguration.sshKeyPath.isEmpty ? .secondary : .primary)
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        Button("Choose…") {
                                            sshPrivateKeyPickerError = nil
                                            isSSHPrivateKeyImporterPresented = true
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color.igActionBlue.opacity(0.08))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(Color.igActionBlue.opacity(0.28), lineWidth: 1)
                                    )
                                    .shadow(color: Color.igActionBlue.opacity(0.05), radius: 8, y: 3)

                                    if let sshPrivateKeyPickerError {
                                        Text(sshPrivateKeyPickerError)
                                            .font(.caption)
                                            .foregroundStyle(Color.igDestructive)
                                    }
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
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
                    subtitle: "\(companionRuntime.hermesModels.count) saved in workspace inventory",
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

                ForEach(HermesRuntimePanel.placeholderPanels) { panel in
                    HermesRuntimeAccordionPanel(
                        title: panel.title,
                        subtitle: panel.subtitle,
                        systemImage: panel.systemImage,
                        isExpanded: Binding(
                            get: { agentConfiguration.activeRuntimePanel == panel.kind },
                            set: { isExpanded in
                                agentConfiguration.activeRuntimePanel = isExpanded ? panel.kind : nil
                            }
                        )
                    ) {
                        Text(panel.placeholder)
                            .font(.subheadline)
                            .foregroundStyle(.hermesSecondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Agent Runtime")
        .background(Color.hermesCanvas)
        .fileImporter(
            isPresented: $isSSHPrivateKeyImporterPresented,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let didAccessSecurityScopedResource = url.startAccessingSecurityScopedResource()
                defer {
                    if didAccessSecurityScopedResource {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                agentConfiguration.sshKeyPath = url.path
                sshPrivateKeyPickerError = nil
            case .failure(let error):
                sshPrivateKeyPickerError = error.localizedDescription
            }
        }
    }
}
