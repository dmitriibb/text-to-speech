import json
from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = REPO_ROOT / "packages" / "model_catalog" / "approved_models.json"
APP_CATALOG_PATHS = [
    REPO_ROOT / "apps" / "desktop_app" / "assets" / "approved_models.json",
    REPO_ROOT / "apps" / "android_app" / "assets" / "approved_models.json",
]


class ModelCatalogTests(unittest.TestCase):
    def setUp(self) -> None:
        self.catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))

    def test_default_model_exists(self) -> None:
        model_ids = {model["id"] for model in self.catalog["models"]}
        self.assertIn(self.catalog["default_model_id"], model_ids)

    def test_model_ids_are_unique(self) -> None:
        model_ids = [model["id"] for model in self.catalog["models"]]
        self.assertEqual(len(model_ids), len(set(model_ids)))

    def test_phase0_default_is_marked_once(self) -> None:
        defaults = [model for model in self.catalog["models"] if model["phase0_default"]]
        self.assertEqual(len(defaults), 1)
        self.assertEqual(defaults[0]["id"], self.catalog["default_model_id"])

    def test_required_sections_exist(self) -> None:
        for model in self.catalog["models"]:
            self.assertIn("status", model)
            self.assertIn("source", model)
            self.assertIn("licensing", model)
            self.assertIn("install", model)
            self.assertIn("files", model)
            self.assertIn("defaults", model)

    def test_app_catalog_assets_match_canonical_catalog(self) -> None:
        for path in APP_CATALOG_PATHS:
            with self.subTest(path=path):
                self.assertEqual(json.loads(path.read_text(encoding="utf-8")), self.catalog)

    def test_german_dialog_models_are_available(self) -> None:
        model_ids = {model["id"] for model in self.catalog["models"]}
        self.assertIn("vits-piper-de_DE-thorsten-medium", model_ids)
        self.assertIn("vits-piper-de_DE-thorsten-high", model_ids)
        self.assertIn("vits-piper-de_DE-kerstin-low", model_ids)


if __name__ == "__main__":
    unittest.main()

