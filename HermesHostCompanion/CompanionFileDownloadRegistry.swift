//
//  CompanionFileDownloadRegistry.swift
//  HermesHostCompanion
//

import Foundation
import UniformTypeIdentifiers

struct CompanionFileDownloadRegistry {
    private let maxDownloadBytes = 100 * 1024 * 1024

    func downloadFile(path rawPath: String) throws -> FileDownloadResult {
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

        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        let fileName = values.localizedName?.isEmpty == false ? values.localizedName! : url.lastPathComponent
        return FileDownloadResult(
            path: trimmedPath,
            fileName: fileName.isEmpty ? "downloaded-file" : fileName,
            byteCount: data.count,
            contentType: values.contentType?.preferredMIMEType ?? "application/octet-stream",
            base64Data: data.base64EncodedString()
        )
    }
}

enum FileDownloadError: LocalizedError {
    case emptyPath
    case notAbsolutePath
    case notRegularFile
    case fileTooLarge(byteCount: Int, limit: Int)

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
        }
    }
}
