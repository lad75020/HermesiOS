//
//  HermesPromptHistoryStore.swift
//  HermesiOS
//

import CryptoKit
import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class HermesPromptHistoryStore {
    private let promptDefaultsKey = "hermes.utilities.promptHistory.entries"
    private let responseDefaultsKey = "hermes.utilities.responseHistory.entries"
    private let maxEntries = 10

    var entries: [HermesPromptHistoryEntry] = []
    var responseEntries: [HermesResponseHistoryEntry] = []

    init() {
        load()
    }

    func record(_ prompt: String, source: HermesPromptHistoryEntry.Source) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let entry = HermesPromptHistoryEntry(prompt: trimmed, source: source)
        if entries.first?.fingerprint == entry.fingerprint { return }
        entries.removeAll { $0.fingerprint == entry.fingerprint }
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        persistPrompts()
    }

    func recordResponse(_ response: String, source: HermesPromptHistoryEntry.Source) {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let entry = HermesResponseHistoryEntry(response: trimmed, source: source)
        if responseEntries.first?.fingerprint == entry.fingerprint { return }
        responseEntries.removeAll { $0.fingerprint == entry.fingerprint }
        responseEntries.insert(entry, at: 0)
        if responseEntries.count > maxEntries {
            responseEntries = Array(responseEntries.prefix(maxEntries))
        }
        persistResponses()
    }

    func copyToPasteboard(_ entry: HermesPromptHistoryEntry) {
        UIPasteboard.general.string = entry.prompt
    }

    func copyResponseToPasteboard(_ entry: HermesResponseHistoryEntry) {
        UIPasteboard.general.string = entry.response
    }

    func delete(_ entry: HermesPromptHistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        persistPrompts()
    }

    func deleteResponse(_ entry: HermesResponseHistoryEntry) {
        responseEntries.removeAll { $0.id == entry.id }
        persistResponses()
    }

    func clear() {
        entries.removeAll()
        persistPrompts()
    }

    func clearResponses() {
        responseEntries.removeAll()
        persistResponses()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: promptDefaultsKey),
           let decoded = try? JSONDecoder().decode([HermesPromptHistoryEntry].self, from: data) {
            entries = Array(decoded.prefix(maxEntries))
        } else {
            entries = []
        }

        if let data = UserDefaults.standard.data(forKey: responseDefaultsKey),
           let decoded = try? JSONDecoder().decode([HermesResponseHistoryEntry].self, from: data) {
            responseEntries = Array(decoded.prefix(maxEntries))
        } else {
            responseEntries = []
        }
    }

    private func persistPrompts() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: promptDefaultsKey)
    }

    private func persistResponses() {
        guard let data = try? JSONEncoder().encode(responseEntries) else { return }
        UserDefaults.standard.set(data, forKey: responseDefaultsKey)
    }
}

struct HermesPromptHistoryEntry: Identifiable, Codable, Equatable {
    enum Source: String, Codable {
        case askHermes
        case chatWithHermes

        var displayName: String {
            switch self {
            case .askHermes: "Ask Hermes"
            case .chatWithHermes: "Chat with Hermes"
            }
        }

        var systemImage: String {
            switch self {
            case .askHermes: "dot.radiowaves.left.and.right"
            case .chatWithHermes: "text.bubble"
            }
        }
    }

    let id: UUID
    let prompt: String
    let source: Source
    let createdAt: Date
    let fingerprint: String

    init(prompt: String, source: Source) {
        self.id = UUID()
        self.prompt = prompt
        self.source = source
        self.createdAt = Date()
        self.fingerprint = Self.makeFingerprint(prompt: prompt, source: source)
    }

    private static func makeFingerprint(prompt: String, source: Source) -> String {
        let payload = Data((source.rawValue + ":prompt:" + prompt).utf8)
        let digest = SHA256.hash(data: payload)
        let hexDigest = digest.map { String(format: "%02x", $0) }.joined()
        return source.rawValue + ":prompt:" + hexDigest
    }

    var title: String {
        Self.normalizedTitle(from: prompt, fallback: "Prompt")
    }

    var subtitle: String {
        "\(prompt.count) characters"
    }

    static func normalizedTitle(from text: String, fallback: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? fallback : normalized
    }
}

struct HermesResponseHistoryEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let response: String
    let source: HermesPromptHistoryEntry.Source
    let createdAt: Date
    let fingerprint: String

    init(response: String, source: HermesPromptHistoryEntry.Source) {
        self.id = UUID()
        self.response = response
        self.source = source
        self.createdAt = Date()
        self.fingerprint = Self.makeFingerprint(response: response, source: source)
    }

    private static func makeFingerprint(response: String, source: HermesPromptHistoryEntry.Source) -> String {
        let payload = Data((source.rawValue + ":response:" + response).utf8)
        let digest = SHA256.hash(data: payload)
        let hexDigest = digest.map { String(format: "%02x", $0) }.joined()
        return source.rawValue + ":response:" + hexDigest
    }

    var title: String {
        HermesPromptHistoryEntry.normalizedTitle(from: response, fallback: "Response")
    }

    var subtitle: String {
        "\(response.count) characters"
    }
}
