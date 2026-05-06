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
        VStack(spacing: 0) {
            HermesGlassEffectContainer(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    HermesTabHeader("Responses API", systemImage: "dot.radiowaves.left.and.right")

                    HermesStatusRow(
                        items: [
                            .init(title: "Thread", value: responseSession.previousResponseID.isEmpty ? "New response" : "Continuing thread", accent: .igGradPurple),
                            .init(title: "Status", value: responseSession.connectionStatus, accent: .igGradOrange)
                        ]
                    )
                }
                .padding(.horizontal)
                .padding(.top)
            }

            responseTranscript
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            responseComposer
        }
        .background(Color.hermesCanvas)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var responseTranscript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if responseSession.entries.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Start a Responses session", systemImage: "bubble.left.and.bubble.right")
                                .font(.headline)
                            Text("Enter a prompt below. Your prompts and Hermes replies will appear here as chat bubbles for this session.")
                                .font(.subheadline)
                                .foregroundStyle(.hermesSecondaryText)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .hermesLiquidGlass(cornerRadius: 22, tint: Color.igActionBlue.opacity(0.06))
                    } else {
                        ForEach(responseSession.entries) { message in
                            HermesResponseBubble(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .onChange(of: responseSession.entries.count) { _, _ in
                scrollToLatest(proxy)
            }
            .onChange(of: responseSession.streamedText) { _, _ in
                scrollToLatest(proxy)
            }
        }
    }

    private var responseComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label("Message type: \(responseSession.latestMessageType.isEmpty ? "waiting" : responseSession.latestMessageType)", systemImage: "tag")
                    .font(.caption.weight(.semibold))
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
            }

            if !responseSession.lastErrorMessage.isEmpty {
                Text(responseSession.lastErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.igDestructive)
            }

            HStack(alignment: .bottom, spacing: 12) {
                TextEditor(text: $requestDraft.userPrompt)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 72, maxHeight: 130)
                    .igFieldBackground()
                    .overlay(alignment: .topLeading) {
                        if requestDraft.userPrompt.isEmpty {
                            Text("Ask Hermes something...")
                                .foregroundStyle(.hermesSecondaryText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    }

                Button {
                    let submittedDraft = requestDraft
                    responseSession.submit(apiSettings: apiSettings, draft: submittedDraft)
                    requestDraft.userPrompt = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.headline)
                        .frame(width: 42, height: 42)
                }
                .hermesGlassProminentButton()
                .disabled(requestDraft.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || responseSession.isSending)
                .accessibilityLabel("Send prompt")
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        guard let lastID = responseSession.entries.last?.id else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastID, anchor: .bottom)
        }
    }
}

struct HermesResponseBubble: View {
    let message: HermesResponseMessage

    var body: some View {
        HStack(alignment: .bottom) {
            if isUser { Spacer(minLength: 44) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                Text(isUser ? "You" : "Hermes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.hermesSecondaryText)

                Text(displayContent)
                    .font(.body)
                    .foregroundStyle(isUser ? .white : .primary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(isUser ? Color.igActionBlue : Color.hermesSurfaceInput)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(isUser ? Color.igActionBlue.opacity(0.45) : Color.hermesDivider.opacity(0.7), lineWidth: 1)
                    )
            }
            .frame(maxWidth: 620, alignment: isUser ? .trailing : .leading)

            if !isUser { Spacer(minLength: 44) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var isUser: Bool { message.role == "user" }

    private var displayContent: String {
        if message.content.isEmpty, !isUser {
            return "…"
        }
        return message.content
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
