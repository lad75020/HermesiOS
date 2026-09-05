"""Source-layout guardrails; native presentation state is tested by XCTest.

Run with: python3 Tests/test_tui_phone_composer.py
These do not substitute for physical-device visual/interaction QA.
"""
from pathlib import Path
import unittest

SOURCE = (Path(__file__).resolve().parents[1] / "HermesiOS" / "HermesTUIGatewayView.swift").read_text()


def section(start, end):
    return SOURCE.split(start, 1)[1].split(end, 1)[0]


class PhoneComposerLayoutTests(unittest.TestCase):
    def test_both_controls_are_after_editor_in_same_vertical_rail(self):
        composer = section("private var composer: some View", "private var phoneInferenceButton:")
        before, after = composer.split("TextEditor(text: $workspace.promptText)", 1)
        self.assertIn("if isPhoneLayout && !usesPhoneComposerRail {\n                phoneInferenceButton", before)
        self.assertEqual(before.count("phoneInferenceButton"), 1)
        self.assertIn("HStack(alignment: .bottom, spacing: 12)", before)
        self.assertIn("if usesPhoneComposerRail {\n                    VStack(spacing: 8) {\n                        phoneInferenceButton\n                        composerActions", after)
        self.assertIn("HermesSkillSlashPicker(", before)

    def test_both_panels_use_one_bottom_anchored_native_popover(self):
        inference = section("private var phoneInferenceButton:", "private func phoneComposerTriggerIcon")
        actions = section("private var composerActions:", "private func attachButton")
        for panel, body in [("inference", inference), ("actions", actions)]:
            self.assertIn(".modifier(HermesTUIPhoneComposerPopover(isPresented: $phoneComposerPresentation[isPresented: ." + panel + "])", body)
            self.assertIn(".hermesGlassButton()", body)
            self.assertIn(".disabled(!store.isConnected || store.isStreaming)", body)
            self.assertIn("phoneComposerTriggerIcon(", body)
        popover = section("private struct HermesTUIPhoneComposerPopover", "private struct HermesTUIGatewayView:")
        self.assertIn("attachmentAnchor: .rect(.bounds), arrowEdge: .bottom", popover)
        self.assertIn(".presentationCompactAdaptation(.popover)", popover)
        self.assertIn(".padding(16)", popover)
        self.assertIn(".frame(width: 320, alignment: .leading)", popover)
        icon = section("private func phoneComposerTriggerIcon", "private var phoneInferencePopover:")
        self.assertIn(".frame(width: 44, height: 44)", icon)

    def test_actions_unfold_vertically_without_replacing_the_trigger(self):
        actions = section("private var composerActions:", "private func attachButton").split("} else if isPhoneLayout {", 1)[0]
        self.assertIn("VStack(spacing: 8) {\n                    attachButton(frame: 44)\n                    sendButton(frame: 44)", actions)
        self.assertNotIn("HStack", actions)
        self.assertNotIn(".transition", actions)
        self.assertNotIn("isPhoneComposerActionsExpanded", SOURCE)

    def test_regular_ipad_composer_branches_remain_inline(self):
        composer = section("private var composer: some View", "private var phoneInferenceButton:")
        self.assertIn("else if !usesPhoneComposerRail {\n                ViewThatFits(in: .horizontal) {\n                    HStack(spacing: 8) { inferenceControls }\n                    VStack(alignment: .leading, spacing: 8) { inferenceControls }\n                }", composer)
        actions = section("private var composerActions:", "private func attachButton")
        self.assertIn("} else {\n            VStack(spacing: 8) {\n                attachButton(frame: 44)\n                sendButton(frame: 44)\n            }", actions)

    def test_compact_ipad_keeps_the_previous_layout(self):
        self.assertIn("private var usesPhoneComposerRail: Bool { UIDevice.current.userInterfaceIdiom == .phone }", SOURCE)
        actions = section("private var composerActions:", "private func attachButton")
        fallback = actions.split("} else if isPhoneLayout {", 1)[1]
        self.assertIn("if isCompactPadComposerActionsExpanded", fallback)
        self.assertIn("HStack(spacing: 8) {\n                    attachButton(frame: 44)\n                    sendButton(frame: 44)", fallback)
        self.assertIn(".transition(.scale(scale: 0.82, anchor: .trailing).combined(with: .opacity))", fallback)

    def test_first_open_starts_a_draft_owned_catalog_request(self):
        opening = section("private var phoneInferenceButton:", "private func phoneComposerTriggerIcon")
        self.assertIn("phoneInference.open(workspace: workspace, load: store.modelOptions)", opening)

    def test_opening_is_read_only_and_close_and_save_share_commit_owner(self):
        opening = section("private var phoneInferenceButton:", "private func phoneComposerTriggerIcon")
        self.assertIn("phoneInference.open(workspace: workspace, load: store.modelOptions)", opening)
        self.assertNotIn("workspace.inference =", opening)
        self.assertNotIn("store.createSession", opening)
        saving = section("private func applyPhoneInferenceDraft()", "private func selectModel(")
        self.assertIn("guard phoneInference.save() else { return }", saving)
        self.assertIn("if !isPresented { phoneInference.dismiss() }", SOURCE)
        owner = (Path(__file__).resolve().parents[1] / "HermesiOS" / "HermesTUIPhoneInferenceDraft.swift").read_text()
        dismiss = owner.split("func dismiss()", 1)[1].split("func selectModel", 1)[0]
        self.assertIn("if let option = explicitlySelectedModel", dismiss)
        self.assertIn("commit(option: option)", dismiss)
        self.assertIn("workspace.inference = draft", owner)
        self.assertIn("workspace.modelOptionsRequestID = UUID()", owner)
        self.assertIn("workspace.store.createSession(inference: draft)", owner)
        self.assertIn('.accessibilityLabel("Save inference settings")', SOURCE)

    def test_attachment_send_and_disabled_contracts_are_retained(self):
        attach = section("private func attachButton", "private func sendButton")
        send = section("private func sendButton", "private var composerMinHeight")
        for action in [attach, send]:
            self.assertIn("phoneComposerPresentation[isPresented: .actions] = false", action)
        self.assertIn("isImportingAttachment = true", attach)
        phone_attach = attach.split("if usesPhoneComposerRail {", 1)[1].split("} else {", 1)[0]
        self.assertIn("isPhoneAttachmentImportPending = true", phone_attach)
        self.assertNotIn("isImportingAttachment = true", phone_attach)
        actions = section("private var composerActions:", "private func attachButton")
        self.assertIn(".onDisappear {", actions)
        self.assertIn("if isPhoneAttachmentImportPending {\n                        isPhoneAttachmentImportPending = false\n                        isImportingAttachment = true", actions)
        self.assertIn(".disabled(!store.isConnected || store.isStreaming)", attach)
        self.assertIn("submitPrompt()", send)
        self.assertIn(".disabled(!store.canSendPrompt || (workspace.promptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && workspace.selectedAttachment == nil))", send)
        self.assertIn('.accessibilityLabel("Send through TUI Gateway")', send)
        submit = section("private func submitPrompt()", "private func handleAttachmentImport")
        self.assertIn("store.submitPrompt(text, attachment: workspace.selectedAttachment, inference: workspace.inference)", submit)


if __name__ == "__main__":
    unittest.main(verbosity=2)
