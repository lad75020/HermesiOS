//
//  HermesTUIProfileSkills.swift
//  HermesiOS
//

import Foundation

struct HermesTUIProfileSkill: Identifiable, Equatable {
    let name: String
    let isEnabled: Bool
    let occurrenceCount: Int

    init(name: String, isEnabled: Bool, occurrenceCount: Int = 1) {
        self.name = name
        self.isEnabled = isEnabled
        self.occurrenceCount = occurrenceCount
    }

    var id: String { name }
}

struct HermesTUIProfileSkills: Equatable {
    let profileName: String
    let skills: [HermesTUIProfileSkill]

    var installedCount: Int { skills.reduce(0) { $0 + $1.occurrenceCount } }
    var enabledCount: Int { skills.filter(\.isEnabled).reduce(0) { $0 + $1.occurrenceCount } }

    static func decode(_ value: JSONValue, profileName: String) throws -> Self {
        let trimmedProfileName = profileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedProfileName.isEmpty, trimmedProfileName == profileName else {
            throw HermesTUIGatewayError.requestFailed("A non-empty, exact profile name is required to load its skills.")
        }
        guard case .object(let response) = value else {
            throw HermesTUIGatewayError.requestFailed("Invalid TUI Gateway profile skills response: expected an object.")
        }
        guard case .string(let responseProfileName)? = response["name"], responseProfileName == profileName else {
            throw HermesTUIGatewayError.requestFailed("TUI Gateway returned skills for a different profile than \(profileName).")
        }
        guard case .array(let rows)? = response["skills"] else {
            throw HermesTUIGatewayError.requestFailed("Invalid TUI Gateway profile skills response: missing skills array.")
        }

        var byName: [String: HermesTUIProfileSkill] = [:]
        for (index, value) in rows.enumerated() {
            guard case .object(let row) = value else {
                throw HermesTUIGatewayError.requestFailed("Invalid profile skill at position \(index + 1): expected an object.")
            }
            guard case .string(let name)? = row["name"], !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw HermesTUIGatewayError.requestFailed("Invalid profile skill at position \(index + 1): name must be nonblank.")
            }
            guard case .bool(let enabled)? = row["enabled"] else {
                throw HermesTUIGatewayError.requestFailed("Invalid profile skill \(name): enabled must be a boolean.")
            }
            if let existing = byName[name], existing.isEnabled != enabled {
                throw HermesTUIGatewayError.requestFailed("Conflicting states for skill \(name); use Companion to inspect its paths.")
            }
            // The RPC returns leaf names, not paths. Retain duplicate counts without inventing paths.
            byName[name] = HermesTUIProfileSkill(name: name, isEnabled: enabled, occurrenceCount: (byName[name]?.occurrenceCount ?? 0) + 1)
        }

        let skills = byName.values.sorted { $0.name < $1.name }
        return Self(profileName: profileName, skills: skills)
    }
}
