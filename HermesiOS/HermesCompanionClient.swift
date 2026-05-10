//
//  HermesCompanionClient.swift
//  HermesiOS
//
//  Created by Codex on 05/05/2026.
//

import Foundation
import Observation

struct HermesCompanionSettings: Codable, Equatable {
    var apiURL = HermesHostEndpoints.webSocketURLString(host: defaultHermesMacHost, port: defaultHermesCompanionPort)
    var authenticationToken = ""
    var hermesWorkspacePath = "/Volumes/WDBlack4TB/Code/HermesiOS/.hermes"
}

struct HermesCompanionIdentityState: Codable, Equatable {
    var deviceID = ""
    var deviceName = ""
    var serverEndpoint = ""
    var issuedAt = Date()

    var isEnrolled: Bool {
        serverEndpoint.isEmpty == false
    }
}

struct HermesCompanionIncomingEnvelope: Codable {
    let id: String?
    let type: String
    let authenticationToken: String?
    let payload: HermesCompanionJSONValue?
}

struct HermesCompanionOutgoingEnvelope: Codable {
    let id: String?
    let ok: Bool
    let payload: HermesCompanionJSONValue?
    let error: HermesCompanionErrorPayload?
}

struct HermesCompanionErrorPayload: Codable {
    let code: String
    let message: String
}


struct HermesCompanionHelloResult: Codable {
    let protocolVersion: String
    let serverName: String
    let capabilities: [String]
}

struct HermesCompanionListTargetsResult: Codable {
    let targets: [HermesCompanionTargetSummary]
}

struct HermesCompanionListTargetsPayload: Codable {
    let workspacePath: String
    let profileName: String?
}

struct HermesCompanionTargetSummary: Codable, Identifiable, Equatable {
    let id: String
    let displayName: String
    let format: HermesCompanionTargetFormat
    let path: String
    let serviceID: String?
    let restartPolicy: HermesCompanionRestartPolicy
}

struct HermesCompanionReadTargetPayload: Codable {
    let targetID: String
    let workspacePath: String?
    let profileName: String?
}

struct HermesCompanionReadTargetResult: Codable, Equatable {
    let targetID: String
    let displayName: String
    let path: String
    let revision: String
    let content: String
    let format: HermesCompanionTargetFormat
}

struct HermesCompanionValidateTargetPayload: Codable {
    let targetID: String
    let content: String?
    let workspacePath: String?
    let profileName: String?
}

struct HermesCompanionValidateTargetResult: Codable, Equatable {
    let targetID: String
    let valid: Bool
    let revision: String?
    let diagnostics: [HermesCompanionValidationDiagnostic]
}

struct HermesCompanionWriteTargetPayload: Codable {
    let targetID: String
    let expectedRevision: String
    let content: String
    let createBackup: Bool
    let workspacePath: String?
    let profileName: String?
}

struct HermesCompanionWriteTargetResult: Codable {
    let targetID: String
    let revision: String
    let backupID: String?
    let diagnostics: [HermesCompanionValidationDiagnostic]
}

struct HermesCompanionServiceStatusPayload: Codable {
    let serviceID: String
}

struct HermesCompanionFileDownloadPayload: Codable {
    let path: String
}

struct HermesCompanionFileDownloadResult: Codable {
    let path: String
    let fileName: String
    let byteCount: Int
    let contentType: String
    let base64Data: String
}

struct HermesCompanionServiceStatusResult: Codable, Equatable {
    let serviceID: String
    let status: HermesCompanionManagedServiceStatus
    let output: String
}

struct HermesCompanionServiceRestartPayload: Codable {
    let serviceID: String
}

struct HermesCompanionServiceStartPayload: Codable {
    let serviceID: String
}

struct HermesCompanionServiceStopPayload: Codable {
    let serviceID: String
}

struct HermesCompanionServiceRestartResult: Codable {
    let serviceID: String
    let status: HermesCompanionManagedServiceStatus
    let output: String
}

struct HermesCompanionServiceStartResult: Codable {
    let serviceID: String
    let status: HermesCompanionManagedServiceStatus
    let output: String
}

struct HermesCompanionServiceStopResult: Codable {
    let serviceID: String
    let status: HermesCompanionManagedServiceStatus
    let output: String
}

struct HermesCompanionInstallationStatusPayload: Codable {
    let workspacePath: String
}

struct HermesCompanionInstallationUpdatePayload: Codable {
    let workspacePath: String
}

struct HermesCompanionInstallationMergePayload: Codable {
    let workspacePath: String
}

struct HermesCompanionInstallationReviewConflictsPayload: Codable {
    let workspacePath: String
}

struct HermesCompanionInstallationStatusResult: Codable, Equatable {
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

struct HermesCompanionInstallationOperationResult: Codable, Equatable {
    let status: HermesCompanionInstallationStatusResult
    let output: String
}

struct HermesCompanionListSkillsPayload: Codable {
    let workspacePath: String
}

struct HermesCompanionListSkillsResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let skills: [HermesCompanionSkillSummary]
}

struct HermesCompanionSetSkillStatePayload: Codable {
    let workspacePath: String
    let skillID: String
    let isEnabled: Bool
}

struct HermesCompanionSetSkillStateResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let skill: HermesCompanionSkillSummary
}

struct HermesCompanionSkillSummary: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let category: String
    let description: String
    let path: String
    let isEnabled: Bool
}

struct HermesCompanionEmptyPayload: Codable {}

struct HermesCompanionListMCPServersResult: Codable {
    let servers: [HermesCompanionMCPServerSummary]
    let output: String
}

enum HermesCompanionMCPServerTransport: String, Codable, CaseIterable, Identifiable {
    case stdio
    case streamableHTTP

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stdio: "Stdio"
        case .streamableHTTP: "Streamable HTTP"
        }
    }
}

struct HermesCompanionAddMCPServerPayload: Codable {
    let name: String
    let transport: HermesCompanionMCPServerTransport
    let command: String
    let arguments: String
    let url: String
    let bearerToken: String
}

struct HermesCompanionRemoveMCPServerPayload: Codable {
    let name: String
}

struct HermesCompanionMCPOperationResult: Codable {
    let serverName: String
    let output: String
    let servers: [HermesCompanionMCPServerSummary]
}

struct HermesCompanionMCPServerSummary: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let transport: String
    let tools: String
    let status: String
}

enum HermesCompanionLogKind: String, Codable, CaseIterable, Identifiable {
    case errors
    case gateway
    case agent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .errors: "ERRORS"
        case .gateway: "GATEWAY"
        case .agent: "AGENT"
        }
    }

    var path: String {
        switch self {
        case .errors: "/Users/laurent/.hermes/logs/errors.log"
        case .gateway: "/Users/laurent/.hermes/logs/gateway.log"
        case .agent: "/Users/laurent/.hermes/logs/agent.log"
        }
    }
}

struct HermesCompanionReadLogPayload: Codable {
    let log: HermesCompanionLogKind
    let lineCount: Int
}

struct HermesCompanionReadLogResult: Codable, Equatable {
    let log: HermesCompanionLogKind
    let label: String
    let path: String
    let requestedLineCount: Int
    let loadedLineCount: Int
    let content: String
    let fileExists: Bool
    let updatedAt: Date
}

struct HermesCompanionGatewayPlatformDefinition: Codable, Identifiable, Equatable {
    let key: String
    let label: String
    let description: String
    let fields: [String]

    var id: String { key }
}

struct HermesCompanionGatewayEnvFieldDefinition: Codable, Identifiable, Equatable {
    let key: String
    let label: String
    let type: String
    let hint: String

    var id: String { key }
    var isSecret: Bool { type == "password" }
}

struct HermesCompanionGatewayConfigPayload: Codable {
    let workspacePath: String
    let profileName: String?
}

struct HermesCompanionGatewayConfigResult: Codable, Equatable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let profileName: String
    let profilePath: String
    let envFilePath: String
    let configPath: String
    let gatewayRunning: Bool
    let env: [String: String]
    let platformEnabled: [String: Bool]
    let fields: [HermesCompanionGatewayEnvFieldDefinition]
    let platforms: [HermesCompanionGatewayPlatformDefinition]
}

struct HermesCompanionGatewayStatusPayload: Codable {
    let workspacePath: String
    let profileName: String?
}

struct HermesCompanionGatewayStatusResult: Codable, Equatable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let profileName: String
    let profilePath: String
    let running: Bool
    let output: String
    let error: String?
}

struct HermesCompanionSetGatewayRunningPayload: Codable {
    let workspacePath: String
    let profileName: String?
    let running: Bool
}

struct HermesCompanionGatewayOperationResult: Codable, Equatable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let profileName: String
    let profilePath: String
    let success: Bool
    let gatewayRunning: Bool
    let output: String
    let error: String?
    let config: HermesCompanionGatewayConfigResult?
}

struct HermesCompanionSetGatewayEnvPayload: Codable {
    let workspacePath: String
    let profileName: String?
    let key: String
    let value: String
}

struct HermesCompanionSetGatewayEnvResult: Codable, Equatable {
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

struct HermesCompanionSetGatewayPlatformPayload: Codable {
    let workspacePath: String
    let profileName: String?
    let platform: String
    let enabled: Bool
}

struct HermesCompanionSetGatewayPlatformResult: Codable, Equatable {
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

struct HermesCompanionRestartGatewayPayload: Codable {
    let workspacePath: String
    let profileName: String?
}

struct HermesCompanionListToolsetsPayload: Codable {
    let workspacePath: String
}

struct HermesCompanionListToolsetsResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let configPath: String
    let toolsets: [HermesCompanionToolsetInfo]
}

struct HermesCompanionSetToolsetEnabledPayload: Codable {
    let workspacePath: String
    let key: String
    let enabled: Bool
}

struct HermesCompanionSetToolsetEnabledResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let configPath: String
    let toolset: HermesCompanionToolsetInfo
}

struct HermesCompanionToolsetInfo: Codable, Identifiable, Equatable {
    let key: String
    let label: String
    let description: String
    let enabled: Bool

    var id: String { key }
}

struct HermesCompanionSavedModel: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let provider: String
    let model: String
    let baseURL: String
    let createdAt: Int64

    var createdAtDate: Date {
        Date(timeIntervalSince1970: TimeInterval(createdAt) / 1000)
    }
}

struct HermesCompanionListModelsPayload: Codable {
    let workspacePath: String
}

struct HermesCompanionListModelsResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let modelsFilePath: String
    let models: [HermesCompanionSavedModel]
}

struct HermesCompanionAddModelPayload: Codable {
    let workspacePath: String
    let name: String
    let provider: String
    let model: String
    let baseURL: String
}

struct HermesCompanionAddModelResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let modelsFilePath: String
    let model: HermesCompanionSavedModel
}

struct HermesCompanionUpdateModelPayload: Codable {
    let workspacePath: String
    let id: String
    let name: String
    let provider: String
    let model: String
    let baseURL: String
}

struct HermesCompanionUpdateModelResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let modelsFilePath: String
    let model: HermesCompanionSavedModel
}

struct HermesCompanionRemoveModelPayload: Codable {
    let workspacePath: String
    let id: String
}

struct HermesCompanionRemoveModelResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let modelsFilePath: String
    let removedModelID: String
}


struct HermesCompanionProviderEnvField: Codable, Identifiable, Equatable {
    let key: String
    let label: String
    let type: String
    let hint: String
    var id: String { key }
}

struct HermesCompanionProviderEnvSection: Codable, Identifiable, Equatable {
    let id: String
    let title: String
    let items: [HermesCompanionProviderEnvField]
}

struct HermesCompanionProviderOption: Codable, Identifiable, Equatable {
    let value: String
    let label: String
    var id: String { value }
}

struct HermesCompanionProviderModelConfig: Codable, Equatable {
    let provider: String
    let model: String
    let baseUrl: String
}

struct HermesCompanionRuntimeModelSlotConfig: Codable, Identifiable, Equatable {
    let id: String
    let label: String
    let section: String
    let key: String
    let provider: String
    let model: String
}

struct HermesCompanionProviderCredentialEntry: Codable, Identifiable, Equatable {
    let key: String
    let label: String
    var id: String { label + ":" + String(key.prefix(8)) }
}

struct HermesCompanionProvidersConfigPayload: Codable {
    let workspacePath: String
}

struct HermesCompanionProvidersConfigResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let envFilePath: String
    let configPath: String
    let authFilePath: String
    let env: [String: String]
    let modelConfig: HermesCompanionProviderModelConfig
    let delegationModelConfig: HermesCompanionRuntimeModelSlotConfig
    let auxiliaryModelConfigs: [HermesCompanionRuntimeModelSlotConfig]
    let credentialPool: [String: [HermesCompanionProviderCredentialEntry]]
    let sections: [HermesCompanionProviderEnvSection]
    let providerOptions: [HermesCompanionProviderOption]
}

struct HermesCompanionSetProviderEnvPayload: Codable {
    let workspacePath: String
    let key: String
    let value: String
}

struct HermesCompanionSetProviderEnvResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let key: String
    let value: String
    let envFilePath: String
}

struct HermesCompanionRemoveProviderEnvPayload: Codable {
    let workspacePath: String
    let key: String
}

struct HermesCompanionRemoveProviderEnvResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let key: String
    let envFilePath: String
    let env: [String: String]
}

struct HermesCompanionSetProviderModelConfigPayload: Codable {
    let workspacePath: String
    let provider: String
    let model: String
    let baseUrl: String
}

struct HermesCompanionSetProviderModelConfigResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let configPath: String
    let modelConfig: HermesCompanionProviderModelConfig
}

struct HermesCompanionSetRuntimeModelSlotPayload: Codable {
    let workspacePath: String
    let section: String
    let key: String
    let provider: String
    let model: String
}

struct HermesCompanionSetRuntimeModelSlotResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let configPath: String
    let slot: HermesCompanionRuntimeModelSlotConfig
}

struct HermesCompanionSetCredentialPoolPayload: Codable {
    let workspacePath: String
    let provider: String
    let entries: [HermesCompanionProviderCredentialEntry]
}

struct HermesCompanionSetCredentialPoolResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let authFilePath: String
    let credentialPool: [String: [HermesCompanionProviderCredentialEntry]]
}


struct HermesCompanionMemoryEntry: Codable, Identifiable, Equatable {
    let index: Int
    let content: String
    var id: Int { index }
}

struct HermesCompanionMemoryFileInfo: Codable, Equatable {
    let content: String
    let exists: Bool
    let lastModified: Int?
    let sizeOnDiskBytes: Int64?
    let entries: [HermesCompanionMemoryEntry]?
    let charCount: Int
    let charLimit: Int
}

struct HermesCompanionMemoryStats: Codable, Equatable {
    let totalSessions: Int
    let totalMessages: Int
}

struct HermesCompanionMemoryProviderInfo: Codable, Identifiable, Equatable {
    let name: String
    let description: String
    let installed: Bool
    let active: Bool
    let envVars: [String]
    var id: String { name }
}

struct HermesCompanionMemoryConfigPayload: Codable {
    let workspacePath: String
}

struct HermesCompanionMemoryConfigResult: Codable, Equatable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let memoryFilePath: String
    let userFilePath: String
    let configPath: String
    let envFilePath: String
    let configSizeOnDiskBytes: Int64?
    let envSizeOnDiskBytes: Int64?
    let memory: HermesCompanionMemoryFileInfo
    let user: HermesCompanionMemoryFileInfo
    let stats: HermesCompanionMemoryStats
    let provider: String
    let providers: [HermesCompanionMemoryProviderInfo]
    let env: [String: String]
}

struct HermesCompanionAddMemoryEntryPayload: Codable {
    let workspacePath: String
    let content: String
}

struct HermesCompanionUpdateMemoryEntryPayload: Codable {
    let workspacePath: String
    let index: Int
    let content: String
}

struct HermesCompanionRemoveMemoryEntryPayload: Codable {
    let workspacePath: String
    let index: Int
}

struct HermesCompanionWriteUserProfilePayload: Codable {
    let workspacePath: String
    let content: String
}

struct HermesCompanionMemoryOperationResult: Codable, Equatable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let success: Bool
    let error: String?
    let memory: HermesCompanionMemoryConfigResult?
}

struct HermesCompanionSetMemoryProviderPayload: Codable {
    let workspacePath: String
    let provider: String
}

struct HermesCompanionSetMemoryProviderResult: Codable, Equatable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let configPath: String
    let provider: String
    let providers: [HermesCompanionMemoryProviderInfo]
}

struct HermesCompanionSetMemoryEnvPayload: Codable {
    let workspacePath: String
    let key: String
    let value: String
}

struct HermesCompanionSetMemoryEnvResult: Codable, Equatable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let envFilePath: String
    let key: String
    let value: String
}

struct HermesCompanionSupermemoryManagementPayload: Codable {
    let workspacePath: String
}

struct HermesCompanionSupermemoryManagementResult: Codable, Equatable {
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

enum HermesCompanionKnowledgeEraserItemKind: String, Codable, Equatable {
    case memoryEntry
    case userProfileBlock
    case skillBlock

    var label: String {
        switch self {
        case .memoryEntry: "Memory"
        case .userProfileBlock: "User profile"
        case .skillBlock: "Skill"
        }
    }
}

struct HermesCompanionKnowledgeEraserScanPayload: Codable {
    let workspacePath: String
    let topic: String
}

struct HermesCompanionKnowledgeEraserErasePayload: Codable {
    let workspacePath: String
    let topic: String
    let selectedItemIDs: [String]
}

struct HermesCompanionKnowledgeEraserItem: Codable, Identifiable, Equatable {
    let id: String
    let kind: HermesCompanionKnowledgeEraserItemKind
    let title: String
    let path: String
    let location: String
    let preview: String
    let content: String
    let confidence: Double
}

struct HermesCompanionKnowledgeEraserScanResult: Codable, Equatable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let topic: String
    let scannedAt: Date
    let items: [HermesCompanionKnowledgeEraserItem]
}

struct HermesCompanionKnowledgeEraserEraseResult: Codable, Equatable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let topic: String
    let erasedAt: Date
    let archivePath: String
    let erasedItemIDs: [String]
    let skippedItemIDs: [String]
    let remainingItems: [HermesCompanionKnowledgeEraserItem]
}

struct HermesCompanionProfileInfo: Codable, Identifiable, Equatable {
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

struct HermesCompanionListProfilesPayload: Codable {
    let workspacePath: String
}

struct HermesCompanionListProfilesResult: Codable, Equatable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let profilesDirectoryPath: String
    let activeProfileName: String
    let profiles: [HermesCompanionProfileInfo]
}

struct HermesCompanionCreateProfilePayload: Codable {
    let workspacePath: String
    let name: String
    let provider: String
    let model: String
    let baseUrl: String
    let createEnv: Bool
    let createSoul: Bool
    let cloneSkills: Bool
}

struct HermesCompanionEditProfilePayload: Codable {
    let workspacePath: String
    let originalName: String
    let name: String
    let provider: String
    let model: String
    let baseUrl: String
    let createEnv: Bool
    let createSoul: Bool
}

struct HermesCompanionProfileOperationPayload: Codable {
    let workspacePath: String
    let name: String
}

struct HermesCompanionProfileOperationResult: Codable, Equatable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let success: Bool
    let output: String
    let error: String?
    let activeProfileName: String
    let profiles: [HermesCompanionProfileInfo]
}

struct HermesCompanionScheduleRepeatInfo: Codable, Equatable {
    let times: Int?
    let completed: Int
}

struct HermesCompanionScheduleCronJob: Codable, Identifiable, Equatable {
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
    let repeatInfo: HermesCompanionScheduleRepeatInfo?
    let deliver: [String]
    let skills: [String]
    let script: String?
}

struct HermesCompanionListSchedulesPayload: Codable {
    let workspacePath: String
    let includeDisabled: Bool
}

struct HermesCompanionListSchedulesResult: Codable, Equatable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let jobsFilePath: String
    let jobs: [HermesCompanionScheduleCronJob]
}

struct HermesCompanionCreateSchedulePayload: Codable {
    let workspacePath: String
    let schedule: String
    let prompt: String?
    let name: String?
    let deliver: String?
}

struct HermesCompanionScheduleOperationPayload: Codable {
    let workspacePath: String
    let jobID: String
}

struct HermesCompanionScheduleOperationResult: Codable, Equatable {
    let workspacePath: String
    let resolvedWorkspacePath: String
    let jobsFilePath: String
    let success: Bool
    let output: String
    let error: String?
    let jobs: [HermesCompanionScheduleCronJob]
}


struct HermesCompanionValidationDiagnostic: Codable, Identifiable, Equatable {
    let id: UUID
    let severity: HermesCompanionValidationSeverity
    let message: String
    let validator: String
}

enum HermesCompanionValidationSeverity: String, Codable, Equatable {
    case error
    case warning
    case info
}

enum HermesCompanionTargetFormat: String, Codable, Equatable {
    case toml
    case json
    case yaml
    case text
}

enum HermesCompanionRestartPolicy: String, Codable, Equatable {
    case manual
    case suggested
    case automatic
}

enum HermesCompanionManagedServiceStatus: String, Codable, Equatable {
    case running
    case stopped
    case unknown
    case restarted
    case started
}

enum HermesCompanionJSONValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: HermesCompanionJSONValue])
    case array([HermesCompanionJSONValue])
    case null

    static func encode<T: Encodable>(_ value: T) -> HermesCompanionJSONValue? {
        guard
            let data = try? JSONEncoder().encode(value),
            let json = try? JSONDecoder().decode(HermesCompanionJSONValue.self, from: data)
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
        } else if let object = try? container.decode([String: HermesCompanionJSONValue].self) {
            self = .object(object)
        } else if let array = try? container.decode([HermesCompanionJSONValue].self) {
            self = .array(array)
        } else {
            throw DecodingError.typeMismatch(
                HermesCompanionJSONValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported companion JSON value.")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

enum HermesCompanionClientError: LocalizedError {
    case invalidURL
    case invalidResponse
    case serverRejected(String)
    case missingPayload
    case missingAuthenticationToken
    case invalidAuthenticationTokenLength
    case notEnrolled

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "The companion API URL is invalid."
        case .invalidResponse:
            "The companion returned an invalid authentication response."
        case .serverRejected(let message):
            message
        case .missingPayload:
            "The companion authentication response did not include a payload."
        case .missingAuthenticationToken:
            "Enter the 256-character Host Companion API key before verifying the connection."
        case .invalidAuthenticationTokenLength:
            "The Host Companion API key must be exactly 256 characters."
        case .notEnrolled:
            "Verify the Host Companion API key before using runtime controls."
        }
    }
}

@MainActor
@Observable
final class HermesCompanionEnrollmentSession {
    var isEnrolling = false
    var connectionStatus = "Not Authenticated"
    var lastErrorMessage = ""
    var identityState: HermesCompanionIdentityState

    private var enrollmentTask: Task<Void, Never>?

    init() {
        let persistedState = HermesSettingsPersistence.loadCompanionIdentityState()
        identityState = persistedState
        if persistedState.isEnrolled {
            connectionStatus = "Authenticated"
        }
    }

    func enroll(settings: HermesCompanionSettings) {
        enrollmentTask?.cancel()
        enrollmentTask = Task {
            await runEnrollment(settings: settings)
        }
    }

    func clearIdentity() {
        enrollmentTask?.cancel()
        enrollmentTask = nil
        identityState = HermesCompanionIdentityState()
        connectionStatus = "Not Authenticated"
        lastErrorMessage = ""
        HermesSettingsPersistence.clearCompanionIdentity()
    }

    private func runEnrollment(settings: HermesCompanionSettings) async {
        let token = settings.authenticationToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard token.isEmpty == false else {
            lastErrorMessage = HermesCompanionClientError.missingAuthenticationToken.localizedDescription
            connectionStatus = "Authentication Failed"
            return
        }
        guard token.count == HermesCompanionSessionFactory.expectedAPIKeyLength else {
            lastErrorMessage = HermesCompanionClientError.invalidAuthenticationTokenLength.localizedDescription
            connectionStatus = "Authentication Failed"
            return
        }

        guard let url = URL(string: settings.apiURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            lastErrorMessage = HermesCompanionClientError.invalidURL.localizedDescription
            connectionStatus = "Authentication Failed"
            return
        }

        isEnrolling = true
        lastErrorMessage = ""
        connectionStatus = "Verifying Token"

        do {
            let result: HermesCompanionHelloResult = try await HermesCompanionSessionFactory.request(
                url: url,
                authenticationToken: token,
                type: "hello",
                payload: Optional<HermesCompanionEmptyPayload>.none
            )
            let newState = HermesCompanionIdentityState(
                deviceID: "token-auth",
                deviceName: result.serverName,
                serverEndpoint: url.absoluteString,
                issuedAt: Date()
            )
            HermesSettingsPersistence.saveCompanionAuthenticationState(newState)
            identityState = newState
            connectionStatus = "Authenticated"
        } catch {
            lastErrorMessage = error.localizedDescription
            connectionStatus = "Authentication Failed"
        }

        isEnrolling = false
    }

}

@MainActor
@Observable
final class HermesCompanionRuntimeSession {
    var targets: [HermesCompanionTargetSummary] = []
    var selectedTargetID = ""
    var targetContent = ""
    var currentRevision = ""
    var diagnostics: [HermesCompanionValidationDiagnostic] = []
    var companionConfigProfileName = "default"
    var linkedServiceStatus = ""
    var linkedServiceOutput = ""
    var macServiceStatuses: [String: HermesCompanionServiceStatusResult] = [:]
    var macServiceOutputs: [String: String] = [:]
    var hermesInstallationStatus: HermesCompanionInstallationStatusResult?
    var hermesInstallationStatusMessage = "Not checked"
    var hermesInstallationStatusError = ""
    var hermesInstallationOperationOutput = ""
    var isCheckingHermesInstallation = false
    var isUpdatingHermesInstallation = false
    var connectionStatus = "Idle"
    var lastErrorMessage = ""
    var isBusy = false
    var isKickstartingRuntime = false
    var runtimeLoadedSectionIDs: Set<String> = []
    var hermesSkills: [HermesCompanionSkillSummary] = []
    var hermesMCPServers: [HermesCompanionMCPServerSummary] = []
    var mcpListOutput = ""
    var mcpOperationOutput = ""
    var observabilityLogKind: HermesCompanionLogKind = .errors
    var observabilityLineCount = 200
    var observabilityLogContent = ""
    var observabilityLogPath = HermesCompanionLogKind.errors.path
    var observabilityLoadedLineCount = 0
    var observabilityUpdatedAt: Date?
    var isLoadingObservabilityLog = false
    var resolvedHermesWorkspacePath = ""

    private var observabilityLogTask: Task<Void, Never>?
    var hermesToolsets: [HermesCompanionToolsetInfo] = []
    var toolsetsConfigPath = ""
    var hermesModels: [HermesCompanionSavedModel] = []
    var modelsFilePath = ""
    var providerEnv: [String: String] = [:]
    var providerSections: [HermesCompanionProviderEnvSection] = []
    var providerOptions: [HermesCompanionProviderOption] = []
    var providerCredentialPool: [String: [HermesCompanionProviderCredentialEntry]] = [:]
    var providerModelConfig = HermesCompanionProviderModelConfig(provider: "auto", model: "", baseUrl: "")
    var delegationModelConfig = HermesCompanionRuntimeModelSlotConfig(id: "delegation", label: "Delegation", section: "delegation", key: "delegation", provider: "", model: "")
    var auxiliaryModelConfigs: [HermesCompanionRuntimeModelSlotConfig] = []
    var providerEnvFilePath = ""
    var providerConfigPath = ""
    var providerAuthFilePath = ""
    var memoryConfig: HermesCompanionMemoryConfigResult?
    var memoryEntries: [HermesCompanionMemoryEntry] = []
    var memoryUserContent = ""
    var memoryProvider = ""
    var memoryProviders: [HermesCompanionMemoryProviderInfo] = []
    var memoryEnv: [String: String] = [:]
    var memoryFilePath = ""
    var memoryUserFilePath = ""
    var memoryConfigPath = ""
    var memoryEnvFilePath = ""
    var supermemoryLastResult: HermesCompanionSupermemoryManagementResult?
    var supermemoryOperationOutput = ""
    var knowledgeEraserTopic = ""
    var knowledgeEraserItems: [HermesCompanionKnowledgeEraserItem] = []
    var knowledgeEraserSelectedItemIDs: Set<String> = []
    var knowledgeEraserArchivePath = ""
    var knowledgeEraserOperationOutput = ""
    var knowledgeEraserLastScanAt: Date?
    var schedules: [HermesCompanionScheduleCronJob] = []
    var schedulesFilePath = ""
    var profiles: [HermesCompanionProfileInfo] = []
    var profilesDirectoryPath = ""
    var activeProfileName = "default"
    var profileOperationOutput = ""
    var gatewayConfig: HermesCompanionGatewayConfigResult?
    var gatewayRunning = false
    var gatewayEnv: [String: String] = [:]
    var gatewayPlatformEnabled: [String: Bool] = [:]
    var gatewayFields: [HermesCompanionGatewayEnvFieldDefinition] = []
    var gatewayPlatforms: [HermesCompanionGatewayPlatformDefinition] = []
    var gatewayProfileName = "default"
    var gatewayProfilePath = ""
    var gatewayEnvFilePath = ""
    var gatewayConfigPath = ""
    var gatewayOperationOutput = ""

    var selectedTarget: HermesCompanionTargetSummary? {
        targets.first(where: { $0.id == selectedTargetID })
    }

    func hasRuntimeSectionLoaded(_ id: String) -> Bool {
        runtimeLoadedSectionIDs.contains(id)
    }

    private func markRuntimeSectionLoaded(_ id: String) {
        runtimeLoadedSectionIDs.insert(id)
    }

    func kickstartRuntimeSections(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        Task {
            guard identityState.isEnrolled else {
                self.lastErrorMessage = "Enroll Host Companion before kickstarting runtime sections."
                self.connectionStatus = "Companion Not Enrolled"
                return
            }

            self.isKickstartingRuntime = true
            self.isBusy = true
            self.lastErrorMessage = ""
            defer {
                self.isKickstartingRuntime = false
                self.isBusy = false
            }

            await self.kickstartSection("companion", status: "Refreshing Companion") {
                try await self.refreshTargetsImmediately(settings: settings, identityState: identityState)
            }
            await self.kickstartSection("skills", status: "Refreshing Skills") {
                try await self.refreshHermesSkillsImmediately(settings: settings, identityState: identityState)
            }
            await self.kickstartSection("profiles", status: "Refreshing Profiles") {
                try await self.refreshProfilesImmediately(settings: settings, identityState: identityState)
            }
            await self.kickstartSection("gateway", status: "Refreshing Messaging") {
                try await self.refreshGatewayConfigImmediately(settings: settings, identityState: identityState)
            }
            await self.kickstartSection("tools", status: "Refreshing Tools") {
                try await self.refreshHermesToolsetsImmediately(settings: settings, identityState: identityState)
            }
            await self.kickstartSection("mcpServers", status: "Refreshing MCP Servers") {
                try await self.refreshHermesMCPServersImmediately(settings: settings, identityState: identityState)
            }
            await self.kickstartSection("providers", status: "Refreshing Providers") {
                try await self.refreshProvidersConfigImmediately(settings: settings, identityState: identityState)
            }
            await self.kickstartSection("memory", status: "Refreshing Memory") {
                try await self.refreshMemoryConfigImmediately(settings: settings, identityState: identityState)
            }
            self.markRuntimeSectionLoaded("knowledgeEraser")
            await self.kickstartSection("schedules", status: "Refreshing Schedules") {
                try await self.refreshSchedulesImmediately(settings: settings, identityState: identityState)
            }
            await self.kickstartSection("models", status: "Refreshing Models") {
                try await self.refreshHermesModelsImmediately(settings: settings, identityState: identityState)
            }
            await self.kickstartSection("observability", status: "Refreshing Observability") {
                try await self.refreshHermesLogImmediately(settings: settings, identityState: identityState, lineCount: 200)
            }
            self.connectionStatus = "Runtime Refreshed"
        }
    }

    private func kickstartSection(_ id: String, status: String, operation: @escaping @MainActor () async throws -> Void) async {
        connectionStatus = status
        do {
            try await operation()
            markRuntimeSectionLoaded(id)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func refreshTargets(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Loading Targets"
            try await self.refreshTargetsImmediately(settings: settings, identityState: identityState)
            self.markRuntimeSectionLoaded("companion")
            self.connectionStatus = self.targets.isEmpty ? "No Targets" : "Targets Loaded"
        }
    }

    private func refreshTargetsImmediately(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) async throws {
        let result: HermesCompanionListTargetsResult = try await HermesCompanionSessionFactory.request(
            settings: settings,
            state: identityState,
            type: "list_targets",
            payload: HermesCompanionListTargetsPayload(workspacePath: settings.hermesWorkspacePath, profileName: companionConfigProfileName)
        )
        targets = result.targets
        if selectedTargetID.isEmpty || targets.contains(where: { $0.id == selectedTargetID }) == false {
            selectedTargetID = targets.first?.id ?? ""
        }
        if selectedTarget != nil {
            try await loadSelectedTarget(settings: settings, identityState: identityState)
        }
    }

    func selectCompanionProfile(name: String, settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        companionConfigProfileName = name.isEmpty ? "default" : name
        selectedTargetID = "hermes-config"
        targetContent = ""
        currentRevision = ""
        diagnostics = []
        refreshTargets(settings: settings, identityState: identityState)
    }

    func refreshCompanionProfileConfig(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Loading Profile Config"
            try await self.refreshProfilesImmediately(settings: settings, identityState: identityState)
            if self.selectedTargetID.isEmpty {
                self.selectedTargetID = "hermes-config"
            }
            try await self.refreshTargetsImmediately(settings: settings, identityState: identityState)
            self.markRuntimeSectionLoaded("companion")
            self.connectionStatus = "Profile Config Loaded"
        }
    }

    func loadSelectedTarget(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            try await self.loadSelectedTarget(settings: settings, identityState: identityState)
        }
    }

    func validateSelectedTarget(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            guard let selectedTarget = self.selectedTarget else { return }
            self.connectionStatus = "Validating \(selectedTarget.displayName)"
            let result: HermesCompanionValidateTargetResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "validate_target",
                payload: HermesCompanionValidateTargetPayload(
                    targetID: selectedTarget.id,
                    content: self.targetContent,
                    workspacePath: settings.hermesWorkspacePath,
                    profileName: self.companionConfigProfileName
                )
            )
            self.diagnostics = result.diagnostics
            self.connectionStatus = result.valid ? "Validation Passed" : "Validation Failed"
        }
    }

    func saveSelectedTarget(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            guard let selectedTarget = self.selectedTarget else { return }
            self.connectionStatus = "Saving \(selectedTarget.displayName)"
            let result: HermesCompanionWriteTargetResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "write_target",
                payload: HermesCompanionWriteTargetPayload(
                    targetID: selectedTarget.id,
                    expectedRevision: self.currentRevision,
                    content: self.targetContent,
                    createBackup: true,
                    workspacePath: settings.hermesWorkspacePath,
                    profileName: self.companionConfigProfileName
                )
            )
            self.diagnostics = result.diagnostics
            self.currentRevision = result.revision
            self.connectionStatus = "Saved"
            try await self.refreshLinkedServiceStatus(settings: settings, identityState: identityState)
        }
    }

    func refreshLinkedServiceStatus(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            try await self.refreshLinkedServiceStatus(settings: settings, identityState: identityState)
        }
    }

    func restartLinkedService(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            guard let serviceID = self.selectedTarget?.serviceID, serviceID.isEmpty == false else { return }
            self.connectionStatus = "Restarting \(serviceID)"
            let result: HermesCompanionServiceRestartResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "service_restart",
                payload: HermesCompanionServiceRestartPayload(serviceID: serviceID)
            )
            self.linkedServiceStatus = result.status.rawValue.capitalized
            self.linkedServiceOutput = result.output
            self.connectionStatus = "Service Restarted"
        }
    }

    func restartAPIService(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Restarting API Server"
            let result: HermesCompanionServiceRestartResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "service_restart",
                payload: HermesCompanionServiceRestartPayload(serviceID: "hermesd")
            )
            self.linkedServiceStatus = result.status.rawValue.capitalized
            self.linkedServiceOutput = result.output
            self.connectionStatus = "API Server Restarted"
        }
    }

    func refreshMacServices(_ serviceIDs: [String], settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Checking Mac Services"
            for serviceID in serviceIDs {
                let result: HermesCompanionServiceStatusResult = try await HermesCompanionSessionFactory.request(
                    settings: settings,
                    state: identityState,
                    type: "service_status",
                    payload: HermesCompanionServiceStatusPayload(serviceID: serviceID)
                )
                self.macServiceStatuses[serviceID] = result
                self.macServiceOutputs[serviceID] = result.output
            }
            self.connectionStatus = "Mac Services Updated"
        }
    }

    func startMacService(_ serviceID: String, settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Starting \(serviceID)"
            let result: HermesCompanionServiceStartResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "service_start",
                payload: HermesCompanionServiceStartPayload(serviceID: serviceID)
            )
            self.macServiceOutputs[serviceID] = result.output
            try await self.refreshMacService(serviceID, settings: settings, identityState: identityState)
            self.connectionStatus = "Service Started"
        }
    }

    func stopMacService(_ serviceID: String, settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Stopping \(serviceID)"
            let result: HermesCompanionServiceStopResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "service_stop",
                payload: HermesCompanionServiceStopPayload(serviceID: serviceID)
            )
            self.macServiceOutputs[serviceID] = result.output
            try await self.refreshMacService(serviceID, settings: settings, identityState: identityState)
            self.connectionStatus = "Service Stopped"
        }
    }

    private func refreshMacService(_ serviceID: String, settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) async throws {
        let result: HermesCompanionServiceStatusResult = try await HermesCompanionSessionFactory.request(
            settings: settings,
            state: identityState,
            type: "service_status",
            payload: HermesCompanionServiceStatusPayload(serviceID: serviceID)
        )
        macServiceStatuses[serviceID] = result
        if macServiceOutputs[serviceID, default: ""].isEmpty {
            macServiceOutputs[serviceID] = result.output
        }
    }

    func refreshHermesInstallationStatusLoop(
        settings: HermesCompanionSettings,
        identityState: HermesCompanionIdentityState,
        interval: Duration = .seconds(3600)
    ) async {
        while !Task.isCancelled {
            await refreshHermesInstallationStatus(settings: settings, identityState: identityState)
            do {
                try await Task.sleep(for: interval)
            } catch {
                return
            }
        }
    }

    func refreshHermesInstallationStatus(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) async {
        guard identityState.isEnrolled else { return }
        isCheckingHermesInstallation = true
        hermesInstallationStatusError = ""
        do {
            let result: HermesCompanionInstallationStatusResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "hermes_installation_status",
                payload: HermesCompanionInstallationStatusPayload(workspacePath: settings.hermesWorkspacePath)
            )
            applyHermesInstallationStatus(result)
        } catch {
            hermesInstallationStatusError = error.localizedDescription
            hermesInstallationStatusMessage = "Unavailable"
        }
        isCheckingHermesInstallation = false
    }

    func updateHermesInstallation(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            guard identityState.isEnrolled else { return }
            self.isUpdatingHermesInstallation = true
            self.hermesInstallationStatusError = ""
            self.hermesInstallationOperationOutput = ""
            self.connectionStatus = "Updating Hermes Installation"
            do {
                let result: HermesCompanionInstallationOperationResult = try await HermesCompanionSessionFactory.request(
                    settings: settings,
                    state: identityState,
                    type: "hermes_installation_update",
                    payload: HermesCompanionInstallationUpdatePayload(workspacePath: settings.hermesWorkspacePath)
                )
                self.applyHermesInstallationStatus(result.status)
                self.hermesInstallationOperationOutput = result.output
                self.connectionStatus = "Hermes Update Ready for Review"
            } catch {
                self.hermesInstallationStatusError = error.localizedDescription
                self.hermesInstallationStatusMessage = "Update Failed"
                self.connectionStatus = "Hermes Update Failed"
            }
            self.isUpdatingHermesInstallation = false
        }
    }

    func reviewHermesInstallationConflicts(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            guard identityState.isEnrolled else { return }
            self.isUpdatingHermesInstallation = true
            self.hermesInstallationStatusError = ""
            self.hermesInstallationOperationOutput = ""
            self.connectionStatus = "Reviewing Hermes Conflicts"
            do {
                let result: HermesCompanionInstallationOperationResult = try await HermesCompanionSessionFactory.request(
                    settings: settings,
                    state: identityState,
                    type: "hermes_installation_review_conflicts",
                    payload: HermesCompanionInstallationReviewConflictsPayload(workspacePath: settings.hermesWorkspacePath)
                )
                self.applyHermesInstallationStatus(result.status)
                self.hermesInstallationOperationOutput = result.output
                self.connectionStatus = "Hermes Conflicts Reviewed and Merged"
            } catch {
                self.hermesInstallationStatusError = error.localizedDescription
                self.hermesInstallationStatusMessage = "Conflict Review Failed"
                self.connectionStatus = "Hermes Conflict Review Failed"
            }
            self.isUpdatingHermesInstallation = false
        }
    }

    func mergeReviewedHermesInstallationUpdate(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            guard identityState.isEnrolled else { return }
            self.isUpdatingHermesInstallation = true
            self.hermesInstallationStatusError = ""
            self.hermesInstallationOperationOutput = ""
            self.connectionStatus = "Merging Hermes Update"
            do {
                let result: HermesCompanionInstallationOperationResult = try await HermesCompanionSessionFactory.request(
                    settings: settings,
                    state: identityState,
                    type: "hermes_installation_merge_reviewed_update",
                    payload: HermesCompanionInstallationMergePayload(workspacePath: settings.hermesWorkspacePath)
                )
                self.applyHermesInstallationStatus(result.status)
                self.hermesInstallationOperationOutput = result.output
                self.connectionStatus = "Hermes Update Merged"
            } catch {
                self.hermesInstallationStatusError = error.localizedDescription
                self.hermesInstallationStatusMessage = "Merge Failed"
                self.connectionStatus = "Hermes Merge Failed"
            }
            self.isUpdatingHermesInstallation = false
        }
    }

    private func applyHermesInstallationStatus(_ result: HermesCompanionInstallationStatusResult) {
        hermesInstallationStatus = result
        resolvedHermesWorkspacePath = result.resolvedWorkspacePath
        hermesInstallationStatusMessage = Self.hermesInstallationStatusMessage(for: result)
        if result.lastUpdateOutput.isEmpty == false {
            hermesInstallationOperationOutput = result.lastUpdateOutput
        }
    }

    private static func hermesInstallationStatusMessage(for result: HermesCompanionInstallationStatusResult) -> String {
        if result.isUpdateBlocked {
            let conflictCount = result.conflictFiles.count
            if conflictCount > 0 {
                return "Review \(conflictCount) conflict\(conflictCount == 1 ? "" : "s") before merge"
            }
            return "Update fetched; review before merge"
        }
        if result.behindBy == 0 {
            return "Up to date"
        }
        return "\(result.behindBy) commit\(result.behindBy == 1 ? "" : "s") behind official main"
    }

    private func loadSelectedTarget(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) async throws {
        guard let selectedTarget else { return }
        connectionStatus = "Reading \(selectedTarget.displayName)"
        let result: HermesCompanionReadTargetResult = try await HermesCompanionSessionFactory.request(
            settings: settings,
            state: identityState,
            type: "read_target",
            payload: HermesCompanionReadTargetPayload(
                targetID: selectedTarget.id,
                workspacePath: settings.hermesWorkspacePath,
                profileName: companionConfigProfileName
            )
        )
        targetContent = result.content
        currentRevision = result.revision
        diagnostics = []
        connectionStatus = "Target Loaded"
        try await refreshLinkedServiceStatus(settings: settings, identityState: identityState)
    }

    private func refreshLinkedServiceStatus(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) async throws {
        guard let serviceID = selectedTarget?.serviceID, serviceID.isEmpty == false else {
            linkedServiceStatus = "No Service"
            linkedServiceOutput = ""
            return
        }
        do {
            let result: HermesCompanionServiceStatusResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "service_status",
                payload: HermesCompanionServiceStatusPayload(serviceID: serviceID)
            )
            linkedServiceStatus = result.status.rawValue.capitalized
            linkedServiceOutput = result.output
        } catch {
            linkedServiceStatus = "Unavailable"
            linkedServiceOutput = error.localizedDescription
        }
    }

    private func run(_ operation: @escaping @MainActor () async throws -> Void) {
        Task {
            isBusy = true
            lastErrorMessage = ""
            do {
                try await operation()
            } catch {
                lastErrorMessage = error.localizedDescription
                connectionStatus = "Failed"
            }
            isBusy = false
        }
    }

    func refreshHermesSkills(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Loading Skills"
            try await self.refreshHermesSkillsImmediately(settings: settings, identityState: identityState)
            self.markRuntimeSectionLoaded("skills")
            self.connectionStatus = self.hermesSkills.isEmpty ? "No Skills Found" : "Skills Loaded"
        }
    }

    private func refreshHermesSkillsImmediately(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) async throws {
        let result: HermesCompanionListSkillsResult = try await HermesCompanionSessionFactory.request(
            settings: settings,
            state: identityState,
            type: "list_skills",
            payload: HermesCompanionListSkillsPayload(workspacePath: settings.hermesWorkspacePath)
        )
        hermesSkills = result.skills
        resolvedHermesWorkspacePath = result.resolvedWorkspacePath
    }

    func setHermesSkillState(
        skillID: String,
        isEnabled: Bool,
        settings: HermesCompanionSettings,
        identityState: HermesCompanionIdentityState
    ) {
        let previousSkills = hermesSkills
        if let index = hermesSkills.firstIndex(where: { $0.id == skillID }) {
            hermesSkills[index] = HermesCompanionSkillSummary(
                id: hermesSkills[index].id,
                name: hermesSkills[index].name,
                category: hermesSkills[index].category,
                description: hermesSkills[index].description,
                path: hermesSkills[index].path,
                isEnabled: isEnabled
            )
        }

        Task {
            isBusy = true
            lastErrorMessage = ""
            connectionStatus = isEnabled ? "Enabling Skill" : "Disabling Skill"
            do {
                let result: HermesCompanionSetSkillStateResult = try await HermesCompanionSessionFactory.request(
                    settings: settings,
                    state: identityState,
                    type: "set_skill_state",
                    payload: HermesCompanionSetSkillStatePayload(
                        workspacePath: settings.hermesWorkspacePath,
                        skillID: skillID,
                        isEnabled: isEnabled
                    )
                )
                if let index = hermesSkills.firstIndex(where: { $0.id == result.skill.id }) {
                    hermesSkills[index] = result.skill
                }
                resolvedHermesWorkspacePath = result.resolvedWorkspacePath
                connectionStatus = "Skills Updated"
            } catch {
                hermesSkills = previousSkills
                lastErrorMessage = error.localizedDescription
                connectionStatus = "Skills Sync Failed"
            }
            isBusy = false
        }
    }

    func refreshGatewayConfig(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Loading Messaging"
            try await self.refreshGatewayConfigImmediately(settings: settings, identityState: identityState)
            self.markRuntimeSectionLoaded("gateway")
            self.connectionStatus = "Messaging Loaded"
        }
    }

    private func refreshGatewayConfigImmediately(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) async throws {
        let result: HermesCompanionGatewayConfigResult = try await HermesCompanionSessionFactory.request(
            settings: settings,
            state: identityState,
            type: "get_gateway_config",
            payload: HermesCompanionGatewayConfigPayload(workspacePath: settings.hermesWorkspacePath, profileName: activeProfileName)
        )
        applyGatewayConfig(result)
    }

    func refreshGatewayStatus(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            let result: HermesCompanionGatewayStatusResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "gateway_status",
                payload: HermesCompanionGatewayStatusPayload(workspacePath: settings.hermesWorkspacePath, profileName: self.gatewayProfileName.isEmpty ? self.activeProfileName : self.gatewayProfileName)
            )
            self.gatewayRunning = result.running
            self.gatewayProfileName = result.profileName
            self.gatewayProfilePath = result.profilePath
            self.gatewayOperationOutput = result.output
            self.connectionStatus = result.running ? "Gateway Running" : "Gateway Stopped"
        }
    }

    func setGatewayRunning(_ running: Bool, settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = running ? "Starting Gateway" : "Stopping Gateway"
            let result: HermesCompanionGatewayOperationResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "set_gateway_running",
                payload: HermesCompanionSetGatewayRunningPayload(workspacePath: settings.hermesWorkspacePath, profileName: self.gatewayProfileName.isEmpty ? self.activeProfileName : self.gatewayProfileName, running: running)
            )
            self.applyGatewayOperation(result)
            self.connectionStatus = result.gatewayRunning ? "Gateway Running" : "Gateway Stopped"
        }
    }

    func restartGateway(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Restarting Gateway"
            let result: HermesCompanionGatewayOperationResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "restart_gateway",
                payload: HermesCompanionRestartGatewayPayload(workspacePath: settings.hermesWorkspacePath, profileName: self.gatewayProfileName.isEmpty ? self.activeProfileName : self.gatewayProfileName)
            )
            self.applyGatewayOperation(result)
            self.connectionStatus = result.gatewayRunning ? "Gateway Restarted" : "Gateway Restarted / Stopped"
        }
    }

    func setGatewayEnvValue(key: String, value: String, settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        gatewayEnv[key] = value
        run {
            self.connectionStatus = "Saving \(key)"
            let result: HermesCompanionSetGatewayEnvResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "set_gateway_env",
                payload: HermesCompanionSetGatewayEnvPayload(workspacePath: settings.hermesWorkspacePath, profileName: self.gatewayProfileName.isEmpty ? self.activeProfileName : self.gatewayProfileName, key: key, value: value)
            )
            self.gatewayEnv = result.env
            self.gatewayRunning = result.gatewayRunning
            self.gatewayProfileName = result.profileName
            self.gatewayProfilePath = result.profilePath
            self.gatewayEnvFilePath = result.envFilePath
            self.gatewayOperationOutput = result.restartOutput ?? "Saved \(result.key)"
            self.connectionStatus = "Messaging Key Saved"
        }
    }

    func setGatewayPlatformEnabled(platform: String, enabled: Bool, settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        gatewayPlatformEnabled[platform] = enabled
        run {
            self.connectionStatus = enabled ? "Enabling Platform" : "Disabling Platform"
            let result: HermesCompanionSetGatewayPlatformResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "set_gateway_platform",
                payload: HermesCompanionSetGatewayPlatformPayload(workspacePath: settings.hermesWorkspacePath, profileName: self.gatewayProfileName.isEmpty ? self.activeProfileName : self.gatewayProfileName, platform: platform, enabled: enabled)
            )
            self.gatewayPlatformEnabled = result.platformEnabled
            self.gatewayRunning = result.gatewayRunning
            self.gatewayProfileName = result.profileName
            self.gatewayProfilePath = result.profilePath
            self.gatewayConfigPath = result.configPath
            self.gatewayOperationOutput = result.restartOutput ?? "Updated \(result.platform)"
            self.connectionStatus = "Messaging Platform Updated"
        }
    }

    private func applyGatewayOperation(_ result: HermesCompanionGatewayOperationResult) {
        gatewayRunning = result.gatewayRunning
        gatewayProfileName = result.profileName
        gatewayProfilePath = result.profilePath
        gatewayOperationOutput = result.output
        resolvedHermesWorkspacePath = result.resolvedWorkspacePath
        if let config = result.config {
            applyGatewayConfig(config)
        }
    }

    private func applyGatewayConfig(_ result: HermesCompanionGatewayConfigResult) {
        gatewayConfig = result
        gatewayRunning = result.gatewayRunning
        gatewayEnv = result.env
        gatewayPlatformEnabled = result.platformEnabled
        gatewayFields = result.fields
        gatewayPlatforms = result.platforms
        gatewayProfileName = result.profileName
        gatewayProfilePath = result.profilePath
        gatewayEnvFilePath = result.envFilePath
        gatewayConfigPath = result.configPath
        resolvedHermesWorkspacePath = result.resolvedWorkspacePath
    }

    private static func withTimeout<T>(seconds: UInt64, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                throw URLError(.timedOut)
            }
            guard let result = try await group.next() else {
                throw URLError(.timedOut)
            }
            group.cancelAll()
            return result
        }
    }

    func refreshHermesLog(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        observabilityLogTask?.cancel()
        let log = observabilityLogKind
        let lineCount = observabilityLineCount
        observabilityLogTask = Task {
            isLoadingObservabilityLog = true
            lastErrorMessage = ""
            connectionStatus = "Loading \(log.label) Log"
            defer { isLoadingObservabilityLog = false }

            do {
                let result: HermesCompanionReadLogResult = try await Self.withTimeout(seconds: 20) {
                    try await HermesCompanionSessionFactory.request(
                        settings: settings,
                        state: identityState,
                        type: "read_hermes_log",
                        payload: HermesCompanionReadLogPayload(
                            log: log,
                            lineCount: lineCount
                        )
                    )
                }
                guard Task.isCancelled == false else { return }
                self.observabilityLogKind = result.log
                self.observabilityLineCount = result.requestedLineCount
                self.observabilityLogContent = result.content
                self.observabilityLogPath = result.path
                self.observabilityLoadedLineCount = result.loadedLineCount
                self.observabilityUpdatedAt = result.updatedAt
                self.markRuntimeSectionLoaded("observability")
                self.connectionStatus = result.fileExists ? "\(result.label) Log Loaded" : "\(result.label) Log Missing"
            } catch is CancellationError {
                return
            } catch {
                self.lastErrorMessage = error.localizedDescription
                self.connectionStatus = "Log Load Failed"
            }
        }
    }

    func setHermesObservabilityLog(_ log: HermesCompanionLogKind, settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        observabilityLogKind = log
        observabilityLogPath = log.path
        observabilityLogContent = ""
        observabilityLoadedLineCount = 0
        refreshHermesLog(settings: settings, identityState: identityState)
    }

    func setHermesObservabilityLineCount(_ lineCount: Int) {
        observabilityLineCount = min(max(lineCount, 10), 10_000)
    }

    private func refreshHermesLogImmediately(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState, lineCount: Int? = nil) async throws {
        let result: HermesCompanionReadLogResult = try await Self.withTimeout(seconds: 20) {
            try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "read_hermes_log",
                payload: HermesCompanionReadLogPayload(
                    log: self.observabilityLogKind,
                    lineCount: lineCount ?? self.observabilityLineCount
                )
            )
        }
        observabilityLogKind = result.log
        observabilityLineCount = result.requestedLineCount
        observabilityLogContent = result.content
        observabilityLogPath = result.path
        observabilityLoadedLineCount = result.loadedLineCount
        observabilityUpdatedAt = result.updatedAt
    }

    func refreshHermesMCPServers(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Loading MCP Servers"
            try await self.refreshHermesMCPServersImmediately(settings: settings, identityState: identityState)
            self.markRuntimeSectionLoaded("mcpServers")
            self.connectionStatus = self.hermesMCPServers.isEmpty ? "No MCP Servers" : "MCP Servers Loaded"
        }
    }

    private func refreshHermesMCPServersImmediately(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) async throws {
        let result: HermesCompanionListMCPServersResult = try await HermesCompanionSessionFactory.request(
            settings: settings,
            state: identityState,
            type: "list_mcp_servers",
            payload: HermesCompanionEmptyPayload()
        )
        hermesMCPServers = result.servers
        mcpListOutput = result.output
    }

    func addHermesMCPServer(
        name: String,
        transport: HermesCompanionMCPServerTransport,
        command: String,
        arguments: String,
        url: String,
        bearerToken: String,
        settings: HermesCompanionSettings,
        identityState: HermesCompanionIdentityState
    ) {
        run {
            self.connectionStatus = "Adding MCP Server"
            let result: HermesCompanionMCPOperationResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "add_mcp_server",
                payload: HermesCompanionAddMCPServerPayload(
                    name: name,
                    transport: transport,
                    command: command,
                    arguments: arguments,
                    url: url,
                    bearerToken: bearerToken
                )
            )
            self.hermesMCPServers = result.servers
            self.mcpOperationOutput = result.output
            self.connectionStatus = "MCP Server Added"
        }
    }

    func removeHermesMCPServer(name: String, settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Removing MCP Server"
            let result: HermesCompanionMCPOperationResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "remove_mcp_server",
                payload: HermesCompanionRemoveMCPServerPayload(name: name)
            )
            self.hermesMCPServers = result.servers
            self.mcpOperationOutput = result.output
            self.connectionStatus = "MCP Server Removed"
        }
    }

    func refreshHermesToolsets(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Loading Toolsets"
            try await self.refreshHermesToolsetsImmediately(settings: settings, identityState: identityState)
            self.markRuntimeSectionLoaded("tools")
            self.connectionStatus = self.hermesToolsets.isEmpty ? "No Toolsets Found" : "Toolsets Loaded"
        }
    }

    private func refreshHermesToolsetsImmediately(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) async throws {
        let result: HermesCompanionListToolsetsResult = try await HermesCompanionSessionFactory.request(
            settings: settings,
            state: identityState,
            type: "list_toolsets",
            payload: HermesCompanionListToolsetsPayload(workspacePath: settings.hermesWorkspacePath)
        )
        hermesToolsets = result.toolsets
        toolsetsConfigPath = result.configPath
        resolvedHermesWorkspacePath = result.resolvedWorkspacePath
    }

    func setHermesToolsetEnabled(
        key: String,
        enabled: Bool,
        settings: HermesCompanionSettings,
        identityState: HermesCompanionIdentityState
    ) {
        let previousToolsets = hermesToolsets
        if let index = hermesToolsets.firstIndex(where: { $0.key == key }) {
            hermesToolsets[index] = HermesCompanionToolsetInfo(
                key: hermesToolsets[index].key,
                label: hermesToolsets[index].label,
                description: hermesToolsets[index].description,
                enabled: enabled
            )
        }

        Task {
            isBusy = true
            lastErrorMessage = ""
            connectionStatus = enabled ? "Enabling Toolset" : "Disabling Toolset"
            do {
                let result: HermesCompanionSetToolsetEnabledResult = try await HermesCompanionSessionFactory.request(
                    settings: settings,
                    state: identityState,
                    type: "set_toolset_enabled",
                    payload: HermesCompanionSetToolsetEnabledPayload(
                        workspacePath: settings.hermesWorkspacePath,
                        key: key,
                        enabled: enabled
                    )
                )
                if let index = hermesToolsets.firstIndex(where: { $0.key == result.toolset.key }) {
                    hermesToolsets[index] = result.toolset
                }
                toolsetsConfigPath = result.configPath
                resolvedHermesWorkspacePath = result.resolvedWorkspacePath
                connectionStatus = "Toolsets Updated"
            } catch {
                hermesToolsets = previousToolsets
                lastErrorMessage = error.localizedDescription
                connectionStatus = "Toolset Sync Failed"
            }
            isBusy = false
        }
    }

    func refreshHermesModels(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Loading Models"
            try await self.refreshHermesModelsImmediately(settings: settings, identityState: identityState)
            self.markRuntimeSectionLoaded("models")
            self.connectionStatus = self.hermesModels.isEmpty ? "No Models Found" : "Models Loaded"
        }
    }

    func addHermesModel(
        name: String,
        provider: String,
        model: String,
        baseURL: String,
        settings: HermesCompanionSettings,
        identityState: HermesCompanionIdentityState
    ) {
        run {
            self.connectionStatus = "Adding Model"
            let result: HermesCompanionAddModelResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "add_model",
                payload: HermesCompanionAddModelPayload(
                    workspacePath: settings.hermesWorkspacePath,
                    name: name,
                    provider: provider,
                    model: model,
                    baseURL: baseURL
                )
            )
            self.modelsFilePath = result.modelsFilePath
            self.resolvedHermesWorkspacePath = result.resolvedWorkspacePath
            try await self.refreshHermesModelsImmediately(settings: settings, identityState: identityState)
            self.connectionStatus = "Model Added"
        }
    }

    func updateHermesModel(
        id: String,
        name: String,
        provider: String,
        model: String,
        baseURL: String,
        settings: HermesCompanionSettings,
        identityState: HermesCompanionIdentityState
    ) {
        run {
            self.connectionStatus = "Updating Model"
            let result: HermesCompanionUpdateModelResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "update_model",
                payload: HermesCompanionUpdateModelPayload(
                    workspacePath: settings.hermesWorkspacePath,
                    id: id,
                    name: name,
                    provider: provider,
                    model: model,
                    baseURL: baseURL
                )
            )
            self.modelsFilePath = result.modelsFilePath
            self.resolvedHermesWorkspacePath = result.resolvedWorkspacePath
            try await self.refreshHermesModelsImmediately(settings: settings, identityState: identityState)
            self.connectionStatus = "Model Updated"
        }
    }

    func removeHermesModel(
        id: String,
        settings: HermesCompanionSettings,
        identityState: HermesCompanionIdentityState
    ) {
        run {
            self.connectionStatus = "Removing Model"
            let result: HermesCompanionRemoveModelResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "remove_model",
                payload: HermesCompanionRemoveModelPayload(
                    workspacePath: settings.hermesWorkspacePath,
                    id: id
                )
            )
            self.modelsFilePath = result.modelsFilePath
            self.resolvedHermesWorkspacePath = result.resolvedWorkspacePath
            try await self.refreshHermesModelsImmediately(settings: settings, identityState: identityState)
            self.connectionStatus = "Model Removed"
        }
    }

    func refreshProvidersConfig(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Loading Providers"
            try await self.refreshProvidersConfigImmediately(settings: settings, identityState: identityState)
            self.markRuntimeSectionLoaded("providers")
            self.connectionStatus = "Providers Loaded"
        }
    }

    private func refreshProvidersConfigImmediately(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) async throws {
        let result: HermesCompanionProvidersConfigResult = try await HermesCompanionSessionFactory.request(
            settings: settings,
            state: identityState,
            type: "get_providers_config",
            payload: HermesCompanionProvidersConfigPayload(workspacePath: settings.hermesWorkspacePath)
        )
        applyProvidersConfig(result)
    }

    func setProviderEnvValue(
        key: String,
        value: String,
        settings: HermesCompanionSettings,
        identityState: HermesCompanionIdentityState
    ) {
        providerEnv[key] = value
        run {
            self.connectionStatus = "Saving \(key)"
            let result: HermesCompanionSetProviderEnvResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "set_provider_env",
                payload: HermesCompanionSetProviderEnvPayload(
                    workspacePath: settings.hermesWorkspacePath,
                    key: key,
                    value: value
                )
            )
            self.providerEnv[result.key] = result.value
            self.providerEnvFilePath = result.envFilePath
            self.resolvedHermesWorkspacePath = result.resolvedWorkspacePath
            self.connectionStatus = "Provider Key Saved"
        }
    }

    func removeProviderEnvValue(
        key: String,
        settings: HermesCompanionSettings,
        identityState: HermesCompanionIdentityState
    ) {
        providerEnv.removeValue(forKey: key)
        run {
            self.connectionStatus = "Removing \(key)"
            let result: HermesCompanionRemoveProviderEnvResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "remove_provider_env",
                payload: HermesCompanionRemoveProviderEnvPayload(
                    workspacePath: settings.hermesWorkspacePath,
                    key: key
                )
            )
            self.providerEnv = result.env
            self.providerEnvFilePath = result.envFilePath
            self.resolvedHermesWorkspacePath = result.resolvedWorkspacePath
            self.connectionStatus = "Provider Removed"
        }
    }

    func saveProviderModelConfig(
        provider: String,
        model: String,
        baseUrl: String,
        settings: HermesCompanionSettings,
        identityState: HermesCompanionIdentityState
    ) {
        providerModelConfig = HermesCompanionProviderModelConfig(provider: provider, model: model, baseUrl: baseUrl)
        run {
            self.connectionStatus = "Saving Provider Model"
            let result: HermesCompanionSetProviderModelConfigResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "set_provider_model_config",
                payload: HermesCompanionSetProviderModelConfigPayload(
                    workspacePath: settings.hermesWorkspacePath,
                    provider: provider,
                    model: model,
                    baseUrl: baseUrl
                )
            )
            self.providerModelConfig = result.modelConfig
            self.providerConfigPath = result.configPath
            self.resolvedHermesWorkspacePath = result.resolvedWorkspacePath
            if model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                _ = try await HermesCompanionSessionFactory.request(
                    settings: settings,
                    state: identityState,
                    type: "add_model",
                    payload: HermesCompanionAddModelPayload(
                        workspacePath: settings.hermesWorkspacePath,
                        name: model.split(separator: "/").last.map(String.init) ?? model,
                        provider: provider,
                        model: model,
                        baseURL: baseUrl
                    )
                ) as HermesCompanionAddModelResult
                try await self.refreshHermesModelsImmediately(settings: settings, identityState: identityState)
            }
            self.connectionStatus = "Provider Model Saved"
        }
    }

    func saveRuntimeModelSlotConfig(
        slot: HermesCompanionRuntimeModelSlotConfig,
        provider: String,
        model: String,
        settings: HermesCompanionSettings,
        identityState: HermesCompanionIdentityState
    ) {
        let updated = HermesCompanionRuntimeModelSlotConfig(
            id: slot.id,
            label: slot.label,
            section: slot.section,
            key: slot.key,
            provider: provider,
            model: model
        )
        if slot.section == "delegation" {
            delegationModelConfig = updated
        } else if let index = auxiliaryModelConfigs.firstIndex(where: { $0.id == slot.id }) {
            auxiliaryModelConfigs[index] = updated
        }
        run {
            self.connectionStatus = "Saving \(slot.label) Model"
            let result: HermesCompanionSetRuntimeModelSlotResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "set_runtime_model_slot",
                payload: HermesCompanionSetRuntimeModelSlotPayload(
                    workspacePath: settings.hermesWorkspacePath,
                    section: slot.section,
                    key: slot.key,
                    provider: provider,
                    model: model
                )
            )
            if result.slot.section == "delegation" {
                self.delegationModelConfig = result.slot
            } else if let index = self.auxiliaryModelConfigs.firstIndex(where: { $0.id == result.slot.id }) {
                self.auxiliaryModelConfigs[index] = result.slot
            } else {
                self.auxiliaryModelConfigs.append(result.slot)
            }
            self.providerConfigPath = result.configPath
            self.resolvedHermesWorkspacePath = result.resolvedWorkspacePath
            self.connectionStatus = "\(result.slot.label) Model Saved"
        }
    }

    func setProviderCredentialPool(
        provider: String,
        entries: [HermesCompanionProviderCredentialEntry],
        settings: HermesCompanionSettings,
        identityState: HermesCompanionIdentityState
    ) {
        providerCredentialPool[provider] = entries
        run {
            self.connectionStatus = "Saving Credential Pool"
            let result: HermesCompanionSetCredentialPoolResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "set_credential_pool",
                payload: HermesCompanionSetCredentialPoolPayload(
                    workspacePath: settings.hermesWorkspacePath,
                    provider: provider,
                    entries: entries
                )
            )
            self.providerCredentialPool = result.credentialPool
            self.providerAuthFilePath = result.authFilePath
            self.resolvedHermesWorkspacePath = result.resolvedWorkspacePath
            self.connectionStatus = "Credential Pool Saved"
        }
    }

    private func applyProvidersConfig(_ result: HermesCompanionProvidersConfigResult) {
        providerEnv = result.env
        providerSections = result.sections
        providerOptions = result.providerOptions
        providerCredentialPool = result.credentialPool
        providerModelConfig = result.modelConfig
        delegationModelConfig = result.delegationModelConfig
        auxiliaryModelConfigs = result.auxiliaryModelConfigs
        providerEnvFilePath = result.envFilePath
        providerConfigPath = result.configPath
        providerAuthFilePath = result.authFilePath
        resolvedHermesWorkspacePath = result.resolvedWorkspacePath
    }


    func refreshMemoryConfig(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Loading Memory"
            try await self.refreshMemoryConfigImmediately(settings: settings, identityState: identityState)
            self.markRuntimeSectionLoaded("memory")
            self.connectionStatus = "Memory Loaded"
        }
    }

    private func refreshMemoryConfigImmediately(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) async throws {
        let result: HermesCompanionMemoryConfigResult = try await HermesCompanionSessionFactory.request(
            settings: settings,
            state: identityState,
            type: "get_memory_config",
            payload: HermesCompanionMemoryConfigPayload(workspacePath: settings.hermesWorkspacePath)
        )
        applyMemoryConfig(result)
    }

    func addMemoryEntry(content: String, settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Adding Memory"
            let result: HermesCompanionMemoryOperationResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "add_memory_entry",
                payload: HermesCompanionAddMemoryEntryPayload(workspacePath: settings.hermesWorkspacePath, content: content)
            )
            self.applyMemoryOperation(result)
            self.connectionStatus = result.success ? "Memory Added" : "Memory Add Failed"
        }
    }

    func updateMemoryEntry(index: Int, content: String, settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Updating Memory"
            let result: HermesCompanionMemoryOperationResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "update_memory_entry",
                payload: HermesCompanionUpdateMemoryEntryPayload(workspacePath: settings.hermesWorkspacePath, index: index, content: content)
            )
            self.applyMemoryOperation(result)
            self.connectionStatus = result.success ? "Memory Updated" : "Memory Update Failed"
        }
    }

    func removeMemoryEntry(index: Int, settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Removing Memory"
            let result: HermesCompanionMemoryOperationResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "remove_memory_entry",
                payload: HermesCompanionRemoveMemoryEntryPayload(workspacePath: settings.hermesWorkspacePath, index: index)
            )
            self.applyMemoryOperation(result)
            self.connectionStatus = result.success ? "Memory Removed" : "Memory Remove Failed"
        }
    }

    func writeUserProfile(content: String, settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        memoryUserContent = content
        run {
            self.connectionStatus = "Saving User Profile"
            let result: HermesCompanionMemoryOperationResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "write_user_profile",
                payload: HermesCompanionWriteUserProfilePayload(workspacePath: settings.hermesWorkspacePath, content: content)
            )
            self.applyMemoryOperation(result)
            self.connectionStatus = result.success ? "User Profile Saved" : "User Profile Save Failed"
        }
    }

    func setMemoryProvider(_ provider: String, settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        memoryProvider = provider
        memoryProviders = memoryProviders.map { item in
            HermesCompanionMemoryProviderInfo(name: item.name, description: item.description, installed: item.installed, active: item.name == provider, envVars: item.envVars)
        }
        run {
            self.connectionStatus = provider.isEmpty ? "Disabling Memory Provider" : "Activating \(provider)"
            let result: HermesCompanionSetMemoryProviderResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "set_memory_provider",
                payload: HermesCompanionSetMemoryProviderPayload(workspacePath: settings.hermesWorkspacePath, provider: provider)
            )
            self.memoryProvider = result.provider
            self.memoryProviders = result.providers
            self.memoryConfigPath = result.configPath
            self.resolvedHermesWorkspacePath = result.resolvedWorkspacePath
            self.connectionStatus = result.provider.isEmpty ? "Memory Provider Disabled" : "Memory Provider Active"
        }
    }

    func setMemoryEnvValue(key: String, value: String, settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        memoryEnv[key] = value
        run {
            self.connectionStatus = "Saving \(key)"
            let result: HermesCompanionSetMemoryEnvResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "set_memory_env",
                payload: HermesCompanionSetMemoryEnvPayload(workspacePath: settings.hermesWorkspacePath, key: key, value: value)
            )
            self.memoryEnv[result.key] = result.value
            self.memoryEnvFilePath = result.envFilePath
            self.resolvedHermesWorkspacePath = result.resolvedWorkspacePath
            self.connectionStatus = "Memory Provider Key Saved"
        }
    }


    func exportSupermemoryDelta(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Exporting Supermemory"
            let result: HermesCompanionSupermemoryManagementResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "export_supermemory_delta",
                payload: HermesCompanionSupermemoryManagementPayload(workspacePath: settings.hermesWorkspacePath)
            )
            self.applySupermemoryManagement(result, fallbackStatus: "Supermemory Exported")
        }
    }

    func importSupermemoryDelta(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Importing Supermemory"
            let result: HermesCompanionSupermemoryManagementResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "import_supermemory_delta",
                payload: HermesCompanionSupermemoryManagementPayload(workspacePath: settings.hermesWorkspacePath)
            )
            self.applySupermemoryManagement(result, fallbackStatus: "Supermemory Imported")
            self.refreshMemoryConfig(settings: settings, identityState: identityState)
        }
    }

    private func applySupermemoryManagement(_ result: HermesCompanionSupermemoryManagementResult, fallbackStatus: String) {
        supermemoryLastResult = result
        resolvedHermesWorkspacePath = result.resolvedWorkspacePath
        let parts = [
            result.status,
            result.exportPath.isEmpty ? nil : "Export: \(result.exportPath)",
            result.digestPath.isEmpty ? nil : "Digest: \(result.digestPath)",
            result.skillReferencePath.isEmpty ? nil : "Skill ref: \(result.skillReferencePath)",
            result.error
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        supermemoryOperationOutput = parts.joined(separator: "\n")
        if let error = result.error, !error.isEmpty {
            lastErrorMessage = error
        } else if result.success {
            lastErrorMessage = ""
        }
        connectionStatus = result.success ? fallbackStatus : "Supermemory Operation Failed"
    }

    func scanKnowledgeEraser(topic: String, settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        knowledgeEraserTopic = topic
        run {
            self.connectionStatus = "Scanning Knowledge"
            let result: HermesCompanionKnowledgeEraserScanResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "scan_knowledge_eraser",
                payload: HermesCompanionKnowledgeEraserScanPayload(workspacePath: settings.hermesWorkspacePath, topic: topic)
            )
            self.knowledgeEraserTopic = result.topic
            self.knowledgeEraserItems = result.items
            self.knowledgeEraserSelectedItemIDs = Set(result.items.map(\.id))
            self.knowledgeEraserLastScanAt = result.scannedAt
            self.knowledgeEraserArchivePath = ""
            self.knowledgeEraserOperationOutput = result.items.isEmpty ? "No matching memory or skill blocks found." : "Found \(result.items.count) candidate items. Review the checkboxes before erasing."
            self.resolvedHermesWorkspacePath = result.resolvedWorkspacePath
            self.markRuntimeSectionLoaded("knowledgeEraser")
            self.connectionStatus = "Knowledge Scan Complete"
        }
    }

    func eraseSelectedKnowledgeItems(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        let selectedIDs = Array(knowledgeEraserSelectedItemIDs)
        let topic = knowledgeEraserTopic
        run {
            self.connectionStatus = "Erasing Knowledge"
            let result: HermesCompanionKnowledgeEraserEraseResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "erase_knowledge_items",
                payload: HermesCompanionKnowledgeEraserErasePayload(workspacePath: settings.hermesWorkspacePath, topic: topic, selectedItemIDs: selectedIDs)
            )
            self.knowledgeEraserTopic = result.topic
            self.knowledgeEraserItems = result.remainingItems
            self.knowledgeEraserSelectedItemIDs = []
            self.knowledgeEraserArchivePath = result.archivePath
            self.knowledgeEraserOperationOutput = "Archived \(result.erasedItemIDs.count) erased items to \(result.archivePath)" + (result.skippedItemIDs.isEmpty ? "" : "\nSkipped \(result.skippedItemIDs.count) items that no longer matched.")
            self.resolvedHermesWorkspacePath = result.resolvedWorkspacePath
            self.connectionStatus = "Knowledge Erased"
            self.refreshMemoryConfig(settings: settings, identityState: identityState)
            self.refreshHermesSkills(settings: settings, identityState: identityState)
        }
    }

    private func applyMemoryOperation(_ result: HermesCompanionMemoryOperationResult) {
        resolvedHermesWorkspacePath = result.resolvedWorkspacePath
        if let error = result.error, !error.isEmpty {
            lastErrorMessage = error
        } else if result.success {
            lastErrorMessage = ""
        }
        if let memory = result.memory {
            applyMemoryConfig(memory)
        }
    }

    private func applyMemoryConfig(_ result: HermesCompanionMemoryConfigResult) {
        memoryConfig = result
        memoryEntries = result.memory.entries ?? []
        memoryUserContent = result.user.content
        memoryProvider = result.provider
        memoryProviders = result.providers
        memoryEnv = result.env
        memoryFilePath = result.memoryFilePath
        memoryUserFilePath = result.userFilePath
        memoryConfigPath = result.configPath
        memoryEnvFilePath = result.envFilePath
        resolvedHermesWorkspacePath = result.resolvedWorkspacePath
    }

    func refreshProfiles(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Loading Profiles"
            try await self.refreshProfilesImmediately(settings: settings, identityState: identityState)
            self.markRuntimeSectionLoaded("profiles")
            self.connectionStatus = self.profiles.isEmpty ? "No Profiles" : "Profiles Loaded"
        }
    }

    private func refreshProfilesImmediately(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) async throws {
        let result: HermesCompanionListProfilesResult = try await HermesCompanionSessionFactory.request(
            settings: settings,
            state: identityState,
            type: "list_profiles",
            payload: HermesCompanionListProfilesPayload(workspacePath: settings.hermesWorkspacePath)
        )
        applyProfiles(result)
    }

    func createProfile(name: String, provider: String, model: String, baseUrl: String, createEnv: Bool, createSoul: Bool, cloneSkills: Bool, settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Creating Profile"
            let result: HermesCompanionProfileOperationResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "create_profile",
                payload: HermesCompanionCreateProfilePayload(workspacePath: settings.hermesWorkspacePath, name: name, provider: provider, model: model, baseUrl: baseUrl, createEnv: createEnv, createSoul: createSoul, cloneSkills: cloneSkills)
            )
            self.applyProfileOperation(result)
            self.connectionStatus = result.success ? "Profile Created" : "Profile Create Failed"
        }
    }

    func editProfile(originalName: String, name: String, provider: String, model: String, baseUrl: String, createEnv: Bool, createSoul: Bool, settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Saving Profile"
            let result: HermesCompanionProfileOperationResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "edit_profile",
                payload: HermesCompanionEditProfilePayload(workspacePath: settings.hermesWorkspacePath, originalName: originalName, name: name, provider: provider, model: model, baseUrl: baseUrl, createEnv: createEnv, createSoul: createSoul)
            )
            self.applyProfileOperation(result)
            self.connectionStatus = result.success ? "Profile Saved" : "Profile Save Failed"
        }
    }

    func deleteProfile(name: String, settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Deleting Profile"
            let result: HermesCompanionProfileOperationResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "delete_profile",
                payload: HermesCompanionProfileOperationPayload(workspacePath: settings.hermesWorkspacePath, name: name)
            )
            self.applyProfileOperation(result)
            self.connectionStatus = result.success ? "Profile Deleted" : "Profile Delete Failed"
        }
    }

    func setActiveProfile(name: String, settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Switching Profile"
            let result: HermesCompanionProfileOperationResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "set_active_profile",
                payload: HermesCompanionProfileOperationPayload(workspacePath: settings.hermesWorkspacePath, name: name)
            )
            self.applyProfileOperation(result)
            self.connectionStatus = result.success ? "Profile Active" : "Profile Switch Failed"
        }
    }

    private func applyProfiles(_ result: HermesCompanionListProfilesResult) {
        profiles = result.profiles
        profilesDirectoryPath = result.profilesDirectoryPath
        activeProfileName = result.activeProfileName
        resolvedHermesWorkspacePath = result.resolvedWorkspacePath
        if profiles.contains(where: { $0.name == companionConfigProfileName }) == false {
            companionConfigProfileName = result.activeProfileName
        } else if companionConfigProfileName == "default", result.activeProfileName != "default", targetContent.isEmpty {
            companionConfigProfileName = result.activeProfileName
        }
    }

    private func applyProfileOperation(_ result: HermesCompanionProfileOperationResult) {
        profiles = result.profiles
        activeProfileName = result.activeProfileName
        profileOperationOutput = result.output
        resolvedHermesWorkspacePath = result.resolvedWorkspacePath
        if let error = result.error, !error.isEmpty {
            lastErrorMessage = error
        } else if result.success {
            lastErrorMessage = ""
        }
    }

    func refreshSchedules(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Loading Schedules"
            try await self.refreshSchedulesImmediately(settings: settings, identityState: identityState)
            self.markRuntimeSectionLoaded("schedules")
            self.connectionStatus = self.schedules.isEmpty ? "No Schedules" : "Schedules Loaded"
        }
    }

    private func refreshSchedulesImmediately(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) async throws {
        let result: HermesCompanionListSchedulesResult = try await HermesCompanionSessionFactory.request(
            settings: settings,
            state: identityState,
            type: "list_schedules",
            payload: HermesCompanionListSchedulesPayload(workspacePath: settings.hermesWorkspacePath, includeDisabled: true)
        )
        applySchedules(result)
    }

    func createSchedule(
        schedule: String,
        prompt: String?,
        name: String?,
        deliver: String?,
        settings: HermesCompanionSettings,
        identityState: HermesCompanionIdentityState
    ) {
        run {
            self.connectionStatus = "Creating Schedule"
            let result: HermesCompanionScheduleOperationResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "create_schedule",
                payload: HermesCompanionCreateSchedulePayload(
                    workspacePath: settings.hermesWorkspacePath,
                    schedule: schedule,
                    prompt: prompt,
                    name: name,
                    deliver: deliver
                )
            )
            self.applyScheduleOperation(result)
            self.connectionStatus = result.success ? "Schedule Created" : "Schedule Create Failed"
        }
    }

    func pauseSchedule(jobID: String, settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        scheduleAction(type: "pause_schedule", status: "Pausing Schedule", successStatus: "Schedule Paused", failureStatus: "Schedule Pause Failed", jobID: jobID, settings: settings, identityState: identityState)
    }

    func resumeSchedule(jobID: String, settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        scheduleAction(type: "resume_schedule", status: "Resuming Schedule", successStatus: "Schedule Resumed", failureStatus: "Schedule Resume Failed", jobID: jobID, settings: settings, identityState: identityState)
    }

    func triggerSchedule(jobID: String, settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        scheduleAction(type: "trigger_schedule", status: "Running Schedule", successStatus: "Schedule Triggered", failureStatus: "Schedule Trigger Failed", jobID: jobID, settings: settings, identityState: identityState)
    }

    func removeSchedule(jobID: String, settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        scheduleAction(type: "remove_schedule", status: "Removing Schedule", successStatus: "Schedule Removed", failureStatus: "Schedule Remove Failed", jobID: jobID, settings: settings, identityState: identityState)
    }

    private func scheduleAction(
        type: String,
        status: String,
        successStatus: String,
        failureStatus: String,
        jobID: String,
        settings: HermesCompanionSettings,
        identityState: HermesCompanionIdentityState
    ) {
        run {
            self.connectionStatus = status
            let result: HermesCompanionScheduleOperationResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: type,
                payload: HermesCompanionScheduleOperationPayload(workspacePath: settings.hermesWorkspacePath, jobID: jobID)
            )
            self.applyScheduleOperation(result)
            self.connectionStatus = result.success ? successStatus : failureStatus
        }
    }

    private func applyScheduleOperation(_ result: HermesCompanionScheduleOperationResult) {
        schedules = result.jobs
        schedulesFilePath = result.jobsFilePath
        resolvedHermesWorkspacePath = result.resolvedWorkspacePath
        if let error = result.error, !error.isEmpty {
            lastErrorMessage = error
        } else if result.success {
            lastErrorMessage = ""
        }
    }

    private func applySchedules(_ result: HermesCompanionListSchedulesResult) {
        schedules = result.jobs
        schedulesFilePath = result.jobsFilePath
        resolvedHermesWorkspacePath = result.resolvedWorkspacePath
    }

    private func refreshHermesModelsImmediately(
        settings: HermesCompanionSettings,
        identityState: HermesCompanionIdentityState
    ) async throws {
        let result: HermesCompanionListModelsResult = try await HermesCompanionSessionFactory.request(
            settings: settings,
            state: identityState,
            type: "list_models",
            payload: HermesCompanionListModelsPayload(workspacePath: settings.hermesWorkspacePath)
        )
        hermesModels = result.models
        modelsFilePath = result.modelsFilePath
        resolvedHermesWorkspacePath = result.resolvedWorkspacePath
    }
}

enum HermesCompanionSessionFactory {
    static let expectedAPIKeyLength = 256

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 300
        return URLSession(configuration: configuration)
    }

    static func request<Payload: Encodable, Response: Decodable>(
        url: URL,
        authenticationToken: String,
        type: String,
        payload: Payload?
    ) async throws -> Response {
        try await HermesBackgroundActivity.run(named: "Hermes Companion Request") {
            let session = makeSession()
            defer { session.invalidateAndCancel() }

            let task = session.webSocketTask(with: url)
            task.resume()

            let envelope = HermesCompanionIncomingEnvelope(
                id: UUID().uuidString,
                type: type,
                authenticationToken: authenticationToken,
                payload: payload.flatMap(HermesCompanionJSONValue.encode)
            )
            let data = try JSONEncoder().encode(envelope)
            guard let text = String(data: data, encoding: .utf8) else {
                throw HermesCompanionClientError.invalidResponse
            }
            try await task.send(.string(text))

            let message = try await task.receive()
            let responseData: Data
            switch message {
            case .data(let data):
                responseData = data
            case .string(let text):
                responseData = Data(text.utf8)
            @unknown default:
                throw HermesCompanionClientError.invalidResponse
            }

            let response = try JSONDecoder().decode(HermesCompanionOutgoingEnvelope.self, from: responseData)
            guard response.ok else {
                throw HermesCompanionClientError.serverRejected(response.error?.message ?? "The companion request failed.")
            }
            guard let payload = response.payload else {
                throw HermesCompanionClientError.missingPayload
            }
            return try payload.decode(Response.self)
        }
    }

    static func request<Payload: Encodable, Response: Decodable>(
        settings: HermesCompanionSettings,
        state: HermesCompanionIdentityState,
        type: String,
        payload: Payload?
    ) async throws -> Response {
        guard state.isEnrolled else {
            throw HermesCompanionClientError.notEnrolled
        }
        let token = settings.authenticationToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard token.isEmpty == false else {
            throw HermesCompanionClientError.missingAuthenticationToken
        }
        guard token.count == HermesCompanionSessionFactory.expectedAPIKeyLength else {
            throw HermesCompanionClientError.invalidAuthenticationTokenLength
        }
        let endpoint = state.serverEndpoint.isEmpty ? settings.apiURL : state.serverEndpoint
        guard let url = URL(string: endpoint.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw HermesCompanionClientError.invalidURL
        }
        return try await request(url: url, authenticationToken: token, type: type, payload: payload)
    }
}


private struct EmptyPayload: Encodable {}
