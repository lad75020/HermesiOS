"""Source wiring guards; RPC behavior is covered by device XCTests."""
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class RuntimeProfileSkillsWiringTests(unittest.TestCase):
    def test_opening_loads_gateway_profile_not_companion_or_process_catalog(self):
        source = (ROOT / "HermesiOS/HermesSkillsPanel.swift").read_text()
        self.assertIn(".task(id: gatewayCatalogTaskIdentity) { loadProfileInventory() }", source)
        loader = source.split("private func loadProfileInventory()", 1)[1].split("private func loadGatewayCatalog()", 1)[0]
        self.assertIn("runtimeProfileSkills(profileName: selectedProfileName)", loader)
        self.assertNotIn("companionRuntime", loader)
        self.assertNotIn("runtimeSkillsCatalog", loader)
        self.assertIn("profileInventoryRequestID == requestID, !Task.isCancelled", loader)
        self.assertIn("profileInventory = nil", loader)

    def test_profile_and_transport_changes_replace_private_panel_state(self):
        source = (ROOT / "HermesiOS/HermesAgentConfigView.swift").read_text()
        skills = source.split("case .skills:\n", 1)[1].split("case .companion:", 1)[0]
        self.assertIn(".id(HermesToolsScopeIdentity(", skills)
        self.assertIn("gateway: runtimeProfileLoadKey", skills)
        self.assertIn("profileName: selectedRuntimeProfileName", skills)
        panel = (ROOT / "HermesiOS/HermesSkillsPanel.swift").read_text()
        self.assertIn("HermesRuntimeConnectionIdentity(dashboardURL:", panel)
        self.assertIn("profileInventoryTask?.cancel()", panel)

    def test_fallback_stays_explicit_and_read_only_gateway_never_replaces_disabled_list(self):
        source = (ROOT / "HermesiOS/HermesSkillsPanel.swift").read_text()
        self.assertIn('Button("Load Selected Profile Inventory") { companionRuntime.refreshHermesSkills', source)
        self.assertIn('companionRuntime.hasRuntimeSectionLoaded("skills")', source)
        self.assertNotIn('"profiles.configure"', source)
        self.assertNotIn('"disabled_skills"', source)
        store = (ROOT / "HermesiOS/HermesTUIGatewayView.swift").read_text()
        method = store.split("func runtimeProfileSkills(", 1)[1].split("var runtimeConnectionVersion", 1)[0]
        self.assertIn('request("profiles.describe", params: ["name": .string(profileName)]', method)
        self.assertNotIn('"config.get"', method)
        self.assertNotIn('"session.create"', method)


if __name__ == "__main__":
    unittest.main()
