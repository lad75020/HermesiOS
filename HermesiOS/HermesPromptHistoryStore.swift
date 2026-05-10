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
    private let defaultsKey = "hermes.utilities.promptHistory.entries"
    private let maxEntries = 10

    var entries: [HermesPromptHistoryEntry] = []

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
        persist()
    }

    func copyToPasteboard(_ entry: HermesPromptHistoryEntry) {
        UIPasteboard.general.string = entry.prompt
    }

    func delete(_ entry: HermesPromptHistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func clear() {
        entries.removeAll()
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([HermesPromptHistoryEntry].self, from: data) else {
            entries = []
            return
        }
        entries = Array(decoded.prefix(maxEntries))
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
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
        let payload = Data((source.rawValue + ":" + prompt).utf8)
        let digest = SHA256.hash(data: payload)
        let hexDigest = digest.map { String(format: "%02x", $0) }.joined()
        return source.rawValue + ":" + hexDigest
    }

    var title: String {
        let normalized = prompt
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? "Prompt" : normalized
    }

    var subtitle: String {
        "\(prompt.count) characters"
    }
}
