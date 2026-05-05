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

struct EnrollmentHelloResult: Codable {
    let protocolVersion: String
    let serverName: String
    let capabilities: [String]
    let requiresPairingCode: Bool
}

struct ListTargetsResult: Codable {
    let targets: [CompanionTargetSummary]
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

struct ServiceRestartResult: Codable {
    let serviceID: String
    let status: CompanionManagedServiceStatus
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

struct EnrollClientPayload: Codable {
    let pairingID: String
    let pairingSecret: String
    let deviceName: String
}

struct EnrollClientResult: Codable {
    let deviceID: String
    let deviceName: String
    let clientIdentityPKCS12Base64: String
    let clientIdentityPassword: String
    let caCertificatePEM: String
    let serverEndpoint: String
    let serverCertificateFingerprint: String
}

struct CompanionPairingSummary: Codable, Identifiable {
    let id: String
    let secret: String
    let createdAt: Date
    let expiresAt: Date
    let displayCode: String
}

enum CompanionManagedServiceStatus: String, Codable {
    case running
    case stopped
    case unknown
    case restarted
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
