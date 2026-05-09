//
//  HermesConsoleViews.swift
//  HermesiOS
//

import AVFoundation
import Observation
import Speech
import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension HermesPromptAttachment {
    static var supportedContentTypes: [UTType] {
        var types: [UTType] = [
            .pdf,
            .plainText,
            .text,
            .json,
            .sourceCode,
            .swiftSource
        ]

        for identifier in [
            "public.png",
            "public.jpeg",
            "com.compuserve.gif",
            "org.webmproject.webp",
            "public.yaml",
            "public.toml",
            "org.openxmlformats.wordprocessingml.document",
            "org.openxmlformats.presentationml.presentation",
            "org.openxmlformats.spreadsheetml.sheet"
        ] {
            if let type = UTType(identifier) {
                types.append(type)
            }
        }

        for extensionValue in Self.supportedFileExtensions {
            if let type = UTType(filenameExtension: extensionValue) {
                types.append(type)
            }
        }

        return Array(Set(types))
    }

    static func load(from url: URL) throws -> HermesPromptAttachment {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess { url.stopAccessingSecurityScopedResource() }
        }

        let resourceValues = try url.resourceValues(forKeys: [.contentTypeKey, .fileSizeKey, .nameKey])
        let filename = resourceValues.name ?? url.lastPathComponent
        let data = try Data(contentsOf: url)
        return try HermesPromptAttachment(filename: filename, contentType: resourceValues.contentType, data: data)
    }
}

private struct HermesAttachmentChip: View {
    let attachment: HermesPromptAttachment
    let remove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: attachment.isImage ? "photo" : "doc.text")
                .foregroundStyle(.igActionBlue)
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.filename)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text("\(attachment.mimeType) · \(attachment.formattedByteCount)")
                    .font(.caption2)
                    .foregroundStyle(.hermesSecondaryText)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button(action: remove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove attachment")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .hermesLiquidGlass(cornerRadius: 14, tint: Color.igActionBlue.opacity(0.08))
    }
}

@MainActor
@Observable
final class HermesSpeechTranscriptionSession {
    var isRecording = false
    var liveText = ""
    var composedText = ""
    var statusMessage = ""
    var lastErrorMessage = ""

    private var audioEngine: AVAudioEngine?
    private var analyzer: SpeechAnalyzer?
    private var transcriber: DictationTranscriber?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var analyzerTask: Task<Void, Never>?
    private var resultsTask: Task<Void, Never>?
    private var audioConverter: AVAudioConverter?
    private var analyzerAudioFormat: AVAudioFormat?
    private var onTextChange: ((String) -> Void)?

    func toggle(seedText: String, onTextChange: @escaping (String) -> Void) {
        if isRecording {
            stop()
        } else {
            start(seedText: seedText, onTextChange: onTextChange)
        }
    }

    func start(seedText: String, onTextChange: @escaping (String) -> Void) {
        guard !isRecording else { return }
        self.onTextChange = onTextChange
        liveText = ""
        composedText = seedText
        lastErrorMessage = ""
        statusMessage = "Requesting speech access…"

        Task {
            do {
                try await requestPermissions()
                try await beginRecognition(seedText: seedText)
            } catch {
                self.lastErrorMessage = error.localizedDescription
                self.statusMessage = "Dictation unavailable"
                self.finishRecognition(status: nil, cancelAnalysis: true)
            }
        }
    }

    func stop() {
        guard isRecording else {
            clearInactiveStatus()
            return
        }
        finishRecognition(status: liveText.isEmpty ? "Dictation stopped — no speech recognized" : "Dictation stopped")
    }

    func clearInactiveStatus() {
        guard !isRecording else { return }
        statusMessage = ""
        lastErrorMessage = ""
    }

    func updateSeedText(_ text: String) {
        composedText = merge(seedText: text, transcription: liveText)
    }

    private func finishRecognition(status: String? = nil, cancelAnalysis: Bool = false) {
        if audioEngine?.isRunning == true {
            audioEngine?.stop()
        }
        audioEngine?.inputNode.removeTap(onBus: 0)
        inputContinuation?.finish()
        inputContinuation = nil

        if cancelAnalysis {
            analyzerTask?.cancel()
            resultsTask?.cancel()
        }
        analyzerTask = nil
        resultsTask = nil

        let analyzerToFinish = analyzer
        analyzer = nil
        transcriber = nil
        audioEngine = nil
        audioConverter = nil
        analyzerAudioFormat = nil
        isRecording = false

        Task {
            if cancelAnalysis {
                await analyzerToFinish?.cancelAndFinishNow()
            } else {
                try? await analyzerToFinish?.finalizeAndFinishThroughEndOfInput()
            }
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        if let status {
            statusMessage = status
        } else if statusMessage.hasPrefix("Listening") {
            statusMessage = "Dictation stopped"
        }
    }

    private func requestPermissions() async throws {
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else {
            throw HermesSpeechError.speechNotAuthorized
        }

        let audioSession = AVAudioSession.sharedInstance()
        let recordPermission = await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                audioSession.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
        guard recordPermission else {
            throw HermesSpeechError.microphoneNotAuthorized
        }
    }

    private func beginRecognition(seedText: String) async throws {
        guard let locale = await DictationTranscriber.supportedLocale(equivalentTo: Locale.current)
        else {
            throw HermesSpeechError.recognizerUnavailable
        }

        let transcriber = DictationTranscriber(locale: locale, preset: .progressiveLongDictation)
        let modules: [any SpeechModule] = [transcriber]
        statusMessage = "Preparing dictation…"

        if let installationRequest = try await AssetInventory.assetInstallationRequest(supporting: modules) {
            statusMessage = "Installing dictation assets…"
            try await installationRequest.downloadAndInstall()
        }

        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let preferredFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: modules, considering: inputFormat) ?? inputFormat
        analyzerAudioFormat = preferredFormat

        let analyzer = SpeechAnalyzer(modules: modules)
        try await analyzer.prepareToAnalyze(in: preferredFormat)

        let (inputStream, continuation) = AsyncStream.makeStream(of: AnalyzerInput.self, bufferingPolicy: .bufferingNewest(12))
        self.inputContinuation = continuation
        self.analyzer = analyzer
        self.transcriber = transcriber

        resultsTask = Task { [weak self, transcriber] in
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    await MainActor.run {
                        self?.applyTranscriptionText(text, seedText: seedText)
                    }
                }
            } catch {
                await MainActor.run {
                    self?.lastErrorMessage = error.localizedDescription
                    self?.statusMessage = "Dictation failed"
                    self?.finishRecognition(status: nil, cancelAnalysis: true)
                }
            }
        }

        analyzerTask = Task { [weak self, analyzer] in
            do {
                let lastSampleTime = try await analyzer.analyzeSequence(inputStream)
                if let lastSampleTime {
                    try await analyzer.finalizeAndFinish(through: lastSampleTime)
                }
            } catch {
                await MainActor.run {
                    self?.lastErrorMessage = error.localizedDescription
                    self?.statusMessage = "Dictation failed"
                    self?.finishRecognition(status: nil, cancelAnalysis: true)
                }
            }
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            Task { @MainActor in
                self?.appendAudioBuffer(buffer)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
        statusMessage = "Listening… speak now"
    }

    private func appendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let inputContinuation else { return }
        guard let converted = convertBufferForAnalyzer(buffer) else { return }
        inputContinuation.yield(AnalyzerInput(buffer: converted))
        if liveText.isEmpty {
            statusMessage = "Listening… microphone audio received"
        }
    }

    private func convertBufferForAnalyzer(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let targetFormat = analyzerAudioFormat else { return buffer }
        guard !buffer.format.isCompatibleForHermesSpeechAnalyzer(with: targetFormat) else { return buffer }

        if audioConverter == nil {
            audioConverter = AVAudioConverter(from: buffer.format, to: targetFormat)
        }
        guard let audioConverter else { return nil }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let frameCapacity = AVAudioFrameCount(max(1, Double(buffer.frameLength) * ratio).rounded(.up))
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCapacity) else { return nil }

        var didProvideInput = false
        var conversionError: NSError?
        audioConverter.convert(to: convertedBuffer, error: &conversionError) { _, status in
            if didProvideInput {
                status.pointee = .noDataNow
                return nil
            }
            didProvideInput = true
            status.pointee = .haveData
            return buffer
        }

        if let conversionError {
            lastErrorMessage = conversionError.localizedDescription
            return nil
        }
        return convertedBuffer.frameLength > 0 ? convertedBuffer : nil
    }

    private func applyTranscriptionText(_ transcription: String, seedText: String) {
        let composed = merge(seedText: seedText, transcription: transcription)
        liveText = transcription
        composedText = composed
        onTextChange?(composed)
        statusMessage = transcription.isEmpty ? "Listening…" : "Dictating: \(transcription)"
    }

    private func merge(seedText: String, transcription: String) -> String {
        let base = seedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let spoken = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else { return spoken }
        guard !spoken.isEmpty else { return base }
        return base + "\n" + spoken
    }
}

private extension AVAudioFormat {
    func isCompatibleForHermesSpeechAnalyzer(with other: AVAudioFormat) -> Bool {
        sampleRate == other.sampleRate
            && channelCount == other.channelCount
            && commonFormat == other.commonFormat
            && isInterleaved == other.isInterleaved
    }
}

private enum HermesSpeechError: LocalizedError {
    case speechNotAuthorized
    case microphoneNotAuthorized
    case recognizerUnavailable

    var errorDescription: String? {
        switch self {
        case .speechNotAuthorized:
            return "Speech recognition permission is required to dictate prompts."
        case .microphoneNotAuthorized:
            return "Microphone permission is required to dictate prompts."
        case .recognizerUnavailable:
            return "Apple speech recognizer is not currently available."
        }
    }
}

private struct HermesMicrophoneButton: View {
    let speechSession: HermesSpeechTranscriptionSession
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: speechSession.isRecording ? "mic.fill" : "mic")
                .font(.headline)
                .frame(width: 42, height: 42)
                .foregroundStyle(speechSession.isRecording ? Color.igDestructive : Color.primary)
        }
        .hermesGlassButton()
        .disabled(isDisabled)
        .accessibilityLabel(speechSession.isRecording ? "Stop dictation" : "Start dictation")
    }
}

struct HermesResponsesConsoleView: View {
    @Binding var apiSettings: HermesAPISettings
    @Binding var requestDraft: HermesRequestDraft
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession
    @Bindable var responseSession: HermesResponsesSession
    let responseWorkspaces: [HermesResponsesWorkspace]
    let workspaceNumber: Int
    let workspaceCount: Int
    let canCreateWorkspace: Bool
    let onCreateWorkspace: () -> Void
    let onSelectWorkspace: (Int) -> Void
    @State private var apiProfiles: [HermesAPIProfile] = []
    @State private var selectedAttachment: HermesPromptAttachment?
    @State private var isImportingAttachment = false
    @State private var speechSession = HermesSpeechTranscriptionSession()
    @State private var promptText = ""

    var body: some View {
        VStack(spacing: 0) {
            HermesGlassEffectContainer(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 12) {
                        HermesTabHeader("Ask Hermes", systemImage: "dot.radiowaves.left.and.right")

                        Spacer(minLength: 8)

                        responseWorkspaceSwitcher
                    }

                    HStack(alignment: .top, spacing: 12) {
                        HermesProfileSelector(
                            selectedProfile: $requestDraft.profile,
                            apiProfiles: apiProfiles,
                            lockedProfile: responseSession.activeProfile,
                            isDisabled: responseSession.isSending
                        ) { newProfile in
                            if responseSession.activeProfile != newProfile {
                                responseSession.terminateAndStartNewSession()
                            }
                        }

                        HermesStatusRow(
                            items: [
                                .init(title: "Session", value: responseSession.displaySessionTitle, accent: .igGradPurple, marqueeCharacterLimit: 40),
                                .init(title: "Status", value: responseSession.connectionStatus, accent: .igGradOrange)
                            ]
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top)
            }

            responseTranscript
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            responseComposer
        }
        .background(Color.hermesCanvas)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: apiSettings.baseURL) {
            if promptText.isEmpty {
                promptText = requestDraft.userPrompt
            }
            await refreshAPIProfiles()
        }
        .onChange(of: apiSettings) { _, _ in
            Task { await refreshAPIProfiles() }
        }
        .onChange(of: promptText) { _, text in
            requestDraft.userPrompt = text
            speechSession.clearInactiveStatus()
        }
        .onChange(of: speechSession.composedText) { _, text in
            promptText = text
            requestDraft.userPrompt = text
        }
        .fileImporter(
            isPresented: $isImportingAttachment,
            allowedContentTypes: HermesPromptAttachment.supportedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleAttachmentImport(result)
        }
    }

    private var responseWorkspaceSwitcher: some View {
        HStack(spacing: 8) {
            Button(action: onCreateWorkspace) {
                Image(systemName: "plus")
                    .font(.headline.weight(.semibold))
                    .frame(width: 34, height: 34)
            }
            .hermesGlassButton()
            .disabled(!canCreateWorkspace)
            .accessibilityLabel("New Hermes request screen")

            ForEach(responseWorkspaceSwitcherWorkspaces) { workspace in
                Button {
                    onSelectWorkspace(workspace.number)
                } label: {
                    Text("\(workspace.number)")
                        .font(.subheadline.weight(.bold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .foregroundStyle(workspaceButtonForeground(for: workspace))
                .background(
                    WorkspaceSwitcherButtonBackground(
                        workspace: workspace,
                        isSelected: workspace.number == workspaceNumber
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(Color.white.opacity(workspace.number == workspaceNumber || workspace.isStreamingActive || workspace.attention != nil ? 0 : 0.12), lineWidth: 1)
                )
                .accessibilityLabel("Open Hermes request screen \(workspace.number)")
            }
        }
    }

    private var responseWorkspaceSwitcherWorkspaces: [HermesResponsesWorkspace] {
        let sorted = responseWorkspaces.sorted { $0.number < $1.number }
        return sorted.isEmpty ? [] : sorted
    }

    private func workspaceButtonForeground(for workspace: HermesResponsesWorkspace) -> Color {
        workspace.number == workspaceNumber || workspace.isStreamingActive || workspace.attention != nil ? .white : .primary
    }

    private struct WorkspaceSwitcherButtonBackground: View {
        let workspace: HermesResponsesWorkspace
        let isSelected: Bool

        var body: some View {
            if workspace.isStreamingActive {
                TimelineView(.animation(minimumInterval: 0.2)) { context in
                    let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4) / 2.4
                    let opacity = 0.42 + (0.46 * (0.5 + 0.5 * sin(phase * 2 * .pi)))
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(Color.igGradOrange.opacity(opacity))
                }
            } else {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(staticColor)
            }
        }

        private var staticColor: Color {
            switch workspace.attention {
            case .completed:
                return .igOnlineGreen
            case .failed:
                return .igDestructive
            case nil:
                return isSelected ? .igActionBlue : Color.hermesSurfaceInput.opacity(0.72)
            }
        }
    }

    private var responseTranscript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if responseSession.entries.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Start a Responses session", systemImage: "bubble.left.and.bubble.right")
                                .font(.headline)
                            Text("Enter a prompt below. Your prompts and Hermes replies will appear here as chat bubbles for this session.")
                                .font(.subheadline)
                                .foregroundStyle(.hermesSecondaryText)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .hermesLiquidGlass(cornerRadius: 22, tint: Color.igActionBlue.opacity(0.06))
                    } else {
                        ForEach(responseSession.entries) { message in
                            HermesResponseBubble(
                                message: message,
                                isResponding: isResponsePlaceholder(message)
                            )
                                .id(message.id)
                        }
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(Self.transcriptBottomID)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .onAppear {
                scrollToLatest(proxy, animated: false)
            }
            .onChange(of: responseSession.entries.count) { _, _ in
                scrollToLatest(proxy)
            }
            .onChange(of: responseSession.streamedText) { _, _ in
                scrollToLatest(proxy)
            }
        }
    }

    private var responseComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            if hasResponseComposerControls {
                HStack(spacing: 10) {
                    Spacer()

                    if canResumeLastResponseSession {
                        Button {
                            responseSession.resumeLastKnownResponseSession()
                        } label: {
                            Label("Resume last", systemImage: "arrow.uturn.forward.circle")
                        }
                        .hermesGlassButton()
                        .disabled(responseSession.isSending)
                    }

                    if responseSession.hasActiveConversation {
                        Button {
                            responseSession.terminateAndStartNewSession()
                        } label: {
                            Label("End Session", systemImage: "xmark.circle")
                        }
                        .hermesGlassButton()
                    }

                    if responseSession.isSending {
                        Button("Cancel") {
                            responseSession.cancel()
                        }
                        .hermesGlassButton()
                    }
                }
            }

            if !responseSession.lastErrorMessage.isEmpty {
                Text(responseSession.lastErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.igDestructive)
            }

            if !speechSession.statusMessage.isEmpty || !speechSession.lastErrorMessage.isEmpty {
                Label(
                    speechSession.lastErrorMessage.isEmpty ? speechSession.statusMessage : speechSession.lastErrorMessage,
                    systemImage: speechSession.isRecording ? "waveform" : "mic"
                )
                .font(.caption)
                .foregroundStyle(speechSession.lastErrorMessage.isEmpty ? Color.hermesSecondaryText : Color.igDestructive)
            }

            if let selectedAttachment {
                HermesAttachmentChip(attachment: selectedAttachment) {
                    self.selectedAttachment = nil
                }
                .disabled(responseSession.isSending)
            }

            HStack(alignment: .bottom, spacing: 12) {
                Button {
                    isImportingAttachment = true
                } label: {
                    Image(systemName: selectedAttachment == nil ? "paperclip" : "paperclip.circle.fill")
                        .font(.headline)
                        .frame(width: 42, height: 42)
                }
                .hermesGlassButton()
                .disabled(responseSession.isSending)
                .accessibilityLabel(selectedAttachment == nil ? "Attach file" : "Change attached file")

                TextEditor(text: $promptText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 72, maxHeight: 130)
                    .igFieldBackground()
                    .overlay(alignment: .topLeading) {
                        if promptText.isEmpty {
                            Text("Ask Hermes something...")
                                .foregroundStyle(.hermesSecondaryText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    }

                VStack(spacing: 8) {
                    HermesMicrophoneButton(
                        speechSession: speechSession,
                        isDisabled: responseSession.isSending
                    ) {
                        speechSession.toggle(seedText: promptText) { text in
                            promptText = text
                            requestDraft.userPrompt = text
                        }
                    }

                    Button {
                        speechSession.stop()
                        var submittedDraft = requestDraft
                        submittedDraft.userPrompt = promptText
                        let submittedAttachment = selectedAttachment
                        responseSession.submit(apiSettings: apiSettings, draft: submittedDraft, attachment: submittedAttachment)
                        promptText = ""
                        requestDraft.userPrompt = ""
                        selectedAttachment = nil
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.headline)
                            .frame(width: 42, height: 42)
                    }
                    .hermesGlassProminentButton()
                    .disabled((promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedAttachment == nil) || responseSession.isSending)
                    .accessibilityLabel("Send prompt")
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
    }

    private static let transcriptBottomID = "responses-transcript-bottom"

    private func scrollToLatest(_ proxy: ScrollViewProxy, animated: Bool = true) {
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(Self.transcriptBottomID, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(Self.transcriptBottomID, anchor: .bottom)
                DispatchQueue.main.async {
                    proxy.scrollTo(Self.transcriptBottomID, anchor: .bottom)
                }
            }
        }
    }

    private var canResumeLastResponseSession: Bool {
        let last = responseSession.lastKnownResponseID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !last.isEmpty else { return false }
        return responseSession.previousResponseID != last && responseSession.latestResponseID != last
    }

    private var hasResponseComposerControls: Bool {
        canResumeLastResponseSession || responseSession.hasActiveConversation || responseSession.isSending
    }

    private func isResponsePlaceholder(_ message: HermesResponseMessage) -> Bool {
        responseSession.isSending
            && message.role != "user"
            && message.content.isEmpty
            && responseSession.entries.last?.id == message.id
    }

    private func handleAttachmentImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                selectedAttachment = try HermesPromptAttachment.load(from: url)
                responseSession.lastErrorMessage = ""
            } catch {
                responseSession.lastErrorMessage = error.localizedDescription
            }
        case .failure(let error):
            responseSession.lastErrorMessage = error.localizedDescription
        }
    }

    private func refreshAPIProfiles() async {
        do {
            let profiles = try await HermesAPIProfilesClient.fetchProfiles(apiSettings: apiSettings)
            apiProfiles = profiles
            syncSelectedProfileWithAPIProfiles(profiles, selectedProfile: &requestDraft.profile)
        } catch {
            if apiProfiles.isEmpty {
                apiProfiles = []
            }
        }
    }

    private func syncSelectedProfileWithAPIProfiles(_ profiles: [HermesAPIProfile], selectedProfile: inout String) {
        let current = selectedProfile.trimmingCharacters(in: .whitespacesAndNewlines)
        if current.isEmpty {
            selectedProfile = profiles.first?.id ?? "default"
        } else if !profiles.isEmpty && !profiles.contains(where: { $0.id == current }) {
            selectedProfile = profiles.first?.id ?? "default"
        }
    }
}

private struct HermesProfileSelector: View {
    @Binding var selectedProfile: String
    let apiProfiles: [HermesAPIProfile]
    let lockedProfile: String
    let isDisabled: Bool
    let onProfileSelected: (String) -> Void

    private var currentProfile: String {
        let locked = lockedProfile.trimmingCharacters(in: .whitespacesAndNewlines)
        if !locked.isEmpty { return locked }
        let selected = selectedProfile.trimmingCharacters(in: .whitespacesAndNewlines)
        return selected.isEmpty ? "default" : selected
    }

    private var selection: Binding<String> {
        Binding(
            get: { currentProfile },
            set: { newValue in
                let profile = newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "default" : newValue
                selectedProfile = profile
                onProfileSelected(profile)
            }
        )
    }

    private var pickerProfiles: [HermesAPIProfile] {
        var seen = Set<String>()
        var unique = apiProfiles.filter { profile in
            let value = profile.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, !seen.contains(value) else { return false }
            seen.insert(value)
            return true
        }

        if !currentProfile.isEmpty, !seen.contains(currentProfile) {
            unique.insert(
                HermesAPIProfile(id: currentProfile, name: currentProfile, isDefault: currentProfile == "default", model: nil, provider: nil),
                at: 0
            )
        }

        if unique.isEmpty {
            unique.append(HermesAPIProfile(id: "default", name: "default", isDefault: true, model: nil, provider: nil))
        }

        return unique
    }

    private var currentProfileLabel: String {
        let activeID = currentProfile.trimmingCharacters(in: .whitespacesAndNewlines)
        if let profile = pickerProfiles.first(where: { $0.id == activeID }) {
            return label(for: profile)
        }
        return activeID.isEmpty ? "default" : activeID
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("PROFILE")
                .font(.igBadge)
                .tracking(0.6)
                .foregroundStyle(.hermesSecondaryText)

            Menu {
                ForEach(pickerProfiles) { profile in
                    Button(label(for: profile)) {
                        selection.wrappedValue = profile.id
                    }
                }
            } label: {
                Text(currentProfileLabel)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .tint(.primary)
            .disabled(isDisabled)
            .opacity(isDisabled ? 0.55 : 1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minWidth: 170, maxWidth: 260, alignment: .leading)
        .hermesLiquidGlass(cornerRadius: 18, tint: Color.igActionBlue.opacity(0.08), interactive: true)
        .accessibilityLabel("Choose Hermes profile")
    }

    private func label(for profile: HermesAPIProfile) -> String {
        let id = profile.id.trimmingCharacters(in: .whitespacesAndNewlines)
        return id.isEmpty ? "default" : id
    }
}

struct HermesResponseBubble: View {
    let message: HermesResponseMessage
    var isResponding = false

    var body: some View {
        HStack(alignment: .bottom) {
            if isUser { Spacer(minLength: 44) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                Text(isUser ? "You" : "Hermes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.hermesSecondaryText)

                HermesCopyableBubbleContent(
                    text: displayContent,
                    copyText: message.content,
                    isUser: isUser,
                    rendersMarkdown: !isUser,
                    isResponding: isResponding
                )
            }
            .frame(maxWidth: 620, alignment: isUser ? .trailing : .leading)

            if !isUser { Spacer(minLength: 44) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var isUser: Bool { message.role == "user" }

    private var displayContent: String {
        return message.content
    }
}

struct HermesChatBubble: View {
    let message: HermesChatMessage
    var liveContent: String? = nil
    var isResponding = false

    var body: some View {
        HStack(alignment: .bottom) {
            if isUser { Spacer(minLength: 44) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                Text(isUser ? "You" : "Hermes")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.hermesSecondaryText)

                HermesCopyableBubbleContent(
                    text: displayContent,
                    copyText: copyContent,
                    isUser: isUser,
                    rendersMarkdown: !isUser,
                    isResponding: isResponding
                )
            }
            .frame(maxWidth: 620, alignment: isUser ? .trailing : .leading)

            if !isUser { Spacer(minLength: 44) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var isUser: Bool { message.role == "user" }

    private var resolvedContent: String {
        let trimmedLiveContent = liveContent ?? ""
        return trimmedLiveContent.isEmpty ? message.content : trimmedLiveContent
    }

    private var displayContent: String {
        return resolvedContent
    }

    private var copyContent: String {
        resolvedContent
    }
}

private struct HermesBubbleMessageText: View {
    let text: String
    let rendersMarkdown: Bool

    var body: some View {
        if rendersMarkdown, let attributedText = try? AttributedString(markdown: text) {
            Text(attributedText)
        } else {
            Text(text)
        }
    }
}

private struct HermesBubbleImageAttachment: Identifiable, Equatable {
    let id = UUID()
    let source: String
    let altText: String

    var displayName: String {
        if !altText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return altText
        }
        if let url = URL(string: source), let lastComponent = url.pathComponents.last, !lastComponent.isEmpty {
            return lastComponent
        }
        if source.hasPrefix("data:") {
            return "Hermes image"
        }
        return URL(fileURLWithPath: source).lastPathComponent.isEmpty ? "Hermes image" : URL(fileURLWithPath: source).lastPathComponent
    }

    var fileExtension: String {
        if let mimeType = dataURLMimeType {
            switch mimeType.lowercased() {
            case "image/jpeg", "image/jpg": return "jpg"
            case "image/gif": return "gif"
            case "image/webp": return "webp"
            default: return "png"
            }
        }
        if let url = URL(string: source), !url.pathExtension.isEmpty {
            return url.pathExtension
        }
        let pathExtension = URL(fileURLWithPath: source).pathExtension
        return pathExtension.isEmpty ? "png" : pathExtension
    }

    var dataURLMimeType: String? {
        guard source.hasPrefix("data:"), let semicolon = source.firstIndex(of: ";") else { return nil }
        return String(source[source.index(source.startIndex, offsetBy: 5)..<semicolon])
    }

    func loadData() async throws -> Data {
        if source.hasPrefix("data:") {
            guard let comma = source.firstIndex(of: ",") else { throw HermesBubbleImageError.invalidImageSource }
            let encoded = String(source[source.index(after: comma)...])
            guard let data = Data(base64Encoded: encoded) else { throw HermesBubbleImageError.invalidImageSource }
            return data
        }

        if let url = URL(string: source), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        }

        let fileURL: URL
        if let url = URL(string: source), url.isFileURL {
            fileURL = url
        } else {
            fileURL = URL(fileURLWithPath: source)
        }
        return try Data(contentsOf: fileURL)
    }

    nonisolated static func extract(from text: String) -> (text: String, images: [HermesBubbleImageAttachment]) {
        var images: [HermesBubbleImageAttachment] = []
        var displayText = text

        let markdownPattern = #"!\[([^\]]*)\]\(([^\s\)]+)(?:\s+\"[^\"]*\")?\)"#
        if let regex = try? NSRegularExpression(pattern: markdownPattern) {
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, range: nsRange).reversed()
            for match in matches {
                guard
                    let fullRange = Range(match.range(at: 0), in: displayText),
                    let altRange = Range(match.range(at: 1), in: text),
                    let sourceRange = Range(match.range(at: 2), in: text)
                else { continue }
                let source = String(text[sourceRange]).trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
                if Self.isSupportedImageSource(source) {
                    images.insert(HermesBubbleImageAttachment(source: source, altText: String(text[altRange])), at: 0)
                    displayText.removeSubrange(fullRange)
                }
            }
        }

        let jsonImages = Self.extractJSONImages(from: displayText)
        if !jsonImages.isEmpty {
            for image in jsonImages where !images.contains(where: { $0.source == image.source }) {
                images.append(image)
            }
            displayText = ""
        }

        let tokenCandidates = displayText
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: CharacterSet(charactersIn: "<>()[]{}.,;\"'")) }
            .filter { Self.isSupportedImageSource($0) }
        for candidate in tokenCandidates where !images.contains(where: { $0.source == candidate }) {
            images.append(HermesBubbleImageAttachment(source: candidate, altText: ""))
        }

        return (displayText.trimmingCharacters(in: .whitespacesAndNewlines), images)
    }

    nonisolated private static func extractJSONImages(from text: String) -> [HermesBubbleImageAttachment] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let jsonText: String
        if trimmed.hasPrefix("```") {
            var lines = trimmed.components(separatedBy: .newlines)
            if lines.first?.hasPrefix("```") == true { lines.removeFirst() }
            if lines.last?.trimmingCharacters(in: .whitespacesAndNewlines) == "```" { lines.removeLast() }
            jsonText = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            jsonText = trimmed
        }

        guard let data = jsonText.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data)
        else { return [] }

        return extractJSONImages(from: object)
    }

    nonisolated private static func extractJSONImages(from object: Any) -> [HermesBubbleImageAttachment] {
        if let array = object as? [Any] {
            return array.flatMap(extractJSONImages(from:))
        }

        guard let dictionary = object as? [String: Any] else { return [] }
        var images: [HermesBubbleImageAttachment] = []

        if let base64 = dictionary["image_base64"] as? String, !base64.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let mimeType = (dictionary["mime_type"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? (dictionary["original_mime_type"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedMimeType = mimeType?.isEmpty == false ? mimeType! : "image/png"
            let source = "data:\(resolvedMimeType);base64,\(base64)"
            images.append(HermesBubbleImageAttachment(source: source, altText: "Hermes image"))
        }

        for nested in dictionary.values {
            for image in extractJSONImages(from: nested) where !images.contains(where: { $0.source == image.source }) {
                images.append(image)
            }
        }

        return images
    }

    nonisolated private static func isSupportedImageSource(_ source: String) -> Bool {
        let lowercased = source.lowercased()
        if lowercased.hasPrefix("data:image/") { return true }
        if lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") || lowercased.hasPrefix("file://") || lowercased.hasPrefix("/") {
            return [".png", ".jpg", ".jpeg", ".gif", ".webp"].contains { lowercased.contains($0) }
        }
        return false
    }
}

private enum HermesBubbleImageError: LocalizedError {
    case invalidImageSource

    var errorDescription: String? {
        "Could not load this image."
    }
}

private struct HermesCopyableBubbleContent: View {
    let text: String
    let copyText: String
    let isUser: Bool
    var rendersMarkdown = false
    var isResponding = false

    private var imageExtraction: (text: String, images: [HermesBubbleImageAttachment]) {
        guard !isUser else { return (text, []) }
        return HermesBubbleImageAttachment.extract(from: text)
    }

    var body: some View {
        let extracted = imageExtraction
        VStack(alignment: .leading, spacing: 10) {
            if isResponding && text.isEmpty && !isUser {
                HermesUndulatingDotsIndicator()
                    .accessibilityLabel("Hermes is responding")
            } else {
                if !extracted.text.isEmpty {
                    HermesBubbleMessageText(text: extracted.text, rendersMarkdown: rendersMarkdown)
                        .font(.body)
                        .foregroundStyle(isUser ? .white : .primary)
                        .textSelection(.enabled)
                }

                ForEach(extracted.images) { image in
                    HermesBubbleImageView(image: image)
                }
            }
        }
            .padding(.leading, 14)
            .padding(.trailing, 32)
            .padding(.top, 11)
            .padding(.bottom, 24)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isUser ? Color.igActionBlue : Color.hermesSurfaceInput)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(isUser ? Color.igActionBlue.opacity(0.45) : Color.hermesDivider.opacity(0.7), lineWidth: 1)
            )
            .overlay(alignment: .bottomTrailing) {
                if !copyText.isEmpty {
                    HermesBubbleCopyButton(text: copyText, isUserBubble: isUser)
                        .padding(.trailing, 8)
                        .padding(.bottom, 6)
                }
            }
    }
}

private struct HermesBubbleImageView: View {
    let image: HermesBubbleImageAttachment
    @State private var imageData: Data?
    @State private var statusMessage = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            imageContent
                .frame(maxWidth: 520, maxHeight: 360)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.hermesDivider.opacity(0.7), lineWidth: 1)
                )
                .task { await loadImageIfNeeded() }

            HStack(spacing: 8) {
                Label(image.displayName, systemImage: "photo")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.hermesSecondaryText)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button {
                    Task { await copyImage() }
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Copy image")

                Button {
                    Task { await downloadImage() }
                } label: {
                    Label("Download", systemImage: "arrow.down.circle")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Download image")
            }

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(.caption2)
                    .foregroundStyle(.hermesSecondaryText)
            }
        }
    }

    @ViewBuilder
    private var imageContent: some View {
        if let imageData, let platformImage = makePlatformImage(from: imageData) {
            platformImageView(platformImage)
                .resizable()
                .scaledToFit()
        } else if image.source.lowercased().hasPrefix("http"), let url = URL(string: image.source) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let loadedImage):
                    loadedImage
                        .resizable()
                        .scaledToFit()
                case .failure:
                    HermesBubbleImagePlaceholder(label: "Image unavailable")
                case .empty:
                    HermesBubbleImagePlaceholder(label: "Loading image…")
                @unknown default:
                    HermesBubbleImagePlaceholder(label: "Loading image…")
                }
            }
        } else {
            HermesBubbleImagePlaceholder(label: "Loading image…")
        }
    }

    private func loadImageIfNeeded() async {
        guard imageData == nil else { return }
        do {
            imageData = try await image.loadData()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func copyImage() async {
        do {
            let data: Data
            if let imageData {
                data = imageData
            } else {
                data = try await image.loadData()
                imageData = data
            }
            copyImageToClipboard(data)
            statusMessage = "Copied image"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func downloadImage() async {
        do {
            let data: Data
            if let imageData {
                data = imageData
            } else {
                data = try await image.loadData()
                imageData = data
            }
            let savedURL = try saveImageData(data)
            statusMessage = "Saved to \(savedURL.lastPathComponent)"
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func saveImageData(_ data: Data) throws -> URL {
        let baseDirectory: URL
#if canImport(UIKit)
        baseDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
#elseif canImport(AppKit)
        baseDirectory = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
#else
        baseDirectory = FileManager.default.temporaryDirectory
#endif
        let directory = baseDirectory.appendingPathComponent("Hermes Images", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = "hermes-image-\(Self.timestamp()).\(image.fileExtension)"
        let destination = directory.appendingPathComponent(filename)
        try data.write(to: destination, options: .atomic)
        return destination
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}

private struct HermesBubbleImagePlaceholder: View {
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.title2)
            Text(label)
                .font(.caption)
        }
        .foregroundStyle(.hermesSecondaryText)
        .frame(width: 260, height: 170)
        .background(Color.hermesCanvas.opacity(0.72))
    }
}

#if canImport(UIKit)
private func makePlatformImage(from data: Data) -> UIImage? { UIImage(data: data) }
private func platformImageView(_ image: UIImage) -> Image { Image(uiImage: image) }
#elseif canImport(AppKit)
private func makePlatformImage(from data: Data) -> NSImage? { NSImage(data: data) }
private func platformImageView(_ image: NSImage) -> Image { Image(nsImage: image) }
#endif

private struct HermesUndulatingDotsIndicator: View {
    private let dotCount = 3

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate

            HStack(spacing: 6) {
                ForEach(0..<dotCount, id: \.self) { index in
                    let phase = time * 4.0 - Double(index) * 0.55
                    let wave = (sin(phase) + 1.0) / 2.0

                    Image(systemName: "circle.fill")
                        .font(.system(size: 7, weight: .bold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.hermesSecondaryText)
                        .offset(y: CGFloat(-5.0 * wave))
                        .scaleEffect(0.78 + (0.22 * wave))
                        .opacity(0.45 + (0.45 * wave))
                }
            }
            .frame(width: 42, height: 20, alignment: .center)
        }
    }
}

private struct HermesBubbleCopyButton: View {
    let text: String
    let isUserBubble: Bool
    @State private var didCopy = false

    var body: some View {
        Button {
            copyToClipboard(text)
            didCopy = true
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.1))
                didCopy = false
            }
        } label: {
            Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 18, height: 18)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isUserBubble ? Color.white.opacity(0.82) : Color.hermesSecondaryText)
        .background(
            Circle()
                .fill(isUserBubble ? Color.white.opacity(0.16) : Color.hermesCanvas.opacity(0.72))
        )
        .accessibilityLabel(didCopy ? "Copied" : "Copy message")
        .disabled(text.isEmpty)
        .opacity(text.isEmpty ? 0.45 : 1)
    }
}

@MainActor
private func copyToClipboard(_ text: String) {
#if canImport(UIKit)
    UIPasteboard.general.string = text
#elseif canImport(AppKit)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
#endif
}

@MainActor
private func copyImageToClipboard(_ data: Data) {
#if canImport(UIKit)
    if let image = UIImage(data: data) {
        UIPasteboard.general.image = image
    }
#elseif canImport(AppKit)
    if let image = NSImage(data: data) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }
#endif
}

struct HermesChatConsoleView: View {
    @Binding var apiSettings: HermesAPISettings
    @Binding var chatDraft: HermesChatDraft
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession
    @Bindable var chatSession: HermesChatSession
    @State private var apiProfiles: [HermesAPIProfile] = []
    @State private var selectedAttachment: HermesPromptAttachment?
    @State private var isImportingAttachment = false
    @State private var speechSession = HermesSpeechTranscriptionSession()
    @State private var promptText = ""

    var body: some View {
        VStack(spacing: 0) {
            HermesGlassEffectContainer(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    HermesTabHeader("Chat with Hermes", systemImage: "text.bubble")

                    HStack(alignment: .top, spacing: 12) {
                        HermesProfileSelector(
                            selectedProfile: $chatDraft.profile,
                            apiProfiles: apiProfiles,
                            lockedProfile: chatSession.activeProfile,
                            isDisabled: chatSession.isSending
                        ) { newProfile in
                            if chatSession.activeProfile != newProfile {
                                chatSession.resetConversation()
                            }
                        }

                        HermesStatusRow(
                            items: [
                                .init(title: "Session", value: chatSession.displaySessionTitle, accent: .igActionBlue, marqueeCharacterLimit: 40),
                                .init(title: "Status", value: chatSession.connectionStatus, accent: .igGradOrange),
                            ]
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top)
            }

            chatTranscript
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            chatComposer
        }
        .background(Color.hermesCanvas)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: apiSettings.baseURL) {
            if promptText.isEmpty {
                promptText = chatDraft.userPrompt
            }
            await refreshAPIProfiles()
        }
        .onChange(of: apiSettings) { _, _ in
            Task { await refreshAPIProfiles() }
        }
        .onChange(of: promptText) { _, text in
            chatDraft.userPrompt = text
            speechSession.clearInactiveStatus()
        }
        .onChange(of: speechSession.composedText) { _, text in
            promptText = text
            chatDraft.userPrompt = text
        }
        .fileImporter(
            isPresented: $isImportingAttachment,
            allowedContentTypes: HermesPromptAttachment.supportedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleAttachmentImport(result)
        }
    }

    private var chatTranscript: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if chatSession.entries.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Start a Chat Completions session", systemImage: "bubble.left.and.bubble.right")
                                .font(.headline)
                            Text("Enter a prompt below. Your prompts and Hermes replies will appear here as chat bubbles for this session.")
                                .font(.subheadline)
                                .foregroundStyle(.hermesSecondaryText)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .hermesLiquidGlass(cornerRadius: 22, tint: Color.igActionBlue.opacity(0.06))
                    } else {
                        ForEach(chatSession.entries) { message in
                            HermesChatBubble(
                                message: message,
                                liveContent: liveContent(for: message),
                                isResponding: isChatPlaceholder(message)
                            )
                            .id(message.id)
                        }
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(Self.transcriptBottomID)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .onAppear {
                scrollToLatest(proxy, animated: false)
            }
            .onChange(of: chatSession.entries.count) { _, _ in
                scrollToLatest(proxy)
            }
            .onChange(of: chatSession.streamedText) { _, _ in
                scrollToLatest(proxy)
            }
        }
    }

    private var chatComposer: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Label("\(chatSession.eventCount) stream events received", systemImage: "timeline.selection")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.hermesSecondaryText)

                Spacer()

                if canResumeLastChatSession {
                    Button {
                        chatSession.resumeLastKnownChatSession()
                    } label: {
                        Label("Resume last", systemImage: "arrow.uturn.forward.circle")
                    }
                    .hermesGlassButton()
                    .disabled(chatSession.isSending)
                }

                if !chatSession.entries.isEmpty && !chatSession.isSending {
                    Button("New Chat") {
                        chatSession.resetConversation()
                    }
                    .hermesGlassButton()
                }

                if chatSession.isSending {
                    Button("Cancel") {
                        chatSession.cancel()
                    }
                    .hermesGlassButton()
                }
            }

            if !chatSession.lastErrorMessage.isEmpty {
                Text(chatSession.lastErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.igDestructive)
            }

            if !speechSession.statusMessage.isEmpty || !speechSession.lastErrorMessage.isEmpty {
                Label(
                    speechSession.lastErrorMessage.isEmpty ? speechSession.statusMessage : speechSession.lastErrorMessage,
                    systemImage: speechSession.isRecording ? "waveform" : "mic"
                )
                .font(.caption)
                .foregroundStyle(speechSession.lastErrorMessage.isEmpty ? Color.hermesSecondaryText : Color.igDestructive)
            }

            if let selectedAttachment {
                HermesAttachmentChip(attachment: selectedAttachment) {
                    self.selectedAttachment = nil
                }
                .disabled(chatSession.isSending)
            }

            HStack(alignment: .bottom, spacing: 12) {
                Button {
                    isImportingAttachment = true
                } label: {
                    Image(systemName: selectedAttachment == nil ? "paperclip" : "paperclip.circle.fill")
                        .font(.headline)
                        .frame(width: 42, height: 42)
                }
                .hermesGlassButton()
                .disabled(chatSession.isSending)
                .accessibilityLabel(selectedAttachment == nil ? "Attach file" : "Change attached file")

                TextEditor(text: $promptText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 72, maxHeight: 130)
                    .igFieldBackground()
                    .overlay(alignment: .topLeading) {
                        if promptText.isEmpty {
                            Text("Ask Hermes something...")
                                .foregroundStyle(.hermesSecondaryText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    }

                VStack(spacing: 8) {
                    HermesMicrophoneButton(
                        speechSession: speechSession,
                        isDisabled: chatSession.isSending
                    ) {
                        speechSession.toggle(seedText: promptText) { text in
                            promptText = text
                            chatDraft.userPrompt = text
                        }
                    }

                    Button {
                        speechSession.stop()
                        var submittedDraft = chatDraft
                        submittedDraft.userPrompt = promptText
                        let submittedAttachment = selectedAttachment
                        chatSession.submit(apiSettings: apiSettings, draft: submittedDraft, attachment: submittedAttachment)
                        promptText = ""
                        chatDraft.userPrompt = ""
                        selectedAttachment = nil
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.headline)
                            .frame(width: 42, height: 42)
                    }
                    .hermesGlassProminentButton()
                    .disabled((promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedAttachment == nil) || chatSession.isSending)
                    .accessibilityLabel("Send chat message")
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
    }

    private static let transcriptBottomID = "chat-transcript-bottom"

    private func scrollToLatest(_ proxy: ScrollViewProxy, animated: Bool = true) {
        DispatchQueue.main.async {
            if animated {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(Self.transcriptBottomID, anchor: .bottom)
                }
            } else {
                proxy.scrollTo(Self.transcriptBottomID, anchor: .bottom)
                DispatchQueue.main.async {
                    proxy.scrollTo(Self.transcriptBottomID, anchor: .bottom)
                }
            }
        }
    }

    private var canResumeLastChatSession: Bool {
        let last = chatSession.lastKnownChatSessionID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !last.isEmpty else { return false }
        return chatSession.activeChatSessionID != last
    }

    private func handleAttachmentImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                selectedAttachment = try HermesPromptAttachment.load(from: url)
                chatSession.lastErrorMessage = ""
            } catch {
                chatSession.lastErrorMessage = error.localizedDescription
            }
        case .failure(let error):
            chatSession.lastErrorMessage = error.localizedDescription
        }
    }

    private func isChatPlaceholder(_ message: HermesChatMessage) -> Bool {
        chatSession.isSending
            && message.role != "user"
            && resolvedLiveContent(for: message).isEmpty
            && message.id == chatSession.entries.last(where: { $0.role != "user" })?.id
    }

    private func liveContent(for message: HermesChatMessage) -> String? {
        let content = resolvedLiveContent(for: message)
        return content.isEmpty ? nil : content
    }

    private func resolvedLiveContent(for message: HermesChatMessage) -> String {
        guard chatSession.isSending,
              message.role != "user",
              message.id == chatSession.entries.last(where: { $0.role != "user" })?.id
        else { return "" }

        return chatSession.streamedText
    }

    private func refreshAPIProfiles() async {
        do {
            let profiles = try await HermesAPIProfilesClient.fetchProfiles(apiSettings: apiSettings)
            apiProfiles = profiles
            syncSelectedProfileWithAPIProfiles(profiles, selectedProfile: &chatDraft.profile)
        } catch {
            if apiProfiles.isEmpty {
                apiProfiles = []
            }
        }
    }

    private func syncSelectedProfileWithAPIProfiles(_ profiles: [HermesAPIProfile], selectedProfile: inout String) {
        let current = selectedProfile.trimmingCharacters(in: .whitespacesAndNewlines)
        if current.isEmpty {
            selectedProfile = profiles.first?.id ?? "default"
        } else if !profiles.isEmpty && !profiles.contains(where: { $0.id == current }) {
            selectedProfile = profiles.first?.id ?? "default"
        }
    }
}
