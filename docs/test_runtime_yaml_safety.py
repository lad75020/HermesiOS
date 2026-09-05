"""Fixture-only checks of the exact Swift-embedded YAML transformer."""
import json
from pathlib import Path
import subprocess
import sys
import unittest
import yaml

SOURCE = Path(__file__).resolve().parents[1] / 'HermesHostCompanion/CompanionRuntimeConfigSafety.swift'
SCRIPT = SOURCE.read_text().split('static let yamlScript = #"""', 1)[1].split('"""#', 1)[0]


def transform(content, **request):
    return subprocess.run([sys.executable, '-I', '-c', SCRIPT], input=json.dumps(dict(content=content, **request)), text=True, capture_output=True)


class RuntimeYAMLSafetyTests(unittest.TestCase):
    def test_tool_toggle_preserves_other_platforms_and_fields(self):
        original = {'platform_toolsets': {'cli': ['web', 'file'], 'telegram': ['custom-tool'], 'discord': []}, 'model': {'provider': 'fixture', 'extra': [1, True]}}
        result = transform(yaml.safe_dump(original), action='setTool', key='web', enabled=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        original['platform_toolsets']['cli'] = ['file']
        self.assertEqual(yaml.safe_load(json.loads(result.stdout)['content']), original)

    def test_gateway_toggle_preserves_nested_fields(self):
        original = {'platforms': {'telegram': {'token': 'fixture-token', 'enabled': False, 'options': {'keep': True}}, 'discord': {'enabled': True}}, 'other': 42}
        result = transform(yaml.safe_dump(original), action='setPlatform', platform='telegram', enabled=True, platforms=['telegram', 'discord'])
        self.assertEqual(result.returncode, 0, result.stderr)
        original['platforms']['telegram']['enabled'] = True
        self.assertEqual(yaml.safe_load(json.loads(result.stdout)['content']), original)

    def test_ambiguous_or_composite_configuration_rejected(self):
        for text in ['platform_toolsets: {cli: [web]}\nplatform_toolsets: {}', 'platform_toolsets: {cli: [hermes-cli]}', 'platform_toolsets: &shared {cli: [web]}', 'platform_toolsets: {cli: wrong}', '[not, a, mapping]']:
            with self.subTest(text=text):
                result = transform(text, action='setTool', key='web', enabled=False)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, '')


if __name__ == '__main__':
    unittest.main()
