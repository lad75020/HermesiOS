//
//  CompanionServer.swift
//  HermesHostCompanion
//
//  Created by Codex on 05/05/2026.
//

import Foundation
import Network
import Observation
import OSLog
import Security

@MainActor
@Observable
final class CompanionServer {
    enum State: Equatable {
        case stopped
        case starting
        case running
        case failed

        var displayName: String {
            switch self {
            case .stopped:
                "Stopped"
            case .starting:
                "Starting"
            case .running:
                "Running"
            case .failed:
                "Failed"
            }
        }
    }

    private(set) var state: State = .stopped
    private(set) var listenerDescription = "Not listening"
    var lastErrorMessage = ""

    private var listener: NWListener?
    private var sessions: [UUID: CompanionClientSession] = [:]
    private var configuration = CompanionServerConfigurationStore.load()

    var currentConfiguration: CompanionServerConfiguration {
        configuration
    }

    func updateConfiguration(_ configuration: CompanionServerConfiguration) {
        self.configuration = configuration
        CompanionServerConfigurationStore.save(configuration)

        if state == .running {
            listenerDescription = "ws://\(configuration.host):\(configuration.port.rawValue)/ws"
        }
    }

    func start() async throws {
        stop()
        state = .starting
        lastErrorMessage = ""

        let parameters = CompanionServerParametersFactory.makeAuthenticatedParameters()

        // Bind the actual companion listener to loopback. The advertised host can
        // still be a Tailscale DNS name/IP; IPNExtension owns tailnet addresses and
        // forwards to the local loopback listener. Binding to configuration.host or
        // all interfaces conflicts with Tailscale Serve.
        parameters.requiredLocalEndpoint = .hostPort(
            host: NWEndpoint.Host("127.0.0.1"),
            port: configuration.port
        )

        let listener = try NWListener(using: parameters)
        let logger = Logger.companion

        listener.stateUpdateHandler = { [weak self] newState in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch newState {
                case .ready:
                    self.state = .running
                    self.listenerDescription = "ws://\(self.configuration.host):\(self.configuration.port.rawValue)/ws"
                    logger.info("Companion HTTP/WebSocket server ready on port \(self.configuration.port.rawValue)")
                case .failed(let error):
                    self.state = .failed
                    self.lastErrorMessage = "API listener failed on port \(self.configuration.port.rawValue): \(error.localizedDescription)"
                    self.listenerDescription = "API listener failed"
                    logger.error("Companion API server failed: \(error.localizedDescription, privacy: .public)")
                case .cancelled:
                    self.state = .stopped
                    self.listenerDescription = "Not listening"
                default:
                    break
                }
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor [weak self] in
                self?.accept(connection: connection)
            }
        }

        listener.start(queue: .main)
        self.listener = listener
    }

    func stop() {
        sessions.values.forEach { $0.stop() }
        sessions.removeAll()
        listener?.cancel()
        listener = nil
        state = .stopped
        listenerDescription = "Not listening"
    }

    private func accept(connection: NWConnection) {
        let session = CompanionClientSession(connection: connection, authenticationToken: CompanionAuthenticationTokenStore.shared.token)
        sessions[session.id] = session
        session.onStop = { [weak self] sessionID in
            Task { @MainActor [weak self] in
                self?.sessions.removeValue(forKey: sessionID)
            }
        }
        session.start()
    }
}

struct CompanionServerConfiguration {
    let host: String
    let port: NWEndpoint.Port

    static let `default` = CompanionServerConfiguration(host: "localhost", port: 9112)
}

private enum CompanionServerConfigurationStore {
    private static let hostKey = "companion.server.host"
    private static let portKey = "companion.server.port"

    static func load() -> CompanionServerConfiguration {
        let defaults = UserDefaults.standard
        let host = defaults.string(forKey: hostKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let portValue = defaults.integer(forKey: portKey)

        let hostValue = (host?.isEmpty == false ? host! : CompanionServerConfiguration.default.host)
        let port = validPort(from: portValue) ?? CompanionServerConfiguration.default.port

        return CompanionServerConfiguration(host: hostValue, port: port)
    }

    static func save(_ configuration: CompanionServerConfiguration) {
        let defaults = UserDefaults.standard
        defaults.set(configuration.host, forKey: hostKey)
        defaults.set(Int(configuration.port.rawValue), forKey: portKey)
    }

    private static func validPort(from value: Int) -> NWEndpoint.Port? {
        guard value > 0, value < 65536 else { return nil }
        return NWEndpoint.Port(rawValue: UInt16(value))
    }
}

private enum CompanionServerParametersFactory {
    static func makeAuthenticatedParameters() -> NWParameters {
        let tcpOptions = NWProtocolTCP.Options()
        let parameters = NWParameters(tls: nil, tcp: tcpOptions)
        let webSocketOptions = NWProtocolWebSocket.Options(.version13)
        webSocketOptions.autoReplyPing = true
        webSocketOptions.maximumMessageSize = 1 << 20
        parameters.defaultProtocolStack.applicationProtocols.insert(webSocketOptions, at: 0)
        parameters.allowLocalEndpointReuse = true
        return parameters
    }
}


final class CompanionClientSession {
    let id = UUID()
    var onStop: ((UUID) -> Void)?

    private let connection: NWConnection
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let registry = CompanionTargetRegistry.shared
    private let serviceRegistry = CompanionServiceRegistry.shared
    private let toolsetRegistry = CompanionToolsetRegistry.shared
    private let modelRegistry = CompanionModelRegistry.shared
    private let providerRegistry = CompanionProviderRegistry()
    private let memoryRegistry = CompanionMemoryRegistry()
    private let scheduleRegistry = CompanionScheduleRegistry()
    private let mcpRegistry = CompanionMCPRegistry()
    private let logRegistry = CompanionLogRegistry()
    private let profileRegistry = CompanionProfileRegistry()
    private let gatewayRegistry = CompanionGatewayRegistry()
    private let gitRegistry = CompanionGitRegistry()
    private let knowledgeEraserRegistry = CompanionKnowledgeEraserRegistry()
    private let fileDownloadRegistry = CompanionFileDownloadRegistry()
    private let tailscaleServeRegistry = CompanionTailscaleServeRegistry()
    private let authenticationToken: String

    init(connection: NWConnection, authenticationToken: String) {
        self.connection = connection
        self.authenticationToken = authenticationToken
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                Logger.companion.info("Accepted companion client session \(self.id.uuidString, privacy: .public)")
                self.receiveNextMessage()
            case .failed(let error):
                Logger.companion.error("Session \(self.id.uuidString, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                self.stop()
            case .cancelled:
                self.stop()
            default:
                break
            }
        }

        connection.start(queue: .main)
    }

    func stop() {
        connection.cancel()
        onStop?(id)
        onStop = nil
    }

    private func receiveNextMessage() {
        connection.receiveMessage { [weak self] data, context, _, error in
            guard let self else { return }
            if let error {
                Logger.companion.error("Receive error for session \(self.id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
                self.stop()
                return
            }

            guard
                let data,
                !data.isEmpty
            else {
                self.receiveNextMessage()
                return
            }

            do {
                let request = try self.decoder.decode(CompanionIncomingEnvelope.self, from: data)
                let response: CompanionOutgoingEnvelope
                if request.authenticationToken == self.authenticationToken {
                    response = self.route(request: request)
                } else {
                    response = .error(id: request.id, code: "invalid_token", message: "The Host Companion API key is invalid.")
                }
                let responseData = try self.encoder.encode(response)
                self.send(responseData)
            } catch {
                let errorResponse = CompanionOutgoingEnvelope.error(
                    id: nil,
                    code: "invalid_request",
                    message: error.localizedDescription
                )
                if let data = try? self.encoder.encode(errorResponse) {
                    self.send(data)
                } else {
                    self.stop()
                }
            }

            self.receiveNextMessage()
        }
    }

    private func send(_ data: Data) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
        let context = NWConnection.ContentContext(identifier: "ws-response", metadata: [metadata])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
    }

    private func route(request: CompanionIncomingEnvelope) -> CompanionOutgoingEnvelope {
        switch request.type {
        case "hello":
            return .success(
                id: request.id,
                payload: HelloResult(
                    protocolVersion: "1",
                    serverName: "HermesHostCompanion",
                    capabilities: [
                        "hello",
                        "list_targets",
                        "read_target",
                        "validate_target",
                        "write_target",
                        "list_backups",
                        "restore_backup",
                        "download_file",
                        "download_file_info",
                        "download_file_chunk",
                        "service_status",
                        "service_start",
                        "service_stop",
                        "service_restart",
                        "service_ports",
                        "tailscale_serve_status",
                        "set_tailscale_serve",
                        "hermes_installation_status",
                        "hermes_installation_update",
                        "hermes_installation_review_conflicts",
                        "hermes_installation_merge_reviewed_update",
                        "list_skills",
                        "set_skill_state",
                        "list_mcp_servers",
                        "add_mcp_server",
                        "remove_mcp_server",
                        "read_hermes_log",
                        "list_toolsets",
                        "set_toolset_enabled",
                        "list_models",
                        "add_model",
                        "update_model",
                        "remove_model",
                        "get_providers_config",
                        "set_provider_env",
                        "remove_provider_env",
                        "set_provider_model_config",
                        "set_runtime_model_slot",
                        "set_credential_pool",
                        "get_memory_config",
                        "add_memory_entry",
                        "update_memory_entry",
                        "remove_memory_entry",
                        "write_user_profile",
                        "set_memory_provider",
                        "set_memory_env",
                        "export_supermemory_delta",
                        "import_supermemory_delta",
                        "scan_knowledge_eraser",
                        "erase_knowledge_items",
                        "list_schedules",
                        "create_schedule",
                        "remove_schedule",
                        "pause_schedule",
                        "resume_schedule",
                        "trigger_schedule",
                        "list_profiles",
                        "create_profile",
                        "edit_profile",
                        "delete_profile",
                        "set_active_profile",
                        "get_gateway_config",
                        "gateway_status",
                        "set_gateway_running",
                        "restart_gateway",
                        "set_gateway_env",
                        "set_gateway_platform"
                    ]
                )
            )
        case "list_targets":
            do {
                let payload = try request.payload?.decode(ListTargetsPayload.self)
                return .success(
                    id: request.id,
                    payload: ListTargetsResult(targets: try registry.listTargets(workspacePath: payload?.workspacePath, profileName: payload?.profileName))
                )
            } catch {
                return .error(id: request.id, code: "list_targets_failed", message: error.localizedDescription)
            }
        case "read_target":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The read_target request requires a payload.")
                }
                let readPayload = try payload.decode(ReadTargetPayload.self)
                let result = try registry.readTarget(
                    id: readPayload.targetID,
                    workspacePath: readPayload.workspacePath,
                    profileName: readPayload.profileName
                )
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "read_target_failed", message: error.localizedDescription)
            }
        case "validate_target":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The validate_target request requires a payload.")
                }
                let validatePayload = try payload.decode(ValidateTargetPayload.self)
                let result = try registry.validateTarget(
                    id: validatePayload.targetID,
                    proposedContent: validatePayload.content,
                    workspacePath: validatePayload.workspacePath,
                    profileName: validatePayload.profileName
                )
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "validate_target_failed", message: error.localizedDescription)
            }
        case "write_target":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The write_target request requires a payload.")
                }
                let writePayload = try payload.decode(WriteTargetPayload.self)
                let result = try registry.writeTarget(
                    id: writePayload.targetID,
                    expectedRevision: writePayload.expectedRevision,
                    content: writePayload.content,
                    createBackup: writePayload.createBackup,
                    workspacePath: writePayload.workspacePath,
                    profileName: writePayload.profileName
                )
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "write_target_failed", message: error.localizedDescription)
            }
        case "list_backups":
            do {
                let payload = try request.payload?.decode(ListBackupsPayload.self) ?? ListBackupsPayload(targetID: nil)
                let result = registry.listBackups(targetID: payload.targetID)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "list_backups_failed", message: error.localizedDescription)
            }
        case "restore_backup":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The restore_backup request requires a payload.")
                }
                let restorePayload = try payload.decode(RestoreBackupPayload.self)
                let result = try registry.restoreBackup(id: restorePayload.backupID)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "restore_backup_failed", message: error.localizedDescription)
            }
        case "download_file":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The download_file request requires a payload.")
                }
                let downloadPayload = try payload.decode(FileDownloadPayload.self)
                let result = try fileDownloadRegistry.downloadFile(path: downloadPayload.path)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "download_file_failed", message: error.localizedDescription)
            }
        case "download_file_info":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The download_file_info request requires a payload.")
                }
                let downloadPayload = try payload.decode(FileDownloadPayload.self)
                let result = try fileDownloadRegistry.downloadFileInfo(path: downloadPayload.path)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "download_file_info_failed", message: error.localizedDescription)
            }
        case "download_file_chunk":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The download_file_chunk request requires a payload.")
                }
                let chunkPayload = try payload.decode(FileDownloadChunkPayload.self)
                let result = try fileDownloadRegistry.downloadFileChunk(
                    path: chunkPayload.path,
                    offset: chunkPayload.offset,
                    length: chunkPayload.length
                )
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "download_file_chunk_failed", message: error.localizedDescription)
            }
        case "service_status":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The service_status request requires a payload.")
                }
                let statusPayload = try payload.decode(ServiceStatusPayload.self)
                let result = try serviceRegistry.status(for: statusPayload.serviceID)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "service_status_failed", message: error.localizedDescription)
            }
        case "service_start":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The service_start request requires a payload.")
                }
                let startPayload = try payload.decode(ServiceStartPayload.self)
                let result = try serviceRegistry.start(serviceID: startPayload.serviceID)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "service_start_failed", message: error.localizedDescription)
            }
        case "service_stop":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The service_stop request requires a payload.")
                }
                let stopPayload = try payload.decode(ServiceStopPayload.self)
                let result = try serviceRegistry.stop(serviceID: stopPayload.serviceID)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "service_stop_failed", message: error.localizedDescription)
            }
        case "service_restart":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The service_restart request requires a payload.")
                }
                let restartPayload = try payload.decode(ServiceRestartPayload.self)
                let result = try serviceRegistry.restart(serviceID: restartPayload.serviceID)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "service_restart_failed", message: error.localizedDescription)
            }
        case "service_ports":
            return .success(id: request.id, payload: CompanionServicePortsStore.load())
        case "tailscale_serve_status":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The tailscale_serve_status request requires a payload.")
                }
                let statusPayload = try payload.decode(TailscaleServeStatusPayload.self)
                return .success(id: request.id, payload: try tailscaleServeRegistry.status(port: statusPayload.port))
            } catch {
                return .error(id: request.id, code: "tailscale_serve_status_failed", message: error.localizedDescription)
            }
        case "set_tailscale_serve":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The set_tailscale_serve request requires a payload.")
                }
                let setPayload = try payload.decode(TailscaleServeSetPayload.self)
                return .success(id: request.id, payload: try tailscaleServeRegistry.set(port: setPayload.port, enabled: setPayload.enabled))
            } catch {
                return .error(id: request.id, code: "set_tailscale_serve_failed", message: error.localizedDescription)
            }
        case "hermes_installation_status":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The hermes_installation_status request requires a payload.")
                }
                let statusPayload = try payload.decode(HermesInstallationStatusPayload.self)
                let result = try gitRegistry.hermesInstallationStatus(workspacePath: statusPayload.workspacePath)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "hermes_installation_status_failed", message: error.localizedDescription)
            }
        case "hermes_installation_update":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The hermes_installation_update request requires a payload.")
                }
                let updatePayload = try payload.decode(HermesInstallationUpdatePayload.self)
                let result = try gitRegistry.updateHermesInstallation(workspacePath: updatePayload.workspacePath)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "hermes_installation_update_failed", message: error.localizedDescription)
            }
        case "hermes_installation_review_conflicts":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The hermes_installation_review_conflicts request requires a payload.")
                }
                let reviewPayload = try payload.decode(HermesInstallationReviewConflictsPayload.self)
                let result = try gitRegistry.reviewHermesInstallationConflicts(workspacePath: reviewPayload.workspacePath)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "hermes_installation_review_conflicts_failed", message: error.localizedDescription)
            }
        case "hermes_installation_merge_reviewed_update":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The hermes_installation_merge_reviewed_update request requires a payload.")
                }
                let mergePayload = try payload.decode(HermesInstallationMergePayload.self)
                let result = try gitRegistry.mergeReviewedHermesInstallationUpdate(workspacePath: mergePayload.workspacePath)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "hermes_installation_merge_reviewed_update_failed", message: error.localizedDescription)
            }
        case "list_skills":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The list_skills request requires a payload.")
                }
                let listPayload = try payload.decode(ListHermesSkillsPayload.self)
                let result = try registry.listHermesSkills(workspacePath: listPayload.workspacePath)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "list_skills_failed", message: error.localizedDescription)
            }
        case "set_skill_state":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The set_skill_state request requires a payload.")
                }
                let setPayload = try payload.decode(SetHermesSkillStatePayload.self)
                let result = try registry.setHermesSkillState(
                    workspacePath: setPayload.workspacePath,
                    skillID: setPayload.skillID,
                    isEnabled: setPayload.isEnabled
                )
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "set_skill_state_failed", message: error.localizedDescription)
            }
        case "list_mcp_servers":
            do {
                return .success(id: request.id, payload: try mcpRegistry.listServers())
            } catch {
                return .error(id: request.id, code: "list_mcp_servers_failed", message: error.localizedDescription)
            }
        case "add_mcp_server":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The add_mcp_server request requires a payload.")
                }
                let addPayload = try payload.decode(AddMCPServerPayload.self)
                return .success(id: request.id, payload: try mcpRegistry.addServer(addPayload))
            } catch {
                return .error(id: request.id, code: "add_mcp_server_failed", message: error.localizedDescription)
            }
        case "remove_mcp_server":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The remove_mcp_server request requires a payload.")
                }
                let removePayload = try payload.decode(RemoveMCPServerPayload.self)
                return .success(id: request.id, payload: try mcpRegistry.removeServer(name: removePayload.name))
            } catch {
                return .error(id: request.id, code: "remove_mcp_server_failed", message: error.localizedDescription)
            }
        case "read_hermes_log":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The read_hermes_log request requires a payload.")
                }
                let logPayload = try payload.decode(ReadHermesLogPayload.self)
                return .success(id: request.id, payload: try logRegistry.readLog(logPayload))
            } catch {
                return .error(id: request.id, code: "read_hermes_log_failed", message: error.localizedDescription)
            }
        case "list_toolsets":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The list_toolsets request requires a payload.")
                }
                let listPayload = try payload.decode(ListToolsetsPayload.self)
                let result = try toolsetRegistry.listToolsets(workspacePath: listPayload.workspacePath)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "list_toolsets_failed", message: error.localizedDescription)
            }
        case "set_toolset_enabled":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The set_toolset_enabled request requires a payload.")
                }
                let setPayload = try payload.decode(SetToolsetEnabledPayload.self)
                let result = try toolsetRegistry.setToolsetEnabled(
                    workspacePath: setPayload.workspacePath,
                    key: setPayload.key,
                    enabled: setPayload.enabled
                )
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "set_toolset_enabled_failed", message: error.localizedDescription)
            }
        case "list_models":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The list_models request requires a payload.")
                }
                let listPayload = try payload.decode(ListModelsPayload.self)
                let result = try modelRegistry.listModels(workspacePath: listPayload.workspacePath)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "list_models_failed", message: error.localizedDescription)
            }
        case "add_model":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The add_model request requires a payload.")
                }
                let addPayload = try payload.decode(AddModelPayload.self)
                let result = try modelRegistry.addModel(
                    workspacePath: addPayload.workspacePath,
                    name: addPayload.name,
                    provider: addPayload.provider,
                    model: addPayload.model,
                    baseURL: addPayload.baseURL
                )
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "add_model_failed", message: error.localizedDescription)
            }
        case "update_model":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The update_model request requires a payload.")
                }
                let updatePayload = try payload.decode(UpdateModelPayload.self)
                let result = try modelRegistry.updateModel(
                    workspacePath: updatePayload.workspacePath,
                    id: updatePayload.id,
                    name: updatePayload.name,
                    provider: updatePayload.provider,
                    model: updatePayload.model,
                    baseURL: updatePayload.baseURL
                )
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "update_model_failed", message: error.localizedDescription)
            }
        case "remove_model":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The remove_model request requires a payload.")
                }
                let removePayload = try payload.decode(RemoveModelPayload.self)
                let result = try modelRegistry.removeModel(
                    workspacePath: removePayload.workspacePath,
                    id: removePayload.id
                )
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "remove_model_failed", message: error.localizedDescription)
            }
        case "get_providers_config":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The get_providers_config request requires a payload.")
                }
                let configPayload = try payload.decode(ProvidersConfigPayload.self)
                let result = try providerRegistry.load(workspacePath: configPayload.workspacePath)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "get_providers_config_failed", message: error.localizedDescription)
            }
        case "set_provider_env":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The set_provider_env request requires a payload.")
                }
                let envPayload = try payload.decode(SetProviderEnvPayload.self)
                let result = try providerRegistry.setEnv(workspacePath: envPayload.workspacePath, key: envPayload.key, value: envPayload.value)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "set_provider_env_failed", message: error.localizedDescription)
            }
        case "remove_provider_env":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The remove_provider_env request requires a payload.")
                }
                let envPayload = try payload.decode(RemoveProviderEnvPayload.self)
                let result = try providerRegistry.removeEnv(workspacePath: envPayload.workspacePath, key: envPayload.key)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "remove_provider_env_failed", message: error.localizedDescription)
            }
        case "set_provider_model_config":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The set_provider_model_config request requires a payload.")
                }
                let modelPayload = try payload.decode(SetProviderModelConfigPayload.self)
                let result = try providerRegistry.setModelConfig(workspacePath: modelPayload.workspacePath, provider: modelPayload.provider, model: modelPayload.model, baseUrl: modelPayload.baseUrl)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "set_provider_model_config_failed", message: error.localizedDescription)
            }
        case "set_runtime_model_slot":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The set_runtime_model_slot request requires a payload.")
                }
                let slotPayload = try payload.decode(SetRuntimeModelSlotPayload.self)
                let result = try providerRegistry.setRuntimeModelSlot(
                    workspacePath: slotPayload.workspacePath,
                    section: slotPayload.section,
                    key: slotPayload.key,
                    provider: slotPayload.provider,
                    model: slotPayload.model
                )
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "set_runtime_model_slot_failed", message: error.localizedDescription)
            }
        case "set_credential_pool":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The set_credential_pool request requires a payload.")
                }
                let poolPayload = try payload.decode(SetCredentialPoolPayload.self)
                let result = try providerRegistry.setCredentialPool(workspacePath: poolPayload.workspacePath, provider: poolPayload.provider, entries: poolPayload.entries)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "set_credential_pool_failed", message: error.localizedDescription)
            }
        case "get_memory_config":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The get_memory_config request requires a payload.")
                }
                let memoryPayload = try payload.decode(MemoryConfigPayload.self)
                let result = try memoryRegistry.load(workspacePath: memoryPayload.workspacePath)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "get_memory_config_failed", message: error.localizedDescription)
            }
        case "add_memory_entry":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The add_memory_entry request requires a payload.") }
                let addPayload = try payload.decode(AddMemoryEntryPayload.self)
                let result = try memoryRegistry.addEntry(workspacePath: addPayload.workspacePath, content: addPayload.content)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "add_memory_entry_failed", message: error.localizedDescription)
            }
        case "update_memory_entry":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The update_memory_entry request requires a payload.") }
                let updatePayload = try payload.decode(UpdateMemoryEntryPayload.self)
                let result = try memoryRegistry.updateEntry(workspacePath: updatePayload.workspacePath, index: updatePayload.index, content: updatePayload.content)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "update_memory_entry_failed", message: error.localizedDescription)
            }
        case "remove_memory_entry":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The remove_memory_entry request requires a payload.") }
                let removePayload = try payload.decode(RemoveMemoryEntryPayload.self)
                let result = try memoryRegistry.removeEntry(workspacePath: removePayload.workspacePath, index: removePayload.index)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "remove_memory_entry_failed", message: error.localizedDescription)
            }
        case "write_user_profile":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The write_user_profile request requires a payload.") }
                let userPayload = try payload.decode(WriteUserProfilePayload.self)
                let result = try memoryRegistry.writeUserProfile(workspacePath: userPayload.workspacePath, content: userPayload.content)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "write_user_profile_failed", message: error.localizedDescription)
            }
        case "set_memory_provider":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The set_memory_provider request requires a payload.") }
                let providerPayload = try payload.decode(SetMemoryProviderPayload.self)
                let result = try memoryRegistry.setProvider(workspacePath: providerPayload.workspacePath, provider: providerPayload.provider)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "set_memory_provider_failed", message: error.localizedDescription)
            }
        case "set_memory_env":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The set_memory_env request requires a payload.") }
                let envPayload = try payload.decode(SetMemoryEnvPayload.self)
                let result = try memoryRegistry.setEnv(workspacePath: envPayload.workspacePath, key: envPayload.key, value: envPayload.value)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "set_memory_env_failed", message: error.localizedDescription)
            }
        case "export_supermemory_delta":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The export_supermemory_delta request requires a payload.") }
                let exportPayload = try payload.decode(SupermemoryManagementPayload.self)
                let result = try memoryRegistry.exportSupermemoryDelta(workspacePath: exportPayload.workspacePath)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "export_supermemory_delta_failed", message: error.localizedDescription)
            }
        case "import_supermemory_delta":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The import_supermemory_delta request requires a payload.") }
                let importPayload = try payload.decode(SupermemoryManagementPayload.self)
                let result = try memoryRegistry.importSupermemoryDelta(workspacePath: importPayload.workspacePath)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "import_supermemory_delta_failed", message: error.localizedDescription)
            }
        case "scan_knowledge_eraser":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The scan_knowledge_eraser request requires a payload.") }
                let scanPayload = try payload.decode(KnowledgeEraserScanPayload.self)
                let result = try knowledgeEraserRegistry.scan(workspacePath: scanPayload.workspacePath, topic: scanPayload.topic)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "scan_knowledge_eraser_failed", message: error.localizedDescription)
            }
        case "erase_knowledge_items":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The erase_knowledge_items request requires a payload.") }
                let erasePayload = try payload.decode(KnowledgeEraserErasePayload.self)
                let result = try knowledgeEraserRegistry.erase(workspacePath: erasePayload.workspacePath, topic: erasePayload.topic, selectedItemIDs: erasePayload.selectedItemIDs)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "erase_knowledge_items_failed", message: error.localizedDescription)
            }
        case "list_schedules":
            do {
                let payload = try request.payload?.decode(ListSchedulesPayload.self) ?? ListSchedulesPayload(workspacePath: NSHomeDirectory() + "/.hermes", includeDisabled: true)
                let result = try scheduleRegistry.list(workspacePath: payload.workspacePath, includeDisabled: payload.includeDisabled)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "list_schedules_failed", message: error.localizedDescription)
            }
        case "create_schedule":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The create_schedule request requires a payload.") }
                let createPayload = try payload.decode(CreateSchedulePayload.self)
                let result = try scheduleRegistry.create(workspacePath: createPayload.workspacePath, schedule: createPayload.schedule, prompt: createPayload.prompt, name: createPayload.name, deliver: createPayload.deliver)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "create_schedule_failed", message: error.localizedDescription)
            }
        case "remove_schedule":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The remove_schedule request requires a payload.") }
                let opPayload = try payload.decode(ScheduleOperationPayload.self)
                let result = try scheduleRegistry.remove(workspacePath: opPayload.workspacePath, jobID: opPayload.jobID)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "remove_schedule_failed", message: error.localizedDescription)
            }
        case "pause_schedule":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The pause_schedule request requires a payload.") }
                let opPayload = try payload.decode(ScheduleOperationPayload.self)
                let result = try scheduleRegistry.pause(workspacePath: opPayload.workspacePath, jobID: opPayload.jobID)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "pause_schedule_failed", message: error.localizedDescription)
            }
        case "resume_schedule":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The resume_schedule request requires a payload.") }
                let opPayload = try payload.decode(ScheduleOperationPayload.self)
                let result = try scheduleRegistry.resume(workspacePath: opPayload.workspacePath, jobID: opPayload.jobID)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "resume_schedule_failed", message: error.localizedDescription)
            }
        case "trigger_schedule":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The trigger_schedule request requires a payload.") }
                let opPayload = try payload.decode(ScheduleOperationPayload.self)
                let result = try scheduleRegistry.trigger(workspacePath: opPayload.workspacePath, jobID: opPayload.jobID)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "trigger_schedule_failed", message: error.localizedDescription)
            }
        case "list_profiles":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The list_profiles request requires a payload.") }
                let listPayload = try payload.decode(ListProfilesPayload.self)
                let result = try profileRegistry.list(workspacePath: listPayload.workspacePath)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "list_profiles_failed", message: error.localizedDescription)
            }
        case "create_profile":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The create_profile request requires a payload.") }
                let createPayload = try payload.decode(CreateProfilePayload.self)
                let result = try profileRegistry.create(workspacePath: createPayload.workspacePath, name: createPayload.name, provider: createPayload.provider, model: createPayload.model, baseUrl: createPayload.baseUrl, createEnv: createPayload.createEnv, createSoul: createPayload.createSoul, cloneSkills: createPayload.cloneSkills)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "create_profile_failed", message: error.localizedDescription)
            }
        case "edit_profile":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The edit_profile request requires a payload.") }
                let editPayload = try payload.decode(EditProfilePayload.self)
                let result = try profileRegistry.edit(workspacePath: editPayload.workspacePath, originalName: editPayload.originalName, name: editPayload.name, provider: editPayload.provider, model: editPayload.model, baseUrl: editPayload.baseUrl, createEnv: editPayload.createEnv, createSoul: editPayload.createSoul)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "edit_profile_failed", message: error.localizedDescription)
            }
        case "delete_profile":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The delete_profile request requires a payload.") }
                let opPayload = try payload.decode(ProfileOperationPayload.self)
                let result = try profileRegistry.remove(workspacePath: opPayload.workspacePath, name: opPayload.name)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "delete_profile_failed", message: error.localizedDescription)
            }
        case "set_active_profile":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The set_active_profile request requires a payload.") }
                let opPayload = try payload.decode(ProfileOperationPayload.self)
                let result = try profileRegistry.activate(workspacePath: opPayload.workspacePath, name: opPayload.name)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "set_active_profile_failed", message: error.localizedDescription)
            }
        case "get_gateway_config":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The get_gateway_config request requires a payload.") }
                let gatewayPayload = try payload.decode(GatewayConfigPayload.self)
                let result = try gatewayRegistry.config(workspacePath: gatewayPayload.workspacePath, profileName: gatewayPayload.profileName)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "get_gateway_config_failed", message: error.localizedDescription)
            }
        case "gateway_status":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The gateway_status request requires a payload.") }
                let gatewayPayload = try payload.decode(GatewayStatusPayload.self)
                let result = gatewayRegistry.gatewayStatus(workspacePath: gatewayPayload.workspacePath, profileName: gatewayPayload.profileName)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "gateway_status_failed", message: error.localizedDescription)
            }
        case "set_gateway_running":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The set_gateway_running request requires a payload.") }
                let gatewayPayload = try payload.decode(SetGatewayRunningPayload.self)
                let result = try gatewayRegistry.setGatewayRunning(workspacePath: gatewayPayload.workspacePath, profileName: gatewayPayload.profileName, running: gatewayPayload.running)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "set_gateway_running_failed", message: error.localizedDescription)
            }
        case "restart_gateway":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The restart_gateway request requires a payload.") }
                let gatewayPayload = try payload.decode(RestartGatewayPayload.self)
                let result = try gatewayRegistry.restartGateway(workspacePath: gatewayPayload.workspacePath, profileName: gatewayPayload.profileName)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "restart_gateway_failed", message: error.localizedDescription)
            }
        case "set_gateway_env":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The set_gateway_env request requires a payload.") }
                let gatewayPayload = try payload.decode(SetGatewayEnvPayload.self)
                let result = try gatewayRegistry.setEnv(workspacePath: gatewayPayload.workspacePath, profileName: gatewayPayload.profileName, key: gatewayPayload.key, value: gatewayPayload.value)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "set_gateway_env_failed", message: error.localizedDescription)
            }
        case "set_gateway_platform":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The set_gateway_platform request requires a payload.") }
                let gatewayPayload = try payload.decode(SetGatewayPlatformPayload.self)
                let result = try gatewayRegistry.setPlatformEnabled(workspacePath: gatewayPayload.workspacePath, profileName: gatewayPayload.profileName, platform: gatewayPayload.platform, enabled: gatewayPayload.enabled)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "set_gateway_platform_failed", message: error.localizedDescription)
            }
        default:
            return .error(
                id: request.id,
                code: "unsupported_operation",
                message: "Operation '\(request.type)' is not implemented in the minimal V1 server skeleton."
            )
        }
    }
}

final class CompanionAuthenticationTokenStore {
    static let shared = CompanionAuthenticationTokenStore()
    static let apiKeyLength = 256

    private let defaults = UserDefaults.standard
    private let tokenKey = "companion.authentication.token"
    private let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")

    private init() {}

    var token: String {
        let existing = defaults.string(forKey: tokenKey) ?? ""
        guard existing.count == Self.apiKeyLength else {
            return regenerateToken()
        }
        return existing
    }

    @discardableResult
    func regenerateToken() -> String {
        var randomBytes = [UInt8](repeating: 0, count: Self.apiKeyLength)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if status != errSecSuccess {
            randomBytes = (0..<Self.apiKeyLength).map { _ in UInt8.random(in: 0...255) }
        }
        let token = String(randomBytes.map { alphabet[Int($0) % alphabet.count] })
        defaults.set(token, forKey: tokenKey)
        return token
    }
}

private extension Logger {
    static let companion = Logger(subsystem: "fr.dubertrand.HermesHostCompanion", category: "CompanionServer")
}
