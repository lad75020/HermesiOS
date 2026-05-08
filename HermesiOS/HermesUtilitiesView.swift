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
    @Bindable var responseSession: HermesResponsesSession
    @Bindable var chatSession: HermesChatSession
    @AppStorage("hermes.utilities.clipboardHistoryExpanded") private var isClipboardHistoryExpanded = false
    @AppStorage("hermes.utilities.debuggingExpanded") private var isDebuggingExpanded = false
    @State private var statusMessage = "Monitoring the iOS clipboard while HermesiOS is active."

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HermesTabHeader("Utilities", systemImage: "wrench.and.screwdriver")

                HermesHeroCard(
                    title: "Utilities",
                    detail: "Quick helpers for day-to-day Hermes work. Clipboard History stores the last ten copied objects locally on this device, and Debugging exposes streamed API JSON in-place.",
                    systemImage: "wrench.and.screwdriver.fill"
                )

                HermesSectionCard("Utilities") {
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
        .background(Color.hermesCanvas.ignoresSafeArea())
        .navigationTitle("Utilities")
        .onAppear {
            clipboardHistory.captureCurrentPasteboardIfNeeded()
        }
    }

    @ViewBuilder
    private var clipboardHistoryContent: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                .buttonStyle(.bordered)
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
                        Button {
                            clipboardHistory.copyToPasteboard(entry)
                            statusMessage = "Copied \(entry.kind.displayName.lowercased()) back to the clipboard."
                        } label: {
                            HermesClipboardHistoryRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Copies this item back to the iOS clipboard")
                    }
                }
            }
        }
        .padding(.top, 12)
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
