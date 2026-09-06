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
    let deviceID: String?
    let deviceSecret: String?
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

struct CompanionOnboardingPayload: Codable {
    let type: String
    let version: Int
    let endpoint: String
    let code: String
    let serverName: String
    let hermesConfigFolderPath: String?
    let apiGatewayAPIKey: String?
}

struct CompanionEnrollDevicePayload: Codable {
    let code: String
    let deviceName: String
}

struct CompanionEnrollDeviceResult: Codable {
    let deviceID: String
    let deviceSecret: String
    let deviceName: String
    let serverEndpoint: String
    let approved: Bool
    let message: String
}

struct CompanionCheckDeviceApprovalPayload: Codable {
    let deviceID: String
    let deviceSecret: String
}

struct CompanionCheckDeviceApprovalResult: Codable {
    let deviceID: String
    let approved: Bool
    let revoked: Bool
    let message: String
}


struct ListTargetsResult: Codable {
    let targets: [CompanionTargetSummary]
}

struct ListTargetsPayload: Codable {
    let workspacePath: String?
    let profileName: String?
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
    let workspacePath: String?
    let profileName: String?
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
    let workspacePath: String?
    let profileName: String?
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
    let workspacePath: String?
    let profileName: String?
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

struct FileDownloadPayload: Codable {
    let path: String
    let workspacePath: String?
}

struct FileBrowserPayload: Codable {
    let path: String
    let workspacePath: String?
}

struct FileBrowserEntry: Codable {
    let name: String
    let path: String
    let isDirectory: Bool
    let byteCount: Int?
}

struct FileBrowserResult: Codable {
    let path: String
    let parentPath: String?
    let entries: [FileBrowserEntry]
}

struct FileDownloadResult: Codable {
    let path: String
    let fileName: String
    let byteCount: Int
    let contentType: String
    let base64Data: String
}

struct FileDownloadInfoResult: Codable {
    let path: String
    let fileName: String
    let byteCount: Int
    let contentType: String
    let chunkSize: Int
}

struct FileDownloadChunkPayload: Codable {
    let path: String
    let offset: Int
    let length: Int
    let workspacePath: String?
}

struct FileDownloadChunkResult: Codable {
    let path: String
    let offset: Int
    let byteCount: Int
    let totalByteCount: Int
    let isComplete: Bool
    let base64Data: String
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

struct CompanionServicePortsResult: Codable, Equatable {
    let apiGatewayPort: String
    let dashboardPort: String
    let officePort: String
}

struct TailscaleServeStatusPayload: Codable {
    let port: String
}

struct TailscaleServeSetPayload: Codable {
    let port: String
    let enabled: Bool
}

struct TailscaleServeStatusResult: Codable {
    let port: String
    let isEnabled: Bool
    let output: String
    let checkedAt: Date
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

struct HermesInstallationReviewConflictsPayload: Codable {
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
    case openAPI
}

struct ListMCPServersResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let servers: [CompanionMCPServerSummary]
    let output: String
}

struct ListMCPServersPayload: Codable {
    let workspacePath: String
}

struct AddMCPServerPayload: Codable {
    let workspacePath: String
    let name: String
    let transport: MCPServerTransport
    let command: String
    let arguments: String
    let url: String
    let bearerToken: String
}

struct RemoveMCPServerPayload: Codable {
    let workspacePath: String
    let name: String
}

struct SetMCPServerEnabledPayload: Codable {
    let workspacePath: String
    let name: String
    let enabled: Bool
}

struct MCPServerOperationResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
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
    let enabled: Bool

    enum CodingKeys: String, CodingKey { case id, name, transport, tools, status, enabled }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        transport = try container.decode(String.self, forKey: .transport)
        tools = try container.decode(String.self, forKey: .tools)
        status = try container.decode(String.self, forKey: .status)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled)
            ?? !status.localizedCaseInsensitiveContains("disabled")
    }
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
    let baseUrl: String

    init(id: String, label: String, section: String, key: String, provider: String, model: String, baseUrl: String = "") {
        self.id = id; self.label = label; self.section = section; self.key = key; self.provider = provider; self.model = model; self.baseUrl = baseUrl
    }

    private enum CodingKeys: String, CodingKey { case id, label, section, key, provider, model, baseUrl }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        label = try values.decode(String.self, forKey: .label)
        section = try values.decode(String.self, forKey: .section)
        key = try values.decode(String.self, forKey: .key)
        provider = try values.decode(String.self, forKey: .provider)
        model = try values.decode(String.self, forKey: .model)
        baseUrl = try values.decodeIfPresent(String.self, forKey: .baseUrl) ?? ""
    }
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
    /// Nil means an older client omitted this field; preserve the existing YAML value.
    let baseUrl: String?
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

struct SupermemoryManagementPayload: Codable {
    let workspacePath: String
}

struct SupermemoryManagementResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let success: Bool
    let status: String
    let exportedCount: Int
    let importedCount: Int
    let exportPath: String
    let digestPath: String
    let skillReferencePath: String
    let previousExportStartedAt: String
    let exportStartedAt: String
    let error: String?
}

enum KnowledgeEraserItemKind: String, Codable {
    case memoryEntry
    case userProfileBlock
    case skillBlock
}

struct KnowledgeEraserScanPayload: Codable {
    let workspacePath: String
    let topic: String
}

struct KnowledgeEraserErasePayload: Codable {
    let workspacePath: String
    let topic: String
    let selectedItemIDs: [String]
}

struct KnowledgeEraserItem: Codable, Identifiable {
    let id: String
    let kind: KnowledgeEraserItemKind
    let title: String
    let path: String
    let location: String
    let preview: String
    let content: String
    let confidence: Double
}

struct KnowledgeEraserScanResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let topic: String
    let scannedAt: Date
    let items: [KnowledgeEraserItem]
}

struct KnowledgeEraserEraseResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let topic: String
    let erasedAt: Date
    let archivePath: String
    let erasedItemIDs: [String]
    let skippedItemIDs: [String]
    let remainingItems: [KnowledgeEraserItem]
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
    /// The scheduler expression, kept separate from the friendly display value.
    let rawSchedule: String
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
    let provider: String?
    let model: String?
    let baseUrl: String?

    init(id: String, name: String, schedule: String, rawSchedule: String, prompt: String, state: String, enabled: Bool, nextRunAt: String?, lastRunAt: String?, lastStatus: String?, lastError: String?, repeatInfo: ScheduleRepeatInfo?, deliver: [String], skills: [String], script: String?, provider: String?, model: String?, baseUrl: String?) {
        self.id = id; self.name = name; self.schedule = schedule; self.rawSchedule = rawSchedule; self.prompt = prompt; self.state = state; self.enabled = enabled; self.nextRunAt = nextRunAt; self.lastRunAt = lastRunAt; self.lastStatus = lastStatus; self.lastError = lastError; self.repeatInfo = repeatInfo; self.deliver = deliver; self.skills = skills; self.script = script; self.provider = provider; self.model = model; self.baseUrl = baseUrl
    }

    private enum CodingKeys: String, CodingKey { case id, name, schedule, rawSchedule, prompt, state, enabled, nextRunAt, lastRunAt, lastStatus, lastError, repeatInfo, deliver, skills, script, provider, model, baseUrl }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id); name = try values.decode(String.self, forKey: .name)
        schedule = try values.decode(String.self, forKey: .schedule)
        rawSchedule = try values.decodeIfPresent(String.self, forKey: .rawSchedule) ?? schedule
        prompt = try values.decode(String.self, forKey: .prompt); state = try values.decode(String.self, forKey: .state); enabled = try values.decode(Bool.self, forKey: .enabled)
        nextRunAt = try values.decodeIfPresent(String.self, forKey: .nextRunAt); lastRunAt = try values.decodeIfPresent(String.self, forKey: .lastRunAt); lastStatus = try values.decodeIfPresent(String.self, forKey: .lastStatus); lastError = try values.decodeIfPresent(String.self, forKey: .lastError)
        repeatInfo = try values.decodeIfPresent(ScheduleRepeatInfo.self, forKey: .repeatInfo)
        deliver = try values.decodeIfPresent([String].self, forKey: .deliver) ?? []
        skills = try values.decodeIfPresent([String].self, forKey: .skills) ?? []
        script = try values.decodeIfPresent(String.self, forKey: .script); provider = try values.decodeIfPresent(String.self, forKey: .provider); model = try values.decodeIfPresent(String.self, forKey: .model); baseUrl = try values.decodeIfPresent(String.self, forKey: .baseUrl)
    }
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
    let provider: String?
    let model: String?
    let baseUrl: String?
}

/// Optional fields deliberately distinguish an omitted edit from an explicit
/// empty value, which Hermes CLI interprets as clearing the corresponding pin.
struct EditSchedulePayload: Codable {
    let workspacePath: String
    let jobID: String
    let schedule: String?
    let prompt: String?
    let name: String?
    let deliver: String?
    let provider: String?
    let model: String?
    let baseUrl: String?
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

enum CompanionWorkspaceSecurity {
    private static let fileManager = FileManager.default

    struct HermesCLIContext {
        let cliRootURL: URL
        let selectedHomeURL: URL
    }

    static func resolvedHermesWorkspaceURL(
        from rawPath: String,
        defaultPath: String = "~/.hermes",
        requireSkillsDirectory: Bool = false,
        requireHermesCLI: Bool = false
    ) -> URL? {
        let trimmed = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let expanded = NSString(string: trimmed.isEmpty ? defaultPath : trimmed).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded, isDirectory: true)
            .resolvingSymlinksInPath()
            .standardizedFileURL

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }
        guard isAllowedWorkspaceShape(url) else { return nil }
        if requireSkillsDirectory {
            guard directoryExists(url.appendingPathComponent("skills", isDirectory: true)) else { return nil }
        }
        if requireHermesCLI {
            guard fileManager.fileExists(atPath: url.appendingPathComponent("hermes-agent/hermes").path) else { return nil }
        }
        return url
    }

    static func approvedHermesRoots(preferredWorkspacePath: String?) -> [URL] {
        var candidates: [String] = []
        let environment = ProcessInfo.processInfo.environment
        if let hermesHome = environment["HERMES_HOME"], hermesHome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            candidates.append(hermesHome)
        }

        let home = fileManager.homeDirectoryForCurrentUser.path
        candidates.append(home + "/.hermes")
        candidates.append("/Volumes/WDBlack4TB/.hermes")
        candidates.append("/Volumes/WDBlack4TB/Code/HermesiOS/.hermes")

        var seen = Set<String>()
        let trustedRoots: [URL] = candidates.compactMap { candidate in
            guard let url = resolvedHermesWorkspaceURL(from: candidate) else { return nil }
            guard seen.insert(url.path).inserted else { return nil }
            return url
        }

        guard let preferredWorkspacePath,
              let preferredURL = resolvedHermesWorkspaceURL(from: preferredWorkspacePath),
              trustedRoots.contains(where: { isDescendant(preferredURL, of: $0) }) else {
            return trustedRoots
        }
        return [preferredURL] + trustedRoots.filter { $0 != preferredURL }
    }

    /// Resolves the executable from an approved Hermes root while retaining a
    /// selected named profile as HERMES_HOME. A profile is accepted only when it
    /// is a direct child of that root's `profiles` directory.
    static func resolvedHermesCLIContext(from rawPath: String) -> HermesCLIContext? {
        guard let selectedHomeURL = resolvedHermesWorkspaceURL(from: rawPath) else { return nil }
        for rootURL in approvedHermesRoots(preferredWorkspacePath: nil) {
            let cliURL = rootURL.appendingPathComponent("hermes-agent/hermes")
            guard fileManager.fileExists(atPath: cliURL.path) else { continue }
            if selectedHomeURL == rootURL {
                return HermesCLIContext(cliRootURL: rootURL, selectedHomeURL: selectedHomeURL)
            }
            let profilesURL = rootURL.appendingPathComponent("profiles", isDirectory: true)
            guard selectedHomeURL.deletingLastPathComponent() == profilesURL,
                  selectedHomeURL.lastPathComponent.isEmpty == false,
                  isDescendant(selectedHomeURL, of: profilesURL)
            else { continue }
            return HermesCLIContext(cliRootURL: rootURL, selectedHomeURL: selectedHomeURL)
        }
        return nil
    }

    static func isDescendant(_ url: URL, of root: URL) -> Bool {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path
        let rootPath = root.resolvingSymlinksInPath().standardizedFileURL.path
        return path == rootPath || path.hasPrefix(rootPath.hasSuffix("/") ? rootPath : rootPath + "/")
    }

    static func resolvedProfileURL(workspaceURL: URL, profileName: String?) -> URL? {
        let workspaceURL = workspaceURL.resolvingSymlinksInPath().standardizedFileURL
        let trimmed = (profileName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, trimmed != "default" else { return workspaceURL }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard !trimmed.hasPrefix("."), trimmed.rangeOfCharacter(from: allowed.inverted) == nil else { return nil }

        guard let profilesURL = resolvedProfilesDirectoryURL(workspaceURL: workspaceURL) else { return nil }
        let profileURL = profilesURL.appendingPathComponent(trimmed, isDirectory: true)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        guard profileURL.deletingLastPathComponent() == profilesURL,
              isDescendant(profileURL, of: profilesURL),
              directoryExists(profileURL) else { return nil }
        return profileURL
    }

    static func resolvedProfilesDirectoryURL(workspaceURL: URL) -> URL? {
        let workspaceURL = workspaceURL.resolvingSymlinksInPath().standardizedFileURL
        let directURL = workspaceURL.appendingPathComponent("profiles", isDirectory: true).standardizedFileURL
        let resolvedURL = directURL.resolvingSymlinksInPath().standardizedFileURL
        guard resolvedURL == directURL,
              resolvedURL.deletingLastPathComponent() == workspaceURL,
              isDescendant(resolvedURL, of: workspaceURL),
              directoryExists(resolvedURL) else { return nil }
        return resolvedURL
    }

    private static func isAllowedWorkspaceShape(_ url: URL) -> Bool {
        let path = url.path
        guard path != "/", path != "/Users", path != NSHomeDirectory() else { return false }
        let markers = [
            "config.yaml",
            ".env",
            "SOUL.md",
            "memory.md",
            "hermes-agent/hermes"
        ]
        if markers.contains(where: { fileManager.fileExists(atPath: url.appendingPathComponent($0).path) }) {
            return true
        }
        let directoryMarkers = ["skills", "cron", "profiles", "plugins"]
        return directoryMarkers.contains { directoryExists(url.appendingPathComponent($0, isDirectory: true)) }
    }

    private static func directoryExists(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
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
