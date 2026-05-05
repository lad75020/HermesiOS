//
//  CompanionAuthenticationStore.swift
//  HermesHostCompanion
//
//  Created by Codex on 05/05/2026.
//

import CryptoKit
import Foundation
import Security

struct CompanionDevicePermissions: Codable {
    let targetIDs: [String]
    let operations: [String]
    let serviceIDs: [String]
    let serviceActions: [String]

    static let minimalV1 = CompanionDevicePermissions(
        targetIDs: ["hermes-config"],
        operations: ["read", "validate", "write", "backup"],
        serviceIDs: ["hermesd"],
        serviceActions: ["status", "restart"]
    )
}

struct CompanionEnrolledDevice: Codable, Identifiable {
    let id: String
    let commonName: String
    let fingerprint: String
    let issuedAt: Date
    var isRevoked: Bool
    let permissions: CompanionDevicePermissions
}

struct CompanionPairingRecord: Codable, Identifiable {
    let id: String
    let secret: String
    let createdAt: Date
    let expiresAt: Date
    let displayCode: String
    var consumedAt: Date?

    var isActive: Bool {
        consumedAt == nil && expiresAt > Date()
    }
}

private struct CompanionAuthenticationDocument: Codable {
    var devices: [CompanionEnrolledDevice]
    var pairings: [CompanionPairingRecord]
}

enum CompanionAuthenticationStoreError: LocalizedError {
    case untrustedClient
    case unknownDevice
    case revokedDevice
    case pairingUnavailable
    case pairingExpired
    case invalidCSR

    var errorDescription: String? {
        switch self {
        case .untrustedClient:
            "The client certificate is not trusted by the companion."
        case .unknownDevice:
            "The client certificate is not enrolled in the companion device registry."
        case .revokedDevice:
            "This enrolled device has been revoked."
        case .pairingUnavailable:
            "The pairing record does not exist or has already been consumed."
        case .pairingExpired:
            "The pairing record has expired."
        case .invalidCSR:
            "The enrollment request is missing a valid certificate signing request."
        }
    }
}

final class CompanionAuthenticationStore {
    static let shared = CompanionAuthenticationStore()

    private let fileManager = FileManager.default
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func authorizeClientTrust(_ trust: SecTrust) throws -> CompanionEnrolledDevice {
        guard let certificate = SecTrustGetCertificateAtIndex(trust, 0) else {
            throw CompanionAuthenticationStoreError.untrustedClient
        }

        let fingerprint = Self.fingerprint(for: certificate)
        let document = try loadDocument()
        guard let device = document.devices.first(where: { $0.fingerprint == fingerprint }) else {
            throw CompanionAuthenticationStoreError.unknownDevice
        }
        guard device.isRevoked == false else {
            throw CompanionAuthenticationStoreError.revokedDevice
        }
        return device
    }

    func listActivePairings() -> [CompanionPairingSummary] {
        let document = (try? loadDocument()) ?? CompanionAuthenticationDocument(devices: [], pairings: [])
        return document.pairings
            .filter(\.isActive)
            .sorted { $0.createdAt > $1.createdAt }
            .map {
                CompanionPairingSummary(
                    id: $0.id,
                    secret: $0.secret,
                    createdAt: $0.createdAt,
                    expiresAt: $0.expiresAt,
                    displayCode: $0.displayCode
                )
            }
    }

    @discardableResult
    func createPairing(expiresIn: TimeInterval = 10 * 60) throws -> CompanionPairingSummary {
        var document = try loadDocument()
        let now = Date()
        let pairing = CompanionPairingRecord(
            id: UUID().uuidString.lowercased(),
            secret: Self.randomToken(length: 32),
            createdAt: now,
            expiresAt: now.addingTimeInterval(expiresIn),
            displayCode: Self.displayCode()
        )
        document.pairings.removeAll { $0.expiresAt <= now || $0.consumedAt != nil }
        document.pairings.insert(pairing, at: 0)
        try saveDocument(document)
        return CompanionPairingSummary(
            id: pairing.id,
            secret: pairing.secret,
            createdAt: pairing.createdAt,
            expiresAt: pairing.expiresAt,
            displayCode: pairing.displayCode
        )
    }

    func enrollDevice(
        pairingID: String,
        pairingSecret: String,
        deviceName: String,
        clientCertificatePEM: String
    ) throws -> CompanionEnrolledDevice {
        guard clientCertificatePEM.contains("BEGIN CERTIFICATE") else {
            throw CompanionAuthenticationStoreError.invalidCSR
        }

        var document = try loadDocument()
        guard let pairingIndex = document.pairings.firstIndex(where: { $0.id == pairingID && $0.consumedAt == nil }) else {
            throw CompanionAuthenticationStoreError.pairingUnavailable
        }
        guard document.pairings[pairingIndex].secret == pairingSecret else {
            throw CompanionAuthenticationStoreError.pairingUnavailable
        }
        guard document.pairings[pairingIndex].expiresAt > Date() else {
            throw CompanionAuthenticationStoreError.pairingExpired
        }

        let certificate = try Self.certificate(fromPEM: clientCertificatePEM)
        let fingerprint = Self.fingerprint(for: certificate)
        let commonName = deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Hermes iOS Device" : deviceName

        if let existingIndex = document.devices.firstIndex(where: { $0.fingerprint == fingerprint }) {
            document.pairings[pairingIndex].consumedAt = Date()
            try saveDocument(document)
            return document.devices[existingIndex]
        }

        let device = CompanionEnrolledDevice(
            id: UUID().uuidString.lowercased(),
            commonName: commonName,
            fingerprint: fingerprint,
            issuedAt: Date(),
            isRevoked: false,
            permissions: .minimalV1
        )
        document.devices.append(device)
        document.pairings[pairingIndex].consumedAt = Date()
        try saveDocument(document)
        return device
    }

    private func loadDocument() throws -> CompanionAuthenticationDocument {
        let url = try documentURL()
        guard fileManager.fileExists(atPath: url.path) else {
            let document = CompanionAuthenticationDocument(devices: [], pairings: [])
            try saveDocument(document)
            return document
        }
        let data = try Data(contentsOf: url)
        return try decoder.decode(CompanionAuthenticationDocument.self, from: data)
    }

    private func saveDocument(_ document: CompanionAuthenticationDocument) throws {
        let url = try documentURL()
        let data = try encoder.encode(document)
        try data.write(to: url, options: .atomic)
    }

    private func documentURL() throws -> URL {
        let directory = try applicationSupportDirectory()
        if fileManager.fileExists(atPath: directory.path) == false {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory.appendingPathComponent("authentication.json")
    }

    private func applicationSupportDirectory() throws -> URL {
        try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("HermesHostCompanion", isDirectory: true)
    }

    private static func certificate(fromPEM pem: String) throws -> SecCertificate {
        let lines = pem
            .components(separatedBy: .newlines)
            .filter { $0.contains("BEGIN CERTIFICATE") == false && $0.contains("END CERTIFICATE") == false && $0.isEmpty == false }
            .joined()
        guard
            let data = Data(base64Encoded: lines),
            let certificate = SecCertificateCreateWithData(nil, data as CFData)
        else {
            throw CompanionAuthenticationStoreError.invalidCSR
        }
        return certificate
    }

    static func fingerprint(for certificate: SecCertificate) -> String {
        let data = SecCertificateCopyData(certificate) as Data
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func randomToken(length: Int) -> String {
        let characters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        return String((0..<length).map { _ in characters.randomElement()! })
    }

    private static func displayCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let segments = (0..<3).map { _ in
            String((0..<4).map { _ in alphabet.randomElement()! })
        }
        return segments.joined(separator: "-")
    }
}
