"""Guard the four targets' Debug and Release Swift language settings."""

from pathlib import Path
import re
import unittest


PROJECT = Path(__file__).resolve().parents[1] / "HermesiOS.xcodeproj" / "project.pbxproj"


class Swift6LanguageModeTests(unittest.TestCase):
    def test_all_target_configurations_use_swift_6_with_xctest_nonisolated(self):
        project = PROJECT.read_text()
        configurations = re.findall(
            r"/\* (Debug|Release) \*/ = \{\s*isa = XCBuildConfiguration;\s*"
            r"buildSettings = \{(.*?)\n\s*\};\s*name = \1;",
            project,
            re.DOTALL,
        )
        swift_configurations = [
            settings for _, settings in configurations if "SWIFT_VERSION = " in settings
        ]
        self.assertEqual(len(swift_configurations), 8)
        for settings in swift_configurations:
            self.assertIn("SWIFT_VERSION = 6.0;", settings)

        self.assertEqual(
            sum("SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor;" in settings
                for settings in swift_configurations),
            2,
        )
        self.assertEqual(
            sum("SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated;" in settings
                for settings in swift_configurations),
            6,
        )
        self.assertEqual(
            sum("SWIFT_APPROACHABLE_CONCURRENCY = YES;" in settings
                for settings in swift_configurations),
            4,
        )
        ios_test_settings = [
            settings for settings in swift_configurations
            if "PRODUCT_BUNDLE_IDENTIFIER = fr.dubertrand.HermesiOSTests;" in settings
        ]
        self.assertEqual(len(ios_test_settings), 2)
        for settings in ios_test_settings:
            self.assertIn("SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated;", settings)


if __name__ == "__main__":
    unittest.main()
