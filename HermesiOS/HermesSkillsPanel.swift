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
    @State private var companionRuntime = HermesCompanionRuntimeSession()
    let tuiGatewayStore: HermesTUIGatewayStore
    let apiSettings: HermesAPISettings
    let dashboardURLString: String
    let selectedProfileName: String
    let authenticatedProfiles: [HermesCompanionProfileInfo]
    @State private var gatewayCatalog: HermesTUIGatewaySkillsCatalog?
    @State private var isLoadingGatewayCatalog = false
    @State private var gatewayCatalogError = ""
    @State private var gatewayCatalogRequestID = UUID()
    @State private var gatewayCatalogTask: Task<Void, Never>?
    @State private var profileSkills = HermesDashboardProfileSkillsStore()
    @State private var profileInventory: [HermesDashboardProfileSkill] = []
    @State private var isLoadingProfileInventory = false
    @State private var profileInventoryError = ""
    @State private var profileInventoryRequestID = UUID()
    @State private var profileInventoryTask: Task<Void, Never>?
    @State private var profileInventoryMutationID = UUID()
    @State private var profileInventoryMutationTask: Task<Void, Never>?
    @State private var profileSkillDescriptions: [String: String] = [:]
    @State private var profileSkillDescriptionErrors: [String: String] = [:]
    @State private var loadingProfileSkillDescriptions: Set<String> = []
    @State private var profileSkillDescriptionRequestIDs: [String: UUID] = [:]
    @State private var profileSkillDescriptionTasks: [String: Task<Void, Never>] = [:]

    private var fallbackSettings: HermesCompanionSettings? {
        guard companionEnrollment.identityState.isEnrolled,
              companionEnrollment.identityState.matches(settings: companionSettings) else { return nil }
        return HermesSkillsFallbackPathPolicy.settings(selectedProfileName: selectedProfileName, authenticatedProfiles: authenticatedProfiles, baseSettings: companionSettings)
    }

    private var filteredHermesSkills: [HermesCompanionSkillSummary] {
        let query = agentConfiguration.skillSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.isEmpty == false else { return companionRuntime.hermesSkills }
        return companionRuntime.hermesSkills.filter { skill in
            let needle = query.lowercased()
            return skill.name.lowercased().contains(needle) || skill.description.lowercased().contains(needle) || skill.category.lowercased().contains(needle)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            profileInventoryCard

            DisclosureGroup("Gateway Process Catalog (Optional)") {
                HermesSectionCard("Gateway Skills Catalog") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Read-only gateway process catalog. It is cached process-wide, not keyed to the selected management profile, has no disabled entries, and may require a gateway restart to refresh.")
                            .font(.subheadline).foregroundStyle(.hermesSecondaryText)
                        if isLoadingGatewayCatalog {
                            ProgressView("Loading gateway catalog")
                        } else if let gatewayCatalog {
                            if gatewayCatalog.categories.isEmpty {
                                ContentUnavailableView("Gateway Catalog Is Empty", systemImage: "square.stack.3d.up", description: Text("The gateway returned no skill names."))
                            } else {
                                Text("\(gatewayCatalog.skillCount) skills in \(gatewayCatalog.categories.count) categories").font(.caption).foregroundStyle(.hermesSecondaryText)
                                ForEach(gatewayCatalog.categories.keys.sorted(), id: \.self) { category in
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(category).font(.headline)
                                        Text(gatewayCatalog.categories[category, default: []].joined(separator: ", ")).font(.subheadline).foregroundStyle(.hermesSecondaryText)
                                    }
                                }
                            }
                        } else {
                            ContentUnavailableView("Gateway Catalog Unavailable", systemImage: "antenna.radiowaves.left.and.right", description: Text(gatewayCatalogError.isEmpty ? "Connect to the TUI Gateway to read its process catalog." : gatewayCatalogError))
                        }
                        Button("Load Gateway Catalog") { loadGatewayCatalog() }.hermesGlassButton().disabled(isLoadingGatewayCatalog)
                    }
                }
            }

            HermesSectionCard("Companion Fallback Inventory") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("The authenticated dashboard controls this exact selected profile. Companion remains available for its own authenticated profile path.")
                        .font(.subheadline).foregroundStyle(.hermesSecondaryText)
                    if let fallbackSettings, companionEnrollment.identityState.isEnrolled {
                        settingsSummaryRow(label: "Selected profile path", value: fallbackSettings.hermesWorkspacePath)
                        Button("Load Selected Profile Inventory") { companionRuntime.refreshHermesSkills(settings: fallbackSettings, identityState: companionEnrollment.identityState) }
                            .hermesGlassProminentButton().disabled(companionRuntime.isBusy)
                        if !companionRuntime.lastErrorMessage.isEmpty {
                            Text(companionRuntime.lastErrorMessage).font(.caption).foregroundStyle(.igDestructive)
                        }
                    } else {
                        Text(companionEnrollment.identityState.isEnrolled ? "The authenticated Companion identity and profile path could not be matched for \"\(selectedProfileName)\". Fallback is blocked; it will not fall through to Default." : "Host Companion enrollment is required only for the fallback profile path. The selected-profile dashboard inventory and toggles above work without enrollment.")
                            .font(.subheadline).foregroundStyle(.hermesSecondaryText)
                    }
                }
            }

            if let fallbackSettings, companionEnrollment.identityState.isEnrolled, companionRuntime.hasRuntimeSectionLoaded("skills") {
                HermesSectionCard("Selected Profile Skills") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Loaded only after an explicit Host Companion request for this selected profile. Toggles update Hermes' disabled-skills configuration.").font(.subheadline).foregroundStyle(.hermesSecondaryText)
                        settingsSummaryRow(label: "Workspace", value: companionRuntime.resolvedHermesWorkspacePath.isEmpty ? fallbackSettings.hermesWorkspacePath : companionRuntime.resolvedHermesWorkspacePath)
                        Text(companionRuntime.isBusy ? "Syncing…" : "\(companionRuntime.hermesSkills.filter(\.isEnabled).count) enabled").font(.caption).foregroundStyle(.hermesSecondaryText)
                    }
                }
            }

            let visibleSkills = filteredHermesSkills
            if fallbackSettings != nil, companionEnrollment.identityState.isEnrolled, companionRuntime.hasRuntimeSectionLoaded("skills"), visibleSkills.isEmpty {
                ContentUnavailableView("No Skills Found", systemImage: "magnifyingglass", description: Text("Enter the beginning of a skill name or verify the selected profile's authenticated path."))
            } else if let fallbackSettings, companionEnrollment.identityState.isEnrolled, companionRuntime.hasRuntimeSectionLoaded("skills"), !visibleSkills.isEmpty {
                HermesSectionCard("Skills Catalog") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Enable or disable skills for the selected profile without deleting their files.").font(.subheadline).foregroundStyle(.hermesSecondaryText)
                        ForEach(visibleSkills) { skill in
                            HermesSkillToggleRow(skill: skill, isEnabled: Binding(
                                get: { companionRuntime.hermesSkills.first(where: { $0.id == skill.id })?.isEnabled ?? skill.isEnabled },
                                set: { isEnabled in companionRuntime.setHermesSkillState(skillID: skill.id, isEnabled: isEnabled, settings: fallbackSettings, identityState: companionEnrollment.identityState) }
                            ))
                            .disabled(companionRuntime.isBusy)
                        }
                    }
                }
            }
        }
        .task(id: gatewayCatalogTaskIdentity) { loadProfileInventory() }
        .onDisappear {
            gatewayCatalogRequestID = UUID()
            gatewayCatalogTask?.cancel()
            profileInventoryRequestID = UUID()
            profileInventoryTask?.cancel()
            profileInventoryMutationID = UUID()
            profileInventoryMutationTask?.cancel()
            cancelProfileDescriptionLoads()
        }
    }

    private var gatewayCatalogTaskIdentity: HermesRuntimeConnectionIdentity {
        HermesRuntimeConnectionIdentity(dashboardURL: dashboardURLString, apiSettings: apiSettings)
    }

    private var profileInventoryCard: some View {
        HermesSectionCard("Selected Profile Skills — Dashboard") {
            VStack(alignment: .leading, spacing: 12) {
                Text(selectedProfileName).font(.headline)
                Text("Installed skills and their configuration state from this exact selected profile. No Companion connection or chat session is needed. This is configuration state, not proof that an existing chat has reloaded its skills.")
                    .font(.subheadline).foregroundStyle(.hermesSecondaryText)
                TextField("Search skills", text: $agentConfiguration.skillSearchQuery)
                    .hermesRuntimeInput(background: Color.igOnlineGreen.opacity(0.08), border: Color.igOnlineGreen.opacity(0.28))
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                if isLoadingProfileInventory {
                    ProgressView("Loading selected-profile skills")
                } else {
                    Text("\(profileInventory.count) installed entries · \(profileInventory.filter(\.isEnabled).count) enabled")
                        .font(.caption).foregroundStyle(.hermesSecondaryText)
                    if profileSkills.isMutating {
                        ProgressView("Updating skill setting")
                    }
                    let query = agentConfiguration.skillSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
                    let skills = profileInventory.filter {
                        query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)
                            || $0.description?.localizedCaseInsensitiveContains(query) == true
                            || profileSkillDescriptions[$0.name]?.localizedCaseInsensitiveContains(query) == true
                            || $0.category.localizedCaseInsensitiveContains(query)
                    }
                    if skills.isEmpty {
                        ContentUnavailableView("No Skills Found", systemImage: "magnifyingglass", description: Text(profileInventory.isEmpty ? "The selected profile has no installed skills." : "No installed skill names match this search."))
                    }
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(skills) { skill in
                            HermesDashboardProfileSkillToggleRow(
                                skill: skill,
                                description: profileSkillDescriptions[skill.name] ?? skill.description,
                                isDescriptionLoading: loadingProfileSkillDescriptions.contains(skill.name),
                                descriptionError: profileSkillDescriptionErrors[skill.name],
                                isEnabled: Binding(
                                    get: { profileInventory.first(where: { $0.id == skill.id })?.isEnabled ?? skill.isEnabled },
                                    set: { setProfileSkillEnabled(skill.name, enabled: $0) }
                                ),
                                canMutate: !profileSkills.isMutating,
                                onRequestDescription: { loadProfileSkillDescription(skill.name) }
                            )
                        }
                    }
                }
                if !profileInventoryError.isEmpty {
                    Text(profileInventoryError).foregroundStyle(.igDestructive)
                }
                Button("Refresh Profile Inventory", systemImage: "arrow.clockwise") { loadProfileInventory() }
                    .hermesGlassProminentButton().disabled(isLoadingProfileInventory || profileSkills.isMutating)
            }
        }
    }

    private func loadProfileInventory() {
        profileInventoryTask?.cancel()
        cancelProfileDescriptionLoads()
        profileSkillDescriptions.removeAll()
        profileSkillDescriptionErrors.removeAll()
        let requestID = UUID()
        profileInventoryRequestID = requestID
        isLoadingProfileInventory = true
        profileInventoryError = ""
        profileInventory = []
        profileInventoryTask = Task {
            defer {
                if profileInventoryRequestID == requestID {
                    isLoadingProfileInventory = false
                    profileInventoryTask = nil
                }
            }
            do {
                try Task.checkCancellation()
                let inventory = try await profileSkills.load(profile: selectedProfileName, dashboardBaseURL: dashboardURLString, apiSettings: apiSettings)
                guard profileInventoryRequestID == requestID, !Task.isCancelled else { return }
                profileInventory = inventory
            } catch {
                guard profileInventoryRequestID == requestID, !Task.isCancelled else { return }
                profileInventoryError = error.localizedDescription
            }
        }
    }

    private func loadProfileSkillDescription(_ name: String) {
        guard profileSkillDescriptions[name] == nil,
              profileSkillDescriptionTasks[name] == nil else { return }
        profileSkillDescriptionErrors[name] = nil
        loadingProfileSkillDescriptions.insert(name)
        let requestID = UUID()
        profileSkillDescriptionRequestIDs[name] = requestID
        profileSkillDescriptionTasks[name] = Task {
            defer {
                if profileSkillDescriptionRequestIDs[name] == requestID {
                    loadingProfileSkillDescriptions.remove(name)
                    profileSkillDescriptionRequestIDs[name] = nil
                    profileSkillDescriptionTasks[name] = nil
                }
            }
            do {
                let description = try await profileSkills.loadDescription(
                    name: name,
                    profile: selectedProfileName,
                    dashboardBaseURL: dashboardURLString,
                    apiSettings: apiSettings
                )
                guard profileSkillDescriptionRequestIDs[name] == requestID, !Task.isCancelled else { return }
                profileSkillDescriptions[name] = description
            } catch {
                guard profileSkillDescriptionRequestIDs[name] == requestID, !Task.isCancelled else { return }
                profileSkillDescriptionErrors[name] = error.localizedDescription
            }
        }
    }

    private func cancelProfileDescriptionLoads() {
        let tasks = Array(profileSkillDescriptionTasks.values)
        profileSkillDescriptionRequestIDs.removeAll()
        profileSkillDescriptionTasks.removeAll()
        loadingProfileSkillDescriptions.removeAll()
        for task in tasks { task.cancel() }
    }

    private func setProfileSkillEnabled(_ name: String, enabled: Bool) {
        guard !isLoadingProfileInventory, !profileSkills.isMutating else { return }
        profileInventoryError = ""
        let mutationID = UUID()
        profileInventoryMutationID = mutationID
        profileInventoryMutationTask = Task {
            defer {
                if profileInventoryMutationID == mutationID {
                    profileInventoryMutationTask = nil
                }
            }
            do {
                try Task.checkCancellation()
                let readback = try await profileSkills.setEnabled(
                    name: name,
                    enabled: enabled,
                    profile: selectedProfileName,
                    dashboardBaseURL: dashboardURLString,
                    apiSettings: apiSettings
                )
                guard profileInventoryMutationID == mutationID, !Task.isCancelled else { return }
                profileInventory = readback
            } catch {
                guard profileInventoryMutationID == mutationID, !Task.isCancelled else { return }
                profileInventoryError = error.localizedDescription
            }
        }
    }

    private func loadGatewayCatalog() {
        gatewayCatalogTask?.cancel()
        let requestID = UUID()
        gatewayCatalogRequestID = requestID
        isLoadingGatewayCatalog = true
        gatewayCatalogError = ""
        gatewayCatalogTask = Task {
            do {
                try await tuiGatewayStore.connectForRuntime(dashboardBaseURL: dashboardURLString, apiSettings: apiSettings)
                let catalog = try await tuiGatewayStore.runtimeSkillsCatalog()
                guard gatewayCatalogRequestID == requestID, !Task.isCancelled else { return }
                gatewayCatalog = catalog
            } catch {
                guard gatewayCatalogRequestID == requestID, !Task.isCancelled else { return }
                gatewayCatalog = nil
                gatewayCatalogError = error.localizedDescription
            }
            guard gatewayCatalogRequestID == requestID, !Task.isCancelled else { return }
            isLoadingGatewayCatalog = false
        }
    }

    private func settingsSummaryRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label).fontWeight(.semibold)
            Spacer()
            Text(value).multilineTextAlignment(.trailing).foregroundStyle(.hermesSecondaryText).textSelection(.enabled)
        }
        .font(.subheadline)
    }
}

enum HermesSkillsFallbackPathPolicy {
    static func settings(selectedProfileName: String, authenticatedProfiles: [HermesCompanionProfileInfo], baseSettings: HermesCompanionSettings) -> HermesCompanionSettings? {
        let selected = selectedProfileName
        let matches = authenticatedProfiles.filter { $0.name == selected }
        guard !selected.isEmpty,
              matches.count == 1, let profile = matches.first,
              !profile.path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        var scoped = baseSettings
        scoped.hermesWorkspacePath = profile.path
        return scoped
    }
}
