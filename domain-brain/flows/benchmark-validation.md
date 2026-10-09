# Benchmark Validation Flow

## Goal

Validate the chosen runtime and model path outside the apps through a repeatable benchmark harness.

## Steps

1. Download an approved model.
2. Extract it into the repo `models/` area.
3. Run the Phase 0 Python validation harness.
4. Generate `.wav` files plus a JSON report under `artifacts/phase0/`.

## Invariants

- The harness validates the same runtime direction used by the apps.
- Validation artifacts are written under `artifacts/phase0/`.
- The harness is a validation tool, not the final app runtime layer.

## Failure Modes

- missing Python dependencies
- missing or broken model files
- synthesis failure during benchmark execution

## Russian dialogue evaluation

- `packages/quality_suite/russian_phone_dialogue.json` supplies unchanged Russian
  texts for two and three actors, stable IDs, voice-design candidates, and a 1–5
  listening rubric. It covers pronunciation, numbers, short/long turns, and colons
  inside spoken text. It does not add an approved app model.
- `tools/benchmark/evaluate_russian_dialogue.py` runs the desktop VoxCPM2 adapter
  in a separate process using `voxcpm==2.0.3` and an exact checkpoint commit SHA.
  Eager CPU operation, no denoiser, and no automatic normalization form the initial
  baseline. Actual execution device and runtime versions are recorded.
- Synthetic actor references are generated once per run and reused for that
  actor's turns. They remain candidates until listening accepts their identity.
- Reports and UTF-8 import transcripts live in ignored `artifacts/russian-dialogue/`
  directories. Reports distinguish download, cold load, warm generation, WAV
  duration/format/hash, and human feedback. Completed stages survive failure,
  cancellation, and the overall process deadline.
- Subsequent runs may reuse references from a matching fixture/checkpoint report;
  reference hashes must match. The listening-preview tool validates completeness,
  transcript order, and source hashes, then joins compatible 48 kHz mono PCM16
  clips with 250 ms gaps. It only attenuates peaks above -1 dBFS and writes a
  separate 300–3400 Hz filtered copy plus processing metadata. This tooling is
  evaluation-only. The shared app renderer and separate Audacity 3.7.7 workflow
  are now implemented and technically tested; listening acceptance remains open.
- Preparing scripts, a successful health check, or valid WAV headers never pass
  the quality gate. Null listening scores mean unevaluated. Engine selection is
  withheld until real samples pass pronunciation, delivery, identity, and phone
  intelligibility with no missing/repeated words, spoken labels, or voice swaps.

- The opt-in desktop real harness exercises actual HTTP reference inference,
  selective retry, saved project reload and shared rendering. The Audacity helper
  applies the saved macro, exports a copy, reopens AUP3 and verifies sample-identical
  reexport with the original clean hash retained. Ten-minute synthetic render
  coverage proves length/streaming, not long-script speech quality.
