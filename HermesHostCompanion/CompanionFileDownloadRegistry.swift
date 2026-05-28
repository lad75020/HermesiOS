//
//  CompanionFileDownloadRegistry.swift
//  HermesHostCompanion
//

import Foundation
import OSLog
import UniformTypeIdentifiers

struct CompanionFileDownloadRegistry {
    private let maxDownloadBytes = 100 * 1024 * 1024
    private let maxChunkBytes = 384 * 1024
    private let logger = Logger(subsystem: "fr.dubertrand.HermesHostCompanion", category: "FileDownload")

    func listDirectory(path rawPath: String, workspacePath: String?, requester: String) throws -> FileBrowserResult {
        let roots = allowedRoots(workspacePath: workspacePath)
        guard let defaultRoot = roots.first else { throw FileBrowserError.noApprovedRoots }

        let trimmedPath = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestedPath = trimmedPath.isEmpty ? defaultRoot.path : trimmedPath
        guard requestedPath.hasPrefix("/") else { throw FileBrowserError.notAbsolutePath }

        let url = URL(fileURLWithPath: requestedPath, isDirectory: true)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        try authorizeBrowserDirectory(url: url, roots: roots)
        let values = try url.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true else { throw FileBrowserError.notDirectory }

        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .fileSizeKey, .localizedNameKey, .isHiddenKey]
        let children = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: Array(keys), options: [.skipsPackageDescendants])
        let entries = children.compactMap { child -> FileBrowserEntry? in
            let canonicalChild = child.resolvingSymlinksInPath().standardizedFileURL
            guard !isSensitivePath(canonicalChild.path) else { return nil }
            guard roots.contains(where: { CompanionWorkspaceSecurity.isDescendant(canonicalChild, of: $0) }) else { return nil }
            guard let childValues = try? canonicalChild.resourceValues(forKeys: keys) else { return nil }
            guard childValues.isDirectory == true || childValues.isRegularFile == true else { return nil }
            let name = childValues.localizedName?.isEmpty == false ? childValues.localizedName! : canonicalChild.lastPathComponent
            guard name.isEmpty == false else { return nil }
            return FileBrowserEntry(
                name: name,
                path: canonicalChild.path,
                isDirectory: childValues.isDirectory == true,
                byteCount: childValues.isDirectory == true ? nil : childValues.fileSize
            )
        }
        .sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory { return lhs.isDirectory && !rhs.isDirectory }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        let parentPath = browserParentPath(for: url, roots: roots)
        logger.info("Allowed file browser listing requester=\(requester, privacy: .public) path=\(url.path, privacy: .private) entries=\(entries.count, privacy: .public)")
        return FileBrowserResult(path: url.path, parentPath: parentPath, entries: entries)
    }

    func downloadFile(path rawPath: String, workspacePath: String?, requester: String) throws -> FileDownloadResult {
        let metadata = try fileMetadata(for: rawPath, workspacePath: workspacePath, requester: requester, operation: "download_file")
        let data = try Data(contentsOf: metadata.url, options: [.mappedIfSafe])
        logger.info("Allowed file download requester=\(requester, privacy: .public) path=\(metadata.path, privacy: .private) bytes=\(data.count, privacy: .public)")
        return FileDownloadResult(
            path: metadata.path,
            fileName: metadata.fileName,
            byteCount: data.count,
            contentType: metadata.contentType,
            base64Data: data.base64EncodedString()
        )
    }

    func downloadFileInfo(path rawPath: String, workspacePath: String?, requester: String) throws -> FileDownloadInfoResult {
        let metadata = try fileMetadata(for: rawPath, workspacePath: workspacePath, requester: requester, operation: "download_file_info")
        logger.info("Allowed file download info requester=\(requester, privacy: .public) path=\(metadata.path, privacy: .private) bytes=\(metadata.byteCount, privacy: .public)")
        return FileDownloadInfoResult(
            path: metadata.path,
            fileName: metadata.fileName,
            byteCount: metadata.byteCount,
            contentType: metadata.contentType,
            chunkSize: maxChunkBytes
        )
    }

    func downloadFileChunk(path rawPath: String, offset: Int, length: Int, workspacePath: String?, requester: String) throws -> FileDownloadChunkResult {
        let metadata = try fileMetadata(for: rawPath, workspacePath: workspacePath, requester: requester, operation: "download_file_chunk")
        guard offset >= 0 else { throw FileDownloadError.invalidChunk }
        guard length > 0 else { throw FileDownloadError.invalidChunk }
        guard offset <= metadata.byteCount else { throw FileDownloadError.invalidChunk }

        let safeLength = min(length, maxChunkBytes, metadata.byteCount - offset)
        let handle = try FileHandle(forReadingFrom: metadata.url)
        defer { try? handle.close() }
        try handle.seek(toOffset: UInt64(offset))
        let data = try handle.read(upToCount: safeLength) ?? Data()
        let nextOffset = offset + data.count
        logger.info("Allowed file download chunk requester=\(requester, privacy: .public) path=\(metadata.path, privacy: .private) offset=\(offset, privacy: .public) bytes=\(data.count, privacy: .public)")
        return FileDownloadChunkResult(
            path: metadata.path,
            offset: offset,
            byteCount: data.count,
            totalByteCount: metadata.byteCount,
            isComplete: nextOffset >= metadata.byteCount,
            base64Data: data.base64EncodedString()
        )
    }

    private func fileMetadata(for rawPath: String, workspacePath: String?, requester: String, operation: String) throws -> FileDownloadMetadata {
        let trimmedPath = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedPath.isEmpty == false else { throw FileDownloadError.emptyPath }
        guard trimmedPath.hasPrefix("/") else { throw FileDownloadError.notAbsolutePath }

        let url = URL(fileURLWithPath: trimmedPath, isDirectory: false)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentTypeKey, .localizedNameKey])
        guard values.isRegularFile == true else { throw FileDownloadError.notRegularFile }

        let byteCount = values.fileSize ?? 0
        guard byteCount <= maxDownloadBytes else { throw FileDownloadError.fileTooLarge(byteCount: byteCount, limit: maxDownloadBytes) }

        do {
            try authorize(url: url, workspacePath: workspacePath)
        } catch {
            logger.error("Denied file download requester=\(requester, privacy: .public) operation=\(operation, privacy: .public) path=\(url.path, privacy: .private) error=\(error.localizedDescription, privacy: .public)")
            throw error
        }

        let fileName = values.localizedName?.isEmpty == false ? values.localizedName! : url.lastPathComponent
        return FileDownloadMetadata(
            url: url,
            path: url.path,
            fileName: fileName.isEmpty ? "downloaded-file" : fileName,
            byteCount: byteCount,
            contentType: values.contentType?.preferredMIMEType ?? "application/octet-stream"
        )
    }

    private func authorizeBrowserDirectory(url: URL, roots: [URL]) throws {
        guard roots.contains(where: { CompanionWorkspaceSecurity.isDescendant(url, of: $0) }) else {
            throw FileBrowserError.pathOutsideApprovedRoots(roots.map(\.path))
        }
        guard !isSensitivePath(url.path) else { throw FileDownloadError.sensitivePath }
    }

    private func authorize(url: URL, workspacePath: String?) throws {
        let path = url.path
        guard !isSensitivePath(path) else { throw FileDownloadError.sensitivePath }
        let roots = allowedRoots(workspacePath: workspacePath)
        guard roots.contains(where: { CompanionWorkspaceSecurity.isDescendant(url, of: $0) }) else {
            throw FileDownloadError.pathOutsideAllowedRoots(roots.map(\.path))
        }
    }

    private func allowedRoots(workspacePath: String?) -> [URL] {
        CompanionWorkspaceSecurity.approvedHermesRoots(preferredWorkspacePath: workspacePath)
    }

    private func browserParentPath(for url: URL, roots: [URL]) -> String? {
        guard let root = roots.first(where: { CompanionWorkspaceSecurity.isDescendant(url, of: $0) }) else { return nil }
        guard url.path != root.path else { return nil }
        let parent = url.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
        guard CompanionWorkspaceSecurity.isDescendant(parent, of: root) else { return nil }
        return parent.path
    }

    private func isSensitivePath(_ path: String) -> Bool {
        let lowercased = path.lowercased()
        let pathComponents = lowercased.split(separator: "/").map(String.init)
        let sensitiveComponents: Set<String> = [
            ".ssh", ".gnupg", "keychains", "cookies", "login data", "profiles", "firefox", "chrome", "chromium", "safari"
        ]
        if pathComponents.contains(where: { sensitiveComponents.contains($0) }) { return true }
        let fileName = URL(fileURLWithPath: lowercased).lastPathComponent
        if fileName == ".env" || fileName == "auth.json" || fileName.hasSuffix(".pem") || fileName.hasSuffix(".key") || fileName.contains("history") { return true }
        return false
    }
}

private struct FileDownloadMetadata {
    let url: URL
    let path: String
    let fileName: String
    let byteCount: Int
    let contentType: String
}

enum FileDownloadError: LocalizedError {
    case emptyPath
    case notAbsolutePath
    case notRegularFile
    case fileTooLarge(byteCount: Int, limit: Int)
    case invalidChunk
    case pathOutsideAllowedRoots([String])
    case sensitivePath

    var errorDescription: String? {
        switch self {
        case .emptyPath:
            return "Enter a macOS full file path."
        case .notAbsolutePath:
            return "The macOS file path must be absolute and start with /."
        case .notRegularFile:
            return "The selected macOS path is not a regular file."
        case .fileTooLarge(let byteCount, let limit):
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useGB]
            formatter.countStyle = .file
            return "File is too large for WebSocket download (\(formatter.string(fromByteCount: Int64(byteCount))) / \(formatter.string(fromByteCount: Int64(limit))) limit)."
        case .invalidChunk:
            return "The requested file chunk is invalid."
        case .pathOutsideAllowedRoots(let roots):
            return "File downloads are restricted to approved Hermes roots: \(roots.joined(separator: ", "))."
        case .sensitivePath:
            return "This path is blocked because it may contain credentials or other sensitive local data."
        }
    }
}

enum FileBrowserError: LocalizedError {
    case notAbsolutePath
    case notDirectory
    case noApprovedRoots
    case pathOutsideApprovedRoots([String])

    var errorDescription: String? {
        switch self {
        case .notAbsolutePath:
            return "The macOS folder path must be absolute and start with /."
        case .notDirectory:
            return "The selected macOS path is not a folder."
        case .noApprovedRoots:
            return "No approved Hermes folders are available for browsing."
        case .pathOutsideApprovedRoots(let roots):
            return "The file browser is restricted to approved Hermes roots: \(roots.joined(separator: ", "))."
        }
    }
}
