//
//  CompanionProtocol.swift
//  HermesHostCompanion
//
//  Created by Codex on 05/05/2026.
//

import Foundation

struct CompanionIncomingEnvelope: Codable {
    let id: String?
    let type: String
    let authenticationToken: String?
    let payload: JSONValue?
}

struct CompanionOutgoingEnvelope: Codable {
    let id: String?
    let ok: Bool
    let payload: JSONValue?
    let error: CompanionErrorPayload?

    static func success<T: Encodable>(id: String?, payload: T) -> CompanionOutgoingEnvelope {
        CompanionOutgoingEnvelope(id: id, ok: true, payload: JSONValue.encode(payload), error: nil)
    }

    static func error(id: String?, code: String, message: String) -> CompanionOutgoingEnvelope {
        CompanionOutgoingEnvelope(
            id: id,
            ok: false,
            payload: nil,
            error: CompanionErrorPayload(code: code, message: message)
        )
    }
}

struct CompanionErrorPayload: Codable {
    let code: String
    let message: String
}

struct HelloResult: Codable {
    let protocolVersion: String
    let serverName: String
    let capabilities: [String]
}


struct ListTargetsResult: Codable {
    let targets: [CompanionTargetSummary]
}

struct ListTargetsPayload: Codable {
    let workspacePath: String?
}

struct CompanionTargetSummary: Codable, Identifiable {
    let id: String
    let displayName: String
    let format: CompanionTargetFormat
    let path: String
    let serviceID: String?
    let restartPolicy: CompanionRestartPolicy
}

struct ReadTargetPayload: Codable {
    let targetID: String
}

struct ReadTargetResult: Codable {
    let targetID: String
    let displayName: String
    let path: String
    let revision: String
    let content: String
    let format: CompanionTargetFormat
}

struct ValidateTargetPayload: Codable {
    let targetID: String
    let content: String?
}

struct ValidateTargetResult: Codable {
    let targetID: String
    let valid: Bool
    let revision: String?
    let diagnostics: [CompanionValidationDiagnostic]
}

struct WriteTargetPayload: Codable {
    let targetID: String
    let expectedRevision: String
    let content: String
    let createBackup: Bool
}

struct WriteTargetResult: Codable {
    let targetID: String
    let revision: String
    let backupID: String?
    let diagnostics: [CompanionValidationDiagnostic]
}

struct ListBackupsPayload: Codable {
    let targetID: String?
}

struct ListBackupsResult: Codable {
    let backups: [CompanionBackupSummary]
}

struct CompanionBackupSummary: Codable, Identifiable {
    let id: String
    let targetID: String
    let createdAt: Date
    let path: String
}

struct RestoreBackupPayload: Codable {
    let backupID: String
}

struct RestoreBackupResult: Codable {
    let backupID: String
    let targetID: String
    let revision: String
}

struct ServiceStatusPayload: Codable {
    let serviceID: String
}

struct ServiceStatusResult: Codable {
    let serviceID: String
    let status: CompanionManagedServiceStatus
    let output: String
}

struct ServiceRestartPayload: Codable {
    let serviceID: String
}

struct ServiceStartPayload: Codable {
    let serviceID: String
}

struct ServiceStopPayload: Codable {
    let serviceID: String
}

struct ServiceRestartResult: Codable {
    let serviceID: String
    let status: CompanionManagedServiceStatus
    let output: String
}

struct ServiceStartResult: Codable {
    let serviceID: String
    let status: CompanionManagedServiceStatus
    let output: String
}

struct ServiceStopResult: Codable {
    let serviceID: String
    let status: CompanionManagedServiceStatus
    let output: String
}

struct HermesInstallationStatusPayload: Codable {
    let workspacePath: String
}

struct HermesInstallationUpdatePayload: Codable {
    let workspacePath: String
}

struct HermesInstallationMergePayload: Codable {
    let workspacePath: String
}

struct HermesInstallationStatusResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let repositoryPath: String
    let remoteURL: String
    let branch: String
    let currentCommit: String
    let upstreamCommit: String
    let behindBy: Int
    let checkedAt: Date
    let pendingUpdateBranch: String?
    let pendingUpdateCommit: String?
    let conflictFiles: [String]
    let lastUpdateOutput: String

    var isUpdateBlocked: Bool {
        pendingUpdateBranch?.isEmpty == false
    }
}

struct HermesInstallationOperationResult: Codable {
    let status: HermesInstallationStatusResult
    let output: String
}

struct ListHermesSkillsPayload: Codable {
    let workspacePath: String
}

struct ListHermesSkillsResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let skills: [CompanionHermesSkillSummary]
}

struct SetHermesSkillStatePayload: Codable {
    let workspacePath: String
    let skillID: String
    let isEnabled: Bool
}

struct SetHermesSkillStateResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let skill: CompanionHermesSkillSummary
}

struct CompanionHermesSkillSummary: Codable, Identifiable {
    let id: String
    let name: String
    let category: String
    let description: String
    let path: String
    let isEnabled: Bool
}

enum MCPServerTransport: String, Codable, CaseIterable {
    case stdio
    case streamableHTTP
}

struct ListMCPServersResult: Codable {
    let servers: [CompanionMCPServerSummary]
    let output: String
}

struct AddMCPServerPayload: Codable {
    let name: String
    let transport: MCPServerTransport
    let command: String
    let arguments: String
    let url: String
    let bearerToken: String
}

struct RemoveMCPServerPayload: Codable {
    let name: String
}

struct MCPServerOperationResult: Codable {
    let serverName: String
    let output: String
    let servers: [CompanionMCPServerSummary]
}

struct CompanionMCPServerSummary: Codable, Identifiable {
    let id: String
    let name: String
    let transport: String
    let tools: String
    let status: String
}

struct GatewayConfigPayload: Codable {
    let workspacePath: String
    let profileName: String?
}

struct GatewayConfigResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let profileName: String
    let profilePath: String
    let envFilePath: String
    let configPath: String
    let gatewayRunning: Bool
    let env: [String: String]
    let platformEnabled: [String: Bool]
    let fields: [GatewayEnvFieldDefinition]
    let platforms: [GatewayPlatformDefinition]
}

struct GatewayStatusPayload: Codable {
    let workspacePath: String
    let profileName: String?
}

struct GatewayStatusResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let profileName: String
    let profilePath: String
    let running: Bool
    let output: String
    let error: String?
}

struct SetGatewayRunningPayload: Codable {
    let workspacePath: String
    let profileName: String?
    let running: Bool
}

struct GatewayOperationResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let profileName: String
    let profilePath: String
    let success: Bool
    let gatewayRunning: Bool
    let output: String
    let error: String?
    let config: GatewayConfigResult?
}

struct SetGatewayEnvPayload: Codable {
    let workspacePath: String
    let profileName: String?
    let key: String
    let value: String
}

struct SetGatewayEnvResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let profileName: String
    let profilePath: String
    let envFilePath: String
    let key: String
    let value: String
    let env: [String: String]
    let gatewayRunning: Bool
    let restartOutput: String?
}

struct SetGatewayPlatformPayload: Codable {
    let workspacePath: String
    let profileName: String?
    let platform: String
    let enabled: Bool
}

struct SetGatewayPlatformResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let profileName: String
    let profilePath: String
    let configPath: String
    let platform: String
    let enabled: Bool
    let platformEnabled: [String: Bool]
    let gatewayRunning: Bool
    let restartOutput: String?
}

struct RestartGatewayPayload: Codable {
    let workspacePath: String
    let profileName: String?
}

struct ListToolsetsPayload: Codable {
    let workspacePath: String
}

struct ListToolsetsResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let configPath: String
    let toolsets: [CompanionToolsetInfo]
}

struct SetToolsetEnabledPayload: Codable {
    let workspacePath: String
    let key: String
    let enabled: Bool
}

struct SetToolsetEnabledResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let configPath: String
    let toolset: CompanionToolsetInfo
}

struct CompanionToolsetInfo: Codable, Identifiable {
    let key: String
    let label: String
    let description: String
    let enabled: Bool

    var id: String { key }
}

struct ListModelsPayload: Codable {
    let workspacePath: String
}

struct ListModelsResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let modelsFilePath: String
    let models: [CompanionSavedModel]
}

struct AddModelPayload: Codable {
    let workspacePath: String
    let name: String
    let provider: String
    let model: String
    let baseURL: String
}

struct AddModelResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let modelsFilePath: String
    let model: CompanionSavedModel
}

struct UpdateModelPayload: Codable {
    let workspacePath: String
    let id: String
    let name: String
    let provider: String
    let model: String
    let baseURL: String
}

struct UpdateModelResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let modelsFilePath: String
    let model: CompanionSavedModel
}

struct RemoveModelPayload: Codable {
    let workspacePath: String
    let id: String
}

struct RemoveModelResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let modelsFilePath: String
    let removedModelID: String
}



struct ProviderEnvField: Codable, Identifiable {
    let key: String
    let label: String
    let type: String
    let hint: String
    var id: String { key }
}

struct ProviderEnvSection: Codable, Identifiable {
    let id: String
    let title: String
    let items: [ProviderEnvField]
}

struct ProviderModelConfig: Codable {
    let provider: String
    let model: String
    let baseUrl: String
}

struct RuntimeModelSlotConfig: Codable, Identifiable {
    let id: String
    let label: String
    let section: String
    let key: String
    let provider: String
    let model: String
}

struct ProviderCredentialEntry: Codable, Identifiable {
    let key: String
    let label: String
    var id: String { label + ":" + String(key.prefix(8)) }
}

struct ProvidersConfigPayload: Codable {
    let workspacePath: String
}

struct ProvidersConfigResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let envFilePath: String
    let configPath: String
    let authFilePath: String
    let env: [String: String]
    let modelConfig: ProviderModelConfig
    let delegationModelConfig: RuntimeModelSlotConfig
    let auxiliaryModelConfigs: [RuntimeModelSlotConfig]
    let credentialPool: [String: [ProviderCredentialEntry]]
    let sections: [ProviderEnvSection]
    let providerOptions: [ProviderOption]
}

struct ProviderOption: Codable, Identifiable {
    let value: String
    let label: String
    var id: String { value }
}

struct SetProviderEnvPayload: Codable {
    let workspacePath: String
    let key: String
    let value: String
}

struct SetProviderEnvResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let key: String
    let value: String
    let envFilePath: String
}

struct RemoveProviderEnvPayload: Codable {
    let workspacePath: String
    let key: String
}

struct RemoveProviderEnvResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let key: String
    let envFilePath: String
    let env: [String: String]
}

struct SetProviderModelConfigPayload: Codable {
    let workspacePath: String
    let provider: String
    let model: String
    let baseUrl: String
}

struct SetProviderModelConfigResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let configPath: String
    let modelConfig: ProviderModelConfig
}

struct SetRuntimeModelSlotPayload: Codable {
    let workspacePath: String
    let section: String
    let key: String
    let provider: String
    let model: String
}

struct SetRuntimeModelSlotResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let configPath: String
    let slot: RuntimeModelSlotConfig
}

struct SetCredentialPoolPayload: Codable {
    let workspacePath: String
    let provider: String
    let entries: [ProviderCredentialEntry]
}

struct SetCredentialPoolResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let authFilePath: String
    let credentialPool: [String: [ProviderCredentialEntry]]
}


struct MemoryEntry: Codable, Identifiable {
    let index: Int
    let content: String
    var id: Int { index }
}

struct MemoryFileInfo: Codable {
    let content: String
    let exists: Bool
    let lastModified: Int?
    let sizeOnDiskBytes: Int64?
    let entries: [MemoryEntry]?
    let charCount: Int
    let charLimit: Int
}

struct MemoryStats: Codable {
    let totalSessions: Int
    let totalMessages: Int
}

struct MemoryProviderInfo: Codable, Identifiable {
    let name: String
    let description: String
    let installed: Bool
    let active: Bool
    let envVars: [String]
    var id: String { name }
}

struct MemoryConfigPayload: Codable {
    let workspacePath: String
}

struct MemoryConfigResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let memoryFilePath: String
    let userFilePath: String
    let configPath: String
    let envFilePath: String
    let configSizeOnDiskBytes: Int64?
    let envSizeOnDiskBytes: Int64?
    let memory: MemoryFileInfo
    let user: MemoryFileInfo
    let stats: MemoryStats
    let provider: String
    let providers: [MemoryProviderInfo]
    let env: [String: String]
}

struct AddMemoryEntryPayload: Codable {
    let workspacePath: String
    let content: String
}

struct UpdateMemoryEntryPayload: Codable {
    let workspacePath: String
    let index: Int
    let content: String
}

struct RemoveMemoryEntryPayload: Codable {
    let workspacePath: String
    let index: Int
}

struct WriteUserProfilePayload: Codable {
    let workspacePath: String
    let content: String
}

struct MemoryOperationResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let success: Bool
    let error: String?
    let memory: MemoryConfigResult?
}

struct SetMemoryProviderPayload: Codable {
    let workspacePath: String
    let provider: String
}

struct SetMemoryProviderResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let configPath: String
    let provider: String
    let providers: [MemoryProviderInfo]
}

struct SetMemoryEnvPayload: Codable {
    let workspacePath: String
    let key: String
    let value: String
}

struct SetMemoryEnvResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let envFilePath: String
    let key: String
    let value: String
}

struct ProfileInfo: Codable, Identifiable {
    let id: String
    let name: String
    let path: String
    let isDefault: Bool
    let isActive: Bool
    let model: String
    let provider: String
    let baseUrl: String
    let hasConfig: Bool
    let hasEnv: Bool
    let hasSoul: Bool
    let skillCount: Int
    let gatewayRunning: Bool
}

struct ListProfilesPayload: Codable {
    let workspacePath: String
}

struct ListProfilesResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let profilesDirectoryPath: String
    let activeProfileName: String
    let profiles: [ProfileInfo]
}

struct CreateProfilePayload: Codable {
    let workspacePath: String
    let name: String
    let provider: String
    let model: String
    let baseUrl: String
    let createEnv: Bool
    let createSoul: Bool
    let cloneSkills: Bool
}

struct EditProfilePayload: Codable {
    let workspacePath: String
    let originalName: String
    let name: String
    let provider: String
    let model: String
    let baseUrl: String
    let createEnv: Bool
    let createSoul: Bool
}

struct ProfileOperationPayload: Codable {
    let workspacePath: String
    let name: String
}

struct ProfileOperationResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let success: Bool
    let output: String
    let error: String?
    let activeProfileName: String
    let profiles: [ProfileInfo]
}

struct ScheduleRepeatInfo: Codable {
    let times: Int?
    let completed: Int
}

struct ScheduleCronJob: Codable, Identifiable {
    let id: String
    let name: String
    let schedule: String
    let prompt: String
    let state: String
    let enabled: Bool
    let nextRunAt: String?
    let lastRunAt: String?
    let lastStatus: String?
    let lastError: String?
    let repeatInfo: ScheduleRepeatInfo?
    let deliver: [String]
    let skills: [String]
    let script: String?
}

struct ListSchedulesPayload: Codable {
    let workspacePath: String
    let includeDisabled: Bool
}

struct ListSchedulesResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let jobsFilePath: String
    let jobs: [ScheduleCronJob]
}

struct CreateSchedulePayload: Codable {
    let workspacePath: String
    let schedule: String
    let prompt: String?
    let name: String?
    let deliver: String?
}

struct ScheduleOperationPayload: Codable {
    let workspacePath: String
    let jobID: String
}

struct ScheduleOperationResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let jobsFilePath: String
    let success: Bool
    let output: String
    let error: String?
    let jobs: [ScheduleCronJob]
}


enum CompanionManagedServiceStatus: String, Codable {
    case running
    case stopped
    case unknown
    case restarted
    case started
}

struct CompanionValidationDiagnostic: Codable, Identifiable {
    let id: UUID
    let severity: CompanionValidationSeverity
    let message: String
    let validator: String
}

enum CompanionValidationSeverity: String, Codable {
    case error
    case warning
    case info
}

enum CompanionTargetFormat: String, Codable {
    case toml
    case json
    case yaml
    case text
}

enum CompanionRestartPolicy: String, Codable {
    case manual
    case suggested
    case automatic
}

enum CompanionValidatorSpec: Codable, Equatable {
    case tomlParse
    case jsonParse
    case yamlParse
    case command([String])

    private enum CodingKeys: String, CodingKey {
        case kind
        case arguments
    }

    private enum Kind: String, Codable {
        case tomlParse
        case jsonParse
        case yamlParse
        case command
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .tomlParse:
            try container.encode(Kind.tomlParse, forKey: .kind)
        case .jsonParse:
            try container.encode(Kind.jsonParse, forKey: .kind)
        case .yamlParse:
            try container.encode(Kind.yamlParse, forKey: .kind)
        case .command(let arguments):
            try container.encode(Kind.command, forKey: .kind)
            try container.encode(arguments, forKey: .arguments)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .tomlParse:
            self = .tomlParse
        case .jsonParse:
            self = .jsonParse
        case .yamlParse:
            self = .yamlParse
        case .command:
            self = .command(try container.decode([String].self, forKey: .arguments))
        }
    }
}

enum JSONValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    static func encode<T: Encodable>(_ value: T) -> JSONValue? {
        guard
            let data = try? JSONEncoder().encode(value),
            let json = try? JSONDecoder().decode(JSONValue.self, from: data)
        else {
            return nil
        }
        return json
    }

    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        let data = try JSONEncoder().encode(self)
        return try JSONDecoder().decode(type, from: data)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value.")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string):
            try container.encode(string)
        case .number(let number):
            try container.encode(number)
        case .bool(let bool):
            try container.encode(bool)
        case .object(let object):
            try container.encode(object)
        case .array(let array):
            try container.encode(array)
        case .null:
            try container.encodeNil()
        }
    }
}
