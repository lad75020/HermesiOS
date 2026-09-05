import Foundation
import Observation

/// A popover-owned editing session. Catalog reads never commit workspace/session settings.
@MainActor
@Observable
final class HermesTUIPhoneInferenceDraft {
    typealias ModelLoader = @MainActor (String) async throws -> [HermesTUIModelOption]

    var draft = HermesTUIInferenceSelection()
    private(set) var modelOptions: [HermesTUIModelOption] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    @ObservationIgnored private var requestID = UUID()
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var profileOptions: () -> [HermesTUIProfileOption] = { [] }
    @ObservationIgnored private weak var workspace: HermesTUIWorkspace?
    @ObservationIgnored private var explicitlySelectedModel: HermesTUIModelOption?

    var canSave: Bool { !isLoading && errorMessage == nil && selectedModel != nil }
    var selectedModel: HermesTUIModelOption? {
        modelOptions.first { $0.provider == draft.provider && $0.model == draft.model }
    }
    var modelLabel: String {
        if isLoading { return "Loading models…" }
        if errorMessage != nil { return "Models unavailable" }
        if modelOptions.isEmpty { return "No models available" }
        return draft.model.isEmpty ? "Choose a model" : draft.model
    }

    @discardableResult
    func open(workspace: HermesTUIWorkspace, load: @escaping ModelLoader) -> Task<Void, Never> {
        self.workspace = workspace
        explicitlySelectedModel = nil
        draft = workspace.inference
        modelOptions = workspace.modelOptions
        // Profile inventory can finish after opening. Read its defaults only when resolving
        // an empty draft, not by copying late workspace inference over the user's edits.
        profileOptions = { [weak workspace] in workspace?.profileOptions ?? [] }
        return reload(load: load)
    }

    @discardableResult
    func selectProfile(_ profile: HermesTUIProfileOption, load: @escaping ModelLoader) -> Task<Void, Never> {
        explicitlySelectedModel = nil
        draft = HermesTUIInferenceSelection(profile: profile.name, provider: profile.provider, model: profile.model)
        modelOptions = []
        return reload(load: load)
    }

    @discardableResult
    func reload(load: @escaping ModelLoader) -> Task<Void, Never> {
        loadTask?.cancel()
        let id = UUID()
        requestID = id
        let profile = draft.profile
        isLoading = true
        errorMessage = nil
        let task = Task { [weak self] in
            do {
                let options = try await load(profile)
                guard let self, self.requestID == id, self.draft.profile == profile, !Task.isCancelled else { return }
                self.modelOptions = options
                self.resolveSelection(options: options)
                self.isLoading = false
                self.loadTask = nil
            } catch {
                guard let self, self.requestID == id, self.draft.profile == profile, !Task.isCancelled else { return }
                self.modelOptions = []
                // Do not surface raw transport/provider diagnostics (or a stale global error).
                self.errorMessage = "Could not load models. Check the connection and retry."
                self.isLoading = false
                self.loadTask = nil
            }
        }
        loadTask = task
        return task
    }

    func dismiss() {
        // A model tap is an explicit choice, unlike a catalog-resolved default. Retain
        // that choice even if the connection drops before tap-away; the next prompt
        // reads workspace.inference. Never mutate inference during an active turn.
        if let option = explicitlySelectedModel,
           option.provider == draft.provider, option.model == draft.model {
            commit(option: option)
        }
        explicitlySelectedModel = nil
        workspace = nil
        requestID = UUID()
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
        profileOptions = { [] }
    }

    func selectModel(_ option: HermesTUIModelOption) {
        guard workspace?.store.isStreaming != true, !isLoading,
              modelOptions.contains(option) else { return }
        explicitlySelectedModel = option
        draft.provider = option.provider
        draft.model = option.model
        if !option.supportsReasoning { draft.reasoningEffort = "none" }
        if !option.supportsFast { draft.fast = false }
    }

    @discardableResult
    func save() -> Bool {
        guard canSave, let option = selectedModel,
              let workspace, workspace.store.isConnected, !workspace.store.isStreaming else { return false }
        commit(option: option)
        explicitlySelectedModel = nil
        return true
    }

    private func commit(option: HermesTUIModelOption) {
        guard let workspace, !workspace.store.isStreaming else { return }
        if !option.supportsReasoning { draft.reasoningEffort = "none" }
        if !option.supportsFast { draft.fast = false }
        let didChange = workspace.inference != draft
        workspace.modelOptionsRequestID = UUID()
        workspace.inference = draft
        // A failed/late refresh must not erase the explicitly chosen model's metadata.
        workspace.modelOptions = modelOptions.contains(option) ? modelOptions : [option]
        if didChange && workspace.store.isConnected {
            workspace.store.createSession(inference: draft)
        }
    }

    private func resolveSelection(options: [HermesTUIModelOption]) {
        if draft.model.isEmpty {
            let profile = profileOptions().first { $0.name == draft.profile }
            let preferred = options.first { $0.provider == profile?.provider && $0.model == profile?.model }
                ?? options.first { $0.model == profile?.model }
                ?? options.first
            if let preferred {
                draft.provider = preferred.provider
                draft.model = preferred.model
            }
        } else if draft.provider.isEmpty, let matching = options.first(where: { $0.model == draft.model }) {
            draft.provider = matching.provider
        }
        if let selectedModel {
            if !selectedModel.supportsReasoning { draft.reasoningEffort = "none" }
            if !selectedModel.supportsFast { draft.fast = false }
        }
    }
}
