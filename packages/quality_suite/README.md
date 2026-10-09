# quality_suite

Curated texts and checks used during local TTS validation.

Primary file:

- `benchmark_texts.json`

The initial benchmark set intentionally covers:

- plain short English
- punctuation and numbers
- a medium paragraph
- a longer paragraph that forces more sentence handling

Russian phone-call evaluation uses `russian_phone_dialogue.json`: a 20-turn
two-actor script, a separate three-actor script, synthetic voice-design candidates,
and a human listening rubric. Numeric text stays unchanged; pronunciation overrides
must be recorded explicitly. Voice descriptions and seeds are candidate generation
tools; the evaluator reuses generated clean references for subsequent turns.

Run from the repository root using the VoxCPM2 backend's isolated environment:

```powershell
apps/voxcpm2_be/.venv/Scripts/python.exe tools/benchmark/evaluate_russian_dialogue.py --revision 32279effe8c19989596f05d353d1447f51d9e915 --limit 2 --timeout-seconds 900 --output artifacts/russian-dialogue/smoke-01
```

The checkpoint SHA was resolved from the official model repository on 2026-10-09.
Use `--prepare-only` to create UTF-8 Dialog transcripts and an unevaluated report
without loading dependencies. Omit `--limit` for all 20 turns; use
`--script three_actor` for the separate sample. Choose a new output directory for
each run. A timeout kills the worker and preserves the last completed stage and
any finished samples. `runtime.log` contains diagnostics.
Use `--reference-report artifacts/russian-dialogue/smoke-01/report.json` to reuse
the same candidate voices across evaluations. Reference hashes and matching
fixture/checkpoint identities are checked before reuse.

To prepare listening comparisons after a successful run:

```powershell
apps/voxcpm2_be/.venv/Scripts/python.exe tools/benchmark/prepare_russian_listening_preview.py --report artifacts/russian-dialogue/smoke-01/report.json --output artifacts/russian-dialogue/smoke-01-preview
```

This evaluator-only tool requires every requested turn, in order, with unchanged
hashes and mono 48 kHz PCM16 inputs. It inserts 250 ms pauses, only attenuates peaks
above -1 dBFS, and makes a separate 300–3400 Hz Butterworth-filtered listening copy.
It preserves all source clips and records exact processing in `preview.json`.
It does not implement the shared app renderer or certify an Audacity preset.

Reports separate download/cold-load time from per-turn synthesis time, WAV duration,
real-time factor, actual device, reference hashes, checkpoint/runtime versions,
effective settings, failures, and listening feedback. Audio inspection validates
non-empty, finite, non-silent WAVs; it cannot assess pronunciation or identity.
Scores remain null and engine selection remains false until listening is recorded.
Score all four dimensions at least 4/5 and check all hard failures explicitly;
assess phone intelligibility on a processed copy. Candidate references need human
acceptance before being treated as frozen actor voices. A smoke run alone does not
complete M1. Generated audio, model caches, logs, and reports stay outside git.

