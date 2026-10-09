"""Bounded, isolated VoxCPM2 evaluation; no app integration or quality claims.

Run with the backend venv Python. Model/media/reports go in ignored artifacts/.
The parent kills a stalled worker and preserves its incremental JSON report.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import importlib.metadata
import json
import math
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import time
import traceback

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / "packages/quality_suite/russian_phone_dialogue.json"


def write_json(path: Path, value: dict) -> None:
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")
    temporary.replace(path)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def inspect_wav(path: Path) -> dict:
    import numpy as np
    import soundfile as sf

    info = sf.info(path)
    if info.format != "WAV" or info.frames <= 0 or info.samplerate <= 0:
        raise ValueError("Result must be a non-empty WAV.")
    peak = 0.0
    with sf.SoundFile(path) as source:
        for block in source.blocks(blocksize=65536, dtype="float32"):
            if not np.isfinite(block).all():
                raise ValueError("Result contains non-finite samples.")
            peak = max(peak, float(np.max(np.abs(block))))
    if peak == 0.0:
        raise ValueError("Result contains only silence.")
    return {
        "file": path.name, "sha256": sha256(path), "sample_rate": info.samplerate,
        "channels": info.channels, "subtype": info.subtype,
        "duration_seconds": info.frames / info.samplerate, "peak": peak,
    }


def new_report(fixture: dict, args: argparse.Namespace) -> dict:
    return {
        "version": 1, "started_at": datetime.now(timezone.utc).isoformat(),
        "status": "prepared", "fixture_sha256": sha256(args.fixture),
        "script": args.script, "turn_limit": args.limit,
        "model": {"id": args.model, "revision": args.revision, "runtime": "voxcpm==2.0.3"},
        "hardware": {"platform": platform.platform(), "processor": platform.processor()},
        "runtime": {"python": sys.version, "requested_device": args.device},
        "settings": {"cfg_value": 2.0, "inference_timesteps": 10, "normalize": False,
                     "denoise": False, "retry_badcase": False, "seed": 42,
                     "optimize": False, "load_denoiser": False},
        "timing": {"download_seconds": None, "cold_load_seconds": None},
        "actors": [], "turns": [], "failures": [],
        "listening": {"status": "pending", "scores": {key: None for key in fixture["rubric"]["dimensions"]},
                      "hard_failures": {key: None for key in fixture["rubric"]["hard_failures"]},
                      "accepted_actor_ids": [], "phone_audio_file": None, "notes": ""},
        "engine_selected": False,
    }


def worker(args: argparse.Namespace, fixture: dict, report: dict) -> int:
    report_path = args.output / "report.json"
    try:
        report["status"] = "loading_runtime"
        write_json(report_path, report)
        import torch
        from huggingface_hub import snapshot_download
        from voxcpm import VoxCPM

        installed = importlib.metadata.version("voxcpm")
        if installed != "2.0.3":
            raise RuntimeError(f"Expected voxcpm==2.0.3; installed {installed}.")
        report["runtime"].update({"voxcpm": installed, "torch": torch.__version__,
                                  "cuda": torch.version.cuda, "hip": torch.version.hip})
        report["runtime"]["packages"] = {
            distribution.metadata["Name"]: distribution.version
            for distribution in importlib.metadata.distributions()
        }
        if torch.cuda.is_available():
            report["hardware"]["gpu"] = torch.cuda.get_device_name(0)
            report["hardware"]["gpu_total_bytes"] = torch.cuda.get_device_properties(0).total_memory
        report["status"] = "downloading"
        write_json(report_path, report)
        started = time.perf_counter()
        local_model = snapshot_download(args.model, revision=args.revision)
        report["timing"]["download_seconds"] = time.perf_counter() - started
        report["status"] = "loading_model"
        write_json(report_path, report)
        # Use the app's adapter, with a pinned local checkpoint and eager baseline.
        sys.path.insert(0, str(ROOT / "apps/voxcpm2_be"))
        from dataclasses import replace
        from src.config import load_settings
        from src.engine import VoxCPM2Engine
        engine = VoxCPM2Engine(replace(load_settings(), model_id=local_model,
                                     device=args.device, optimize=False, load_denoiser=False))
        started = time.perf_counter()
        engine._ensure_initialized()
        report["timing"]["cold_load_seconds"] = time.perf_counter() - started
        report["runtime"].update({"actual_device": engine.device, "device_backend": engine.device_backend})
        # Verify pinned API signature, rather than assuming current main's controls.
        import inspect
        report["runtime"]["generation_signature"] = str(inspect.signature(VoxCPM._generate))
        script = next(item for item in fixture["scripts"] if item["id"] == args.script)
        turns = script["turns"][:args.limit] if args.limit else script["turns"]
        actors = {actor["id"]: actor for actor in fixture["actors"]}
        used_actors = list(dict.fromkeys(turn["actor_id"] for turn in turns))
        references = {}
        report["status"] = "generating_references"
        write_json(report_path, report)
        previous = None
        if args.reference_report:
            previous = json.loads(args.reference_report.read_text(encoding="utf-8"))
            if (previous["fixture_sha256"] != report["fixture_sha256"]
                    or previous["model"] != report["model"]):
                raise ValueError("Reference report must match this fixture, model and exact revision.")
        for index, actor_id in enumerate(used_actors):
            actor = actors[actor_id]
            path = args.output / f"reference-{actor_id}.wav"
            settings = {**report["settings"], "seed": 42 + index, "style": actor["design"]}
            old_actor = next((item for item in previous["actors"] if item["id"] == actor_id), None) if previous else None
            if old_actor:
                name = old_actor["audio"]["file"]
                if Path(name).name != name or "/" in name or "\\" in name:
                    raise ValueError("Reference filename must stay inside its report directory.")
                source = args.reference_report.parent / name
                if sha256(source) != old_actor["audio"]["sha256"]:
                    raise ValueError(f"Reference content changed for {actor_id}.")
                shutil.copyfile(source, path)
                references[actor_id] = path
                report["actors"].append({**old_actor, "candidate_only": True,
                                         "reused_from": str(args.reference_report.resolve()),
                                         "audio": inspect_wav(path)})
                write_json(report_path, report)
                continue
            started = time.perf_counter()
            engine.generate(text=fixture["reference_text"], settings=settings,
                            reference_audio_path=None, output_path=path)
            elapsed = time.perf_counter() - started
            references[actor_id] = path
            report["actors"].append({"id": actor_id, "name": actor["name"],
                                     "reference_transcript": fixture["reference_text"],
                                     "settings": settings, "synthesis_seconds": elapsed,
                                     "candidate_only": True, "audio": inspect_wav(path)})
            write_json(report_path, report)
        report["status"] = "generating_turns"
        write_json(report_path, report)
        for turn in turns:
            entry = {"id": turn["id"], "actor_id": turn["actor_id"], "text": turn["text"],
                     "status": "generating", "settings": report["settings"], "audio": None}
            report["turns"].append(entry)
            write_json(report_path, report)
            path = args.output / f"{turn['id']}.wav"
            started = time.perf_counter()
            try:
                engine.generate(text=turn["text"], settings=report["settings"],
                                reference_audio_path=references[turn["actor_id"]], output_path=path)
                entry["synthesis_seconds"] = time.perf_counter() - started
                entry["audio"] = inspect_wav(path)
                entry["real_time_factor"] = entry["synthesis_seconds"] / entry["audio"]["duration_seconds"]
                entry["status"] = "succeeded"
            except Exception as error:
                entry.update(status="failed", error=str(error))
                report["failures"].append({"stage": turn["id"], "error": str(error)})
                write_json(report_path, report)
                raise
            write_json(report_path, report)
        report["status"] = "awaiting_listening"
        write_json(report_path, report)
        return 0
    except Exception as error:
        report["failures"].append({"stage": report["status"], "error": f"{type(error).__name__}: {error}"})
        report["status"] = "failed"
        write_json(report_path, report)
        traceback.print_exc()
        return 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", type=Path, default=FIXTURE)
    parser.add_argument("--script", choices=["two_actor", "three_actor"], default="two_actor")
    parser.add_argument("--model", default="openbmb/VoxCPM2")
    parser.add_argument("--revision", required=True, help="Exact 40-character checkpoint commit SHA")
    parser.add_argument("--device", choices=["cpu", "auto", "cuda"], default="cpu")
    parser.add_argument("--limit", type=int, default=0, help="0 runs all turns; use 2 for a smoke test")
    parser.add_argument("--timeout-seconds", type=float, default=900)
    parser.add_argument("--output", type=Path, required=True, help="New output directory, never overwritten")
    parser.add_argument("--prepare-only", action="store_true", help="Write scripts/report without importing the runtime")
    parser.add_argument("--reference-report", type=Path, help="Reuse hashed actor references from a matching evaluation")
    parser.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    if len(args.revision) != 40 or any(c not in "0123456789abcdef" for c in args.revision):
        parser.error("--revision must be an exact lowercase 40-character commit SHA")
    if args.limit < 0 or not math.isfinite(args.timeout_seconds) or args.timeout_seconds <= 0:
        parser.error("limit must be nonnegative and timeout must be finite and positive")
    fixture = json.loads(args.fixture.read_text(encoding="utf-8"))
    report = new_report(fixture, args)
    if args.worker:
        return worker(args, fixture, report)
    args.output.mkdir(parents=True, exist_ok=False)
    report_path = args.output / "report.json"
    write_json(report_path, report)
    for script in fixture["scripts"]:
        actors = {actor["id"]: actor["name"] for actor in fixture["actors"]}
        text = "\n".join(f"{actors[turn['actor_id']]}: {turn['text']}" for turn in script["turns"]) + "\n"
        (args.output / f"{script['id']}.txt").write_text(text, encoding="utf-8")
    if args.prepare_only:
        print(f"Prepared unevaluated report and transcripts: {args.output}")
        return 0
    with (args.output / "runtime.log").open("w", encoding="utf-8") as log:
        process = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), *sys.argv[1:], "--worker"],
                                   stdout=log, stderr=subprocess.STDOUT)
        try:
            result = process.wait(timeout=args.timeout_seconds)
        except (subprocess.TimeoutExpired, KeyboardInterrupt) as error:
            process.kill()
            process.wait()
            report = json.loads(report_path.read_text(encoding="utf-8"))
            stage = report["status"]
            report["status"] = "timeout" if isinstance(error, subprocess.TimeoutExpired) else "cancelled"
            report["failures"].append({"stage": stage, "error": report["status"],
                                       "deadline_seconds": args.timeout_seconds})
            write_json(report_path, report)
            result = 2
    print(f"Evaluation exit {result}; report: {report_path}")
    return result


if __name__ == "__main__":
    raise SystemExit(main())
