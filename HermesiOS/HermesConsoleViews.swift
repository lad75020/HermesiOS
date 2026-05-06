//
//  HermesConsoleViews.swift
//  HermesiOS
//

import Observation
import SwiftUI

struct HermesResponsesConsoleView: View {
    @Binding var apiSettings: HermesAPISettings
    @Binding var requestDraft: HermesRequestDraft
    @Bindable var responseSession: HermesResponsesSession

    var body: some View {
        ScrollView {
            HermesGlassEffectContainer(spacing: 26) {
                VStack(alignment: .leading, spacing: 20) {
                HermesTabHeader("Responses API", systemImage: "dot.radiowaves.left.and.right")

                HermesStatusRow(
                    items: [
                        .init(title: "Thread", value: responseSession.previousResponseID.isEmpty ? "New response" : "Continuing thread", accent: .igGradPurple),
                        .init(title: "Status", value: responseSession.connectionStatus, accent: .igGradOrange)
                    ]
                )

                HermesSectionCard("Request Draft") {
                    VStack(alignment: .leading, spacing: 14) {
                        if !responseSession.previousResponseID.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Next request resumes a stored Hermes thread.", systemImage: "arrow.triangle.branch")
                                    .font(.caption.weight(.semibold))
                                Text(responseSession.previousResponseID)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.hermesSecondaryText)
                                    .textSelection(.enabled)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        TextEditor(text: $requestDraft.userPrompt)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 160)
                            .igFieldBackground()
                            .overlay(alignment: .topLeading) {
                                if requestDraft.userPrompt.isEmpty {
                                    Text("Ask Hermes to inspect files, run tools, or explain context...")
                                        .foregroundStyle(.hermesSecondaryText)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 8)
                                        .allowsHitTesting(false)
                                }
                            }

                        HStack {
                            Label("Send a prompt and inspect Hermes events", systemImage: "waveform.path.ecg")
                                .font(.footnote)
                                .foregroundStyle(.hermesSecondaryText)
                            Spacer()

                            if !responseSession.previousResponseID.isEmpty && !responseSession.isSending {
                                Button("New Thread") {
                                    responseSession.resetConversation()
                                }
                                .hermesGlassButton()
                            }

                            if responseSession.isSending {
                                Button("Cancel") {
                                    responseSession.cancel()
                                }
                                .hermesGlassButton()
                            }

                            Button("Send Request") {
                                responseSession.submit(apiSettings: apiSettings, draft: requestDraft)
                            }
                            .hermesGlassProminentButton()
                            .disabled(requestDraft.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }

                HermesSectionCard("Assistant Output") {
                    VStack(alignment: .leading, spacing: 12) {
                        if !responseSession.previousResponseID.isEmpty {
                            Label("Continuing from: \(responseSession.previousResponseID)", systemImage: "link")
                                .font(.caption)
                                .foregroundStyle(.hermesSecondaryText)
                        }

                        if !responseSession.latestResponseID.isEmpty {
                            Label("Response ID: \(responseSession.latestResponseID)", systemImage: "number")
                                .font(.caption)
                                .foregroundStyle(.hermesSecondaryText)
                        }

                        if !responseSession.lastErrorMessage.isEmpty {
                            Text(responseSession.lastErrorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.igDestructive)
                        }

                        Label("Message type: \(responseSession.latestMessageType.isEmpty ? "waiting" : responseSession.latestMessageType)", systemImage: "tag")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.hermesSecondaryText)

                        Group {
                            if responseSession.streamedText.isEmpty {
                                Text("Send a `/v1/responses` request to populate streamed assistant output here.")
                                    .foregroundStyle(.hermesSecondaryText)
                            } else {
                                Text(responseSession.streamedText)
                                    .textSelection(.enabled)
                            }
                        }
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                }
                .padding()
            }
        }
        .background(Color.hermesCanvas)
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct HermesChatConsoleView: View {
    @Binding var apiSettings: HermesAPISettings
    @Binding var chatDraft: HermesChatDraft
    @Bindable var chatSession: HermesChatSession

    var body: some View {
        ScrollView {
            HermesGlassEffectContainer(spacing: 26) {
                VStack(alignment: .leading, spacing: 20) {
                HermesTabHeader("Chat Completions", systemImage: "text.bubble")

                HermesStatusRow(
                    items: [
                        .init(title: "History", value: "\(chatSession.entries.count) messages", accent: .igGradPurple),
                        .init(title: "Status", value: chatSession.connectionStatus, accent: .igGradOrange)
                    ]
                )

                HermesSectionCard("Message Draft") {
                    VStack(alignment: .leading, spacing: 14) {
                        TextEditor(text: $chatDraft.userPrompt)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 160)
                            .igFieldBackground()
                            .overlay(alignment: .topLeading) {
                                if chatDraft.userPrompt.isEmpty {
                                    Text("Send a message to Hermes using the chat completions format...")
                                        .foregroundStyle(.hermesSecondaryText)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 8)
                                        .allowsHitTesting(false)
                                }
                            }

                        HStack {
                            Label("Chat transcript stays separate from `/v1/responses`", systemImage: "rectangle.split.3x1")
                                .font(.footnote)
                                .foregroundStyle(.hermesSecondaryText)
                            Spacer()

                            if !chatSession.entries.isEmpty && !chatSession.isSending {
                                Button("New Chat") {
                                    chatSession.resetConversation()
                                }
                                .hermesGlassButton()
                            }

                            if chatSession.isSending {
                                Button("Cancel") {
                                    chatSession.cancel()
                                }
                                .hermesGlassButton()
                            }

                            Button("Send Message") {
                                chatSession.submit(apiSettings: apiSettings, draft: chatDraft)
                            }
                            .hermesGlassProminentButton()
                            .disabled(chatDraft.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }

                HermesSectionCard("Assistant Output") {
                    VStack(alignment: .leading, spacing: 12) {
                        if !chatSession.lastErrorMessage.isEmpty {
                            Text(chatSession.lastErrorMessage)
                                .font(.subheadline)
                                .foregroundStyle(.igDestructive)
                        }

                        Group {
                            if chatSession.streamedText.isEmpty {
                                Text("Send a `/v1/chat/completions` message to populate assistant output here.")
                                    .foregroundStyle(.hermesSecondaryText)
                            } else {
                                Text(chatSession.streamedText)
                                    .textSelection(.enabled)
                            }
                        }
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                HermesSectionCard("Transcript") {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("\(chatSession.eventCount) stream events received", systemImage: "timeline.selection")
                            .font(.caption)
                            .foregroundStyle(.hermesSecondaryText)

                        if chatSession.entries.isEmpty {
                            Text("User and assistant messages from the chat completions session will accumulate here.")
                                .font(.subheadline)
                                .foregroundStyle(.hermesSecondaryText)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(chatSession.entries) { message in
                                    HermesChatMessageCard(message: message)
                                }
                            }
                        }
                    }
                }
                }
                .padding()
            }
        }
        .background(Color.hermesCanvas)
        .toolbar(.hidden, for: .navigationBar)
    }
}
