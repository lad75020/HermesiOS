//
//  HermesMCPServersPanel.swift
//  HermesiOS
//

import Observation
import SwiftUI

struct HermesMCPServersPanel: View {
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession

    @State private var serverName = ""
    @State private var transport: HermesCompanionMCPServerTransport = .stdio
    @State private var command = ""
    @State private var arguments = ""
    @State private var url = ""
    @State private var bearerToken = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if companionEnrollment.identityState.isEnrolled == false {
                ContentUnavailableView(
                    "Host Companion Required",
                    systemImage: "lock.laptopcomputer",
                    description: Text("Authenticate the macOS companion before listing or editing Hermes MCP servers.")
                )
            } else {
                HermesSectionCard("Known MCP Servers") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Loaded with `hermes mcp list` on the host.")
                                .font(.subheadline)
                                .foregroundStyle(.hermesSecondaryText)
                            Spacer()
                            Button {
                                companionRuntime.refreshHermesMCPServers(
                                    settings: companionSettings,
                                    identityState: companionEnrollment.identityState
                                )
                            } label: {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                            .hermesGlassButton()
                            .disabled(companionRuntime.isBusy)
                        }

                        if companionRuntime.hermesMCPServers.isEmpty {
                            ContentUnavailableView(
                                "No MCP Servers",
                                systemImage: "shippingbox",
                                description: Text("Add a stdio or streamable HTTP MCP server below.")
                            )
                        } else {
                            ForEach(companionRuntime.hermesMCPServers) { server in
                                MCPServerRow(server: server) {
                                    companionRuntime.removeHermesMCPServer(
                                        name: server.name,
                                        settings: companionSettings,
                                        identityState: companionEnrollment.identityState
                                    )
                                }
                            }
                        }
                    }
                }

                HermesSectionCard("Add MCP Server") {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Server name", text: $serverName)
                            .hermesRuntimeInput()
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        Picker("Transport", selection: $transport) {
                            ForEach(HermesCompanionMCPServerTransport.allCases) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)

                        if transport == .stdio {
                            TextField("Command, e.g. npx", text: $command)
                                .hermesRuntimeInput()
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                            TextField("Arguments, e.g. @modelcontextprotocol/server-github", text: $arguments, axis: .vertical)
                                .lineLimit(2...5)
                                .hermesRuntimeInput()
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        } else {
                            TextField("MCP URL", text: $url)
                                .hermesRuntimeInput()
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)

                            SecureField("Bearer token (optional)", text: $bearerToken)
                                .hermesRuntimeInput()
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }

                        Text(addCommandPreview)
                            .font(.caption.monospaced())
                            .foregroundStyle(.hermesSecondaryText)
                            .textSelection(.enabled)

                        Button {
                            companionRuntime.addHermesMCPServer(
                                name: serverName,
                                transport: transport,
                                command: command,
                                arguments: arguments,
                                url: url,
                                bearerToken: bearerToken,
                                settings: companionSettings,
                                identityState: companionEnrollment.identityState
                            )
                            bearerToken = ""
                        } label: {
                            Label("Add MCP Server", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .hermesGlassProminentButton()
                        .disabled(companionRuntime.isBusy || !canAdd)

                        if !companionRuntime.mcpOperationOutput.isEmpty {
                            Text(companionRuntime.mcpOperationOutput)
                                .font(.caption.monospaced())
                                .foregroundStyle(.hermesSecondaryText)
                                .textSelection(.enabled)
                                .lineLimit(6)
                        }
                    }
                }
            }
        }
        .task(id: companionEnrollment.identityState.deviceID) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            companionRuntime.refreshHermesMCPServers(settings: companionSettings, identityState: companionEnrollment.identityState)
        }
    }

    private var canAdd: Bool {
        let trimmedName = serverName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return false }
        switch transport {
        case .stdio:
            return !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .streamableHTTP:
            let trimmedURL = url.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return trimmedURL.hasPrefix("http://") || trimmedURL.hasPrefix("https://")
        }
    }

    private var addCommandPreview: String {
        let name = serverName.isEmpty ? "servername" : serverName
        switch transport {
        case .stdio:
            return "hermes mcp add \(name) --command \(command.isEmpty ? "<command>" : command) --args \(arguments.isEmpty ? "<arguments>" : arguments)"
        case .streamableHTTP:
            return "hermes mcp add \(name) --url \(url.isEmpty ? "<url>" : url)" + (bearerToken.isEmpty ? "" : " --auth header")
        }
    }
}

private struct MCPServerRow: View {
    let server: HermesCompanionMCPServerSummary
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(server.name)
                        .font(.headline)
                    Text(server.status)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(server.status.localizedCaseInsensitiveContains("enabled") ? .igOnlineGreen : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((server.status.localizedCaseInsensitiveContains("enabled") ? Color.igOnlineGreen : Color.secondary).opacity(0.12))
                        .clipShape(Capsule())
                }
                Text(server.transport)
                    .font(.caption.monospaced())
                    .foregroundStyle(.hermesSecondaryText)
                    .textSelection(.enabled)
                Text("Tools: \(server.tools)")
                    .font(.caption)
                    .foregroundStyle(.hermesSecondaryText)
            }
            Spacer()
            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Remove", systemImage: "trash")
            }
            .labelStyle(.iconOnly)
            .hermesGlassButton()
        }
        .padding(14)
        .background(Color.hermesSurfaceInput)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
