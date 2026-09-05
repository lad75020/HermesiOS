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


class PhoneRuntimeNavigationTests(unittest.TestCase):
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
