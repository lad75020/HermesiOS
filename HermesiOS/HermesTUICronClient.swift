import Foundation
import Observation

struct HermesTUICronJob: Identifiable, Equatable {
    let id: String
    let name: String
    let promptPreview: String
    let schedule: String
    let state: String
    let enabled: Bool
    let deliver: String
    let repeatDescription: String
    let nextRunAt: String?
    let lastRunAt: String?
    let model: String?
    let provider: String?
}

enum HermesTUICronAction: String {
    case pause
    case resume
    case remove
}

struct HermesTUICronDraft: Equatable {
    var name = ""
    var prompt = ""
    var schedule = "0 9 * * *"
    var deliver = "local"
    var repeatLimit = ""
    var continuity = false

    var validationMessage: String? {
        if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "A scheduled job prompt is required."
        }
        if schedule.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "A schedule is required."
        }
        if deliver.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "A delivery target is required."
        }
        guard !repeatLimit.isEmpty else { return nil }
        let isDecimal = repeatLimit.unicodeScalars.allSatisfy { (48...57).contains($0.value) }
        guard isDecimal, Int(repeatLimit) != nil else {
            return "Repeat limit must be a nonnegative whole number."
        }
        return nil
    }
}

/// A structured adapter for the TUI Gateway's profile-scoped cron API.
@MainActor
@Observable
final class HermesTUICronClient {
    typealias Request = @MainActor ([String: JSONValue]) async throws -> JSONValue

    private let request: Request
    private let generation: @MainActor () -> UUID

    private(set) var jobs: [HermesTUICronJob] = []
    private(set) var isBusy = false
    private(set) var errorMessage = ""
    private(set) var warning = ""
    private(set) var hasLoaded = false

    init(
        request: @escaping Request,
        generation: @escaping @MainActor () -> UUID
    ) {
        self.request = request
        self.generation = generation
    }

    func load(profile: String) async {
        guard beginOperation() else { return }
        defer { isBusy = false }
        let operationGeneration = generation()
        do {
            let listing = try await list(profile: profile, generation: operationGeneration)
            try validate(operationGeneration)
            jobs = listing.jobs
            warning = listing.warning
            errorMessage = ""
            hasLoaded = true
        } catch {
            fail(error)
        }
    }

    func mutate(action: HermesTUICronAction, jobID: String, profile: String) async {
        guard beginOperation() else { return }
        defer { isBusy = false }
        let operationGeneration = generation()
        do {
            let preflight = try await list(profile: profile, generation: operationGeneration)
            guard let current = preflight.jobs.first(where: { $0.id == jobID }) else {
                throw CronError("The scheduled job is no longer present in the selected profile.")
            }
            try validateAction(action, job: current)
            try validate(operationGeneration)

            let receipt = try await request([
                "action": .string(action.rawValue),
                "name": .string(jobID),
                "profile": .string(try scopedProfile(profile))
            ])
            try validate(operationGeneration)
            try validateReceipt(receipt, action: action, jobID: jobID)

            let readback = try await list(profile: profile, generation: operationGeneration)
            try validateReadback(readback.jobs, action: action, jobID: jobID)
            try validate(operationGeneration)
            jobs = readback.jobs
            warning = readback.warning
            errorMessage = ""
            hasLoaded = true
        } catch {
            fail(error)
        }
    }

    @discardableResult
    func create(draft: HermesTUICronDraft, profile: String) async -> Bool {
        guard beginOperation() else { return false }
        defer { isBusy = false }
        if let validationMessage = draft.validationMessage {
            fail(CronError(validationMessage))
            return false
        }
        var addDispatched = false
        let operationGeneration = generation()
        do {
            let scopedProfile = try scopedProfile(profile)
            let preflight = try await list(profile: scopedProfile, generation: operationGeneration)
            let preflightIDs = Set(preflight.jobs.map(\.id))
            try validate(operationGeneration)

            var parameters: [String: JSONValue] = [
                "action": .string("add"),
                "name": .string(draft.name.trimmingCharacters(in: .whitespacesAndNewlines)),
                "prompt": .string(draft.prompt),
                "schedule": .string(draft.schedule.trimmingCharacters(in: .whitespacesAndNewlines)),
                "profile": .string(scopedProfile),
                "deliver": .string(draft.deliver.trimmingCharacters(in: .whitespacesAndNewlines)),
                "continuity": .bool(draft.continuity)
            ]
            if !draft.repeatLimit.isEmpty { parameters["repeat"] = .string(draft.repeatLimit) }

            addDispatched = true
            let receipt = try await request(parameters)
            try validate(operationGeneration)
            let created = try validateCreateReceipt(receipt, preflightIDs: preflightIDs)
            let readback = try await list(profile: scopedProfile, generation: operationGeneration)
            guard readback.jobs.contains(where: { $0.id == created.id }) else {
                throw CronError("The newly created scheduled job could not be confirmed from the selected profile.")
            }
            try validate(operationGeneration)
            jobs = readback.jobs
            warning = created.warning.isEmpty ? readback.warning : created.warning
            errorMessage = ""
            hasLoaded = true
            return true
        } catch {
            failCreation(error, addDispatched: addDispatched)
            return false
        }
    }

    private func beginOperation() -> Bool {
        guard !isBusy else {
            errorMessage = "A scheduled-jobs operation is already in progress."
            return false
        }
        isBusy = true
        errorMessage = ""
        return true
    }

    private func fail(_ error: Error) {
        // A failure never turns an existing list into a convincing empty success state.
        hasLoaded = false
        warning = ""
        errorMessage = error is CancellationError
            ? "Scheduled jobs request was cancelled; the displayed jobs may be stale."
            : "Scheduled jobs could not be verified; the displayed jobs may be stale. \(error.localizedDescription)"
    }

    private func failCreation(_ error: Error, addDispatched: Bool) {
        hasLoaded = false
        warning = ""
        if addDispatched {
            errorMessage = "Scheduled-job creation may have succeeded, but could not be verified. Review the refreshed list before resubmitting. \(error.localizedDescription)"
        } else {
            errorMessage = error is CancellationError
                ? "Scheduled-job creation was cancelled before it was sent."
                : "Scheduled-job creation could not be started. \(error.localizedDescription)"
        }
    }

    private func list(profile: String, generation: UUID) async throws -> Listing {
        let profile = try scopedProfile(profile)
        try validate(generation)
        let result = try await request([
            "action": .string("list"),
            "profile": .string(profile),
            "include_disabled": .bool(true)
        ])
        try validate(generation)
        return try decodeListing(result, profile: profile)
    }

    private func validate(_ expectedGeneration: UUID) throws {
        guard !Task.isCancelled else { throw CancellationError() }
        guard generation() == expectedGeneration else {
            throw CronError("The gateway connection changed; scheduled jobs were not updated.")
        }
    }

    private func scopedProfile(_ profile: String) throws -> String {
        guard !profile.isEmpty else {
            throw CronError("A selected profile is required to manage scheduled jobs.")
        }
        return profile
    }

    private func validateAction(_ action: HermesTUICronAction, job: HermesTUICronJob) throws {
        switch action {
        case .pause:
            guard job.enabled, job.state != "completed" else {
                throw CronError("Only an enabled, non-completed scheduled job can be paused.")
            }
        case .resume:
            guard !job.enabled, job.state == "paused" else {
                throw CronError("Only a paused scheduled job can be resumed.")
            }
        case .remove:
            break
        }
    }

    private func validateReceipt(_ result: JSONValue, action: HermesTUICronAction, jobID: String) throws {
        guard case .object(let payload) = result, payload["success"] == .bool(true) else {
            throw CronError("The gateway did not acknowledge the scheduled-jobs change.")
        }
        switch action {
        case .remove:
            guard case .object(let removed)? = payload["removed_job"], removed["id"] == .string(jobID) else {
                throw CronError("The gateway did not identify the removed scheduled job.")
            }
        case .pause, .resume:
            guard case .object(let job)? = payload["job"], job["job_id"] == .string(jobID) else {
                throw CronError("The gateway did not identify the changed scheduled job.")
            }
        }
    }

    private func validateCreateReceipt(_ result: JSONValue, preflightIDs: Set<String>) throws -> CreateReceipt {
        if case .object(let payload) = result, payload["success"] == .bool(false),
           case .string(let reason)? = payload["error"], !reason.isEmpty {
            // Registration failures can leave a stored job, so retain the uncertain-write warning.
            throw CronError(reason)
        }
        guard case .object(let payload) = result,
              payload["success"] == .bool(true),
              case .string(let jobID)? = payload["job_id"], !jobID.isEmpty,
              case .object(let job)? = payload["job"],
              job["job_id"] == .string(jobID),
              !preflightIDs.contains(jobID) else {
            throw CronError("The gateway did not provide a verifiable newly created scheduled job.")
        }
        let warning: String
        if let rawWarning = payload["warning"] {
            guard case .string(let text) = rawWarning else {
                throw CronError("The scheduled-job creation warning was malformed.")
            }
            warning = text
        } else {
            warning = ""
        }
        return CreateReceipt(id: jobID, warning: warning)
    }

    private func validateReadback(_ jobs: [HermesTUICronJob], action: HermesTUICronAction, jobID: String) throws {
        let job = jobs.first(where: { $0.id == jobID })
        switch action {
        case .pause:
            guard let job, !job.enabled, job.state == "paused" else {
                throw CronError("The paused state could not be confirmed from the selected profile.")
            }
        case .resume:
            guard let job, job.enabled, job.state != "paused" else {
                throw CronError("The resumed state could not be confirmed from the selected profile.")
            }
        case .remove:
            guard job == nil else {
                throw CronError("The scheduled job still appears in the selected profile after removal.")
            }
        }
    }

    private func decodeListing(_ value: JSONValue, profile: String) throws -> Listing {
        guard case .object(let payload) = value,
              payload["success"] == .bool(true),
              payload["scoped"] == .string(profile),
              case .number(let countValue)? = payload["count"],
              let count = Int(exactly: countValue),
              case .array(let rows)? = payload["jobs"],
              count == rows.count else {
            throw CronError("The gateway returned an incomplete or mismatched scheduled-jobs list.")
        }
        let decoded = try rows.map(decodeJob)
        guard Set(decoded.map(\.id)).count == decoded.count else {
            throw CronError("The gateway returned duplicate scheduled-job IDs.")
        }
        let warning: String
        if let value = payload["warning"] {
            guard case .string(let text) = value else { throw CronError("The scheduled-jobs warning was malformed.") }
            warning = text
        } else {
            warning = ""
        }
        return Listing(jobs: decoded, warning: warning)
    }

    private func decodeJob(_ value: JSONValue) throws -> HermesTUICronJob {
        guard case .object(let row) = value,
              case .string(let id)? = row["job_id"], !id.isEmpty,
              case .string(let name)? = row["name"],
              case .string(let promptPreview)? = row["prompt_preview"],
              case .string(let schedule)? = row["schedule"],
              case .string(let state)? = row["state"],
              case .bool(let enabled)? = row["enabled"],
              case .string(let deliver)? = row["deliver"],
              case .string(let repeatDescription)? = row["repeat"],
              let nextRunAt = optionalString(row["next_run_at"]),
              let lastRunAt = optionalString(row["last_run_at"]),
              let model = optionalString(row["model"]),
              let provider = optionalString(row["provider"]) else {
            throw CronError("The gateway returned a malformed scheduled job.")
        }
        return .init(id: id, name: name, promptPreview: promptPreview, schedule: schedule, state: state,
                     enabled: enabled, deliver: deliver, repeatDescription: repeatDescription,
                     nextRunAt: nextRunAt, lastRunAt: lastRunAt, model: model, provider: provider)
    }

    /// `nil` means JSON null or an absent optional field; a different concrete type is rejected.
    private func optionalString(_ value: JSONValue?) -> String?? {
        switch value {
        case nil, .some(.null): return .some(nil)
        case .some(.string(let text)): return .some(text)
        default: return nil
        }
    }

    private struct Listing {
        let jobs: [HermesTUICronJob]
        let warning: String
    }

    private struct CreateReceipt {
        let id: String
        let warning: String
    }

    private struct CronError: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }
}
