//
//  HermesUtilitiesView.swift
//  HermesiOS
//

import CryptoKit
import Foundation
import LocalAuthentication
import Observation
import Security
import SwiftUI
import UniformTypeIdentifiers
import UIKit

private enum HermesMessagesHistoryMode: String, CaseIterable, Identifiable {
    case prompt
    case response

    var id: String { rawValue }

    var title: String {
        switch self {
        case .prompt: "Prompt"
        case .response: "Response"
        }
    }
}

struct HermesUtilitiesView: View {
    @Bindable var clipboardHistory: HermesClipboardHistoryStore
    @Bindable var promptHistory: HermesPromptHistoryStore
    @Bindable var responseSession: HermesResponsesSession
    @Bindable var chatSession: HermesChatSession
    let apiSettings: HermesAPISettings
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession
    @AppStorage("hermes.utilities.clipboardHistoryExpanded") private var isClipboardHistoryExpanded = false
    @AppStorage("hermes.utilities.clipboardHistoryMonitoringEnabled") private var isClipboardHistoryMonitoringEnabled = false
    @AppStorage("hermes.utilities.promptHistoryExpanded") private var isPromptHistoryExpanded = false
    @AppStorage("hermes.utilities.fileDownloaderExpanded") private var isFileDownloaderExpanded = false
    @AppStorage("hermes.utilities.commandCenterExpanded") private var isCommandCenterExpanded = false
    @AppStorage("hermes.utilities.debuggingExpanded") private var isDebuggingExpanded = false
    @AppStorage("hermes.utilities.supermemoryManagementExpanded") private var isSupermemoryManagementExpanded = false
    @State private var statusMessage = "Clipboard history is encrypted and requires Face ID after restart."
    @State private var isUnlockingClipboardHistory = false
    @State private var messagesHistoryMode: HermesMessagesHistoryMode = .prompt
    @State private var promptHistoryStatusMessage = "Capturing prompts sent from Ask Hermes and Chat with Hermes."
    @State private var isFileDownloaderFolderImporterPresented = false
    @State private var selectedDownloadFolderURL: URL?
    @State private var macFilePath = ""
    @State private var isMacFileBrowserPresented = false
    @State private var macFileBrowserPath = ""
    @State private var macFileBrowserEntries: [HermesCompanionFileBrowserEntry] = []
    @State private var macFileBrowserParentPath: String?
    @State private var isLoadingMacFileBrowser = false
    @State private var macFileBrowserError = ""
    @State private var fileDownloaderStatus = "Pick an iOS Files folder, browse the Mac, then download."
    @State private var isDownloadingFile = false
    @State private var commandCenter = HermesCommandCenterStore()

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
                                Text(clipboardHistorySubtitle)
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
                            title: "Messages History",
                            subtitle: messagesHistorySubtitle,
                            systemImage: "text.bubble"
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

                    DisclosureGroup(isExpanded: $isCommandCenterExpanded) {
                        HermesCommandCenterPanel(
                            store: commandCenter,
                            apiSettings: apiSettings,
                            responseSession: responseSession,
                            chatSession: chatSession
                        )
                    } label: {
                        utilityDisclosureLabel(
                            title: "Active Agents / Runs",
                            subtitle: commandCenterSubtitle,
                            systemImage: "waveform.path.ecg.rectangle"
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
        .sheet(isPresented: $isMacFileBrowserPresented) {
            macFileBrowserSheet
        }
        .onAppear {
            if isClipboardHistoryMonitoringEnabled {
                clipboardHistory.captureCurrentPasteboardIfNeeded()
            }
        }
        .task(id: commandCenterRefreshKey) {
            await commandCenter.runStatusLoop(apiSettings: apiSettings)
        }
        .onDisappear {
            collapseAllUtilitySections()
        }
    }


    private func collapseAllUtilitySections() {
        isClipboardHistoryExpanded = false
        isPromptHistoryExpanded = false
        isFileDownloaderExpanded = false
        isCommandCenterExpanded = false
        isDebuggingExpanded = false
        isSupermemoryManagementExpanded = false
    }

    private var commandCenterRefreshKey: String {
        [
            apiSettings.baseURL,
            apiSettings.apiKey.isEmpty ? "no-key" : "key-set",
            apiSettings.allowSelfSignedCertificates ? "self-signed" : "strict"
        ].joined(separator: "|")
    }

    private var commandCenterSubtitle: String {
        let foregroundCount = [responseSession.isSending || responseSession.isStreaming, chatSession.isSending || chatSession.isStreaming].filter { $0 }.count
        let activeCount = foregroundCount + commandCenter.activeTrackedRunsCount + commandCenter.activeAgentsCount
        if activeCount > 0 {
            return "\(activeCount) active • \(commandCenter.status)"
        }
        return "Monitor runs, tool activity, elapsed time, tokens and cancellation"
    }

    private var isSupermemoryActive: Bool {
        companionRuntime.memoryProvider.lowercased() == "supermemory"
            || companionRuntime.memoryProviders.contains { $0.name.lowercased() == "supermemory" && $0.active }
    }

    private var clipboardHistorySubtitle: String {
        if clipboardHistory.isLocked {
            return "Locked • encrypted history requires Face ID"
        }
        let privacy = isClipboardHistoryMonitoringEnabled ? "Monitoring on" : "Monitoring off"
        return "\(privacy) • \(clipboardHistory.entries.count) encrypted items"
    }

    private var messagesHistorySubtitle: String {
        switch messagesHistoryMode {
        case .prompt:
            return "Last \(promptHistory.entries.count) of 10 prompts sent to Hermes"
        case .response:
            return "Last \(promptHistory.responseEntries.count) of 10 Hermes responses"
        }
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

            Button {
                presentMacFileBrowser()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "macwindow")
                        .foregroundStyle(.igActionBlue)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(macFilePath.isEmpty ? "Browse Mac files" : URL(fileURLWithPath: macFilePath).lastPathComponent)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(macFilePath.isEmpty ? "Starts in your approved Hermes workspace" : macFilePath)
                            .font(.caption.monospaced())
                            .foregroundStyle(.hermesSecondaryText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.hermesSecondaryText)
                }
                .padding(12)
                .background(Color.hermesSurfaceInput, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!companionEnrollment.identityState.isEnrolled || companionRuntime.isBusy || isDownloadingFile)

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

    private var macFileBrowserSheet: some View {
        NavigationStack {
            List {
                if isLoadingMacFileBrowser {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Loading \(macFileBrowserPath)…")
                            .foregroundStyle(.hermesSecondaryText)
                    }
                }

                if macFileBrowserError.isEmpty == false {
                    Text(macFileBrowserError)
                        .font(.igSecondaryMeta)
                        .foregroundStyle(.igGradOrange)
                        .textSelection(.enabled)
                }

                if let macFileBrowserParentPath {
                    Button {
                        loadMacFileBrowser(path: macFileBrowserParentPath)
                    } label: {
                        Label("Parent folder", systemImage: "arrow.up.folder")
                    }
                }

                ForEach(macFileBrowserEntries) { entry in
                    Button {
                        if entry.isDirectory {
                            loadMacFileBrowser(path: entry.path)
                        } else {
                            macFilePath = entry.path
                            fileDownloaderStatus = "Selected Mac file: \(entry.name)."
                            isMacFileBrowserPresented = false
                        }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: entry.isDirectory ? "folder" : "doc")
                                .foregroundStyle(entry.isDirectory ? .igActionBlue : .hermesSecondaryText)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(entry.name)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(entry.isDirectory ? entry.path : fileBrowserDetail(for: entry))
                                    .font(.caption)
                                    .foregroundStyle(.hermesSecondaryText)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer(minLength: 0)
                            if entry.isDirectory {
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.hermesSecondaryText)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Mac files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { isMacFileBrowserPresented = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { loadMacFileBrowser(path: macFileBrowserPath) } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoadingMacFileBrowser)
                }
            }
            .safeAreaInset(edge: .top) {
                Text(macFileBrowserPath)
                    .font(.caption.monospaced())
                    .foregroundStyle(.hermesSecondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.bar)
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            if macFileBrowserEntries.isEmpty {
                loadMacFileBrowser(path: macFileBrowserPath)
            }
        }
    }

    private var canDownloadFile: Bool {
        companionEnrollment.identityState.isEnrolled
            && selectedDownloadFolderURL != nil
            && macFilePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && !isDownloadingFile
            && !companionRuntime.isBusy
    }

    private func presentMacFileBrowser() {
        macFileBrowserPath = macFilePath.isEmpty ? companionSettings.hermesWorkspacePath : (URL(fileURLWithPath: macFilePath).deletingLastPathComponent().path)
        macFileBrowserError = ""
        isMacFileBrowserPresented = true
        loadMacFileBrowser(path: macFileBrowserPath)
    }

    private func loadMacFileBrowser(path: String) {
        guard companionEnrollment.identityState.isEnrolled else {
            macFileBrowserError = "Enroll this device with the Host Companion first."
            return
        }
        let requestedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { @MainActor in
            isLoadingMacFileBrowser = true
            macFileBrowserError = ""
            defer { isLoadingMacFileBrowser = false }
            do {
                let result: HermesCompanionFileBrowserResult = try await HermesCompanionSessionFactory.request(
                    settings: companionSettings,
                    state: companionEnrollment.identityState,
                    type: "browse_files",
                    payload: HermesCompanionFileBrowserPayload(path: requestedPath, workspacePath: companionSettings.hermesWorkspacePath)
                )
                macFileBrowserPath = result.path
                macFileBrowserParentPath = result.parentPath
                macFileBrowserEntries = result.entries
                if result.entries.isEmpty {
                    macFileBrowserError = "No visible files in this folder."
                }
            } catch {
                macFileBrowserError = error.localizedDescription
            }
        }
    }

    private func fileBrowserDetail(for entry: HermesCompanionFileBrowserEntry) -> String {
        if let byteCount = entry.byteCount {
            return "\(Self.byteCountFormatter.string(fromByteCount: Int64(byteCount))) • \(entry.path)"
        }
        return entry.path
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
                    payload: HermesCompanionFileDownloadPayload(path: path, workspacePath: companionSettings.hermesWorkspacePath)
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
                        payload: HermesCompanionFileDownloadChunkPayload(path: path, offset: offset, length: chunkSize, workspacePath: companionSettings.hermesWorkspacePath)
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
            Toggle(isOn: $isClipboardHistoryMonitoringEnabled) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Monitor clipboard while active")
                        .font(.igUsername)
                    Text("Opt-in only; history is encrypted and unlocks with Face ID next session.")
                        .font(.igSecondaryMeta)
                        .foregroundStyle(.hermesSecondaryText)
                }
            }
            .toggleStyle(.switch)
            .onChange(of: isClipboardHistoryMonitoringEnabled) { _, enabled in
                statusMessage = enabled ? "Clipboard monitoring enabled. Captured items are encrypted." : "Clipboard monitoring disabled. Encrypted history stays available after Face ID unlock."
            }

            if clipboardHistory.isLocked {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Protected clipboard history is locked from a previous session.")
                        .font(.igSecondaryMeta)
                        .foregroundStyle(.hermesSecondaryText)

                    Button {
                        unlockClipboardHistory()
                    } label: {
                        Label(isUnlockingClipboardHistory ? "Unlocking…" : "Unlock with Face ID", systemImage: "faceid")
                    }
                    .disabled(isUnlockingClipboardHistory)
                    .hermesGlassButton()
                }
            }

            HStack(spacing: 10) {
                Button {
                    if clipboardHistory.captureCurrentPasteboardIfNeeded(force: true) {
                        statusMessage = "Clipboard checked."
                    } else {
                        statusMessage = "Clipboard checked; no safe new item found."
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(clipboardHistory.isLocked)
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
                    clipboardHistory.isLocked ? "Clipboard history locked" : "No clipboard history yet",
                    systemImage: "clipboard",
                    description: Text(clipboardHistory.isLocked ? "Unlock with Face ID to restore encrypted clipboard items from the previous session." : "Enable monitoring or tap Refresh to capture safe clipboard items. Stored history is encrypted and requires Face ID after restart.")
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

    private func unlockClipboardHistory() {
        isUnlockingClipboardHistory = true
        defer { isUnlockingClipboardHistory = false }

        do {
            try clipboardHistory.unlockProtectedHistory()
            statusMessage = clipboardHistory.entries.isEmpty
                ? "Encrypted clipboard history unlocked; no saved items found."
                : "Unlocked \(clipboardHistory.entries.count) encrypted clipboard items."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    @ViewBuilder
    private var promptHistoryContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Messages history mode", selection: $messagesHistoryMode) {
                ForEach(HermesMessagesHistoryMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                Button(role: .destructive) {
                    switch messagesHistoryMode {
                    case .prompt:
                        promptHistory.clear()
                        promptHistoryStatusMessage = "Prompt history cleared."
                    case .response:
                        promptHistory.clearResponses()
                        promptHistoryStatusMessage = "Response history cleared."
                    }
                } label: {
                    Label("Clear", systemImage: "trash")
                }
                .disabled(isSelectedMessagesHistoryEmpty)
                .hermesGlassButton()
            }

            Text(promptHistoryStatusMessage)
                .font(.igSecondaryMeta)
                .foregroundStyle(.hermesSecondaryText)

            switch messagesHistoryMode {
            case .prompt:
                promptHistoryList
            case .response:
                responseHistoryList
            }
        }
        .padding(.top, 12)
    }

    private var isSelectedMessagesHistoryEmpty: Bool {
        switch messagesHistoryMode {
        case .prompt: promptHistory.entries.isEmpty
        case .response: promptHistory.responseEntries.isEmpty
        }
    }

    @ViewBuilder
    private var promptHistoryList: some View {
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
                            historyTrashIcon
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Delete prompt from history")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var responseHistoryList: some View {
        if promptHistory.responseEntries.isEmpty {
            ContentUnavailableView(
                "No response history yet",
                systemImage: "text.bubble",
                description: Text("Hermes responses from Ask Hermes and Chat with Hermes will appear here after requests complete.")
            )
            .frame(maxWidth: .infinity, minHeight: 220)
        } else {
            LazyVStack(spacing: 10) {
                ForEach(promptHistory.responseEntries) { entry in
                    HStack(alignment: .center, spacing: 10) {
                        Button {
                            promptHistory.copyResponseToPasteboard(entry)
                            promptHistoryStatusMessage = "Copied response to the clipboard."
                        } label: {
                            HermesResponseHistoryRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Copies this response back to the iOS clipboard")

                        Button(role: .destructive) {
                            promptHistory.deleteResponse(entry)
                            promptHistoryStatusMessage = "Deleted response from history."
                        } label: {
                            historyTrashIcon
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Delete response from history")
                    }
                }
            }
        }
    }

    private var historyTrashIcon: some View {
        Image(systemName: "trash")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.igDestructive)
            .frame(width: 38, height: 38)
            .hermesLiquidGlass(cornerRadius: 12, tint: Color.igDestructive.opacity(0.12), interactive: true)
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

private struct HermesResponseHistoryRow: View {
    let entry: HermesResponseHistoryEntry

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: entry.source.systemImage)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.igActionBlue)
                .frame(width: 72, height: 72)
                .background(Color.hermesSurfaceInput, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Label(entry.source.displayName, systemImage: "text.bubble")
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

private enum ClipboardProtectedStorageError: LocalizedError {
    case accessControlCreationFailed
    case encryptionFailed
    case faceIDUnavailable
    case keychain(OSStatus)
    case storageUnavailable

    var errorDescription: String? {
        switch self {
        case .accessControlCreationFailed:
            return "Could not create Face ID protection for clipboard history."
        case .encryptionFailed:
            return "Could not encrypt clipboard history."
        case .faceIDUnavailable:
            return "Face ID must be available and enrolled before encrypted clipboard history can be saved."
        case .keychain(let status):
            if status == errSecUserCanceled {
                return "Face ID authentication was canceled."
            }
            if status == errSecAuthFailed {
                return "Face ID authentication failed."
            }
            if status == errSecItemNotFound {
                return "The encrypted clipboard history key was not found."
            }
            return "Clipboard history Keychain operation failed with status \(status)."
        case .storageUnavailable:
            return "Encrypted clipboard history storage is unavailable."
        }
    }
}

private extension JSONEncoder {
    static var hermesClipboardHistory: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var hermesClipboardHistory: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

@Observable
final class HermesClipboardHistoryStore {
    private static let legacyDefaultsKey = "hermes.utilities.clipboardHistory.entries"
    private static let encryptedStorageFilename = "ClipboardHistory.v1.enc"
    private static let keychainService = "fr.dubertrand.HermesiOS.clipboardHistory"
    private static let keychainKeyAccount = "encryptedHistoryKey"
    private let maxEntries = 10
    private let maxStoredBytes = 25 * 1024 * 1024
    private var lastObservedChangeCount = UIPasteboard.general.changeCount
    private var encryptionKey: SymmetricKey?

    var entries: [HermesClipboardHistoryEntry] = []
    var hasProtectedHistory = false
    var isUnlocked = false
    var storageErrorMessage: String?

    var isLocked: Bool {
        hasProtectedHistory && !isUnlocked
    }

    init() {
        discardLegacyPersistedHistory()
        hasProtectedHistory = Self.encryptedStoreURL().map { FileManager.default.fileExists(atPath: $0.path) } ?? false
    }

    @MainActor
    func runMonitoringLoop(isEnabled: Bool) async {
        guard isEnabled, !isLocked else { return }
        _ = captureCurrentPasteboardIfNeeded(force: true)
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            _ = captureCurrentPasteboardIfNeeded()
        }
    }

    @MainActor
    @discardableResult
    func captureCurrentPasteboardIfNeeded(force: Bool = false) -> Bool {
        guard !isLocked else {
            storageErrorMessage = "Unlock encrypted clipboard history with Face ID before capturing new items."
            return false
        }
        let pasteboard = UIPasteboard.general
        guard force || pasteboard.changeCount != lastObservedChangeCount else { return false }
        lastObservedChangeCount = pasteboard.changeCount

        guard let entry = Self.entry(from: pasteboard, maxStoredBytes: maxStoredBytes) else { return false }
        insert(entry)
        return true
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
        deleteProtectedHistory()
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

    private func discardLegacyPersistedHistory() {
        UserDefaults.standard.removeObject(forKey: Self.legacyDefaultsKey)
    }

    private func persist() {
        guard !isLocked else { return }
        do {
            if entries.isEmpty {
                deleteProtectedHistory()
                return
            }

            let key = try loadOrCreateEncryptionKey()
            let data = try JSONEncoder.hermesClipboardHistory.encode(entries)
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else {
                throw ClipboardProtectedStorageError.encryptionFailed
            }
            guard let url = Self.encryptedStoreURL(createDirectory: true) else {
                throw ClipboardProtectedStorageError.storageUnavailable
            }
            try combined.write(to: url, options: [.atomic, .completeFileProtection])
            hasProtectedHistory = true
            isUnlocked = true
            storageErrorMessage = nil
        } catch {
            storageErrorMessage = error.localizedDescription
        }
    }

    func unlockProtectedHistory() throws {
        guard hasProtectedHistory else {
            isUnlocked = true
            storageErrorMessage = nil
            return
        }
        guard let url = Self.encryptedStoreURL(), FileManager.default.fileExists(atPath: url.path) else {
            hasProtectedHistory = false
            isUnlocked = true
            storageErrorMessage = nil
            return
        }

        do {
            let key = try loadEncryptionKey(reason: "Use Face ID to unlock encrypted clipboard history from the previous session.")
            let encryptedData = try Data(contentsOf: url)
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: key)
            entries = try JSONDecoder.hermesClipboardHistory.decode([HermesClipboardHistoryEntry].self, from: decryptedData)
            encryptionKey = key
            isUnlocked = true
            hasProtectedHistory = true
            storageErrorMessage = nil
        } catch {
            storageErrorMessage = error.localizedDescription
            throw error
        }
    }

    private func loadOrCreateEncryptionKey() throws -> SymmetricKey {
        if let encryptionKey { return encryptionKey }
        if hasProtectedHistory, Self.keychainKeyExists() {
            let key = try loadEncryptionKey(reason: "Use Face ID to update encrypted clipboard history.")
            encryptionKey = key
            return key
        }

        Self.deleteEncryptionKey()
        try Self.requireFaceIDAvailable()
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }
        try Self.saveEncryptionKey(keyData)
        encryptionKey = key
        return key
    }

    private func loadEncryptionKey(reason: String) throws -> SymmetricKey {
        try Self.requireFaceIDAvailable()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainKeyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseOperationPrompt as String: reason
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            throw ClipboardProtectedStorageError.keychain(status)
        }
        return SymmetricKey(data: data)
    }

    private func deleteProtectedHistory() {
        if let url = Self.encryptedStoreURL(), FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        Self.deleteEncryptionKey()
        encryptionKey = nil
        hasProtectedHistory = false
        isUnlocked = false
        storageErrorMessage = nil
    }

    private static func requireFaceIDAvailable() throws {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error), context.biometryType == .faceID else {
            throw ClipboardProtectedStorageError.faceIDUnavailable
        }
    }

    private static func saveEncryptionKey(_ data: Data) throws {
        guard let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            nil
        ) else {
            throw ClipboardProtectedStorageError.accessControlCreationFailed
        }

        deleteEncryptionKey()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainKeyAccount,
            kSecAttrAccessControl as String: accessControl,
            kSecValueData as String: data
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw ClipboardProtectedStorageError.keychain(status)
        }
    }

    private static func deleteEncryptionKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainKeyAccount
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func keychainKeyExists() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainKeyAccount,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        return status == errSecSuccess || status == errSecInteractionNotAllowed || status == errSecAuthFailed
    }

    private static func encryptedStoreURL(createDirectory: Bool = false) -> URL? {
        guard let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directory = applicationSupport.appendingPathComponent("HermesiOS", isDirectory: true)
        if createDirectory {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory.appendingPathComponent(encryptedStorageFilename)
    }

    private static func entry(from pasteboard: UIPasteboard, maxStoredBytes: Int) -> HermesClipboardHistoryEntry? {
        if let image = pasteboard.image,
           let data = image.pngData(),
           data.count <= maxStoredBytes {
            return HermesClipboardHistoryEntry(kind: .image, typeIdentifier: UTType.png.identifier, payload: data, displayName: "Clipboard image")
        }

        if let string = pasteboard.string, !string.isEmpty,
           !containsSensitiveText(string),
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
                if let text = String(data: data, encoding: .utf8), containsSensitiveText(text) { continue }
                return HermesClipboardHistoryEntry(kind: .file, typeIdentifier: typeIdentifier, payload: data, displayName: displayName(for: typeIdentifier))
            }

            if let url = value as? URL,
               url.isFileURL,
               !containsSensitiveFilename(url.lastPathComponent),
               let data = try? Data(contentsOf: url),
               data.count <= maxStoredBytes {
                if let text = String(data: data, encoding: .utf8), containsSensitiveText(text) { continue }
                return HermesClipboardHistoryEntry(kind: .file, typeIdentifier: typeIdentifier, payload: data, displayName: url.lastPathComponent)
            }
        }
        return nil
    }

    private static func isTextType(_ identifier: String) -> Bool {
        guard let type = UTType(identifier) else { return identifier.localizedCaseInsensitiveContains("text") }
        return type.conforms(to: .text)
    }

    private static func containsSensitiveText(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        let obviousMarkers = [
            "-----begin private key-----",
            "-----begin openSSH private key-----".lowercased(),
            "password=",
            "password:",
            "api_key",
            "apikey",
            "access_token",
            "auth_token",
            "bearer ",
            "secret=",
            "client_secret"
        ]
        if obviousMarkers.contains(where: { lowercased.contains($0) }) { return true }

        let patterns = [
            #"(?i)sk-[A-Za-z0-9_\-]{20,}"#,
            #"(?i)(xox[baprs]-)[A-Za-z0-9\-]{20,}"#,
            #"(?i)gh[pousr]_[A-Za-z0-9_]{20,}"#,
            #"(?i)[A-Za-z0-9_\-]{24,}\.[A-Za-z0-9_\-]{6,}\.[A-Za-z0-9_\-]{20,}"#
        ]
        return patterns.contains { text.range(of: $0, options: .regularExpression) != nil }
    }

    private static func containsSensitiveFilename(_ filename: String) -> Bool {
        let lowercased = filename.lowercased()
        return lowercased.contains("id_rsa")
            || lowercased.contains("id_ed25519")
            || lowercased.contains("private")
            || lowercased.contains("secret")
            || lowercased.hasSuffix(".key")
            || lowercased.hasSuffix(".p12")
            || lowercased.hasSuffix(".mobileprovision")
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

