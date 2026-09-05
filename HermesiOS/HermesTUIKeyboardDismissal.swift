import SwiftUI
import UIKit

/// Device idiom, not size class: compact iPad windows keep their existing focus behavior.
enum HermesTUIKeyboardDismissal {
    static func isEnabled(for idiom: UIUserInterfaceIdiom) -> Bool {
        idiom == .phone
    }

    static func transcriptTapped(idiom: UIUserInterfaceIdiom, isPromptFocused: inout Bool) {
        guard isEnabled(for: idiom), isPromptFocused else { return }
        isPromptFocused = false
    }
}

extension View {
    @ViewBuilder
    func tuiPhonePromptFocus(_ focus: FocusState<Bool>.Binding) -> some View {
        if HermesTUIKeyboardDismissal.isEnabled(for: UIDevice.current.userInterfaceIdiom) {
            focused(focus)
        } else {
            self
        }
    }

    /// Apply only to the transcript ScrollView, never its composer/header ancestor.
    @ViewBuilder
    func tuiPhoneTranscriptTapToDismiss(_ focus: FocusState<Bool>.Binding) -> some View {
        if HermesTUIKeyboardDismissal.isEnabled(for: UIDevice.current.userInterfaceIdiom) {
            // Shape the viewport, not the lazy rows, so blank space is also tappable.
            frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    TapGesture().onEnded {
                        HermesTUIKeyboardDismissal.transcriptTapped(
                            idiom: UIDevice.current.userInterfaceIdiom,
                            isPromptFocused: &focus.wrappedValue
                        )
                    },
                    including: .all
                )
        } else {
            // No focus binding, hit shape, or gesture is added to iPad.
            self
        }
    }
}
