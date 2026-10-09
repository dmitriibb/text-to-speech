import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
HARNESS = ROOT / "tools/benchmark/evaluate_russian_dialogue.py"
FIXTURE = ROOT / "packages/quality_suite/russian_phone_dialogue.json"
spec = importlib.util.spec_from_file_location("russian_evaluation", HARNESS)
evaluation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(evaluation)


class RussianEvaluationTests(unittest.TestCase):
    def test_fixture_covers_russian_acceptance_cases_and_actors(self):
        fixture = json.loads(FIXTURE.read_text(encoding="utf-8"))
        scripts = {item["id"]: item["turns"] for item in fixture["scripts"]}
        self.assertEqual(len(scripts["two_actor"]), 20)
        self.assertEqual(len({item["actor_id"] for item in scripts["two_actor"]}), 2)
        self.assertEqual(len({item["actor_id"] for item in scripts["three_actor"]}), 3)
        actor_ids = {actor["id"] for actor in fixture["actors"]}
        turns = [turn for script in scripts.values() for turn in script]
        self.assertEqual(len({turn["id"] for turn in turns}), len(turns))
        self.assertTrue(all(turn["actor_id"] in actor_ids and turn["text"].strip() for turn in turns))
        cases = {case for turn in scripts["two_actor"] for case in turn["cases"]}
        self.assertTrue({"yo", "surname", "date", "price", "abbreviation", "telephone", "hesitation",
                         "very_short", "long_turn", "punctuation", "spoken_colon"} <= cases)
        self.assertTrue(any("ё" in turn["text"] for turn in turns))
        self.assertTrue(any(":" in turn["text"] for turn in turns))

    def test_prepare_requires_no_model_and_does_not_claim_listening_pass(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "evaluation"
            result = subprocess.run([sys.executable, str(HARNESS), "--prepare-only", "--revision", "a" * 40,
                                     "--output", str(output)], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            report = json.loads((output / "report.json").read_text(encoding="utf-8"))
            self.assertFalse(report["engine_selected"])
            self.assertEqual(report["listening"]["status"], "pending")
            self.assertTrue(all(score is None for score in report["listening"]["scores"].values()))
            transcript = (output / "two_actor.txt").read_text(encoding="utf-8")
            self.assertIn("Анна: Нет, в письме написано: вход со двора, второй этаж.", transcript)
            repeat = subprocess.run([sys.executable, str(HARNESS), "--prepare-only", "--revision", "a" * 40,
                                     "--output", str(output)], capture_output=True, text=True)
            self.assertNotEqual(repeat.returncode, 0)
            self.assertEqual(report, json.loads((output / "report.json").read_text(encoding="utf-8")))

    def test_rejects_moving_model_revision_before_creating_output(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "evaluation"
            result = subprocess.run([sys.executable, str(HARNESS), "--prepare-only", "--revision", "main",
                                     "--output", str(output)], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
