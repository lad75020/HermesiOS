"""Regression guard for sidebar logo asset-catalog membership.

Run with: python3 Tests/test_sidebar_logo_assets.py
"""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
ASSET_CATALOG = ROOT / "HermesiOS" / "Assets.xcassets"


class SidebarLogoAssetTests(unittest.TestCase):
    def test_sidebar_logos_are_compiled_asset_catalog_images(self):
        for name in ("HermesLogoDark", "HermesLogoLight"):
            with self.subTest(name=name):
                image_set = ASSET_CATALOG / f"{name}.imageset"
                contents = json.loads((image_set / "Contents.json").read_text())
                filenames = {
                    image["filename"]
                    for image in contents["images"]
                    if "filename" in image
                }
                self.assertEqual({image["scale"] for image in contents["images"]}, {"1x", "2x", "3x"})
                self.assertEqual(len(filenames), 3)
                for filename in filenames:
                    self.assertTrue((image_set / filename).is_file())


if __name__ == "__main__":
    unittest.main(verbosity=2)
