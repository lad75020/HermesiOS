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
    let authenticatedProfiles: [HermesCompanionProfileInfo]
    let gatewayProfilePath: String?
    let tuiGatewayStore: HermesTUIGatewayStore
    let apiSettings: HermesAPISettings
    let dashboardURLString: String
    let runtimeProfileName: String
    @State private var searchQuery = ""
    @State private var tuiToolsets: [HermesTUIRuntimeToolset] = []
    @State private var tuiErrorMessage = ""
    @State private var isLoadingTUIToolsets = false
    @State private var isMutatingTUIToolsets = false
    @State private var offerCompanionFallback = false
    @State private var companionFallbackRuntime = HermesCompanionRuntimeSession()
    @State private var companionFallbackScopeIdentity = ""
    @State private var hasScopeMismatch = false
    @State private var mutationTask: Task<Void, Never>?

    private var visibleCompanionToolsets: [HermesCompanionToolsetInfo] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard query.isEmpty == false else { return companionFallbackRuntime.hermesToolsets }
        return companionFallbackRuntime.hermesToolsets.filter { $0.label.lowercased().contains(query) || $0.description.lowercased().contains(query) || $0.key.lowercased().contains(query) }
    }

    private var visibleTUIToolsets: [HermesTUIRuntimeToolset] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard query.isEmpty == false else { return tuiToolsets }
        return tuiToolsets.filter { $0.name.lowercased().contains(query) || $0.description.lowercased().contains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if offerCompanionFallback {
                companionToolsets
            } else {
                tuiGatewayToolsets
            }
        }
        .task(id: toolsetLoadID) {
            offerCompanionFallback = false
            await refreshTUIToolsets()
        }
        .onDisappear { mutationTask?.cancel() }
    }

    private var toolsetLoadID: String {
        runtimeProfileName
    }

    private var selectedAuthenticatedProfile: HermesCompanionProfileInfo? {
        let matches = authenticatedProfiles.filter { $0.name == runtimeProfileName }
        guard matches.count == 1, matches[0].path.isEmpty == false,
              authenticatedProfiles.filter({ $0.path == matches[0].path }).count == 1,
              matches[0].path == gatewayProfilePath else { return nil }
        return matches[0]
    }

    private var fallbackSettings: HermesCompanionSettings? {
        guard let profile = selectedAuthenticatedProfile,
              companionEnrollment.identityState.isEnrolled,
              companionEnrollment.identityState.matches(settings: companionSettings) else { return nil }
        var settings = companionSettings
        // The inventory path is opaque remote data. Do not resolve, expand, or normalize it on iOS.
        settings.hermesWorkspacePath = profile.path
        return settings
    }

    private var tuiGatewayToolsets: some View {
        HermesSectionCard("Hermes Toolsets") {
            VStack(alignment: .leading, spacing: 14) {
                Label("TUI Gateway", systemImage: "terminal")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.igOnlineGreen)
                Text("Gateway controls are enabled only after its launch home exactly matches the selected path in the authenticated gateway profile catalog. Companion is not required.")
                    .font(.subheadline)
                    .foregroundStyle(.hermesSecondaryText)

                if tuiErrorMessage.isEmpty == false {
                    Text(tuiErrorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.igDestructive)
                }

                if isLoadingTUIToolsets == false, tuiToolsets.isEmpty, hasScopeMismatch {
                    Button("Use authenticated Companion fallback") {
                        activateCompanionFallback()
                    }
                    .hermesGlassButton()
                    .disabled(fallbackSettings == nil || companionEnrollment.identityState.isEnrolled == false)
                    Text(fallbackSettings == nil
                         ? "Fallback is blocked: the authenticated Companion inventory has no unique exact path for this selected profile."
                         : "Fallback stays scoped to the exact authenticated profile path.")
                        .font(.caption)
                        .foregroundStyle(.hermesSecondaryText)
                }

                TextField("Search tools", text: $searchQuery)
                    .hermesRuntimeInput()
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button("Reload gateway toolsets") {
                    mutationTask = Task { await refreshTUIToolsets() }
                }
                .disabled(isLoadingTUIToolsets || isMutatingTUIToolsets)

                if isLoadingTUIToolsets || isMutatingTUIToolsets {
                    ProgressView("Loading TUI Gateway toolsets")
                } else if tuiToolsets.isEmpty {
                    ContentUnavailableView(
                        "No TUI Gateway Toolsets",
                        systemImage: "wrench.and.screwdriver",
                        description: Text("Reconnect to refresh the active gateway runtime."))
                } else {
                    ForEach(visibleTUIToolsets) { toolset in
                        tuiToolsetRow(toolset)
                    }
                }
            }
        }
    }

    private var companionToolsets: some View {
        HermesSectionCard("Hermes Toolsets") {
            VStack(alignment: .leading, spacing: 14) {
                Label("Host Companion fallback", systemImage: "laptopcomputer")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.igGradOrange)
                Text("This fallback was explicitly selected after a proven Gateway launch-scope mismatch.")
                    .font(.subheadline)
                    .foregroundStyle(.hermesSecondaryText)

                if !companionFallbackRuntime.lastErrorMessage.isEmpty {
                    Text(companionFallbackRuntime.lastErrorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.igDestructive)
                }

                TextField("Search tools", text: $searchQuery)
                    .hermesRuntimeInput()
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                if companionFallbackRuntime.hermesToolsets.isEmpty {
                    Text("No toolsets were returned for this Host Companion fallback scope.")
                        .font(.subheadline)
                        .foregroundStyle(.hermesSecondaryText)
                } else {
                    ForEach(visibleCompanionToolsets) { toolset in
                        HermesToolsetToggleRow(
                            toolset: toolset,
                            isEnabled: Binding(
                                get: {
                                    companionFallbackRuntime.hermesToolsets.first(where: { $0.key == toolset.key })?.enabled ?? toolset.enabled
                                },
                                set: { isEnabled in
                                    guard let settings = fallbackSettings else { return }
                                    companionFallbackRuntime.setHermesToolsetEnabled(
                                        key: toolset.key,
                                        enabled: isEnabled,
                                        settings: settings,
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

    private func tuiToolsetRow(_ toolset: HermesTUIRuntimeToolset) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(toolset.name)
                        .font(.headline)
                    Text(toolset.enabled ? "On" : "Off")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(toolset.enabled ? .igOnlineGreen : .secondary)
                }
                Text(toolset.description)
                    .font(.subheadline)
                    .foregroundStyle(.hermesSecondaryText)
                Text("\(toolset.toolCount) tools")
                    .font(.caption)
                    .foregroundStyle(.hermesSecondaryText)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: Binding(
                get: { tuiToolsets.first(where: { $0.name == toolset.name })?.enabled ?? toolset.enabled },
                set: { setTUIToolsetEnabled(toolset.name, enabled: $0) }
            ))
            .labelsHidden()
            .disabled(isLoadingTUIToolsets || isMutatingTUIToolsets)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hermesLiquidGlass(cornerRadius: 18, tint: toolset.enabled ? .igOnlineGreen.opacity(0.06) : .white.opacity(0.03))
    }

    private func refreshTUIToolsets() async {
        isLoadingTUIToolsets = true
        tuiErrorMessage = ""
        hasScopeMismatch = false
        tuiToolsets = []
        defer { isLoadingTUIToolsets = false }
        do {
            guard let path = gatewayProfilePath, !path.isEmpty else {
                throw HermesTUIGatewayError.requestFailed("Gateway toolset controls are blocked until the authenticated gateway profile catalog resolves the selected path.")
            }
            try await tuiGatewayStore.connectForRuntime(dashboardBaseURL: dashboardURLString, apiSettings: apiSettings)
            let toolsets = try await tuiGatewayStore.runtimeToolsets(profileName: runtimeProfileName, authenticatedProfilePath: path)
            try Task.checkCancellation()
            tuiToolsets = toolsets
        } catch {
            guard !Task.isCancelled else { return }
            tuiToolsets = []
            if case HermesTUIGatewayError.runtimeScopeMismatch = error { hasScopeMismatch = true }
            tuiErrorMessage = error.localizedDescription
        }
    }

    private func setTUIToolsetEnabled(_ name: String, enabled: Bool) {
        guard !isLoadingTUIToolsets, !isMutatingTUIToolsets, let path = gatewayProfilePath else { return }
        isMutatingTUIToolsets = true
        mutationTask = Task {
            defer { isMutatingTUIToolsets = false }
            do {
                tuiErrorMessage = ""
                try Task.checkCancellation()
                try await tuiGatewayStore.connectForRuntime(dashboardBaseURL: dashboardURLString, apiSettings: apiSettings)
                let toolsets = try await tuiGatewayStore.setRuntimeToolsetEnabled(
                    name: name,
                    enabled: enabled,
                    profileName: runtimeProfileName,
                    authenticatedProfilePath: path
                )
                try Task.checkCancellation()
                tuiToolsets = toolsets
            } catch {
                guard !Task.isCancelled else { return }
                tuiToolsets = []
                if case HermesTUIGatewayError.runtimeScopeMismatch = error { hasScopeMismatch = true }
                tuiErrorMessage = error.localizedDescription
            }
        }
    }

    private func activateCompanionFallback() {
        guard let settings = fallbackSettings,
              companionEnrollment.identityState.isEnrolled else { return }
        let identity = "\(runtimeProfileName)|\(settings.hermesWorkspacePath)|\(companionEnrollment.identityState.deviceID)"
        if companionFallbackScopeIdentity != identity {
            companionFallbackRuntime = HermesCompanionRuntimeSession()
            companionFallbackScopeIdentity = identity
        }
        offerCompanionFallback = true
        companionFallbackRuntime.refreshHermesToolsets(settings: settings, identityState: companionEnrollment.identityState)
    }
}
