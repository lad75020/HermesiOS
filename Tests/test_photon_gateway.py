"""Photon catalog and exact production YAML transformer; fixture data only."""
import json
from pathlib import Path
import re
import subprocess
import sys
import unittest
import yaml

ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / 'HermesHostCompanion/CompanionGatewayRegistry.swift').read_text()
SCRIPT = (ROOT / 'HermesHostCompanion/CompanionRuntimeConfigSafety.swift').read_text().split('static let yamlScript = #"""', 1)[1].split('"""#', 1)[0]
KEYS = ['PHOTON_PROJECT_ID', 'PHOTON_PROJECT_SECRET', 'PHOTON_ALLOWED_USERS',
        'PHOTON_HOME_CHANNEL', 'PHOTON_HOME_CHANNEL_NAME', 'PHOTON_SIDECAR_PORT',
        'PHOTON_REQUIRE_MENTION', 'PHOTON_MENTION_PATTERNS']


def transform(config, **request):
    result = subprocess.run([sys.executable, '-I', '-c', SCRIPT],
                            input=json.dumps(dict(content=yaml.safe_dump(config), platforms=['photon', 'telegram'], **request)),
                            text=True, capture_output=True)
    if result.returncode:
        raise AssertionError('Fixture transformer rejected request')
    return json.loads(result.stdout)


class PhotonGatewayTests(unittest.TestCase):
    def test_catalog_has_exact_supported_photon_fields(self):
        row = re.search(r'\.init\(key: "photon"[^\n]+', SOURCE)
        self.assertIsNotNone(row, 'Photon missing from host catalog')
        fields = re.search(r'fields: \[([^\]]+)\]', row.group()).group(1)
        self.assertEqual(re.findall(r'"([A-Z_]+)"', fields), KEYS)
        for key in KEYS:
            self.assertRegex(SOURCE, rf'\.init\(key: "{key}", label:')
        self.assertRegex(SOURCE, r'key: "PHOTON_PROJECT_SECRET", label: "[^"]+", type: "password"')

    def test_nested_photon_toggle_preserves_settings(self):
        cfg = {'gateway': {'platforms': {'photon': {'enabled': True, 'require_mention': True, 'extra': {'keep': [1, True]}}, 'telegram': {'enabled': True}}, 'other': 7}, 'model': {'default': 'fixture'}}
        for enabled in [False, True]:
            result = transform(cfg, action='setPlatform', platform='photon', enabled=enabled)
            cfg['gateway']['platforms']['photon']['enabled'] = enabled
            self.assertEqual(yaml.safe_load(result['content']), cfg)
            self.assertEqual(result['platformEnabled'], {'photon': enabled, 'telegram': True})

    def test_precedence_and_toggle_target_match_gateway_loader(self):
        cfg = {'gateway': {'platforms': {'photon': {'enabled': False, 'require_mention': True}}, 'photon': {'enabled': True, 'extra': {'keep': 'fixture'}}}, 'platforms': {'photon': {'enabled': False}}}
        self.assertTrue(transform(cfg, action='listPlatforms')['platformEnabled']['photon'])
        result = transform(cfg, action='setPlatform', platform='photon', enabled=False)
        cfg['gateway']['photon']['enabled'] = False
        self.assertEqual(yaml.safe_load(result['content']), cfg)
        self.assertFalse(result['platformEnabled']['photon'])

    def test_top_level_precedes_nested_and_explicit_false_persists(self):
        cfg = {'gateway': {'platforms': {'photon': {'enabled': True}}}, 'platforms': {'photon': {'enabled': False, 'extra': {'project_id': 'fixture'}}}}
        self.assertFalse(transform(cfg, action='listPlatforms')['platformEnabled']['photon'])
        for enabled in [True, False]:
            result = transform(cfg, action='setPlatform', platform='photon', enabled=enabled)
            cfg['platforms']['photon']['enabled'] = enabled
            self.assertEqual(yaml.safe_load(result['content']), cfg)

    def test_new_platform_uses_explicit_top_level_enabled(self):
        result = transform({'model': {'default': 'fixture'}}, action='setPlatform', platform='photon', enabled=False)
        self.assertEqual(yaml.safe_load(result['content']), {'model': {'default': 'fixture'}, 'platforms': {'photon': {'enabled': False}}})


if __name__ == '__main__':
    unittest.main()
