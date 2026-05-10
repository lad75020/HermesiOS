//
//  CompanionFileDownloadRegistry.swift
//  HermesHostCompanion
//

import Foundation
import UniformTypeIdentifiers

struct CompanionFileDownloadRegistry {
    private let maxDownloadBytes = 100 * 1024 * 1024
    private let maxChunkBytes = 384 * 1024

    func downloadFile(path rawPath: String) throws -> FileDownloadResult {
        let metadata = try fileMetadata(for: rawPath)
        let data = try Data(contentsOf: metadata.url, options: [.mappedIfSafe])
        return FileDownloadResult(
            path: metadata.path,
            fileName: metadata.fileName,
            byteCount: data.count,
            contentType: metadata.contentType,
            base64Data: data.base64EncodedString()
        )
    }

    func downloadFileInfo(path rawPath: String) throws -> FileDownloadInfoResult {
        let metadata = try fileMetadata(for: rawPath)
        return FileDownloadInfoResult(
            path: metadata.path,
            fileName: metadata.fileName,
            byteCount: metadata.byteCount,
            contentType: metadata.contentType,
            chunkSize: maxChunkBytes
        )
    }

    func downloadFileChunk(path rawPath: String, offset: Int, length: Int) throws -> FileDownloadChunkResult {
        let metadata = try fileMetadata(for: rawPath)
        guard offset >= 0 else { throw FileDownloadError.invalidChunk }
        guard length > 0 else { throw FileDownloadError.invalidChunk }
        guard offset <= metadata.byteCount else { throw FileDownloadError.invalidChunk }

        let safeLength = min(length, maxChunkBytes, metadata.byteCount - offset)
        let handle = try FileHandle(forReadingFrom: metadata.url)
        defer { try? handle.close() }
        try handle.seek(toOffset: UInt64(offset))
        let data = try handle.read(upToCount: safeLength) ?? Data()
        let nextOffset = offset + data.count
        return FileDownloadChunkResult(
            path: metadata.path,
            offset: offset,
            byteCount: data.count,
            totalByteCount: metadata.byteCount,
            isComplete: nextOffset >= metadata.byteCount,
            base64Data: data.base64EncodedString()
        )
    }

    private func fileMetadata(for rawPath: String) throws -> FileDownloadMetadata {
        let trimmedPath = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedPath.isEmpty == false else {
            throw FileDownloadError.emptyPath
        }
        guard trimmedPath.hasPrefix("/") else {
            throw FileDownloadError.notAbsolutePath
        }

        let url = URL(fileURLWithPath: trimmedPath, isDirectory: false).standardizedFileURL
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey, .contentTypeKey, .localizedNameKey])
        guard values.isRegularFile == true else {
            throw FileDownloadError.notRegularFile
        }
        let byteCount = values.fileSize ?? 0
        guard byteCount <= maxDownloadBytes else {
            throw FileDownloadError.fileTooLarge(byteCount: byteCount, limit: maxDownloadBytes)
        }
        let fileName = values.localizedName?.isEmpty == false ? values.localizedName! : url.lastPathComponent
        return FileDownloadMetadata(
            url: url,
            path: trimmedPath,
            fileName: fileName.isEmpty ? "downloaded-file" : fileName,
            byteCount: byteCount,
            contentType: values.contentType?.preferredMIMEType ?? "application/octet-stream"
        )
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
        }
    }
}
