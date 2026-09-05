import Observation
import SwiftUI

/// Scheduled-job summaries and supported actions go straight to the TUI Gateway.
/// The Companion editor is explicit and retains the full, non-truncated job data.
struct HermesGatewaySchedulesPanel: View {
    let gatewayStore: HermesTUIGatewayStore
    let apiSettings: HermesAPISettings
    let dashboardURL: String
    let profileName: String
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    let authenticatedProfiles: [HermesCompanionProfileInfo]

    @State private var client: HermesTUICronClient
    @State private var operation: Task<Void, Never>?
    @State private var isConnecting = false
    @State private var connectionError = ""
    @State private var deleteCandidate: HermesTUICronJob?
    @State private var showFallback = false
    @State private var showCreateForm = false
    @State private var fallbackRuntime = HermesCompanionRuntimeSession()

    init(gatewayStore: HermesTUIGatewayStore, apiSettings: HermesAPISettings, dashboardURL: String, profileName: String, companionSettings: HermesCompanionSettings, companionEnrollment: HermesCompanionEnrollmentSession, authenticatedProfiles: [HermesCompanionProfileInfo]) {
        self.gatewayStore = gatewayStore
        self.apiSettings = apiSettings
        self.dashboardURL = dashboardURL
        self.profileName = profileName
        self.companionSettings = companionSettings
        self.companionEnrollment = companionEnrollment
        self.authenticatedProfiles = authenticatedProfiles
        _client = State(initialValue: HermesTUICronClient(
            request: { try await gatewayStore.runtimeCronRequest(params: $0) },
            generation: { gatewayStore.runtimeConnectionVersion }
        ))
    }

    private var isBusy: Bool { isConnecting || client.isBusy || operation != nil }
    private var canMutate: Bool { client.hasLoaded && connectionError.isEmpty && gatewayStore.isConnected && !isBusy }

    private var fallbackSettings: HermesCompanionSettings? {
        let identity = companionEnrollment.identityState
        let matches = authenticatedProfiles.filter { $0.name == profileName }
        guard identity.isEnrolled, identity.matches(settings: companionSettings),
              matches.count == 1, !matches[0].path.isEmpty else { return nil }
        var scoped = companionSettings
        scoped.hermesWorkspacePath = matches[0].path
        return scoped
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HermesSectionCard("Scheduled Jobs") {
                VStack(alignment: .leading, spacing: 12) {
                    Label("TUI Gateway", systemImage: "terminal")
                        .font(.headline)
                    Text("Create, list, pause, resume, and delete jobs in the selected profile. Companion is not required for these operations.")
                        .font(.subheadline)
                        .foregroundStyle(.hermesSecondaryText)
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        operation = Task { await refresh(); operation = nil }
                    }
                    .hermesGlassProminentButton()
                    .disabled(isBusy)
                    Button("New Task", systemImage: "plus") { showCreateForm = true }
                        .hermesGlassButton()
                        .disabled(!canMutate)
                    if isBusy { ProgressView("Updating schedules") }
                    if !connectionError.isEmpty {
                        Text(connectionError).foregroundStyle(.igDestructive)
                    }
                    if !client.errorMessage.isEmpty {
                        Text(client.errorMessage).foregroundStyle(.igDestructive)
                    }
                    if !client.warning.isEmpty {
                        Text(client.warning).foregroundStyle(.igGradOrange)
                    }
                    if client.hasLoaded && connectionError.isEmpty {
                        Text("\(client.jobs.count) jobs · \(client.jobs.filter { $0.state == "scheduled" }.count) scheduled · \(client.jobs.filter { $0.state == "paused" }.count) paused")
                            .font(.caption)
                    } else if !client.jobs.isEmpty {
                        Text("Previously loaded jobs — refresh before changing them.")
                            .font(.caption)
                            .foregroundStyle(.hermesSecondaryText)
                    }
                }
            }

            if client.hasLoaded && client.jobs.isEmpty && connectionError.isEmpty {
                ContentUnavailableView("No Scheduled Jobs", systemImage: "calendar", description: Text("The selected profile has no scheduled jobs, including paused jobs."))
            } else {
                ForEach(client.jobs) { job in jobCard(job) }
            }

            HermesSectionCard("Additional Schedule Operations") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Model/provider overrides during creation, full editing, and Run Now are not provided by the existing cron.manage RPC. Use Companion for these operations.")
                        .font(.caption)
                        .foregroundStyle(.hermesSecondaryText)
                    Button("Open Companion advanced controls", systemImage: "laptopcomputer") {
                        fallbackRuntime = HermesCompanionRuntimeSession()
                        showFallback = true
                    }
                    .hermesGlassButton()
                    .disabled(isBusy || fallbackSettings == nil)
                    if fallbackSettings == nil {
                        Text("Companion fallback requires enrollment and a resolved selected-profile path.")
                            .font(.caption)
                            .foregroundStyle(.hermesSecondaryText)
                    }
                }
            }
        }
        .task { await refresh() }
        .onDisappear { operation?.cancel() }
        .confirmationDialog("Delete scheduled task?", isPresented: Binding(get: { deleteCandidate != nil }, set: { if !$0 { deleteCandidate = nil } }), titleVisibility: .visible) {
            if let job = deleteCandidate {
                Button("Delete", role: .destructive) {
                    deleteCandidate = nil
                    mutate(.remove, job: job)
                }
            }
            Button("Cancel", role: .cancel) { deleteCandidate = nil }
        } message: {
            Text("Remove \(deleteCandidate?.name ?? "this job") from profile \(profileName)?")
        }
        .sheet(isPresented: $showCreateForm) {
            HermesGatewayScheduleCreationForm(profileName: profileName, submit: create)
        }
        .sheet(isPresented: $showFallback, onDismiss: {
            operation = Task { await refresh(); operation = nil }
        }) {
            NavigationStack {
                if let settings = fallbackSettings {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Host Companion fallback", systemImage: "laptopcomputer")
                            HermesSchedulesPanel(companionSettings: settings, companionEnrollment: companionEnrollment, companionRuntime: fallbackRuntime, gatewayManagedControls: true)
                        }
                        .padding()
                    }
                    .navigationTitle("Companion Schedules")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { showFallback = false } } }
                }
            }
        }
    }

    private func jobCard(_ job: HermesTUICronJob) -> some View {
        HermesSectionCard(job.name) {
            VStack(alignment: .leading, spacing: 10) {
                Text(job.state).font(.caption.weight(.semibold))
                Text(job.schedule)
                Text(job.promptPreview).font(.subheadline).textSelection(.enabled)
                Text("Prompt preview only; full editing is available through Companion.")
                    .font(.caption2).foregroundStyle(.hermesSecondaryText)
                LabeledContent("Delivery", value: job.deliver)
                LabeledContent("Repeat", value: job.repeatDescription)
                if let next = job.nextRunAt { LabeledContent("Next run", value: next) }
                if let last = job.lastRunAt { LabeledContent("Last run", value: last) }
                if let model = job.model, !model.isEmpty { LabeledContent("Model", value: model) }
                if let provider = job.provider, !provider.isEmpty { LabeledContent("Provider", value: provider) }
                HStack {
                    if job.enabled && job.state != "completed" && job.state != "paused" {
                        Button("Pause", systemImage: "pause.fill") { mutate(.pause, job: job) }
                            .hermesGlassButton()
                    } else if job.state == "paused" {
                        Button("Resume", systemImage: "play.fill") { mutate(.resume, job: job) }
                            .hermesGlassButton()
                    }
                    Spacer()
                    Button("Delete", systemImage: "trash", role: .destructive) { deleteCandidate = job }
                        .hermesGlassButton()
                }
                .disabled(!canMutate)
            }
        }
    }

    private func refresh() async {
        isConnecting = true
        connectionError = ""
        defer { isConnecting = false }
        do {
            try await gatewayStore.connectForRuntime(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
            try Task.checkCancellation()
            await client.load(profile: profileName)
        } catch {
            guard !Task.isCancelled else { return }
            connectionError = error.localizedDescription
        }
    }

    private func create(_ draft: HermesTUICronDraft) async -> String? {
        guard !isBusy else { return "Another scheduled-jobs operation is in progress." }
        isConnecting = true
        connectionError = ""
        defer { isConnecting = false }
        do {
            try await gatewayStore.connectForRuntime(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
            try Task.checkCancellation()
            let created = await client.create(draft: draft, profile: profileName)
            return created ? nil : client.errorMessage
        } catch {
            return error.localizedDescription
        }
    }

    private func mutate(_ action: HermesTUICronAction, job: HermesTUICronJob) {
        guard canMutate else { return }
        operation = Task {
            defer { operation = nil }
            do {
                try await gatewayStore.connectForRuntime(dashboardBaseURL: dashboardURL, apiSettings: apiSettings)
                try Task.checkCancellation()
                await client.mutate(action: action, jobID: job.id, profile: profileName)
            } catch {
                guard !Task.isCancelled else { return }
                connectionError = error.localizedDescription
            }
        }
    }
}
