//
//  HermesCompanionClient.swift
//  HermesiOS
//
//  Created by Codex on 05/05/2026.
//

import CryptoKit
import CoreImage
import Foundation
import Observation
import Security
import UIKit
import Vision
import VisionKit

struct HermesCompanionSettings: Codable, Equatable {
    var enrollmentURL = "wss://127.0.0.1:9113/enroll"
    var apiURL = "wss://127.0.0.1:9112/ws"
    var expectedServerFingerprint = ""
    var deviceName = "Hermes iOS Device"
    var pairingID = ""
    var pairingSecret = ""
    var hermesWorkspacePath = "/Volumes/WDBlack4TB/Code/HermesiOS/.hermes"
}

struct HermesCompanionIdentityState: Codable, Equatable {
    var deviceID = ""
    var deviceName = ""
    var serverEndpoint = ""
    var serverCertificateFingerprint = ""
    var issuedAt = Date()

    var isEnrolled: Bool {
        deviceID.isEmpty == false
    }
}

struct HermesCompanionPairingQRCodePayload: Codable {
    let version: Int
    let enrollmentURL: String
    let apiURL: String
    let serverFingerprint: String
    let pairingID: String
    let pairingSecret: String
}

struct HermesStoredCompanionIdentity: Codable {
    let pkcs12Base64: String
    let password: String
}

struct HermesCompanionIncomingEnvelope: Codable {
    let id: String?
    let type: String
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

struct HermesEnrollClientPayload: Codable {
    let pairingID: String
    let pairingSecret: String
    let deviceName: String
}

struct HermesEnrollClientResult: Codable {
    let deviceID: String
    let deviceName: String
    let clientIdentityPKCS12Base64: String
    let clientIdentityPassword: String
    let caCertificatePEM: String
    let serverEndpoint: String
    let serverCertificateFingerprint: String
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

struct HermesCompanionServiceStatusResult: Codable, Equatable {
    let serviceID: String
    let status: HermesCompanionManagedServiceStatus
    let output: String
}

struct HermesCompanionServiceRestartPayload: Codable {
    let serviceID: String
}

struct HermesCompanionServiceRestartResult: Codable {
    let serviceID: String
    let status: HermesCompanionManagedServiceStatus
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
    case missingPinnedFingerprint
    case invalidIdentityBundle
    case untrustedServer
    case notEnrolled
    case invalidPairingQRCode

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "The companion enrollment URL is invalid."
        case .invalidResponse:
            "The companion returned an invalid enrollment response."
        case .serverRejected(let message):
            message
        case .missingPayload:
            "The companion enrollment response did not include an identity payload."
        case .missingPinnedFingerprint:
            "Enter the companion server fingerprint before attempting enrollment."
        case .invalidIdentityBundle:
            "The enrolled client identity could not be imported on this device."
        case .untrustedServer:
            "The companion server certificate fingerprint does not match the expected value."
        case .notEnrolled:
            "Enroll this iOS device with the host companion before using runtime controls."
        case .invalidPairingQRCode:
            "The scanned QR code is not a valid Hermes companion pairing payload."
        }
    }
}

@MainActor
@Observable
final class HermesCompanionEnrollmentSession {
    var isEnrolling = false
    var connectionStatus = "Not Enrolled"
    var lastErrorMessage = ""
    var identityState: HermesCompanionIdentityState

    private var enrollmentTask: Task<Void, Never>?

    init() {
        let persistedState = HermesSettingsPersistence.loadCompanionIdentityState()
        identityState = persistedState
        if persistedState.isEnrolled {
            connectionStatus = "Enrolled"
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
        connectionStatus = "Not Enrolled"
        lastErrorMessage = ""
        HermesSettingsPersistence.clearCompanionIdentity()
    }

    private func runEnrollment(settings: HermesCompanionSettings) async {
        let trimmedFingerprint = HermesCompanionSessionFactory.normalizedFingerprint(settings.expectedServerFingerprint)
        guard trimmedFingerprint.isEmpty == false else {
            lastErrorMessage = HermesCompanionClientError.missingPinnedFingerprint.localizedDescription
            connectionStatus = "Enrollment Failed"
            return
        }

        guard let url = URL(string: settings.enrollmentURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            lastErrorMessage = HermesCompanionClientError.invalidURL.localizedDescription
            connectionStatus = "Enrollment Failed"
            return
        }

        isEnrolling = true
        lastErrorMessage = ""
        connectionStatus = "Contacting Enrollment Endpoint"

        do {
            let result = try await HermesCompanionSessionFactory.enroll(
                url: url,
                expectedServerFingerprint: trimmedFingerprint,
                payload: HermesEnrollClientPayload(
                    pairingID: settings.pairingID.trimmingCharacters(in: .whitespacesAndNewlines),
                    pairingSecret: settings.pairingSecret.trimmingCharacters(in: .whitespacesAndNewlines),
                    deviceName: settings.deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )

            let newState = HermesCompanionIdentityState(
                deviceID: result.deviceID,
                deviceName: result.deviceName,
                serverEndpoint: result.serverEndpoint,
                serverCertificateFingerprint: HermesCompanionSessionFactory.normalizedFingerprint(result.serverCertificateFingerprint),
                issuedAt: Date()
            )
            try HermesSettingsPersistence.saveCompanionIdentity(
                pkcs12Base64: result.clientIdentityPKCS12Base64,
                password: result.clientIdentityPassword,
                state: newState
            )
            identityState = newState
            connectionStatus = "Enrolled"
        } catch {
            lastErrorMessage = error.localizedDescription
            connectionStatus = "Enrollment Failed"
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
    var linkedServiceStatus = ""
    var linkedServiceOutput = ""
    var connectionStatus = "Idle"
    var lastErrorMessage = ""
    var isBusy = false
    var hermesSkills: [HermesCompanionSkillSummary] = []
    var resolvedHermesWorkspacePath = ""
    var hermesToolsets: [HermesCompanionToolsetInfo] = []
    var toolsetsConfigPath = ""
    var hermesModels: [HermesCompanionSavedModel] = []
    var modelsFilePath = ""
    var providerEnv: [String: String] = [:]
    var providerSections: [HermesCompanionProviderEnvSection] = []
    var providerOptions: [HermesCompanionProviderOption] = []
    var providerCredentialPool: [String: [HermesCompanionProviderCredentialEntry]] = [:]
    var providerModelConfig = HermesCompanionProviderModelConfig(provider: "auto", model: "", baseUrl: "")
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
    var schedules: [HermesCompanionScheduleCronJob] = []
    var schedulesFilePath = ""

    var selectedTarget: HermesCompanionTargetSummary? {
        targets.first(where: { $0.id == selectedTargetID })
    }

    func refreshTargets(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Loading Targets"
            let result: HermesCompanionListTargetsResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "list_targets",
                payload: HermesCompanionListTargetsPayload(workspacePath: settings.hermesWorkspacePath)
            )
            self.targets = result.targets
            if self.selectedTargetID.isEmpty || self.targets.contains(where: { $0.id == self.selectedTargetID }) == false {
                self.selectedTargetID = self.targets.first?.id ?? ""
            }
            self.connectionStatus = self.targets.isEmpty ? "No Targets" : "Targets Loaded"
            if self.selectedTarget != nil {
                try await self.loadSelectedTarget(settings: settings, identityState: identityState)
            }
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
                payload: HermesCompanionValidateTargetPayload(targetID: selectedTarget.id, content: self.targetContent)
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
                    createBackup: true
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

    private func loadSelectedTarget(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) async throws {
        guard let selectedTarget else { return }
        connectionStatus = "Reading \(selectedTarget.displayName)"
        let result: HermesCompanionReadTargetResult = try await HermesCompanionSessionFactory.request(
            settings: settings,
            state: identityState,
            type: "read_target",
            payload: HermesCompanionReadTargetPayload(targetID: selectedTarget.id)
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
            let result: HermesCompanionListSkillsResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "list_skills",
                payload: HermesCompanionListSkillsPayload(workspacePath: settings.hermesWorkspacePath)
            )
            self.hermesSkills = result.skills
            self.resolvedHermesWorkspacePath = result.resolvedWorkspacePath
            self.connectionStatus = result.skills.isEmpty ? "No Skills Found" : "Skills Loaded"
        }
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

    func refreshHermesToolsets(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Loading Toolsets"
            let result: HermesCompanionListToolsetsResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "list_toolsets",
                payload: HermesCompanionListToolsetsPayload(workspacePath: settings.hermesWorkspacePath)
            )
            self.hermesToolsets = result.toolsets
            self.toolsetsConfigPath = result.configPath
            self.resolvedHermesWorkspacePath = result.resolvedWorkspacePath
            self.connectionStatus = result.toolsets.isEmpty ? "No Toolsets Found" : "Toolsets Loaded"
        }
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
            let result: HermesCompanionListModelsResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "list_models",
                payload: HermesCompanionListModelsPayload(workspacePath: settings.hermesWorkspacePath)
            )
            self.hermesModels = result.models
            self.modelsFilePath = result.modelsFilePath
            self.resolvedHermesWorkspacePath = result.resolvedWorkspacePath
            self.connectionStatus = result.models.isEmpty ? "No Models Found" : "Models Loaded"
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
            let result: HermesCompanionProvidersConfigResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "get_providers_config",
                payload: HermesCompanionProvidersConfigPayload(workspacePath: settings.hermesWorkspacePath)
            )
            self.applyProvidersConfig(result)
            self.connectionStatus = "Providers Loaded"
        }
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
        providerEnvFilePath = result.envFilePath
        providerConfigPath = result.configPath
        providerAuthFilePath = result.authFilePath
        resolvedHermesWorkspacePath = result.resolvedWorkspacePath
    }


    func refreshMemoryConfig(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Loading Memory"
            let result: HermesCompanionMemoryConfigResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "get_memory_config",
                payload: HermesCompanionMemoryConfigPayload(workspacePath: settings.hermesWorkspacePath)
            )
            self.applyMemoryConfig(result)
            self.connectionStatus = "Memory Loaded"
        }
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

    private func applyMemoryOperation(_ result: HermesCompanionMemoryOperationResult) {
        resolvedHermesWorkspacePath = result.resolvedWorkspacePath
        if let error = result.error, !error.isEmpty {
            lastErrorMessage = error
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

    func refreshSchedules(settings: HermesCompanionSettings, identityState: HermesCompanionIdentityState) {
        run {
            self.connectionStatus = "Loading Schedules"
            let result: HermesCompanionListSchedulesResult = try await HermesCompanionSessionFactory.request(
                settings: settings,
                state: identityState,
                type: "list_schedules",
                payload: HermesCompanionListSchedulesPayload(workspacePath: settings.hermesWorkspacePath, includeDisabled: true)
            )
            self.applySchedules(result)
            self.connectionStatus = result.jobs.isEmpty ? "No Schedules" : "Schedules Loaded"
        }
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
    static func makeSession(for settings: HermesCompanionSettings, state: HermesCompanionIdentityState) -> URLSession {
        let delegate = HermesCompanionURLSessionDelegate(
            expectedServerFingerprint: normalizedFingerprint(
                state.serverCertificateFingerprint.isEmpty ? settings.expectedServerFingerprint : state.serverCertificateFingerprint
            ),
            identityProvider: HermesCompanionIdentityLoader.loadCredential
        )
        return URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
    }

    static func enroll(
        url: URL,
        expectedServerFingerprint: String,
        payload: HermesEnrollClientPayload
    ) async throws -> HermesEnrollClientResult {
        let delegate = HermesCompanionURLSessionDelegate(
            expectedServerFingerprint: expectedServerFingerprint,
            identityProvider: { nil }
        )
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        defer { session.invalidateAndCancel() }

        let task = session.webSocketTask(with: url)
        task.resume()

        let envelope = HermesCompanionIncomingEnvelope(
            id: UUID().uuidString,
            type: "enroll_client",
            payload: .encode(payload)
        )
        let requestData = try JSONEncoder().encode(envelope)
        guard let requestString = String(data: requestData, encoding: .utf8) else {
            throw HermesCompanionClientError.invalidResponse
        }
        try await task.send(.string(requestString))

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
            throw HermesCompanionClientError.serverRejected(response.error?.message ?? "The companion rejected the enrollment request.")
        }
        guard let payload = response.payload else {
            throw HermesCompanionClientError.missingPayload
        }

        return try payload.decode(HermesEnrollClientResult.self)
    }

    static func normalizedFingerprint(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

        let endpoint = state.serverEndpoint.isEmpty ? settings.apiURL : state.serverEndpoint
        guard let url = URL(string: endpoint.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw HermesCompanionClientError.invalidURL
        }

        let session = makeSession(for: settings, state: state)
        defer { session.invalidateAndCancel() }

        let task = session.webSocketTask(with: url)
        task.resume()

        let envelope = HermesCompanionIncomingEnvelope(
            id: UUID().uuidString,
            type: type,
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

enum HermesCompanionPairingPayloadDecoder {
    static func decode(_ rawValue: String) throws -> HermesCompanionPairingQRCodePayload {
        guard let data = rawValue.data(using: .utf8) else {
            throw HermesCompanionClientError.invalidPairingQRCode
        }
        let payload = try JSONDecoder().decode(HermesCompanionPairingQRCodePayload.self, from: data)
        guard payload.version == 1 else {
            throw HermesCompanionClientError.invalidPairingQRCode
        }
        return payload
    }
}

enum HermesPairingImageDecoder {
    static func decode(from imageData: Data) throws -> HermesCompanionPairingQRCodePayload {
        guard let ciImage = CIImage(data: imageData) else {
            throw HermesCompanionClientError.invalidPairingQRCode
        }

        let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )
        guard
            let features = detector?.features(in: ciImage) as? [CIQRCodeFeature],
            let payload = features.compactMap(\.messageString).first
        else {
            throw HermesCompanionClientError.invalidPairingQRCode
        }

        return try HermesCompanionPairingPayloadDecoder.decode(payload)
    }
}

private struct EmptyPayload: Encodable {}

private final class HermesCompanionURLSessionDelegate: NSObject, URLSessionDelegate {
    private let expectedServerFingerprint: String
    private let identityProvider: () -> URLCredential?

    init(expectedServerFingerprint: String, identityProvider: @escaping () -> URLCredential?) {
        self.expectedServerFingerprint = expectedServerFingerprint
        self.identityProvider = identityProvider
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodServerTrust:
            guard
                let trust = challenge.protectionSpace.serverTrust,
                let certificates = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
                let certificate = certificates.first
            else {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }

            let fingerprint = HermesCompanionSessionFactory.normalizedFingerprint(
                CompanionCertificateFingerprint.fingerprint(for: certificate)
            )
            guard fingerprint == expectedServerFingerprint else {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }

            completionHandler(.useCredential, URLCredential(trust: trust))
        case NSURLAuthenticationMethodClientCertificate:
            if let credential = identityProvider() {
                completionHandler(.useCredential, credential)
            } else {
                completionHandler(.rejectProtectionSpace, nil)
            }
        default:
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

private enum CompanionCertificateFingerprint {
    static func fingerprint(for certificate: SecCertificate) -> String {
        let data = SecCertificateCopyData(certificate) as Data
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private enum HermesCompanionIdentityLoader {
    nonisolated static func loadCredential() -> URLCredential? {
        struct StoredIdentity: Decodable {
            let pkcs12Base64: String
            let password: String
        }

        let service = "com.hermesios.companion"
        let account = "clientIdentity"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard
            status == errSecSuccess,
            let data = item as? Data,
            let storedIdentity = try? JSONDecoder().decode(StoredIdentity.self, from: data),
            let pkcs12Data = Data(base64Encoded: storedIdentity.pkcs12Base64)
        else {
            return nil
        }

        let options = [kSecImportExportPassphrase as String: storedIdentity.password]
        var items: CFArray?
        let importStatus = SecPKCS12Import(pkcs12Data as CFData, options as CFDictionary, &items)
        guard
            importStatus == errSecSuccess,
            let array = items as? [[String: Any]],
            let rawIdentity = array.first?[kSecImportItemIdentity as String],
            let certificateChain = array.first?[kSecImportItemCertChain as String] as? [SecCertificate]
        else {
            return nil
        }

        let identity = rawIdentity as! SecIdentity
        return URLCredential(identity: identity, certificates: certificateChain, persistence: .forSession)
    }
}
