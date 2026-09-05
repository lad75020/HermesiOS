//
//  HermesAgentConfigView.swift
//  HermesiOS
//
//  Native configuration workspace for the Host Companion runtime APIs.
//

import Observation
import SwiftUI

/// Keeps the layout decision deterministic and independently testable. 720pt leaves
/// enough room for a useful category rail while allowing iPad multitasking to use the
/// same pushed-detail experience as iPhone.
enum HermesRuntimeWorkspaceLayout: Equatable {
    case overview
    case split

    static func forWidth(_ width: CGFloat) -> Self {
        width >= 720 ? .split : .overview
    }
}

extension HermesRuntimePanelKind {
    static let primaryCategories: [Self] = [
        .profiles, .gateway, .tools, .skills, .mcpServers, .providers, .schedules, .models
    ]

    static let secondaryCategories: [Self] = [.companion, .memory, .knowledgeEraser, .observability]

    var title: String {
        switch self {
        case .profiles: "Profiles"
        case .gateway: "Messaging"
        case .tools: "Tools"
        case .skills: "Skills"
        case .mcpServers: "MCP Servers"
        case .providers: "Provider Keys"
        case .schedules: "Scheduled Jobs"
        case .models: "Models"
        case .companion: "Host Companion"
        case .memory: "Memory"
        case .knowledgeEraser: "Knowledge Eraser"
        case .observability: "Observability"
        }
    }

    var systemImage: String {
        switch self {
        case .profiles: "person.crop.rectangle.stack"
        case .gateway: "antenna.radiowaves.left.and.right"
        case .tools: "wrench.and.screwdriver"
        case .skills: "square.stack.3d.up.fill"
        case .mcpServers: "point.3.connected.trianglepath.dotted"
        case .providers: "key.horizontal"
        case .schedules: "calendar.badge.clock"
        case .models: "cpu"
        case .companion: "lock.laptopcomputer"
        case .memory: "brain.head.profile"
        case .knowledgeEraser: "eraser.line.dashed.fill"
        case .observability: "waveform.and.magnifyingglass"
        }
    }
}

struct HermesAgentConfigView: View {
    @Binding var agentConfiguration: HermesAgentConfiguration
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession
    let tuiGatewayStore: HermesTUIGatewayStore
    let apiSettings: HermesAPISettings
    let dashboardURLString: String

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// This is deliberately local to Agent Runtime. Selecting an edit scope must
    /// never change Hermes' sticky, host-wide active profile.
    @State private var selectedRuntimeProfileName = "default"
    /// Runtime editing is deliberately isolated from the app-wide session that
    /// ContentView kickstarts. Replacing this object on a scope change makes an
    /// old request unable to populate the newly selected profile's UI.
    @State private var scopedCompanionRuntime = HermesCompanionRuntimeSession()
    /// The TUI Gateway is the primary source of the Agent Runtime edit scope.
    /// Host Companion keeps its own profile inventory only for panels that require
    /// the explicit host fallback.
    @State private var runtimeProfiles: [HermesTUIProfileOption] = []
    @State private var isLoadingRuntimeProfiles = false
    @State private var runtimeProfilesError = ""

    private var selectedCategory: HermesRuntimePanelKind {
        agentConfiguration.activeRuntimePanel ?? .profiles
    }

    private var scopedCompanionSettings: HermesCompanionSettings {
        var scoped = companionSettings
        if let profile = companionRuntime.profiles.first(where: { $0.name == selectedRuntimeProfileName }) {
            // `path` comes from the authenticated list_profiles result; never
            // construct a path from user-entered profile text.
            scoped.hermesWorkspacePath = profile.path
        }
        return scoped
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = HermesRuntimeWorkspaceLayout.forWidth(proxy.size.width)
            Group {
                if layout == .split && horizontalSizeClass != .compact {
                    splitWorkspace
                } else {
                    overviewWorkspace
                }
            }
        }
        .background(HermesLiquidGlassCanvas().ignoresSafeArea())
        .navigationTitle("Agent Runtime")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: HermesRuntimePanelKind.self) { category in
            detailPage(for: category)
        }
        .task(id: companionEnrollment.identityState.deviceID) {
            // Resolve authenticated host paths only for panels that fall back to
            // Host Companion. The runtime scope itself comes from TUI Gateway.
            guard companionEnrollment.identityState.isEnrolled else { return }
            companionRuntime.refreshProfiles(settings: companionSettings, identityState: companionEnrollment.identityState)
        }
        .task(id: runtimeProfileLoadKey) {
            await loadRuntimeProfiles()
        }

    }

    private var overviewWorkspace: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                workspaceHeader
                connectionBanner

                Text("Configuration")
                    .font(.title3.weight(.bold))
                    .accessibilityAddTraits(.isHeader)
                categoryLinks(HermesRuntimePanelKind.primaryCategories)

                Text("Connection & Utilities")
                    .font(.title3.weight(.bold))
                    .padding(.top, 8)
                    .accessibilityAddTraits(.isHeader)
                categoryLinks(HermesRuntimePanelKind.secondaryCategories)
            }
            .padding()
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func categoryLinks(_ categories: [HermesRuntimePanelKind]) -> some View {
        LazyVStack(spacing: 10) {
            ForEach(categories) { category in
                NavigationLink(value: category) {
                    categoryRow(category)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens \(category.title) configuration")
            }
        }
    }

    private var splitWorkspace: some View {
        HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    workspaceHeader
                    connectionBanner
                    categoryRailSection("Configuration", categories: HermesRuntimePanelKind.primaryCategories)
                    categoryRailSection("Connection & Utilities", categories: HermesRuntimePanelKind.secondaryCategories)
                }
                .padding()
            }
            .frame(minWidth: 280, idealWidth: 320, maxWidth: 360)
            .background(.thinMaterial)

            Divider()

            detailPage(for: selectedCategory)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func categoryRailSection(_ title: String, categories: [HermesRuntimePanelKind]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.hermesSecondaryText)
                .textCase(.uppercase)
                .padding(.top, 6)
            ForEach(categories) { category in
                Button {
                    select(category)
                } label: {
                    categoryRow(category, compact: true, selected: selectedCategory == category)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(category.title)
                .accessibilityValue(categoryStatus(for: category).accessibilityText)
                .accessibilityHint(selectedCategory == category ? "Current category" : "Shows \(category.title) details")
            }
        }
    }

    private var workspaceHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "server.rack")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.igActionBlue)
                .frame(width: 48, height: 48)
                .hermesLiquidGlass(cornerRadius: 14, tint: .igActionBlue.opacity(0.14))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text("Hermes Agent Runtime")
                    .font(.title2.weight(.bold))
                Text(profileScopeText)
                    .font(.subheadline)
                    .foregroundStyle(.hermesSecondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var runtimeScopePicker: some View {
        if runtimeProfiles.isEmpty == false {
            Picker("Runtime edit scope", selection: $selectedRuntimeProfileName) {
                ForEach(runtimeProfiles) { profile in
                    Text(profile.name == "default" ? "Default workspace" : profile.displayName).tag(profile.name)
                }
            }
            .pickerStyle(.menu)
            .accessibilityHint("Changes only the TUI Gateway edit target; it does not change Hermes' active profile.")
            .onChange(of: selectedRuntimeProfileName) { _, _ in
                scopedCompanionRuntime = HermesCompanionRuntimeSession()
            }
        } else if isLoadingRuntimeProfiles {
            ProgressView("Loading TUI Gateway profiles")
                .controlSize(.small)
        }
    }

    private var connectionBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: tuiGatewayStore.isConnected ? "checkmark.circle.fill" : "terminal.fill")
                .foregroundStyle(tuiGatewayStore.isConnected ? .igOnlineGreen : .igGradOrange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(tuiGatewayConnectionTitle)
                    .font(.subheadline.weight(.semibold))
                Text(tuiGatewayConnectionDetail)
                    .font(.caption)
                    .foregroundStyle(.hermesSecondaryText)
            }
            Spacer(minLength: 8)
            if !tuiGatewayStore.isConnected, !isLoadingRuntimeProfiles {
                Button("Reconnect") {
                    Task { await loadRuntimeProfiles() }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hermesLiquidGlass(cornerRadius: 18, tint: (tuiGatewayStore.isConnected ? Color.igOnlineGreen : Color.igGradOrange).opacity(0.10))
        .accessibilityElement(children: .combine)
    }

    private func categoryRow(_ category: HermesRuntimePanelKind, compact: Bool = false, selected: Bool = false) -> some View {
        let status = categoryStatus(for: category)
        return HStack(spacing: 12) {
            Image(systemName: category.systemImage)
                .font(.title3)
                .foregroundStyle(selected ? .white : .igActionBlue)
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(category.title)
                    .font(.headline)
                    .foregroundStyle(selected ? .white : .primary)
                if !compact {
                    Text(status.summary)
                        .font(.caption)
                        .foregroundStyle(selected ? .white.opacity(0.84) : .hermesSecondaryText)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            Text(status.badge)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(status.hasError ? .igDestructive : (selected ? .white.opacity(0.9) : .hermesSecondaryText))
            if !compact {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(selected ? Color.white.opacity(0.8) : Color.secondary.opacity(0.7))
                    .accessibilityHidden(true)
            }
        }
        .padding(compact ? 11 : 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? Color.igActionBlue : Color.clear)
        .clipShape(.rect(cornerRadius: compact ? 14 : 18))
        .hermesLiquidGlass(cornerRadius: compact ? 14 : 18, tint: selected ? .igActionBlue.opacity(0.9) : .white.opacity(0.05), interactive: true)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(category.title)
        .accessibilityValue(status.accessibilityText)
    }

    private func detailPage(for category: HermesRuntimePanelKind) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                detailHeader(for: category)
                runtimeScopePicker
                detailContent(for: category)
                    .id("runtime-scope-\(selectedRuntimeProfileName)")
            }
            .padding()
            .frame(maxWidth: 960, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .onAppear { select(category) }
        .accessibilityIdentifier("agent-runtime-detail-\(category.rawValue)")
    }

    private func detailHeader(for category: HermesRuntimePanelKind) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(category.title, systemImage: category.systemImage)
                .font(.title2.weight(.bold))
            Text(profileScopeText)
                .font(.caption)
                .foregroundStyle(.hermesSecondaryText)
            let status = categoryStatus(for: category)
            Text(status.loaded ? status.summary : "Not loaded — open the panel to request the current host state.")
                .font(.subheadline)
                .foregroundStyle(status.hasError ? .igDestructive : .hermesSecondaryText)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func detailContent(for category: HermesRuntimePanelKind) -> some View {
        switch category {
        case .skills:
            HermesSkillsPanel(
                agentConfiguration: $agentConfiguration,
                companionSettings: companionSettings,
                companionEnrollment: companionEnrollment,
                tuiGatewayStore: tuiGatewayStore,
                apiSettings: apiSettings,
                dashboardURLString: dashboardURLString,
                selectedProfileName: selectedRuntimeProfileName,
                authenticatedProfiles: companionRuntime.profiles
            )
            .id(HermesToolsScopeIdentity(
                gateway: runtimeProfileLoadKey,
                profileName: selectedRuntimeProfileName,
                gatewayPath: nil,
                companionPath: skillsFallbackPathIdentity,
                settings: companionSettings,
                identity: companionEnrollment.identityState
            ))
        case .companion: HermesCompanionPanel(companionSettings: companionSettings, companionEnrollment: companionEnrollment, companionRuntime: companionRuntime)
        case .profiles: HermesProfilesPanel(companionSettings: companionSettings, companionEnrollment: companionEnrollment, companionRuntime: companionRuntime)
        case .gateway: HermesGatewayPanel(companionSettings: scopedCompanionSettings, companionEnrollment: companionEnrollment, companionRuntime: scopedCompanionRuntime)
        case .tools:
            HermesToolsPanel(
                // Tools owns its fallback scope privately.  Give it the unscoped
                // Companion settings plus the authenticated inventory so it can
                // require an exact selected-profile path before any fallback.
                companionSettings: companionSettings,
                companionEnrollment: companionEnrollment,
                authenticatedProfiles: companionRuntime.profiles,
                gatewayProfilePath: selectedToolsGatewayPath,
                tuiGatewayStore: tuiGatewayStore,
                apiSettings: apiSettings,
                dashboardURLString: dashboardURLString,
                runtimeProfileName: selectedRuntimeProfileName
            )
            .id(HermesToolsScopeIdentity(
                gateway: runtimeProfileLoadKey,
                profileName: selectedRuntimeProfileName,
                gatewayPath: selectedToolsGatewayPath,
                companionPath: companionRuntime.profiles.filter { $0.name == selectedRuntimeProfileName }.map(\.path).sorted().joined(separator: "|"),
                settings: companionSettings,
                identity: companionEnrollment.identityState
            ))
        case .mcpServers:
            HermesMCPServersPanel(
                companionSettings: scopedCompanionSettings,
                companionEnrollment: companionEnrollment,
                companionRuntime: scopedCompanionRuntime,
                tuiGatewayStore: tuiGatewayStore,
                apiSettings: apiSettings,
                dashboardURLString: dashboardURLString,
                selectedRuntimeProfileName: selectedRuntimeProfileName
            )
        case .providers: HermesProvidersPanel(companionSettings: scopedCompanionSettings, companionEnrollment: companionEnrollment, companionRuntime: scopedCompanionRuntime)
        case .models:
            HermesGatewayModelsPanel(gatewayStore: tuiGatewayStore, apiSettings: apiSettings,
                dashboardURL: dashboardURLString, profileName: selectedRuntimeProfileName,
                companionSettings: companionSettings, companionEnrollment: companionEnrollment,
                authenticatedProfiles: companionRuntime.profiles)
            .id(HermesToolsScopeIdentity(gateway: runtimeProfileLoadKey,
                profileName: selectedRuntimeProfileName, gatewayPath: nil,
                companionPath: companionRuntime.profiles.filter { $0.name == selectedRuntimeProfileName }.map(\.path).sorted().joined(separator: "|"),
                settings: companionSettings, identity: companionEnrollment.identityState))
        case .memory: HermesMemoryPanel(companionSettings: scopedCompanionSettings, companionEnrollment: companionEnrollment, companionRuntime: scopedCompanionRuntime)
        case .knowledgeEraser: HermesKnowledgeEraserPanel(companionSettings: scopedCompanionSettings, companionEnrollment: companionEnrollment, companionRuntime: scopedCompanionRuntime)
        case .schedules:
            HermesGatewaySchedulesPanel(
                gatewayStore: tuiGatewayStore,
                apiSettings: apiSettings,
                dashboardURL: dashboardURLString,
                profileName: selectedRuntimeProfileName,
                companionSettings: companionSettings,
                companionEnrollment: companionEnrollment,
                authenticatedProfiles: companionRuntime.profiles
            )
            .id(HermesToolsScopeIdentity(
                gateway: runtimeProfileLoadKey,
                profileName: selectedRuntimeProfileName,
                gatewayPath: nil,
                companionPath: companionRuntime.profiles.filter { $0.name == selectedRuntimeProfileName }.map(\.path).sorted().joined(separator: "|"),
                settings: companionSettings,
                identity: companionEnrollment.identityState
            ))
        case .observability: HermesObservabilityPanel(companionSettings: scopedCompanionSettings, companionEnrollment: companionEnrollment, companionRuntime: scopedCompanionRuntime)
        }
    }

    private var profileScopeText: String {
        guard let profile = runtimeProfiles.first(where: { $0.name == selectedRuntimeProfileName }) else {
            return runtimeProfilesError.isEmpty ? "Loading TUI Gateway profiles for the Runtime edit scope" : runtimeProfilesError
        }
        return "Runtime edit scope: \(profile.name == "default" ? "Default workspace" : profile.displayName)"
    }

    private var tuiGatewayConnectionTitle: String {
        if tuiGatewayStore.isConnected { return "TUI Gateway connected" }
        if isLoadingRuntimeProfiles { return "Connecting to TUI Gateway" }
        return "TUI Gateway unavailable"
    }

    private var tuiGatewayConnectionDetail: String {
        if !runtimeProfilesError.isEmpty { return runtimeProfilesError }
        if tuiGatewayStore.isConnected {
            return "Agent Runtime uses existing TUI Gateway RPCs first. Host Companion is used only where that RPC surface has no equivalent."
        }
        return "Connect the Hermes dashboard and API gateway in Settings, then retry."
    }

    private var runtimeProfileLoadKey: HermesRuntimeConnectionIdentity {
        HermesRuntimeConnectionIdentity(dashboardURL: dashboardURLString, apiSettings: apiSettings)
    }

    private var selectedToolsGatewayPath: String? {
        let matches = runtimeProfiles.filter { $0.name == selectedRuntimeProfileName }
        guard matches.count == 1, !matches[0].path.isEmpty else { return nil }
        return matches[0].path
    }

    private var skillsFallbackPathIdentity: String {
        companionRuntime.profiles.first(where: { $0.name == selectedRuntimeProfileName })?.path ?? "unresolved"
    }

    @MainActor
    private func loadRuntimeProfiles() async {
        isLoadingRuntimeProfiles = true
        runtimeProfilesError = ""
        defer { isLoadingRuntimeProfiles = false }
        do {
            try await tuiGatewayStore.connectForRuntime(
                dashboardBaseURL: dashboardURLString,
                apiSettings: apiSettings
            )
            let profiles = try await tuiGatewayStore.runtimeProfileOptions()
            try Task.checkCancellation()
            runtimeProfiles = profiles
            if !profiles.contains(where: { $0.name == selectedRuntimeProfileName }) {
                selectedRuntimeProfileName = profiles.first?.name ?? "default"
            }
        } catch {
            guard !Task.isCancelled else { return }
            runtimeProfiles = []
            runtimeProfilesError = error.localizedDescription
        }
    }

    private func select(_ category: HermesRuntimePanelKind) {
        agentConfiguration.activeRuntimePanel = category
    }

    private func categoryStatus(for category: HermesRuntimePanelKind) -> HermesRuntimeCategoryStatus {
        if category == .models {
            return .init(summary: "Gateway main model; Companion endpoint, delegation, and auxiliary settings", badge: "Gateway", loaded: false, hasError: false)
        }
        if category == .schedules {
            return .init(summary: "Gateway creation, list, pause, resume, and delete; Companion advanced controls", badge: "Gateway", loaded: false, hasError: false)
        }
        if category == .tools {
            return .init(summary: "Gateway toolsets require a verified profile match; Companion fallback is optional", badge: "Gateway", loaded: false, hasError: false)
        }
        if category == .skills {
            return .init(summary: "Gateway selected-profile inventory; Companion details and toggles", badge: "Gateway", loaded: false, hasError: false)
        }
        guard companionEnrollment.identityState.isEnrolled else { return .init(summary: "Companion not enrolled", badge: "Locked", loaded: false, hasError: false) }
        let runtime = (category == .profiles || category == .companion) ? companionRuntime : scopedCompanionRuntime
        let error = runtime.runtimeSectionError(category.rawValue)
        guard runtime.hasRuntimeSectionLoaded(category.rawValue) else { return .init(summary: error.isEmpty ? "Not loaded" : error, badge: error.isEmpty ? "Not loaded" : "Load failed", loaded: false, hasError: !error.isEmpty) }
        let hasError = !error.isEmpty
        let badge = hasError ? "Error" : "Loaded"
        switch category {
        case .profiles: return .init(summary: "\(companionRuntime.profiles.count) profiles · active \(companionRuntime.activeProfileName)", badge: badge, loaded: true, hasError: hasError)
        case .gateway: return .init(summary: "\(runtime.gatewayPlatformEnabled.values.filter { $0 }.count) of \(runtime.gatewayPlatforms.count) messaging platforms enabled", badge: badge, loaded: true, hasError: hasError)
        case .tools: return .init(summary: "\(runtime.hermesToolsets.filter(\.enabled).count) enabled of \(runtime.hermesToolsets.count)", badge: badge, loaded: true, hasError: hasError)
        case .skills: return .init(summary: "\(runtime.hermesSkills.filter(\.isEnabled).count) enabled of \(runtime.hermesSkills.count)", badge: badge, loaded: true, hasError: hasError)
        case .mcpServers: return .init(summary: "\(runtime.hermesMCPServers.count) configured", badge: badge, loaded: true, hasError: hasError)
        case .providers: return .init(summary: "\(runtime.providerEnv.filter { !$0.value.isEmpty }.count) configured key entries", badge: badge, loaded: true, hasError: hasError)
        case .schedules: return .init(summary: "\(runtime.schedules.filter { $0.state == "active" }.count) active of \(runtime.schedules.count)", badge: badge, loaded: true, hasError: hasError)
        case .models: return .init(summary: "Main, delegation, and \(runtime.auxiliaryModelConfigs.count) auxiliary slots", badge: badge, loaded: true, hasError: hasError)
        case .companion: return .init(summary: companionRuntime.connectionStatus, badge: badge, loaded: true, hasError: hasError)
        case .memory: return .init(summary: "\(runtime.memoryEntries.count) memory entries", badge: badge, loaded: true, hasError: hasError)
        case .knowledgeEraser: return .init(summary: "\(runtime.knowledgeEraserItems.count) candidates", badge: badge, loaded: true, hasError: hasError)
        case .observability: return .init(summary: "\(runtime.observabilityLoadedLineCount) log lines", badge: badge, loaded: true, hasError: hasError)
        }
    }
}

private struct HermesRuntimeCategoryStatus {
    let summary: String
    let badge: String
    let loaded: Bool
    let hasError: Bool

    var accessibilityText: String {
        hasError ? "Loaded with an error. \(summary)" : "\(badge). \(summary)"
    }
}
