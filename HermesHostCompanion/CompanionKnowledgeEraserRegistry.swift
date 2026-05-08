import Foundation

enum CompanionKnowledgeEraserError: LocalizedError {
    case invalidWorkspace(String)
    case emptyTopic
    case noSelectedItems

    var errorDescription: String? {
        switch self {
        case .invalidWorkspace(let path):
            return "The Hermes workspace path '\(path)' is invalid."
        case .emptyTopic:
            return "Enter a topic description before scanning."
        case .noSelectedItems:
            return "Select at least one item to erase."
        }
    }
}

final class CompanionKnowledgeEraserRegistry {
    private let fileManager = FileManager.default
    private let entryDelimiter = "\n§\n"

    func scan(workspacePath: String, topic: String) throws -> KnowledgeEraserScanResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let normalizedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedTopic.isEmpty == false else { throw CompanionKnowledgeEraserError.emptyTopic }
        let matcher = TopicMatcher(topic: normalizedTopic)
        var items: [KnowledgeEraserItem] = []
        items.append(contentsOf: scanMemoryEntries(workspaceURL: workspaceURL, matcher: matcher))
        items.append(contentsOf: scanUserProfile(workspaceURL: workspaceURL, matcher: matcher))
        items.append(contentsOf: scanSkills(workspaceURL: workspaceURL, matcher: matcher))
        items.sort { lhs, rhs in
            if lhs.confidence == rhs.confidence { return lhs.path < rhs.path }
            return lhs.confidence > rhs.confidence
        }
        return KnowledgeEraserScanResult(
            workspacePath: workspacePath,
            resolvedWorkspacePath: workspaceURL.path,
            topic: normalizedTopic,
            scannedAt: Date(),
            items: items
        )
    }

    func erase(workspacePath: String, topic: String, selectedItemIDs: [String]) throws -> KnowledgeEraserEraseResult {
        let workspaceURL = try resolvedWorkspaceURL(from: workspacePath)
        let selectedIDs = Set(selectedItemIDs)
        guard selectedIDs.isEmpty == false else { throw CompanionKnowledgeEraserError.noSelectedItems }
        let scanResult = try scan(workspacePath: workspacePath, topic: topic)
        let selectedItems = scanResult.items.filter { selectedIDs.contains($0.id) }
        guard selectedItems.isEmpty == false else { throw CompanionKnowledgeEraserError.noSelectedItems }

        let archiveURL = try archive(items: selectedItems, topic: scanResult.topic, workspaceURL: workspaceURL)
        var erasedIDs: [String] = []
        var skippedIDs: [String] = []

        let memoryIDs = selectedItems.filter { $0.kind == .memoryEntry }.map(\.id)
        if memoryIDs.isEmpty == false {
            erasedIDs.append(contentsOf: try eraseMemoryEntries(workspaceURL: workspaceURL, selectedIDs: Set(memoryIDs)))
        }

        let fileItems = selectedItems.filter { $0.kind == .userProfileBlock || $0.kind == .skillBlock }
        let groupedByPath = Dictionary(grouping: fileItems, by: \.path)
        for (path, items) in groupedByPath {
            let result = try eraseBlocks(path: path, items: items)
            erasedIDs.append(contentsOf: result.erased)
            skippedIDs.append(contentsOf: result.skipped)
        }

        let erasedSet = Set(erasedIDs)
        skippedIDs.append(contentsOf: selectedItems.map(\.id).filter { erasedSet.contains($0) == false && skippedIDs.contains($0) == false })

        return KnowledgeEraserEraseResult(
            workspacePath: workspacePath,
            resolvedWorkspacePath: workspaceURL.path,
            topic: scanResult.topic,
            erasedAt: Date(),
            archivePath: archiveURL.path,
            erasedItemIDs: erasedIDs,
            skippedItemIDs: skippedIDs,
            remainingItems: try scan(workspacePath: workspacePath, topic: topic).items
        )
    }

    private func scanMemoryEntries(workspaceURL: URL, matcher: TopicMatcher) -> [KnowledgeEraserItem] {
        let url = memoryURL(for: workspaceURL)
        let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let entries = content.components(separatedBy: entryDelimiter).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return entries.enumerated().compactMap { index, entry in
            guard let confidence = matcher.confidence(in: entry) else { return nil }
            return KnowledgeEraserItem(
                id: "memory:\(index)",
                kind: .memoryEntry,
                title: "Memory entry #\(index + 1)",
                path: url.path,
                location: "Entry \(index + 1)",
                preview: Self.preview(entry),
                content: entry,
                confidence: confidence
            )
        }
    }

    private func scanUserProfile(workspaceURL: URL, matcher: TopicMatcher) -> [KnowledgeEraserItem] {
        scanTextBlocks(url: userURL(for: workspaceURL), kind: .userProfileBlock, titlePrefix: "User profile") { text in
            matcher.confidence(in: text)
        }
    }

    private func scanSkills(workspaceURL: URL, matcher: TopicMatcher) -> [KnowledgeEraserItem] {
        let skillsURL = workspaceURL.appendingPathComponent("skills", isDirectory: true)
        guard let enumerator = fileManager.enumerator(
            at: skillsURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        var items: [KnowledgeEraserItem] = []
        for case let url as URL in enumerator {
            guard ["md", "txt", "yaml", "yml", "json"].contains(url.pathExtension.lowercased()) else { continue }
            items.append(contentsOf: scanTextBlocks(url: url, kind: .skillBlock, titlePrefix: "Skill file") { text in
                matcher.confidence(in: text)
            })
        }
        return items
    }

    private func scanTextBlocks(url: URL, kind: KnowledgeEraserItemKind, titlePrefix: String, confidence: (String) -> Double?) -> [KnowledgeEraserItem] {
        guard let content = try? String(contentsOf: url, encoding: .utf8), content.isEmpty == false else { return [] }
        let lines = content.components(separatedBy: .newlines)
        let blocks = Self.blocks(from: lines)
        return blocks.compactMap { block in
            let text = block.lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.isEmpty == false, let score = confidence(text) else { return nil }
            return KnowledgeEraserItem(
                id: "block:\(url.path):\(block.startLine):\(block.endLine)",
                kind: kind,
                title: "\(titlePrefix) lines \(block.startLine)-\(block.endLine)",
                path: url.path,
                location: "Lines \(block.startLine)-\(block.endLine)",
                preview: Self.preview(text),
                content: text,
                confidence: score
            )
        }
    }

    private func eraseMemoryEntries(workspaceURL: URL, selectedIDs: Set<String>) throws -> [String] {
        let url = memoryURL(for: workspaceURL)
        let content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        let entries = content.components(separatedBy: entryDelimiter).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        var erased: [String] = []
        var kept: [String] = []
        for (index, entry) in entries.enumerated() {
            let id = "memory:\(index)"
            if selectedIDs.contains(id) {
                erased.append(id)
            } else {
                kept.append(entry)
            }
        }
        try kept.joined(separator: entryDelimiter).write(to: url, atomically: true, encoding: .utf8)
        return erased
    }

    private func eraseBlocks(path: String, items: [KnowledgeEraserItem]) throws -> (erased: [String], skipped: [String]) {
        let url = URL(fileURLWithPath: path)
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return ([], items.map(\.id))
        }
        let lines = content.components(separatedBy: .newlines)
        let selected = Set(items.map(\.id))
        var eraseLineNumbers = Set<Int>()
        for block in Self.blocks(from: lines) {
            let id = "block:\(path):\(block.startLine):\(block.endLine)"
            if selected.contains(id) {
                for line in block.startLine...block.endLine { eraseLineNumbers.insert(line) }
            }
        }
        guard eraseLineNumbers.isEmpty == false else { return ([], items.map(\.id)) }
        var newLines: [String] = []
        for (offset, line) in lines.enumerated() {
            if eraseLineNumbers.contains(offset + 1) == false {
                newLines.append(line)
            }
        }
        try newLines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return (items.map(\.id), [])
    }

    private func archive(items: [KnowledgeEraserItem], topic: String, workspaceURL: URL) throws -> URL {
        let folder = workspaceURL.appendingPathComponent("knowledge-erasure-archive", isDirectory: true)
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let fileName = "\(Self.slug(topic))-\(Self.archiveDateFormatter.string(from: Date())).md"
        let url = folder.appendingPathComponent(fileName)
        var markdown = "# Knowledge Eraser Archive\n\n"
        markdown += "Topic: \(topic)\n\n"
        markdown += "Created: \(ISO8601DateFormatter().string(from: Date()))\n\n"
        markdown += "Selected items: \(items.count)\n\n"
        for item in items {
            markdown += "## \(item.title)\n\n"
            markdown += "- Kind: \(item.kind.rawValue)\n"
            markdown += "- Path: \(item.path)\n"
            markdown += "- Location: \(item.location)\n"
            markdown += "- Confidence: \(String(format: "%.2f", item.confidence))\n\n"
            markdown += "```text\n\(item.content)\n```\n\n"
        }
        try markdown.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func resolvedWorkspaceURL(from path: String) throws -> URL {
        let expanded = (path as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw CompanionKnowledgeEraserError.invalidWorkspace(path)
        }
        return url
    }

    private func memoryURL(for workspaceURL: URL) -> URL { workspaceURL.appendingPathComponent("memory.md") }
    private func userURL(for workspaceURL: URL) -> URL { workspaceURL.appendingPathComponent("USER.md") }

    private static func blocks(from lines: [String]) -> [(startLine: Int, endLine: Int, lines: [String])] {
        var result: [(Int, Int, [String])] = []
        var start: Int?
        var current: [String] = []
        for (offset, line) in lines.enumerated() {
            let lineNumber = offset + 1
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let startLine = start, current.isEmpty == false {
                    result.append((startLine, lineNumber - 1, current))
                }
                start = nil
                current = []
            } else {
                if start == nil { start = lineNumber }
                current.append(line)
            }
        }
        if let startLine = start, current.isEmpty == false {
            result.append((startLine, lines.count, current))
        }
        return result
    }

    private static func preview(_ text: String) -> String {
        let collapsed = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsed.count > 240 ? String(collapsed.prefix(240)) + "…" : collapsed
    }

    private static func slug(_ text: String) -> String {
        let lowered = text.lowercased()
        let scalars = lowered.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : "-"
        }
        let collapsed = String(scalars).split(separator: "-").joined(separator: "-")
        return collapsed.isEmpty ? "topic" : String(collapsed.prefix(80))
    }

    private static let archiveDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()
}

private struct TopicMatcher {
    let topic: String
    let tokens: [String]

    init(topic: String) {
        self.topic = topic.lowercased()
        self.tokens = topic.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 3 }
    }

    func confidence(in text: String) -> Double? {
        let haystack = text.lowercased()
        if haystack.contains(topic), topic.count >= 3 { return 1.0 }
        guard tokens.isEmpty == false else { return nil }
        let matched = tokens.filter { haystack.contains($0) }
        if matched.count >= max(1, min(2, tokens.count)) {
            return min(0.95, 0.45 + Double(matched.count) / Double(tokens.count) * 0.5)
        }
        return nil
    }
}
