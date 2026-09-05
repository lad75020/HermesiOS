import XCTest
import UIKit
@testable import HermesiOS

final class HermesTUIKeyboardDismissalTests: XCTestCase {
    func testPhoneTranscriptTapClearsPromptFocus() {
        var focused = true
        HermesTUIKeyboardDismissal.transcriptTapped(idiom: .phone, isPromptFocused: &focused)
        XCTAssertFalse(focused)
    }

    func testRepeatedPhoneTranscriptTapDoesNotAcquireFocus() {
        var focused = false
        for _ in 0..<3 {
            HermesTUIKeyboardDismissal.transcriptTapped(idiom: .phone, isPromptFocused: &focused)
            XCTAssertFalse(focused)
        }
        // Tapping the editor can reacquire focus; the next transcript tap clears it again.
        focused = true
        HermesTUIKeyboardDismissal.transcriptTapped(idiom: .phone, isPromptFocused: &focused)
        XCTAssertFalse(focused)
    }

    func testPadKeepsFocusRegardlessOfWindowWidth() {
        // The policy intentionally has no size-class input: compact iPad is still iPad.
        XCTAssertFalse(HermesTUIKeyboardDismissal.isEnabled(for: .pad))
        for initialFocus in [false, true] {
            var focused = initialFocus
            HermesTUIKeyboardDismissal.transcriptTapped(idiom: .pad, isPromptFocused: &focused)
            XCTAssertEqual(focused, initialFocus)
        }
    }

    func testOnlyPhoneOptsIntoTheGestureAndFocusBinding() {
        XCTAssertTrue(HermesTUIKeyboardDismissal.isEnabled(for: .phone))
        for idiom: UIUserInterfaceIdiom in [.pad, .mac, .tv, .carPlay, .vision, .unspecified] {
            XCTAssertFalse(HermesTUIKeyboardDismissal.isEnabled(for: idiom))
            var focused = true
            HermesTUIKeyboardDismissal.transcriptTapped(idiom: idiom, isPromptFocused: &focused)
            XCTAssertTrue(focused)
        }
    }
}
