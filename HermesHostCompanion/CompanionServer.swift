//
//  CompanionServer.swift
//  HermesHostCompanion
//
//  Created by Codex on 05/05/2026.
//

import Foundation
import Network
import Observation
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
    private let configuration = CompanionServerConfiguration.default

    func start() async throws {
        stop()
        state = .starting
        lastErrorMessage = ""

        let identity = try CompanionTLSIdentityStore.shared.loadServerIdentity()
        let parameters = try CompanionServerParametersFactory.makeParameters(
            identity: identity,
            allowedClientCA: identity.caCertificate
        )

        let listener = try NWListener(using: parameters, on: configuration.port)
        let logger = Logger.companion

        listener.stateUpdateHandler = { [weak self] newState in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch newState {
                case .ready:
                    self.state = .running
                    self.listenerDescription = "wss://\(self.configuration.host):\(self.configuration.port.rawValue)/ws"
                    logger.info("Companion server ready on port \(self.configuration.port.rawValue)")
                case .failed(let error):
                    self.state = .failed
                    self.lastErrorMessage = error.localizedDescription
                    self.listenerDescription = "Listener failed"
                    logger.error("Companion server failed: \(error.localizedDescription, privacy: .public)")
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

    static let `default` = CompanionServerConfiguration(host: "localhost", port: 9443)
}

private enum CompanionServerParametersFactory {
    static func makeParameters(identity: CompanionServerIdentity, allowedClientCA: SecCertificate) throws -> NWParameters {
        let tlsOptions = NWProtocolTLS.Options()
        let secOptions = tlsOptions.securityProtocolOptions

        sec_protocol_options_set_min_tls_protocol_version(secOptions, .TLSv12)

        let identityRef = try identity.secIdentity.asSecIdentityRef()
        sec_protocol_options_set_local_identity(secOptions, identityRef)

        let caRef = allowedClientCA.asSecCertificateRef()
        sec_protocol_options_set_verify_block(secOptions, { metadata, trust, completion in
            let secTrust = sec_trust_copy_ref(trust).takeRetainedValue()
            SecTrustSetAnchorCertificates(secTrust, [caRef] as CFArray)
            SecTrustSetAnchorCertificatesOnly(secTrust, true)

            var error: CFError?
            let isTrusted = SecTrustEvaluateWithError(secTrust, &error)
            completion(isTrusted)
        }, DispatchQueue.global(qos: .userInitiated))

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

@MainActor
final class CompanionClientSession {
    let id = UUID()
    var onStop: ((UUID) -> Void)?

    private let connection: NWConnection
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

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
                payload: .hello(
                    protocolVersion: "1",
                    serverName: "HermesHostCompanion",
                    capabilities: [
                        "list_targets",
                        "read_target",
                        "validate_target",
                        "write_target",
                        "list_backups",
                        "restore_backup",
                        "service_status",
                        "service_restart"
                    ]
                )
            )
        default:
            return .error(
                id: request.id,
                code: "unsupported_operation",
                message: "Operation '\(request.type)' is not implemented in the minimal V1 server skeleton."
            )
        }
    }
}

private struct CompanionIncomingEnvelope: Codable {
    let id: String?
    let type: String
    let payload: [String: String]?
}

private struct CompanionOutgoingEnvelope: Codable {
    let id: String?
    let ok: Bool
    let payload: CompanionPayload?
    let error: CompanionErrorPayload?

    static func success(id: String?, payload: CompanionPayload) -> CompanionOutgoingEnvelope {
        CompanionOutgoingEnvelope(id: id, ok: true, payload: payload, error: nil)
    }

    static func error(id: String?, code: String, message: String) -> CompanionOutgoingEnvelope {
        CompanionOutgoingEnvelope(
            id: id,
            ok: false,
            payload: nil,
            error: CompanionErrorPayload(code: code, message: message)
        )
    }
}

private enum CompanionPayload: Codable {
    case hello(protocolVersion: String, serverName: String, capabilities: [String])

    private enum CodingKeys: String, CodingKey {
        case kind
        case protocolVersion
        case serverName
        case capabilities
    }

    private enum Kind: String, Codable {
        case hello
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .hello(let protocolVersion, let serverName, let capabilities):
            try container.encode(Kind.hello, forKey: .kind)
            try container.encode(protocolVersion, forKey: .protocolVersion)
            try container.encode(serverName, forKey: .serverName)
            try container.encode(capabilities, forKey: .capabilities)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .hello:
            self = .hello(
                protocolVersion: try container.decode(String.self, forKey: .protocolVersion),
                serverName: try container.decode(String.self, forKey: .serverName),
                capabilities: try container.decode([String].self, forKey: .capabilities)
            )
        }
    }
}

private struct CompanionErrorPayload: Codable {
    let code: String
    let message: String
}

private extension Logger {
    static let companion = Logger(subsystem: "fr.dubertrand.HermesHostCompanion", category: "CompanionServer")
}
