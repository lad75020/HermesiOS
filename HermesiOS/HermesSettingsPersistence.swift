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
    private static let companionTokenAccount = "authenticationToken"

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
        if var components = URLComponents(string: settings.apiURL), components.scheme?.lowercased().hasSuffix("s") == true {
            components.scheme = String(components.scheme?.dropLast() ?? "ws")
            settings.apiURL = components.url?.absoluteString ?? HermesCompanionSettings().apiURL
        }
        settings.authenticationToken = loadKeychainString(service: companionService, account: companionTokenAccount)
        return settings
    }

    static func saveCompanionSettings(_ settings: HermesCompanionSettings) {
        var persistedSettings = settings
        persistedSettings.authenticationToken = ""
        encode(persistedSettings, to: companionSettingsKey)
        saveKeychainString(settings.authenticationToken, service: companionService, account: companionTokenAccount)
    }

    static func loadCompanionIdentityState() -> HermesCompanionIdentityState {
        decode(HermesCompanionIdentityState.self, from: companionIdentityStateKey) ?? HermesCompanionIdentityState()
    }

    static func saveCompanionAuthenticationState(_ state: HermesCompanionIdentityState) {
        encode(state, to: companionIdentityStateKey)
    }

    static func clearCompanionIdentity() {
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


    private static func encode<T: Encodable>(_ value: T, to key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func loadBearerToken() -> String {
        loadKeychainString(service: tokenService, account: tokenAccount)
    }

    private static func saveBearerToken(_ token: String) {
        saveKeychainString(token, service: tokenService, account: tokenAccount)
    }

    private static func loadKeychainString(service: String, account: String) -> String {
        guard let data = loadKeychainData(service: service, account: account) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func saveKeychainString(_ value: String, service: String, account: String) {
        if value.isEmpty {
            deleteKeychainData(service: service, account: account)
            return
        }
        saveKeychainData(Data(value.utf8), service: service, account: account)
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
