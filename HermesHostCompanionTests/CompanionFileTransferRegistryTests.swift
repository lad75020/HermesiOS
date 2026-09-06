import Foundation
import XCTest
@testable import HermesHostCompanion

@MainActor
final class CompanionFileTransferRegistryTests: XCTestCase {
    func testChunkedUploadWritesFileWithoutOverwritingExistingFile() throws {
        try withApprovedWorkspace { workspace in
            let destination = workspace.appendingPathComponent("uploads", isDirectory: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try Data("existing".utf8).write(to: destination.appendingPathComponent("report.txt"))

            let registry = CompanionFileDownloadRegistry(transferRootPath: workspace.path)
            let payload = Data("uploaded content".utf8)
            let start = try registry.startUpload(
                destinationPath: destination.path,
                fileName: "report.txt",
                byteCount: payload.count,
                workspacePath: workspace.path,
                requester: "device-a"
            )

            let first = payload.prefix(5)
            let second = payload.dropFirst(5)
            let partial = try registry.appendUploadChunk(
                uploadID: start.uploadID,
                offset: 0,
                base64Data: Data(first).base64EncodedString(),
                requester: "device-a"
            )
            XCTAssertFalse(partial.isComplete)

            let completed = try registry.appendUploadChunk(
                uploadID: start.uploadID,
                offset: first.count,
                base64Data: Data(second).base64EncodedString(),
                requester: "device-a"
            )

            XCTAssertTrue(completed.isComplete)
            XCTAssertEqual(completed.receivedByteCount, payload.count)
            XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: completed.destinationPath)), payload)
            XCTAssertEqual(try Data(contentsOf: destination.appendingPathComponent("report.txt")), Data("existing".utf8))
            XCTAssertNotEqual(completed.destinationPath, destination.appendingPathComponent("report.txt").path)
        }
    }

    func testConcurrentUploadsReserveDifferentDestinationPaths() throws {
        try withApprovedWorkspace { workspace in
            let destination = workspace.appendingPathComponent("uploads", isDirectory: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            let registry = CompanionFileDownloadRegistry(transferRootPath: workspace.path)
            let firstData = Data("first".utf8)
            let secondData = Data("second".utf8)

            let first = try registry.startUpload(
                destinationPath: destination.path,
                fileName: "shared.txt",
                byteCount: firstData.count,
                workspacePath: "/ignored",
                requester: "device-a"
            )
            let second = try registry.startUpload(
                destinationPath: destination.path,
                fileName: "shared.txt",
                byteCount: secondData.count,
                workspacePath: "/ignored",
                requester: "device-b"
            )

            XCTAssertNotEqual(first.destinationPath, second.destinationPath)

            let firstResult = try registry.appendUploadChunk(
                uploadID: first.uploadID,
                offset: 0,
                base64Data: firstData.base64EncodedString(),
                requester: "device-a"
            )
            let secondResult = try registry.appendUploadChunk(
                uploadID: second.uploadID,
                offset: 0,
                base64Data: secondData.base64EncodedString(),
                requester: "device-b"
            )

            XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: firstResult.destinationPath)), firstData)
            XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: secondResult.destinationPath)), secondData)
        }
    }

    func testUploadRejectsTraversalSensitiveNamesAndWrongRequester() throws {
        try withApprovedWorkspace { workspace in
            let destination = workspace.appendingPathComponent("uploads", isDirectory: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            let registry = CompanionFileDownloadRegistry(transferRootPath: workspace.path)

            XCTAssertThrowsError(try registry.startUpload(
                destinationPath: destination.path,
                fileName: "../escape.txt",
                byteCount: 1,
                workspacePath: workspace.path,
                requester: "device-a"
            ))
            XCTAssertThrowsError(try registry.startUpload(
                destinationPath: destination.path,
                fileName: ".env",
                byteCount: 1,
                workspacePath: workspace.path,
                requester: "device-a"
            ))

            let start = try registry.startUpload(
                destinationPath: destination.path,
                fileName: "safe.txt",
                byteCount: 1,
                workspacePath: workspace.path,
                requester: "device-a"
            )
            XCTAssertThrowsError(try registry.appendUploadChunk(
                uploadID: start.uploadID,
                offset: 0,
                base64Data: Data([1]).base64EncodedString(),
                requester: "device-b"
            ))
        }
    }

    func testTransferLimitAllowsOneGigabyteAndRejectsAnythingLarger() throws {
        try withApprovedWorkspace { workspace in
            let destination = workspace.appendingPathComponent("uploads", isDirectory: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            let source = workspace.appendingPathComponent("large.bin")
            FileManager.default.createFile(atPath: source.path, contents: nil)
            let handle = try FileHandle(forWritingTo: source)
            defer { try? handle.close() }
            let registry = CompanionFileDownloadRegistry(transferRootPath: workspace.path)

            try handle.truncate(atOffset: 1_000_000_000)
            let info = try registry.downloadFileInfo(
                path: source.path,
                workspacePath: workspace.path,
                requester: "device-a"
            )
            XCTAssertEqual(info.byteCount, 1_000_000_000)
            XCTAssertNoThrow(try registry.startUpload(
                destinationPath: destination.path,
                fileName: "accepted.bin",
                byteCount: 1_000_000_000,
                workspacePath: workspace.path,
                requester: "device-a"
            ))

            try handle.truncate(atOffset: 1_000_000_001)
            XCTAssertThrowsError(try registry.downloadFileInfo(
                path: source.path,
                workspacePath: workspace.path,
                requester: "device-a"
            ))
            XCTAssertThrowsError(try registry.startUpload(
                destinationPath: destination.path,
                fileName: "rejected.bin",
                byteCount: 1_000_000_001,
                workspacePath: workspace.path,
                requester: "device-a"
            ))
        }
    }

    func testFileTransferCannotEscapeConfiguredTransferRoot() throws {
        try withApprovedWorkspace { workspace in
            let outside = FileManager.default.temporaryDirectory
                .appendingPathComponent("outside-hermes-file-transfer-\(UUID().uuidString)", isDirectory: true)
            defer { try? FileManager.default.removeItem(at: outside) }
            try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
            let outsideFile = outside.appendingPathComponent("outside.txt")
            try Data("outside".utf8).write(to: outsideFile)
            let registry = CompanionFileDownloadRegistry(transferRootPath: workspace.path)

            XCTAssertThrowsError(try registry.listDirectory(
                path: outside.path,
                workspacePath: outside.path,
                requester: "device-a"
            ))
            XCTAssertThrowsError(try registry.downloadFileInfo(
                path: outsideFile.path,
                workspacePath: outside.path,
                requester: "device-a"
            ))
            XCTAssertThrowsError(try registry.startUpload(
                destinationPath: outside.path,
                fileName: "upload.txt",
                byteCount: 1,
                workspacePath: outside.path,
                requester: "device-a"
            ))

            XCTAssertNoThrow(try registry.listDirectory(
                path: workspace.path,
                workspacePath: outside.path,
                requester: "device-a"
            ))
        }
    }

    func testDownloadUsesStableFileDescriptorAndRequiresOwningRequester() throws {
        try withApprovedWorkspace { workspace in
            let source = workspace.appendingPathComponent("source.txt")
            let replacement = workspace.appendingPathComponent("replacement.txt")
            let originalData = Data("original file contents".utf8)
            let replacementData = Data("replacement contents!!".utf8)
            XCTAssertEqual(originalData.count, replacementData.count)
            try originalData.write(to: source)
            try replacementData.write(to: replacement)

            let registry = CompanionFileDownloadRegistry(transferRootPath: workspace.path)
            let info = try registry.downloadFileInfo(
                path: source.path,
                workspacePath: workspace.path,
                requester: "device-a"
            )

            XCTAssertThrowsError(try registry.downloadFileChunk(
                downloadID: info.downloadID,
                offset: 0,
                length: info.chunkSize,
                requester: "device-b"
            ))

            try FileManager.default.removeItem(at: source)
            try FileManager.default.moveItem(at: replacement, to: source)

            let chunk = try registry.downloadFileChunk(
                downloadID: info.downloadID,
                offset: 0,
                length: info.chunkSize,
                requester: "device-a"
            )
            XCTAssertTrue(chunk.isComplete)
            XCTAssertEqual(Data(base64Encoded: chunk.base64Data), originalData)
            XCTAssertThrowsError(try registry.cancelDownload(downloadID: info.downloadID, requester: "device-a"))
        }
    }

    func testCancelledUploadRemovesPrivateStagingFile() throws {
        try withApprovedWorkspace { workspace in
            let destination = workspace.appendingPathComponent("uploads", isDirectory: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            let registry = CompanionFileDownloadRegistry(transferRootPath: workspace.path)
            let start = try registry.startUpload(
                destinationPath: destination.path,
                fileName: "cancelled.txt",
                byteCount: 4,
                workspacePath: workspace.path,
                requester: "device-a"
            )
            let stagedFile = workspace
                .appendingPathComponent(".hermes-transfer-staging", isDirectory: true)
                .appendingPathComponent("upload-\(start.uploadID).partial")
            XCTAssertTrue(FileManager.default.fileExists(atPath: stagedFile.path))

            _ = try registry.appendUploadChunk(
                uploadID: start.uploadID,
                offset: 0,
                base64Data: Data("a".utf8).base64EncodedString(),
                requester: "device-a"
            )
            XCTAssertThrowsError(try registry.cancelUpload(uploadID: start.uploadID, requester: "device-b"))
            XCTAssertTrue(FileManager.default.fileExists(atPath: stagedFile.path))

            let cancellation = try registry.cancelUpload(uploadID: start.uploadID, requester: "device-a")
            XCTAssertEqual(cancellation.transferID, start.uploadID)
            XCTAssertFalse(FileManager.default.fileExists(atPath: stagedFile.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: destination.appendingPathComponent("cancelled.txt").path))
        }
    }

    func testUploadReservationsAreBounded() throws {
        try withApprovedWorkspace { workspace in
            let destination = workspace.appendingPathComponent("uploads", isDirectory: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            let registry = CompanionFileDownloadRegistry(transferRootPath: workspace.path)

            XCTAssertNoThrow(try registry.startUpload(
                destinationPath: destination.path,
                fileName: "first.bin",
                byteCount: 1_000_000_000,
                workspacePath: workspace.path,
                requester: "device-a"
            ))
            XCTAssertNoThrow(try registry.startUpload(
                destinationPath: destination.path,
                fileName: "second.bin",
                byteCount: 1_000_000_000,
                workspacePath: workspace.path,
                requester: "device-b"
            ))
            XCTAssertThrowsError(try registry.startUpload(
                destinationPath: destination.path,
                fileName: "over-capacity.bin",
                byteCount: 1,
                workspacePath: workspace.path,
                requester: "device-c"
            ))
        }
    }

    func testLegacyDownloadRemainsAvailableForSmallFilesOnly() throws {
        try withApprovedWorkspace { workspace in
            let smallFile = workspace.appendingPathComponent("small.txt")
            let largeFile = workspace.appendingPathComponent("large.bin")
            let smallData = Data("legacy".utf8)
            try smallData.write(to: smallFile)
            FileManager.default.createFile(atPath: largeFile.path, contents: nil)
            let handle = try FileHandle(forWritingTo: largeFile)
            defer { try? handle.close() }
            try handle.truncate(atOffset: UInt64(384 * 1024 + 1))

            let registry = CompanionFileDownloadRegistry(transferRootPath: workspace.path)
            let result = try registry.downloadFile(
                path: smallFile.path,
                workspacePath: workspace.path,
                requester: "legacy-device"
            )
            XCTAssertEqual(Data(base64Encoded: result.base64Data), smallData)
            XCTAssertThrowsError(try registry.downloadFile(
                path: largeFile.path,
                workspacePath: workspace.path,
                requester: "legacy-device"
            ))
        }
    }

    func testLegacyPathBasedChunkRemainsAvailable() throws {
        try withApprovedWorkspace { workspace in
            let source = workspace.appendingPathComponent("legacy-chunk.txt")
            let data = Data("legacy chunk".utf8)
            try data.write(to: source)

            let registry = CompanionFileDownloadRegistry(transferRootPath: workspace.path)
            let result = try registry.downloadFileChunkLegacy(
                path: source.path,
                offset: 0,
                length: 384 * 1024,
                workspacePath: workspace.path,
                requester: "legacy-device"
            )
            XCTAssertTrue(result.isComplete)
            XCTAssertEqual(Data(base64Encoded: result.base64Data), data)
        }
    }

    private func withApprovedWorkspace(_ body: (URL) throws -> Void) throws {
        let workspace = FileManager.default.temporaryDirectory
            .appendingPathComponent("hermes-file-transfer-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: workspace)
        }
        try FileManager.default.createDirectory(
            at: workspace.appendingPathComponent("skills", isDirectory: true),
            withIntermediateDirectories: true
        )
        try body(workspace)
    }
}
