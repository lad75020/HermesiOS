//
//  CompanionServer.swift
//  HermesHostCompanion
//
//  Created by Codex on 05/05/2026.
//

import CryptoKit
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
            listenerDescription = configuration.webSocketURLString
        }
    }

    func start() async throws {
        let hadListener = listener != nil
        stop()
        if hadListener {
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
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

        let listener: NWListener
        do {
            listener = try NWListener(using: parameters)
        } catch {
            state = .failed
            lastErrorMessage = "API listener failed on port \(configuration.port.rawValue): \(error.localizedDescription)"
            listenerDescription = "API listener failed"
            Logger.companion.error("Companion API server failed before listen: \(error.localizedDescription, privacy: .public)")
            throw error
        }
        let logger = Logger.companion

        listener.stateUpdateHandler = { [weak self] newState in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch newState {
                case .ready:
                    self.state = .running
                    self.listenerDescription = self.configuration.webSocketURLString
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
        let session = CompanionClientSession(connection: connection)
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

    var webSocketURLString: String {
        "\(advertisedWebSocketScheme)://\(Self.urlHostLiteral(host)):\(port.rawValue)/ws"
    }

    var advertisedWebSocketScheme: String {
        Self.isPlaintextWebSocketHost(host) ? "ws" : "wss"
    }

    static let `default` = CompanionServerConfiguration(host: "localhost", port: 9112)

    static func sanitizedHost(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return Self.default.host }

        if let components = URLComponents(string: trimmed), components.scheme != nil, let host = components.host, host.isEmpty == false {
            return host
        }

        let withoutPath: String
        if let slashIndex = trimmed.firstIndex(of: "/") {
            withoutPath = String(trimmed[..<slashIndex])
        } else {
            withoutPath = trimmed
        }

        if withoutPath.hasPrefix("[") == false,
           withoutPath.filter({ $0 == ":" }).count == 1,
           let colonIndex = withoutPath.lastIndex(of: ":") {
            return String(withoutPath[..<colonIndex])
        }

        return withoutPath.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
    }

    static func port(from rawValue: String, fallback: NWEndpoint.Port) -> NWEndpoint.Port {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if let components = URLComponents(string: trimmed), let port = components.port {
            return NWEndpoint.Port(rawValue: UInt16(port)) ?? fallback
        }
        if trimmed.hasPrefix("[") == false,
           trimmed.filter({ $0 == ":" }).count == 1,
           let colonIndex = trimmed.lastIndex(of: ":") {
            let suffix = trimmed[trimmed.index(after: colonIndex)...]
            if let value = UInt16(suffix) { return NWEndpoint.Port(rawValue: value) ?? fallback }
        }
        if let value = UInt16(trimmed) { return NWEndpoint.Port(rawValue: value) ?? fallback }
        return fallback
    }

    static func isLoopbackHost(_ host: String) -> Bool {
        let normalized = sanitizedHost(host).lowercased()
        return normalized == "localhost" || normalized == "::1" || normalized == "0:0:0:0:0:0:0:1" || normalized.hasPrefix("127.")
    }

    static func isTailnetHost(_ host: String) -> Bool {
        let normalized = sanitizedHost(host).lowercased()
        if normalized.hasSuffix(".ts.net") { return true }
        if normalized.hasPrefix("fd7a:115c:a1e0:") { return true }
        let pieces = normalized.split(separator: ".")
        guard pieces.count == 4,
              let first = UInt8(pieces[0]),
              let second = UInt8(pieces[1]) else { return false }
        return first == 100 && (64...127).contains(second)
    }

    static func isPlaintextWebSocketHost(_ host: String) -> Bool {
        isLoopbackHost(host) || isTailnetHost(host)
    }

    private static func urlHostLiteral(_ host: String) -> String {
        let sanitized = sanitizedHost(host)
        if sanitized.contains(":"), sanitized.hasPrefix("[") == false, sanitized.hasSuffix("]") == false {
            return "[\(sanitized)]"
        }
        return sanitized
    }
}

private enum CompanionServerConfigurationStore {
    private static let hostKey = "companion.server.host"
    private static let portKey = "companion.server.port"

    static func load() -> CompanionServerConfiguration {
        let defaults = UserDefaults.standard
        let host = defaults.string(forKey: hostKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let portValue = defaults.integer(forKey: portKey)

        let hostValue = CompanionServerConfiguration.sanitizedHost(host ?? CompanionServerConfiguration.default.host)
        let port = validPort(from: portValue) ?? CompanionServerConfiguration.default.port

        return CompanionServerConfiguration(host: hostValue, port: port)
    }

    static func save(_ configuration: CompanionServerConfiguration) {
        let defaults = UserDefaults.standard
        defaults.set(CompanionServerConfiguration.sanitizedHost(configuration.host), forKey: hostKey)
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


@MainActor
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

    init(connection: NWConnection) {
        self.connection = connection
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
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
            Task { @MainActor in
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
                if CompanionDeviceAuthorizationStore.isUnauthenticatedOperation(request.type) {
                    response = await self.route(request: request)
                } else if CompanionDeviceAuthorizationStore.shared.authenticate(deviceID: request.deviceID, deviceSecret: request.deviceSecret) {
                    response = await self.route(request: request)
                } else {
                    response = .error(id: request.id, code: "device_not_approved", message: "This iOS device is not approved by HermesHostCompanion.")
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
    }

    private func send(_ data: Data) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
        let context = NWConnection.ContentContext(identifier: "ws-response", metadata: [metadata])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
    }

    private func route(request: CompanionIncomingEnvelope) async -> CompanionOutgoingEnvelope {
        switch request.type {
        case "enroll_device":
            do {
                guard let requestPayload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The enroll_device request requires a payload.") }
                let payload = try requestPayload.decode(CompanionEnrollDevicePayload.self)
                Logger.companion.info("Received device enrollment request for \(payload.deviceName, privacy: .public)")
                let result = try CompanionDeviceAuthorizationStore.shared.enrollDevice(payload, endpoint: CompanionServerConfigurationStore.load().webSocketURLString)
                Logger.companion.info("Created pending device enrollment \(result.deviceID, privacy: .public)")
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "enroll_device_failed", message: error.localizedDescription)
            }
        case "check_device_approval":
            do {
                guard let requestPayload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The check_device_approval request requires a payload.") }
                let payload = try requestPayload.decode(CompanionCheckDeviceApprovalPayload.self)
                let result = try CompanionDeviceAuthorizationStore.shared.checkApproval(payload)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "check_device_approval_failed", message: error.localizedDescription)
            }
        case "hello":
            return .success(
                id: request.id,
                payload: HelloResult(
                    protocolVersion: "1",
                    serverName: "HermesHostCompanion",
                    capabilities: [
                        "hello",
                        "enroll_device",
                        "check_device_approval",
                        "device_authorization",
                        "list_targets",
                        "read_target",
                        "validate_target",
                        "write_target",
                        "list_backups",
                        "restore_backup",
                        "download_file",
                        "browse_files",
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
                        "list_skills",
                        "set_skill_state",
                        "list_mcp_servers",
                        "add_mcp_server",
                        "remove_mcp_server",
                        "set_mcp_server_enabled",
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
                        "edit_schedule",
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
        case "browse_files":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The browse_files request requires a payload.")
                }
                let browserPayload = try payload.decode(FileBrowserPayload.self)
                let result = try fileDownloadRegistry.listDirectory(path: browserPayload.path, workspacePath: browserPayload.workspacePath, requester: id.uuidString)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "browse_files_failed", message: error.localizedDescription)
            }
        case "download_file":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The download_file request requires a payload.")
                }
                let downloadPayload = try payload.decode(FileDownloadPayload.self)
                let result = try fileDownloadRegistry.downloadFile(path: downloadPayload.path, workspacePath: downloadPayload.workspacePath, requester: id.uuidString)
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
                let result = try fileDownloadRegistry.downloadFileInfo(path: downloadPayload.path, workspacePath: downloadPayload.workspacePath, requester: id.uuidString)
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
                    length: chunkPayload.length,
                    workspacePath: chunkPayload.workspacePath,
                    requester: id.uuidString
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
                let listPayload = try payload.decode(ListMCPServersPayload.self)
                let result = try await registry.listHermesSkills(workspacePath: listPayload.workspacePath)
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
                let result = try await registry.setHermesSkillState(
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
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The list_mcp_servers request requires a payload.") }
                let listPayload = try payload.decode(ListHermesSkillsPayload.self)
                return .success(id: request.id, payload: try await mcpRegistry.listServers(workspacePath: listPayload.workspacePath))
            } catch {
                return .error(id: request.id, code: "list_mcp_servers_failed", message: error.localizedDescription)
            }
        case "add_mcp_server":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The add_mcp_server request requires a payload.")
                }
                let addPayload = try payload.decode(AddMCPServerPayload.self)
                return .success(id: request.id, payload: try await mcpRegistry.addServer(addPayload))
            } catch {
                return .error(id: request.id, code: "add_mcp_server_failed", message: error.localizedDescription)
            }
        case "remove_mcp_server":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The remove_mcp_server request requires a payload.")
                }
                let removePayload = try payload.decode(RemoveMCPServerPayload.self)
                return .success(id: request.id, payload: try await mcpRegistry.removeServer(workspacePath: removePayload.workspacePath, name: removePayload.name))
            } catch {
                return .error(id: request.id, code: "remove_mcp_server_failed", message: error.localizedDescription)
            }
        case "set_mcp_server_enabled":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The set_mcp_server_enabled request requires a payload.") }
                return .success(id: request.id, payload: try await mcpRegistry.setServerEnabled(try payload.decode(SetMCPServerEnabledPayload.self)))
            } catch {
                return .error(id: request.id, code: "set_mcp_server_enabled_failed", message: error.localizedDescription)
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
                    model: slotPayload.model,
                    baseUrl: slotPayload.baseUrl
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
                let result = try scheduleRegistry.create(workspacePath: createPayload.workspacePath, schedule: createPayload.schedule, prompt: createPayload.prompt, name: createPayload.name, deliver: createPayload.deliver, provider: createPayload.provider, model: createPayload.model, baseUrl: createPayload.baseUrl)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "create_schedule_failed", message: error.localizedDescription)
            }
        case "edit_schedule":
            do {
                guard let payload = request.payload else { return .error(id: request.id, code: "missing_payload", message: "The edit_schedule request requires a payload.") }
                let editPayload = try payload.decode(EditSchedulePayload.self)
                let result = try scheduleRegistry.edit(workspacePath: editPayload.workspacePath, jobID: editPayload.jobID, schedule: editPayload.schedule, prompt: editPayload.prompt, name: editPayload.name, deliver: editPayload.deliver, provider: editPayload.provider, model: editPayload.model, baseUrl: editPayload.baseUrl)
                return .success(id: request.id, payload: result)
            } catch {
                return .error(id: request.id, code: "edit_schedule_failed", message: error.localizedDescription)
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


struct CompanionAuthorizedDeviceRecord: Codable, Identifiable, Equatable {
    let id: String
    var deviceName: String
    var secretFingerprint: String
    var createdAt: Date
    var approvedAt: Date?
    var revokedAt: Date?
    var lastSeenAt: Date?

    var isApproved: Bool {
        approvedAt != nil && revokedAt == nil
    }

    var statusLabel: String {
        if revokedAt != nil { return "Revoked" }
        if approvedAt != nil { return "Approved" }
        return "Pending approval"
    }
}

final class CompanionDeviceAuthorizationStore {
    static let shared = CompanionDeviceAuthorizationStore()

    static let didChangeNotification = Notification.Name("CompanionDeviceAuthorizationStoreDidChange")

    private let defaults = UserDefaults.standard
    private let devicesKey = "companion.authorized.devices"
    private let onboardingCodeKey = "companion.onboarding.code"
    private let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")

    private init() {}

    var onboardingCode: String {
        let existing = defaults.string(forKey: onboardingCodeKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if existing.count >= 20 { return existing }
        return rotateOnboardingCode()
    }

    var devices: [CompanionAuthorizedDeviceRecord] {
        loadDevices().sorted { lhs, rhs in
            let lhsDate = lhs.lastSeenAt ?? lhs.approvedAt ?? lhs.createdAt
            let rhsDate = rhs.lastSeenAt ?? rhs.approvedAt ?? rhs.createdAt
            return lhsDate > rhsDate
        }
    }

    static func isUnauthenticatedOperation(_ type: String) -> Bool {
        type == "enroll_device" || type == "check_device_approval"
    }

    func qrPayload(endpoint: String, hermesConfigFolderPath: String, apiGatewayAPIKey: String) -> CompanionOnboardingPayload {
        CompanionOnboardingPayload(
            type: "hermes_companion_onboarding",
            version: 1,
            endpoint: endpoint,
            code: onboardingCode,
            serverName: "HermesHostCompanion",
            hermesConfigFolderPath: hermesConfigFolderPath,
            apiGatewayAPIKey: apiGatewayAPIKey
        )
    }

    @discardableResult
    func rotateOnboardingCode() -> String {
        let code = randomURLSafeString(length: 32)
        defaults.set(code, forKey: onboardingCodeKey)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        return code
    }

    func enrollDevice(_ payload: CompanionEnrollDevicePayload, endpoint: String) throws -> CompanionEnrollDeviceResult {
        guard payload.code == onboardingCode else {
            throw CompanionDeviceAuthorizationError.invalidOnboardingCode
        }
        let deviceID = UUID().uuidString
        let deviceSecret = randomURLSafeString(length: 64)
        let deviceName = payload.deviceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "HermesiOS Device" : payload.deviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        var devices = loadDevices()
        devices.append(
            CompanionAuthorizedDeviceRecord(
                id: deviceID,
                deviceName: deviceName,
                secretFingerprint: Self.fingerprint(for: deviceSecret),
                createdAt: Date(),
                approvedAt: nil,
                revokedAt: nil,
                lastSeenAt: nil
            )
        )
        saveDevices(devices)
        rotateOnboardingCode()
        return CompanionEnrollDeviceResult(
            deviceID: deviceID,
            deviceSecret: deviceSecret,
            deviceName: deviceName,
            serverEndpoint: endpoint,
            approved: false,
            message: "Device request received. Approve it in HermesHostCompanion."
        )
    }

    func checkApproval(_ payload: CompanionCheckDeviceApprovalPayload) throws -> CompanionCheckDeviceApprovalResult {
        guard let record = loadDevices().first(where: { $0.id == payload.deviceID && Self.securelyMatchesFingerprint(payload.deviceSecret, expectedFingerprint: $0.secretFingerprint) }) else {
            throw CompanionDeviceAuthorizationError.unknownDevice
        }
        return CompanionCheckDeviceApprovalResult(
            deviceID: record.id,
            approved: record.isApproved,
            revoked: record.revokedAt != nil,
            message: record.revokedAt != nil ? "Device access was revoked." : (record.isApproved ? "Device approved." : "Waiting for approval in HermesHostCompanion.")
        )
    }

    func authenticate(deviceID: String?, deviceSecret: String?) -> Bool {
        guard let deviceID, let deviceSecret else { return false }
        var devices = loadDevices()
        guard let index = devices.firstIndex(where: { $0.id == deviceID }) else { return false }
        guard devices[index].isApproved else { return false }
        guard Self.securelyMatchesFingerprint(deviceSecret, expectedFingerprint: devices[index].secretFingerprint) else { return false }
        devices[index].lastSeenAt = Date()
        saveDevices(devices)
        return true
    }

    func approveDevice(id: String) {
        mutateDevice(id: id) { record in
            record.approvedAt = Date()
            record.revokedAt = nil
        }
    }

    func revokeDevice(id: String) {
        mutateDevice(id: id) { record in
            record.revokedAt = Date()
        }
    }

    func forgetDevice(id: String) {
        saveDevices(loadDevices().filter { $0.id != id })
    }

    private func mutateDevice(id: String, mutate: (inout CompanionAuthorizedDeviceRecord) -> Void) {
        var devices = loadDevices()
        guard let index = devices.firstIndex(where: { $0.id == id }) else { return }
        mutate(&devices[index])
        saveDevices(devices)
    }

    private func loadDevices() -> [CompanionAuthorizedDeviceRecord] {
        guard let data = defaults.data(forKey: devicesKey),
              let devices = try? JSONDecoder().decode([CompanionAuthorizedDeviceRecord].self, from: data)
        else { return [] }
        return devices
    }

    private func saveDevices(_ devices: [CompanionAuthorizedDeviceRecord]) {
        if let data = try? JSONEncoder().encode(devices) {
            defaults.set(data, forKey: devicesKey)
            NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
        }
    }

    private func randomURLSafeString(length: Int) -> String {
        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if status != errSecSuccess {
            randomBytes = (0..<length).map { _ in UInt8.random(in: 0...255) }
        }
        return String(randomBytes.map { alphabet[Int($0) % alphabet.count] })
    }

    static func fingerprint(for secret: String) -> String {
        let digest = SHA256.hash(data: Data(secret.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func securelyMatchesFingerprint(_ candidateSecret: String?, expectedFingerprint: String) -> Bool {
        guard let candidateSecret else { return false }
        return securelyMatches(fingerprint(for: candidateSecret), expected: expectedFingerprint)
    }

    static func securelyMatches(_ candidate: String, expected: String) -> Bool {
        let candidateBytes = Array(candidate.utf8)
        let expectedBytes = Array(expected.utf8)
        var difference = candidateBytes.count ^ expectedBytes.count
        for index in 0..<max(candidateBytes.count, expectedBytes.count) {
            let lhs = index < candidateBytes.count ? candidateBytes[index] : 0
            let rhs = index < expectedBytes.count ? expectedBytes[index] : 0
            difference |= Int(lhs ^ rhs)
        }
        return difference == 0
    }
}

enum CompanionDeviceAuthorizationError: LocalizedError {
    case invalidOnboardingCode
    case unknownDevice

    var errorDescription: String? {
        switch self {
        case .invalidOnboardingCode:
            "The QR onboarding code is invalid or expired. Scan the current QR code from HermesHostCompanion."
        case .unknownDevice:
            "This device is unknown to HermesHostCompanion. Scan the QR code again."
        }
    }
}


private extension Logger {
    static let companion = Logger(subsystem: "fr.dubertrand.HermesHostCompanion", category: "CompanionServer")
}
