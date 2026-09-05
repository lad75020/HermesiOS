"""Regression guards for polling tasks that capture API settings by value."""
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class PollingAuthTaskIdentityTests(unittest.TestCase):
    def test_detailed_health_authenticates_before_sending(self):
        source = (ROOT / "HermesiOS/HermesCommandCenterView.swift").read_text()
        body = source.split("private func fetchHealth(apiSettings:", 1)[1].split("\n    }", 1)[0]
        validation = body.index("try HermesEndpointSecurity.validateSensitiveURL(url)")
        authorization = body.index("request.setHermesAuthorization(from: apiSettings)")
        sending = body.index("session.data(for: request)")
        self.assertLess(validation, authorization)
        self.assertLess(authorization, sending)

    def test_status_and_command_center_tasks_restart_for_normalized_key_rotation(self):
        cases = [
            ("HermesiOS/ContentView.swift", "statusRefreshKey", ".task(id: statusLoopKey)", "statusMonitor.runStatusLoop("),
            ("HermesiOS/HermesUtilitiesView.swift", "commandCenterRefreshKey", ".task(id: commandCenterRefreshKey)", "commandCenter.runStatusLoop(apiSettings: apiSettings)"),
        ]
        for path, key_name, task_wiring, loop_call in cases:
            source = (ROOT / path).read_text()
            self.assertIn(task_wiring, source)
            self.assertIn(loop_call, source)
            key = source.split(f"private var {key_name}: String {{", 1)[1].split("\n    }", 1)[0]
            self.assertIn("HermesRuntimeConnectionIdentity.fingerprint(apiSettings.normalizedAPIKey)", key)
            self.assertNotIn("apiSettings.apiKey", key)
            self.assertIn("apiSettings.baseURL", key)
            self.assertIn("apiSettings.allowSelfSignedCertificates", key)

    def test_credential_fingerprint_normalizes_bearer_and_whitespace_before_hashing(self):
        source = (ROOT / "HermesiOS/HermesRuntimeConnectionIdentity.swift").read_text()
        initializer = source.split("init(dashboardURL: String, apiSettings: HermesAPISettings) {", 1)[1].split("\n    }", 1)[0]
        self.assertIn("Self.fingerprint(apiSettings.normalizedAPIKey)", initializer)
        self.assertNotIn("credentialFingerprint = apiSettings.apiKey", initializer)


if __name__ == "__main__":
    unittest.main()
