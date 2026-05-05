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
    private(set) var enrollmentListenerDescription = "Not listening"
    var lastErrorMessage = ""

    private var listener: NWListener?
    private var enrollmentListener: NWListener?
    private var sessions: [UUID: CompanionClientSession] = [:]
    private var enrollmentSessions: [UUID: CompanionEnrollmentSession] = [:]
    private var configuration = CompanionServerConfigurationStore.load()

    var currentConfiguration: CompanionServerConfiguration {
        configuration
    }

    func updateConfiguration(_ configuration: CompanionServerConfiguration) {
        self.configuration = configuration
        CompanionServerConfigurationStore.save(configuration)

        if state == .running {
            listenerDescription = "wss://\(configuration.host):\(configuration.port.rawValue)/ws"
            enrollmentListenerDescription = "wss://\(configuration.host):\(configuration.enrollmentPort.rawValue)/enroll"
        }
    }

    func start() async throws {
        stop()
        state = .starting
        lastErrorMessage = ""

        let identity = try CompanionTLSIdentityStore.shared.loadServerIdentity(host: configuration.host)
        let parameters = try CompanionServerParametersFactory.makeAuthenticatedParameters(
            identity: identity,
            allowedClientCA: identity.caCertificate,
            authenticationStore: CompanionAuthenticationStore.shared
        )
        let enrollmentParameters = try CompanionServerParametersFactory.makeEnrollmentParameters(identity: identity)

        parameters.requiredLocalEndpoint = .hostPort(
            host: NWEndpoint.Host(configuration.host),
            port: configuration.port
        )
        enrollmentParameters.requiredLocalEndpoint = .hostPort(
            host: NWEndpoint.Host(configuration.host),
            port: configuration.enrollmentPort
        )

        let listener = try NWListener(using: parameters, on: configuration.port)
        let enrollmentListener = try NWListener(using: enrollmentParameters, on: configuration.enrollmentPort)
        let logger = Logger.companion

        listener.stateUpdateHandler = { [weak self] newState in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch newState {
                case .ready:
                    self.state = .running
                    self.listenerDescription = "wss://\(self.configuration.host):\(self.configuration.port.rawValue)/ws"
                    self.enrollmentListenerDescription = "wss://\(self.configuration.host):\(self.configuration.enrollmentPort.rawValue)/enroll"
                    logger.info("Companion API server ready on port \(self.configuration.port.rawValue)")
                case .failed(let error):
                    self.state = .failed
                    self.lastErrorMessage = "API listener failed on port \(self.configuration.port.rawValue): \(error.localizedDescription)"
                    self.listenerDescription = "API listener failed"
                    logger.error("Companion API server failed: \(error.localizedDescription, privacy: .public)")
                case .cancelled:
                    self.state = .stopped
                    self.listenerDescription = "Not listening"
                    self.enrollmentListenerDescription = "Not listening"
                default:
                    break
                }
            }
        }

        enrollmentListener.stateUpdateHandler = { [weak self] newState in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch newState {
                case .ready:
                    self.enrollmentListenerDescription = "wss://\(self.configuration.host):\(self.configuration.enrollmentPort.rawValue)/enroll"
                    logger.info("Companion enrollment server ready on port \(self.configuration.enrollmentPort.rawValue)")
                case .failed(let error):
                    self.state = .failed
                    self.lastErrorMessage = "Enrollment listener failed on port \(self.configuration.enrollmentPort.rawValue): \(error.localizedDescription)"
                    self.enrollmentListenerDescription = "Enrollment listener failed"
                    logger.error("Companion enrollment server failed: \(error.localizedDescription, privacy: .public)")
                case .cancelled:
                    self.enrollmentListenerDescription = "Not listening"
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

        enrollmentListener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor [weak self] in
                self?.acceptEnrollment(connection: connection)
            }
        }

        listener.start(queue: .main)
        enrollmentListener.start(queue: .main)
        self.listener = listener
        self.enrollmentListener = enrollmentListener
    }

    func stop() {
        sessions.values.forEach { $0.stop() }
        enrollmentSessions.values.forEach { $0.stop() }
        sessions.removeAll()
        enrollmentSessions.removeAll()
        listener?.cancel()
        enrollmentListener?.cancel()
        listener = nil
        enrollmentListener = nil
        state = .stopped
        listenerDescription = "Not listening"
        enrollmentListenerDescription = "Not listening"
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

    private func acceptEnrollment(connection: NWConnection) {
        let session = CompanionEnrollmentSession(connection: connection, configuration: configuration)
        enrollmentSessions[session.id] = session
        session.onStop = { [weak self] sessionID in
            Task { @MainActor [weak self] in
                self?.enrollmentSessions.removeValue(forKey: sessionID)
            }
        }
        session.start()
    }
}

struct CompanionServerConfiguration {
    let host: String
    let port: NWEndpoint.Port
    let enrollmentPort: NWEndpoint.Port

    static let `default` = CompanionServerConfiguration(host: "localhost", port: 9112, enrollmentPort: 9113)
}

private enum CompanionServerConfigurationStore {
    private static let hostKey = "companion.server.host"
    private static let portKey = "companion.server.port"
    private static let enrollmentPortKey = "companion.server.enrollmentPort"

    static func load() -> CompanionServerConfiguration {
        let defaults = UserDefaults.standard
        let host = defaults.string(forKey: hostKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let portValue = defaults.integer(forKey: portKey)
        let enrollmentPortValue = defaults.integer(forKey: enrollmentPortKey)

        let hostValue = (host?.isEmpty == false ? host! : CompanionServerConfiguration.default.host)
        let port = validPort(from: portValue) ?? CompanionServerConfiguration.default.port
        let enrollmentPort = validPort(from: enrollmentPortValue) ?? CompanionServerConfiguration.default.enrollmentPort

        return CompanionServerConfiguration(host: hostValue, port: port, enrollmentPort: enrollmentPort)
    }

    static func save(_ configuration: CompanionServerConfiguration) {
        let defaults = UserDefaults.standard
        defaults.set(configuration.host, forKey: hostKey)
        defaults.set(Int(configuration.port.rawValue), forKey: portKey)
        defaults.set(Int(configuration.enrollmentPort.rawValue), forKey: enrollmentPortKey)
    }

    private static func validPort(from value: Int) -> NWEndpoint.Port? {
        guard value > 0, value < 65536 else { return nil }
        return NWEndpoint.Port(rawValue: UInt16(value))
    }
}

private enum CompanionServerParametersFactory {
    static func makeAuthenticatedParameters(
        identity: CompanionServerIdentity,
        allowedClientCA: SecCertificate,
        authenticationStore: CompanionAuthenticationStore
    ) throws -> NWParameters {
        let tlsOptions = NWProtocolTLS.Options()
        let secOptions = tlsOptions.securityProtocolOptions

        sec_protocol_options_set_min_tls_protocol_version(secOptions, .TLSv12)

        guard let identityRef = identity.secIdentity.asSecIdentityRef() else {
            throw CompanionTLSIdentityStoreError.serverIdentityUnavailable
        }
        sec_protocol_options_set_local_identity(secOptions, identityRef)

        guard let caRef = allowedClientCA.asSecCertificateRef() else {
            throw CompanionTLSIdentityStoreError.certificateUnavailable
        }
        sec_protocol_options_set_verify_block(secOptions, { metadata, trust, completion in
            let secTrust = sec_trust_copy_ref(trust).takeRetainedValue()
            SecTrustSetAnchorCertificates(secTrust, [caRef] as CFArray)
            SecTrustSetAnchorCertificatesOnly(secTrust, true)

            var error: CFError?
            let isTrusted = SecTrustEvaluateWithError(secTrust, &error)
            guard isTrusted else {
                completion(false)
                return
            }

            do {
                _ = try authenticationStore.authorizeClientTrust(secTrust)
                completion(true)
            } catch {
                completion(false)
            }
        }, DispatchQueue.global(qos: .userInitiated))

        return makeBaseParameters(tlsOptions: tlsOptions)
    }

    static func makeEnrollmentParameters(identity: CompanionServerIdentity) throws -> NWParameters {
        let tlsOptions = NWProtocolTLS.Options()
        let secOptions = tlsOptions.securityProtocolOptions

        sec_protocol_options_set_min_tls_protocol_version(secOptions, .TLSv12)
        guard let identityRef = identity.secIdentity.asSecIdentityRef() else {
            throw CompanionTLSIdentityStoreError.serverIdentityUnavailable
        }
        sec_protocol_options_set_local_identity(secOptions, identityRef)
        return makeBaseParameters(tlsOptions: tlsOptions)
    }

    private static func makeBaseParameters(tlsOptions: NWProtocolTLS.Options) -> NWParameters {
        let tcpOptions = NWProtocolTCP.Options()
        let parameters = NWParameters(tls: tlsOptions, tcp: tcpOptions)
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

    init(connection: NWConnection) {
        self.connection = connection
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
                let response = self.route(request: request)
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
                        "service_status",
                        "service_restart",
                        "list_skills",
                        "set_skill_state",
                        "list_toolsets",
                        "set_toolset_enabled",
                        "list_models",
                        "add_model",
                        "update_model",
                        "remove_model"
                    ]
                )
            )
        case "list_targets":
            return .success(
                id: request.id,
                payload: ListTargetsResult(targets: registry.listTargets())
            )
        case "read_target":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The read_target request requires a payload.")
                }
                let readPayload = try payload.decode(ReadTargetPayload.self)
                let result = try registry.readTarget(id: readPayload.targetID)
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
                    proposedContent: validatePayload.content
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
                    createBackup: writePayload.createBackup
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
        default:
            return .error(
                id: request.id,
                code: "unsupported_operation",
                message: "Operation '\(request.type)' is not implemented in the minimal V1 server skeleton."
            )
        }
    }
}

final class CompanionEnrollmentSession {
    let id = UUID()
    var onStop: ((UUID) -> Void)?

    private let connection: NWConnection
    private let configuration: CompanionServerConfiguration
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(connection: NWConnection, configuration: CompanionServerConfiguration) {
        self.connection = connection
        self.configuration = configuration
    }

    func start() {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                Logger.companion.info("Accepted enrollment session \(self.id.uuidString, privacy: .public)")
                self.receiveNextMessage()
            case .failed(let error):
                Logger.companion.error("Enrollment session \(self.id.uuidString, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
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
        connection.receiveMessage { [weak self] data, _, _, error in
            guard let self else { return }
            if let error {
                Logger.companion.error("Enrollment receive error for session \(self.id.uuidString, privacy: .public): \(error.localizedDescription, privacy: .public)")
                self.stop()
                return
            }

            guard let data, data.isEmpty == false else {
                self.receiveNextMessage()
                return
            }

            do {
                let request = try self.decoder.decode(CompanionIncomingEnvelope.self, from: data)
                let response = self.route(request: request)
                let responseData = try self.encoder.encode(response)
                self.send(responseData)
            } catch {
                let response = CompanionOutgoingEnvelope.error(
                    id: nil,
                    code: "invalid_request",
                    message: error.localizedDescription
                )
                if let encoded = try? self.encoder.encode(response) {
                    self.send(encoded)
                }
            }

            self.receiveNextMessage()
        }
    }

    private func send(_ data: Data) {
        let metadata = NWProtocolWebSocket.Metadata(opcode: .binary)
        let context = NWConnection.ContentContext(identifier: "enrollment-response", metadata: [metadata])
        connection.send(content: data, contentContext: context, isComplete: true, completion: .idempotent)
    }

    private func route(request: CompanionIncomingEnvelope) -> CompanionOutgoingEnvelope {
        switch request.type {
        case "hello":
            return .success(
                id: request.id,
                payload: EnrollmentHelloResult(
                    protocolVersion: "1",
                    serverName: "HermesHostCompanionEnrollment",
                    capabilities: ["hello", "enroll_client"],
                    requiresPairingCode: true
                )
            )
        case "enroll_client":
            do {
                guard let payload = request.payload else {
                    return .error(id: request.id, code: "missing_payload", message: "The enroll_client request requires a payload.")
                }
                let enrollPayload = try payload.decode(EnrollClientPayload.self)
                let signedIdentity = try CompanionTLSIdentityStore.shared.createSignedClientIdentity(
                    commonName: enrollPayload.deviceName
                )
                let enrolledDevice = try CompanionAuthenticationStore.shared.enrollDevice(
                    pairingID: enrollPayload.pairingID,
                    pairingSecret: enrollPayload.pairingSecret,
                    deviceName: enrollPayload.deviceName,
                    clientCertificatePEM: signedIdentity.certificatePEM
                )
                let serverIdentity = try CompanionTLSIdentityStore.shared.loadServerIdentity(host: configuration.host)
                return .success(
                    id: request.id,
                    payload: EnrollClientResult(
                        deviceID: enrolledDevice.id,
                        deviceName: enrolledDevice.commonName,
                        clientIdentityPKCS12Base64: signedIdentity.identityPKCS12Base64,
                        clientIdentityPassword: signedIdentity.identityPassword,
                        caCertificatePEM: signedIdentity.caCertificatePEM,
                        serverEndpoint: "wss://\(configuration.host):\(configuration.port.rawValue)/ws",
                        serverCertificateFingerprint: serverIdentity.serverCertificateFingerprint
                    )
                )
            } catch {
                return .error(id: request.id, code: "enroll_client_failed", message: error.localizedDescription)
            }
        default:
            return .error(
                id: request.id,
                code: "unsupported_operation",
                message: "Operation '\(request.type)' is not available on the enrollment listener."
            )
        }
    }
}

private extension Logger {
    static let companion = Logger(subsystem: "fr.dubertrand.HermesHostCompanion", category: "CompanionServer")
}
