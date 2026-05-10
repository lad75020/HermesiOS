//
//  HermesTerminalView.swift
//  HermesiOS
//

import Crypto
import Foundation
import NIOCore
import NIOPosix
import NIOSSH
import SwiftTerm
import SwiftUI
import UIKit

struct HermesTerminalSettings: Codable, Equatable {
    var username: String = ""
    var port: String = "22"
    var hasPrivateKey: Bool = false
}

private struct HermesTerminalConnectionInfo: Equatable {
    let host: String
    let port: Int
    let username: String
    let privateKey: String
    let term: String = "xterm-256color"
    let environment: [String: String] = ["LANG": "en_US.UTF-8"]
}

private enum HermesTerminalError: LocalizedError {
    case unsupportedPrivateKey
    case invalidPrivateKey(String)
    case invalidChannelType

    var errorDescription: String? {
        switch self {
        case .unsupportedPrivateKey:
            return "Only unencrypted OpenSSH Ed25519 private keys are supported for terminal login."
        case .invalidPrivateKey(let reason):
            return "Invalid SSH private key: \(reason)"
        case .invalidChannelType:
            return "The SSH server returned an unexpected channel type."
        }
    }
}

struct HermesTerminalView: View {
    let host: String
    @Binding var terminalSettings: HermesTerminalSettings
    @State private var session = HermesTerminalSession()
    @State private var pasteRequestID = UUID()

    private let raspberryTunnelCommand = "socat TCP-LISTEN:15900,bind=100.90.128.88,reuseaddr,fork TCP:192.168.1.19:5900"

    private var trimmedHost: String { host.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedUsername: String { terminalSettings.username.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var port: Int { Int(terminalSettings.port.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 22 }
    private var canConnect: Bool { !trimmedHost.isEmpty && !trimmedUsername.isEmpty && terminalSettings.hasPrivateKey }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "terminal")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.igActionBlue)
                    .frame(width: 56, height: 56)
                    .accessibilityHidden(true)

                Text("Terminal")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.72)

                Button {
                    pasteRequestID = UUID()
                } label: {
                    Text("🍓")
                        .font(.system(size: 24))
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.borderedProminent)
                .tint(.igGradOrange)
                .disabled(!session.isConnected)
                .accessibilityLabel("Paste Raspberry VNC tunnel command")
                .help("Paste Raspberry VNC tunnel command")

                Toggle("Terminal connection", isOn: Binding(
                    get: { session.isConnectionRequested },
                    set: { isEnabled in
                        if isEnabled {
                            connect()
                        } else {
                            session.disconnect()
                        }
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(.igOnlineGreen)
                .disabled((!canConnect && !session.isConnectionRequested) || session.isConnecting)
                .accessibilityLabel("Terminal connection")

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.top)

            if !session.lastErrorMessage.isEmpty {
                Text(session.lastErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.igDestructive)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }

            HermesSwiftTermContainer(
                connectionInfo: session.connectionInfo,
                terminalID: session.terminalID,
                pasteRequestID: pasteRequestID,
                pasteText: raspberryTunnelCommand,
                onConnected: session.markConnected,
                onFailed: session.markFailed
            )
                .background(Color.black)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
                .padding(.horizontal)
                .padding(.bottom)
        }
        .background(HermesLiquidGlassCanvas().ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private func connect() {
        Task { @MainActor in
            session.status = "Unlocking key…"
            session.lastErrorMessage = ""
            do {
                let privateKey = try HermesSettingsPersistence.loadTerminalPrivateKeyWithBiometrics(
                    reason: "Authenticate to connect the Terminal tab to your Mac over SSH."
                )
                let info = HermesTerminalConnectionInfo(
                    host: trimmedHost,
                    port: port,
                    username: trimmedUsername,
                    privateKey: privateKey
                )
                session.connect(info)
            } catch {
                session.isConnectionRequested = false
                session.status = "Key locked"
                session.lastErrorMessage = error.localizedDescription
            }
        }
    }
}

@Observable
private final class HermesTerminalSession {
    var connectionInfo: HermesTerminalConnectionInfo?
    var terminalID = UUID()
    var status = "Disconnected"
    var lastErrorMessage = ""
    var isConnecting = false
    var isConnected = false
    var isConnectionRequested = false

    func connect(_ info: HermesTerminalConnectionInfo) {
        isConnectionRequested = true
        isConnecting = true
        isConnected = false
        status = "Connecting…"
        lastErrorMessage = ""
        connectionInfo = info
        terminalID = UUID()
    }

    func markConnected() {
        isConnecting = false
        isConnected = true
        status = "Connected"
    }

    func markDisconnected(_ message: String = "Disconnected") {
        isConnecting = false
        isConnected = false
        isConnectionRequested = false
        status = message
    }

    func markFailed(_ message: String) {
        isConnecting = false
        isConnected = false
        isConnectionRequested = false
        status = "Failed"
        lastErrorMessage = message
    }

    func disconnect() {
        connectionInfo = nil
        terminalID = UUID()
        markDisconnected()
    }
}

private struct HermesSwiftTermContainer: UIViewRepresentable {
    let connectionInfo: HermesTerminalConnectionInfo?
    let terminalID: UUID
    let pasteRequestID: UUID
    let pasteText: String
    let onConnected: () -> Void
    let onFailed: (String) -> Void

    func makeUIView(context: Context) -> HermesSshTerminalView {
        let view = HermesSshTerminalView(frame: .zero)
        view.onConnected = onConnected
        view.onFailed = onFailed
        view.isOpaque = true
        view.backgroundColor = .black
        view.nativeBackgroundColor = .black
        view.contentInsetAdjustmentBehavior = .never
        return view
    }

    func updateUIView(_ uiView: HermesSshTerminalView, context: Context) {
        uiView.onConnected = onConnected
        uiView.onFailed = onFailed
        if let connectionInfo {
            uiView.configure(connectionInfo: connectionInfo, terminalID: terminalID)
            uiView.paste(text: pasteText, requestID: pasteRequestID)
            DispatchQueue.main.async {
                uiView.becomeFirstResponder()
            }
        } else {
            uiView.disconnectAndReset()
        }
    }
}

private final class AcceptAllHostKeysDelegate: NIOSSHClientServerAuthenticationDelegate {
    func validateHostKey(hostKey: NIOSSHPublicKey, validationCompletePromise: EventLoopPromise<Void>) {
        validationCompletePromise.succeed(())
    }
}

private final class PrivateKeyAuthenticationDelegate: NIOSSHClientUserAuthenticationDelegate {
    private var authRequest: NIOSSHUserAuthenticationOffer?

    init(username: String, privateKey: NIOSSHPrivateKey) {
        authRequest = NIOSSHUserAuthenticationOffer(
            username: username,
            serviceName: "",
            offer: .privateKey(.init(privateKey: privateKey))
        )
    }

    func nextAuthenticationType(
        availableMethods: NIOSSHAvailableUserAuthenticationMethods,
        nextChallengePromise: EventLoopPromise<NIOSSHUserAuthenticationOffer?>
    ) {
        guard let authRequest, availableMethods.contains(.publicKey) else {
            nextChallengePromise.succeed(nil)
            return
        }
        self.authRequest = nil
        nextChallengePromise.succeed(authRequest)
    }
}

private final class SSHErrorHandler: ChannelInboundHandler {
    typealias InboundIn = Any
    private let onError: (Error) -> Void

    init(onError: @escaping (Error) -> Void) {
        self.onError = onError
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        onError(error)
        context.close(promise: nil)
    }
}

private final class SSHShellChannelHandler: ChannelInboundHandler {
    typealias InboundIn = SSHChannelData

    private weak var terminalView: HermesSshTerminalView?
    private let term: String
    private let environment: [String: String]
    private let initialWindowSize: (cols: Int, rows: Int)

    init(terminalView: HermesSshTerminalView?, term: String, environment: [String: String], initialWindowSize: (cols: Int, rows: Int)) {
        self.terminalView = terminalView
        self.term = term
        self.environment = environment
        self.initialWindowSize = initialWindowSize
    }

    func handlerAdded(context: ChannelHandlerContext) {
        context.channel.setOption(ChannelOptions.allowRemoteHalfClosure, value: true).whenFailure { error in
            context.fireErrorCaught(error)
        }
    }

    func channelActive(context: ChannelHandlerContext) {
        let pty = SSHChannelRequestEvent.PseudoTerminalRequest(
            wantReply: false,
            term: term,
            terminalCharacterWidth: initialWindowSize.cols,
            terminalRowHeight: initialWindowSize.rows,
            terminalPixelWidth: 0,
            terminalPixelHeight: 0,
            terminalModes: SSHTerminalModes([:])
        )
        context.triggerUserOutboundEvent(pty, promise: nil)

        for (name, value) in environment {
            let env = SSHChannelRequestEvent.EnvironmentRequest(wantReply: false, name: name, value: value)
            context.triggerUserOutboundEvent(env, promise: nil)
        }

        context.triggerUserOutboundEvent(SSHChannelRequestEvent.ShellRequest(wantReply: false), promise: nil)
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let payload = unwrapInboundIn(data)
        guard case .byteBuffer(var buffer) = payload.data,
              let bytes = buffer.readBytes(length: buffer.readableBytes),
              !bytes.isEmpty
        else { return }

        let chunkSize = 1024
        var next = 0
        while next < bytes.count {
            let end = min(next + chunkSize, bytes.count)
            let chunk = bytes[next..<end]
            DispatchQueue.main.async { [weak terminalView] in
                terminalView?.feed(byteArray: chunk)
            }
            next = end
        }
    }

    func userInboundEventTriggered(context: ChannelHandlerContext, event: Any) {
        if let status = event as? SSHChannelRequestEvent.ExitStatus {
            DispatchQueue.main.async { [weak terminalView] in
                terminalView?.feed(text: "\n[SSH] Session exited with status \(status.exitStatus)\n")
            }
        } else if let signal = event as? SSHChannelRequestEvent.ExitSignal {
            DispatchQueue.main.async { [weak terminalView] in
                terminalView?.feed(text: "\n[SSH] Session closed: \(signal.signalName)\n")
            }
        } else {
            context.fireUserInboundEventTriggered(event)
        }
    }
}

private final class HermesSSHConnection {
    private weak var terminalView: HermesSshTerminalView?
    private let info: HermesTerminalConnectionInfo
    private let initialWindowSize: (cols: Int, rows: Int)
    private var group: EventLoopGroup?
    private var channel: Channel?
    private var sessionChannel: Channel?

    init(terminalView: HermesSshTerminalView, info: HermesTerminalConnectionInfo, initialWindowSize: (cols: Int, rows: Int)) {
        self.terminalView = terminalView
        self.info = info
        self.initialWindowSize = initialWindowSize
    }

    func connect() {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        self.group = group

        let userAuthDelegate: NIOSSHClientUserAuthenticationDelegate
        do {
            userAuthDelegate = PrivateKeyAuthenticationDelegate(
                username: info.username,
                privateKey: try OpenSSHEd25519PrivateKeyParser.parse(info.privateKey)
            )
        } catch {
            handleError(error)
            shutdownGroup()
            return
        }

        let bootstrap = ClientBootstrap(group: group)
            .channelInitializer { [weak self] channel in
                channel.eventLoop.makeCompletedFuture {
                    guard let self else { return }
                    let sshHandler = NIOSSHHandler(
                        role: .client(.init(userAuthDelegate: userAuthDelegate, serverAuthDelegate: AcceptAllHostKeysDelegate())),
                        allocator: channel.allocator,
                        inboundChildChannelInitializer: nil
                    )
                    try channel.pipeline.syncOperations.addHandler(sshHandler)
                    try channel.pipeline.syncOperations.addHandler(SSHErrorHandler { [weak self] error in
                        self?.handleError(error)
                    })
                }
            }
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(IPPROTO_TCP), TCP_NODELAY), value: 1)

        bootstrap.connect(host: info.host, port: info.port).whenComplete { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.handleError(error)
                self.shutdownGroup()
            case .success(let channel):
                self.channel = channel
                self.createSessionChannel(on: channel)
            }
        }
    }

    func send(_ data: Data) {
        guard let sessionChannel else { return }
        sessionChannel.eventLoop.execute {
            var buffer = sessionChannel.allocator.buffer(capacity: data.count)
            buffer.writeBytes(data)
            let payload = SSHChannelData(type: .channel, data: .byteBuffer(buffer))
            sessionChannel.writeAndFlush(payload, promise: nil)
        }
    }

    func resize(cols: Int, rows: Int) {
        guard cols > 0, rows > 0, let sessionChannel else { return }
        sessionChannel.eventLoop.execute {
            let event = SSHChannelRequestEvent.WindowChangeRequest(
                terminalCharacterWidth: cols,
                terminalRowHeight: rows,
                terminalPixelWidth: 0,
                terminalPixelHeight: 0
            )
            sessionChannel.triggerUserOutboundEvent(event, promise: nil)
        }
    }

    func disconnect() {
        if let channel {
            channel.closeFuture.whenComplete { [weak self] _ in
                self?.shutdownGroup()
            }
            channel.close(promise: nil)
        } else {
            shutdownGroup()
        }
    }

    private func createSessionChannel(on channel: Channel) {
        channel.pipeline.handler(type: NIOSSHHandler.self).whenComplete { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.handleError(error)
            case .success(let sshHandler):
                let promise = channel.eventLoop.makePromise(of: Channel.self)
                sshHandler.createChannel(promise, channelType: .session) { [weak self] childChannel, channelType in
                    guard let self else {
                        return channel.eventLoop.makeFailedFuture(HermesTerminalError.invalidChannelType)
                    }
                    guard channelType == .session else {
                        return channel.eventLoop.makeFailedFuture(HermesTerminalError.invalidChannelType)
                    }
                    return childChannel.eventLoop.makeCompletedFuture {
                        let sync = childChannel.pipeline.syncOperations
                        try sync.addHandler(SSHShellChannelHandler(
                            terminalView: self.terminalView,
                            term: self.info.term,
                            environment: self.info.environment,
                            initialWindowSize: self.initialWindowSize
                        ))
                        try sync.addHandler(SSHErrorHandler { [weak self] error in
                            self?.handleError(error)
                        })
                    }
                }

                promise.futureResult.whenComplete { [weak self] result in
                    guard let self else { return }
                    switch result {
                    case .failure(let error):
                        self.handleError(error)
                    case .success(let childChannel):
                        self.sessionChannel = childChannel
                        DispatchQueue.main.async { [weak self] in
                            guard let self, let terminal = self.terminalView?.getTerminal() else { return }
                            self.terminalView?.markConnected()
                            self.resize(cols: terminal.cols, rows: terminal.rows)
                        }
                    }
                }
            }
        }
    }

    private func handleError(_ error: Error) {
        DispatchQueue.main.async { [weak terminalView] in
            terminalView?.markFailed(error.localizedDescription)
            terminalView?.feed(text: "[ERROR] \(error.localizedDescription)\n")
        }
    }

    private func shutdownGroup() {
        if let group {
            self.group = nil
            group.shutdownGracefully { _ in }
        }
    }
}

private final class HermesSshTerminalView: TerminalView, TerminalViewDelegate {
    var onConnected: (() -> Void)?
    var onFailed: ((String) -> Void)?

    private var sshConnection: HermesSSHConnection?
    private var configuredInfo: HermesTerminalConnectionInfo?
    private var configuredTerminalID: UUID?
    private var lastPasteRequestID: UUID?

    override init(frame: CGRect) {
        super.init(frame: frame)
        terminalDelegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        sshConnection?.disconnect()
    }

    func configure(connectionInfo: HermesTerminalConnectionInfo, terminalID: UUID) {
        guard configuredInfo != connectionInfo || configuredTerminalID != terminalID else { return }
        configuredInfo = connectionInfo
        configuredTerminalID = terminalID
        sshConnection?.disconnect()
        feed(text: "\u{001B}[2J\u{001B}[H")
        feed(text: "Connecting to \(connectionInfo.username)@\(connectionInfo.host):\(connectionInfo.port)…\n")
        let terminal = getTerminal()
        let cols = terminal.cols > 0 ? terminal.cols : 80
        let rows = terminal.rows > 0 ? terminal.rows : 24
        let connection = HermesSSHConnection(
            terminalView: self,
            info: connectionInfo,
            initialWindowSize: (cols: cols, rows: rows)
        )
        sshConnection = connection
        connection.connect()
    }

    func disconnectAndReset() {
        configuredInfo = nil
        configuredTerminalID = nil
        sshConnection?.disconnect()
        sshConnection = nil
        feed(text: "\u{001B}[2J\u{001B}[H")
        feed(text: "Terminal disconnected.\n")
    }

    func paste(text: String, requestID: UUID) {
        guard lastPasteRequestID != requestID else { return }
        guard lastPasteRequestID != nil else {
            lastPasteRequestID = requestID
            return
        }
        lastPasteRequestID = requestID
        guard let data = text.data(using: .utf8) else { return }
        sshConnection?.send(data)
    }

    func markConnected() {
        onConnected?()
        feed(text: "[SSH] Connected.\n")
    }

    func markFailed(_ message: String) {
        onFailed?(message)
        feed(text: "[SSH] \(message)\n")
    }

    func scrolled(source: TerminalView, position: Double) {}
    func setTerminalTitle(source: TerminalView, title: String) {}
    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        sshConnection?.resize(cols: newCols, rows: newRows)
    }
    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        sshConnection?.send(Data(data))
    }
    func clipboardCopy(source: TerminalView, content: Data) {
        if let str = String(bytes: content, encoding: .utf8) {
            UIPasteboard.general.string = str
        }
    }
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
        if let url = URL(string: link) {
            UIApplication.shared.open(url)
        }
    }
    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
}

private enum OpenSSHEd25519PrivateKeyParser {
    static func parse(_ key: String) throws -> NIOSSHPrivateKey {
        let raw = try extractOpenSSHBase64(key)
        var reader = SSHBufferReader(data: raw)
        guard try reader.readCString() == "openssh-key-v1" else {
            throw HermesTerminalError.invalidPrivateKey("missing OpenSSH key header")
        }
        let cipherName = try reader.readString()
        let kdfName = try reader.readString()
        _ = try reader.readData()
        guard cipherName == "none", kdfName == "none" else {
            throw HermesTerminalError.unsupportedPrivateKey
        }
        guard try reader.readUInt32() == 1 else {
            throw HermesTerminalError.invalidPrivateKey("expected exactly one key")
        }
        _ = try reader.readData()
        let privateBlob = try reader.readData()
        var privateReader = SSHBufferReader(data: privateBlob)
        let check1 = try privateReader.readUInt32()
        let check2 = try privateReader.readUInt32()
        guard check1 == check2 else {
            throw HermesTerminalError.invalidPrivateKey("check values do not match")
        }
        guard try privateReader.readString() == "ssh-ed25519" else {
            throw HermesTerminalError.unsupportedPrivateKey
        }
        let publicKey = try privateReader.readData()
        let privateAndPublic = try privateReader.readData()
        guard publicKey.count == 32, privateAndPublic.count == 64 else {
            throw HermesTerminalError.invalidPrivateKey("unexpected Ed25519 key length")
        }
        let seed = privateAndPublic.prefix(32)
        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: seed)
        return NIOSSHPrivateKey(ed25519Key: privateKey)
    }

    private static func extractOpenSSHBase64(_ key: String) throws -> Data {
        let lines = key
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("-----BEGIN") && !$0.hasPrefix("-----END") }
        guard !lines.isEmpty, let data = Data(base64Encoded: lines.joined()) else {
            throw HermesTerminalError.invalidPrivateKey("could not decode OpenSSH base64 payload")
        }
        return data
    }
}

private struct SSHBufferReader {
    private let data: Data
    private var offset: Int = 0

    init(data: Data) {
        self.data = data
    }

    mutating func readCString() throws -> String {
        guard let nul = data[offset...].firstIndex(of: 0) else {
            throw HermesTerminalError.invalidPrivateKey("unterminated string")
        }
        let bytes = data[offset..<nul]
        offset = data.index(after: nul)
        return String(decoding: bytes, as: UTF8.self)
    }

    mutating func readUInt32() throws -> UInt32 {
        let bytes = try readBytes(count: 4)
        return bytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }

    mutating func readString() throws -> String {
        let payload = try readData()
        return String(decoding: payload, as: UTF8.self)
    }

    mutating func readData() throws -> Data {
        let length = Int(try readUInt32())
        return Data(try readBytes(count: length))
    }

    private mutating func readBytes(count: Int) throws -> [UInt8] {
        guard count >= 0, offset + count <= data.count else {
            throw HermesTerminalError.invalidPrivateKey("unexpected end of key data")
        }
        let end = offset + count
        defer { offset = end }
        return Array(data[offset..<end])
    }
}
