import json
from pathlib import Path
import unittest


REPO_ROOT = Path(__file__).resolve().parents[1]
BENCHMARKS_PATH = REPO_ROOT / "packages" / "quality_suite" / "benchmark_texts.json"


class QualitySuiteTests(unittest.TestCase):
    def setUp(self) -> None:
        self.benchmarks = json.loads(BENCHMARKS_PATH.read_text(encoding="utf-8"))

    def test_benchmark_sets_reference_existing_texts(self) -> None:
        text_ids = {entry["id"] for entry in self.benchmarks["texts"]}
        for entries in self.benchmarks["benchmark_sets"].values():
            for text_id in entries:
                self.assertIn(text_id, text_ids)

    def test_text_ids_are_unique(self) -> None:
        text_ids = [entry["id"] for entry in self.benchmarks["texts"]]
        self.assertEqual(len(text_ids), len(set(text_ids)))

    def test_texts_are_non_empty(self) -> None:
        for entry in self.benchmarks["texts"]:
            self.assertTrue(entry["text"].strip())
            self.assertIn(entry["category"], {"short", "medium", "long"})


if __name__ == "__main__":
    unittest.main()
