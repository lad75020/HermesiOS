import Synchronization
import XCTest
@testable import HermesiOS

final class QRScannerCaptureSessionTests: XCTestCase {
    func testCaptureLifecycleRunsSeriallyOffMainAndStopsOnce() async {
        let events = Mutex<[(String, Bool)]>([])
        let capture = QRScannerCaptureSession(testOperations: QRScannerTestOperations(
            prepare: { events.withLock { $0.append(("prepare", Thread.isMainThread)) } },
            start: { events.withLock { $0.append(("start", Thread.isMainThread)) } },
            stop: { events.withLock { $0.append(("stop", Thread.isMainThread)) } }
        ))

        let prepared = await capture.prepare()
        await capture.start()
        await capture.stop()
        await capture.stop()
        await capture.start()
        let preparedAfterDismiss = await capture.prepare()

        XCTAssertTrue(prepared)
        XCTAssertFalse(preparedAfterDismiss)
        let recorded = events.withLock { $0 }
        XCTAssertEqual(recorded.map(\.0), ["prepare", "start", "stop"])
        XCTAssertTrue(recorded.allSatisfy { !$0.1 })
    }

    func testDismissBeforePreparationPreventsStart() async {
        let events = Mutex<[String]>([])
        let capture = QRScannerCaptureSession(testOperations: QRScannerTestOperations(
            prepare: { events.withLock { $0.append("prepare") } },
            start: { events.withLock { $0.append("start") } },
            stop: { events.withLock { $0.append("stop") } }
        ))

        await capture.stop()
        let prepared = await capture.prepare()
        await capture.start()

        XCTAssertFalse(prepared)
        XCTAssertEqual(events.withLock { $0 }, ["stop"])
    }
}
