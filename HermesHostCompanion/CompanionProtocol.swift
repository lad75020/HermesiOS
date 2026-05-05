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
