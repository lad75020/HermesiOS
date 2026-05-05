//
//  HermesRuntimeComponents.swift
//  HermesiOS
//

import Observation
import SwiftUI
import UniformTypeIdentifiers

struct HermesRuntimeAccordionPanel<Content: View>: View {
    let title: String
    let subtitle: String
    let systemImage: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: systemImage)
                        .font(.title3)
                        .foregroundStyle(.igActionBlue)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.hermesSecondaryText)
                    }
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.hermesSecondaryText)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.hermesElevated)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                    VStack(alignment: .leading, spacing: 16) {
                        content
                    }
                    .padding(20)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .background(Color.hermesElevated)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct HermesSkillToggleRow: View {
    let skill: HermesCompanionSkillSummary
    @Binding var isEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(skill.name)
                            .font(.headline)
                        Text(isEnabled ? "On" : "Off")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isEnabled ? .igOnlineGreen : .secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background((isEnabled ? Color.igOnlineGreen : Color.secondary).opacity(0.12))
                            .clipShape(Capsule())
                    }

                    Text(skill.description)
                        .font(.subheadline)
                        .foregroundStyle(.hermesSecondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        Text(skill.category.uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.hermesSecondaryText)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.igActionBlue.opacity(0.08))
                            .clipShape(Capsule())
                    }

                    Text(skill.path)
                        .font(.caption.monospaced())
                        .foregroundStyle(.hermesSecondaryText)
                        .textSelection(.enabled)
                }

                Toggle("", isOn: $isEnabled)
                    .labelsHidden()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hermesSurfaceInput)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct HermesToolsetToggleRow: View {
    let toolset: HermesCompanionToolsetInfo
    @Binding var isEnabled: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(toolset.label)
                        .font(.headline)
                    Text(toolset.enabled ? "On" : "Off")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(toolset.enabled ? .igOnlineGreen : .secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background((toolset.enabled ? Color.igOnlineGreen : Color.secondary).opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(toolset.description)
                    .font(.subheadline)
                    .foregroundStyle(.hermesSecondaryText)

                Text(toolset.key)
                    .font(.caption.monospaced())
                    .foregroundStyle(.hermesSecondaryText)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 12)

            Toggle("", isOn: $isEnabled)
                .labelsHidden()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hermesSurfaceInput)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}


enum HermesTerminalBackend: String, CaseIterable, Identifiable {
    case local
    case ssh

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .local:
            "Local"
        case .ssh:
            "SSH"
        }
    }

    var systemImage: String {
        switch self {
        case .local:
            "laptopcomputer"
        case .ssh:
            "network.badge.shield.half.filled"
        }
    }
}

enum HermesRuntimePanelKind: String, Identifiable {
    case skills
    case companion
    case backend
    case profiles
    case permissions
    case tools
    case mcpServers
    case providers
    case models
    case sandbox
    case memory
    case schedules
    case observability

    var id: String { rawValue }
}

struct HermesRuntimePanel: Identifiable {
    let kind: HermesRuntimePanelKind
    let title: String
    let subtitle: String
    let systemImage: String
    let placeholder: String

    var id: HermesRuntimePanelKind { kind }

    static let placeholderPanels: [HermesRuntimePanel] = [
        .init(kind: .profiles, title: "Profiles", subtitle: "Switch between runtime profiles and targets", systemImage: "person.crop.rectangle.stack", placeholder: "Profile routing, per-target overrides, and environment inheritance will live here."),
        .init(kind: .permissions, title: "Permissions", subtitle: "Approval policy and privileged operations", systemImage: "checkmark.shield", placeholder: "Approval policy, escalations, and audit-friendly permission controls can expand here."),
        .init(kind: .sandbox, title: "Sandbox", subtitle: "Filesystem and network boundaries", systemImage: "lock.square.stack", placeholder: "Workspace-write, read-only, and network isolation controls can be configured here."),
        .init(kind: .observability, title: "Observability", subtitle: "Logs, traces, and runtime diagnostics", systemImage: "waveform.and.magnifyingglass", placeholder: "Runtime logs, traces, and environment diagnostics can be collected and displayed here.")
    ]
}

struct HermesAgentConfiguration {
    var backend: HermesTerminalBackend = .local
    var persistentShell = true
    var workingDirectory = "."
    var sshHost = ""
    var sshUser = ""
    var sshPort = "22"
    var sshKeyPath = "~/.ssh/id_rsa"
    var activeRuntimePanel: HermesRuntimePanelKind? = .companion
    var skillSearchQuery = ""

    var backendSummary: String {
        switch backend {
        case .local:
            "Commands execute directly on the device host running Hermes. This is the fastest path for initial gateway integration."
        case .ssh:
            "Commands execute on a remote server over SSH with a persistent shell, which is the right fit once the app starts managing remote agents."
        }
    }

}

#Preview("Default") {
    ContentView()
}

extension View {
    func hermesRuntimeInput(
        background: Color = Color.igActionBlue.opacity(0.08),
        border: Color = Color.igActionBlue.opacity(0.28)
    ) -> some View {
        self
            .textFieldStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            )
            .shadow(color: border.opacity(0.18), radius: 8, y: 3)
    }
}
