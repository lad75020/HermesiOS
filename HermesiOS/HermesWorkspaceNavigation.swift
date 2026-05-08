//
//  HermesWorkspaceNavigation.swift
//  HermesiOS
//

import SwiftUI

enum WorkspaceSection: String, CaseIterable, Identifiable {
    case responses
    case chat
    case history
    case office
    case settings
    case runtime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .responses:
            "Ask Hermes"
        case .chat:
            "Chat with Hermes"
        case .history:
            "History"
        case .office:
            "Office"
        case .settings:
            "Settings"
        case .runtime:
            "Agent Runtime"
        }
    }

    var subtitle: String {
        switch self {
        case .responses:
            "Use `/v1/responses` with SSE and response chaining."
        case .chat:
            "Use `/v1/chat/completions` with an independent transcript."
        case .history:
            "Review saved requests and final responses grouped by session."
        case .office:
            "Open the Hermes Office web experience inside the app."
        case .settings:
            "Configure gateway, prompts, models, and streaming behavior."
        case .runtime:
            "Model local and SSH-backed agent environments."
        }
    }

    var systemImage: String {
        switch self {
        case .responses:
            "dot.radiowaves.left.and.right"
        case .chat:
            "text.bubble"
        case .history:
            "clock.arrow.circlepath"
        case .office:
            "building.2.crop.circle"
        case .settings:
            "slider.horizontal.3"
        case .runtime:
            "server.rack"
        }
    }
}

struct WorkspaceSidebar: View {
    @Binding var selection: WorkspaceSection?
    @Bindable var statusMonitor: HermesStatusMonitor
    @Bindable var responseSession: HermesResponsesSession
    @Bindable var chatSession: HermesChatSession
    @Binding var isShowingStreamDebugJSON: Bool
    var selectedDebugStreamSource: HermesStreamDebugSource = .responses
    var apiChannelActive = false
    var companionChannelActive = false
    var dashboardChannelActive = false
    @Binding var isResponsesCompletionUnread: Bool
    @Binding var isChatCompletionUnread: Bool
    @Binding var isHistorySearchCompletionUnread: Bool
    @Binding var isResponsesFailureUnread: Bool
    @Binding var isChatFailureUnread: Bool
    @Binding var isHistorySearchFailureUnread: Bool

    private func completionUnread(for section: WorkspaceSection) -> Bool {
        switch section {
        case .responses:
            isResponsesCompletionUnread
        case .chat:
            isChatCompletionUnread
        case .history:
            isHistorySearchCompletionUnread
        case .office, .settings, .runtime:
            false
        }
    }

    private func failureUnread(for section: WorkspaceSection) -> Bool {
        switch section {
        case .responses:
            isResponsesFailureUnread
        case .chat:
            isChatFailureUnread
        case .history:
            isHistorySearchFailureUnread
        case .office, .settings, .runtime:
            false
        }
    }

    private func clearUnreadState(for section: WorkspaceSection) {
        switch section {
        case .responses:
            isResponsesCompletionUnread = false
            isResponsesFailureUnread = false
        case .chat:
            isChatCompletionUnread = false
            isChatFailureUnread = false
        case .history:
            isHistorySearchCompletionUnread = false
            isHistorySearchFailureUnread = false
        case .office, .settings, .runtime:
            break
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Hermes")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 14)
                .padding(.bottom, 8)
                .accessibilityAddTraits(.isHeader)

            HermesStatusBand(
                statusMonitor: statusMonitor,
                showsLabels: false,
                apiChannelActive: apiChannelActive,
                companionChannelActive: companionChannelActive,
                dashboardChannelActive: dashboardChannelActive
            )

            List(WorkspaceSection.allCases) { section in
                let hasUnreadCompletion = completionUnread(for: section)
                let hasUnreadFailure = failureUnread(for: section)
                Button {
                    selection = section
                    clearUnreadState(for: section)
                } label: {
                    Image(systemName: section.systemImage)
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .foregroundStyle(hasUnreadFailure || hasUnreadCompletion ? Color.white : (selection == section ? Color.igActionBlue : Color.hermesSecondaryText))
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(hasUnreadFailure ? Color.igDestructive.opacity(0.9) : (hasUnreadCompletion ? Color.green.opacity(0.85) : Color.clear))
                        )
                        .contentShape(Rectangle())
                        .accessibilityLabel(section.title)
                        .accessibilityHint(hasUnreadFailure ? "Request failed. Tap to clear the failure indicator." : (hasUnreadCompletion ? "Completed. Tap to mark as seen." : ""))
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                .listRowBackground(
                    selection == section
                        ? AnyView(HermesLiquidGlassBackground(cornerRadius: 14, tint: .igActionBlue.opacity(0.18), interactive: true))
                        : AnyView(Color.clear)
                )
                .listRowSeparatorTint(.hermesDivider.opacity(0.4))
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Divider()
                .overlay(Color.hermesDivider.opacity(0.4))

            Button {
                isShowingStreamDebugJSON = true
            } label: {
                Image(systemName: "ladybug")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.hermesSecondaryText)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
            .accessibilityLabel("Debug stream JSON")
            .accessibilityHint("Shows a modal with raw JSON streamed by the Hermes Responses and Chat Completions APIs")
        }
        .background(Color.hermesCanvas)
        .sheet(isPresented: $isShowingStreamDebugJSON) {
            HermesStreamedJSONDebugSheet(
                responseSession: responseSession,
                chatSession: chatSession,
                initialSource: selectedDebugStreamSource
            )
        }
    }
}

enum HermesStreamDebugSource: String, CaseIterable, Identifiable {
    case responses
    case chat

    var id: String { rawValue }

    var title: String {
        switch self {
        case .responses:
            "Responses"
        case .chat:
            "Chat Completions"
        }
    }
}

struct HermesStreamedJSONDebugSheet: View {
    @Bindable var responseSession: HermesResponsesSession
    @Bindable var chatSession: HermesChatSession
    var initialSource: HermesStreamDebugSource = .responses
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSource: HermesStreamDebugSource = .responses

    private var debugText: String {
        switch selectedSource {
        case .responses:
            if responseSession.rawStreamedJSON.isEmpty {
                return "No Responses API JSON has been streamed yet. Send a Responses API request with streaming enabled to populate this debug view."
            }
            return responseSession.rawStreamedJSON
        case .chat:
            if chatSession.rawStreamedJSON.isEmpty {
                return "No Chat Completions API JSON has been streamed yet. Send a Chat Completions request with streaming enabled to populate this debug view."
            }
            return chatSession.rawStreamedJSON
        }
    }

    private var currentEventCount: Int {
        switch selectedSource {
        case .responses:
            responseSession.eventCount
        case .chat:
            chatSession.eventCount
        }
    }

    private var isCurrentDebugTextEmpty: Bool {
        switch selectedSource {
        case .responses:
            responseSession.rawStreamedJSON.isEmpty
        case .chat:
            chatSession.rawStreamedJSON.isEmpty
        }
    }

    private func clearCurrentDebugText() {
        switch selectedSource {
        case .responses:
            responseSession.rawStreamedJSON = ""
        case .chat:
            chatSession.rawStreamedJSON = ""
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Debug stream", selection: $selectedSource) {
                    ForEach(HermesStreamDebugSource.allCases) { source in
                        Text(source.title).tag(source)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 12) {
                    Label("\(currentEventCount) events", systemImage: "timeline.selection")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.hermesSecondaryText)

                    Spacer()

                    Button {
                        clearCurrentDebugText()
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                    .hermesGlassButton()
                    .disabled(isCurrentDebugTextEmpty)
                }

                TextEditor(text: .constant(debugText))
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 420)
                    .padding(8)
                    .igFieldBackground()
            }
            .padding()
            .background(Color.hermesCanvas)
            .navigationTitle("Streamed Hermes JSON")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            selectedSource = initialSource
        }
    }
}
