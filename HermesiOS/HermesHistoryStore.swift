//
//  HermesHistoryStore.swift
//  HermesiOS
//
//  Created by Codex on 04/05/2026.
//

import Foundation
import Observation

enum HermesHistoryKind: String, Codable, CaseIterable {
    case responses
    case chat

    var title: String {
        switch self {
        case .responses:
            "Responses"
        case .chat:
            "Chat"
        }
    }
}

struct HermesHistoryExchange: Identifiable, Codable, Equatable {
    let id: UUID
    let requestText: String
    let responseText: String
    let completedAt: Date
}

struct HermesHistorySessionRecord: Identifiable, Codable, Equatable {
    let id: String
    let kind: HermesHistoryKind
    var createdAt: Date
    var updatedAt: Date
    var exchanges: [HermesHistoryExchange]
}

@MainActor
@Observable
final class HermesHistoryStore {
    var sessions: [HermesHistorySessionRecord] = []

    private let fileURL: URL

    init() {
        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let directory = baseDirectory.appendingPathComponent("HermesiOS", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("history.json")
        load()
    }

    func recordExchange(kind: HermesHistoryKind, sessionID: String, requestText: String, responseText: String) {
        let trimmedRequest = requestText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedResponse = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRequest.isEmpty, !trimmedResponse.isEmpty else { return }

        let now = Date()
        let exchange = HermesHistoryExchange(
            id: UUID(),
            requestText: trimmedRequest,
            responseText: trimmedResponse,
            completedAt: now
        )

        if let index = sessions.firstIndex(where: { $0.id == sessionID && $0.kind == kind }) {
            sessions[index].updatedAt = now
            sessions[index].exchanges.insert(exchange, at: 0)
        } else {
            sessions.insert(
                HermesHistorySessionRecord(
                    id: sessionID,
                    kind: kind,
                    createdAt: now,
                    updatedAt: now,
                    exchanges: [exchange]
                ),
                at: 0
            )
        }

        sortSessions()
        save()
    }

    func deleteSession(_ sessionID: String, kind: HermesHistoryKind) {
        sessions.removeAll { $0.id == sessionID && $0.kind == kind }
        save()
    }

    func deleteExchange(sessionID: String, kind: HermesHistoryKind, exchangeID: UUID) {
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionID && $0.kind == kind }) else { return }
        sessions[sessionIndex].exchanges.removeAll { $0.id == exchangeID }
        if sessions[sessionIndex].exchanges.isEmpty {
            sessions.remove(at: sessionIndex)
        } else {
            sessions[sessionIndex].updatedAt = sessions[sessionIndex].exchanges.first?.completedAt ?? sessions[sessionIndex].updatedAt
        }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        sessions = (try? JSONDecoder().decode([HermesHistorySessionRecord].self, from: data)) ?? []
        sortSessions()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }

    private func sortSessions() {
        sessions.sort { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.id > rhs.id
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }
}
