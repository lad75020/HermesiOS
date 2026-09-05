import XCTest
@testable import HermesiOS

@MainActor
final class HermesTUIGatewayNotificationTests: XCTestCase {
    private func send(_ type: String, to store: HermesTUIGatewayStore) async {
        await store.handleWebSocketText("{\"jsonrpc\":\"2.0\",\"method\":\"event\",\"params\":{\"type\":\"\(type)\",\"session_id\":\"\",\"payload\":{}}}")
    }

    func testGlobalChangesLeaveIdleConversationUntouched() async {
        let store = HermesTUIGatewayStore()
        let types = ["sessions.changed", "cron.changed", "platforms.changed", "pairing.changed", "pet.changed", "skin.changed"]
        for type in types {
            await send(type, to: store)
            XCTAssertEqual(store.connectionStatus, "Idle", type)
            XCTAssertTrue(store.messages.isEmpty, type)
            XCTAssertFalse(store.isStreaming, type)
            XCTAssertTrue(store.sessionID.isEmpty, type)
        }
        XCTAssertEqual(store.eventCount, types.count)
    }

    func testGlobalChangePreservesStreamingAndCompletionStatus() async {
        let store = HermesTUIGatewayStore()
        await send("message.start", to: store)
        await send("sessions.changed", to: store)
        XCTAssertTrue(store.isStreaming)
        XCTAssertEqual(store.connectionStatus, "Hermes is responding")
        XCTAssertTrue(store.messages.isEmpty)
        await send("message.complete", to: store)
        await send("sessions.changed", to: store)
        XCTAssertFalse(store.isStreaming)
        XCTAssertEqual(store.connectionStatus, "Completed")
        XCTAssertTrue(store.messages.isEmpty)
        XCTAssertEqual(store.eventCount, 4)
    }

    func testUnknownChangesAreNotSilentlyDiscarded() async {
        let store = HermesTUIGatewayStore()
        await send("custom.changed", to: store)
        XCTAssertEqual(store.messages.count, 1)
        XCTAssertEqual(store.messages.first?.eventType, "custom.changed")
        XCTAssertEqual(store.eventCount, 1)
    }
}
