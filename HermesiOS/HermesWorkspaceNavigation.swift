//
//  HermesWorkspaceNavigation.swift
//  HermesiOS
//

import SwiftUI

enum WorkspaceSection: String, CaseIterable, Identifiable {
    case responses
    case chat
    case history
    case web
    case terminal
    case utilities
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
        case .web:
            "Web"
        case .terminal:
            "Terminal"
        case .utilities:
            "Utilities"
        case .settings:
            "Settings"
        case .runtime:
            "Hermes Agent Runtime"
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
        case .web:
            "Browse a web page inside HermesiOS."
        case .terminal:
            "Open an SSH terminal to the configured Mac host."
        case .utilities:
            "Clipboard history and other local helpers."
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
        case .web:
            "globe"
        case .terminal:
            "terminal"
        case .utilities:
            "wrench.and.screwdriver"
        case .settings:
            "slider.horizontal.3"
        case .runtime:
            "server.rack"
        }
    }
}

struct WorkspaceSidebar: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var selection: WorkspaceSection?
    var sections: [WorkspaceSection] = WorkspaceSection.allCases
    @Bindable var statusMonitor: HermesStatusMonitor
    @Bindable var responseSession: HermesResponsesSession
    @Bindable var chatSession: HermesChatSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession
    @ObservedObject var webBrowserStore: HermesWebBrowserDeckStore
    var apiChannelActive = false
    var companionChannelActive = false
    var dashboardChannelActive = false
    var isResponsesStreamingActive = false
    var isHistorySearchActive = false
    var hasUnreadResponsesCompletion = false
    var hasUnreadResponsesFailure = false
    @Binding var isResponsesCompletionUnread: Bool
    @Binding var isChatCompletionUnread: Bool
    @Binding var isHistorySearchCompletionUnread: Bool
    @Binding var isResponsesFailureUnread: Bool
    @Binding var isChatFailureUnread: Bool
    @Binding var isHistorySearchFailureUnread: Bool

    private func completionUnread(for section: WorkspaceSection) -> Bool {
        switch section {
        case .responses:
            hasUnreadResponsesCompletion
        case .chat:
            isChatCompletionUnread
        case .history:
            isHistorySearchCompletionUnread
        case .web, .utilities, .settings, .runtime, .terminal:
            false
        }
    }

    private func failureUnread(for section: WorkspaceSection) -> Bool {
        switch section {
        case .responses:
            hasUnreadResponsesFailure
        case .chat:
            isChatFailureUnread
        case .history:
            isHistorySearchFailureUnread
        case .web, .utilities, .settings, .runtime, .terminal:
            false
        }
    }

    private func activityBlinkActive(for section: WorkspaceSection) -> Bool {
        switch section {
        case .responses:
            isResponsesStreamingActive
        case .chat:
            chatSession.isSending
        case .history:
            isHistorySearchActive
        case .runtime:
            companionRuntime.isKickstartingRuntime
        case .web:
            webBrowserStore.hasUnloadedWebPages
        case .utilities, .settings, .terminal:
            false
        }
    }

    private var sidebarLogoName: String {
        colorScheme == .dark ? "HermesLogoDark" : "HermesLogoLight"
    }

    private func activityAccessibilityHint(for section: WorkspaceSection) -> String {
        switch section {
        case .runtime:
            "Runtime sections are loading from the Mac host companion."
        case .web:
            "Saved web pages are loading."
        case .responses, .chat, .history, .utilities, .settings, .terminal:
            "Activity in progress."
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
        case .web, .utilities, .settings, .runtime, .terminal:
            break
        }
    }

    private func iconForegroundColor(
        isSelected: Bool,
        hasUnreadFailure: Bool,
        hasUnreadCompletion: Bool,
        isActivityBlinkActive: Bool
    ) -> Color {
        hasUnreadFailure || hasUnreadCompletion || isActivityBlinkActive || isSelected
            ? Color.white
            : Color.hermesSecondaryText
    }

    var body: some View {
        HermesGlassEffectContainer(spacing: 12) {
            VStack(spacing: 0) {
                Image(sidebarLogoName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 54, height: 36)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .accessibilityLabel("Hermes")
                    .accessibilityAddTraits(.isHeader)

                HermesStatusBand(
                    statusMonitor: statusMonitor,
                    showsLabels: false,
                    apiChannelActive: apiChannelActive,
                    companionChannelActive: companionChannelActive,
                    dashboardChannelActive: dashboardChannelActive
                )

                List(sections) { section in
                    let hasUnreadCompletion = completionUnread(for: section)
                    let hasUnreadFailure = failureUnread(for: section)
                    let isActivityBlinkActive = activityBlinkActive(for: section)
                    Button {
                        selection = section
                        clearUnreadState(for: section)
                    } label: {
                        Image(systemName: section.systemImage)
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .foregroundStyle(iconForegroundColor(isSelected: selection == section, hasUnreadFailure: hasUnreadFailure, hasUnreadCompletion: hasUnreadCompletion, isActivityBlinkActive: isActivityBlinkActive))
                            .background(
                                WorkspaceSidebarIconBackground(
                                    isSelected: selection == section,
                                    isActivityBlinkActive: isActivityBlinkActive,
                                    hasUnreadFailure: hasUnreadFailure,
                                    hasUnreadCompletion: hasUnreadCompletion
                                )
                            )
                            .contentShape(Rectangle())
                            .accessibilityLabel(section.title)
                            .accessibilityHint(isActivityBlinkActive ? activityAccessibilityHint(for: section) : (hasUnreadFailure ? "Request failed. Tap to clear the failure indicator." : (hasUnreadCompletion ? "Completed. Tap to mark as seen." : "")))
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(.hermesDivider.opacity(0.4))
                }
                .listStyle(.sidebar)
                .scrollContentBackground(.hidden)
            }
        }
        .background(HermesLiquidGlassCanvas().ignoresSafeArea())
    }
}

private struct WorkspaceSidebarIconBackground: View {
    let isSelected: Bool
    let isActivityBlinkActive: Bool
    let hasUnreadFailure: Bool
    let hasUnreadCompletion: Bool

    var body: some View {
        if isActivityBlinkActive {
            TimelineView(.animation(minimumInterval: 0.2)) { context in
                let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4) / 2.4
                let opacity = 0.42 + (0.46 * (0.5 + 0.5 * sin(phase * 2 * .pi)))
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.igGradOrange.opacity(opacity))
            }
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(iconFill)
        }
    }

    private var iconFill: Color {
        if hasUnreadFailure {
            Color.igDestructive.opacity(0.9)
        } else if hasUnreadCompletion {
            Color.igOnlineGreen.opacity(0.85)
        } else if isSelected {
            Color.igActionBlue.opacity(0.92)
        } else {
            Color.clear
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

struct HermesStreamedJSONDebugPanel: View {
    @Bindable var responseSession: HermesResponsesSession
    @Bindable var chatSession: HermesChatSession
    var initialSource: HermesStreamDebugSource = .responses
    @State private var selectedSource: HermesStreamDebugSource = .responses

    private let visibleDebugLineCount: CGFloat = 16
    private let debugLineHeight: CGFloat = 18

    private var debugText: String {
        switch selectedSource {
        case .responses:
            if responseSession.rawStreamedJSON.isEmpty {
                return "No Responses API JSON has been streamed yet. Send a Responses API request with streaming enabled to populate this debug view."
            }
            return responseSession.rawStreamedJSON
        case .chat:
            if chatSession.rawStreamedJSON.isEmpty && chatSession.debugEventText.isEmpty {
                return "No Chat Completions API JSON has been streamed yet. Send a Chat Completions request with streaming enabled to populate this debug view."
            }
            if !chatSession.debugEventText.isEmpty {
                if chatSession.rawStreamedJSON.isEmpty {
                    return chatSession.debugEventText
                }
                return chatSession.debugEventText + "\n\n--- Raw SSE JSON ---\n\n" + chatSession.rawStreamedJSON
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
            chatSession.rawStreamedJSON.isEmpty && chatSession.debugEventText.isEmpty
        }
    }

    private func clearCurrentDebugText() {
        switch selectedSource {
        case .responses:
            responseSession.rawStreamedJSON = ""
        case .chat:
            chatSession.rawStreamedJSON = ""
            chatSession.debugEventText = ""
        }
    }

    var body: some View {
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
                    .frame(height: visibleDebugLineCount * debugLineHeight)
                    .padding(8)
                    .igFieldBackground()
        }
        .padding(.top, 12)
        .onAppear {
            selectedSource = initialSource
        }
    }
}
