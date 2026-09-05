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
    let tuiGatewayStore: HermesTUIGatewayStore
    let apiSettings: HermesAPISettings
    let dashboardURLString: String
    let selectedRuntimeProfileName: String

    @State private var serverName = ""
    @State private var transport: HermesCompanionMCPServerTransport = .stdio
    @State private var command = ""
    @State private var arguments = ""
    @State private var url = ""
    @State private var bearerToken = ""
    @State private var searchQuery = ""
    @State private var testRequestIDs: [String: UUID] = [:]
    @State private var testDisplays: [String: MCPServerTestDisplay] = [:]

    private var visibleServers: [HermesCompanionMCPServerSummary] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard query.isEmpty == false else { return companionRuntime.hermesMCPServers }
        return companionRuntime.hermesMCPServers.filter { $0.name.lowercased().contains(query) || $0.transport.lowercased().contains(query) || $0.tools.lowercased().contains(query) }
    }

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
                            Text("Loaded from the selected Hermes profile on the host.")
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

                        TextField("Search MCP servers", text: $searchQuery)
                            .hermesRuntimeInput()
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        if visibleServers.isEmpty {
                            ContentUnavailableView(
                                "No MCP Servers",
                                systemImage: "shippingbox",
                                description: Text("Add a stdio or streamable HTTP MCP server below.")
                            )
                        } else {
                            ForEach(visibleServers) { server in
                                MCPServerRow(
                                    server: server,
                                    isTesting: testRequestIDs[server.id] != nil,
                                    isMutating: companionRuntime.isBusy,
                                    testDisplay: testDisplays[server.id],
                                    onEnabledChange: { enabled in
                                        companionRuntime.setHermesMCPServerEnabled(
                                            name: server.name,
                                            enabled: enabled,
                                            settings: companionSettings,
                                            identityState: companionEnrollment.identityState
                                        )
                                    },
                                    onTest: { testAvailability(server) },
                                    onRemove: {
                                        companionRuntime.removeHermesMCPServer(
                                            name: server.name,
                                            settings: companionSettings,
                                            identityState: companionEnrollment.identityState
                                        )
                                    }
                                )
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
                            TextField(transport == .openAPI ? "OpenAPI base URL" : "MCP URL", text: $url)
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
        .task(id: "\(companionEnrollment.identityState.deviceID)|\(selectedRuntimeProfileName)") {
            testRequestIDs = [:]
            testDisplays = [:]
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
        case .streamableHTTP, .openAPI:
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
        case .openAPI:
            return "hermes mcp add \(name) --transport openapi --url \(url.isEmpty ? "<url>" : url)" + (bearerToken.isEmpty ? "" : " --auth header")
        }
    }

    private func testAvailability(_ server: HermesCompanionMCPServerSummary) {
        let serverID = server.id
        let serverName = server.name
        let profileName = selectedRuntimeProfileName
        let requestID = UUID()
        testRequestIDs[serverID] = requestID
        testDisplays.removeValue(forKey: serverID)
        Task { @MainActor in
            defer {
                if profileName == selectedRuntimeProfileName,
                   testRequestIDs[serverID] == requestID {
                    testRequestIDs.removeValue(forKey: serverID)
                }
            }
            do {
                try await tuiGatewayStore.connectForRuntime(
                    dashboardBaseURL: dashboardURLString,
                    apiSettings: apiSettings
                )
                let result = try await tuiGatewayStore.testMCPServer(name: serverName, profileName: profileName)
                guard testRequestIDs[serverID] == requestID,
                      profileName == selectedRuntimeProfileName,
                      companionRuntime.hermesMCPServers.contains(where: { $0.id == serverID }) else { return }
                testDisplays[serverID] = result.ok
                    ? .success(result.tools)
                    : .failure
            } catch {
                guard testRequestIDs[serverID] == requestID,
                      profileName == selectedRuntimeProfileName else { return }
                // Gateway or probe errors can include host transport detail. Keep
                // the UI safe and actionable without rendering untrusted text.
                testDisplays[serverID] = .failure
            }
        }
    }
}

private enum MCPServerTestDisplay: Equatable {
    case success([HermesTUIMCPServerTool])
    case failure
}

private struct MCPServerRow: View {
    let server: HermesCompanionMCPServerSummary
    let isTesting: Bool
    let isMutating: Bool
    let testDisplay: MCPServerTestDisplay?
    let onEnabledChange: (Bool) -> Void
    let onTest: () -> Void
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
                Toggle("Enabled", isOn: Binding(
                    get: { server.enabled },
                    set: onEnabledChange
                ))
                .disabled(isTesting || isMutating)
                Button {
                    onTest()
                } label: {
                    if isTesting {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("Testing Availability")
                        }
                    } else {
                        Label("Test Availability", systemImage: "network")
                    }
                }
                .hermesGlassButton()
                .disabled(isTesting || isMutating)
                testResult
            }
            Spacer()
            Button(role: .destructive) {
                onRemove()
            } label: {
                Label("Remove", systemImage: "trash")
            }
            .labelStyle(.iconOnly)
            .hermesGlassButton()
            .disabled(isTesting || isMutating)
        }
        .padding(14)
        .background(Color.hermesSurfaceInput)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private var testResult: some View {
        switch testDisplay {
        case .success(let tools):
            VStack(alignment: .leading, spacing: 4) {
                Text("Available · \(tools.count) tools")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.igOnlineGreen)
                ForEach(tools) { tool in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(tool.name).font(.caption.monospaced())
                        Text(tool.description).font(.caption).foregroundStyle(.hermesSecondaryText)
                    }
                }
            }
        case .failure:
            Text("Availability test failed. Check the selected profile’s server configuration and try again.")
                .font(.caption)
                .foregroundStyle(.red)
        case nil:
            EmptyView()
        }
    }
}
