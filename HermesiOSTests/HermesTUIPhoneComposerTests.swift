import XCTest
@testable import HermesiOS

final class HermesTUIPhoneComposerTests: XCTestCase {
    func testBothPanelsStartDismissed() {
        let presentation = HermesTUIPhoneComposerPresentation()
        XCTAssertNil(presentation.activePanel)
        XCTAssertFalse(presentation[isPresented: .inference])
        XCTAssertFalse(presentation[isPresented: .actions])
    }

    func testOpeningEitherPanelReplacesTheOther() {
        var presentation = HermesTUIPhoneComposerPresentation()
        presentation[isPresented: .inference] = true
        XCTAssertTrue(presentation[isPresented: .inference])
        XCTAssertFalse(presentation[isPresented: .actions])
        presentation[isPresented: .actions] = true
        XCTAssertFalse(presentation[isPresented: .inference])
        XCTAssertTrue(presentation[isPresented: .actions])
        presentation[isPresented: .inference] = true
        XCTAssertTrue(presentation[isPresented: .inference])
        XCTAssertFalse(presentation[isPresented: .actions])
    }

    func testBothPanelsDismissAndReopenIdentically() {
        for panel in [HermesTUIPhoneComposerPresentation.Panel.inference, .actions] {
            var presentation = HermesTUIPhoneComposerPresentation()
            presentation[isPresented: panel] = true
            presentation[isPresented: panel] = false
            XCTAssertNil(presentation.activePanel)
            presentation[isPresented: panel] = true
            XCTAssertTrue(presentation[isPresented: panel])
        }
    }

    func testDelayedDismissalDoesNotCloseReplacementPanel() {
        var presentation = HermesTUIPhoneComposerPresentation()
        presentation[isPresented: .inference] = true
        presentation[isPresented: .actions] = true
        presentation[isPresented: .inference] = false
        XCTAssertTrue(presentation[isPresented: .actions])
        presentation[isPresented: .inference] = true
        presentation[isPresented: .actions] = false
        XCTAssertTrue(presentation[isPresented: .inference])
    }
}
