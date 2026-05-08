
import Foundation

enum CompanionScheduleRegistryError: LocalizedError {
    case invalidWorkspace(String)
    case missingJobID
    case missingSchedule

    var errorDescription: String? {
        switch self {
        case .invalidWorkspace(let path):
            return "The Hermes workspace path '\(path)' is invalid."
        case .missingJobID:
            return "Missing scheduled job ID."
        case .missingSchedule:
            return "Missing schedule expression."
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

    func create(workspacePath: String, schedule: String, prompt: String?, name: String?, deliver: String?) throws -> ScheduleOperationResult {
        let trimmedSchedule = schedule.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedSchedule.isEmpty == false else { throw CompanionScheduleRegistryError.missingSchedule }
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        var args = ["create", trimmedSchedule]
        if let prompt, prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            // `hermes cron create` defines the prompt as an optional positional
            // argument immediately after the schedule. Passing it after options
            // with `--` makes argparse report it as an unrecognized argument.
            args.append(prompt.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let name, name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            args.append(contentsOf: ["--name", name.trimmingCharacters(in: .whitespacesAndNewlines)])
        }
        if let deliver, deliver.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false, deliver != "local" {
            args.append(contentsOf: ["--deliver", deliver.trimmingCharacters(in: .whitespacesAndNewlines)])
        }
        let result = runCronCommand(args: args, workspaceURL: workspaceURL)
        return operationResult(workspacePath: workspacePath, workspaceURL: workspaceURL, result: result)
    }

    func remove(workspacePath: String, jobID: String) throws -> ScheduleOperationResult {
        try runJobAction(workspacePath: workspacePath, jobID: jobID, action: "remove")
    }

    func pause(workspacePath: String, jobID: String) throws -> ScheduleOperationResult {
        try runJobAction(workspacePath: workspacePath, jobID: jobID, action: "pause")
    }

    func resume(workspacePath: String, jobID: String) throws -> ScheduleOperationResult {
        try runJobAction(workspacePath: workspacePath, jobID: jobID, action: "resume")
    }

    func trigger(workspacePath: String, jobID: String) throws -> ScheduleOperationResult {
        try runJobAction(workspacePath: workspacePath, jobID: jobID, action: "run")
    }

    private func runJobAction(workspacePath: String, jobID: String, action: String) throws -> ScheduleOperationResult {
        let trimmedJobID = jobID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedJobID.isEmpty == false else { throw CompanionScheduleRegistryError.missingJobID }
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let result = runCronCommand(args: [action, trimmedJobID], workspaceURL: workspaceURL)
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
        let trimmedPath = workspacePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let expandedPath = (trimmedPath.isEmpty ? "~/.hermes" : trimmedPath as NSString).expandingTildeInPath
        let workspaceURL = URL(fileURLWithPath: expandedPath, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: workspaceURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
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
        return rawJobs.compactMap { normalizeJob($0, includeDisabled: includeDisabled) }
    }

    private func normalizeJob(_ job: [String: Any], includeDisabled: Bool) -> ScheduleCronJob? {
        guard let rawID = job["id"] else { return nil }
        let id = String(describing: rawID)
        let enabled = (job["enabled"] as? Bool) ?? true
        if includeDisabled == false && enabled == false { return nil }
        var state = "active"
        if (job["state"] as? String) == "paused" || enabled == false { state = "paused" }
        else if (job["state"] as? String) == "completed" { state = "completed" }
        let scheduleValue: String
        if let display = job["schedule_display"] as? String, display.isEmpty == false {
            scheduleValue = display
        } else if let schedule = job["schedule"] as? String {
            scheduleValue = schedule
        } else if let schedule = job["schedule"] as? [String: Any], let value = schedule["value"] as? String {
            scheduleValue = value
        } else {
            scheduleValue = "?"
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
            script: job["script"] as? String
        )
    }

    private func stringArray(from value: Any?, defaultValue: [String]) -> [String] {
        if let array = value as? [String] { return array }
        if let string = value as? String, string.isEmpty == false { return [string] }
        return defaultValue
    }

    private func runCronCommand(args: [String], workspaceURL: URL) -> (success: Bool, output: String, error: String?) {
        let repoURL = workspaceURL.appendingPathComponent("hermes-agent")
        let scriptURL = repoURL.appendingPathComponent("hermes")
        let pythonURL = repoURL.appendingPathComponent("venv/bin/python")
        guard FileManager.default.fileExists(atPath: scriptURL.path) else {
            return (false, "", "Hermes CLI script not found at \(scriptURL.path)")
        }

        let process = Process()
        if FileManager.default.fileExists(atPath: pythonURL.path) {
            process.executableURL = pythonURL
            process.arguments = [scriptURL.path, "cron"] + args
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["python3", scriptURL.path, "cron"] + args
        }
        process.currentDirectoryURL = repoURL
        var env = ProcessInfo.processInfo.environment
        env["HERMES_HOME"] = workspaceURL.path
        env["PATH"] = enhancedPath(workspaceURL: workspaceURL, existing: env["PATH"] ?? "")
        process.environment = env

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
            process.waitUntilExit()
            let out = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return (process.terminationStatus == 0, out, process.terminationStatus == 0 ? nil : (err.isEmpty ? out : err))
        } catch {
            return (false, "", error.localizedDescription)
        }
    }

    private func enhancedPath(workspaceURL: URL, existing: String) -> String {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return [
            home.appendingPathComponent(".local/bin").path,
            home.appendingPathComponent(".cargo/bin").path,
            workspaceURL.appendingPathComponent("hermes-agent/venv/bin").path,
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            existing
        ].joined(separator: ":")
    }
}
