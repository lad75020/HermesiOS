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
    var statusMessage = ""
    var lastErrorMessage = ""

    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
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
        liveText = seedText
        lastErrorMessage = ""
        statusMessage = "Requesting speech access…"

        Task {
            do {
                try await requestPermissions()
                try beginRecognition(seedText: seedText)
            } catch {
                self.lastErrorMessage = error.localizedDescription
                self.statusMessage = "Dictation unavailable"
                self.stop()
            }
        }
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
        if statusMessage == "Listening…" {
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

    private func beginRecognition(seedText: String) throws {
        recognitionTask?.cancel()
        recognitionTask = nil

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw HermesSpeechError.recognizerUnavailable
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
        statusMessage = "Listening…"

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    let transcription = result.bestTranscription.formattedString
                    self.liveText = transcription
                    self.onTextChange?(self.merge(seedText: seedText, transcription: transcription))
                    if result.isFinal {
                        self.statusMessage = "Dictation complete"
                        self.stop()
                    }
                }

                if let error {
                    self.lastErrorMessage = error.localizedDescription
                    self.statusMessage = "Dictation failed"
                    self.stop()
                }
            }
        }
    }

    private func merge(seedText: String, transcription: String) -> String {
        let base = seedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let spoken = transcription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else { return spoken }
        guard !spoken.isEmpty else { return base }
        return base + "\n" + spoken
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
    @State private var apiServerModels: [HermesAPIServerModel] = []
    @State private var selectedAttachment: HermesPromptAttachment?
    @State private var isImportingAttachment = false
    @State private var speechSession = HermesSpeechTranscriptionSession()

    var body: some View {
        VStack(spacing: 0) {
            HermesGlassEffectContainer(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    HermesTabHeader("Responses API", systemImage: "dot.radiowaves.left.and.right")

                    HStack(alignment: .top, spacing: 12) {
                        HermesModelSelector(
                            selectedModel: $requestDraft.model,
                            apiModels: apiServerModels,
                            isEnabled: !responseSession.hasActiveConversation,
                            lockedModel: responseSession.activeModel,
                            fallbackModel: "hermes-agent"
                        )

                        HermesStatusRow(
                            items: [
                                .init(title: "Thread", value: responseSession.previousResponseID.isEmpty ? "New response" : "Continuing thread", accent: .igGradPurple),
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
            await refreshAPIServerModels()
        }
        .onChange(of: apiSettings) { _, _ in
            Task { await refreshAPIServerModels() }
        }
        .fileImporter(
            isPresented: $isImportingAttachment,
            allowedContentTypes: HermesPromptAttachment.supportedContentTypes,
            allowsMultipleSelection: false
        ) { result in
            handleAttachmentImport(result)
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
                            HermesResponseBubble(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
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

                TextEditor(text: $requestDraft.userPrompt)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 72, maxHeight: 130)
                    .igFieldBackground()
                    .overlay(alignment: .topLeading) {
                        if requestDraft.userPrompt.isEmpty {
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
                        speechSession.toggle(seedText: requestDraft.userPrompt) { text in
                            requestDraft.userPrompt = text
                        }
                    }

                    Button {
                        speechSession.stop()
                        let submittedDraft = requestDraft
                        let submittedAttachment = selectedAttachment
                        responseSession.submit(apiSettings: apiSettings, draft: submittedDraft, attachment: submittedAttachment)
                        requestDraft.userPrompt = ""
                        selectedAttachment = nil
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.headline)
                            .frame(width: 42, height: 42)
                    }
                    .hermesGlassProminentButton()
                    .disabled((requestDraft.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedAttachment == nil) || responseSession.isSending)
                    .accessibilityLabel("Send prompt")
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        guard let lastID = responseSession.entries.last?.id else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastID, anchor: .bottom)
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

    private func refreshAPIServerModels() async {
        do {
            let models = try await HermesAPIServerModelsClient.fetchModels(apiSettings: apiSettings)
            apiServerModels = models
            syncSelectedModelWithAPIServerModels(models, selectedModel: &requestDraft.model)
        } catch {
            if apiServerModels.isEmpty {
                apiServerModels = []
            }
        }
    }

    private func syncSelectedModelWithAPIServerModels(_ models: [HermesAPIServerModel], selectedModel: inout String) {
        guard let firstModel = models.first?.id else { return }
        let current = selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if current.isEmpty || !models.contains(where: { $0.id == current }) {
            selectedModel = firstModel
        }
    }
}

private struct HermesModelSelector: View {
    @Binding var selectedModel: String
    let apiModels: [HermesAPIServerModel]
    let isEnabled: Bool
    let lockedModel: String
    let fallbackModel: String

    private var currentModel: String {
        let locked = lockedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !locked.isEmpty { return locked }
        let selected = selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return selected.isEmpty ? fallbackModel : selected
    }

    private var selection: Binding<String> {
        Binding(
            get: { currentModel },
            set: { selectedModel = $0 }
        )
    }

    private var pickerModels: [HermesAPIServerModel] {
        var seen = Set<String>()
        var unique = apiModels.filter { model in
            let value = model.id.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, !seen.contains(value) else { return false }
            seen.insert(value)
            return true
        }

        if !currentModel.isEmpty, !seen.contains(currentModel) {
            unique.insert(
                HermesAPIServerModel(id: currentModel, object: "model", ownedBy: nil),
                at: 0
            )
        }

        return unique
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("MODEL")
                .font(.igBadge)
                .tracking(0.6)
                .foregroundStyle(.hermesSecondaryText)

            Picker("Model", selection: selection) {
                ForEach(pickerModels) { model in
                    Text(label(for: model)).tag(model.id)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .disabled(!isEnabled)
            .font(.igUsername)
            .lineLimit(1)
            .tint(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minWidth: 170, maxWidth: 260, alignment: .leading)
        .hermesLiquidGlass(cornerRadius: 18, tint: Color.igActionBlue.opacity(0.08), interactive: isEnabled)
        .opacity(isEnabled ? 1 : 0.72)
        .accessibilityLabel(isEnabled ? "Choose model" : "Model locked for this session")
    }

    private func label(for model: HermesAPIServerModel) -> String {
        let id = model.id.trimmingCharacters(in: .whitespacesAndNewlines)
        let owner = model.ownedBy?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return owner.isEmpty || owner == "hermes" ? id : "\(id) · \(owner)"
    }
}

struct HermesResponseBubble: View {
    let message: HermesResponseMessage

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
                    isUser: isUser
                )
            }
            .frame(maxWidth: 620, alignment: isUser ? .trailing : .leading)

            if !isUser { Spacer(minLength: 44) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var isUser: Bool { message.role == "user" }

    private var displayContent: String {
        if message.content.isEmpty, !isUser {
            return "…"
        }
        return message.content
    }
}

struct HermesChatBubble: View {
    let message: HermesChatMessage
    var liveContent: String? = nil

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
                    isUser: isUser
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
        if resolvedContent.isEmpty, !isUser {
            return "…"
        }
        return resolvedContent
    }

    private var copyContent: String {
        resolvedContent
    }
}

private struct HermesCopyableBubbleContent: View {
    let text: String
    let copyText: String
    let isUser: Bool

    var body: some View {
        Text(text)
            .font(.body)
            .foregroundStyle(isUser ? .white : .primary)
            .textSelection(.enabled)
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
                HermesBubbleCopyButton(text: copyText, isUserBubble: isUser)
                    .padding(.trailing, 8)
                    .padding(.bottom, 6)
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

struct HermesChatConsoleView: View {
    @Binding var apiSettings: HermesAPISettings
    @Binding var chatDraft: HermesChatDraft
    let companionSettings: HermesCompanionSettings
    @Bindable var companionEnrollment: HermesCompanionEnrollmentSession
    @Bindable var companionRuntime: HermesCompanionRuntimeSession
    @Bindable var chatSession: HermesChatSession
    @State private var apiServerModels: [HermesAPIServerModel] = []
    @State private var selectedAttachment: HermesPromptAttachment?
    @State private var isImportingAttachment = false
    @State private var speechSession = HermesSpeechTranscriptionSession()

    var body: some View {
        VStack(spacing: 0) {
            HermesGlassEffectContainer(spacing: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    HermesTabHeader("Chat Completions", systemImage: "text.bubble")

                    HStack(alignment: .top, spacing: 12) {
                        HermesModelSelector(
                            selectedModel: $chatDraft.model,
                            apiModels: apiServerModels,
                            isEnabled: chatSession.entries.isEmpty && !chatSession.isSending,
                            lockedModel: chatSession.activeModel,
                            fallbackModel: "hermes-agent"
                        )

                        HermesStatusRow(
                            items: [
                                .init(title: "History", value: "\(chatSession.entries.count) messages", accent: .igGradPurple),
                                .init(title: "Session", value: chatSession.activeChatSessionID.isEmpty ? "New chat" : "Continuing chat", accent: .igActionBlue),
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
            await refreshAPIServerModels()
        }
        .onChange(of: apiSettings) { _, _ in
            Task { await refreshAPIServerModels() }
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
                                liveContent: liveContent(for: message)
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
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

                TextEditor(text: $chatDraft.userPrompt)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 72, maxHeight: 130)
                    .igFieldBackground()
                    .overlay(alignment: .topLeading) {
                        if chatDraft.userPrompt.isEmpty {
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
                        speechSession.toggle(seedText: chatDraft.userPrompt) { text in
                            chatDraft.userPrompt = text
                        }
                    }

                    Button {
                        speechSession.stop()
                        let submittedDraft = chatDraft
                        let submittedAttachment = selectedAttachment
                        chatSession.submit(apiSettings: apiSettings, draft: submittedDraft, attachment: submittedAttachment)
                        chatDraft.userPrompt = ""
                        selectedAttachment = nil
                    } label: {
                        Image(systemName: "paperplane.fill")
                            .font(.headline)
                            .frame(width: 42, height: 42)
                    }
                    .hermesGlassProminentButton()
                    .disabled((chatDraft.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && selectedAttachment == nil) || chatSession.isSending)
                    .accessibilityLabel("Send chat message")
                }
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
    }

    private func scrollToLatest(_ proxy: ScrollViewProxy) {
        guard let lastID = chatSession.entries.last?.id else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(lastID, anchor: .bottom)
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

    private func liveContent(for message: HermesChatMessage) -> String? {
        guard chatSession.isSending,
              message.role != "user",
              message.id == chatSession.entries.last(where: { $0.role != "user" })?.id,
              !chatSession.streamedText.isEmpty
        else { return nil }

        return chatSession.streamedText
    }

    private func refreshAPIServerModels() async {
        do {
            let models = try await HermesAPIServerModelsClient.fetchModels(apiSettings: apiSettings)
            apiServerModels = models
            syncSelectedModelWithAPIServerModels(models, selectedModel: &chatDraft.model)
        } catch {
            if apiServerModels.isEmpty {
                apiServerModels = []
            }
        }
    }

    private func syncSelectedModelWithAPIServerModels(_ models: [HermesAPIServerModel], selectedModel: inout String) {
        guard let firstModel = models.first?.id else { return }
        let current = selectedModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if current.isEmpty || !models.contains(where: { $0.id == current }) {
            selectedModel = firstModel
        }
    }
}
