//
//  CompanionGatewayRegistry.swift
//  HermesHostCompanion
//

import Darwin
import Foundation

struct GatewayPlatformDefinition: Codable, Identifiable {
    let key: String
    let label: String
    let description: String
    let fields: [String]

    var id: String { key }
}

struct GatewayEnvFieldDefinition: Codable, Identifiable {
    let key: String
    let label: String
    let type: String
    let hint: String

    var id: String { key }
}

enum CompanionGatewayRegistryError: LocalizedError {
    case invalidWorkspace(String)
    case invalidProfileName
    case invalidEnvKey(String)
    case invalidPlatform(String)
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidWorkspace(let path):
            return "The Hermes workspace path '\(path)' is invalid."
        case .invalidProfileName:
            return "Enter a valid profile name."
        case .invalidEnvKey(let key):
            return "The environment key '\(key)' is not managed by the Gateway panel."
        case .invalidPlatform(let platform):
            return "The platform '\(platform)' is not managed by the Gateway panel."
        case .commandFailed(let message):
            return message
        }
    }
}

final class CompanionGatewayRegistry {
    private let fileManager = FileManager.default

    func config(workspacePath: String, profileName: String?) throws -> GatewayConfigResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let profileURL = try profileURL(workspaceURL: workspaceURL, profileName: profileName)
        let profile = normalizedProfileName(profileName) ?? activeProfileName(workspaceURL: workspaceURL)
        return GatewayConfigResult(
            workspacePath: workspacePath,
            resolvedWorkspacePath: workspaceURL.path,
            profileName: profile,
            profilePath: profileURL.path,
            envFilePath: profileURL.appendingPathComponent(".env").path,
            configPath: profileURL.appendingPathComponent("config.yaml").path,
            gatewayRunning: gatewayStatus(workspacePath: workspacePath, profileName: profile).running,
            env: readEnv(profileURL: profileURL),
            platformEnabled: try readPlatformEnabled(profileURL: profileURL),
            fields: Self.fields,
            platforms: Self.platforms
        )
    }

    func gatewayStatus(workspacePath: String, profileName: String?) -> GatewayStatusResult {
        do {
            let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
            let profileURL = try profileURL(workspaceURL: workspaceURL, profileName: profileName)
            let profile = normalizedProfileName(profileName) ?? activeProfileName(workspaceURL: workspaceURL)
            let pidRunning = isGatewayRunning(profileURL: profileURL)
            let command = runGatewayCommand(["status"], workspaceURL: workspaceURL, profileURL: profileURL, timeout: 5)
            let commandRunning = command.output.localizedCaseInsensitiveContains("running") && !command.output.localizedCaseInsensitiveContains("not running")
            return GatewayStatusResult(
                workspacePath: workspacePath,
                resolvedWorkspacePath: workspaceURL.path,
                profileName: profile,
                profilePath: profileURL.path,
                running: pidRunning || commandRunning,
                output: command.output,
                error: command.error
            )
        } catch {
            return GatewayStatusResult(
                workspacePath: workspacePath,
                resolvedWorkspacePath: "",
                profileName: normalizedProfileName(profileName) ?? "default",
                profilePath: "",
                running: false,
                output: "",
                error: error.localizedDescription
            )
        }
    }

    func setGatewayRunning(workspacePath: String, profileName: String?, running: Bool) throws -> GatewayOperationResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let profileURL = try profileURL(workspaceURL: workspaceURL, profileName: profileName)
        let profile = normalizedProfileName(profileName) ?? activeProfileName(workspaceURL: workspaceURL)
        let command = runGatewayCommand([running ? "start" : "stop"], workspaceURL: workspaceURL, profileURL: profileURL, timeout: 25)
        let status = gatewayStatus(workspacePath: workspacePath, profileName: profile)
        return GatewayOperationResult(
            workspacePath: workspacePath,
            resolvedWorkspacePath: workspaceURL.path,
            profileName: profile,
            profilePath: profileURL.path,
            success: command.success,
            gatewayRunning: status.running,
            output: command.output,
            error: command.error,
            config: try? config(workspacePath: workspacePath, profileName: profile)
        )
    }

    func restartGateway(workspacePath: String, profileName: String?) throws -> GatewayOperationResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let profileURL = try profileURL(workspaceURL: workspaceURL, profileName: profileName)
        let profile = normalizedProfileName(profileName) ?? activeProfileName(workspaceURL: workspaceURL)
        let command = runGatewayCommand(["restart"], workspaceURL: workspaceURL, profileURL: profileURL, timeout: 30)
        let status = gatewayStatus(workspacePath: workspacePath, profileName: profile)
        return GatewayOperationResult(
            workspacePath: workspacePath,
            resolvedWorkspacePath: workspaceURL.path,
            profileName: profile,
            profilePath: profileURL.path,
            success: command.success,
            gatewayRunning: status.running,
            output: command.output,
            error: command.error,
            config: try? config(workspacePath: workspacePath, profileName: profile)
        )
    }

    func setEnv(workspacePath: String, profileName: String?, key: String, value: String) throws -> SetGatewayEnvResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let profileURL = try profileURL(workspaceURL: workspaceURL, profileName: profileName)
        let normalizedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.fieldKeys.contains(normalizedKey) else { throw CompanionGatewayRegistryError.invalidEnvKey(normalizedKey) }
        try CompanionRuntimeConfigSafety.validateEnvReplacement(value)
        try setEnvValue(profileURL: profileURL, key: normalizedKey, value: value)
        let profile = normalizedProfileName(profileName) ?? activeProfileName(workspaceURL: workspaceURL)
        let shouldRestart = normalizedKey.hasSuffix("_API_KEY") || normalizedKey.hasSuffix("_TOKEN") || normalizedKey == "HF_TOKEN"
        let restartOutput: String?
        if shouldRestart, gatewayStatus(workspacePath: workspacePath, profileName: profile).running {
            let command = runGatewayCommand(["restart"], workspaceURL: workspaceURL, profileURL: profileURL, timeout: 30)
            guard command.success else { throw CompanionGatewayRegistryError.commandFailed("Settings were saved, but the gateway restart failed. Restart it on the host to apply changes.") }
            restartOutput = "Gateway restart completed."
        } else {
            restartOutput = nil
        }
        return SetGatewayEnvResult(
            workspacePath: workspacePath,
            resolvedWorkspacePath: workspaceURL.path,
            profileName: profile,
            profilePath: profileURL.path,
            envFilePath: profileURL.appendingPathComponent(".env").path,
            key: normalizedKey,
            value: readEnv(profileURL: profileURL)[normalizedKey] ?? "",
            env: readEnv(profileURL: profileURL),
            gatewayRunning: gatewayStatus(workspacePath: workspacePath, profileName: profile).running,
            restartOutput: restartOutput
        )
    }

    func setPlatformEnabled(workspacePath: String, profileName: String?, platform: String, enabled: Bool) throws -> SetGatewayPlatformResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let profileURL = try profileURL(workspaceURL: workspaceURL, profileName: profileName)
        let normalizedPlatform = platform.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.platformKeys.contains(normalizedPlatform) else { throw CompanionGatewayRegistryError.invalidPlatform(normalizedPlatform) }
        try setPlatformEnabledValue(profileURL: profileURL, platform: normalizedPlatform, enabled: enabled)
        let profile = normalizedProfileName(profileName) ?? activeProfileName(workspaceURL: workspaceURL)
        let command: (success: Bool, output: String, error: String?)?
        if gatewayStatus(workspacePath: workspacePath, profileName: profile).running {
            command = runGatewayCommand(["restart"], workspaceURL: workspaceURL, profileURL: profileURL, timeout: 30)
        } else {
            command = nil
        }
        if let command, !command.success {
            throw CompanionGatewayRegistryError.commandFailed("Platform settings were saved, but the gateway restart failed. Restart it on the host to apply changes.")
        }
        return SetGatewayPlatformResult(
            workspacePath: workspacePath,
            resolvedWorkspacePath: workspaceURL.path,
            profileName: profile,
            profilePath: profileURL.path,
            configPath: profileURL.appendingPathComponent("config.yaml").path,
            platform: normalizedPlatform,
            enabled: enabled,
            platformEnabled: try readPlatformEnabled(profileURL: profileURL),
            gatewayRunning: gatewayStatus(workspacePath: workspacePath, profileName: profile).running,
            restartOutput: command == nil ? nil : "Gateway restart completed."
        )
    }

    private func resolvedWorkspaceURL(from workspacePath: String) throws -> URL {
        guard let url = CompanionWorkspaceSecurity.resolvedHermesWorkspaceURL(from: workspacePath) else {
            throw CompanionGatewayRegistryError.invalidWorkspace(workspacePath)
        }
        return url
    }

    private func profileURL(workspaceURL: URL, profileName: String?) throws -> URL {
        let name = normalizedProfileName(profileName) ?? activeProfileName(workspaceURL: workspaceURL)
        if name == "default" { return workspaceURL }
        guard name.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]*$"#, options: .regularExpression) != nil else { throw CompanionGatewayRegistryError.invalidProfileName }
        let profilesURL = workspaceURL.appendingPathComponent("profiles", isDirectory: true)
        let selectedURL = profilesURL.appendingPathComponent(name, isDirectory: true)
        guard selectedURL.resolvingSymlinksInPath().deletingLastPathComponent() == profilesURL.resolvingSymlinksInPath(),
              CompanionWorkspaceSecurity.resolvedHermesWorkspaceURL(from: selectedURL.path) != nil else { throw CompanionGatewayRegistryError.invalidProfileName }
        return selectedURL
    }

    private func normalizedProfileName(_ name: String?) -> String? {
        guard let name else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private func activeProfileName(workspaceURL: URL) -> String {
        let activeURL = workspaceURL.appendingPathComponent("active_profile")
        guard let raw = try? String(contentsOf: activeURL, encoding: .utf8) else { return "default" }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "default" : trimmed
    }

    private func readEnv(profileURL: URL) -> [String: String] {
        guard let content = try? String(contentsOf: profileURL.appendingPathComponent(".env"), encoding: .utf8) else { return [:] }
        return CompanionRuntimeConfigSafety.envMetadata(content: content, allowedKey: { Self.fieldKeys.contains($0) })
    }

    private func setEnvValue(profileURL: URL, key: String, value: String) throws {
        try fileManager.createDirectory(at: profileURL, withIntermediateDirectories: true)
        let envURL = profileURL.appendingPathComponent(".env")
        let safeValue = value.replacingOccurrences(of: "\n", with: "")
        let content = try CompanionRuntimeConfigSafety.read(envURL)
        var lines = content.components(separatedBy: .newlines)
        var found = false
        let keyPattern = "^#?\\s*\(NSRegularExpression.escapedPattern(for: key))\\s*="
        for index in lines.indices {
            let trimmed = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.range(of: keyPattern, options: .regularExpression) != nil {
                lines[index] = "\(key)=\(safeValue)"
                found = true
                break
            }
        }
        if !found { lines.append("\(key)=\(safeValue)") }
        try lines.joined(separator: "\n").write(to: envURL, atomically: true, encoding: .utf8)
    }

    private func readPlatformEnabled(profileURL: URL) throws -> [String: Bool] {
        let result = try CompanionRuntimeConfigSafety.apply(
            configURL: profileURL.appendingPathComponent("config.yaml"),
            request: ["action": "listPlatforms", "platforms": Self.platformKeys.sorted()])
        guard let enabled = result["platformEnabled"] as? [String: Bool] else { throw CompanionRuntimeConfigSafety.Failure.rejected }
        return enabled
    }

    private func setPlatformEnabledValue(profileURL: URL, platform: String, enabled: Bool) throws {
        _ = try CompanionRuntimeConfigSafety.apply(
            configURL: profileURL.appendingPathComponent("config.yaml"),
            request: ["action": "setPlatform", "platform": platform, "enabled": enabled, "platforms": Self.platformKeys.sorted()])
    }

    private func isGatewayRunning(profileURL: URL) -> Bool {
        let pidURL = profileURL.appendingPathComponent("gateway.pid")
        guard let raw = try? String(contentsOf: pidURL, encoding: .utf8),
              let pid = Int32(raw.trimmingCharacters(in: .whitespacesAndNewlines)) else { return false }
        return kill(pid, 0) == 0
    }

    private func runGatewayCommand(_ args: [String], workspaceURL: URL, profileURL: URL, timeout: TimeInterval) -> (success: Bool, output: String, error: String?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["hermes", "gateway", "--accept-hooks"] + args
        process.environment = commandEnvironment(workspaceURL: workspaceURL, profileURL: profileURL)
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        do {
            try process.run()
            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
            if process.isRunning { process.terminate() }
            process.waitUntilExit()
            let out = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let combined = [out, err].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: "\n")
            let success = process.terminationStatus == 0
            return (success, combined.isEmpty ? "Command completed." : combined, success ? nil : combined)
        } catch {
            return (false, "", error.localizedDescription)
        }
    }

    private func commandEnvironment(workspaceURL: URL, profileURL: URL) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["HERMES_HOME"] = profileURL.path == workspaceURL.path ? workspaceURL.path : profileURL.path
        env["HOME"] = NSHomeDirectory()
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        env["PATH"] = [
            home.appendingPathComponent(".local/bin").path,
            home.appendingPathComponent(".cargo/bin").path,
            workspaceURL.appendingPathComponent("hermes-agent/venv/bin").path,
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "/opt/homebrew/sbin",
            env["PATH"] ?? ""
        ].joined(separator: ":")
        return env
    }

    private static let platforms: [GatewayPlatformDefinition] = [
        .init(key: "telegram", label: "Telegram", description: "Telegram bot gateway", fields: ["TELEGRAM_BOT_TOKEN", "TELEGRAM_ALLOWED_USERS"]),
        .init(key: "discord", label: "Discord", description: "Discord bot gateway", fields: ["DISCORD_BOT_TOKEN", "DISCORD_ALLOWED_CHANNELS"]),
        .init(key: "slack", label: "Slack", description: "Slack app and bot tokens", fields: ["SLACK_BOT_TOKEN", "SLACK_APP_TOKEN"]),
        .init(key: "whatsapp", label: "WhatsApp", description: "WhatsApp API bridge", fields: ["WHATSAPP_API_URL", "WHATSAPP_API_TOKEN"]),
        .init(key: "signal", label: "Signal", description: "Signal phone integration", fields: ["SIGNAL_PHONE_NUMBER"]),
        .init(key: "matrix", label: "Matrix", description: "Matrix homeserver integration", fields: ["MATRIX_HOMESERVER", "MATRIX_USER_ID", "MATRIX_ACCESS_TOKEN"]),
        .init(key: "mattermost", label: "Mattermost", description: "Mattermost incoming gateway", fields: ["MATTERMOST_URL", "MATTERMOST_TOKEN"]),
        .init(key: "email", label: "Email", description: "IMAP/SMTP email gateway", fields: ["EMAIL_IMAP_SERVER", "EMAIL_SMTP_SERVER", "EMAIL_ADDRESS", "EMAIL_PASSWORD"]),
        .init(key: "sms", label: "SMS", description: "Twilio/SMS gateway", fields: ["SMS_PROVIDER", "TWILIO_ACCOUNT_SID", "TWILIO_AUTH_TOKEN", "TWILIO_PHONE_NUMBER"]),
        .init(key: "bluebubbles", label: "iMessage", description: "BlueBubbles iMessage bridge", fields: ["BLUEBUBBLES_URL", "BLUEBUBBLES_PASSWORD"]),
        .init(key: "dingtalk", label: "DingTalk", description: "DingTalk bot gateway", fields: ["DINGTALK_APP_KEY", "DINGTALK_APP_SECRET"]),
        .init(key: "feishu", label: "Feishu", description: "Feishu app gateway", fields: ["FEISHU_APP_ID", "FEISHU_APP_SECRET"]),
        .init(key: "wecom", label: "WeCom", description: "WeCom corporate gateway", fields: ["WECOM_CORP_ID", "WECOM_AGENT_ID", "WECOM_SECRET"]),
        .init(key: "weixin", label: "Weixin", description: "Weixin bot gateway", fields: ["WEIXIN_BOT_TOKEN"]),
        .init(key: "webhooks", label: "Webhooks", description: "Webhook receiver gateway", fields: ["WEBHOOK_SECRET"]),
        .init(key: "home_assistant", label: "Home Assistant", description: "Home Assistant control gateway", fields: ["HA_URL", "HA_TOKEN"])
    ]

    private static let fields: [GatewayEnvFieldDefinition] = [
        .init(key: "TELEGRAM_BOT_TOKEN", label: "Bot token", type: "password", hint: "Token from @BotFather."),
        .init(key: "TELEGRAM_ALLOWED_USERS", label: "Allowed users", type: "text", hint: "Comma-separated Telegram user IDs/usernames."),
        .init(key: "DISCORD_BOT_TOKEN", label: "Bot token", type: "password", hint: "Discord application bot token."),
        .init(key: "DISCORD_ALLOWED_CHANNELS", label: "Allowed channels", type: "text", hint: "Comma-separated Discord channel IDs."),
        .init(key: "SLACK_BOT_TOKEN", label: "Bot token", type: "password", hint: "Slack xoxb bot token."),
        .init(key: "SLACK_APP_TOKEN", label: "App token", type: "password", hint: "Slack xapp-level token."),
        .init(key: "WHATSAPP_API_URL", label: "API URL", type: "text", hint: "WhatsApp bridge API URL."),
        .init(key: "WHATSAPP_API_TOKEN", label: "API token", type: "password", hint: "WhatsApp bridge access token."),
        .init(key: "SIGNAL_PHONE_NUMBER", label: "Phone number", type: "text", hint: "Signal account phone number."),
        .init(key: "MATRIX_HOMESERVER", label: "Homeserver", type: "text", hint: "Matrix homeserver URL."),
        .init(key: "MATRIX_USER_ID", label: "User ID", type: "text", hint: "Matrix user ID."),
        .init(key: "MATRIX_ACCESS_TOKEN", label: "Access token", type: "password", hint: "Matrix access token."),
        .init(key: "MATTERMOST_URL", label: "Server URL", type: "text", hint: "Mattermost server URL."),
        .init(key: "MATTERMOST_TOKEN", label: "Token", type: "password", hint: "Mattermost access token."),
        .init(key: "EMAIL_IMAP_SERVER", label: "IMAP server", type: "text", hint: "Incoming mail server."),
        .init(key: "EMAIL_SMTP_SERVER", label: "SMTP server", type: "text", hint: "Outgoing mail server."),
        .init(key: "EMAIL_ADDRESS", label: "Email address", type: "text", hint: "Mailbox address."),
        .init(key: "EMAIL_PASSWORD", label: "Password", type: "password", hint: "Mailbox password or app password."),
        .init(key: "SMS_PROVIDER", label: "SMS provider", type: "text", hint: "SMS provider name, e.g. twilio."),
        .init(key: "TWILIO_ACCOUNT_SID", label: "Twilio account SID", type: "text", hint: "Twilio account SID."),
        .init(key: "TWILIO_AUTH_TOKEN", label: "Twilio auth token", type: "password", hint: "Twilio auth token."),
        .init(key: "TWILIO_PHONE_NUMBER", label: "Twilio phone number", type: "text", hint: "Twilio sender phone number."),
        .init(key: "BLUEBUBBLES_URL", label: "BlueBubbles URL", type: "text", hint: "BlueBubbles server URL."),
        .init(key: "BLUEBUBBLES_PASSWORD", label: "BlueBubbles password", type: "password", hint: "BlueBubbles server password."),
        .init(key: "DINGTALK_APP_KEY", label: "App key", type: "password", hint: "DingTalk application key."),
        .init(key: "DINGTALK_APP_SECRET", label: "App secret", type: "password", hint: "DingTalk application secret."),
        .init(key: "FEISHU_APP_ID", label: "App ID", type: "text", hint: "Feishu app ID."),
        .init(key: "FEISHU_APP_SECRET", label: "App secret", type: "password", hint: "Feishu app secret."),
        .init(key: "WECOM_CORP_ID", label: "Corp ID", type: "text", hint: "WeCom corporation ID."),
        .init(key: "WECOM_AGENT_ID", label: "Agent ID", type: "text", hint: "WeCom agent ID."),
        .init(key: "WECOM_SECRET", label: "Secret", type: "password", hint: "WeCom app secret."),
        .init(key: "WEIXIN_BOT_TOKEN", label: "Bot token", type: "password", hint: "Weixin bot token."),
        .init(key: "WEBHOOK_SECRET", label: "Webhook secret", type: "password", hint: "Shared secret for inbound webhooks."),
        .init(key: "HA_URL", label: "Home Assistant URL", type: "text", hint: "Home Assistant URL."),
        .init(key: "HA_TOKEN", label: "Home Assistant token", type: "password", hint: "Home Assistant long-lived access token.")
    ]

    private static var fieldKeys: Set<String> { Set(fields.map(\.key)) }
    private static var platformKeys: Set<String> { Set(platforms.map(\.key)) }
}
