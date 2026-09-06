import Foundation
import XCTest
@testable import HermesiOS

@MainActor
final class HermesDashboardHistorySearchTests: XCTestCase {
    private let settings = HermesAPISettings(baseURL: "https://100.64.0.2:8642/v1")

    func testSearchReportsTotalsAndLoadsDistinctConversationPages() async throws {
        let search = HermesDashboardHistorySearchSession()
        var requestedOffsets: [Int] = []
        var requestedRoles: [String] = []
        var requestedQueries: [String] = []
        var requestedSnapshots: [String?] = []
        var requestedMessageViews: [String] = []
        search.transportOverride = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            guard request.url?.path == "/api/sessions/search/conversations" else {
                return (Data(#"window.__HERMES_SESSION_TOKEN__="token""#.utf8), response)
            }

            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            let offset = Int(components?.queryItems?.first { $0.name == "offset" }?.value ?? "0") ?? 0
            requestedOffsets.append(offset)
            requestedRoles.append(components?.queryItems?.first { $0.name == "role" }?.value ?? "")
            requestedQueries.append(components?.queryItems?.first { $0.name == "q" }?.value ?? "")
            requestedSnapshots.append(components?.queryItems?.first { $0.name == "snapshot_max_message_id" }?.value)
            requestedMessageViews.append(components?.queryItems?.first { $0.name == "message_view" }?.value ?? "")
            let sessionID = offset == 0 ? "session-a" : "session-b"
            let hasMore = offset == 0
            let body = """
            {
              "results": [{
                "session_id": "\(sessionID)",
                "session": {"id": "\(sessionID)", "title": "Conversation \(sessionID)"},
                "matches": [{"id": \(offset + 1), "session_id": "\(sessionID)", "role": "user", "snippet": "HermesiOS"}],
                "messages": [
                  {"id": "u-\(offset)", "role": "user", "content": "HermesiOS prompt"},
                  {"id": "a-\(offset)", "role": "assistant", "content": "Result"}
                ]
              }],
              "limit": 1,
              "offset": \(offset),
              "matched_messages": 70,
              "matched_sessions": 2,
              "has_more": \(hasMore),
              "next_offset": \(offset + 1),
              "snapshot_max_message_id": 50
            }
            """
            return (Data(body.utf8), response)
        }

        search.query = "HermesiOS"
        search.search(
            dashboardBaseURL: "https://100.64.0.2:8642",
            apiSettings: settings,
            limit: 1
        )
        try await waitUntil { !search.isSearching && search.results.count == 1 }

        XCTAssertEqual(search.matchedMessages, 70)
        XCTAssertEqual(search.matchedSessions, 2)
        XCTAssertTrue(search.hasMoreResults)
        XCTAssertEqual(search.status, "Showing 1 of 2 conversations")

        search.query = "different query"
        search.loadMore(
            dashboardBaseURL: "https://100.64.0.2:8642",
            apiSettings: settings,
            profileFilter: "Work",
            limit: 1
        )
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(requestedOffsets, [0])
        XCTAssertEqual(search.results.map(\.sessionID), ["session-a"])

        search.query = "HermesiOS"

        search.loadMore(
            dashboardBaseURL: "https://100.64.0.2:8642",
            apiSettings: settings,
            limit: 1
        )
        try await waitUntil { !search.isSearching && search.results.count == 2 }

        XCTAssertEqual(search.results.map(\.sessionID), ["session-a", "session-b"])
        XCTAssertEqual(requestedOffsets, [0, 1])
        XCTAssertEqual(requestedRoles, ["user,assistant", "user,assistant"])
        XCTAssertEqual(requestedQueries, ["HermesiOS", "HermesiOS"])
        XCTAssertEqual(requestedSnapshots, [nil, "50"])
        XCTAssertEqual(requestedMessageViews, ["summary", "summary"])
        XCTAssertFalse(search.hasMoreResults)
        XCTAssertEqual(search.status, "Showing 2 of 2 conversations")
    }

    private func waitUntil(
        timeout: Duration = .seconds(2),
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() {
            guard clock.now < deadline else {
                XCTFail("Timed out waiting for history search state")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}
