#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import sys
import time
import wave


REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_CATALOG = REPO_ROOT / "packages" / "model_catalog" / "approved_models.json"
DEFAULT_BENCHMARKS = REPO_ROOT / "packages" / "quality_suite" / "benchmark_texts.json"
DEFAULT_MODELS_ROOT = REPO_ROOT / "models"
DEFAULT_ARTIFACTS_ROOT = REPO_ROOT / "artifacts" / "phase0"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run Phase 0 local TTS validation with sherpa-onnx."
    )
    parser.add_argument("--model-id", required=True, help="Model id from the catalog")
    parser.add_argument(
        "--benchmark-set",
        choices=["quick", "full"],
        default="quick",
        help="Named benchmark set from benchmark_texts.json",
    )
    parser.add_argument(
        "--catalog",
        default=str(DEFAULT_CATALOG),
        help="Path to the approved model catalog JSON",
    )
    parser.add_argument(
        "--benchmarks",
        default=str(DEFAULT_BENCHMARKS),
        help="Path to the benchmark texts JSON",
    )
    parser.add_argument(
        "--models-root",
        default=str(DEFAULT_MODELS_ROOT),
        help="Directory containing extracted models",
    )
    parser.add_argument(
        "--artifacts-root",
        default=str(DEFAULT_ARTIFACTS_ROOT),
        help="Directory where audio and reports are written",
    )
    parser.add_argument(
        "--num-threads",
        type=int,
        default=None,
        help="Override the catalog default thread count",
    )
    parser.add_argument(
        "--speed",
        type=float,
        default=None,
        help="Override the catalog default speech speed",
    )
    return parser.parse_args()


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def find_model(catalog: dict, model_id: str) -> dict:
    for model in catalog["models"]:
        if model["id"] == model_id:
            return model
    raise SystemExit(f"Unknown model id: {model_id}")


def find_texts(benchmarks: dict, benchmark_set: str) -> list[dict]:
    ids = benchmarks["benchmark_sets"][benchmark_set]
    by_id = {entry["id"]: entry for entry in benchmarks["texts"]}
    return [by_id[text_id] for text_id in ids]


def import_sherpa_onnx():
    try:
        import sherpa_onnx  # type: ignore
    except ModuleNotFoundError as exc:
        raise SystemExit(
            "Missing dependency: sherpa_onnx. "
            "Install Phase 0 requirements first."
        ) from exc
    return sherpa_onnx


def build_tts(sherpa_onnx, model: dict, model_root: Path, num_threads: int):
    family = model["family"]
    if family != "vits":
        raise SystemExit(f"Unsupported Phase 0 model family: {family}")

    files = model["files"]
    defaults = model["defaults"]
    lexicon_path = str(model_root / files["lexicon"]) if "lexicon" in files else ""
    data_dir_path = str(model_root / files["data_dir"]) if "data_dir" in files else ""
    tts_config = sherpa_onnx.OfflineTtsConfig(
        model=sherpa_onnx.OfflineTtsModelConfig(
            vits=sherpa_onnx.OfflineTtsVitsModelConfig(
                model=str(model_root / files["model"]),
                lexicon=lexicon_path,
                tokens=str(model_root / files["tokens"]),
                data_dir=data_dir_path,
            ),
            provider=defaults["provider"],
            num_threads=num_threads,
            debug=False,
        ),
        max_num_sentences=defaults["max_num_sentences"],
    )
    if not tts_config.validate():
        raise SystemExit("Invalid sherpa-onnx TTS configuration")
    return sherpa_onnx.OfflineTts(tts_config)


def clamp_to_pcm16(sample: float) -> int:
    bounded = max(-1.0, min(1.0, float(sample)))
    if bounded == 1.0:
        bounded = 32767 / 32768
    return int(round(bounded * 32767))


def write_wav(path: Path, samples, sample_rate: int) -> None:
    pcm = bytearray()
    for sample in samples:
        value = clamp_to_pcm16(sample)
        pcm.extend(int(value).to_bytes(2, byteorder="little", signed=True))
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(sample_rate)
        handle.writeframes(pcm)


def main() -> None:
    args = parse_args()
    catalog = load_json(Path(args.catalog).resolve())
    benchmarks = load_json(Path(args.benchmarks).resolve())
    model = find_model(catalog, args.model_id)
    texts = find_texts(benchmarks, args.benchmark_set)
    model_root = Path(args.models_root).resolve() / model["install"]["install_dir_name"]

    if not model_root.exists():
        raise SystemExit(
            f"Model directory does not exist: {model_root}. "
            "Run tools/model_fetch/fetch_approved_model.py first."
        )

    sherpa_onnx = import_sherpa_onnx()
    num_threads = args.num_threads or model["defaults"]["num_threads"]
    speed = args.speed or model["defaults"]["speed"]
    speaker_id = model["defaults"]["speaker_id"]
    tts = build_tts(sherpa_onnx, model, model_root, num_threads)

    timestamp = time.strftime("%Y%m%d-%H%M%S")
    output_dir = Path(args.artifacts_root).resolve() / model["id"] / timestamp
    output_dir.mkdir(parents=True, exist_ok=True)

    results = []
    for index, entry in enumerate(texts, start=1):
        wav_path = output_dir / f"{index:02d}-{entry['id']}.wav"
        started_at = time.perf_counter()
        audio = tts.generate(entry["text"], sid=speaker_id, speed=speed)
        elapsed = time.perf_counter() - started_at
        if len(audio.samples) == 0:
            raise SystemExit(f"Generated empty audio for benchmark text {entry['id']}")
        write_wav(wav_path, audio.samples, audio.sample_rate)
        duration = len(audio.samples) / audio.sample_rate
        rtf = math.inf if duration == 0 else elapsed / duration
        results.append(
            {
                "text_id": entry["id"],
                "category": entry["category"],
                "output_wav": str(wav_path),
                "sample_rate": audio.sample_rate,
                "elapsed_seconds": round(elapsed, 4),
                "audio_duration_seconds": round(duration, 4),
                "real_time_factor": round(rtf, 4),
            }
        )
        print(
            f"{entry['id']}: saved {wav_path.name} "
            f"(elapsed={elapsed:.3f}s, duration={duration:.3f}s, rtf={rtf:.3f})"
        )

    report = {
        "model_id": model["id"],
        "benchmark_set": args.benchmark_set,
        "num_threads": num_threads,
        "speed": speed,
        "results": results,
    }
    report_path = output_dir / "report.json"
    with report_path.open("w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2)
        handle.write("\n")
    print(f"Report written to {report_path}")


if __name__ == "__main__":
    main()

