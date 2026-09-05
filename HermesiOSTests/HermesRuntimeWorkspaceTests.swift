import XCTest
@testable import HermesiOS

final class HermesRuntimeWorkspaceTests: XCTestCase {
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
