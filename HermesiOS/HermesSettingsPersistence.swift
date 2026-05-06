//
//  HermesSettingsPersistence.swift
//  HermesiOS
//
//  Created by Codex on 04/05/2026.
//

import Foundation
import Security

enum HermesSettingsPersistence {
    private static let apiSettingsKey = "hermes.apiSettings"
    private static let responsesDraftKey = "hermes.responsesDraft"
    private static let chatDraftKey = "hermes.chatDraft"
    private static let companionSettingsKey = "hermes.companionSettings"
    private static let companionIdentityStateKey = "hermes.companionIdentityState"
    private static let tokenService = "com.hermesios.api"
    private static let tokenAccount = "bearerToken"
    private static let companionService = "com.hermesios.companion"
    private static let companionIdentityAccount = "clientIdentity"

    static func loadAPISettings() -> HermesAPISettings {
        var settings = decode(HermesAPISettings.self, from: apiSettingsKey) ?? HermesAPISettings()
        settings.apiKey = loadBearerToken()
        return settings
    }

    static func saveAPISettings(_ settings: HermesAPISettings) {
        var persistedSettings = settings
        persistedSettings.apiKey = ""
        encode(persistedSettings, to: apiSettingsKey)
        saveBearerToken(settings.apiKey)
    }

    static func loadResponsesDraft() -> HermesRequestDraft {
        decode(HermesRequestDraft.self, from: responsesDraftKey) ?? HermesRequestDraft()
    }

    static func saveResponsesDraft(_ draft: HermesRequestDraft) {
        encode(draft, to: responsesDraftKey)
    }

    static func loadChatDraft() -> HermesChatDraft {
        decode(HermesChatDraft.self, from: chatDraftKey) ?? HermesChatDraft()
    }

    static func saveChatDraft(_ draft: HermesChatDraft) {
        encode(draft, to: chatDraftKey)
    }

    static func loadCompanionSettings() -> HermesCompanionSettings {
        var settings = decode(HermesCompanionSettings.self, from: companionSettingsKey) ?? HermesCompanionSettings()

        // Migrate the original companion defaults to the current simulator-to-host ports.
        // Keep user-edited values intact.
        if settings.enrollmentURL == "wss://localhost:9444/enroll" {
            settings.enrollmentURL = HermesCompanionSettings().enrollmentURL
        }
        if settings.apiURL == "wss://localhost:9443/ws" {
            settings.apiURL = HermesCompanionSettings().apiURL
        }
        return settings
    }

    static func saveCompanionSettings(_ settings: HermesCompanionSettings) {
        encode(settings, to: companionSettingsKey)
    }

    static func loadCompanionIdentityState() -> HermesCompanionIdentityState {
        decode(HermesCompanionIdentityState.self, from: companionIdentityStateKey) ?? HermesCompanionIdentityState()
    }

    static func saveCompanionIdentity(
        pkcs12Base64: String,
        password: String,
        state: HermesCompanionIdentityState
    ) throws {
        let bundle = HermesStoredCompanionIdentity(pkcs12Base64: pkcs12Base64, password: password)
        let data = try JSONEncoder().encode(bundle)
        saveKeychainData(data, service: companionService, account: companionIdentityAccount)
        encode(state, to: companionIdentityStateKey)
    }

    static func clearCompanionIdentity() {
        deleteKeychainData(service: companionService, account: companionIdentityAccount)
        UserDefaults.standard.removeObject(forKey: companionIdentityStateKey)
    }

    static func removeLegacyLocalHistoryFile() {
        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let historyURL = baseDirectory?
            .appendingPathComponent("HermesiOS", isDirectory: true)
            .appendingPathComponent("history.json")
        else { return }

        try? FileManager.default.removeItem(at: historyURL)
    }

    static func loadCompanionClientCredential() -> URLCredential? {
        guard
            let data = loadKeychainData(service: companionService, account: companionIdentityAccount),
            let storedIdentity = try? JSONDecoder().decode(HermesStoredCompanionIdentity.self, from: data),
            let pkcs12Data = Data(base64Encoded: storedIdentity.pkcs12Base64)
        else {
            return nil
        }

        let options = [kSecImportExportPassphrase as String: storedIdentity.password]
        var items: CFArray?
        let status = SecPKCS12Import(pkcs12Data as CFData, options as CFDictionary, &items)
        guard
            status == errSecSuccess,
            let array = items as? [[String: Any]],
            let rawIdentity = array.first?[kSecImportItemIdentity as String],
            let certificateChain = array.first?[kSecImportItemCertChain as String] as? [SecCertificate]
        else {
            return nil
        }

        let identity = rawIdentity as! SecIdentity
        return URLCredential(identity: identity, certificates: certificateChain, persistence: .forSession)
    }

    private static func encode<T: Encodable>(_ value: T, to key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func loadBearerToken() -> String {
        guard let data = loadKeychainData(service: tokenService, account: tokenAccount) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func saveBearerToken(_ token: String) {
        if token.isEmpty {
            deleteKeychainData(service: tokenService, account: tokenAccount)
            return
        }

        saveKeychainData(Data(token.utf8), service: tokenService, account: tokenAccount)
    }

    private static func loadKeychainData(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return data
    }

    private static func saveKeychainData(_ data: Data, service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var insertQuery = query
            insertQuery[kSecValueData as String] = data
            SecItemAdd(insertQuery as CFDictionary, nil)
        }
    }

    private static func deleteKeychainData(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
