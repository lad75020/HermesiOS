"""Source wiring guards, not live keyboard/gesture interaction tests."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
VIEW = (ROOT / "HermesiOS/HermesTUIGatewayView.swift").read_text()
HELPER = (ROOT / "HermesiOS/HermesTUIKeyboardDismissal.swift").read_text()


class KeyboardDismissalWiringTests(unittest.TestCase):
    def test_focus_is_owned_by_gateway_and_bound_only_to_prompt(self):
        self.assertIn("@FocusState private var isPromptFocused: Bool", VIEW)
        self.assertEqual(VIEW.count(".tuiPhonePromptFocus("), 1)
        self.assertIn("TextEditor(text: $workspace.promptText)\n                        .tuiPhonePromptFocus($isPromptFocused)", VIEW)

    def test_gesture_is_only_on_transcript_scroll_view_not_rows_or_composer(self):
        transcript = VIEW.split("private var transcript: some View", 1)[1].split("private var emptyState:", 1)[0]
        self.assertEqual(VIEW.count(".tuiPhoneTranscriptTapToDismiss("), 1)
        self.assertIn(".padding(.vertical, 16)\n            }\n            .tuiPhoneTranscriptTapToDismiss($isPromptFocused)", transcript)
        self.assertIn("ScrollView {", transcript)
        self.assertIn(".onChange(of: store.messages.count)", transcript)
        self.assertIn(".onChange(of: store.messages.last?.content)", transcript)

    def test_blank_viewport_uses_nonexclusive_tap_without_global_interception(self):
        self.assertIn("frame(maxWidth: .infinity, maxHeight: .infinity)\n                .contentShape(Rectangle())\n                .simultaneousGesture(", HELPER)
        self.assertIn("TapGesture().onEnded", HELPER)
        self.assertIn("including: .all", HELPER)
        for forbidden in [".onTapGesture", ".highPriorityGesture", "DragGesture", "UIApplication.shared", "resignFirstResponder", "endEditing", ".overlay", ".scrollDismissesKeyboard"]:
            self.assertNotIn(forbidden, HELPER)

    def test_ipad_modifiers_are_identity_and_gate_is_idiom_not_width(self):
        self.assertIn("idiom == .phone", HELPER)
        self.assertNotIn("horizontalSizeClass", HELPER)
        self.assertEqual(HELPER.count("if HermesTUIKeyboardDismissal.isEnabled(for: UIDevice.current.userInterfaceIdiom)"), 2)
        self.assertEqual(HELPER.count("            self\n"), 2)
        self.assertIn("focused(focus)", HELPER)
        self.assertIn("isPromptFocused: &focus.wrappedValue", HELPER)
        self.assertIn("guard isEnabled(for: idiom), isPromptFocused else { return }", HELPER)


if __name__ == "__main__":
    unittest.main(verbosity=2)
