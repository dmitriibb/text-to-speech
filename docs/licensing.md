# Licensing Status

Updated: 2026-04-03

This file records what is currently approved, what is blocked, and what is still Unknown.

## Approved technologies

### `sherpa-onnx`

- Status: Approved
- License: Apache-2.0
- Reason: Open runtime with official support for desktop and Android

### Flutter

- Status: Approved
- License: BSD-style open-source license
- Reason: Free cross-platform UI framework for desktop and Android

## Phase 0 model status

### `vits-piper-en_US-lessac-medium`

- Status for local validation: Approved
- Status for redistribution: Not approved
- Runtime source: official `sherpa-onnx` TTS release
- Model license: Unknown
- Dataset license: Unknown
- Needed to decide:
  - explicit model artifact license from the upstream exported release
  - redistribution terms for the `lessac_blizzard2013` training data

### `vits-ljs`

- Status for local validation: Approved
- Status for redistribution: Not approved
- Runtime source: official `sherpa-onnx` TTS release
- Model license: Unknown
- Dataset license: Public Domain
- Needed to decide:
  - explicit model artifact license from the upstream exported release

## Candidate for later shipping review

### `en_US-ljspeech-medium` from `rhasspy/piper-voices`

- Status for Phase 0 runtime: Not used
- Status for future review: Candidate
- Repository license signal: MIT
- Dataset license signal: Public Domain
- Why it is not the current Phase 0 default:
  - the current harness uses official pre-packaged `sherpa-onnx` TTS archives
  - raw Piper voices need extra packaging work for the chosen runtime path

## Rule for the repo

If a model license or redistribution status is Unknown, we can use it for local evaluation only. We do not bundle or distribute it with the applications until the missing license evidence is captured.

