"""Create evaluation-only clean/phone previews, not the app conversation renderer."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from evaluate_russian_dialogue import FIXTURE, inspect_wav, sha256, write_json


def prepare(report_path: Path, output: Path, fixture_path: Path = FIXTURE) -> dict:
    import numpy as np
    import soundfile as sf
    from scipy.signal import butter, sosfilt

    report = json.loads(report_path.read_text(encoding="utf-8"))
    if report["status"] != "awaiting_listening" or not report["turns"]:
        raise ValueError("Only a finished evaluation with all requested turns can be previewed.")
    if sha256(fixture_path) != report["fixture_sha256"]:
        raise ValueError("Fixture changed since evaluation.")
    fixture = json.loads(fixture_path.read_text(encoding="utf-8"))
    expected = next(script["turns"] for script in fixture["scripts"] if script["id"] == report["script"])
    if report["turn_limit"]:
        expected = expected[:report["turn_limit"]]
    if [turn["id"] for turn in report["turns"]] != [turn["id"] for turn in expected]:
        raise ValueError("Every requested turn must be present once, in transcript order.")
    chunks = []
    total_frames = 0
    rate = 48000
    pause_frames = round(rate * 0.250)
    for index, turn in enumerate(report["turns"]):
        if turn["status"] != "succeeded" or not turn["audio"]:
            raise ValueError(f"Missing turn: {turn['id']}")
        name = turn["audio"]["file"]
        if Path(name).name != name or "/" in name or "\\" in name:
            raise ValueError("Turn filename must stay in the report directory.")
        source = report_path.parent / name
        if sha256(source) != turn["audio"]["sha256"]:
            raise ValueError(f"Turn changed: {turn['id']}")
        info = sf.info(source)
        if info.format != "WAV" or info.samplerate != rate or info.channels != 1 or info.subtype != "PCM_16":
            raise ValueError("Evaluation previews require mono 48 kHz PCM16 inputs; no resampling is implied.")
        total_frames += info.frames + (pause_frames if index else 0)
        if total_frames > rate * 600:
            raise ValueError("Evaluation preview is bounded to ten minutes.")
        samples, _ = sf.read(source, dtype="float32")
        if not np.isfinite(samples).all() or samples.size == 0:
            raise ValueError(f"Invalid audio: {turn['id']}")
        if index:
            chunks.append(np.zeros(pause_frames, dtype="float32"))
        chunks.append(samples)
    clean = np.concatenate(chunks)
    ceiling = 10 ** (-1 / 20)
    clean_gain = min(1.0, ceiling / max(float(np.max(np.abs(clean))), 1e-12))
    clean *= clean_gain
    # Conservative narrowband comparison only; not an accepted Audacity preset.
    coefficients = butter(4, [300, 3400], btype="bandpass", fs=rate, output="sos")
    phone = sosfilt(coefficients, clean)
    phone_gain = min(1.0, ceiling / max(float(np.max(np.abs(phone))), 1e-12))
    phone *= phone_gain
    output.mkdir(parents=True, exist_ok=False)
    for name, audio in [("evaluation-clean.wav", clean), ("evaluation-phone-preview.wav", phone)]:
        temporary = output / f"{name}.tmp"
        sf.write(temporary, audio, rate, subtype="PCM_16", format="WAV")
        inspect_wav(temporary)
        temporary.replace(output / name)
    manifest = {
        "version": 1, "source_report": str(report_path.resolve()),
        "source_report_sha256": sha256(report_path), "evaluation_only": True,
        "turn_ids": [turn["id"] for turn in report["turns"]],
        "pause_ms": 250, "sample_rate": rate, "clean_gain": clean_gain,
        "phone_effect": {"type": "Butterworth bandpass", "order": 4,
                         "low_hz": 300, "high_hz": 3400, "gain": phone_gain,
                         "accepted_audacity_preset": False},
        "clean": inspect_wav(output / "evaluation-clean.wav"),
        "phone": inspect_wav(output / "evaluation-phone-preview.wav"),
        "listening_status": "pending",
    }
    write_json(output / "preview.json", manifest)
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--fixture", type=Path, default=FIXTURE)
    parser.add_argument("--output", type=Path, required=True, help="New directory, never overwritten")
    args = parser.parse_args()
    manifest = prepare(args.report, args.output, args.fixture)
    print(f"Prepared {len(manifest['turn_ids'])} turns; {manifest['clean']['duration_seconds']:.2f} seconds: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
