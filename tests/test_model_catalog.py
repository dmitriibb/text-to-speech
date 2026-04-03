import json
from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
CATALOG_PATH = REPO_ROOT / "packages" / "model_catalog" / "approved_models.json"


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


if __name__ == "__main__":
    unittest.main()

