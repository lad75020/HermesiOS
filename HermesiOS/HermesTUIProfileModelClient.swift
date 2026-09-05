import Observation
import Foundation

struct HermesTUIProfileModel: Equatable {
    let profile: String
    let provider: String
    let model: String

    static func decode(_ value: JSONValue, profile: String) throws -> Self {
        guard case .object(let object) = value, object["name"] == .string(profile),
              case .object(let model)? = object["model"],
              case .string(let provider)? = model["provider"],
              case .string(let name)? = model["default"] else {
            throw HermesTUIGatewayError.requestFailed("Invalid model snapshot for the selected profile.")
        }
        return Self(profile: profile, provider: provider, model: name)
    }
}

/// Uses only the existing profile editor RPCs. No session creation or active-profile switch.
@MainActor @Observable
final class HermesTUIProfileModelClient {
    private(set) var snapshot: HermesTUIProfileModel?
    private(set) var isBusy = false
    private(set) var errorMessage = ""
    private(set) var saved = false
    private(set) var confirmationMessage = ""
    @ObservationIgnored private var pendingConfirmation: (value: HermesTUIProfileModel, generation: UUID)?
    private let request: (String, [String: JSONValue]) async throws -> JSONValue
    private let generation: () -> UUID

    init(request: @escaping (String, [String: JSONValue]) async throws -> JSONValue, generation: @escaping () -> UUID) {
        self.request = request
        self.generation = generation
    }

    func cancelConfirmation() {
        pendingConfirmation = nil
        confirmationMessage = ""
    }

    func load(profile: String) async {
        guard !isBusy else { return }
        isBusy = true
        saved = false
        snapshot = nil
        errorMessage = ""
        cancelConfirmation()
        defer { isBusy = false }
        let version = generation()
        do {
            try validate(profile: profile, version: version)
            snapshot = try await describe(profile: profile, version: version)
        } catch { errorMessage = error.localizedDescription }
    }

    /// A warning can only be acknowledged for the exact draft and connection that received it.
    func save(profile: String, provider: String, model: String, confirmWarning: Bool = false) async {
        guard !isBusy else { return }
        isBusy = true
        saved = false
        errorMessage = ""
        defer { isBusy = false }
        let version = generation()
        let draft = HermesTUIProfileModel(profile: profile, provider: provider, model: model)
        var dispatched = false
        do {
            try validate(profile: profile, version: version)
            guard !provider.isEmpty, !model.isEmpty,
                  provider == provider.trimmingCharacters(in: .whitespacesAndNewlines),
                  model == model.trimmingCharacters(in: .whitespacesAndNewlines) else {
                throw HermesTUIGatewayError.requestFailed("Enter a provider and model without surrounding whitespace.")
            }
            if confirmWarning {
                guard pendingConfirmation?.value == draft, pendingConfirmation?.generation == version else {
                    throw HermesTUIGatewayError.requestFailed("The model confirmation is stale. Save again to request a new warning.")
                }
            }
            cancelConfirmation()
            // Prove the selected profile is readable before dispatching a write.
            snapshot = try await describe(profile: profile, version: version)
            var params: [String: JSONValue] = ["name": .string(profile), "provider": .string(provider), "model": .string(model)]
            params["confirm_expensive_model"] = .bool(confirmWarning)
            try validate(profile: profile, version: version)
            dispatched = true
            let receipt = try await request("profiles.configure", params)
            try validate(profile: profile, version: version)
            guard case .object(let object) = receipt, object["ok"] == .bool(true) else {
                throw HermesTUIGatewayError.requestFailed("The gateway did not acknowledge the model change.")
            }
            if object["confirm_required"] == .bool(true) {
                guard !confirmWarning, case .string(let message)? = object["confirm_message"], !message.isEmpty,
                      case .object(let applied)? = object["applied"], applied.isEmpty else {
                    throw HermesTUIGatewayError.requestFailed("Unexpected model confirmation response.")
                }
                dispatched = false // The existing gateway contract writes nothing when asking for confirmation.
                pendingConfirmation = (draft, version)
                confirmationMessage = message
                return
            }
            guard object["confirm_required"] == nil || object["confirm_required"] == .bool(false),
                  case .object(let applied)? = object["applied"], applied["model"] == .bool(true) else {
                throw HermesTUIGatewayError.requestFailed("The gateway did not apply the model change.")
            }
            let readback = try await describe(profile: profile, version: version)
            snapshot = readback
            guard readback == draft else {
                throw HermesTUIGatewayError.requestFailed("The gateway returned a different provider/model (it may have normalized the selection). Review the current value before saving again.")
            }
            saved = true
        } catch {
            cancelConfirmation()
            errorMessage = error.localizedDescription
            if dispatched {
                errorMessage += " The change may already have been saved. Refresh before retrying; no automatic retry was made."
            }
        }
    }

    private func describe(profile: String, version: UUID) async throws -> HermesTUIProfileModel {
        let result = try await request("profiles.describe", ["name": .string(profile)])
        try validate(profile: profile, version: version)
        return try HermesTUIProfileModel.decode(result, profile: profile)
    }

    private func validate(profile: String, version: UUID) throws {
        guard !profile.isEmpty, profile == profile.trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw HermesTUIGatewayError.requestFailed("An exact selected profile name is required.")
        }
        guard !Task.isCancelled, generation() == version else { throw HermesTUIGatewayError.notConnected }
    }
}
