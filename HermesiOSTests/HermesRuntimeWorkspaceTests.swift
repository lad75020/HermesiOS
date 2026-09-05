import XCTest
@testable import HermesiOS

final class HermesRuntimeWorkspaceTests: XCTestCase {
    func testWorkspaceTabVisibilityDefaultsKeepAskAndChatButHideRuntime() {
        let visibility = HermesWorkspaceTabVisibility()

        XCTAssertTrue(visibility.visibleSections.contains(.responses))
        XCTAssertTrue(visibility.visibleSections.contains(.chat))
        XCTAssertFalse(visibility.visibleSections.contains(.runtime))
    }

    func testWorkspaceTabVisibilityFiltersAllOptionalSections() {
        let visibility = HermesWorkspaceTabVisibility(
            isAskHermesEnabled: false,
            isChatWithHermesEnabled: false,
            isRuntimeEnabled: true
        )

        XCTAssertFalse(visibility.visibleSections.contains(.responses))
        XCTAssertFalse(visibility.visibleSections.contains(.chat))
        XCTAssertTrue(visibility.visibleSections.contains(.runtime))
        XCTAssertTrue(visibility.visibleSections.contains(.tuiGateway))
    }

    func testWorkspaceTabVisibilityFallsBackFromDisabledSelectionsInPreferredOrder() {
        XCTAssertEqual(
            HermesWorkspaceTabVisibility(
                isAskHermesEnabled: true,
                isChatWithHermesEnabled: false,
                isRuntimeEnabled: false
            ).resolvedSelection(.chat),
            .responses
        )
        XCTAssertEqual(
            HermesWorkspaceTabVisibility(
                isAskHermesEnabled: false,
                isChatWithHermesEnabled: true,
                isRuntimeEnabled: false
            ).resolvedSelection(.responses),
            .chat
        )
        XCTAssertEqual(
            HermesWorkspaceTabVisibility(
                isAskHermesEnabled: false,
                isChatWithHermesEnabled: false,
                isRuntimeEnabled: false
            ).resolvedSelection(.runtime),
            .tuiGateway
        )
        XCTAssertEqual(HermesWorkspaceTabVisibility().resolvedSelection(nil), .responses)
    }

    func testWorkspaceTabVisibilityKeepsEnabledSelections() {
        let visibility = HermesWorkspaceTabVisibility(isRuntimeEnabled: true)

        XCTAssertEqual(visibility.resolvedSelection(.responses), .responses)
        XCTAssertEqual(visibility.resolvedSelection(.chat), .chat)
        XCTAssertEqual(visibility.resolvedSelection(.runtime), .runtime)
    }

    func testPrimaryCategoriesMatchTheEightRuntimeConfigurationAreas() {
        XCTAssertEqual(
            HermesRuntimePanelKind.primaryCategories,
            [.profiles, .gateway, .tools, .skills, .mcpServers, .providers, .schedules, .models]
        )
        XCTAssertEqual(HermesRuntimePanelKind.primaryCategories.count, 8)
        XCTAssertFalse(HermesRuntimePanelKind.primaryCategories.contains(.companion))
    }

    func testCompanionAndExistingUtilitiesRemainSecondary() {
        XCTAssertEqual(
            HermesRuntimePanelKind.secondaryCategories,
            [.companion, .memory, .knowledgeEraser, .observability]
        )
        XCTAssertTrue(HermesRuntimePanelKind.secondaryCategories.contains(.companion))
    }

    func testAdaptiveLayoutUsesCategoryRailOnlyWhenThereIsEnoughWidth() {
        XCTAssertEqual(HermesRuntimeWorkspaceLayout.forWidth(390), .overview)
        XCTAssertEqual(HermesRuntimeWorkspaceLayout.forWidth(719), .overview)
        XCTAssertEqual(HermesRuntimeWorkspaceLayout.forWidth(720), .split)
        XCTAssertEqual(HermesRuntimeWorkspaceLayout.forWidth(1024), .split)
    }

    func testCategoryTitlesDescribeThePushedDestinations() {
        XCTAssertEqual(HermesRuntimePanelKind.gateway.title, "Messaging")
        XCTAssertEqual(HermesRuntimePanelKind.providers.title, "Provider Keys")
        XCTAssertEqual(HermesRuntimePanelKind.schedules.title, "Scheduled Jobs")
    }

    @MainActor
    func testScopedRuntimeSessionsAreIndependentAndDoNotShareState() {
        let oldScope = HermesCompanionRuntimeSession()
        oldScope.hermesSkills = []
        let newScope = HermesCompanionRuntimeSession()
        newScope.connectionStatus = "Loading Models"
        XCTAssertFalse(oldScope === newScope)
        XCTAssertEqual(oldScope.connectionStatus, "Idle")
        XCTAssertEqual(newScope.connectionStatus, "Loading Models")
    }

    @MainActor
    func testRuntimeSectionErrorsStayScopedToTheirCategory() {
        let runtime = HermesCompanionRuntimeSession()
        runtime.runtimeSectionErrors["schedules"] = "host unavailable"
        XCTAssertEqual(runtime.runtimeSectionError("schedules"), "host unavailable")
        XCTAssertEqual(runtime.runtimeSectionError("skills"), "")
    }
}
