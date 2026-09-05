import SwiftUI

/// Main model selection uses existing profile RPCs; richer routing remains an explicit fallback.
struct HermesGatewayModelsPanel: View {
    let gatewayStore: HermesTUIGatewayStore
    let apiSettings: HermesAPISettings
    let dashboardURL: String
    let profileName: String
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    let authenticatedProfiles: [HermesCompanionProfileInfo]

    @State private var client: HermesTUIProfileModelClient
    @State private var provider = ""
    @State private var model = ""
    @State private var operation: Task<Void, Never>?
    @State private var connecting = false
    @State private var connectionError = ""
    @State private var showConfirmation = false
    @State private var showFallback = false
    @State private var fallbackRuntime = HermesCompanionRuntimeSession()

    init(gatewayStore: HermesTUIGatewayStore, apiSettings: HermesAPISettings, dashboardURL: String, profileName: String, companionSettings: HermesCompanionSettings, companionEnrollment: HermesCompanionEnrollmentSession, authenticatedProfiles: [HermesCompanionProfileInfo]) {
        self.gatewayStore = gatewayStore
        self.apiSettings = apiSettings
        self.dashboardURL = dashboardURL
        self.profileName = profileName
        self.companionSettings = companionSettings
        self.companionEnrollment = companionEnrollment
        self.authenticatedProfiles = authenticatedProfiles
        _client = State(initialValue: HermesTUIProfileModelClient(
            request: { try await gatewayStore.runtimeProfileModelRequest(method: $0, params: $1) },
            generation: { gatewayStore.runtimeConnectionVersion }
        ))
    }

    private var busy: Bool { connecting || client.isBusy || operation != nil }
    private var fallbackSettings: HermesCompanionSettings? {
        let matches = authenticatedProfiles.filter { $0.name == profileName }
        guard companionEnrollment.identityState.isEnrolled,
              companionEnrollment.identityState.matches(settings: companionSettings),
              matches.count == 1, !matches[0].path.isEmpty else { return nil }
        var settings = companionSettings
        settings.hermesWorkspacePath = matches[0].path
        return settings
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HermesSectionCard("Main Model — TUI Gateway") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Read and save the selected profile's main provider and model without Companion. This does not switch the active profile or modify an existing conversation.")
                        .font(.subheadline).foregroundStyle(.hermesSecondaryText)
                    if let snapshot = client.snapshot {
                        LabeledContent("Current provider", value: snapshot.provider.isEmpty ? "Unset" : snapshot.provider)
                        LabeledContent("Current model", value: snapshot.model.isEmpty ? "Unset" : snapshot.model)
                    }
                    TextField("Provider identifier", text: $provider)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Model identifier", text: $model)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Text("Gateway model selection resets the context-length override. Switching providers also clears the previous model endpoint/key overrides; choosing another model on the same provider preserves them. Use Companion below to configure custom endpoints.")
                        .font(.caption).foregroundStyle(.hermesSecondaryText)
                    HStack {
                        Button("Save Main Model") { save() }
                            .hermesGlassProminentButton()
                            .disabled(busy || client.snapshot == nil || provider.isEmpty || model.isEmpty || !gatewayStore.isConnected)
                        Button("Reload / Reset Draft") { operation = Task { await refresh(); operation = nil } }
                            .hermesGlassButton().disabled(busy)
                    }
                    if busy { ProgressView("Updating main model") }
                    if !connectionError.isEmpty { Text(connectionError).foregroundStyle(.igDestructive) }
                    if !client.errorMessage.isEmpty { Text(client.errorMessage).foregroundStyle(.igDestructive) }
                    if client.saved, client.snapshot?.provider == provider, client.snapshot?.model == model {
                        Label("Saved and verified", systemImage: "checkmark.circle")
                    }
                }
            }
            HermesSectionCard("Additional Model Settings") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("The profile editor RPC does not expose delegation, auxiliary model slots, or custom endpoint editing. These controls remain available through Companion.")
                        .font(.subheadline).foregroundStyle(.hermesSecondaryText)
                    Button("Open Companion model settings", systemImage: "laptopcomputer") {
                        fallbackRuntime = HermesCompanionRuntimeSession()
                        showFallback = true
                    }
                    .hermesGlassButton().disabled(busy || fallbackSettings == nil)
                    if fallbackSettings == nil {
                        Text("Fallback requires Companion enrollment and a resolved selected-profile path.")
                            .font(.caption).foregroundStyle(.hermesSecondaryText)
                    }
                }
            }
        }
        .task { await refresh() }
        .onDisappear { operation?.cancel(); client.cancelConfirmation() }
        .confirmationDialog("Confirm gateway model warning", isPresented: $showConfirmation, titleVisibility: .visible) {
            Button("Confirm and Save") { save(confirmWarning: true) }
            Button("Cancel", role: .cancel) { client.cancelConfirmation() }
        } message: { Text(client.confirmationMessage) }
        .sheet(isPresented: $showFallback, onDismiss: {
            operation = Task { await refresh(); operation = nil }
        }) {
            NavigationStack {
                if let settings = fallbackSettings {
                    ScrollView {
                        HermesModelsPanel(companionSettings: settings, companionEnrollment: companionEnrollment, companionRuntime: fallbackRuntime)
                            .padding()
                    }
                    .navigationTitle("Companion Model Settings")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { showFallback = false } } }
                }
            }
        }
    }

    private func refresh() async {
        connecting = true
        connectionError = ""
        defer { connecting = false }
        do {
            try await gatewayStore.connectForRuntime(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
            try Task.checkCancellation()
            await client.load(profile: profileName)
            guard !Task.isCancelled, let snapshot = client.snapshot else { return }
            provider = snapshot.provider
            model = snapshot.model
        } catch {
            guard !Task.isCancelled else { return }
            connectionError = error.localizedDescription
        }
    }

    private func save(confirmWarning: Bool = false) {
        guard !busy else { return }
        let requestedProvider = provider
        let requestedModel = model
        operation = Task {
            defer { operation = nil }
            do {
                try await gatewayStore.connectForRuntime(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                try Task.checkCancellation()
                connectionError = ""
                await client.save(profile: profileName, provider: requestedProvider, model: requestedModel, confirmWarning: confirmWarning)
                guard !Task.isCancelled else { return }
                showConfirmation = !client.confirmationMessage.isEmpty
            } catch {
                guard !Task.isCancelled else { return }
                connectionError = error.localizedDescription
            }
        }
    }
}
