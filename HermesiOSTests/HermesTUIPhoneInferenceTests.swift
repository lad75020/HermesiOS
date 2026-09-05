import XCTest
@testable import HermesiOS

@MainActor
final class HermesTUIPhoneInferenceTests: XCTestCase {
    private let option = HermesTUIModelOption(provider: "test", providerName: "Test", model: "default-model", supportsReasoning: true, supportsFast: true)

    func testChosenModelSurvivesCloseWithoutCheckmarkAndReopen() async {
        let workspace = HermesTUIWorkspace(number: 1)
        workspace.inference = .init(provider: option.provider, model: option.model)
        let replacement = HermesTUIModelOption(provider: "other", providerName: "Other", model: "model-B", supportsReasoning: false, supportsFast: false)
        let state = HermesTUIPhoneInferenceDraft()
        await state.open(workspace: workspace) { _ in [self.option, replacement] }.value
        state.selectModel(replacement)
        state.dismiss()
        XCTAssertEqual(workspace.inference.model, replacement.model)
        XCTAssertEqual(workspace.inference.provider, replacement.provider)
        await state.open(workspace: workspace) { _ in [self.option, replacement] }.value
        XCTAssertEqual(state.selectedModel, replacement)
    }

    func testCloseAndExplicitSaveSubmitChosenProviderAndModel() async {
        for explicitSave in [false, true] {
            let workspace = HermesTUIWorkspace(number: 1)
            workspace.inference = .init(provider: option.provider, model: option.model)
            workspace.store.isConnected = true
            workspace.store.sessionID = "existing-session"
            let replacement = HermesTUIModelOption(provider: "other", providerName: "Other", model: "model-B", supportsReasoning: false, supportsFast: false)
            let sessionCreated = expectation(description: "Chosen inference creates one session")
            sessionCreated.assertForOverFulfill = true
            let submitted = expectation(description: "Real prompt.submit uses chosen inference")
            var methods: [String] = []
            workspace.store.requestOverride = { method, params in
                methods.append(method)
                if method == "session.create" || method == "prompt.submit" {
                    XCTAssertEqual(params["model"], .string(replacement.model))
                    XCTAssertEqual(params["provider"], .string(replacement.provider))
                    XCTAssertEqual(params["profile"], .string("default"))
                }
                if method == "session.create" {
                    sessionCreated.fulfill()
                    return .object(["session_id": .string("chosen-session")])
                }
                if method == "prompt.submit" { submitted.fulfill() }
                return .object([:])
            }
            let state = HermesTUIPhoneInferenceDraft()
            await state.open(workspace: workspace) { _ in [self.option, replacement] }.value
            XCTAssertTrue(methods.isEmpty, "Opening/catalog resolution must not create a session")
            state.selectModel(replacement)
            if explicitSave { XCTAssertTrue(state.save()) }
            state.dismiss()
            await fulfillment(of: [sessionCreated], timeout: 2)
            await state.open(workspace: workspace) { _ in [self.option, replacement] }.value
            XCTAssertEqual(state.selectedModel, replacement)
            state.dismiss() // Reopening/closing without choosing must not create another session.
            workspace.store.submitPrompt("test prompt", inference: workspace.inference)
            await fulfillment(of: [submitted], timeout: 2)
            XCTAssertEqual(methods.filter { $0 == "session.create" }.count, 1)
        }
    }

    func testCloseAfterCatalogResolutionDoesNotCommitUnselectedDefault() async {
        let workspace = HermesTUIWorkspace(number: 1)
        workspace.store.isConnected = true
        var requests = 0
        workspace.store.requestOverride = { _, _ in requests += 1; return .object([:]) }
        let original = workspace.inference
        let state = HermesTUIPhoneInferenceDraft()
        await state.open(workspace: workspace) { _ in [self.option] }.value
        state.dismiss()
        XCTAssertEqual(workspace.inference, original)
        XCTAssertTrue(workspace.modelOptions.isEmpty)
        XCTAssertTrue(workspace.store.sessionID.isEmpty)
        await Task.yield()
        XCTAssertEqual(requests, 0)
    }

    func testChosenModelSurvivesDisconnectAndLateRefreshFailure() async {
        let workspace = HermesTUIWorkspace(number: 1)
        let state = HermesTUIPhoneInferenceDraft()
        await state.open(workspace: workspace) { _ in [self.option] }.value
        state.selectModel(option)
        let loader = ControlledModelLoader()
        let late = state.reload(load: loader.load)
        await loader.waitForRequest(1)
        workspace.store.disconnect()
        state.dismiss()
        loader.fail(0)
        await late.value
        XCTAssertEqual(workspace.inference.model, option.model)
        XCTAssertEqual(workspace.modelOptions, [option])
        XCTAssertTrue(workspace.store.sessionID.isEmpty)
        XCTAssertNil(state.errorMessage)
    }

    func testChosenModelSurvivesLateWorkspaceDefaultCatalog() async {
        let workspace = HermesTUIWorkspace(number: 1)
        let loader = ControlledModelLoader()
        let late = Task { await workspace.store.loadModelOptions(into: workspace, selectProfileDefault: true, load: loader.load) }
        await loader.waitForRequest(1)
        let state = HermesTUIPhoneInferenceDraft()
        await state.open(workspace: workspace) { _ in [self.option] }.value
        state.selectModel(option)
        state.dismiss()
        loader.succeed(0, with: [])
        let applied = await late.value
        XCTAssertFalse(applied)
        XCTAssertEqual(workspace.inference.model, option.model)
        XCTAssertEqual(workspace.modelOptions, [option])
    }

    func testProfileSwitchDoesNotCommitPreviouslyChosenModelOrNewDefaultOnClose() async {
        let workspace = HermesTUIWorkspace(number: 1)
        let original = workspace.inference
        let state = HermesTUIPhoneInferenceDraft()
        await state.open(workspace: workspace) { _ in [self.option] }.value
        state.selectModel(option)
        await state.selectProfile(.init(name: "other", displayName: "Other", provider: option.provider, model: option.model)) { _ in [self.option] }.value
        state.dismiss()
        XCTAssertEqual(workspace.inference, original)
    }

    func testSaveRejectsModelAbsentFromCatalog() async {
        let workspace = HermesTUIWorkspace(number: 1)
        workspace.store.isConnected = true
        workspace.inference = .init(provider: "missing", model: "not-in-catalog")
        let original = workspace.inference
        let state = HermesTUIPhoneInferenceDraft()
        await state.open(workspace: workspace) { _ in [self.option] }.value
        XCTAssertFalse(state.canSave)
        XCTAssertFalse(state.save())
        state.dismiss()
        XCTAssertEqual(workspace.inference, original)
    }

    func testStreamingPreventsSaveAndCloseCommit() async {
        let workspace = HermesTUIWorkspace(number: 1)
        let original = workspace.inference
        let state = HermesTUIPhoneInferenceDraft()
        await state.open(workspace: workspace) { _ in [self.option] }.value
        state.selectModel(option)
        workspace.store.isConnected = true
        workspace.store.isStreaming = true
        XCTAssertFalse(state.save())
        state.dismiss()
        XCTAssertEqual(workspace.inference, original)
    }

    func testFirstOpenFetchesDefaultProfileWithoutSavingWorkspace() async {
        let workspace = HermesTUIWorkspace(number: 1)
        let original = workspace.inference
        let state = HermesTUIPhoneInferenceDraft()
        var requestedProfiles: [String] = []
        let task = state.open(workspace: workspace) { profile in
            requestedProfiles.append(profile)
            return [self.option]
        }
        XCTAssertTrue(state.isLoading)
        await task.value
        XCTAssertEqual(requestedProfiles, ["default"])
        XCTAssertEqual(state.modelOptions, [option])
        XCTAssertEqual(state.draft.model, option.model)
        XCTAssertFalse(state.isLoading)
        XCTAssertTrue(state.canSave)
        XCTAssertEqual(workspace.inference, original)
        XCTAssertTrue(workspace.modelOptions.isEmpty)
        XCTAssertTrue(workspace.store.sessionID.isEmpty)
    }

    func testDelayedFirstOpenPublishesIntoVisibleDraftAfterWorkspaceInventoryArrives() async {
        let workspace = HermesTUIWorkspace(number: 1)
        let state = HermesTUIPhoneInferenceDraft()
        let loader = ControlledModelLoader()
        let request = state.open(workspace: workspace, load: loader.load)
        await loader.waitForRequest(1)
        XCTAssertEqual(loader.profiles, ["default"])
        XCTAssertTrue(state.modelOptions.isEmpty)
        XCTAssertTrue(state.isLoading)
        XCTAssertFalse(state.canSave)
        // This is the old bug: the initial empty copy did not observe later workspace updates.
        workspace.profileOptions = [.init(name: "default", displayName: "Default", provider: option.provider, model: option.model)]
        workspace.modelOptions = [option]
        workspace.inference.model = "background-workspace-value"
        state.draft.reasoningEffort = "high"
        let other = HermesTUIModelOption(provider: "test", providerName: "Test", model: "alphabetically-first", supportsReasoning: true, supportsFast: true)
        loader.succeed(0, with: [other, option])
        await request.value
        XCTAssertEqual(state.modelOptions, [other, option])
        XCTAssertEqual(state.draft.model, option.model)
        XCTAssertEqual(state.draft.reasoningEffort, "high")
        XCTAssertFalse(state.isLoading)
        XCTAssertTrue(state.canSave)
        XCTAssertEqual(workspace.inference.model, "background-workspace-value")
    }

    func testProfileSwitchRejectsLatePreviousProfileCompletion() async {
        let workspace = HermesTUIWorkspace(number: 1)
        let state = HermesTUIPhoneInferenceDraft()
        let loader = ControlledModelLoader()
        let first = state.open(workspace: workspace, load: loader.load)
        await loader.waitForRequest(1)
        let replacement = HermesTUIModelOption(provider: "other", providerName: "Other", model: "other-model", supportsReasoning: false, supportsFast: false)
        let second = state.selectProfile(.init(name: "other", displayName: "Other", provider: replacement.provider, model: replacement.model), load: loader.load)
        await loader.waitForRequest(2)
        XCTAssertTrue(state.modelOptions.isEmpty)
        loader.succeed(1, with: [replacement])
        await second.value
        loader.succeed(0, with: [option]) // Intentionally ignores cancellation.
        await first.value
        XCTAssertEqual(loader.profiles, ["default", "other"])
        XCTAssertEqual(state.draft.profile, "other")
        XCTAssertEqual(state.draft.model, replacement.model)
        XCTAssertEqual(state.modelOptions, [replacement])
        XCTAssertFalse(state.isLoading)
        XCTAssertNil(state.errorMessage)
        XCTAssertEqual(workspace.inference, HermesTUIInferenceSelection())
    }

    func testDismissAndReopenSameProfileRejectsOldFailure() async {
        let workspace = HermesTUIWorkspace(number: 1)
        let state = HermesTUIPhoneInferenceDraft()
        let loader = ControlledModelLoader()
        let first = state.open(workspace: workspace, load: loader.load)
        await loader.waitForRequest(1)
        state.dismiss()
        let second = state.open(workspace: workspace, load: loader.load)
        await loader.waitForRequest(2)
        loader.fail(0)
        await first.value
        XCTAssertTrue(state.isLoading)
        XCTAssertNil(state.errorMessage)
        loader.succeed(1, with: [option])
        await second.value
        XCTAssertEqual(state.modelOptions, [option])
        XCTAssertTrue(state.canSave)
    }

    func testFailureStopsLoadingAndRetryLoadsSameProfile() async {
        let workspace = HermesTUIWorkspace(number: 1)
        let state = HermesTUIPhoneInferenceDraft()
        let loader = ControlledModelLoader()
        let first = state.open(workspace: workspace, load: loader.load)
        await loader.waitForRequest(1)
        loader.fail(0)
        await first.value
        XCTAssertFalse(state.isLoading)
        XCTAssertFalse(state.canSave)
        XCTAssertNotNil(state.errorMessage)
        XCTAssertEqual(state.modelLabel, "Models unavailable")
        let retry = state.reload(load: loader.load)
        await loader.waitForRequest(2)
        XCTAssertNil(state.errorMessage)
        loader.succeed(1, with: [option])
        await retry.value
        XCTAssertEqual(loader.profiles, ["default", "default"])
        XCTAssertTrue(state.canSave)
        XCTAssertEqual(state.modelLabel, option.model)
        XCTAssertTrue(workspace.store.lastErrorMessage.isEmpty)
    }

    func testEmptyCatalogIsNotPermanentLoading() async {
        let state = HermesTUIPhoneInferenceDraft()
        await state.open(workspace: HermesTUIWorkspace(number: 1)) { _ in [] }.value
        XCTAssertFalse(state.isLoading)
        XCTAssertNil(state.errorMessage)
        XCTAssertFalse(state.canSave)
        XCTAssertEqual(state.modelLabel, "No models available")
    }

    func testRefreshPreservesExistingModelAndDraftEdits() async {
        let workspace = HermesTUIWorkspace(number: 1)
        workspace.inference.provider = option.provider
        workspace.inference.model = option.model
        workspace.modelOptions = [option]
        let original = workspace.inference
        let state = HermesTUIPhoneInferenceDraft()
        let loader = ControlledModelLoader()
        let request = state.open(workspace: workspace, load: loader.load)
        await loader.waitForRequest(1)
        state.draft.fast = true
        state.draft.reasoningEffort = "high"
        loader.succeed(0, with: [option])
        await request.value
        XCTAssertEqual(state.draft.model, original.model)
        XCTAssertTrue(state.draft.fast)
        XCTAssertEqual(state.draft.reasoningEffort, "high")
        XCTAssertEqual(workspace.inference, original)
    }

    func testDismissRejectsLateSuccessWithoutSaving() async {
        let workspace = HermesTUIWorkspace(number: 1)
        let state = HermesTUIPhoneInferenceDraft()
        let loader = ControlledModelLoader()
        let request = state.open(workspace: workspace, load: loader.load)
        await loader.waitForRequest(1)
        state.dismiss()
        loader.succeed(0, with: [option])
        await request.value
        XCTAssertFalse(state.isLoading)
        XCTAssertTrue(state.modelOptions.isEmpty)
        XCTAssertEqual(workspace.inference, HermesTUIInferenceSelection())
    }

    func testWorkspaceCatalogCannotOverwriteSavedDraftEvenAfterProfileReturnsToDefault() async {
        let workspace = HermesTUIWorkspace(number: 1)
        let loader = ControlledModelLoader()
        let request = Task { await workspace.store.loadModelOptions(into: workspace, selectProfileDefault: true, load: loader.load) }
        await loader.waitForRequest(1)
        workspace.inference.profile = "other"
        workspace.inference = HermesTUIInferenceSelection()
        workspace.modelOptions = [option]
        loader.succeed(0, with: [])
        let applied = await request.value
        XCTAssertFalse(applied)
        XCTAssertEqual(workspace.modelOptions, [option])
        XCTAssertEqual(workspace.inference, HermesTUIInferenceSelection())
    }

    func testNewestWorkspaceRequestWinsForSameProfile() async {
        let workspace = HermesTUIWorkspace(number: 1)
        let loader = ControlledModelLoader()
        let first = Task { await workspace.store.loadModelOptions(into: workspace, selectProfileDefault: false, load: loader.load) }
        await loader.waitForRequest(1)
        let second = Task { await workspace.store.loadModelOptions(into: workspace, selectProfileDefault: false, load: loader.load) }
        await loader.waitForRequest(2)
        loader.succeed(1, with: [option])
        let secondApplied = await second.value
        XCTAssertTrue(secondApplied)
        loader.fail(0)
        let firstApplied = await first.value
        XCTAssertFalse(firstApplied)
        XCTAssertEqual(workspace.modelOptions, [option])
        XCTAssertTrue(workspace.store.lastErrorMessage.isEmpty)
    }

    func testDisconnectedWorkspaceRejectsDelayedCatalog() async {
        let workspace = HermesTUIWorkspace(number: 1)
        let loader = ControlledModelLoader()
        let request = Task { await workspace.store.loadModelOptions(into: workspace, selectProfileDefault: false, load: loader.load) }
        await loader.waitForRequest(1)
        workspace.store.disconnect()
        loader.succeed(0, with: [option])
        let applied = await request.value
        XCTAssertFalse(applied)
        XCTAssertTrue(workspace.modelOptions.isEmpty)
    }
}

/// Deterministic delayed transport, deliberately completing even cancelled requests.
@MainActor
private final class ControlledModelLoader {
    private(set) var profiles: [String] = []
    private var pending: [Int: CheckedContinuation<[HermesTUIModelOption], Error>] = [:]
    private var waiters: [Int: CheckedContinuation<Void, Never>] = [:]

    func load(_ profile: String) async throws -> [HermesTUIModelOption] {
        try await withCheckedThrowingContinuation { continuation in
            let index = profiles.count
            profiles.append(profile)
            pending[index] = continuation
            waiters.removeValue(forKey: profiles.count)?.resume()
        }
    }

    func waitForRequest(_ count: Int) async {
        if profiles.count >= count { return }
        await withCheckedContinuation { waiters[count] = $0 }
    }

    func succeed(_ index: Int, with options: [HermesTUIModelOption]) {
        pending.removeValue(forKey: index)!.resume(returning: options)
    }

    func fail(_ index: Int) {
        pending.removeValue(forKey: index)!.resume(throwing: URLError(.timedOut))
    }
}
