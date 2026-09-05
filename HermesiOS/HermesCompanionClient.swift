//
//  HermesCompanionClient.swift
//  HermesiOS
//
//  Created by Codex on 05/05/2026.
//

import CryptoKit
import Foundation
import Network
import Observation

struct HermesCompanionSettings: Codable, Equatable {
    var apiURL = HermesHostEndpoints.webSocketURLString(host: defaultHermesMacHost, port: defaultHermesCompanionPort)
    var deviceSecret = ""
    var hermesWorkspacePath = "/Volumes/WDBlack4TB/Code/HermesiOS/.hermes"
}

struct HermesCompanionIdentityState: Codable, Equatable {
    var deviceID = ""
    var deviceName = ""
    var serverEndpoint = ""
    var deviceSecretFingerprint = ""
    var issuedAt = Date()
    var approvedAt: Date?
    var revokedAt: Date?

    init(
        deviceID: String = "",
        deviceName: String = "",
        serverEndpoint: String = "",
        deviceSecretFingerprint: String = "",
        issuedAt: Date = Date(),
        approvedAt: Date? = nil,
        revokedAt: Date? = nil
    ) {
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.serverEndpoint = serverEndpoint
        self.deviceSecretFingerprint = deviceSecretFingerprint
        self.issuedAt = issuedAt
        self.approvedAt = approvedAt
        self.revokedAt = revokedAt
    }

    enum CodingKeys: String, CodingKey {
        case deviceID
        case deviceName
        case serverEndpoint
        case deviceSecretFingerprint
        case authenticationTokenFingerprint
        case issuedAt
        case approvedAt
        case revokedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceID = try container.decodeIfPresent(String.self, forKey: .deviceID) ?? ""
        deviceName = try container.decodeIfPresent(String.self, forKey: .deviceName) ?? ""
        serverEndpoint = try container.decodeIfPresent(String.self, forKey: .serverEndpoint) ?? ""
        deviceSecretFingerprint = try container.decodeIfPresent(String.self, forKey: .deviceSecretFingerprint)
            ?? container.decodeIfPresent(String.self, forKey: .authenticationTokenFingerprint)
            ?? ""
        issuedAt = try container.decodeIfPresent(Date.self, forKey: .issuedAt) ?? Date()
        approvedAt = try container.decodeIfPresent(Date.self, forKey: .approvedAt)
        revokedAt = try container.decodeIfPresent(Date.self, forKey: .revokedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(deviceID, forKey: .deviceID)
        try container.encode(deviceName, forKey: .deviceName)
        try container.encode(serverEndpoint, forKey: .serverEndpoint)
        try container.encode(deviceSecretFingerprint, forKey: .deviceSecretFingerprint)
        try container.encode(issuedAt, forKey: .issuedAt)
        try container.encodeIfPresent(approvedAt, forKey: .approvedAt)
        try container.encodeIfPresent(revokedAt, forKey: .revokedAt)
    }

    var hasPairing: Bool {
        serverEndpoint.isEmpty == false && deviceID.isEmpty == false && deviceSecretFingerprint.isEmpty == false
    }

    var isPendingApproval: Bool {
        hasPairing && approvedAt == nil && revokedAt == nil
    }

    var isEnrolled: Bool {
        hasPairing && approvedAt != nil && revokedAt == nil
    }

    func matches(settings: HermesCompanionSettings) -> Bool {
        let endpoint = settings.apiURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = settings.deviceSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        return hasPairing &&
            serverEndpoint == endpoint &&
            deviceSecretFingerprint == Self.fingerprint(for: secret)
    }

    static func fingerprint(for secret: String) -> String {
        let digest = SHA256.hash(data: Data(secret.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

struct HermesCompanionSavedConnection: Codable, Identifiable, Equatable {
    var nickname = ""
    var serverName = ""
    var identityState = HermesCompanionIdentityState()
    var lastMessage = ""
    var updatedAt = Date()

    var id: String { identityState.deviceID }

    init(
        nickname: String = "",
        serverName: String = "",
        identityState: HermesCompanionIdentityState = HermesCompanionIdentityState(),
        lastMessage: String = "",
        updatedAt: Date = Date()
    ) {
        self.nickname = nickname
        self.serverName = serverName
        self.identityState = identityState
        self.lastMessage = lastMessage
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case nickname
        case serverName
        case identityState
        case lastMessage
        case updatedAt
    }

    var displayName: String {
        let trimmedNickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedNickname.isEmpty == false { return trimmedNickname }
        let trimmedServerName = serverName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedServerName.isEmpty == false { return trimmedServerName }
        if let host = URL(string: identityState.serverEndpoint)?.host, host.isEmpty == false { return host }
        if identityState.deviceName.isEmpty == false { return identityState.deviceName }
        return identityState.deviceID.isEmpty ? "Host Companion" : "Host \(identityState.deviceID.prefix(8))"
    }

    var statusLabel: String {
        if identityState.revokedAt != nil { return "Revoked" }
        if identityState.isEnrolled { return "Approved" }
        if identityState.isPendingApproval { return "Pending approval" }
        return "Not paired"
    }
}

struct HermesCompanionIncomingEnvelope: Codable {
    let id: String?
    let type: String
    let deviceID: String?
    let deviceSecret: String?
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

struct HermesCompanionOnboardingPayload: Codable {
    let type: String
    let version: Int
    let endpoint: String
    let code: String
    let serverName: String
    let hermesConfigFolderPath: String?
    let apiGatewayAPIKey: String?

    static func decode(from text: String) throws -> HermesCompanionOnboardingPayload {
        let data = Data(text.utf8)
        let payload = try JSONDecoder().decode(HermesCompanionOnboardingPayload.self, from: data)
        guard payload.type == "hermes_companion_onboarding", payload.version == 1 else {
            throw HermesCompanionClientError.invalidOnboardingCode
        }
        return payload
    }
}

struct HermesCompanionEnrollDevicePayload: Codable {
    let code: String
    let deviceName: String
}

struct HermesCompanionEnrollDeviceResult: Codable {
    let deviceID: String
    let deviceSecret: String
    let deviceName: String
    let serverEndpoint: String
    let approved: Bool
    let message: String
}

struct HermesCompanionCheckDeviceApprovalPayload: Codable {
    let deviceID: String
    let deviceSecret: String
}

struct HermesCompanionCheckDeviceApprovalResult: Codable {
    let deviceID: String
    let approved: Bool
    let revoked: Bool
    let message: String
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
    let workspacePath: String?

    init(path: String, workspacePath: String? = nil) {
        self.path = path
        self.workspacePath = workspacePath
    }
}

struct HermesCompanionFileBrowserPayload: Codable {
    let path: String
    let workspacePath: String?

    init(path: String, workspacePath: String? = nil) {
        self.path = path
        self.workspacePath = workspacePath
    }
}

struct HermesCompanionFileBrowserEntry: Codable, Identifiable, Equatable {
    var id: String { path }

    let name: String
    let path: String
    let isDirectory: Bool
    let byteCount: Int?
}

struct HermesCompanionFileBrowserResult: Codable, Equatable {
    let path: String
    let parentPath: String?
    let entries: [HermesCompanionFileBrowserEntry]
}

struct HermesCompanionFileDownloadResult: Codable {
    let path: String
    let fileName: String
    let byteCount: Int
    let contentType: String
    let base64Data: String
}

struct HermesCompanionFileDownloadInfoResult: Codable {
    let path: String
    let fileName: String
    let byteCount: Int
    let contentType: String
    let chunkSize: Int
}

struct HermesCompanionFileDownloadChunkPayload: Codable {
    let path: String
    let offset: Int
    let length: Int
    let workspacePath: String?

    init(path: String, offset: Int, length: Int, workspacePath: String? = nil) {
        self.path = path
        self.offset = offset
        self.length = length
        self.workspacePath = workspacePath
    }
}

struct HermesCompanionFileDownloadChunkResult: Codable {
    let path: String
    let offset: Int
    let byteCount: Int
    let totalByteCount: Int
    let isComplete: Bool
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

struct HermesCompanionServicePortsResult: Codable, Equatable {
    var apiGatewayPort = defaultHermesAPIPort
    var dashboardPort = defaultHermesDashboardPort
    var officePort = defaultHermesOfficePort
}

struct HermesCompanionTailscaleServeStatusPayload: Codable {
    let port: String
}

struct HermesCompanionSetTailscaleServePayload: Codable {
    let port: String
    let enabled: Bool
}

struct HermesCompanionTailscaleServeStatusResult: Codable, Equatable {
    let port: String
    let isEnabled: Bool
    let output: String
    let checkedAt: Date
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
    let workspacePath: String
    let resolvedWorkspacePath: String
    let servers: [HermesCompanionMCPServerSummary]
    let output: String
}

struct HermesCompanionListMCPServersPayload: Codable {
    let workspacePath: String
}

enum HermesCompanionMCPServerTransport: String, Codable, CaseIterable, Identifiable {
    case stdio
    case streamableHTTP
    case openAPI

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stdio: "Stdio"
        case .streamableHTTP: "Streamable HTTP"
        case .openAPI: "OpenAPI"
        }
    }
}

struct HermesCompanionAddMCPServerPayload: Codable {
    let workspacePath: String
    let name: String
    let transport: HermesCompanionMCPServerTransport
    let command: String
    let arguments: String
    let url: String
    let bearerToken: String
}

struct HermesCompanionRemoveMCPServerPayload: Codable {
    let workspacePath: String
    let name: String
}

struct HermesCompanionMCPOperationResult: Codable {
    let workspacePath: String
    let resolvedWorkspacePath: String
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
    let baseUrl: String

    private enum CodingKeys: String, CodingKey { case id, label, section, key, provider, model, baseUrl }
    init(id: String, label: String, section: String, key: String, provider: String, model: String, baseUrl: String = "") { self.id = id; self.label = label; self.section = section; self.key = key; self.provider = provider; self.model = model; self.baseUrl = baseUrl }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id); label = try values.decode(String.self, forKey: .label); section = try values.decode(String.self, forKey: .section); key = try values.decode(String.self, forKey: .key); provider = try values.decode(String.self, forKey: .provider); model = try values.decode(String.self, forKey: .model); baseUrl = try values.decodeIfPresent(String.self, forKey: .baseUrl) ?? ""
    }
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
    let baseUrl: String?
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
    let rawSchedule: String
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
    let provider: String?
    let model: String?
    let baseUrl: String?

    init(id: String, name: String, schedule: String, rawSchedule: String, prompt: String, state: String, enabled: Bool, nextRunAt: String?, lastRunAt: String?, lastStatus: String?, lastError: String?, repeatInfo: HermesCompanionScheduleRepeatInfo?, deliver: [String], skills: [String], script: String?, provider: String?, model: String?, baseUrl: String?) {
        self.id = id; self.name = name; self.schedule = schedule; self.rawSchedule = rawSchedule; self.prompt = prompt; self.state = state; self.enabled = enabled; self.nextRunAt = nextRunAt; self.lastRunAt = lastRunAt; self.lastStatus = lastStatus; self.lastError = lastError; self.repeatInfo = repeatInfo; self.deliver = deliver; self.skills = skills; self.script = script; self.provider = provider; self.model = model; self.baseUrl = baseUrl
    }

    private enum CodingKeys: String, CodingKey { case id, name, schedule, rawSchedule, prompt, state, enabled, nextRunAt, lastRunAt, lastStatus, lastError, repeatInfo, deliver, skills, script, provider, model, baseUrl }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id); name = try values.decode(String.self, forKey: .name); schedule = try values.decode(String.self, forKey: .schedule); rawSchedule = try values.decodeIfPresent(String.self, forKey: .rawSchedule) ?? schedule; prompt = try values.decode(String.self, forKey: .prompt); state = try values.decode(String.self, forKey: .state); enabled = try values.decode(Bool.self, forKey: .enabled); nextRunAt = try values.decodeIfPresent(String.self, forKey: .nextRunAt); lastRunAt = try values.decodeIfPresent(String.self, forKey: .lastRunAt); lastStatus = try values.decodeIfPresent(String.self, forKey: .lastStatus); lastError = try values.decodeIfPresent(String.self, forKey: .lastError); repeatInfo = try values.decodeIfPresent(HermesCompanionScheduleRepeatInfo.self, forKey: .repeatInfo); deliver = try values.decodeIfPresent([String].self, forKey: .deliver) ?? []; skills = try values.decodeIfPresent([String].self, forKey: .skills) ?? []; script = try values.decodeIfPresent(String.self, forKey: .script); provider = try values.decodeIfPresent(String.self, forKey: .provider); model = try values.decodeIfPresent(String.self, forKey: .model); baseUrl = try values.decodeIfPresent(String.self, forKey: .baseUrl)
    }
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
    let provider: String?
    let model: String?
    let baseUrl: String?
}

struct HermesCompanionEditSchedulePayload: Codable {
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
    case missingDeviceSecret
    case invalidOnboardingCode
    case notEnrolled
    case pendingApproval
    case deviceRevoked
    case insecureEndpoint(String)
    case requestTimedOut

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
        case .missingDeviceSecret:
            "Scan the Host Companion QR code before using runtime controls."
        case .invalidOnboardingCode:
            "The QR code is not a valid HermesHostCompanion onboarding code."
        case .notEnrolled:
            "Approve this device in HermesHostCompanion before using runtime controls."
        case .pendingApproval:
            "This device is waiting for approval in HermesHostCompanion."
        case .deviceRevoked:
            "This device has been revoked in HermesHostCompanion. Scan the QR code again to onboard it."
        case .insecureEndpoint(let message):
            message
        case .requestTimedOut:
            "The Host Companion did not answer the pairing request. Check that HermesHostCompanion is running, that its server state is Running, and scan the current QR code again."
        }
    }
}

@MainActor
@Observable
final class HermesCompanionEnrollmentSession {
    var isEnrolling = false
    var connectionStatus = "Not Paired"
    var lastErrorMessage = ""
    var identityState: HermesCompanionIdentityState
    var connections: [HermesCompanionSavedConnection]
    var activeConnectionID: String

    private var enrollmentTask: Task<Void, Never>?

    init() {
        let loadedConnections = HermesSettingsPersistence.loadCompanionConnections()
        var loadedActiveConnectionID = HermesSettingsPersistence.loadActiveCompanionConnectionID()
        if loadedActiveConnectionID.isEmpty, let firstConnection = loadedConnections.first {
            loadedActiveConnectionID = firstConnection.id
            HermesSettingsPersistence.saveActiveCompanionConnectionID(firstConnection.id)
        }
        let persistedState = loadedConnections.first(where: { $0.id == loadedActiveConnectionID })?.identityState
            ?? HermesSettingsPersistence.loadCompanionIdentityState()
        connections = loadedConnections
        activeConnectionID = loadedActiveConnectionID
        identityState = persistedState
        connectionStatus = Self.statusTitle(for: persistedState)
    }

    func enroll(onboarding payload: HermesCompanionOnboardingPayload, deviceName: String, activateWhenFinished: Bool = true) {
        enrollmentTask?.cancel()
        enrollmentTask = Task {
            await runEnrollment(onboarding: payload, deviceName: deviceName, activateWhenFinished: activateWhenFinished)
        }
    }

    func checkApproval(settings: HermesCompanionSettings, connectionID: String? = nil) {
        enrollmentTask?.cancel()
        enrollmentTask = Task {
            await runApprovalCheck(settings: settings, connectionID: connectionID)
        }
    }

    func activateConnection(id: String) {
        guard let connection = connections.first(where: { $0.id == id }) else { return }
        activeConnectionID = connection.id
        identityState = connection.identityState
        connectionStatus = Self.statusTitle(for: connection.identityState)
        lastErrorMessage = connection.lastMessage
        HermesSettingsPersistence.saveActiveCompanionConnectionID(connection.id)
        HermesSettingsPersistence.saveCompanionAuthenticationState(connection.identityState)
    }

    func forgetConnection(id: String) {
        enrollmentTask?.cancel()
        enrollmentTask = nil
        isEnrolling = false
        let wasActive = id == activeConnectionID
        HermesSettingsPersistence.removeCompanionConnection(deviceID: id)
        connections = HermesSettingsPersistence.loadCompanionConnections()
        activeConnectionID = HermesSettingsPersistence.loadActiveCompanionConnectionID()
        if activeConnectionID.isEmpty, let firstConnection = connections.first {
            activeConnectionID = firstConnection.id
            HermesSettingsPersistence.saveActiveCompanionConnectionID(firstConnection.id)
        }
        if wasActive {
            identityState = connections.first(where: { $0.id == activeConnectionID })?.identityState ?? HermesCompanionIdentityState()
            connectionStatus = Self.statusTitle(for: identityState)
        }
        if connections.isEmpty {
            identityState = HermesCompanionIdentityState()
            connectionStatus = "Not Paired"
            HermesSettingsPersistence.clearCompanionIdentity()
        }
        lastErrorMessage = ""
    }

    func clearIdentity() {
        if activeConnectionID.isEmpty == false {
            forgetConnection(id: activeConnectionID)
            return
        }
        enrollmentTask?.cancel()
        enrollmentTask = nil
        isEnrolling = false
        identityState = HermesCompanionIdentityState()
        connections = []
        activeConnectionID = ""
        connectionStatus = "Not Paired"
        lastErrorMessage = ""
        HermesSettingsPersistence.clearCompanionIdentity()
        HermesSettingsPersistence.saveCompanionDeviceSecret("")
    }

    func resetAfterPairingFailure(message: String) {
        enrollmentTask?.cancel()
        enrollmentTask = nil
        isEnrolling = false
        lastErrorMessage = message
        connectionStatus = "QR Scan Failed"
    }

    func invalidateIfSettingsChanged(settings: HermesCompanionSettings) {
        guard identityState.hasPairing, identityState.matches(settings: settings) == false else { return }
        enrollmentTask?.cancel()
        enrollmentTask = nil
        lastErrorMessage = "Host Companion endpoint changed. Select a saved host or scan the current QR code."
    }

    func connection(for id: String) -> HermesCompanionSavedConnection? {
        connections.first { $0.id == id }
    }

    private func runEnrollment(onboarding payload: HermesCompanionOnboardingPayload, deviceName: String, activateWhenFinished: Bool) async {
        guard let url = URL(string: payload.endpoint.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            lastErrorMessage = HermesCompanionClientError.invalidURL.localizedDescription
            connectionStatus = "Pairing Failed"
            return
        }
        if let warning = HermesEndpointSecurity.plaintextTransportWarning(for: url.absoluteString, endpointName: "Host Companion") {
            lastErrorMessage = warning
            connectionStatus = "Pairing Failed"
            return
        }

        isEnrolling = true
        lastErrorMessage = ""
        connectionStatus = "Sending Pairing Request"
        defer { isEnrolling = false }

        do {
            let result: HermesCompanionEnrollDeviceResult = try await HermesCompanionSessionFactory.request(
                url: url,
                deviceID: nil,
                deviceSecret: nil,
                type: "enroll_device",
                payload: HermesCompanionEnrollDevicePayload(code: payload.code, deviceName: deviceName)
            )
            HermesSettingsPersistence.saveCompanionDeviceSecret(result.deviceSecret, deviceID: result.deviceID)
            let newState = HermesCompanionIdentityState(
                deviceID: result.deviceID,
                deviceName: result.deviceName,
                serverEndpoint: result.serverEndpoint,
                deviceSecretFingerprint: HermesCompanionIdentityState.fingerprint(for: result.deviceSecret),
                issuedAt: Date(),
                approvedAt: result.approved ? Date() : nil,
                revokedAt: nil
            )
            let connection = HermesCompanionSavedConnection(
                serverName: payload.serverName,
                identityState: newState,
                lastMessage: result.message,
                updatedAt: Date()
            )
            upsert(connection)
            let shouldActivate = activateWhenFinished || identityState.hasPairing == false
            if shouldActivate {
                activateConnection(id: newState.deviceID)
                connectionStatus = result.approved ? "Device Approved" : "Pending Approval"
                lastErrorMessage = result.message
            } else {
                connectionStatus = "Host Stored"
                lastErrorMessage = "\(connection.displayName) was stored. Switch hosts after active streams finish."
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            connectionStatus = "Pairing Failed"
        }

    }

    private func runApprovalCheck(settings: HermesCompanionSettings, connectionID: String?) async {
        let targetState: HermesCompanionIdentityState
        if let connectionID, let connection = connections.first(where: { $0.id == connectionID }) {
            targetState = connection.identityState
        } else {
            targetState = identityState
        }
        guard targetState.hasPairing else {
            lastErrorMessage = HermesCompanionClientError.notEnrolled.localizedDescription
            connectionStatus = "Not Paired"
            return
        }
        let secret = HermesCompanionSessionFactory.deviceSecret(from: settings, deviceID: targetState.deviceID)
        guard secret.isEmpty == false else {
            lastErrorMessage = HermesCompanionClientError.missingDeviceSecret.localizedDescription
            connectionStatus = "Not Paired"
            return
        }
        guard let url = URL(string: targetState.serverEndpoint.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            lastErrorMessage = HermesCompanionClientError.invalidURL.localizedDescription
            connectionStatus = "Approval Check Failed"
            return
        }
        if let warning = HermesEndpointSecurity.plaintextTransportWarning(for: url.absoluteString, endpointName: "Host Companion") {
            lastErrorMessage = warning
            connectionStatus = "Approval Check Failed"
            return
        }

        isEnrolling = true
        lastErrorMessage = ""
        connectionStatus = "Checking Approval"
        defer { isEnrolling = false }

        do {
            let result: HermesCompanionCheckDeviceApprovalResult = try await HermesCompanionSessionFactory.request(
                url: url,
                deviceID: nil,
                deviceSecret: nil,
                type: "check_device_approval",
                payload: HermesCompanionCheckDeviceApprovalPayload(deviceID: targetState.deviceID, deviceSecret: secret)
            )
            var newState = targetState
            if result.revoked {
                newState.revokedAt = Date()
                newState.approvedAt = nil
                connectionStatus = "Revoked"
            } else if result.approved {
                newState.approvedAt = newState.approvedAt ?? Date()
                newState.revokedAt = nil
                connectionStatus = "Device Approved"
            } else {
                connectionStatus = "Pending Approval"
            }
            var updatedConnection = connections.first(where: { $0.id == newState.deviceID }) ?? HermesCompanionSavedConnection(identityState: newState)
            updatedConnection.identityState = newState
            updatedConnection.lastMessage = result.message
            updatedConnection.updatedAt = Date()
            upsert(updatedConnection)
            if newState.deviceID == activeConnectionID {
                identityState = newState
                HermesSettingsPersistence.saveCompanionAuthenticationState(newState)
            }
            lastErrorMessage = result.message
        } catch {
            lastErrorMessage = error.localizedDescription
            connectionStatus = "Approval Check Failed"
        }

    }

    private func upsert(_ connection: HermesCompanionSavedConnection) {
        connections.removeAll { $0.id == connection.id }
        connections.append(connection)
        connections.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        HermesSettingsPersistence.saveCompanionConnections(connections)
    }

    private static func statusTitle(for state: HermesCompanionIdentityState) -> String {
        if state.revokedAt != nil { return "Revoked" }
        if state.isEnrolled { return "Device Approved" }
        if state.isPendingApproval { return "Pending Approval" }
        return "Not Paired"
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
    var servicePorts = HermesCompanionServicePortsResult()
    var servicePortsUpdatedAt: Date?
    var servicePortsError = ""
    var tailscaleServeStatus: HermesCompanionTailscaleServeStatusResult?
    var tailscaleServeOutput = ""
    var tailscaleServeError = ""
    var isCheckingTailscaleServe = false
    var isSettingTailscaleServe = false
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
    /// Errors belong to a request category. A failed schedule refresh must not
    /// turn Skills, Models, and every other already-loaded panel red.
    var runtimeSectionErrors: [String: String] = [:]
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
    var delegationModelConfig = HermesCompanionRuntimeModelSlotConfig(id: "delegation", label: "Delegation", section: "delegation", key: "delegation", provider: "", model: "", baseUrl: "")
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

    func runtimeSectionError(_ id: String) -> String { runtimeSectionErrors[id] ?? "" }

    private func markRuntimeSectionLoaded(_ id: String) {
        runtimeLoadedSectionIDs.insert(id)
        runtimeSectionErrors[id] = nil
    }

    func resetRuntimeScopeState() {
        runtimeLoadedSectionIDs = []
        runtimeSectionErrors = [:]
        lastErrorMessage = ""
        resolvedHermesWorkspacePath = ""
        hermesSkills = []
        hermesMCPServers = []
        hermesToolsets = []
        hermesModels = []
        providerEnv = [:]
        providerSections = []
        providerOptions = []
        providerCredentialPool = [:]
        providerModelConfig = HermesCompanionProviderModelConfig(provider: "auto", model: "", baseUrl: "")
        delegationModelConfig = HermesCompanionRuntimeModelSlotConfig(id: "delegation", label: "Delegation", section: "delegation", key: "delegation", provider: "", model: "", baseUrl: "")
        auxiliaryModelConfigs = []
        memoryConfig = nil
        memoryEntries = []
        schedules = []
        gatewayConfig = nil
        gatewayEnv = [:]
        gatewayPlatformEnabled = [:]
        observabilityLogContent = ""
        observabilityLoadedLineCount = 0
        knowledgeEraserItems = []
        knowledgeEraserSelectedItemIDs = []
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
            runtimeSectionErrors[id] = error.localizedDescription
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

    func refreshServicePorts(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) async throws -> HermesCompanionServicePortsResult {
        let result: HermesCompanionServicePortsResult = try await HermesCompanionSessionFactory.request(
            settings: settings,
            state: identityState,
            type: "service_ports",
            payload: HermesCompanionEmptyPayload()
        )
        servicePorts = result
        servicePortsUpdatedAt = Date()
        servicePortsError = ""
        return result
    }

    func refreshTailscaleServeStatus(port: String, settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        Task {
            guard identityState.isEnrolled else { return }
            isCheckingTailscaleServe = true
            tailscaleServeError = ""
            do {
                let result: HermesCompanionTailscaleServeStatusResult = try await HermesCompanionSessionFactory.request(
                    settings: settings,
                    state: identityState,
                    type: "tailscale_serve_status",
                    payload: HermesCompanionTailscaleServeStatusPayload(port: port)
                )
                tailscaleServeStatus = result
                tailscaleServeOutput = result.output
                connectionStatus = result.isEnabled ? "Tailscale Serve On" : "Tailscale Serve Off"
            } catch {
                tailscaleServeError = error.localizedDescription
                connectionStatus = "Tailscale Serve Unavailable"
            }
            isCheckingTailscaleServe = false
        }
    }

    func setTailscaleServe(_ enabled: Bool, port: String, settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        Task {
            guard identityState.isEnrolled else { return }
            isSettingTailscaleServe = true
            tailscaleServeError = ""
            connectionStatus = enabled ? "Enabling Tailscale Serve" : "Disabling Tailscale Serve"
            do {
                let result: HermesCompanionTailscaleServeStatusResult = try await HermesCompanionSessionFactory.request(
                    settings: settings,
                    state: identityState,
                    type: "set_tailscale_serve",
                    payload: HermesCompanionSetTailscaleServePayload(port: port, enabled: enabled)
                )
                tailscaleServeStatus = result
                tailscaleServeOutput = result.output
                connectionStatus = result.isEnabled ? "Tailscale Serve On" : "Tailscale Serve Off"
            } catch {
                tailscaleServeError = error.localizedDescription
                connectionStatus = "Tailscale Serve Failed"
                refreshTailscaleServeStatus(port: port, settings: settings, identityState: identityState)
            }
            isSettingTailscaleServe = false
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
                self.connectionStatus = result.status.conflictFiles.isEmpty ? "Hermes Updated and Pushed" : "Hermes Merge Conflicts"
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
        if result.isUpdateBlocked || result.conflictFiles.isEmpty == false {
            let conflictCount = result.conflictFiles.count
            if conflictCount > 0 {
                return "Resolve \(conflictCount) merge conflict\(conflictCount == 1 ? "" : "s") on the Mac"
            }
            return "Merge stopped; refresh after resolving"
        }
        if result.behindBy == 0 {
            return "Up to date"
        }
        return "\(result.behindBy) commit\(result.behindBy == 1 ? "" : "s") behind upstream main"
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

    private func run(category: String? = nil, _ operation: @escaping @MainActor () async throws -> Void) {
        Task {
            isBusy = true
            lastErrorMessage = ""
            do {
                try await operation()
            } catch {
                lastErrorMessage = error.localizedDescription
                if let category { runtimeSectionErrors[category] = error.localizedDescription }
                connectionStatus = "Failed"
            }
            isBusy = false
        }
    }

    func refreshHermesSkills(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run(category: "skills") {
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
        run(category: "gateway") {
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
        run(category: "gateway") {
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
        run(category: "gateway") {
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
        run(category: "gateway") {
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
        run(category: "gateway") {
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
        run(category: "gateway") {
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
        run(category: "mcpServers") {
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
            payload: HermesCompanionListMCPServersPayload(workspacePath: settings.hermesWorkspacePath)
        )
        hermesMCPServers = result.servers
        mcpListOutput = result.output
        resolvedHermesWorkspacePath = result.resolvedWorkspacePath
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
        run(category: "mcpServers") {
            self.connectionStatus = "Adding MCP Server"
            let result: HermesCompanionMCPOperationResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "add_mcp_server",
                payload: HermesCompanionAddMCPServerPayload(
                    workspacePath: settings.hermesWorkspacePath,
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
            self.resolvedHermesWorkspacePath = result.resolvedWorkspacePath
            self.connectionStatus = "MCP Server Added"
        }
    }

    func removeHermesMCPServer(name: String, settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run(category: "mcpServers") {
            self.connectionStatus = "Removing MCP Server"
            let result: HermesCompanionMCPOperationResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "remove_mcp_server",
                payload: HermesCompanionRemoveMCPServerPayload(workspacePath: settings.hermesWorkspacePath, name: name)
            )
            self.hermesMCPServers = result.servers
            self.mcpOperationOutput = result.output
            self.resolvedHermesWorkspacePath = result.resolvedWorkspacePath
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
        baseUrl: String,
        settings: HermesCompanionSettings,
        identityState: HermesCompanionIdentityState
    ) {
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
                    model: model,
                    baseUrl: baseUrl
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
        provider: String?,
        model: String?,
        baseUrl: String?,
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
                    deliver: deliver,
                    provider: provider,
                    model: model,
                    baseUrl: baseUrl
                )
            )
            self.applyScheduleOperation(result)
            self.connectionStatus = result.success ? "Schedule Created" : "Schedule Create Failed"
        }
    }

    func editSchedule(
        jobID: String,
        schedule: String?,
        prompt: String?,
        name: String?,
        deliver: String?,
        provider: String?,
        model: String?,
        baseUrl: String?,
        settings: HermesCompanionSettings,
        identityState: HermesCompanionIdentityState
    ) {
        run {
            self.connectionStatus = "Updating Schedule"
            let result: HermesCompanionScheduleOperationResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "edit_schedule",
                payload: HermesCompanionEditSchedulePayload(
                    workspacePath: settings.hermesWorkspacePath,
                    jobID: jobID,
                    schedule: schedule,
                    prompt: prompt,
                    name: name,
                    deliver: deliver,
                    provider: provider,
                    model: model,
                    baseUrl: baseUrl
                )
            )
            self.applyScheduleOperation(result)
            self.connectionStatus = result.success ? "Schedule Updated" : "Schedule Update Failed"
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

private final class HermesCompanionRequestState: @unchecked Sendable {
    private let lock = NSLock()
    nonisolated(unsafe) private var resumed = false
    nonisolated(unsafe) private var timedOut = false

    nonisolated var didTimeout: Bool {
        lock.lock()
        defer { lock.unlock() }
        return timedOut
    }

    nonisolated func markResumed() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard resumed == false else { return false }
        resumed = true
        return true
    }

    nonisolated func markTimedOut() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard resumed == false else { return false }
        resumed = true
        timedOut = true
        return true
    }
}

enum HermesCompanionSessionFactory {
    private static let networkQueue = DispatchQueue(label: "HermesCompanionNetworkWebSocket", qos: .userInitiated)

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 20
        return URLSession(configuration: configuration)
    }

    static func request<Payload: Encodable, Response: Decodable>(
        url: URL,
        deviceID: String?,
        deviceSecret: String?,
        type: String,
        payload: Payload?
    ) async throws -> Response {
        try await HermesBackgroundActivity.run(named: "Hermes Companion Request") {
            let envelope = HermesCompanionIncomingEnvelope(
                id: UUID().uuidString,
                type: type,
                deviceID: deviceID,
                deviceSecret: deviceSecret,
                payload: payload.flatMap(HermesCompanionJSONValue.encode)
            )
            let data = try JSONEncoder().encode(envelope)
            guard let text = String(data: data, encoding: .utf8) else {
                throw HermesCompanionClientError.invalidResponse
            }

            let responseData = try await companionWebSocketRoundTrip(url: url, text: text)

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
        let secret = deviceSecret(from: settings)
        guard secret.isEmpty == false else {
            throw HermesCompanionClientError.missingDeviceSecret
        }
        guard state.isPendingApproval == false else {
            throw HermesCompanionClientError.pendingApproval
        }
        guard state.revokedAt == nil else {
            throw HermesCompanionClientError.deviceRevoked
        }
        let endpoint = state.serverEndpoint.isEmpty ? settings.apiURL : state.serverEndpoint
        guard let url = URL(string: endpoint.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw HermesCompanionClientError.invalidURL
        }
        if let warning = HermesEndpointSecurity.plaintextTransportWarning(for: url.absoluteString, endpointName: "Host Companion") {
            throw HermesCompanionClientError.insecureEndpoint(warning)
        }
        return try await request(url: url, deviceID: state.deviceID, deviceSecret: secret, type: type, payload: payload)
    }

    private static func companionWebSocketRoundTrip(url: URL, text: String) async throws -> Data {
        guard let scheme = url.scheme?.lowercased() else {
            throw HermesCompanionClientError.invalidURL
        }
        if scheme == "ws", HermesEndpointSecurity.isPlaintextTransportAllowed(for: url) {
            return try await plaintextWebSocketRoundTrip(url: url, text: text)
        }
        return try await urlSessionWebSocketRoundTrip(url: url, text: text)
    }

    private static func urlSessionWebSocketRoundTrip(url: URL, text: String) async throws -> Data {
        let session = makeSession()
        defer { session.invalidateAndCancel() }

        let task = session.webSocketTask(with: url)
        let requestState = HermesCompanionRequestState()
        let timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            guard Task.isCancelled == false else { return }
            guard requestState.markTimedOut() else { return }
            task.cancel(with: .goingAway, reason: nil)
        }
        defer { timeoutTask.cancel() }

        do {
            task.resume()
            try await task.send(.string(text))

            let message = try await task.receive()
            _ = requestState.markResumed()
            switch message {
            case .data(let data):
                return data
            case .string(let text):
                return Data(text.utf8)
            @unknown default:
                throw HermesCompanionClientError.invalidResponse
            }
        } catch {
            if requestState.didTimeout {
                throw HermesCompanionClientError.requestTimedOut
            }
            throw error
        }
    }

    private static func plaintextWebSocketRoundTrip(url: URL, text: String) async throws -> Data {
        let portValue = url.port ?? 80
        guard let host = url.host,
              let port = NWEndpoint.Port(rawValue: UInt16(portValue)) else {
            throw HermesCompanionClientError.invalidURL
        }

        let parameters = NWParameters.tcp
        let connection = NWConnection(host: NWEndpoint.Host(host), port: port, using: parameters)
        defer { connection.cancel() }

        let key = webSocketKey()
        try await waitUntilTCPReady(connection)
        let handshake = plaintextWebSocketHandshake(url: url, host: host, port: portValue, key: key)
        try await sendTCPData(Data(handshake.utf8), on: connection)
        let headers = try await receiveHTTPHeaders(from: connection)
        try validatePlaintextWebSocketHandshake(headers, expectedKey: key)
        try await sendTCPData(maskedWebSocketFrame(opcode: 0x1, payload: Data(text.utf8)), on: connection)
        return try await receivePlaintextWebSocketMessage(from: connection)
    }

    private static func waitUntilTCPReady(_ connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let requestState = HermesCompanionRequestState()
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard requestState.markResumed() else { return }
                    continuation.resume()
                case .failed(let error):
                    guard requestState.markResumed() else { return }
                    continuation.resume(throwing: error)
                case .cancelled:
                    guard requestState.markResumed() else { return }
                    continuation.resume(throwing: requestState.didTimeout ? HermesCompanionClientError.requestTimedOut : HermesCompanionClientError.invalidResponse)
                default:
                    break
                }
            }
            networkQueue.asyncAfter(deadline: .now() + 15) {
                guard requestState.markTimedOut() else { return }
                connection.cancel()
                continuation.resume(throwing: HermesCompanionClientError.requestTimedOut)
            }
            connection.start(queue: networkQueue)
        }
    }

    private static func sendTCPData(_ data: Data, on connection: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let requestState = HermesCompanionRequestState()
            connection.send(content: data, completion: .contentProcessed { error in
                guard requestState.markResumed() else { return }
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            })
            networkQueue.asyncAfter(deadline: .now() + 15) {
                guard requestState.markTimedOut() else { return }
                connection.cancel()
                continuation.resume(throwing: HermesCompanionClientError.requestTimedOut)
            }
        }
    }

    private static func receiveTCPData(from connection: NWConnection, maximumLength: Int) async throws -> Data {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            let requestState = HermesCompanionRequestState()
            connection.receive(minimumIncompleteLength: 1, maximumLength: maximumLength) { data, _, isComplete, error in
                guard requestState.markResumed() else { return }
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let data, data.isEmpty == false {
                    continuation.resume(returning: data)
                    return
                }
                continuation.resume(throwing: isComplete ? HermesCompanionClientError.invalidResponse : HermesCompanionClientError.requestTimedOut)
            }
            networkQueue.asyncAfter(deadline: .now() + 15) {
                guard requestState.markTimedOut() else { return }
                connection.cancel()
                continuation.resume(throwing: HermesCompanionClientError.requestTimedOut)
            }
        }
    }

    private static func receiveExactTCPData(length: Int, from connection: NWConnection) async throws -> Data {
        var buffer = Data()
        while buffer.count < length {
            let chunk = try await receiveTCPData(from: connection, maximumLength: length - buffer.count)
            buffer.append(chunk)
        }
        return buffer
    }

    private static func receiveHTTPHeaders(from connection: NWConnection) async throws -> String {
        let terminator = Data("\r\n\r\n".utf8)
        var buffer = Data()
        while buffer.range(of: terminator) == nil {
            let chunk = try await receiveTCPData(from: connection, maximumLength: 4096)
            buffer.append(chunk)
            guard buffer.count <= 65_536 else {
                throw HermesCompanionClientError.invalidResponse
            }
        }
        guard let text = String(data: buffer, encoding: .utf8) else {
            throw HermesCompanionClientError.invalidResponse
        }
        return text
    }

    private static func plaintextWebSocketHandshake(url: URL, host: String, port: Int, key: String) -> String {
        let querySuffix = url.query.map { "?\($0)" } ?? ""
        let path = (url.path.isEmpty ? "/" : url.path) + querySuffix
        let hostHeader = webSocketHostHeader(host: host, port: port)
        return "GET \(path) HTTP/1.1\r\n"
            + "Host: \(hostHeader)\r\n"
            + "Upgrade: websocket\r\n"
            + "Connection: Upgrade\r\n"
            + "Sec-WebSocket-Key: \(key)\r\n"
            + "Sec-WebSocket-Version: 13\r\n"
            + "User-Agent: HermesiOS Host Companion\r\n"
            + "\r\n"
    }

    private static func webSocketHostHeader(host: String, port: Int) -> String {
        let normalizedHost = host.contains(":") && host.hasPrefix("[") == false ? "[\(host)]" : host
        return port == 80 ? normalizedHost : "\(normalizedHost):\(port)"
    }

    private static func validatePlaintextWebSocketHandshake(_ headers: String, expectedKey: String) throws {
        let lines = headers.components(separatedBy: "\r\n")
        guard let statusLine = lines.first,
              statusLine.contains(" 101 ") || statusLine.hasSuffix(" 101") || statusLine.contains(" 101 Switching Protocols") else {
            throw HermesCompanionClientError.invalidResponse
        }
        var headerFields: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let colonIndex = line.firstIndex(of: ":") else { continue }
            let name = String(line[..<colonIndex]).lowercased()
            let value = line[line.index(after: colonIndex)...].trimmingCharacters(in: .whitespacesAndNewlines)
            headerFields[name] = value
        }
        let expectedAccept = webSocketAcceptValue(for: expectedKey)
        guard headerFields["sec-websocket-accept"] == expectedAccept else {
            throw HermesCompanionClientError.invalidResponse
        }
    }

    private static func receivePlaintextWebSocketMessage(from connection: NWConnection) async throws -> Data {
        while true {
            let header = try await receiveExactTCPData(length: 2, from: connection)
            let firstByte = header[header.startIndex]
            let secondByte = header[header.index(after: header.startIndex)]
            let isFinal = (firstByte & 0x80) != 0
            let opcode = firstByte & 0x0F
            var payloadLength = Int(secondByte & 0x7F)
            if payloadLength == 126 {
                let lengthData = try await receiveExactTCPData(length: 2, from: connection)
                payloadLength = Int(UInt16(lengthData[0]) << 8 | UInt16(lengthData[1]))
            } else if payloadLength == 127 {
                let lengthData = try await receiveExactTCPData(length: 8, from: connection)
                payloadLength = lengthData.reduce(0) { ($0 << 8) | Int($1) }
            }
            let isMasked = (secondByte & 0x80) != 0
            let mask = isMasked ? try await receiveExactTCPData(length: 4, from: connection) : Data()
            var payload = payloadLength > 0 ? try await receiveExactTCPData(length: payloadLength, from: connection) : Data()
            if isMasked {
                for index in payload.indices {
                    payload[index] ^= mask[index % 4]
                }
            }

            switch opcode {
            case 0x1, 0x2:
                guard isFinal else { throw HermesCompanionClientError.invalidResponse }
                return payload
            case 0x8:
                throw HermesCompanionClientError.invalidResponse
            case 0x9:
                try await sendTCPData(maskedWebSocketFrame(opcode: 0xA, payload: payload), on: connection)
            case 0xA:
                continue
            default:
                throw HermesCompanionClientError.invalidResponse
            }
        }
    }

    private static func maskedWebSocketFrame(opcode: UInt8, payload: Data) -> Data {
        var frame = Data([0x80 | opcode])
        let payloadCount = payload.count
        let mask = Data((0..<4).map { _ in UInt8.random(in: 0...255) })
        if payloadCount < 126 {
            frame.append(0x80 | UInt8(payloadCount))
        } else if payloadCount <= UInt16.max {
            frame.append(0x80 | 126)
            frame.append(UInt8((payloadCount >> 8) & 0xFF))
            frame.append(UInt8(payloadCount & 0xFF))
        } else {
            frame.append(0x80 | 127)
            for shift in stride(from: 56, through: 0, by: -8) {
                frame.append(UInt8((UInt64(payloadCount) >> UInt64(shift)) & 0xFF))
            }
        }
        frame.append(mask)
        for (offset, byte) in payload.enumerated() {
            frame.append(byte ^ mask[offset % 4])
        }
        return frame
    }

    private static func webSocketKey() -> String {
        Data((0..<16).map { _ in UInt8.random(in: 0...255) }).base64EncodedString()
    }

    private static func webSocketAcceptValue(for key: String) -> String {
        let magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let digest = Insecure.SHA1.hash(data: Data((key + magic).utf8))
        return Data(digest).base64EncodedString()
    }

    static func deviceSecret(from settings: HermesCompanionSettings, deviceID: String? = nil) -> String {
        let settingSecret = settings.deviceSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        if settingSecret.isEmpty == false, deviceID == nil || deviceID == HermesSettingsPersistence.loadActiveCompanionConnectionID() { return settingSecret }
        return HermesSettingsPersistence.loadCompanionDeviceSecret(deviceID: deviceID)
    }
}


private struct EmptyPayload: Encodable {}
