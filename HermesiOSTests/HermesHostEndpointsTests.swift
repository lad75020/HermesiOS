import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import HermesiOS

final class HermesHostEndpointsTests: XCTestCase {
    func testNormalizedHostStripsSchemePortAndPath() {
        XCTAssertEqual(
            HermesHostEndpoints.normalizedHost("  https://macbook.example.ts.net:9112/ws  "),
            "macbook.example.ts.net"
        )
        XCTAssertEqual(HermesHostEndpoints.normalizedHost("example.com:8642/v1"), "example.com")
        XCTAssertEqual(HermesHostEndpoints.normalizedHost("   "), defaultHermesMacHost)
    }

    func testRemoteEndpointsUseTLSAndRemoteDashboardPortMigration() {
        XCTAssertEqual(
            HermesHostEndpoints.webSocketURLString(host: "companion.example.com", port: "9112"),
            "wss://companion.example.com:9112/ws"
        )
        XCTAssertEqual(
            HermesHostEndpoints.remoteDashboardPort(from: legacyLocalHermesDashboardPort, host: "companion.example.com"),
            defaultHermesDashboardPort
        )
        XCTAssertEqual(
            HermesHostEndpoints.remoteDashboardPort(from: legacyLocalHermesDashboardPort, host: "localhost"),
            legacyLocalHermesDashboardPort
        )
    }

    func testPlaintextSensitiveEndpointsAreLimitedToLoopbackAndTailnet() throws {
        let remote = try XCTUnwrap(URL(string: "http://example.com/v1"))
        let loopback = try XCTUnwrap(URL(string: "http://127.0.0.1:8642/v1"))
        let tailnet = try XCTUnwrap(URL(string: "ws://macbook.example.ts.net:9112/ws"))

        XCTAssertFalse(HermesEndpointSecurity.isPlaintextTransportAllowed(for: remote))
        XCTAssertTrue(HermesEndpointSecurity.isPlaintextTransportAllowed(for: loopback))
        XCTAssertTrue(HermesEndpointSecurity.isPlaintextTransportAllowed(for: tailnet))
        XCTAssertNotNil(HermesEndpointSecurity.plaintextTransportWarning(for: remote.absoluteString, endpointName: "Hermes API"))
        XCTAssertNil(HermesEndpointSecurity.plaintextTransportWarning(for: loopback.absoluteString, endpointName: "Hermes API"))
        XCTAssertThrowsError(try HermesEndpointSecurity.validateSensitiveURL(remote))
        XCTAssertNoThrow(try HermesEndpointSecurity.validateSensitiveURL(tailnet))
    }
}

final class HermesPhonePrimaryTabTests: XCTestCase {
    func testIPhoneUsesSingleLandingPageAtEveryWidth() {
        XCTAssertEqual(HermesRootLayout.resolve(idiom: .phone, isCompact: true), .phone)
        XCTAssertEqual(HermesRootLayout.resolve(idiom: .phone, isCompact: false), .phone)
    }

    func testIPadKeepsItsExistingCompactTabsAndRegularSplitLayout() {
        XCTAssertEqual(HermesRootLayout.resolve(idiom: .pad, isCompact: true), .compactPad)
        XCTAssertEqual(HermesRootLayout.resolve(idiom: .pad, isCompact: false), .split)
    }

    @MainActor
    func testMorePathSupportsWorkspaceThenRuntimePanelAndBack() {
        for category in HermesRuntimePanelKind.primaryCategories + HermesRuntimePanelKind.secondaryCategories {
            var path = NavigationPath([WorkspaceSection.runtime])
            path.append(category)
            XCTAssertEqual(path.count, 2)
            path.removeLast()
            XCTAssertEqual(path, NavigationPath([WorkspaceSection.runtime]))
            path.removeLast()
            XCTAssertTrue(path.isEmpty)
        }
    }

    func testCompactIPadTabsStillContainOnlyTUIAndMore() {
        XCTAssertEqual(HermesPhonePrimaryTab.allCases.map(\.title), ["TUI", "More"])
        XCTAssertFalse(HermesPhonePrimaryTab.allCases.map(\.systemImage).contains("dot.radiowaves.left.and.right"))
        XCTAssertFalse(HermesPhonePrimaryTab.allCases.map(\.systemImage).contains("text.bubble"))
    }

    func testRemovedConsoleSectionsResolveToTUIGateway() {
        XCTAssertEqual(HermesPhonePrimaryTab.resolve(for: .responses), .tuiGateway)
        XCTAssertEqual(HermesPhonePrimaryTab.resolve(for: .chat), .tuiGateway)
        XCTAssertEqual(HermesPhonePrimaryTab.resolve(for: .history), .more)
    }

    func testWorkspaceInventoryContainsOnlySupportedDestinations() {
        XCTAssertEqual(WorkspaceSection.allCases, [
            .responses, .chat, .tuiGateway, .history, .web,
            .terminal, .utilities, .settings, .runtime
        ])
        XCTAssertEqual(HermesPhonePrimaryTab.tuiGateway.selectedSection, .tuiGateway)
        XCTAssertNil(HermesPhonePrimaryTab.more.selectedSection)
        for section in [WorkspaceSection.history, .web, .terminal, .utilities, .settings, .runtime] {
            XCTAssertEqual(HermesPhonePrimaryTab.resolve(for: section), .more)
        }
    }
}

@MainActor
final class HermesTUIHistoryResumeCoordinatorTests: XCTestCase {
    func testUsesAvailableInactiveWorkspaceWithoutSelectingActiveWorkspace() {
        let selected = HermesTUIWorkspace(number: 1)
        let inactive = HermesTUIWorkspace(number: 2)
        var workspaces = [selected, inactive]

        let destination = HermesTUIHistoryResumeCoordinator.destination(
            in: &workspaces,
            selectedWorkspaceID: selected.id,
            isBusy: { _ in false },
            makeWorkspace: { HermesTUIWorkspace(number: 3) }
        )

        XCTAssertEqual(destination.id, inactive.id)
        XCTAssertNotEqual(destination.id, selected.id)
        XCTAssertEqual(workspaces.count, 2)
    }

    func testCreatesInactiveWorkspaceWhenNoAvailableInactiveWorkspaceExists() {
        let selected = HermesTUIWorkspace(number: 1)
        var workspaces = [selected]

        let destination = HermesTUIHistoryResumeCoordinator.destination(
            in: &workspaces,
            selectedWorkspaceID: selected.id,
            isBusy: { _ in false },
            makeWorkspace: { HermesTUIWorkspace(number: 2) }
        )

        XCTAssertNotEqual(destination.id, selected.id)
        XCTAssertEqual(workspaces.map(\.number), [1, 2])
    }
}

final class HermesHistorySearchFocusPolicyTests: XCTestCase {
    func testDismissesKeyboardAfterSuccessfulSearchWithResults() {
        XCTAssertTrue(
            HermesHistorySearchFocusPolicy.shouldDismissKeyboard(
                wasSearching: true,
                isSearching: false,
                isCompactWidth: true,
                status: "Found 3 conversations",
                lastErrorMessage: ""
            )
        )
    }

    func testDismissesKeyboardAfterSuccessfulSearchWithoutResults() {
        XCTAssertTrue(
            HermesHistorySearchFocusPolicy.shouldDismissKeyboard(
                wasSearching: true,
                isSearching: false,
                isCompactWidth: true,
                status: "No matching conversations",
                lastErrorMessage: ""
            )
        )
    }

    func testKeepsKeyboardStateForCancellationAndFailure() {
        XCTAssertFalse(
            HermesHistorySearchFocusPolicy.shouldDismissKeyboard(
                wasSearching: true,
                isSearching: false,
                isCompactWidth: true,
                status: "Cancelled",
                lastErrorMessage: ""
            )
        )
        XCTAssertFalse(
            HermesHistorySearchFocusPolicy.shouldDismissKeyboard(
                wasSearching: true,
                isSearching: false,
                isCompactWidth: true,
                status: "Search failed",
                lastErrorMessage: "Network unavailable"
            )
        )
    }

    func testKeepsKeyboardStateOutsideCompactWidth() {
        XCTAssertFalse(
            HermesHistorySearchFocusPolicy.shouldDismissKeyboard(
                wasSearching: true,
                isSearching: false,
                isCompactWidth: false,
                status: "Found 3 conversations",
                lastErrorMessage: ""
            )
        )
    }
}
