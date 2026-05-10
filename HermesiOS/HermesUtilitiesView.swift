//
//  HermesUtilitiesView.swift
//  HermesiOS
//

import CryptoKit
import Observation
import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct HermesUtilitiesView: View {
    @Bindable var clipboardHistory: HermesClipboardHistoryStore
    @Bindable var promptHistory: HermesPromptHistoryStore
    @Bindable var responseSession: HermesResponsesSession
    @Bindable var chatSession: HermesChatSession
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession
    @AppStorage("hermes.utilities.clipboardHistoryExpanded") private var isClipboardHistoryExpanded = false
    @AppStorage("hermes.utilities.promptHistoryExpanded") private var isPromptHistoryExpanded = false
    @AppStorage("hermes.utilities.fileDownloaderExpanded") private var isFileDownloaderExpanded = false
    @AppStorage("hermes.utilities.sshTerminalExpanded") private var isSSHTerminalExpanded = false
    @AppStorage("hermes.utilities.debuggingExpanded") private var isDebuggingExpanded = false
    @AppStorage("hermes.utilities.supermemoryManagementExpanded") private var isSupermemoryManagementExpanded = false
    @State private var statusMessage = "Monitoring the iOS clipboard while HermesiOS is active."
    @State private var promptHistoryStatusMessage = "Capturing prompts sent from Ask Hermes and Chat with Hermes."
    @State private var isFileDownloaderFolderImporterPresented = false
    @State private var selectedDownloadFolderURL: URL?
    @State private var macFilePath = "/Users/me"
    @State private var fileDownloaderStatus = "Pick an iOS Files folder, enter a full macOS file path, then download."
    @State private var isDownloadingFile = false
    @AppStorage(hermesMacHostStorageKey) private var macHost = defaultHermesMacHost
    @State private var terminalCommand = "uname -a"
    @State private var terminalOutput = "Configure SSH username and private key in Settings, then run a command."
    @State private var isRunningTerminalCommand = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HermesTabHeader("Utilities", systemImage: "wrench.and.screwdriver")

                HermesSectionCard {
                    DisclosureGroup(isExpanded: $isClipboardHistoryExpanded) {
                        clipboardHistoryContent
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "clipboard")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.igActionBlue)
                                .frame(width: 34, height: 34)
                                .hermesLiquidGlass(cornerRadius: 11, tint: .igActionBlue.opacity(0.16), interactive: true)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Clipboard History")
                                    .font(.igUsername)
                                    .foregroundStyle(.primary)
                                Text("Last \(clipboardHistory.entries.count) of 10 copied objects")
                                    .font(.igSecondaryMeta)
                                    .foregroundStyle(.hermesSecondaryText)
                            }

                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .tint(.igActionBlue)

                    Divider()
                        .overlay(Color.hermesDivider.opacity(0.5))
                        .padding(.vertical, 4)

                    DisclosureGroup(isExpanded: $isPromptHistoryExpanded) {
                        promptHistoryContent
                    } label: {
                        utilityDisclosureLabel(
                            title: "Prompt History",
                            subtitle: "Last \(promptHistory.entries.count) of 10 prompts sent to Hermes",
                            systemImage: "text.quote"
                        )
                    }
                    .tint(.igActionBlue)

                    Divider()
                        .overlay(Color.hermesDivider.opacity(0.5))
                        .padding(.vertical, 4)

                    DisclosureGroup(isExpanded: $isFileDownloaderExpanded) {
                        fileDownloaderContent
                    } label: {
                        utilityDisclosureLabel(
                            title: "File Downloader",
                            subtitle: fileDownloaderSubtitle,
                            systemImage: "tray.and.arrow.down"
                        )
                    }
                    .tint(.igActionBlue)

                    Divider()
                        .overlay(Color.hermesDivider.opacity(0.5))
                        .padding(.vertical, 4)

                    DisclosureGroup(isExpanded: $isSSHTerminalExpanded) {
                        sshTerminalContent
                    } label: {
                        utilityDisclosureLabel(
                            title: "Terminal",
                            subtitle: sshTerminalSubtitle,
                            systemImage: "terminal"
                        )
                    }
                    .tint(.igActionBlue)

                    Divider()
                        .overlay(Color.hermesDivider.opacity(0.5))
                        .padding(.vertical, 4)

                    if isSupermemoryActive {
                        DisclosureGroup(isExpanded: $isSupermemoryManagementExpanded) {
                            supermemoryManagementContent
                        } label: {
                            utilityDisclosureLabel(
                                title: "Supermemory management",
                                subtitle: supermemorySubtitle,
                                systemImage: "externaldrive.connected.to.line.below"
                            )
                        }
                        .tint(.igActionBlue)

                        Divider()
                            .overlay(Color.hermesDivider.opacity(0.5))
                            .padding(.vertical, 4)
                    }

                    DisclosureGroup(isExpanded: $isDebuggingExpanded) {
                        HermesStreamedJSONDebugPanel(
                            responseSession: responseSession,
                            chatSession: chatSession
                        )
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "ladybug")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.igActionBlue)
                                .frame(width: 34, height: 34)
                                .hermesLiquidGlass(cornerRadius: 11, tint: .igActionBlue.opacity(0.16), interactive: true)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Debugging")
                                    .font(.igUsername)
                                    .foregroundStyle(.primary)
                                Text("Inspect streamed Responses and Chat Completions JSON")
                                    .font(.igSecondaryMeta)
                                    .foregroundStyle(.hermesSecondaryText)
                            }

                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .tint(.igActionBlue)
                }
            }
            .padding(24)
            .frame(maxWidth: 980, alignment: .leading)
        }
        .background(HermesLiquidGlassCanvas().ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .fileImporter(
            isPresented: $isFileDownloaderFolderImporterPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFileDownloaderFolderImport(result)
        }
        .onAppear {
            clipboardHistory.captureCurrentPasteboardIfNeeded()
        }
        .onDisappear {
            collapseAllUtilitySections()
        }
    }


    private func collapseAllUtilitySections() {
        isClipboardHistoryExpanded = false
        isPromptHistoryExpanded = false
        isFileDownloaderExpanded = false
        isSSHTerminalExpanded = false
        isDebuggingExpanded = false
        isSupermemoryManagementExpanded = false
    }

    private var isSupermemoryActive: Bool {
        companionRuntime.memoryProvider.lowercased() == "supermemory"
            || companionRuntime.memoryProviders.contains { $0.name.lowercased() == "supermemory" && $0.active }
    }

    private var supermemorySubtitle: String {
        if let result = companionRuntime.supermemoryLastResult {
            if result.importedCount > 0 { return "Last import: \(result.importedCount) documents" }
            return "Last export: \(result.exportedCount) documents"
        }
        return "Export Supermemory deltas and import them into Hermes files"
    }

    private var fileDownloaderSubtitle: String {
        if let folderName = selectedDownloadFolderURL?.lastPathComponent, folderName.isEmpty == false {
            return "Save macOS files into \(folderName)"
        }
        return "Download a Mac file into an iOS Files folder"
    }

    private var sshTerminalSubtitle: String {
        let user = companionSettings.sshUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let host = macHost.trimmingCharacters(in: .whitespacesAndNewlines)
        if !user.isEmpty, !host.isEmpty {
            return "Run SSH commands as \(user)@\(host)"
        }
        return "Run commands on the Mac over SSH"
    }

    private func utilityDisclosureLabel(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.igActionBlue)
                .frame(width: 34, height: 34)
                .hermesLiquidGlass(cornerRadius: 11, tint: .igActionBlue.opacity(0.16), interactive: true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.igUsername)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.igSecondaryMeta)
                    .foregroundStyle(.hermesSecondaryText)
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private var sshTerminalContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Runs one command over SSH against the Mac host configured in Settings using the saved username and private key.")
                .font(.subheadline)
                .foregroundStyle(.hermesSecondaryText)

            TextField("Command", text: $terminalCommand, axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body.monospaced())
                .lineLimit(3, reservesSpace: true)
                .padding(12)
                .background(Color.hermesSurfaceInput, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .textSelection(.enabled)

            HStack(spacing: 10) {
                Button {
                    runSSHTerminalCommand()
                } label: {
                    Label(isRunningTerminalCommand ? "Running…" : "Run Command", systemImage: "play.fill")
                }
                .hermesGlassButton()
                .disabled(!canRunSSHTerminalCommand)

                if isRunningTerminalCommand {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            ScrollView {
                Text(terminalOutput)
                    .font(.caption.monospaced())
                    .foregroundStyle(terminalOutput.hasPrefix("Exit 0") ? Color.primary : Color.hermesSecondaryText)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(minHeight: 160, maxHeight: 320)
            .background(Color.hermesSurfaceInput, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.top, 12)
    }

    private var canRunSSHTerminalCommand: Bool {
        companionEnrollment.identityState.isEnrolled
            && !isRunningTerminalCommand
            && !companionRuntime.isBusy
            && !macHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !companionSettings.sshUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !companionSettings.sshPrivateKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !terminalCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func runSSHTerminalCommand() {
        let host = macHost.trimmingCharacters(in: .whitespacesAndNewlines)
        let username = companionSettings.sshUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let privateKey = companionSettings.sshPrivateKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let command = terminalCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        let port = Int(companionSettings.sshPort.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 22

        Task { @MainActor in
            isRunningTerminalCommand = true
            terminalOutput = "Running over SSH…"
            companionRuntime.connectionStatus = "SSH Terminal"
            companionRuntime.lastErrorMessage = ""
            defer { isRunningTerminalCommand = false }

            do {
                let result: HermesCompanionSSHTerminalResult = try await HermesCompanionSessionFactory.request(
                    settings: companionSettings,
                    state: companionEnrollment.identityState,
                    type: "ssh_terminal_command",
                    payload: HermesCompanionSSHTerminalPayload(
                        host: host,
                        port: port,
                        username: username,
                        privateKey: privateKey,
                        command: command
                    )
                )
                terminalOutput = "Exit \(result.exitCode) • \(result.username)@\(result.host)\n$ \(result.command)\n\n\(result.output)"
                companionRuntime.connectionStatus = result.exitCode == 0 ? "SSH Complete" : "SSH Failed"
            } catch {
                terminalOutput = error.localizedDescription
                companionRuntime.lastErrorMessage = error.localizedDescription
                companionRuntime.connectionStatus = "SSH Failed"
            }
        }
    }

    private var fileDownloaderContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    isFileDownloaderFolderImporterPresented = true
                } label: {
                    Label("Pick iOS Folder", systemImage: "folder")
                }
                .hermesGlassButton()

                if let selectedDownloadFolderURL {
                    Text(selectedDownloadFolderURL.lastPathComponent)
                        .font(.igSecondaryMeta)
                        .foregroundStyle(.hermesSecondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                } else {
                    Text("No destination folder selected")
                        .font(.igSecondaryMeta)
                        .foregroundStyle(.hermesSecondaryText)
                }
            }

            TextField("/Users/me", text: $macFilePath)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body.monospaced())
                .padding(12)
                .background(Color.hermesSurfaceInput, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .textSelection(.enabled)

            HStack(spacing: 10) {
                Button {
                    downloadFileFromMac()
                } label: {
                    Label(isDownloadingFile ? "Downloading…" : "Download", systemImage: "arrow.down.doc")
                }
                .hermesGlassButton()
                .disabled(!canDownloadFile)

                if isDownloadingFile {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Text(fileDownloaderStatus)
                .font(.igSecondaryMeta)
                .foregroundStyle(fileDownloaderStatus.hasPrefix("Saved") ? .igOnlineGreen : .hermesSecondaryText)
                .textSelection(.enabled)
        }
        .padding(.top, 12)
    }

    private var canDownloadFile: Bool {
        companionEnrollment.identityState.isEnrolled
            && selectedDownloadFolderURL != nil
            && macFilePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && !isDownloadingFile
            && !companionRuntime.isBusy
    }

    private func handleFileDownloaderFolderImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            selectedDownloadFolderURL = url
            fileDownloaderStatus = "Destination folder selected: \(url.lastPathComponent)."
        } catch {
            fileDownloaderStatus = error.localizedDescription
        }
    }

    private func downloadFileFromMac() {
        guard let folderURL = selectedDownloadFolderURL else {
            fileDownloaderStatus = "Pick an iOS destination folder first."
            return
        }
        let path = macFilePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard path.isEmpty == false else {
            fileDownloaderStatus = "Enter a full macOS file path."
            return
        }

        Task { @MainActor in
            isDownloadingFile = true
            fileDownloaderStatus = "Downloading from Mac…"
            companionRuntime.connectionStatus = "Downloading File"
            companionRuntime.lastErrorMessage = ""
            defer { isDownloadingFile = false }

            do {
                let info: HermesCompanionFileDownloadInfoResult = try await HermesCompanionSessionFactory.request(
                    settings: companionSettings,
                    state: companionEnrollment.identityState,
                    type: "download_file_info",
                    payload: HermesCompanionFileDownloadPayload(path: path)
                )
                var data = Data()
                data.reserveCapacity(info.byteCount)
                var offset = 0
                let chunkSize = max(1, info.chunkSize)

                repeat {
                    let chunk: HermesCompanionFileDownloadChunkResult = try await HermesCompanionSessionFactory.request(
                        settings: companionSettings,
                        state: companionEnrollment.identityState,
                        type: "download_file_chunk",
                        payload: HermesCompanionFileDownloadChunkPayload(path: path, offset: offset, length: chunkSize)
                    )
                    guard let chunkData = Data(base64Encoded: chunk.base64Data) else {
                        throw HermesFileDownloaderError.invalidPayload
                    }
                    data.append(chunkData)
                    offset += chunk.byteCount
                    fileDownloaderStatus = "Downloading from Mac… \(Self.byteCountFormatter.string(fromByteCount: Int64(data.count))) / \(Self.byteCountFormatter.string(fromByteCount: Int64(info.byteCount)))"
                    if chunk.isComplete || chunk.byteCount == 0 { break }
                } while offset < info.byteCount

                guard data.count == info.byteCount else {
                    throw HermesFileDownloaderError.incompleteDownload(expected: info.byteCount, actual: data.count)
                }
                let savedURL = try saveDownloadedFile(data, fileName: info.fileName, in: folderURL)
                fileDownloaderStatus = "Saved \(savedURL.lastPathComponent) (\(Self.byteCountFormatter.string(fromByteCount: Int64(data.count)))) to \(folderURL.lastPathComponent)."
                companionRuntime.connectionStatus = "File Downloaded"
            } catch {
                fileDownloaderStatus = error.localizedDescription
                companionRuntime.lastErrorMessage = error.localizedDescription
                companionRuntime.connectionStatus = "Download Failed"
            }
        }
    }

    private func saveDownloadedFile(_ data: Data, fileName: String, in folderURL: URL) throws -> URL {
        let didAccess = folderURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess { folderURL.stopAccessingSecurityScopedResource() }
        }

        var destinationURL = folderURL.appendingPathComponent(fileName.isEmpty ? "downloaded-file" : fileName, isDirectory: false)
        destinationURL = uniqueFileURL(for: destinationURL)
        try data.write(to: destinationURL, options: [.atomic])
        return destinationURL
    }

    private func uniqueFileURL(for url: URL) -> URL {
        guard FileManager.default.fileExists(atPath: url.path) else { return url }
        let directory = url.deletingLastPathComponent()
        let baseName = url.deletingPathExtension().lastPathComponent
        let pathExtension = url.pathExtension

        for index in 1...999 {
            let candidateName = pathExtension.isEmpty ? "\(baseName)-\(index)" : "\(baseName)-\(index).\(pathExtension)"
            let candidateURL = directory.appendingPathComponent(candidateName, isDirectory: false)
            if !FileManager.default.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
        }
        return directory.appendingPathComponent(UUID().uuidString + (pathExtension.isEmpty ? "" : ".\(pathExtension)"), isDirectory: false)
    }

    private static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter
    }()

    private var supermemoryManagementContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exports Supermemory documents created since the previous export trigger into a JSONL file on the Mac, then imports that delta into Hermes memory and skill-reference files.")
                .font(.subheadline)
                .foregroundStyle(.hermesSecondaryText)

            HStack(spacing: 10) {
                Button {
                    companionRuntime.exportSupermemoryDelta(settings: companionSettings, identityState: companionEnrollment.identityState)
                } label: {
                    Label("Export", systemImage: "square.and.arrow.down")
                }
                .hermesGlassButton()
                .disabled(!companionEnrollment.identityState.isEnrolled || companionRuntime.isBusy)

                Button {
                    companionRuntime.importSupermemoryDelta(settings: companionSettings, identityState: companionEnrollment.identityState)
                } label: {
                    Label("Import into Hermes", systemImage: "square.and.arrow.down.on.square")
                }
                .hermesGlassButton()
                .disabled(!companionEnrollment.identityState.isEnrolled || companionRuntime.isBusy)
            }

            if !companionRuntime.supermemoryOperationOutput.isEmpty {
                Text(companionRuntime.supermemoryOperationOutput)
                    .font(.caption.monospaced())
                    .foregroundStyle(.hermesSecondaryText)
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.hermesSurfaceInput, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                Text(companionEnrollment.identityState.isEnrolled ? "Ready." : "Enroll the Mac companion to run Supermemory management.")
                    .font(.igSecondaryMeta)
                    .foregroundStyle(.hermesSecondaryText)
            }
        }
        .padding(.top, 12)
        .task(id: companionEnrollment.identityState.deviceID) {
            guard companionEnrollment.identityState.isEnrolled else { return }
            if companionRuntime.memoryConfig == nil {
                companionRuntime.refreshMemoryConfig(settings: companionSettings, identityState: companionEnrollment.identityState)
            }
        }
    }

    @ViewBuilder
    private var clipboardHistoryContent: some View {        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    clipboardHistory.captureCurrentPasteboardIfNeeded(force: true)
                    statusMessage = "Clipboard checked."
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .hermesGlassButton()

                Button(role: .destructive) {
                    clipboardHistory.clear()
                    statusMessage = "Clipboard history cleared."
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(clipboardHistory.entries.isEmpty)
                .hermesGlassButton()
            }

            Text(statusMessage)
                .font(.igSecondaryMeta)
                .foregroundStyle(.hermesSecondaryText)

            if clipboardHistory.entries.isEmpty {
                ContentUnavailableView(
                    "No clipboard history yet",
                    systemImage: "clipboard",
                    description: Text("Copy text, images, or files while HermesiOS is active, then open this utility to paste them back later.")
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(clipboardHistory.entries) { entry in
                        HStack(alignment: .center, spacing: 10) {
                            Button {
                                clipboardHistory.copyToPasteboard(entry)
                                statusMessage = "Copied \(entry.kind.displayName.lowercased()) back to the clipboard."
                            } label: {
                                HermesClipboardHistoryRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Copies this item back to the iOS clipboard")

                            Button(role: .destructive) {
                                clipboardHistory.delete(entry)
                                statusMessage = "Deleted \(entry.kind.displayName.lowercased()) from clipboard history."
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.igDestructive)
                                    .frame(width: 38, height: 38)
                                    .hermesLiquidGlass(cornerRadius: 12, tint: Color.igDestructive.opacity(0.12), interactive: true)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Delete \(entry.kind.displayName.lowercased()) from clipboard history")
                        }
                    }
                }
            }
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var promptHistoryContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button(role: .destructive) {
                    promptHistory.clear()
                    promptHistoryStatusMessage = "Prompt history cleared."
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(promptHistory.entries.isEmpty)
                .hermesGlassButton()
            }

            Text(promptHistoryStatusMessage)
                .font(.igSecondaryMeta)
                .foregroundStyle(.hermesSecondaryText)

            if promptHistory.entries.isEmpty {
                ContentUnavailableView(
                    "No prompt history yet",
                    systemImage: "text.quote",
                    description: Text("Send prompts from Ask Hermes or Chat with Hermes, then open this utility to copy them back later.")
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(promptHistory.entries) { entry in
                        HStack(alignment: .center, spacing: 10) {
                            Button {
                                promptHistory.copyToPasteboard(entry)
                                promptHistoryStatusMessage = "Copied prompt to the clipboard."
                            } label: {
                                HermesPromptHistoryRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Copies this prompt back to the iOS clipboard")

                            Button(role: .destructive) {
                                promptHistory.delete(entry)
                                promptHistoryStatusMessage = "Deleted prompt from history."
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.igDestructive)
                                    .frame(width: 38, height: 38)
                                    .hermesLiquidGlass(cornerRadius: 12, tint: Color.igDestructive.opacity(0.12), interactive: true)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Delete prompt from history")
                        }
                    }
                }
            }
        }
        .padding(.top, 12)
    }
}

private struct HermesPromptHistoryRow: View {
    let entry: HermesPromptHistoryEntry

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: entry.source.systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.igActionBlue)
                .frame(width: 72, height: 72)
                .background(Color.hermesSurfaceInput, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Label(entry.source.displayName, systemImage: "text.quote")
                        .font(.igSecondaryMeta.weight(.semibold))
                        .foregroundStyle(.hermesSecondaryText)

                    Text(entry.createdAt, style: .time)
                        .font(.igSecondaryMeta)
                        .foregroundStyle(.hermesSecondaryText)
                }

                Text(entry.title)
                    .font(.igUsername)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                Text(entry.subtitle)
                    .font(.igSecondaryMeta)
                    .foregroundStyle(.hermesSecondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.igActionBlue)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hermesLiquidGlass(cornerRadius: 20, tint: .igActionBlue.opacity(0.06), interactive: true)
    }
}

private enum HermesFileDownloaderError: LocalizedError {
    case invalidPayload
    case incompleteDownload(expected: Int, actual: Int)

    var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return "The Mac companion returned an invalid file payload."
        case .incompleteDownload(let expected, let actual):
            return "The Mac companion returned an incomplete file (\(actual) of \(expected) bytes)."
        }
    }
}

private struct HermesClipboardHistoryRow: View {
    let entry: HermesClipboardHistoryEntry

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            preview
                .frame(width: 72, height: 72)
                .background(Color.hermesSurfaceInput, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Label(entry.kind.displayName, systemImage: entry.kind.systemImage)
                        .font(.igSecondaryMeta.weight(.semibold))
                        .foregroundStyle(.hermesSecondaryText)

                    Text(entry.createdAt, style: .time)
                        .font(.igSecondaryMeta)
                        .foregroundStyle(.hermesSecondaryText)
                }

                Text(entry.title)
                    .font(.igUsername)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let subtitle = entry.subtitle {
                    Text(subtitle)
                        .font(.igSecondaryMeta)
                        .foregroundStyle(.hermesSecondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.igActionBlue)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hermesLiquidGlass(cornerRadius: 20, tint: .igActionBlue.opacity(0.06), interactive: true)
    }

    @ViewBuilder
    private var preview: some View {
        switch entry.kind {
        case .text:
            Text(entry.textValue ?? "")
                .font(.caption2.monospaced())
                .foregroundStyle(.primary)
                .lineLimit(5)
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .image:
            if let image = entry.uiImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.hermesSecondaryText)
            }
        case .file:
            Image(systemName: entry.kind.systemImage)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.igActionBlue)
        }
    }
}

@Observable
final class HermesClipboardHistoryStore {
    private let defaultsKey = "hermes.utilities.clipboardHistory.entries"
    private let maxEntries = 10
    private let maxStoredBytes = 25 * 1024 * 1024
    private var lastObservedChangeCount = UIPasteboard.general.changeCount

    var entries: [HermesClipboardHistoryEntry] = []

    init() {
        load()
    }

    @MainActor
    func runMonitoringLoop() async {
        captureCurrentPasteboardIfNeeded(force: true)
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            captureCurrentPasteboardIfNeeded()
        }
    }

    @MainActor
    func captureCurrentPasteboardIfNeeded(force: Bool = false) {
        let pasteboard = UIPasteboard.general
        guard force || pasteboard.changeCount != lastObservedChangeCount else { return }
        lastObservedChangeCount = pasteboard.changeCount

        guard let entry = Self.entry(from: pasteboard, maxStoredBytes: maxStoredBytes) else { return }
        insert(entry)
    }

    @MainActor
    func copyToPasteboard(_ entry: HermesClipboardHistoryEntry) {
        let pasteboard = UIPasteboard.general
        switch entry.kind {
        case .text:
            pasteboard.string = entry.textValue
        case .image:
            if let image = entry.uiImage {
                pasteboard.image = image
            }
        case .file:
            pasteboard.setItems([[entry.typeIdentifier: entry.payload]])
        }
        lastObservedChangeCount = pasteboard.changeCount
    }

    func clear() {
        entries.removeAll()
        persist()
    }

    func delete(_ entry: HermesClipboardHistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    private func insert(_ entry: HermesClipboardHistoryEntry) {
        if entries.first?.fingerprint == entry.fingerprint { return }
        entries.removeAll { $0.fingerprint == entry.fingerprint }
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        persist()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([HermesClipboardHistoryEntry].self, from: data) else {
            entries = []
            return
        }
        entries = Array(decoded.prefix(maxEntries))
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private static func entry(from pasteboard: UIPasteboard, maxStoredBytes: Int) -> HermesClipboardHistoryEntry? {
        if let image = pasteboard.image,
           let data = image.pngData(),
           data.count <= maxStoredBytes {
            return HermesClipboardHistoryEntry(kind: .image, typeIdentifier: UTType.png.identifier, payload: data, displayName: "Clipboard image")
        }

        if let string = pasteboard.string, !string.isEmpty,
           let data = string.data(using: .utf8),
           data.count <= maxStoredBytes {
            return HermesClipboardHistoryEntry(kind: .text, typeIdentifier: UTType.utf8PlainText.identifier, payload: data, displayName: nil)
        }

        for item in pasteboard.items {
            if let fileEntry = fileEntry(from: item, maxStoredBytes: maxStoredBytes) {
                return fileEntry
            }
        }

        return nil
    }

    private static func fileEntry(from item: [String: Any], maxStoredBytes: Int) -> HermesClipboardHistoryEntry? {
        for (typeIdentifier, value) in item {
            guard !isTextType(typeIdentifier), !isImageType(typeIdentifier) else { continue }

            if let data = value as? Data, data.count <= maxStoredBytes {
                return HermesClipboardHistoryEntry(kind: .file, typeIdentifier: typeIdentifier, payload: data, displayName: displayName(for: typeIdentifier))
            }

            if let url = value as? URL,
               url.isFileURL,
               let data = try? Data(contentsOf: url),
               data.count <= maxStoredBytes {
                return HermesClipboardHistoryEntry(kind: .file, typeIdentifier: typeIdentifier, payload: data, displayName: url.lastPathComponent)
            }
        }
        return nil
    }

    private static func isTextType(_ identifier: String) -> Bool {
        guard let type = UTType(identifier) else { return identifier.localizedCaseInsensitiveContains("text") }
        return type.conforms(to: .text)
    }

    private static func isImageType(_ identifier: String) -> Bool {
        guard let type = UTType(identifier) else { return identifier.localizedCaseInsensitiveContains("image") }
        return type.conforms(to: .image)
    }

    private static func displayName(for typeIdentifier: String) -> String {
        if let type = UTType(typeIdentifier) {
            return type.localizedDescription ?? type.preferredFilenameExtension?.uppercased() ?? "File"
        }
        return "File"
    }
}

struct HermesClipboardHistoryEntry: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case text
        case image
        case file

        var displayName: String {
            switch self {
            case .text: "Text"
            case .image: "Image"
            case .file: "File"
            }
        }

        var systemImage: String {
            switch self {
            case .text: "text.alignleft"
            case .image: "photo"
            case .file: "doc"
            }
        }
    }

    let id: UUID
    let kind: Kind
    let typeIdentifier: String
    let payload: Data
    let displayName: String?
    let createdAt: Date
    let fingerprint: String

    init(kind: Kind, typeIdentifier: String, payload: Data, displayName: String?) {
        self.id = UUID()
        self.kind = kind
        self.typeIdentifier = typeIdentifier
        self.payload = payload
        self.displayName = displayName
        self.createdAt = Date()
        self.fingerprint = Self.makeFingerprint(kind: kind, typeIdentifier: typeIdentifier, payload: payload)
    }

    private static func makeFingerprint(kind: Kind, typeIdentifier: String, payload: Data) -> String {
        let digest = SHA256.hash(data: payload)
        let hexDigest = digest.map { String(format: "%02x", $0) }.joined()
        return kind.rawValue + ":" + typeIdentifier + ":" + hexDigest
    }

    var textValue: String? {
        String(data: payload, encoding: .utf8)
    }

    var uiImage: UIImage? {
        UIImage(data: payload)
    }

    var title: String {
        switch kind {
        case .text:
            let trimmed = (textValue ?? "Text").replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Text" : trimmed
        case .image:
            return displayName ?? "Image"
        case .file:
            return displayName ?? "File"
        }
    }

    var subtitle: String? {
        switch kind {
        case .text:
            guard let textValue else { return nil }
            return "\(textValue.count) characters"
        case .image, .file:
            return ByteCountFormatter.string(fromByteCount: Int64(payload.count), countStyle: .file)
        }
    }
}

