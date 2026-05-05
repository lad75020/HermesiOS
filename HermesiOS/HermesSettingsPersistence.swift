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
    private static let tokenService = "com.hermesios.api"
    private static let tokenAccount = "bearerToken"

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

    private static func encode<T: Encodable>(_ value: T, to key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func loadBearerToken() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tokenService,
            kSecAttrAccount as String: tokenAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func saveBearerToken(_ token: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: tokenService,
            kSecAttrAccount as String: tokenAccount
        ]

        if token.isEmpty {
            SecItemDelete(query as CFDictionary)
            return
        }

        let data = Data(token.utf8)
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var insertQuery = query
            insertQuery[kSecValueData as String] = data
            SecItemAdd(insertQuery as CFDictionary, nil)
        }
    }
}
