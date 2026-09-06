//
//  CompanionFileDownloadRegistry.swift
//  HermesHostCompanion
//

import Foundation
import OSLog
import UniformTypeIdentifiers

@MainActor
final class CompanionFileDownloadRegistry {
    static let shared = CompanionFileDownloadRegistry()

    private let transferRootPath: String

    private struct DownloadSession {
        let requester: String
        let handle: FileHandle
        let path: String
        let fileName: String
        let byteCount: Int
        let contentType: String
        var nextOffset: Int
        var lastActivity: Date
    }

    private struct UploadSession {
        let requester: String
        let temporaryURL: URL
        let destinationURL: URL
        let expectedByteCount: Int
        var receivedByteCount: Int
        var lastActivity: Date
    }

    private let maxTransferBytes = 1_000_000_000
    private let maxChunkBytes = 384 * 1024
    private let maxActiveDownloads = 8
    private let maxActiveUploads = 4
    private let maxReservedUploadBytes = 2_000_000_000
    private let sessionLifetime: TimeInterval = 3_600
    private let logger = Logger(subsystem: "fr.dubertrand.HermesHostCompanion", category: "FileTransfer")
    private var downloads: [String: DownloadSession] = [:]
    private var uploads: [String: UploadSession] = [:]

    init(transferRootPath: String = "/Volumes/WDBlack4TB/.hermes") {
        self.transferRootPath = transferRootPath
    }

    deinit {
        for download in downloads.values {
            try? download.handle.close()
        }
        for upload in uploads.values {
            try? FileManager.default.removeItem(at: upload.temporaryURL)
        }
    }

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
            guard !isSensitivePath(canonicalChild.path, roots: roots) else { return nil }
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
        guard metadata.byteCount <= maxChunkBytes else {
            throw FileDownloadError.legacyDownloadRequiresChunking(limit: maxChunkBytes)
        }
        let data = try Data(contentsOf: metadata.url, options: [.mappedIfSafe])
        logger.info("Allowed legacy file download requester=\(requester, privacy: .public) path=\(metadata.path, privacy: .private) bytes=\(data.count, privacy: .public)")
        return FileDownloadResult(
            path: metadata.path,
            fileName: metadata.fileName,
            byteCount: data.count,
            contentType: metadata.contentType,
            base64Data: data.base64EncodedString()
        )
    }

    func downloadFileInfo(path rawPath: String, workspacePath: String?, requester: String) throws -> FileDownloadInfoResult {
        cleanupExpiredTransfers()
        discardDownloads(for: requester)
        guard downloads.count < maxActiveDownloads else { throw FileDownloadError.serverBusy }
        let metadata = try fileMetadata(for: rawPath, workspacePath: workspacePath, requester: requester, operation: "download_file_info")
        let handle = try FileHandle(forReadingFrom: metadata.url)
        let downloadID = UUID().uuidString
        downloads[downloadID] = DownloadSession(
            requester: requester,
            handle: handle,
            path: metadata.path,
            fileName: metadata.fileName,
            byteCount: metadata.byteCount,
            contentType: metadata.contentType,
            nextOffset: 0,
            lastActivity: Date()
        )
        logger.info("Allowed file download info requester=\(requester, privacy: .public) path=\(metadata.path, privacy: .private) bytes=\(metadata.byteCount, privacy: .public)")
        return FileDownloadInfoResult(
            downloadID: downloadID,
            path: metadata.path,
            fileName: metadata.fileName,
            byteCount: metadata.byteCount,
            contentType: metadata.contentType,
            chunkSize: maxChunkBytes
        )
    }

    func downloadFileChunk(downloadID: String, offset: Int, length: Int, requester: String) throws -> FileDownloadChunkResult {
        cleanupExpiredTransfers()
        guard var download = downloads[downloadID] else { throw FileDownloadError.unknownDownload }
        guard download.requester == requester else { throw FileDownloadError.unauthorizedDownload }
        guard offset == download.nextOffset else { throw FileDownloadError.invalidChunk }
        guard length > 0 else { throw FileDownloadError.invalidChunk }
        guard offset <= download.byteCount else { throw FileDownloadError.invalidChunk }

        let safeLength = min(length, maxChunkBytes, download.byteCount - offset)
        try download.handle.seek(toOffset: UInt64(offset))
        let data = try download.handle.read(upToCount: safeLength) ?? Data()
        guard !data.isEmpty || offset == download.byteCount else {
            discardDownload(downloadID)
            throw FileDownloadError.readFailed
        }
        let nextOffset = offset + data.count
        let isComplete = nextOffset >= download.byteCount
        if isComplete {
            discardDownload(downloadID)
        } else {
            download.nextOffset = nextOffset
            download.lastActivity = Date()
            downloads[downloadID] = download
        }
        logger.info("Allowed file download chunk requester=\(requester, privacy: .public) path=\(download.path, privacy: .private) offset=\(offset, privacy: .public) bytes=\(data.count, privacy: .public)")
        return FileDownloadChunkResult(
            path: download.path,
            offset: offset,
            byteCount: data.count,
            totalByteCount: download.byteCount,
            isComplete: isComplete,
            base64Data: data.base64EncodedString()
        )
    }

    func downloadFileChunkLegacy(
        path rawPath: String,
        offset: Int,
        length: Int,
        workspacePath: String?,
        requester: String
    ) throws -> FileDownloadChunkResult {
        let metadata = try fileMetadata(
            for: rawPath,
            workspacePath: workspacePath,
            requester: requester,
            operation: "download_file_chunk"
        )
        guard offset >= 0, offset <= metadata.byteCount, length > 0 else {
            throw FileDownloadError.invalidChunk
        }

        let safeLength = min(length, maxChunkBytes, metadata.byteCount - offset)
        let handle = try FileHandle(forReadingFrom: metadata.url)
        defer { try? handle.close() }
        try handle.seek(toOffset: UInt64(offset))
        let data = try handle.read(upToCount: safeLength) ?? Data()
        guard !data.isEmpty || offset == metadata.byteCount else {
            throw FileDownloadError.readFailed
        }
        let nextOffset = offset + data.count
        logger.info("Allowed legacy file download chunk requester=\(requester, privacy: .public) path=\(metadata.path, privacy: .private) offset=\(offset, privacy: .public) bytes=\(data.count, privacy: .public)")
        return FileDownloadChunkResult(
            path: metadata.path,
            offset: offset,
            byteCount: data.count,
            totalByteCount: metadata.byteCount,
            isComplete: nextOffset >= metadata.byteCount,
            base64Data: data.base64EncodedString()
        )
    }

    func cancelDownload(downloadID: String, requester: String) throws -> FileTransferCancelResult {
        guard let download = downloads[downloadID] else { throw FileDownloadError.unknownDownload }
        guard download.requester == requester else { throw FileDownloadError.unauthorizedDownload }
        discardDownload(downloadID)
        return FileTransferCancelResult(transferID: downloadID)
    }

    func startUpload(
        destinationPath rawDestinationPath: String,
        fileName rawFileName: String,
        byteCount: Int,
        workspacePath: String?,
        requester: String
    ) throws -> FileUploadStartResult {
        cleanupExpiredTransfers()
        discardUploads(for: requester)
        guard byteCount >= 0, byteCount <= maxTransferBytes else {
            throw FileUploadError.fileTooLarge(byteCount: byteCount, limit: maxTransferBytes)
        }
        guard uploads.count < maxActiveUploads,
              uploads.values.reduce(0, { $0 + $1.expectedByteCount }) + byteCount <= maxReservedUploadBytes else {
            throw FileUploadError.serverBusy
        }
        let roots = allowedRoots(workspacePath: workspacePath)
        guard !roots.isEmpty else { throw FileBrowserError.noApprovedRoots }
        let destinationDirectory = try uploadDestinationDirectory(rawDestinationPath, roots: roots)
        let stagingDirectory = try uploadStagingDirectory(root: roots[0])
        cleanupAbandonedUploadFiles(in: stagingDirectory)
        let fileName = rawFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fileName.isEmpty,
              fileName == URL(fileURLWithPath: fileName).lastPathComponent,
              fileName != ".",
              fileName != ".." else {
            throw FileUploadError.invalidFileName
        }

        let requestedURL = destinationDirectory.appendingPathComponent(fileName, isDirectory: false)
        guard !isSensitivePath(requestedURL.path, roots: roots) else { throw FileUploadError.sensitivePath }
        let destinationURL = uniqueFileURL(for: requestedURL)
        let uploadID = UUID().uuidString
        let temporaryURL = stagingDirectory.appendingPathComponent("upload-\(uploadID).partial", isDirectory: false)
        guard FileManager.default.createFile(
            atPath: temporaryURL.path,
            contents: nil,
            attributes: [.posixPermissions: 0o600]
        ) else {
            throw FileUploadError.writeFailed
        }

        if byteCount == 0 {
            do {
                try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
            } catch {
                try? FileManager.default.removeItem(at: temporaryURL)
                throw FileUploadError.writeFailed
            }
            return FileUploadStartResult(
                uploadID: uploadID,
                destinationPath: destinationURL.path,
                chunkSize: maxChunkBytes,
                isComplete: true
            )
        }

        uploads[uploadID] = UploadSession(
            requester: requester,
            temporaryURL: temporaryURL,
            destinationURL: destinationURL,
            expectedByteCount: byteCount,
            receivedByteCount: 0,
            lastActivity: Date()
        )
        logger.info("Started file upload requester=\(requester, privacy: .public) destination=\(destinationURL.path, privacy: .private) bytes=\(byteCount, privacy: .public)")
        return FileUploadStartResult(
            uploadID: uploadID,
            destinationPath: destinationURL.path,
            chunkSize: maxChunkBytes,
            isComplete: false
        )
    }

    func appendUploadChunk(
        uploadID: String,
        offset: Int,
        base64Data: String,
        requester: String
    ) throws -> FileUploadChunkResult {
        cleanupExpiredTransfers()
        guard var upload = uploads[uploadID] else { throw FileUploadError.unknownUpload }
        guard upload.requester == requester else { throw FileUploadError.unauthorizedUpload }
        guard offset == upload.receivedByteCount,
              let data = Data(base64Encoded: base64Data),
              !data.isEmpty,
              data.count <= maxChunkBytes,
              upload.receivedByteCount + data.count <= upload.expectedByteCount else {
            throw FileUploadError.invalidChunk
        }

        do {
            let handle = try FileHandle(forWritingTo: upload.temporaryURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            discardUpload(uploadID)
            throw FileUploadError.writeFailed
        }

        upload.receivedByteCount += data.count
        upload.lastActivity = Date()
        let isComplete = upload.receivedByteCount == upload.expectedByteCount
        if isComplete {
            do {
                try FileManager.default.moveItem(at: upload.temporaryURL, to: upload.destinationURL)
            } catch {
                discardUpload(uploadID)
                throw FileUploadError.writeFailed
            }
            uploads.removeValue(forKey: uploadID)
            logger.info("Completed file upload requester=\(requester, privacy: .public) destination=\(upload.destinationURL.path, privacy: .private) bytes=\(upload.receivedByteCount, privacy: .public)")
        } else {
            uploads[uploadID] = upload
        }

        return FileUploadChunkResult(
            uploadID: uploadID,
            destinationPath: upload.destinationURL.path,
            receivedByteCount: upload.receivedByteCount,
            totalByteCount: upload.expectedByteCount,
            isComplete: isComplete
        )
    }

    func cancelUpload(uploadID: String, requester: String) throws -> FileTransferCancelResult {
        guard let upload = uploads[uploadID] else { throw FileUploadError.unknownUpload }
        guard upload.requester == requester else { throw FileUploadError.unauthorizedUpload }
        discardUpload(uploadID)
        return FileTransferCancelResult(transferID: uploadID)
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

        guard let byteCount = values.fileSize else { throw FileDownloadError.unavailableFileSize }
        guard byteCount <= maxTransferBytes else { throw FileDownloadError.fileTooLarge(byteCount: byteCount, limit: maxTransferBytes) }

        do {
            try authorize(url: url, roots: allowedRoots(workspacePath: workspacePath))
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

    private func uploadDestinationDirectory(_ rawPath: String, roots: [URL]) throws -> URL {
        let trimmedPath = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedPath.hasPrefix("/") else { throw FileBrowserError.notAbsolutePath }
        let url = URL(fileURLWithPath: trimmedPath, isDirectory: true)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        try authorizeBrowserDirectory(url: url, roots: roots)
        let values = try url.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true else { throw FileBrowserError.notDirectory }
        return url
    }

    private func uploadStagingDirectory(root: URL) throws -> URL {
        let stagingURL = root.appendingPathComponent(".hermes-transfer-staging", isDirectory: true).standardizedFileURL
        let resolvedURL = stagingURL.resolvingSymlinksInPath().standardizedFileURL
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: stagingURL.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue, resolvedURL == stagingURL else { throw FileUploadError.writeFailed }
        } else {
            try FileManager.default.createDirectory(
                at: stagingURL,
                withIntermediateDirectories: false,
                attributes: [.posixPermissions: 0o700]
            )
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: stagingURL.path)
        return stagingURL
    }

    private func uniqueFileURL(for url: URL) -> URL {
        let reservedPaths = Set(uploads.values.map(\.destinationURL.path))
        guard !FileManager.default.fileExists(atPath: url.path), !reservedPaths.contains(url.path) else {
            return numberedUniqueFileURL(for: url, reservedPaths: reservedPaths)
        }
        return url
    }

    private func numberedUniqueFileURL(for url: URL, reservedPaths: Set<String>) -> URL {
        let directory = url.deletingLastPathComponent()
        let baseName = url.deletingPathExtension().lastPathComponent
        let pathExtension = url.pathExtension
        for index in 1...999 {
            let name = pathExtension.isEmpty ? "\(baseName)-\(index)" : "\(baseName)-\(index).\(pathExtension)"
            let candidate = directory.appendingPathComponent(name, isDirectory: false)
            if !FileManager.default.fileExists(atPath: candidate.path), !reservedPaths.contains(candidate.path) {
                return candidate
            }
        }
        return directory.appendingPathComponent("\(UUID().uuidString)\(pathExtension.isEmpty ? "" : ".\(pathExtension)")")
    }

    private func discardUpload(_ uploadID: String) {
        guard let upload = uploads.removeValue(forKey: uploadID) else { return }
        try? FileManager.default.removeItem(at: upload.temporaryURL)
    }

    private func discardUploads(for requester: String) {
        let uploadIDs = uploads.compactMap { $0.value.requester == requester ? $0.key : nil }
        for uploadID in uploadIDs { discardUpload(uploadID) }
    }

    private func discardDownload(_ downloadID: String) {
        guard let download = downloads.removeValue(forKey: downloadID) else { return }
        try? download.handle.close()
    }

    private func discardDownloads(for requester: String) {
        let downloadIDs = downloads.compactMap { $0.value.requester == requester ? $0.key : nil }
        for downloadID in downloadIDs { discardDownload(downloadID) }
    }

    private func cleanupExpiredTransfers() {
        let expirationDate = Date().addingTimeInterval(-sessionLifetime)
        let expiredDownloads = downloads.compactMap { $0.value.lastActivity < expirationDate ? $0.key : nil }
        for downloadID in expiredDownloads { discardDownload(downloadID) }
        let expiredUploads = uploads.compactMap { $0.value.lastActivity < expirationDate ? $0.key : nil }
        for uploadID in expiredUploads { discardUpload(uploadID) }
    }

    private func cleanupAbandonedUploadFiles(in directory: URL) {
        let expirationDate = Date().addingTimeInterval(-sessionLifetime)
        let activePaths = Set(uploads.values.map(\.temporaryURL.path))
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .isRegularFileKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsSubdirectoryDescendants]
        ) else { return }
        for file in files where isGeneratedUploadFile(file) && !activePaths.contains(file.path) {
            guard let values = try? file.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  (values.contentModificationDate ?? .distantPast) < expirationDate else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func isGeneratedUploadFile(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        guard name.hasPrefix("upload-"), name.hasSuffix(".partial") else { return false }
        let start = name.index(name.startIndex, offsetBy: "upload-".count)
        let end = name.index(name.endIndex, offsetBy: -".partial".count)
        return UUID(uuidString: String(name[start..<end])) != nil
    }

    private func authorizeBrowserDirectory(url: URL, roots: [URL]) throws {
        guard roots.contains(where: { CompanionWorkspaceSecurity.isDescendant(url, of: $0) }) else {
            throw FileBrowserError.pathOutsideApprovedRoots(roots.map(\.path))
        }
        guard !isSensitivePath(url.path, roots: roots) else { throw FileDownloadError.sensitivePath }
    }

    private func authorize(url: URL, roots: [URL]) throws {
        guard roots.contains(where: { CompanionWorkspaceSecurity.isDescendant(url, of: $0) }) else {
            throw FileDownloadError.pathOutsideAllowedRoots(roots.map(\.path))
        }
        guard !isSensitivePath(url.path, roots: roots) else { throw FileDownloadError.sensitivePath }
    }

    private func allowedRoots(workspacePath _: String?) -> [URL] {
        guard let configuredHome = CompanionWorkspaceSecurity.resolvedHermesWorkspaceURL(from: transferRootPath) else {
            return []
        }
        return [configuredHome]
    }

    private func browserParentPath(for url: URL, roots: [URL]) -> String? {
        guard let root = roots.first(where: { CompanionWorkspaceSecurity.isDescendant(url, of: $0) }) else { return nil }
        guard url.path != root.path else { return nil }
        let parent = url.deletingLastPathComponent().resolvingSymlinksInPath().standardizedFileURL
        guard CompanionWorkspaceSecurity.isDescendant(parent, of: root) else { return nil }
        return parent.path
    }

    private func isSensitivePath(_ path: String, roots: [URL]) -> Bool {
        let url = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL
        guard let root = roots.first(where: { CompanionWorkspaceSecurity.isDescendant(url, of: $0) }) else {
            return true
        }
        let relativePath = String(url.path.dropFirst(root.path.count)).lowercased()
        let pathComponents = relativePath.split(separator: "/").map(String.init)
        let sensitiveComponents: Set<String> = [
            ".ssh", ".gnupg", ".hermes-transfer-staging", "keychains", "cookies", "login data", "profiles", "firefox", "chrome", "chromium", "safari"
        ]
        if pathComponents.contains(where: { sensitiveComponents.contains($0) }) { return true }
        let fileName = url.lastPathComponent.lowercased()
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
    case unavailableFileSize
    case fileTooLarge(byteCount: Int, limit: Int)
    case legacyDownloadRequiresChunking(limit: Int)
    case unknownDownload
    case unauthorizedDownload
    case invalidChunk
    case readFailed
    case serverBusy
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
        case .unavailableFileSize:
            return "The Host Companion could not determine the selected file's size."
        case .fileTooLarge(let byteCount, let limit):
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useGB]
            formatter.countStyle = .file
            return "File is too large for WebSocket download (\(formatter.string(fromByteCount: Int64(byteCount))) / \(formatter.string(fromByteCount: Int64(limit))) limit)."
        case .legacyDownloadRequiresChunking(let limit):
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return "This client can download up to \(formatter.string(fromByteCount: Int64(limit))) per request. Update HermesiOS to use chunked transfers for larger files."
        case .unknownDownload:
            return "This file download is no longer active."
        case .unauthorizedDownload:
            return "This device cannot continue another device's file download."
        case .invalidChunk:
            return "The requested file chunk is invalid."
        case .readFailed:
            return "The Host Companion could not finish reading the selected file."
        case .serverBusy:
            return "The Host Companion is already handling too many file downloads."
        case .pathOutsideAllowedRoots(let roots):
            return "File transfers are restricted to the Mac Hermes folder: \(roots.joined(separator: ", "))."
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
            return "The Mac Hermes folder at /Volumes/WDBlack4TB/.hermes is not accessible."
        case .pathOutsideApprovedRoots(let roots):
            return "The file browser is restricted to the Mac Hermes folder: \(roots.joined(separator: ", "))."
        }
    }
}

enum FileUploadError: LocalizedError {
    case invalidFileName
    case fileTooLarge(byteCount: Int, limit: Int)
    case unknownUpload
    case unauthorizedUpload
    case invalidChunk
    case sensitivePath
    case writeFailed
    case serverBusy

    var errorDescription: String? {
        switch self {
        case .invalidFileName:
            return "The iOS file name is invalid."
        case .fileTooLarge(let byteCount, let limit):
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return "File is too large for transfer (\(formatter.string(fromByteCount: Int64(byteCount))) / \(formatter.string(fromByteCount: Int64(limit))) limit)."
        case .unknownUpload:
            return "This file upload is no longer active."
        case .unauthorizedUpload:
            return "This device cannot continue another device's file upload."
        case .invalidChunk:
            return "The uploaded file chunk is invalid or out of order."
        case .sensitivePath:
            return "This file name is blocked because it may contain credentials or other sensitive data."
        case .writeFailed:
            return "The Host Companion could not save the uploaded file."
        case .serverBusy:
            return "The Host Companion is already handling the maximum reserved upload size."
        }
    }
}
