import XCTest
import UIKit
@testable import HermesiOS

@MainActor
final class HermesTUIAttachmentTests: XCTestCase {
    private func store() -> HermesTUIGatewayStore {
        let store = HermesTUIGatewayStore()
        store.isConnected = true
        store.sessionID = "attachment-session"
        return store
    }

    // Incompressible pixels give us a real multi-MiB PNG without a checked-in binary.
    private func imageFixture() throws -> Data {
        var seed: UInt32 = 42
        var pixels = Data(count: 1024 * 1024 * 4)
        pixels.withUnsafeMutableBytes { (bytes: UnsafeMutableRawBufferPointer) in
            for i in bytes.indices {
                seed = 1664525 &* seed &+ 1013904223
                bytes[i] = i % 4 == 3 ? 255 : UInt8(truncatingIfNeeded: seed >> 24)
            }
        }
        let provider = try XCTUnwrap(CGDataProvider(data: pixels as CFData))
        let image = try XCTUnwrap(CGImage(width: 1024, height: 1024, bitsPerComponent: 8,
            bitsPerPixel: 32, bytesPerRow: 4096, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let data = try XCTUnwrap(UIImage(cgImage: image).pngData())
        XCTAssertGreaterThan(data.count, 2 * 1024 * 1024)
        return data
    }

    func testMultiMegabyteImageUsesDedicatedUploadThenShortPrompt() async throws {
        let data = try imageFixture()
        // Files providers can report a generic type; the supported extension owns image MIME.
        let attachment = try HermesPromptAttachment(filename: "shot.png", contentType: .data, data: data)
        let store = store()
        var calls: [String] = []
        store.requestOverride = { method, params in
            calls.append(method)
            XCTAssertEqual(params["session_id"], .string("attachment-session"))
            if method == "image.attach_bytes" {
                XCTAssertFalse(store.canSendPrompt, "Upload must reserve this turn")
                XCTAssertEqual(params["filename"], .string("shot.png"))
                let encoded = try XCTUnwrap(params["content_base64"]?.stringValue)
                XCTAssertTrue(encoded.hasPrefix("data:image/png;base64,"))
                let decoded = Data(base64Encoded: String(encoded.dropFirst("data:image/png;base64,".count)))
                XCTAssertTrue(decoded == data)
                return .object(["attached": .bool(true), "path": .string("/fixture/images/shot.png")])
            }
            XCTAssertEqual(method, "prompt.submit")
            let prompt = try XCTUnwrap(params["text"]?.stringValue)
            XCTAssertEqual(prompt, "Describe this")
            XCTAssertEqual(params["provider"], .string("test-provider"))
            XCTAssertEqual(params["model"], .string("test-model"))
            XCTAssertLessThan(try JSONEncoder().encode(params).count, 1024)
            return .object([:])
        }
        await store.submit("Describe this", attachment: attachment,
            inference: .init(provider: "test-provider", model: "test-model"))
        XCTAssertEqual(calls, ["image.attach_bytes", "prompt.submit"])
        XCTAssertTrue(store.messages.allSatisfy { !$0.content.contains("base64,") && $0.content.count < 1024 })
    }

    func testBinaryAndInvalidUTF8UseFileReferenceNotBase64Text() async throws {
        for name in ["report.pdf", "report.docx", "broken.txt"] {
            let data = Data(repeating: 0xff, count: 3 * 1024 * 1024)
            let attachment = try HermesPromptAttachment(filename: name, contentType: nil, data: data)
            let store = store()
            var calls: [String] = []
            store.requestOverride = { method, params in
                calls.append(method)
                if method == "file.attach" {
                    XCTAssertEqual(params["name"], .string(name))
                    let encoded = try XCTUnwrap(params["data_url"]?.stringValue)
                    XCTAssertTrue(encoded.hasPrefix("data:\(attachment.mimeType);base64,"))
                    XCTAssertTrue(Data(base64Encoded: String(encoded.split(separator: ",", maxSplits: 1)[1])) == data)
                    return .object(["attached": .bool(true), "ref_text": .string("@file:`/fixture/report file.pdf`")])
                }
                XCTAssertEqual(params["text"], .string("Inspect\n\n@file:`/fixture/report file.pdf`"))
                XCTAssertLessThan(try JSONEncoder().encode(params).count, 1024)
                return .object([:])
            }
            await store.submit("Inspect", attachment: attachment, inference: .init())
            XCTAssertEqual(calls, ["file.attach", "prompt.submit"])
            XCTAssertTrue(store.messages.allSatisfy { !$0.content.contains("base64,") })
        }
    }

    func testSmallUTF8InlineAndLargeUTF8UploadedWithoutTruncation() async throws {
        for size in [32 * 1024, 32 * 1024 + 1] {
            let data = Data(repeating: 65, count: size)
            let attachment = try HermesPromptAttachment(filename: "notes.txt", contentType: nil, data: data)
            let store = store()
            var calls: [String] = []
            store.requestOverride = { method, params in
                calls.append(method)
                if method == "file.attach" {
                    return .object(["attached": .bool(true), "ref_text": .string("@file:/fixture/notes.txt")])
                }
                let prompt = try XCTUnwrap(params["text"]?.stringValue)
                if size == 32 * 1024 {
                    XCTAssertTrue(prompt.contains(String(decoding: data, as: UTF8.self)))
                    XCTAssertLessThan(prompt.utf8.count, size + 1024)
                } else {
                    XCTAssertEqual(prompt, "Read\n\n@file:/fixture/notes.txt")
                }
                return .object([:])
            }
            await store.submit("Read", attachment: attachment, inference: .init())
            XCTAssertEqual(calls, size == 32 * 1024 ? ["prompt.submit"] : ["file.attach", "prompt.submit"])
        }
    }

    func testAttachmentOnlyImageHasShortDefaultPrompt() async throws {
        let attachment = try HermesPromptAttachment(filename: "shot.png", contentType: nil, data: Data([1]))
        let store = store()
        store.requestOverride = { method, params in
            if method == "image.attach_bytes" {
                return .object(["attached": .bool(true), "path": .string("/fixture/shot.png")])
            }
            XCTAssertEqual(params["text"], .string("What do you see in this image?"))
            return .object([:])
        }
        await store.submit("", attachment: attachment, inference: .init())
        XCTAssertTrue(store.isStreaming)
    }

    func testRejectedOrMalformedUploadNeverSubmits() async throws {
        for result in [JSONValue.object([:]), .object(["attached": .bool(false)]),
                       .object(["attached": .bool(true), "ref_text": .string("data:application/pdf;base64,AAAA")])] {
            let attachment = try HermesPromptAttachment(filename: "a.pdf", contentType: nil, data: Data([1]))
            let store = store()
            var calls: [String] = []
            store.requestOverride = { method, _ in calls.append(method); return result }
            await store.submit("Read", attachment: attachment, inference: .init())
            XCTAssertEqual(calls, ["file.attach"])
            XCTAssertFalse(store.isStreaming)
            XCTAssertFalse(store.lastErrorMessage.isEmpty)
            XCTAssertTrue(store.messages.isEmpty)
        }
    }

    func testUploadFailureDoesNotFallBackToPromptText() async throws {
        let attachment = try HermesPromptAttachment(filename: "a.png", contentType: nil, data: Data([1]))
        let store = store()
        var calls: [String] = []
        store.requestOverride = { method, _ in
            calls.append(method)
            throw NSError(domain: "fixture", code: -32601)
        }
        await store.submit("Read", attachment: attachment, inference: .init())
        XCTAssertEqual(calls, ["image.attach_bytes"])
        XCTAssertFalse(store.isStreaming)
        XCTAssertTrue(store.messages.isEmpty)
    }

    func testResumedNativeImageAndLegacyBinaryDoNotReinflateTranscript() {
        let encoded = Data(repeating: 0xff, count: 3 * 1024 * 1024).base64EncodedString()
        let store = store()
        store.restoreMessages(from: [
            .object(["role": .string("user"), "content": .string("Describe\ndata:image/png;base64,\(encoded)")]),
            .object(["role": .string("user"), "content": .string("Read\ndata:application/pdf;base64,\(encoded)")])
        ])
        XCTAssertEqual(store.messages.map(\.content), ["Describe\n[Attached media]", "Read\n[Attached media]"])
    }

    func testEmptyAttachmentFailsBeforeAnyRPC() async throws {
        let attachment = try HermesPromptAttachment(filename: "empty.png", contentType: nil, data: Data())
        let store = store()
        store.requestOverride = { _, _ in XCTFail("Invalid size reached transport"); return .object([:]) }
        await store.submit("Describe", attachment: attachment, inference: .init())
        XCTAssertFalse(store.isStreaming)
        XCTAssertFalse(store.lastErrorMessage.isEmpty)
    }

    func testOversizeAttachmentCannotBeConstructed() {
        XCTAssertThrowsError(
            try HermesPromptAttachment(
                filename: "large.png",
                contentType: nil,
                data: Data(repeating: 1, count: HermesPromptAttachment.maxFileBytes + 1)
            )
        ) { error in
            guard case HermesAttachmentError.fileTooLarge = error else {
                return XCTFail("Expected fileTooLarge, got \(error)")
            }
        }
    }

    func testHTTPPromptEmbeddingAcceptsOnlyBoundedUTF8Text() throws {
        let boundedText = try HermesPromptAttachment(
            filename: "notes.txt",
            contentType: .plainText,
            data: Data(repeating: 65, count: 32 * 1024)
        )
        let oversizedText = try HermesPromptAttachment(
            filename: "notes.txt",
            contentType: .plainText,
            data: Data(repeating: 65, count: 32 * 1024 + 1)
        )
        let binary = try HermesPromptAttachment(
            filename: "report.pdf",
            contentType: .pdf,
            data: Data([0xFF, 0x00])
        )

        XCTAssertNotNil(boundedText.httpTextAttachmentBlock)
        XCTAssertNil(oversizedText.httpTextAttachmentBlock)
        XCTAssertNil(binary.httpTextAttachmentBlock)
    }

    func testFileImportRejectsOversizedAttachmentBeforeLoadingIt() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("oversized-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(repeating: 65, count: 25 * 1024 * 1024 + 1).write(to: url)

        XCTAssertThrowsError(try HermesPromptAttachment.load(from: url)) { error in
            guard case HermesAttachmentError.fileTooLarge = error else {
                return XCTFail("Expected fileTooLarge, got \(error)")
            }
        }
    }

    func testBoundedFileReadNeverReturnsMoreThanAttachmentLimit() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("bounded-\(UUID().uuidString).txt")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(repeating: 65, count: HermesPromptAttachment.maxFileBytes + 1).write(to: url)

        XCTAssertThrowsError(try HermesPromptAttachment.readBoundedData(from: url)) { error in
            guard case HermesAttachmentError.fileTooLarge = error else {
                return XCTFail("Expected fileTooLarge, got \(error)")
            }
        }
    }

    func testDisconnectDuringUploadCannotSendIntoReplacementSession() async throws {
        let attachment = try HermesPromptAttachment(filename: "a.png", contentType: nil, data: Data([1]))
        let store = store()
        var calls: [String] = []
        store.requestOverride = { method, _ in
            calls.append(method)
            store.disconnect()
            store.sessionID = "replacement"
            store.isConnected = true
            return .object(["attached": .bool(true), "path": .string("/fixture/a.png")])
        }
        await store.submit("Read", attachment: attachment, inference: .init())
        XCTAssertEqual(calls, ["image.attach_bytes"])
        XCTAssertTrue(store.messages.isEmpty)
    }
}
