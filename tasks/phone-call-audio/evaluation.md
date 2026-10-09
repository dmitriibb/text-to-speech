# Russian voice evaluation — 2026-10-09

Status: real CPU synthesis succeeds. Listening, frozen actor acceptance, and
engine selection are pending; M1 and D2 remain unchecked. No AMD inference tested.

## Reproducible baseline

- Model: `openbmb/VoxCPM2`, commit `32279effe8c19989596f05d353d1447f51d9e915`.
- Runtime: `voxcpm==2.0.3`, `torch==2.14.1+cpu`, CPython 3.10.22 for the full
  two/three-actor runs. The initial smoke used 3.10.0; it generated audio but that
  Python cannot run the currently resolved Pydantic API. The backend venv is now
  upgraded to 3.10.22. Its base interpreter is in ignored
  `artifacts/russian-dialogue/python-runtime/`; preserve it or recreate the venv.
- Windows build 26200; AMD CPU. Actual device/backend: `cpu`, no CUDA or HIP.
- Eager operation, denoiser and normalization disabled, CFG 2.0, 10 inference
  steps, bad-case retries off, seed 42. Seed uses scoped Torch RNG because the
  pinned generation API has no native seed parameter.
- Synthetic clean voice-design references generated once and reused by content
  hash. Anna/Sergey references are 5.92/6.88 seconds. They remain candidates;
  generated references and exact intended transcripts still require listening.
- Full/three-actor reports capture the complete resolved package versions. All
  reports capture reference hashes, turn settings, audio format/duration/peak,
  timings, and null listening scores.

## Measured results

| Run | Successful turns | Spoken audio | Turn synthesis | Preview with 250 ms gaps |
| --- | ---: | ---: | ---: | ---: |
| Two actors | 20/20 | 68.00 s | 284.53 s | 72.75 s |
| Three actors | 6/6 | 13.28 s | 55.78 s | 14.53 s |

Initial download took 237.12 seconds; full-run cold load took 11.70 seconds.
Median two-actor per-turn real-time factor was 4.10. These measurements describe
this CPU baseline and short fixture only, not GPU performance or a long recording.
Every generated output is a non-empty, finite, non-silent 48 kHz mono PCM16 WAV.
That validates technical output, not pronunciation, completeness of spoken words,
voice identity, or naturalness.

Local artifacts, intentionally ignored by git:

- `artifacts/russian-dialogue/smoke-2026-10-09-01/`: two references, two turns,
  original UTF-8 import scripts, runtime log and report.
- `artifacts/russian-dialogue/full-2026-10-09-01/`: all 20 turns and reused references.
- `artifacts/russian-dialogue/three-2026-10-09-01/`: six turns, reused Anna/Sergey,
  and a new Irina candidate reference.
- The corresponding `*-preview/` directories contain `evaluation-clean.wav`,
  `evaluation-phone-preview.wav`, and `preview.json`.

Previews validate every requested turn once in order and source hashes. They use
250 ms pauses, no second actor gain, peak attenuation to -1 dBFS, and a separate
300–3400 Hz Butterworth-filtered copy. They preserve clean masters and clips.
They remain evaluator listening artifacts. The shared app renderer and real Audacity
workflow have since been implemented and technically verified separately; see
[implementation verification](implementation-verification.md).

## Engineering changes and verification

- Fixed the adapter's unsupported native seed argument; inference is serialized.
- Normalization defaults off; unsupported speed values now fail before dispatch
  instead of silently leaving speech unchanged.
- Shared Dialog import diagnostics show skipped source rows and first-import
  errors, preserve Cyrillic/inner colons, and are wired into both apps. Idle users
  can repaste corrected input; importing during generation is disabled.
- Core: 40 tests; shared UI: 12; desktop: 18; Android: 5; backend/preview: 12;
  Python quality/evaluation fixture checks: 6. All passed.
- Analysis passed for both shared packages and both apps. Desktop used
  `dart analyze` because Flutter's dependency/plugin bootstrap requests Windows
  symlink support; `flutter test --no-pub` passed without changing system settings.
- Basic parity: identical parser/diagnostics/widgets on both platforms; only the
  existing platform clipboard adapters differ. No import changes remain unwired.
  Python inference/evaluation is desktop Extended and is not Android integration.

## User testing gate

All remaining Russian-dialog engineering is complete. Listen to references,
complete clean/phone conversations and a longer new script; record rubric scores,
missing/repeated words, spoken labels and voice swaps. Accept or replace candidate
references before marking D2/M1 complete. Exercise native preview/seek, desktop
save and Android share. The finished implementation task is archived; task 19
retains its broader Home/German/GPU scope and AMD remains a separate plan.
See [workflow guide](../../docs/russian-phone-call-workflow.md) and
[verification](implementation-verification.md).
