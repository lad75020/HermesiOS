
import Foundation

enum CompanionScheduleRegistryError: LocalizedError {
    case invalidWorkspace(String)
    case missingJobID
    case missingSchedule
    case unsupportedBaseURLPin

    var errorDescription: String? {
        switch self {
        case .invalidWorkspace(let path):
            return "The Hermes workspace path '\(path)' is invalid."
        case .missingJobID:
            return "Missing scheduled job ID."
        case .missingSchedule:
            return "Missing schedule expression."
        case .unsupportedBaseURLPin:
            return "This installed Hermes CLI does not expose a cron --base-url flag, so a base URL pin cannot be changed safely."
        }
    }
}

final class CompanionScheduleRegistry {
    func list(workspacePath: String, includeDisabled: Bool = true) throws -> ListSchedulesResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        return ListSchedulesResult(
            workspacePath: workspacePath,
            resolvedWorkspacePath: workspaceURL.path,
            jobsFilePath: jobsURL(for: workspaceURL).path,
            jobs: readJobs(workspaceURL: workspaceURL, includeDisabled: includeDisabled)
        )
    }

    func create(workspacePath: String, schedule: String, prompt: String?, name: String?, deliver: String?, provider: String?, model: String?, baseUrl: String?) async throws -> ScheduleOperationResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let args = try Self.createArguments(schedule: schedule, prompt: prompt, name: name, deliver: deliver, provider: provider, model: model, baseUrl: baseUrl)
        let result = await runCronCommand(args: args, workspaceURL: workspaceURL)
        return operationResult(workspacePath: workspacePath, workspaceURL: workspaceURL, result: result)
    }

    func edit(workspacePath: String, jobID: String, schedule: String?, prompt: String?, name: String?, deliver: String?, provider: String?, model: String?, baseUrl: String?) async throws -> ScheduleOperationResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let args = try Self.editArguments(jobID: jobID, schedule: schedule, prompt: prompt, name: name, deliver: deliver, provider: provider, model: model, baseUrl: baseUrl)
        let result = await runCronCommand(args: args, workspaceURL: workspaceURL)
        return operationResult(workspacePath: workspacePath, workspaceURL: workspaceURL, result: result)
    }

    func remove(workspacePath: String, jobID: String) async throws -> ScheduleOperationResult {
        try await runJobAction(workspacePath: workspacePath, jobID: jobID, action: "remove")
    }

    func pause(workspacePath: String, jobID: String) async throws -> ScheduleOperationResult {
        try await runJobAction(workspacePath: workspacePath, jobID: jobID, action: "pause")
    }

    func resume(workspacePath: String, jobID: String) async throws -> ScheduleOperationResult {
        try await runJobAction(workspacePath: workspacePath, jobID: jobID, action: "resume")
    }

    func trigger(workspacePath: String, jobID: String) async throws -> ScheduleOperationResult {
        try await runJobAction(workspacePath: workspacePath, jobID: jobID, action: "run")
    }

    private func runJobAction(workspacePath: String, jobID: String, action: String) async throws -> ScheduleOperationResult {
        let trimmedJobID = jobID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedJobID.isEmpty == false else { throw CompanionScheduleRegistryError.missingJobID }
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let result = await runCronCommand(args: [action, trimmedJobID], workspaceURL: workspaceURL)
        return operationResult(workspacePath: workspacePath, workspaceURL: workspaceURL, result: result)
    }

    private func operationResult(workspacePath: String, workspaceURL: URL, result: (success: Bool, output: String, error: String?)) -> ScheduleOperationResult {
        ScheduleOperationResult(
            workspacePath: workspacePath,
            resolvedWorkspacePath: workspaceURL.path,
            jobsFilePath: jobsURL(for: workspaceURL).path,
            success: result.success,
            output: result.output,
            error: result.error,
            jobs: readJobs(workspaceURL: workspaceURL, includeDisabled: true)
        )
    }

    private func resolvedWorkspaceURL(from workspacePath: String) throws -> URL {
        guard let workspaceURL = CompanionWorkspaceSecurity.resolvedHermesCLIContext(from: workspacePath)?.selectedHomeURL else {
            throw CompanionScheduleRegistryError.invalidWorkspace(workspacePath)
        }
        return workspaceURL
    }

    private func jobsURL(for workspaceURL: URL) -> URL { workspaceURL.appendingPathComponent("cron/jobs.json") }

    private func readJobs(workspaceURL: URL, includeDisabled: Bool) -> [ScheduleCronJob] {
        let url = jobsURL(for: workspaceURL)
        guard let data = try? Data(contentsOf: url),
              let parsed = try? JSONSerialization.jsonObject(with: data) else { return [] }
        let rawJobs: [[String: Any]]
        if let array = parsed as? [[String: Any]] {
            rawJobs = array
        } else if let object = parsed as? [String: Any], let array = object["jobs"] as? [[String: Any]] {
            rawJobs = array
        } else {
            rawJobs = []
        }
        return rawJobs.compactMap { Self.normalizeJob($0, includeDisabled: includeDisabled) }
    }

    static func normalizeJob(_ job: [String: Any], includeDisabled: Bool) -> ScheduleCronJob? {
        guard let rawID = job["id"] else { return nil }
        let id = String(describing: rawID)
        let enabled = (job["enabled"] as? Bool) ?? true
        if includeDisabled == false && enabled == false { return nil }
        var state = "active"
        if (job["state"] as? String) == "paused" || enabled == false { state = "paused" }
        else if (job["state"] as? String) == "completed" { state = "completed" }
        let rawSchedule = rawSchedule(from: job)
        let scheduleValue: String
        if let display = job["schedule_display"] as? String, display.isEmpty == false {
            scheduleValue = display
        } else {
            scheduleValue = rawSchedule.isEmpty ? "?" : rawSchedule
        }
        let repeatInfo: ScheduleRepeatInfo?
        if let repeatObject = job["repeat"] as? [String: Any] {
            repeatInfo = ScheduleRepeatInfo(times: repeatObject["times"] as? Int, completed: repeatObject["completed"] as? Int ?? 0)
        } else {
            repeatInfo = nil
        }
        return ScheduleCronJob(
            id: id,
            name: (job["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "(unnamed)",
            schedule: scheduleValue,
            rawSchedule: rawSchedule,
            prompt: job["prompt"] as? String ?? "",
            state: state,
            enabled: enabled,
            nextRunAt: job["next_run_at"] as? String,
            lastRunAt: job["last_run_at"] as? String,
            lastStatus: job["last_status"] as? String,
            lastError: job["last_error"] as? String,
            repeatInfo: repeatInfo,
            deliver: stringArray(from: job["deliver"], defaultValue: ["local"]),
            skills: stringArray(from: job["skills"], defaultValue: (job["skill"] as? String).map { [$0] } ?? []),
            script: job["script"] as? String,
            provider: string(from: job["provider"] ?? job["model_provider"]),
            model: string(from: job["model"]),
            baseUrl: string(from: job["base_url"])
        )
    }

    static func createArguments(schedule: String, prompt: String?, name: String?, deliver: String?, provider: String?, model: String?, baseUrl: String?) throws -> [String] {
        let trimmedSchedule = schedule.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedSchedule.isEmpty == false else { throw CompanionScheduleRegistryError.missingSchedule }
        guard baseUrl == nil else { throw CompanionScheduleRegistryError.unsupportedBaseURLPin }
        var args = ["create", trimmedSchedule]
        if let prompt, prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            args.append(prompt.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        appendCreatePin(&args, flag: "--name", value: name)
        appendCreatePin(&args, flag: "--deliver", value: deliver)
        appendCreatePin(&args, flag: "--provider", value: provider)
        appendCreatePin(&args, flag: "--model", value: model)
        return args
    }

    static func editArguments(jobID: String, schedule: String?, prompt: String?, name: String?, deliver: String?, provider: String?, model: String?, baseUrl: String?) throws -> [String] {
        let trimmedJobID = jobID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedJobID.isEmpty == false else { throw CompanionScheduleRegistryError.missingJobID }
        guard baseUrl == nil else { throw CompanionScheduleRegistryError.unsupportedBaseURLPin }
        var args = ["edit", trimmedJobID]
        appendEditPin(&args, flag: "--schedule", value: schedule)
        appendEditPin(&args, flag: "--prompt", value: prompt)
        appendEditPin(&args, flag: "--name", value: name)
        appendEditPin(&args, flag: "--deliver", value: deliver)
        appendEditPin(&args, flag: "--provider", value: provider)
        appendEditPin(&args, flag: "--model", value: model)
        return args
    }

    private static func appendCreatePin(_ args: inout [String], flag: String, value: String?) {
        guard let value else { return }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        args.append("\(flag)=\(trimmed)")
    }

    private static func appendEditPin(_ args: inout [String], flag: String, value: String?) {
        guard let value else { return }
        args.append("\(flag)=\(value.trimmingCharacters(in: .whitespacesAndNewlines))")
    }

    private static func rawSchedule(from job: [String: Any]) -> String {
        if let schedule = job["schedule"] as? String { return schedule }
        if let schedule = job["schedule"] as? [String: Any], let value = schedule["value"] as? String { return value }
        return ""
    }

    private static func stringArray(from value: Any?, defaultValue: [String]) -> [String] {
        if let array = value as? [String] { return array }
        if let string = value as? String, string.isEmpty == false { return [string] }
        return defaultValue
    }

    private static func string(from value: Any?) -> String? {
        guard let value = value as? String, value.isEmpty == false else { return nil }
        return value
    }

    private func runCronCommand(args: [String], workspaceURL: URL) async -> (success: Bool, output: String, error: String?) {
        guard let cliContext = CompanionWorkspaceSecurity.resolvedHermesCLIContext(from: workspaceURL.path) else {
            return (false, "", "Hermes CLI root could not be resolved for \(workspaceURL.path)")
        }
        let repoURL = cliContext.cliRootURL.appendingPathComponent("hermes-agent")
        let scriptURL = repoURL.appendingPathComponent("hermes")
        let pythonURL = repoURL.appendingPathComponent("venv/bin/python")
        guard FileManager.default.fileExists(atPath: scriptURL.path) else {
            return (false, "", "Hermes CLI script not found at \(scriptURL.path)")
        }

        let executableURL: URL
        let arguments: [String]
        if FileManager.default.fileExists(atPath: pythonURL.path) {
            executableURL = pythonURL
            arguments = [scriptURL.path, "cron"] + args
        } else {
            executableURL = URL(fileURLWithPath: "/usr/bin/env")
            arguments = ["python3", scriptURL.path, "cron"] + args
        }
        var env = ProcessInfo.processInfo.environment
        env["HERMES_HOME"] = cliContext.selectedHomeURL.path
        env["PATH"] = enhancedPath(cliRootURL: cliContext.cliRootURL, existing: env["PATH"] ?? "")
        do {
            let result = try await CompanionSubprocess.run(
                executableURL: executableURL,
                arguments: arguments,
                environment: env,
                currentDirectoryURL: repoURL,
                timeout: 60
            )
            let out = String(data: result.stdout, encoding: .utf8) ?? ""
            let err = String(data: result.stderr, encoding: .utf8) ?? ""
            return (result.status == 0, out, result.status == 0 ? nil : (err.isEmpty ? out : err))
        } catch {
            return (false, "", error.localizedDescription)
        }
    }

    private func enhancedPath(cliRootURL: URL, existing: String) -> String {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return [
            home.appendingPathComponent(".local/bin").path,
            home.appendingPathComponent(".cargo/bin").path,
            cliRootURL.appendingPathComponent("hermes-agent/venv/bin").path,
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            existing
        ].joined(separator: ":")
    }
}
