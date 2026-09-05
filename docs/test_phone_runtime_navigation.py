"""Source-contract guard for the compact More stack's heterogeneous routes.

Run: python3 docs/test_phone_runtime_navigation.py
This guards the production wiring without adding a test-only view API. Device
UI testing still needs to exercise More > Agent Runtime > category > Back.
"""

from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
CONTENT = (ROOT / "HermesiOS/ContentView.swift").read_text()
RUNTIME = (ROOT / "HermesiOS/HermesAgentConfigView.swift").read_text()
TUI = (ROOT / "HermesiOS/HermesTUIGatewayView.swift").read_text()


def content_section(start, end):
    return CONTENT.split(start, 1)[1].split(end, 1)[0]


class PhoneRuntimeNavigationTests(unittest.TestCase):
    def test_phone_landing_is_not_a_tab_view_and_more_is_a_separate_presentation(self):
        landing = content_section("private var iPhoneLayout:", "private var compactPadLayout:")
        self.assertNotIn("TabView", landing)
        self.assertEqual(landing.count("NavigationStack {"), 1)
        self.assertIn("HermesTUIGatewayWorkspacesView(", landing)
        self.assertIn("onOpenMore: { isShowingPhoneMore = true }", landing)
        self.assertIn(".sheet(isPresented: $isShowingPhoneMore", landing)
        self.assertIn("phoneMoreNavigation", landing.split(".sheet", 1)[1])
        self.assertIn("openPhoneWorkspace(.tuiGateway)", landing.split("onDismiss:", 1)[1])
        self.assertNotIn(".id(", landing)

    def test_idiom_routing_preserves_compact_ipad_tabs(self):
        self.assertIn("if idiom == .phone { return .phone }", CONTENT)
        self.assertIn("return isCompact ? .compactPad : .split", CONTENT)
        self.assertIn("HermesRootLayout.resolve(idiom: UIDevice.current.userInterfaceIdiom", CONTENT)
        root = content_section("private var phoneRootLayout:", "private var iPhoneLayout:")
        self.assertIn("if rootLayout == .phone", root)
        self.assertIn("compactPadLayout", root)
        compact = content_section("private var compactPadLayout:", "private var phoneMoreNavigation:")
        self.assertIn("TabView(selection: $selectedPhoneTab)", compact)
        self.assertIn("HermesPhonePrimaryTab.tuiGateway.title", compact)
        self.assertIn("HermesPhonePrimaryTab.more.title", compact)
        self.assertNotIn("onOpenMore:", compact)

    def test_more_replaces_only_the_phone_header_icon_not_workspace_controls(self):
        header = TUI.split("private var header: some View", 1)[1].split("private var controls:", 1)[0]
        phone, fallback = header.split("} else if isPhoneLayout {", 1)
        self.assertIn("if UIDevice.current.userInterfaceIdiom == .phone, let onOpenMore", phone)
        self.assertIn("Button(action: onOpenMore)", phone)
        self.assertIn('Label("More", systemImage: "ellipsis.circle")', phone)
        self.assertNotIn('"terminal.fill"', phone)
        self.assertLess(phone.index("Button(action: onOpenMore)"), phone.index("workspaceControls"))
        self.assertIn('Image(systemName: "terminal.fill")', fallback)
        self.assertIn('HermesTabHeader("TUI Gateway", systemImage: "terminal.fill")', fallback)
        self.assertIn("onOpenMore: onOpenMore", TUI)

    def test_secondary_inventory_and_programmatic_settings_remain_available(self):
        inventory = content_section("private var phoneSecondarySections:", "private func openPhoneWorkspace")
        self.assertIn("[.history, .web, .terminal, .utilities]", inventory)
        self.assertIn("(isRuntimeTabEnabled ? [.runtime] : [])", inventory)
        self.assertIn("+ [.settings]", inventory)
        routing = content_section("private func openPhoneWorkspace", "private func responsesConsoleView")
        self.assertIn("if rootLayout == .phone", routing)
        self.assertIn("isShowingPhoneMore = tab == .more", routing)
        self.assertIn("phoneMorePath = NavigationPath([section])", routing)
        self.assertIn("phoneMorePath = NavigationPath()", routing)
        self.assertNotIn("tuiWorkspaces =", routing)
        self.assertNotIn("selectedTUIWorkspaceID =", routing)
        self.assertNotIn("disconnect()", routing)

    def test_phone_secondary_screens_restore_native_back_navigation(self):
        more = content_section("private var phoneMoreNavigation:", "private var phoneSecondarySections:")
        self.assertEqual(more.count("NavigationStack("), 1)
        self.assertIn("if rootLayout == .phone", more)
        self.assertIn(".toolbar(.visible, for: .navigationBar)", more)
        self.assertIn('Button("Back to TUI") { openPhoneWorkspace(.tuiGateway) }', more)

    def test_more_stack_accepts_workspace_and_runtime_route_types(self):
        self.assertRegex(
            CONTENT,
            r"@State private var phoneMorePath(?:\s*:\s*NavigationPath)?\s*=\s*NavigationPath\(\)",
        )
        self.assertIn("NavigationStack(path: $phoneMorePath)", CONTENT)

    def test_programmatic_navigation_and_resets_preserve_path_type(self):
        assignments = re.findall(r"phoneMorePath\s*=\s*([^\n]+)", CONTENT)
        self.assertTrue(assignments)
        self.assertTrue(all(value.startswith("NavigationPath(") for value in assignments))
        self.assertIn("phoneMorePath = NavigationPath([section])", CONTENT)

    def test_both_route_types_have_destinations_and_companion_uses_same_path(self):
        self.assertIn(".navigationDestination(for: WorkspaceSection.self)", CONTENT)
        self.assertIn(".navigationDestination(for: HermesRuntimePanelKind.self)", RUNTIME)
        self.assertIn("NavigationLink(value: category)", RUNTIME)
        self.assertIn("NavigationLink(value: HermesRuntimePanelKind.companion)", RUNTIME)


if __name__ == "__main__":
    unittest.main()
