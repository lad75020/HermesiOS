//
//  HermesResponsesWorkspace.swift
//  HermesiOS
//

import Foundation
import Observation

@MainActor
@Observable
final class HermesResponsesWorkspace: Identifiable {
    let id: UUID
    let number: Int
    var draft: HermesRequestDraft
    let session: HermesResponsesSession

    init(id: UUID = UUID(), number: Int, draft: HermesRequestDraft, session: HermesResponsesSession) {
        self.id = id
        self.number = number
        self.draft = draft
        self.session = session
    }
}
