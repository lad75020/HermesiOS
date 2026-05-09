//
//  HermesResponsesWorkspace.swift
//  HermesiOS
//

import Foundation
import Observation

enum HermesResponsesWorkspaceAttention {
    case completed
    case failed
}

@MainActor
@Observable
final class HermesResponsesWorkspace: Identifiable {
    let id: UUID
    let number: Int
    var draft: HermesRequestDraft
    let session: HermesResponsesSession
    private var acknowledgedCompletionToken = ""
    private var acknowledgedFailureToken = ""

    init(id: UUID = UUID(), number: Int, draft: HermesRequestDraft, session: HermesResponsesSession) {
        self.id = id
        self.number = number
        self.draft = draft
        self.session = session
    }

    var isStreamingActive: Bool {
        session.isSending
    }

    var attention: HermesResponsesWorkspaceAttention? {
        switch session.connectionStatus {
        case "Failed":
            let token = failureToken
            return token.isEmpty || token == acknowledgedFailureToken ? nil : .failed
        case "Completed":
            let token = completionToken
            return token.isEmpty || token == acknowledgedCompletionToken ? nil : .completed
        default:
            return nil
        }
    }

    func acknowledgeCurrentStatus() {
        switch session.connectionStatus {
        case "Failed":
            acknowledgedFailureToken = failureToken
        case "Completed":
            acknowledgedCompletionToken = completionToken
        default:
            break
        }
    }

    private var completionToken: String {
        let latest = session.latestResponseID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !latest.isEmpty { return latest }
        return "entries:\(session.entries.count)"
    }

    private var failureToken: String {
        let message = session.lastErrorMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        if !message.isEmpty { return message }
        return "failed:\(session.entries.count)"
    }
}
