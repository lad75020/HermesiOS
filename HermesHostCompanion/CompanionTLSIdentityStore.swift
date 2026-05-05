//
//  CompanionTLSIdentityStore.swift
//  HermesHostCompanion
//
//  Created by Codex on 05/05/2026.
//

import CryptoKit
import Foundation
import Security

struct CompanionServerIdentity {
    let secIdentity: SecIdentity
    let caCertificate: SecCertificate
    let serverCertificateFingerprint: String
}

struct CompanionSignedClientIdentity {
    let certificatePEM: String
    let caCertificatePEM: String
}

enum CompanionTLSIdentityStoreError: LocalizedError {
    case serverIdentityUnavailable
    case certificateUnavailable
    case invalidPEM
    case opensslUnavailable
    case opensslFailed(String)
    case invalidPKCS12

    var errorDescription: String? {
        switch self {
        case .serverIdentityUnavailable:
            "No server TLS identity is installed yet."
        case .certificateUnavailable:
            "The companion certificate authority is unavailable."
        case .invalidPEM:
            "The generated certificate material could not be decoded."
        case .opensslUnavailable:
            "OpenSSL is not available on this Mac, so the companion cannot bootstrap its certificates."
        case .opensslFailed(let output):
            "OpenSSL failed while generating companion certificates: \(output)"
        case .invalidPKCS12:
            "The generated server identity bundle could not be imported."
        }
    }
}

final class CompanionTLSIdentityStore {
    static let shared = CompanionTLSIdentityStore()

    private let fileManager = FileManager.default
    private let opensslPath = "/usr/bin/openssl"
    private let stateDirectoryName = "HermesHostCompanion"
    private let pkiDirectoryName = "PKI"
    private let serverP12Password = "HermesHostCompanion-PKCS12"

    private init() {}

    func loadServerIdentity() throws -> CompanionServerIdentity {
        try bootstrapIfNeeded()

        let caCertificate = try loadCertificate(from: caCertificateURL())
        let serverCertificate = try loadCertificate(from: serverCertificateURL())
        let secIdentity = try loadPKCS12Identity()

        return CompanionServerIdentity(
            secIdentity: secIdentity,
            caCertificate: caCertificate,
            serverCertificateFingerprint: Self.fingerprint(for: serverCertificate)
        )
    }

    func createSignedClientIdentity(csrPEM: String, commonName: String) throws -> CompanionSignedClientIdentity {
        try bootstrapIfNeeded()

        let temporaryDirectory = try makeTemporaryDirectory(prefix: "client-signing")
        defer { try? fileManager.removeItem(at: temporaryDirectory) }

        let csrURL = temporaryDirectory.appendingPathComponent("client.csr.pem")
        let certificateURL = temporaryDirectory.appendingPathComponent("client.cert.pem")
        let extensionURL = temporaryDirectory.appendingPathComponent("client.ext")

        try csrPEM.write(to: csrURL, atomically: true, encoding: .utf8)
        try clientExtensionsPEM(commonName: commonName).write(to: extensionURL, atomically: true, encoding: .utf8)

        try runOpenSSL(arguments: [
            "x509",
            "-req",
            "-in", csrURL.path,
            "-CA", caCertificateURL().path,
            "-CAkey", caPrivateKeyURL().path,
            "-CAcreateserial",
            "-out", certificateURL.path,
            "-days", "825",
            "-sha256",
            "-extfile", extensionURL.path
        ])

        let certificatePEM = try String(contentsOf: certificateURL, encoding: .utf8)
        let caPEM = try String(contentsOf: caCertificateURL(), encoding: .utf8)
        return CompanionSignedClientIdentity(certificatePEM: certificatePEM, caCertificatePEM: caPEM)
    }

    func caCertificatePEM() throws -> String {
        try bootstrapIfNeeded()
        return try String(contentsOf: caCertificateURL(), encoding: .utf8)
    }

    private func bootstrapIfNeeded() throws {
        guard fileManager.fileExists(atPath: opensslPath) else {
            throw CompanionTLSIdentityStoreError.opensslUnavailable
        }

        let directory = try pkiDirectory()
        if fileManager.fileExists(atPath: directory.path) == false {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let caCertificatePath = try caCertificateURL().path
        let caKeyPath = try caPrivateKeyURL().path
        if fileManager.fileExists(atPath: caCertificatePath) == false || fileManager.fileExists(atPath: caKeyPath) == false {
            try generateLocalCA()
        }

        let serverP12Path = try serverP12URL().path
        let serverCertificatePath = try serverCertificateURL().path
        if fileManager.fileExists(atPath: serverP12Path) == false || fileManager.fileExists(atPath: serverCertificatePath) == false {
            try generateServerIdentity()
        }
    }

    private func generateLocalCA() throws {
        try runOpenSSL(arguments: [
            "req",
            "-x509",
            "-newkey", "rsa:4096",
            "-keyout", caPrivateKeyURL().path,
            "-out", caCertificateURL().path,
            "-days", "3650",
            "-nodes",
            "-subj", "/CN=HermesHostCompanion Local CA"
        ])
    }

    private func generateServerIdentity() throws {
        let temporaryDirectory = try makeTemporaryDirectory(prefix: "server-bootstrap")
        defer { try? fileManager.removeItem(at: temporaryDirectory) }

        let csrURL = temporaryDirectory.appendingPathComponent("server.csr.pem")
        let extensionURL = temporaryDirectory.appendingPathComponent("server.ext")

        try serverExtensionsPEM().write(to: extensionURL, atomically: true, encoding: .utf8)

        try runOpenSSL(arguments: [
            "req",
            "-new",
            "-newkey", "rsa:4096",
            "-keyout", serverPrivateKeyURL().path,
            "-out", csrURL.path,
            "-nodes",
            "-subj", "/CN=HermesHostCompanion Server"
        ])

        try runOpenSSL(arguments: [
            "x509",
            "-req",
            "-in", csrURL.path,
            "-CA", caCertificateURL().path,
            "-CAkey", caPrivateKeyURL().path,
            "-CAcreateserial",
            "-out", serverCertificateURL().path,
            "-days", "825",
            "-sha256",
            "-extfile", extensionURL.path
        ])

        try runOpenSSL(arguments: [
            "pkcs12",
            "-export",
            "-inkey", serverPrivateKeyURL().path,
            "-in", serverCertificateURL().path,
            "-certfile", caCertificateURL().path,
            "-out", serverP12URL().path,
            "-passout", "pass:\(serverP12Password)"
        ])
    }

    private func loadPKCS12Identity() throws -> SecIdentity {
        let data = try Data(contentsOf: serverP12URL())
        let options = [kSecImportExportPassphrase as String: serverP12Password]
        var items: CFArray?
        let status = SecPKCS12Import(data as CFData, options as CFDictionary, &items)
        guard
            status == errSecSuccess,
            let array = items as? [[String: Any]],
            let rawIdentity = array.first?[kSecImportItemIdentity as String]
        else {
            throw CompanionTLSIdentityStoreError.invalidPKCS12
        }
        return rawIdentity as! SecIdentity
    }

    private func loadCertificate(from url: URL) throws -> SecCertificate {
        let pem = try String(contentsOf: url, encoding: .utf8)
        let base64 = pem
            .components(separatedBy: .newlines)
            .filter { $0.contains("BEGIN CERTIFICATE") == false && $0.contains("END CERTIFICATE") == false && $0.isEmpty == false }
            .joined()
        guard
            let data = Data(base64Encoded: base64),
            let certificate = SecCertificateCreateWithData(nil, data as CFData)
        else {
            throw CompanionTLSIdentityStoreError.invalidPEM
        }
        return certificate
    }

    private func runOpenSSL(arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: opensslPath)
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let outputData = stdout.fileHandleForReading.readDataToEndOfFile() + stderr.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? "Unknown OpenSSL error."
            throw CompanionTLSIdentityStoreError.opensslFailed(output)
        }
    }

    private func pkiDirectory() throws -> URL {
        let root = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent(stateDirectoryName, isDirectory: true)
        .appendingPathComponent(pkiDirectoryName, isDirectory: true)
        return root
    }

    private func makeTemporaryDirectory(prefix: String) throws -> URL {
        let url = fileManager.temporaryDirectory.appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func caPrivateKeyURL() throws -> URL {
        try pkiDirectory().appendingPathComponent("ca.key.pem")
    }

    private func caCertificateURL() throws -> URL {
        try pkiDirectory().appendingPathComponent("ca.cert.pem")
    }

    private func serverPrivateKeyURL() throws -> URL {
        try pkiDirectory().appendingPathComponent("server.key.pem")
    }

    private func serverCertificateURL() throws -> URL {
        try pkiDirectory().appendingPathComponent("server.cert.pem")
    }

    private func serverP12URL() throws -> URL {
        try pkiDirectory().appendingPathComponent("server.p12")
    }

    private func serverExtensionsPEM() -> String {
        """
        basicConstraints=CA:FALSE
        keyUsage=digitalSignature,keyEncipherment
        extendedKeyUsage=serverAuth
        subjectAltName=DNS:localhost,IP:127.0.0.1
        """
    }

    private func clientExtensionsPEM(commonName: String) -> String {
        """
        basicConstraints=CA:FALSE
        keyUsage=digitalSignature,keyEncipherment
        extendedKeyUsage=clientAuth
        subjectAltName=DNS:\(sanitizedCommonName(commonName))
        """
    }

    private func sanitizedCommonName(_ value: String) -> String {
        let allowed = value.filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "." }
        return allowed.isEmpty ? "hermes-ios-device" : allowed
    }

    private static func fingerprint(for certificate: SecCertificate) -> String {
        let data = SecCertificateCopyData(certificate) as Data
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

extension SecIdentity {
    func asSecIdentityRef() -> sec_identity_t? {
        sec_identity_create(self)
    }
}

extension SecCertificate {
    func asSecCertificateRef() -> sec_certificate_t? {
        sec_certificate_create(self)
    }
}
