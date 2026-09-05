"""Source guards for the dashboard profile-scoped Skills contract."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]

class RuntimeProfileSkillsWiringTests(unittest.TestCase):
    def test_dashboard_client_uses_exact_profile_rest_contract_and_session_token(self):
        source = (ROOT / "HermesiOS/HermesDashboardProfileSkills.swift").read_text()
        self.assertIn('URLQueryItem(name: "profile", value: profile)', source)
        self.assertIn('URLQueryItem(name: "include_descriptions", value: "false")', source)
        self.assertIn('baseURL.appendingPathComponent("api/skills/description")', source)
        self.assertIn('URLQueryItem(name: "name", value: name)', source)
        self.assertIn('baseURL.appendingPathComponent("api/skills/toggle")', source)
        self.assertIn('request.httpMethod = "PUT"', source)
        self.assertIn('HermesDashboardSkillToggleRequest(name: name, enabled: enabled, profile: profile)', source)
        self.assertIn('X-Hermes-Session-Token', source)
        self.assertIn('HermesNetworkSessionFactory.session(for: apiSettings)', source)
        self.assertIn('catch HermesDashboardProfileSkillsError.httpError(401)', source)

    def test_write_validates_acknowledgement_then_reads_same_profile_before_ui_update(self):
        source = (ROOT / "HermesiOS/HermesDashboardProfileSkills.swift").read_text()
        self.assertIn('guard acknowledgement.ok, acknowledgement.name == name, acknowledgement.enabled == enabled', source)
        self.assertIn('let readback = try await load(profile: profile', source)
        self.assertIn('readback.first(where: { $0.name == name })?.isEnabled == enabled', source)
        panel = (ROOT / "HermesiOS/HermesSkillsPanel.swift").read_text()
        mutation = panel.split('private func setProfileSkillEnabled', 1)[1].split('private func loadGatewayCatalog', 1)[0]
        self.assertIn('profileSkills.setEnabled(', mutation)
        self.assertIn('profileInventory = readback', mutation)
        self.assertIn('profileInventoryMutationID == mutationID, !Task.isCancelled', mutation)
        self.assertNotIn('tuiGatewayStore', mutation)
        self.assertNotIn('sessionID', mutation)

    def test_rpc_skill_mutation_and_disabled_skills_replacement_are_absent(self):
        gateway = (ROOT / "HermesiOS/HermesTUIGatewayView.swift").read_text()
        profile_model = (ROOT / "HermesiOS/HermesTUIProfileSkills.swift").read_text()
        self.assertNotIn('setRuntimeProfileSkillEnabled', gateway)
        self.assertNotIn('runtimeProfileSkillMutationInProgress', gateway)
        self.assertNotIn('"disabled_skills"', profile_model)
        self.assertNotIn('profiles.configure', (ROOT / "HermesiOS/HermesSkillsPanel.swift").read_text())

    def test_panel_keeps_optional_catalog_and_lazily_loads_description_on_disclosure(self):
        panel = (ROOT / "HermesiOS/HermesSkillsPanel.swift").read_text()
        self.assertIn('DisclosureGroup("Gateway Process Catalog (Optional)")', panel)
        self.assertIn('runtimeSkillsCatalog()', panel)
        self.assertIn('HermesDashboardProfileSkillToggleRow', panel)
        self.assertIn('profileSkills.loadDescription(', panel)
        self.assertIn('profileSkillDescriptionRequestIDs[name] == requestID, !Task.isCancelled', panel)
        self.assertIn('profileSkillDescriptions[$0.name]?.localizedCaseInsensitiveContains(query) == true', panel)
        self.assertIn('$0.category.localizedCaseInsensitiveContains(query)', panel)
        components = (ROOT / "HermesiOS/HermesRuntimeComponents.swift").read_text()
        self.assertGreaterEqual(components.count('@State private var isDescriptionExpanded = false'), 2)
        self.assertIn('struct HermesDashboardProfileSkillToggleRow', components)
        self.assertIn('if isDescriptionExpanded', components)
        self.assertIn('onRequestDescription()', components)
        self.assertIn('ProgressView("Loading description")', components)

if __name__ == "__main__":
    unittest.main()
