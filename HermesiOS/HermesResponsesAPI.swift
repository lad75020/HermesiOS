//
//  HermesResponsesAPI.swift
//  HermesiOS
//
//  Created by Codex on 04/05/2026.
//

import Foundation
import Observation
import UniformTypeIdentifiers

enum HermesImageJSONFormatter {
    nonisolated static func renderableImageMarkdown(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("image_base64") || trimmed.contains("b64_json") else { return nil }

        if let object = jsonObject(from: trimmed), let markdown = imageMarkdown(from: object) {
            return markdown
        }

        let mimeType = firstJSONStringValue(for: "mime_type", in: trimmed)
            ?? firstJSONStringValue(for: "original_mime_type", in: trimmed)
        let resolvedMimeType = mimeType?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? mimeType! : "image/png"
        let base64 = firstJSONStringValue(for: "image_base64", in: trimmed)
            ?? firstJSONStringValue(for: "b64_json", in: trimmed)
        guard let base64, !base64.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return markdown(source: "data:\(resolvedMimeType);base64,\(cleanBase64(base64))")
    }

    nonisolated private static func jsonObject(from text: String) -> Any? {
        let jsonText: String
        if text.hasPrefix("```") {
            var lines = text.components(separatedBy: .newlines)
            if lines.first?.hasPrefix("```") == true { lines.removeFirst() }
            if lines.last?.trimmingCharacters(in: .whitespacesAndNewlines) == "```" { lines.removeLast() }
            jsonText = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            jsonText = text
        }
        guard let data = jsonText.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }

    nonisolated private static func imageMarkdown(from object: Any) -> String? {
        if let array = object as? [Any] {
            return array.compactMap(imageMarkdown(from:)).first
        }
        guard let dictionary = object as? [String: Any] else { return nil }

        if let imageURL = dictionary["image_url"] as? [String: Any], let url = imageURL["url"] as? String, !url.isEmpty {
            return markdown(source: url)
        }
        if let url = dictionary["image_url"] as? String, !url.isEmpty {
            return markdown(source: url)
        }
        if let url = dictionary["url"] as? String, !url.isEmpty {
            return markdown(source: url)
        }
        let base64 = (dictionary["image_base64"] as? String) ?? (dictionary["b64_json"] as? String)
        if let base64, !base64.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let mimeType = (dictionary["mime_type"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? (dictionary["original_mime_type"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedMimeType = mimeType?.isEmpty == false ? mimeType! : "image/png"
            return markdown(source: "data:\(resolvedMimeType);base64,\(cleanBase64(base64))")
        }

        return dictionary.values.compactMap(imageMarkdown(from:)).first
    }

    nonisolated private static func markdown(source: String) -> String {
        "\n\n![Hermes image](\(source))"
    }

    nonisolated private static func firstJSONStringValue(for key: String, in text: String) -> String? {
        let escapedKey = NSRegularExpression.escapedPattern(for: key)
        let pattern = #""# + escapedKey + #""\s*:\s*"((?:\\.|[^"\\])*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return unescapeJSONStringFragment(String(text[range]))
    }

    nonisolated private static func unescapeJSONStringFragment(_ value: String) -> String {
        let wrapped = "\"\(value)\""
        if let data = wrapped.data(using: .utf8),
           let decoded = try? JSONSerialization.jsonObject(with: data) as? String {
            return decoded
        }
        return value
            .replacingOccurrences(of: #"\/"#, with: "/")
            .replacingOccurrences(of: #"\n"#, with: "\n")
            .replacingOccurrences(of: #"\r"#, with: "\r")
            .replacingOccurrences(of: #"\t"#, with: "\t")
            .replacingOccurrences(of: #"\""#, with: "\"")
            .replacingOccurrences(of: #"\\"#, with: #"\"#)
    }

    nonisolated private static func cleanBase64(_ value: String) -> String {
        value.filter { !$0.isWhitespace }
    }
}

enum HermesStreamTextFormatter {
    static func lineBreakAfterStatementDots(_ text: String) -> String {
        if let imageMarkdown = HermesImageJSONFormatter.renderableImageMarkdown(from: text) {
            return imageMarkdown
        }
        guard text.contains(".") else { return text }
        guard !looksLikeJSONPayload(text) else { return text }

        var formatted = ""
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            formatted.append(character)

            if character == "." {
                let previous = index > text.startIndex ? text[text.index(before: index)] : nil
                let nextIndex = text.index(after: index)
                let next = nextIndex < text.endIndex ? text[nextIndex] : nil

                if shouldInsertLineBreak(afterDotWithPrevious: previous, next: next) {
                    formatted.append("\n")
                }
            }

            index = text.index(after: index)
        }

        return formatted
    }

    private static func shouldInsertLineBreak(afterDotWithPrevious previous: Character?, next: Character?) -> Bool {
        if previous == "." || next == "." { return false }
        if next == "\n" || next == "\r" { return false }
        if let previous, let next, isDigit(previous), isDigit(next) { return false }
        return true
    }

    private static func isDigit(_ character: Character) -> Bool {
        character.unicodeScalars.allSatisfy { CharacterSet.decimalDigits.contains($0) }
    }

    private static func looksLikeJSONPayload(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{") || trimmed.hasPrefix("[") else { return false }
        return trimmed.contains("\":") || trimmed.contains("image_base64") || trimmed.contains("b64_json")
    }
}

struct HermesPromptAttachment: Equatable {
    let filename: String
    let mimeType: String
    let data: Data
    let fileExtension: String

    static let supportedFileExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp",
        "pdf", "docx", "pptx", "xlsx",
        "txt", "text", "json", "yaml", "yml", "toml", "swift"
    ]

    static let imageFileExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp"]
    static let utf8FileExtensions: Set<String> = ["txt", "text", "json", "yaml", "yml", "toml", "swift"]

    init(filename: String, contentType: UTType?, data: Data) throws {
        let normalizedName = filename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "attachment" : filename
        let ext = URL(fileURLWithPath: normalizedName).pathExtension.lowercased()
        guard Self.supportedFileExtensions.contains(ext) else {
            throw HermesAttachmentError.unsupportedFileType(ext.isEmpty ? normalizedName : ".\(ext)")
        }

        self.filename = normalizedName
        self.fileExtension = ext
        self.mimeType = Self.mimeType(forExtension: ext, contentType: contentType)
        self.data = data
    }

    var isImage: Bool {
        Self.imageFileExtensions.contains(fileExtension)
    }

    var isUTF8Text: Bool {
        Self.utf8FileExtensions.contains(fileExtension)
    }

    var formattedByteCount: String {
        ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
    }

    var base64DataURL: String {
        "data:\(mimeType);base64,\(data.base64EncodedString())"
    }

    var textContent: String? {
        guard isUTF8Text else { return nil }
        return String(data: data, encoding: .utf8)
    }

    var textAttachmentBlock: String {
        if let textContent {
            return """

Attached file: \(filename) (\(mimeType), \(formattedByteCount))
```\(fileExtension)
\(textContent)
```
"""
        }

        return """

Attached file: \(filename) (\(mimeType), \(formattedByteCount))
The file is provided as a base64 data URL. Decode it if you need to inspect or process the document bytes:
\(base64DataURL)
"""
    }

    private static func mimeType(forExtension ext: String, contentType: UTType?) -> String {
        if let preferred = contentType?.preferredMIMEType, !preferred.isEmpty {
            return preferred
        }

        switch ext {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "pdf": return "application/pdf"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "json": return "application/json"
        case "yaml", "yml": return "application/yaml"
        case "toml": return "application/toml"
        case "swift": return "text/x-swift"
        default: return "text/plain"
        }
    }
}

enum HermesAttachmentError: LocalizedError {
    case unsupportedFileType(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType(let type):
            return "Unsupported attachment type: \(type). Choose an image, PDF, Office document, text, JSON, YAML, TOML, or Swift file."
        }
    }
}

final class HermesNetworkSessionDelegate: NSObject, URLSessionDelegate {
    private let allowSelfSignedCertificates: Bool

    init(allowSelfSignedCertificates: Bool) {
        self.allowSelfSignedCertificates = allowSelfSignedCertificates
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard
            allowSelfSignedCertificates,
            challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let trust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}

enum HermesNetworkSessionFactory {
    static func session(for apiSettings: HermesAPISettings) -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 3600

        if apiSettings.allowSelfSignedCertificates {
            let delegate = HermesNetworkSessionDelegate(
                allowSelfSignedCertificates: apiSettings.allowSelfSignedCertificates
            )
            return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
        }

        return URLSession(configuration: configuration)
    }
}

enum HermesRequestFailureClassifier {
    static func isTimeoutOrNetworkLoss(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return isTimeoutOrNetworkLoss(urlError.code)
        }

        if case HermesResponsesError.httpError(let statusCode) = error {
            return isTimeoutHTTPStatus(statusCode)
        }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return isTimeoutOrNetworkLoss(URLError.Code(rawValue: nsError.code))
        }

        return isTimeoutOrNetworkLoss(error.localizedDescription)
    }

    static func isTimeoutOrNetworkLoss(_ message: String) -> Bool {
        let normalized = message.lowercased()
        return normalized.contains("timed out")
            || normalized.contains("timeout")
            || normalized.contains("network connection was lost")
            || normalized.contains("network connection lost")
            || normalized.contains("not connected to the internet")
            || normalized.contains("internet connection appears to be offline")
            || normalized.contains("cannot connect to the host")
            || normalized.contains("could not connect to the server")
            || normalized.contains("cannot find host")
            || normalized.contains("dns")
            || normalized.contains("http 408")
            || normalized.contains("http 504")
    }

    private static func isTimeoutHTTPStatus(_ statusCode: Int) -> Bool {
        switch statusCode {
        case 408, 504:
            return true
        default:
            return false
        }
    }

    private static func isTimeoutOrNetworkLoss(_ code: URLError.Code) -> Bool {
        switch code {
        case .timedOut,
             .networkConnectionLost,
             .notConnectedToInternet,
             .cannotConnectToHost,
             .cannotFindHost,
             .dnsLookupFailed,
             .internationalRoamingOff,
             .dataNotAllowed:
            return true
        default:
            return false
        }
    }
}

@MainActor
@Observable
final class HermesResponsesSession {
    var entries: [HermesResponseMessage] = []
    var streamedText = ""
    var isSending = false
    var activeProfile = ""
    var connectionStatus = "Idle"
    var latestResponseID = ""
    var previousResponseID = ""
    var activeHermesSessionID = ""
    var lastKnownResponseID = ""
    var lastKnownResponseTitle = ""
    var lastErrorMessage = ""
    var lastErrorWasTimeoutOrNetworkLoss = false
    var latestMessageType = ""
    var eventCount = 0
    var rawStreamedJSON = ""
    var sessionTitle = ""

    var displaySessionTitle: String {
        let trimmedTitle = sessionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }
        return previousResponseID.isEmpty && activeHermesSessionID.isEmpty ? "New response" : "Continuing response"
    }

    var hasActiveConversation: Bool {
        !previousResponseID.isEmpty || !latestResponseID.isEmpty || !activeHermesSessionID.isEmpty || !entries.isEmpty || isSending
    }

    private var requestTask: Task<Void, Never>?
    private var activeAssistantEntryID: UUID?

    init() {
        lastKnownResponseID = HermesSettingsPersistence.loadLastResponsesSessionID()
        lastKnownResponseTitle = HermesSettingsPersistence.loadLastResponsesSessionTitle()
    }

    func submit(apiSettings: HermesAPISettings, draft: HermesRequestDraft, attachment: HermesPromptAttachment? = nil) {
        requestTask?.cancel()
        let requestedProfile = draft.profile.trimmingCharacters(in: .whitespacesAndNewlines)
        if activeProfile.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            activeProfile = requestedProfile.isEmpty ? "default" : requestedProfile
        }
        let lockedDraft = draft.locked(toProfile: activeProfile)
        requestTask = Task {
            await runRequest(apiSettings: apiSettings, draft: lockedDraft, attachment: attachment)
        }
    }

    func cancel() {
        requestTask?.cancel()
        requestTask = nil
        isSending = false
        connectionStatus = "Cancelled"
    }

    func resetConversation() {
        requestTask?.cancel()
        requestTask = nil
        entries = []
        streamedText = ""
        activeAssistantEntryID = nil
        isSending = false
        activeProfile = ""
        connectionStatus = "Idle"
        latestResponseID = ""
        previousResponseID = ""
        activeHermesSessionID = ""
        lastErrorMessage = ""
        lastErrorWasTimeoutOrNetworkLoss = false
        latestMessageType = ""
        eventCount = 0
        rawStreamedJSON = ""
        sessionTitle = ""
    }

    func terminateAndStartNewSession() {
        resetConversation()
        connectionStatus = "New session ready"
    }

    func resumeLastKnownResponseSession() {
        let sessionID = lastKnownResponseID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sessionID.isEmpty else {
            connectionStatus = "No previous session"
            return
        }

        requestTask?.cancel()
        requestTask = nil
        entries = [HermesResponseMessage(role: "assistant", content: "Resumed last Responses session \(Self.shortResponseID(sessionID)). Send a new prompt to continue.")]
        streamedText = ""
        activeAssistantEntryID = nil
        isSending = false
        latestResponseID = ""
        previousResponseID = sessionID
        activeHermesSessionID = ""
        lastErrorMessage = ""
        lastErrorWasTimeoutOrNetworkLoss = false
        latestMessageType = "resumed response"
        eventCount = 0
        rawStreamedJSON = ""
        sessionTitle = Self.userFriendlySessionTitle(from: lastKnownResponseTitle, fallback: "Last response")
        connectionStatus = "Resumed last response"
    }

    func resumeConversation(from result: HermesDashboardConversationResult) {
        requestTask?.cancel()
        requestTask = nil
        streamedText = ""
        activeAssistantEntryID = nil
        isSending = false
        latestResponseID = ""
        activeProfile = ""
        activeHermesSessionID = Self.hermesSessionID(from: result)
        let continuationID = Self.responseContinuationID(from: result)
        previousResponseID = continuationID
        persistLastResponseID(continuationID)
        lastErrorMessage = ""
        lastErrorWasTimeoutOrNetworkLoss = false
        latestMessageType = continuationID.isEmpty ? (activeHermesSessionID.isEmpty ? "loaded history" : "resumed session") : "resumed response"
        eventCount = 0
        rawStreamedJSON = ""

        let restoredEntries = result.messages
            .filter { message in
                let role = message.role.lowercased()
                return (role == "user" || role == "assistant") && !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            .map { message in
                HermesResponseMessage(role: message.role.lowercased(), content: message.content)
            }

        let displayTitle = result.sessionFriendlyName
        sessionTitle = Self.userFriendlySessionTitle(from: displayTitle, fallback: continuationID.isEmpty ? (activeHermesSessionID.isEmpty ? "Loaded history" : activeHermesSessionID) : continuationID)
        if !continuationID.isEmpty {
            persistLastResponseTitle(sessionTitle)
        }

        entries = restoredEntries.isEmpty
            ? [HermesResponseMessage(role: "assistant", content: "Loaded session \(displayTitle). Send a new prompt to start a new Responses API turn.")]
            : restoredEntries
        connectionStatus = continuationID.isEmpty ? (activeHermesSessionID.isEmpty ? "Loaded history" : "Resumed session") : "Resumed response"
    }

    private static func hermesSessionID(from result: HermesDashboardConversationResult) -> String {
        [result.sessionID, result.session.id]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? ""
    }

    private static func responseContinuationID(from result: HermesDashboardConversationResult) -> String {
        [result.sessionID, result.session.id]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { $0.hasPrefix("resp_") } ?? ""
    }

    private static func shortResponseID(_ responseID: String) -> String {
        guard responseID.count > 18 else { return responseID }
        return String(responseID.prefix(18)) + "…"
    }

    private static func userFriendlySessionTitle(from title: String, fallback: String) -> String {
        let normalized = title
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if !normalized.isEmpty {
            return normalized
        }

        let normalizedFallback = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalizedFallback.isEmpty ? "New response" : normalizedFallback
    }

    private func persistLastResponseID(_ responseID: String) {
        let trimmed = responseID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lastKnownResponseID = trimmed
        HermesSettingsPersistence.saveLastResponsesSessionID(trimmed)
    }

    private func persistLastResponseTitle(_ title: String) {
        let normalized = Self.userFriendlySessionTitle(from: title, fallback: "")
        guard !normalized.isEmpty else { return }
        lastKnownResponseTitle = normalized
        HermesSettingsPersistence.saveLastResponsesSessionTitle(normalized)
    }

    private func runRequest(apiSettings: HermesAPISettings, draft: HermesRequestDraft, attachment: HermesPromptAttachment?) async {
        let continuationID = previousResponseID
        let hermesSessionID = activeHermesSessionID
        let prompt = draft.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayPrompt = displayPrompt(prompt, attachment: attachment)
        if sessionTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sessionTitle = Self.userFriendlySessionTitle(from: prompt, fallback: attachment?.filename ?? "New response")
        }
        persistLastResponseTitle(sessionTitle)
        resetForRequest()
        appendExchange(prompt: displayPrompt)
        isSending = true
        connectionStatus = continuationID.isEmpty
            ? (draft.stream ? "Connecting to SSE stream" : "Sending request")
            : (draft.stream ? "Continuing SSE stream" : "Continuing request")

        do {
            try await HermesBackgroundActivity.run(named: "Hermes Responses Request") {
                if draft.stream {
                    try await streamResponse(apiSettings: apiSettings, draft: draft, attachment: attachment, previousResponseID: continuationID, hermesSessionID: hermesSessionID)
                } else {
                    try await fetchResponse(apiSettings: apiSettings, draft: draft, attachment: attachment, previousResponseID: continuationID, hermesSessionID: hermesSessionID)
                }
            }
            if !latestResponseID.isEmpty {
                previousResponseID = latestResponseID
                persistLastResponseID(latestResponseID)
            }
            if !Task.isCancelled {
                connectionStatus = "Completed"
            }
        } catch is CancellationError {
            connectionStatus = "Cancelled"
            updateActiveAssistantEntry(with: streamedText.isEmpty ? "Cancelled." : streamedText)
        } catch {
            lastErrorMessage = error.localizedDescription
            lastErrorWasTimeoutOrNetworkLoss = HermesRequestFailureClassifier.isTimeoutOrNetworkLoss(error)
            connectionStatus = "Failed"
            updateActiveAssistantEntry(with: streamedText.isEmpty ? "Request failed: \(error.localizedDescription)" : streamedText)
        }

        isSending = false
    }

    private func resetForRequest() {
        streamedText = ""
        latestResponseID = ""
        lastErrorMessage = ""
        lastErrorWasTimeoutOrNetworkLoss = false
        latestMessageType = ""
        eventCount = 0
        rawStreamedJSON = ""
        activeAssistantEntryID = nil
    }

    private func appendExchange(prompt: String) {
        guard !prompt.isEmpty else { return }
        entries.append(HermesResponseMessage(role: "user", content: prompt))
        let assistant = HermesResponseMessage(role: "assistant", content: "")
        activeAssistantEntryID = assistant.id
        entries.append(assistant)
    }

    private func displayPrompt(_ prompt: String, attachment: HermesPromptAttachment?) -> String {
        guard let attachment else { return prompt }
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let label = "Attached: \(attachment.filename) (\(attachment.mimeType), \(attachment.formattedByteCount))"
        return trimmedPrompt.isEmpty ? label : "\(trimmedPrompt)\n\n\(label)"
    }

    private func updateActiveAssistantEntry(with content: String) {
        guard let activeAssistantEntryID,
              let index = entries.firstIndex(where: { $0.id == activeAssistantEntryID })
        else { return }
        var updatedEntries = entries
        updatedEntries[index].content = HermesStreamTextFormatter.lineBreakAfterStatementDots(content)
        entries = updatedEntries
    }

    private func streamResponse(apiSettings: HermesAPISettings, draft: HermesRequestDraft, attachment: HermesPromptAttachment?, previousResponseID: String, hermesSessionID: String) async throws {
        let request = try buildRequest(
            apiSettings: apiSettings,
            draft: draft,
            attachment: attachment,
            stream: true,
            previousResponseID: previousResponseID,
            hermesSessionID: hermesSessionID
        )
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (bytes, response) = try await session.bytes(for: request)
        try validate(response: response)
        persistHermesSessionID(from: response)

        var parser = HermesSSEParser()
        for try await line in bytes.lines {
            try Task.checkCancellation()
            if let event = parser.consume(line: line) {
                handle(event: event)
            }
        }

        if let event = parser.finish() {
            handle(event: event)
        }
    }

    private func fetchResponse(apiSettings: HermesAPISettings, draft: HermesRequestDraft, attachment: HermesPromptAttachment?, previousResponseID: String, hermesSessionID: String) async throws {
        let request = try buildRequest(
            apiSettings: apiSettings,
            draft: draft,
            attachment: attachment,
            stream: false,
            previousResponseID: previousResponseID,
            hermesSessionID: hermesSessionID
        )
        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (data, response) = try await session.data(for: request)
        try validate(response: response)
        persistHermesSessionID(from: response)

        let envelope = try JSONDecoder().decode(HermesResponseEnvelope.self, from: data)
        rawStreamedJSON = Self.prettyPrintedJSON(from: data)
        latestResponseID = envelope.id ?? ""
        persistLastResponseID(latestResponseID)
        streamedText = envelope.assistantText
        updateActiveAssistantEntry(with: streamedText)
        latestMessageType = envelope.outputMessageType
        eventCount = 1
    }

    private func buildRequest(
        apiSettings: HermesAPISettings,
        draft: HermesRequestDraft,
        attachment: HermesPromptAttachment?,
        stream: Bool,
        previousResponseID: String,
        hermesSessionID: String
    ) throws -> URLRequest {
        guard let url = HermesAPISettings.responseURL(from: apiSettings.baseURL) else {
            throw HermesResponsesError.invalidURL
        }

        let payload = HermesResponsesRequestBody(
            model: "hermes-agent",
            input: HermesResponsesInput(prompt: draft.userPrompt, attachment: attachment),
            stream: stream,
            store: true,
            previousResponseID: previousResponseID.isEmpty ? nil : previousResponseID
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if stream {
            request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 0
        }

        let profile = draft.profile.trimmingCharacters(in: .whitespacesAndNewlines)
        request.setValue(profile.isEmpty ? "default" : profile, forHTTPHeaderField: "X-Hermes-Profile")

        let trimmedHermesSessionID = hermesSessionID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedHermesSessionID.isEmpty {
            request.setValue(trimmedHermesSessionID, forHTTPHeaderField: "X-Hermes-Session-Id")
            request.setValue(trimmedHermesSessionID, forHTTPHeaderField: "x-openclaw-session-key")
        }

        if !apiSettings.apiKey.isEmpty {
            request.setValue("Bearer \(apiSettings.apiKey)", forHTTPHeaderField: "Authorization")
        }

        request.httpBody = try JSONEncoder().encode(payload)
        return request
    }

    private func persistHermesSessionID(from response: URLResponse) {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        let candidates = [
            httpResponse.value(forHTTPHeaderField: "X-Hermes-Session-Id"),
            httpResponse.value(forHTTPHeaderField: "x-openclaw-session-key")
        ]

        for candidate in candidates {
            let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmed.isEmpty else { continue }
            activeHermesSessionID = trimmed
            return
        }
    }

    private func validate(response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HermesResponsesError.invalidResponse
        }

        guard 200 ..< 300 ~= httpResponse.statusCode else {
            throw HermesResponsesError.httpError(httpResponse.statusCode)
        }
    }

    private func handle(event: HermesSSEEvent) {
        appendRawStreamedJSON(event)

        if event.data == "[DONE]" {
            connectionStatus = "Completed"
            return
        }

        eventCount += 1
        let summary = HermesEventSummaryBuilder.summary(for: event)
        latestMessageType = summary.messageType

        if let responseID = summary.responseID, !responseID.isEmpty {
            latestResponseID = responseID
            persistLastResponseID(responseID)
        }

        if let delta = summary.outputDelta, !delta.isEmpty {
            if streamedText.isEmpty {
                streamedText = delta
            } else if summary.title == "response.completed" && streamedText.count >= delta.count {
                streamedText = streamedText
            } else if delta.hasPrefix(streamedText) {
                streamedText = delta
            } else if !streamedText.hasSuffix(delta) {
                streamedText += delta
            }
            updateActiveAssistantEntry(with: streamedText)
            connectionStatus = "Streaming output"
        } else if summary.title.hasPrefix("response.output_item.") {
            connectionStatus = summary.status
        } else {
            connectionStatus = "Processing \(summary.title)"
        }

    }

    private func appendRawStreamedJSON(_ event: HermesSSEEvent) {
        let eventName = event.event ?? "message"
        let payload = event.data == "[DONE]" ? "[DONE]" : Self.prettyPrintedJSON(from: event.data)
        let block = "event: \(eventName)\n\(payload)"
        rawStreamedJSON = rawStreamedJSON.isEmpty ? block : rawStreamedJSON + "\n\n" + block
    }

    private static func prettyPrintedJSON(from string: String) -> String {
        guard let data = string.data(using: .utf8) else { return string }
        return prettyPrintedJSON(from: data)
    }

    private static func prettyPrintedJSON(from data: Data) -> String {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let prettyData = try? JSONSerialization.data(
                withJSONObject: object,
                options: [.prettyPrinted, .sortedKeys]
            ),
            let pretty = String(data: prettyData, encoding: .utf8)
        else {
            return String(data: data, encoding: .utf8) ?? ""
        }
        return pretty
    }
}


struct HermesResponseMessage: Identifiable {
    let id = UUID()
    let role: String
    var content: String
}

struct HermesAPISettings: Codable, Equatable {
    var baseURL = HermesHostEndpoints.httpURLString(host: defaultHermesMacHost, port: defaultHermesAPIPort, path: "/v1")
    var apiKey = ""
    var allowSelfSignedCertificates = false

    static func responseURL(from baseURL: String) -> URL? {
        endpointURL(from: baseURL, suffix: "responses")
    }

    static func chatCompletionsURL(from baseURL: String) -> URL? {
        endpointURL(from: baseURL, suffix: "chat/completions")
    }

    static func modelsURL(from baseURL: String) -> URL? {
        endpointURL(from: baseURL, suffix: "models")
    }

    static func profilesURL(from baseURL: String) -> URL? {
        endpointURL(from: baseURL, suffix: "profiles")
    }

    private static func endpointURL(from baseURL: String, suffix: String) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasSuffix("/\(suffix)") {
            return URL(string: trimmed)
        }

        guard var components = URLComponents(string: trimmed) else { return nil }
        let normalizedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        // The Hermes API server is documented as an OpenAI-compatible `/v1` endpoint,
        // but it is easy to enter only the host/port in Settings (for example
        // `http://127.0.0.1:8642`).  Without this guard the Responses tab posts to
        // `/responses`, which the API server correctly reports as 404.  Treat a bare
        // origin as the Hermes API root and add `/v1` before the endpoint suffix.
        if normalizedPath.isEmpty {
            components.path = "/v1/\(suffix)"
            return components.url
        }

        if trimmed.hasSuffix("/") {
            return URL(string: trimmed + suffix)
        }

        return URL(string: trimmed + "/" + suffix)
    }
}

struct HermesAPIProfile: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let isDefault: Bool
    let model: String?
    let provider: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case isDefault = "is_default"
        case model
        case provider
    }
}

private struct HermesAPIProfilesEnvelope: Decodable {
    let data: [HermesAPIProfile]
}

enum HermesAPIProfilesClient {
    static func fetchProfiles(apiSettings: HermesAPISettings) async throws -> [HermesAPIProfile] {
        guard let url = HermesAPISettings.profilesURL(from: apiSettings.baseURL) else {
            throw HermesResponsesError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !apiSettings.apiKey.isEmpty {
            request.setValue("Bearer \(apiSettings.apiKey)", forHTTPHeaderField: "Authorization")
        }

        let session = HermesNetworkSessionFactory.session(for: apiSettings)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HermesResponsesError.invalidResponse
        }
        guard 200 ..< 300 ~= httpResponse.statusCode else {
            throw HermesResponsesError.httpError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(HermesAPIProfilesEnvelope.self, from: data).data
            .filter { !$0.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

struct HermesRequestDraft: Codable, Equatable {
    var profile = "default"
    var userPrompt = "Summarize the current project layout and recommend the next integration step."
    var stream = true

    enum CodingKeys: String, CodingKey {
        case profile
        case userPrompt
        case stream
        case legacyModel = "model"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profile = try container.decodeIfPresent(String.self, forKey: .profile) ?? "default"
        _ = try container.decodeIfPresent(String.self, forKey: .legacyModel)
        userPrompt = try container.decodeIfPresent(String.self, forKey: .userPrompt) ?? userPrompt
        stream = try container.decodeIfPresent(Bool.self, forKey: .stream) ?? stream
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(profile, forKey: .profile)
        try container.encode(userPrompt, forKey: .userPrompt)
        try container.encode(stream, forKey: .stream)
    }

    func locked(toProfile profile: String) -> HermesRequestDraft {
        var copy = self
        let trimmedProfile = profile.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.profile = trimmedProfile.isEmpty ? "default" : trimmedProfile
        return copy
    }
}

private enum HermesResponsesInput: Encodable {
    case text(String)
    case message([HermesResponsesInputMessage])

    init(prompt: String, attachment: HermesPromptAttachment?) {
        guard let attachment else {
            self = .text(prompt)
            return
        }

        if attachment.isImage {
            self = .message([
                HermesResponsesInputMessage(
                    role: "user",
                    content: [
                        .inputText(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Please inspect the attached image." : prompt),
                        .inputImage(attachment.base64DataURL)
                    ]
                )
            ])
        } else {
            let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            let basePrompt = trimmedPrompt.isEmpty ? "Please inspect the attached file." : trimmedPrompt
            self = .text(basePrompt + attachment.textAttachmentBlock)
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .text(let text):
            var container = encoder.singleValueContainer()
            try container.encode(text)
        case .message(let messages):
            var container = encoder.singleValueContainer()
            try container.encode(messages)
        }
    }
}

private struct HermesResponsesInputMessage: Encodable {
    let role: String
    let content: [HermesResponsesInputContentPart]
}

private enum HermesResponsesInputContentPart: Encodable {
    case inputText(String)
    case inputImage(String)

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .inputText(let text):
            try container.encode("input_text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .inputImage(let dataURL):
            try container.encode("input_image", forKey: .type)
            try container.encode(dataURL, forKey: .imageURL)
        }
    }
}

private struct HermesResponsesRequestBody: Encodable {
    let model: String
    let input: HermesResponsesInput
    let stream: Bool
    let store: Bool
    let previousResponseID: String?

    enum CodingKeys: String, CodingKey {
        case model
        case input
        case stream
        case store
        case previousResponseID = "previous_response_id"
    }
}

private struct HermesResponseEnvelope: Decodable {
    let id: String?
    let status: String?
    let output: [HermesResponseOutputItem]?

    var assistantText: String {
        guard let output else { return "" }
        return output.compactMap(\.assistantText).joined(separator: "\n\n")
    }

    var outputMessageType: String {
        guard let output, let item = output.first(where: { $0.assistantText?.isEmpty == false }) else {
            return "message"
        }
        return item.type
    }
}

private struct HermesResponseOutputItem: Decodable {
    let type: String
    let content: [HermesResponseContent]?
    let output: [HermesResponseContent]?

    var assistantText: String? {
        guard type == "message" else { return nil }
        let text = (content ?? output ?? [])
            .compactMap(\.displayValue)
            .joined()
        return text.isEmpty ? nil : text
    }
}

private struct HermesResponseContent: Decodable {
    let type: String
    let text: String?
    let imageURL: HermesImageURLPayload?
    let url: String?
    let b64JSON: String?
    let imageBase64: String?
    let mimeType: String?
    let originalMimeType: String?

    var displayValue: String? {
        if type == "output_text" || type == "text" || type == "message" {
            guard let text else { return nil }
            return HermesImageJSONFormatter.renderableImageMarkdown(from: text) ?? text
        }
        if let imageMarkdown {
            return imageMarkdown
        }
        return nil
    }

    var imageMarkdown: String? {
        let base64 = b64JSON ?? imageBase64
        let mimeCandidate = mimeType ?? originalMimeType
        let resolvedMimeType = mimeCandidate?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? mimeCandidate! : "image/png"
        let source = imageURL?.url ?? url ?? base64.map { "data:\(resolvedMimeType);base64,\($0)" }
        guard let source, !source.isEmpty else { return nil }
        return "\n\n![Hermes image](\(source))"
    }

    enum CodingKeys: String, CodingKey {
        case type
        case text
        case imageURL = "image_url"
        case url
        case b64JSON = "b64_json"
        case imageBase64 = "image_base64"
        case mimeType = "mime_type"
        case originalMimeType = "original_mime_type"
    }
}

private struct HermesImageURLPayload: Decodable {
    let url: String?
}

private struct HermesSSEEvent {
    let event: String?
    let data: String
}

private struct HermesSSEParser {
    private var eventName: String?
    private var dataLines: [String] = []

    mutating func consume(line: String) -> HermesSSEEvent? {
        if line.isEmpty {
            return flush()
        }

        if line.hasPrefix("event:") {
            if !dataLines.isEmpty || eventName != nil {
                let pending = flush()
                eventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                return pending
            }
            eventName = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
        } else if line.hasPrefix("data:") {
            let value = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            dataLines.append(value)
        }

        return nil
    }

    mutating func finish() -> HermesSSEEvent? {
        flush()
    }

    private mutating func flush() -> HermesSSEEvent? {
        guard !dataLines.isEmpty || eventName != nil else { return nil }
        let payload = dataLines.joined(separator: "\n")
        let event = HermesSSEEvent(event: eventName, data: payload)
        eventName = nil
        dataLines.removeAll(keepingCapacity: true)
        return event
    }
}

private struct HermesEventSummary {
    let title: String
    let messageType: String
    let status: String
    let detail: String
    let metadata: [String]
    let responseID: String?
    let outputDelta: String?
    let includeInTimeline: Bool
}

private enum HermesEventSummaryBuilder {
    static func summary(for event: HermesSSEEvent) -> HermesEventSummary {
        let title = event.event ?? "message"
        let payload = HermesLooseJSON(json: event.data)

        switch title {
        case "response.created":
            let responseID = payload.string(at: ["response", "id"]) ?? payload.string(at: ["id"])
            let status = payload.string(at: ["response", "status"]) ?? payload.string(at: ["status"]) ?? "Created"
            return HermesEventSummary(
                title: title,
                messageType: "response",
                status: status.capitalized,
                detail: responseID.map { "Started response \($0)." } ?? "Response created.",
                metadata: compactMetadata([
                    responseID.map { "Response ID: \($0)" }
                ]),
                responseID: responseID,
                outputDelta: nil,
                includeInTimeline: true
            )

        case "response.output_text.delta":
            let delta = payload.string(at: ["delta"]) ?? ""
            return HermesEventSummary(
                title: title,
                messageType: "message",
                status: "Streaming",
                detail: delta.isEmpty ? "Received output delta." : delta,
                metadata: compactMetadata([
                    payload.string(at: ["item_id"]).map { "Item ID: \($0)" },
                    payload.string(at: ["output_index"]).map { "Output Index: \($0)" }
                ]),
                responseID: payload.string(at: ["response_id"]),
                outputDelta: delta,
                includeInTimeline: false
            )

        case "response.output_text.done":
            let text = payload.string(at: ["text"]) ?? ""
            return HermesEventSummary(
                title: title,
                messageType: "message",
                status: "Completed",
                detail: text.isEmpty ? "Received finalized output text." : text,
                metadata: compactMetadata([
                    payload.string(at: ["item_id"]).map { "Item ID: \($0)" },
                    payload.string(at: ["output_index"]).map { "Output Index: \($0)" }
                ]),
                responseID: payload.string(at: ["response_id"]),
                outputDelta: text,
                includeInTimeline: true
            )

        case let eventName where eventName.hasPrefix("response.output_item."):
            let itemType = payload.string(at: ["item", "type"]) ?? payload.string(at: ["type"]) ?? "item"
            let name = payload.string(at: ["item", "name"]) ?? payload.string(at: ["name"])
            let itemStatus = payload.string(at: ["item", "status"])
                ?? payload.string(at: ["status"])
                ?? String(eventName.dropFirst("response.output_item.".count))
            let statusText = "\(name ?? itemType): \(itemStatus)"
            let detail = name.map { "\(itemType) \($0)" } ?? "Received \(itemType)."
            return HermesEventSummary(
                title: title,
                messageType: itemType,
                status: statusText,
                detail: detail,
                metadata: compactMetadata([
                    payload.string(at: ["item", "call_id"]).map { "Call ID: \($0)" },
                    payload.string(at: ["output_index"]).map { "Output Index: \($0)" }
                ]),
                responseID: payload.string(at: ["response_id"]),
                outputDelta: nil,
                includeInTimeline: itemType != "message"
            )

        case "response.completed":
            let responseID = payload.string(at: ["response", "id"]) ?? payload.string(at: ["id"])
            let status = payload.string(at: ["response", "status"]) ?? payload.string(at: ["status"]) ?? "Completed"
            let outputText = payload.messageOutputTexts(at: ["response", "output"]).joined(separator: "\n\n")
            return HermesEventSummary(
                title: title,
                messageType: "response",
                status: status.capitalized,
                detail: outputText.isEmpty ? "Hermes finished the streamed response." : outputText,
                metadata: compactMetadata([
                    responseID.map { "Response ID: \($0)" }
                ]),
                responseID: responseID,
                outputDelta: outputText.isEmpty ? nil : outputText,
                includeInTimeline: true
            )

        default:
            return HermesEventSummary(
                title: title,
                messageType: title,
                status: "Event",
                detail: payload.primaryDescription ?? event.data,
                metadata: [],
                responseID: payload.string(at: ["response_id"]),
                outputDelta: nil,
                includeInTimeline: false
            )
        }
    }

    private static func compactMetadata(_ values: [String?]) -> [String] {
        values.compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
    }
}

struct HermesLooseJSON {
    private let object: Any?

    init(json: String) {
        if let data = json.data(using: .utf8) {
            object = try? JSONSerialization.jsonObject(with: data)
        } else {
            object = nil
        }
    }

    init(data: Data) {
        object = try? JSONSerialization.jsonObject(with: data)
    }

    func string(at path: [String]) -> String? {
        guard let value = value(at: path) else { return nil }

        switch value {
        case let string as String:
            return string
        case let number as NSNumber:
            return number.stringValue
        default:
            return nil
        }
    }

    func texts(at path: [String]) -> [String] {
        guard let value = value(at: path) else { return [] }
        return extractTexts(from: value)
    }

    func messageOutputTexts(at path: [String]) -> [String] {
        guard let value = value(at: path) else { return [] }
        return extractMessageOutputTexts(from: value)
    }

    var primaryDescription: String? {
        if let message = string(at: ["message"]) {
            return message
        }

        if let error = string(at: ["error", "message"]) {
            return error
        }

        return nil
    }

    var chatCompletionFallbackText: String {
        guard let object else { return "" }
        return extractChatFallbackTexts(from: object).joined()
    }

    private func value(at path: [String]) -> Any? {
        var current = object

        for key in path {
            if let index = Int(key), let array = current as? [Any], array.indices.contains(index) {
                current = array[index]
            } else {
                guard let dictionary = current as? [String: Any] else {
                    return nil
                }
                current = dictionary[key]
            }
        }

        return current
    }

    private func extractMessageOutputTexts(from value: Any) -> [String] {
        if let array = value as? [Any] {
            return array.flatMap(extractMessageOutputTexts)
        }

        guard let dictionary = value as? [String: Any] else { return [] }

        if let type = dictionary["type"] as? String, type != "message" {
            return []
        }

        if let content = dictionary["content"] ?? dictionary["output"] {
            return extractTexts(from: content)
        }

        return extractTexts(from: dictionary)
    }

    private func extractTexts(from value: Any) -> [String] {
        if let string = value as? String {
            return [string]
        }

        if let dictionary = value as? [String: Any] {
            if let text = dictionary["text"] as? String {
                return [text]
            }

            if let outputText = dictionary["output_text"] as? String {
                return [outputText]
            }

            if let imageMarkdown = extractImageMarkdown(from: dictionary) {
                return [imageMarkdown]
            }

            return dictionary.values.flatMap(extractTexts)
        }

        if let array = value as? [Any] {
            return array.flatMap(extractTexts)
        }

        return []
    }

    private func extractImageMarkdown(from dictionary: [String: Any]) -> String? {
        let source: String?
        if let imageURL = dictionary["image_url"] as? [String: Any] {
            source = imageURL["url"] as? String
        } else if let imageURL = dictionary["image_url"] as? String {
            source = imageURL
        } else if let url = dictionary["url"] as? String {
            source = url
        } else if let base64 = dictionary["b64_json"] as? String {
            source = "data:image/png;base64,\(base64)"
        } else if let base64 = dictionary["image_base64"] as? String {
            let mimeType = (dictionary["mime_type"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? (dictionary["original_mime_type"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedMimeType = mimeType?.isEmpty == false ? mimeType! : "image/png"
            source = "data:\(resolvedMimeType);base64,\(base64)"
        } else {
            source = nil
        }

        guard let source, !source.isEmpty else { return nil }
        return "\n\n![Hermes image](\(source))"
    }

    private func extractChatFallbackTexts(from value: Any) -> [String] {
        if let string = value as? String {
            return [string]
        }

        if let array = value as? [Any] {
            return array.flatMap(extractChatFallbackTexts)
        }

        guard let dictionary = value as? [String: Any] else { return [] }

        let directKeys = ["content", "text", "output_text"]
        let directTexts = directKeys.flatMap { key in
            dictionary[key].map(extractTexts(from:)) ?? []
        }
        if !directTexts.isEmpty {
            return directTexts
        }

        let metadataKeys: Set<String> = [
            "id", "object", "created", "created_at", "model", "system_fingerprint",
            "service_tier", "finish_reason", "index", "role", "type", "status",
            "usage", "prompt_tokens", "completion_tokens", "total_tokens"
        ]

        return dictionary
            .filter { !metadataKeys.contains($0.key) }
            .values
            .flatMap(extractChatFallbackTexts)
    }
}

enum HermesResponsesError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            "The Hermes gateway URL is invalid."
        case .invalidResponse:
            "The Hermes gateway returned an invalid response."
        case .httpError(let statusCode):
            "The Hermes gateway returned HTTP \(statusCode)."
        }
    }
}
