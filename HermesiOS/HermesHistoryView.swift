//
//  HermesHistoryView.swift
//  HermesiOS
//

import Observation
import SwiftUI

struct HermesHistoryView: View {
    @Bindable var historyStore: HermesHistoryStore

    var body: some View {
        VStack(spacing: 0) {
            HermesTabHeader("History", systemImage: "clock.arrow.circlepath")
                .padding(.horizontal)
                .padding(.top)

            List {
                if historyStore.sessions.isEmpty {
                    ContentUnavailableView(
                        "No History Yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Completed Responses and Chat exchanges will be stored here by session ID.")
                    )
                } else {
                    ForEach(historyStore.sessions) { session in
                        Section {
                            ForEach(session.exchanges) { exchange in
                                HermesHistoryExchangeCard(exchange: exchange)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            historyStore.deleteExchange(
                                                sessionID: session.id,
                                                kind: session.kind,
                                                exchangeID: exchange.id
                                            )
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        } header: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Label(session.kind.title, systemImage: session.kind == .responses ? "dot.radiowaves.left.and.right" : "text.bubble")
                                    Spacer()
                                    Button(role: .destructive) {
                                        historyStore.deleteSession(session.id, kind: session.kind)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.plain)
                                }
                                Text("Session ID: \(session.id)")
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                                Text(session.updatedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.hermesSecondaryText)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .background(Color.hermesCanvas)
        .toolbar(.hidden, for: .navigationBar)
    }
}
