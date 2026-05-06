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
            "Responses API"
        case .chat:
            "Chat Completions"
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
    var apiChannelActive = false
    var companionChannelActive = false
    var dashboardChannelActive = false

    var body: some View {
        VStack(spacing: 0) {
            HermesStatusBand(
                statusMonitor: statusMonitor,
                apiChannelActive: apiChannelActive,
                companionChannelActive: companionChannelActive,
                dashboardChannelActive: dashboardChannelActive
            )

            List(WorkspaceSection.allCases, selection: $selection) { section in
                NavigationLink(value: section) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(section.title, systemImage: section.systemImage)
                            .font(.headline)
                        Text(section.subtitle)
                            .font(.caption)
                            .foregroundStyle(.hermesSecondaryText)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 4)
                }
                .listRowBackground(
                    selection == section
                        ? AnyView(HermesLiquidGlassBackground(cornerRadius: 14, tint: .igActionBlue.opacity(0.18), interactive: true))
                        : AnyView(Color.clear)
                )
                .listRowSeparatorTint(.hermesDivider.opacity(0.4))
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .background(Color.hermesCanvas)
    }
}
