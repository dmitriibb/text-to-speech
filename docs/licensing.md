# Licensing Status

Updated: 2026-04-11

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

### `kokoro-en-v0_19`

- Status for local validation: Approved
- Status for redistribution: Not approved
- Runtime source: official `sherpa-onnx` TTS release
- Model license: Apache-2.0
- Dataset license: Unknown
- Needed to decide:
  - confirm redistribution terms for the packaged sherpa release asset
  - capture any dataset or speaker-asset restrictions that apply to the exported archive

### `kokoro-multi-lang-v1_0`

- Status for local validation: Approved
- Status for redistribution: Not approved
- Runtime source: official `sherpa-onnx` TTS release
- Model license: Apache-2.0
- Dataset license: Unknown
- Needed to decide:
  - confirm redistribution terms for the packaged multilingual sherpa release asset
  - verify redistribution terms for bundled multilingual speaker assets and Chinese normalization data

### `kitten-mini-en-v0_1-fp16`

- Status for local validation: Approved
- Status for redistribution: Not approved
- Runtime source: official `sherpa-onnx` TTS release
- Model license: Apache-2.0
- Dataset license: Unknown
- Needed to decide:
  - capture an explicit release-level license statement for the sherpa-converted KittenTTS archive
  - verify whether any bundled speaker assets add extra redistribution constraints

### `vits-piper-de_DE-thorsten-medium`

- Status for local validation: Approved
- Status for redistribution: Not approved
- Runtime source: official `sherpa-onnx` TTS release
- Model license: Unknown
- Dataset license: Unknown
- Needed to decide:
  - explicit model artifact license from the upstream exported release
  - redistribution terms for the original Thorsten German voice dataset and voice assets

### `vits-piper-de_DE-thorsten-high`

- Status for local validation: Approved
- Status for redistribution: Not approved
- Runtime source: official `sherpa-onnx` TTS release
- Model license: Unknown
- Dataset license: Unknown
- Needed to decide:
  - explicit model artifact license from the upstream exported release
  - redistribution terms for the original Thorsten German voice dataset and voice assets

### `vits-piper-de_DE-kerstin-low`

- Status for local validation: Approved
- Status for redistribution: Not approved
- Runtime source: official `sherpa-onnx` TTS release
- Model license: Unknown
- Dataset license: Unknown
- Needed to decide:
  - explicit model artifact license from the upstream exported release
  - redistribution terms for the original Kerstin German voice dataset and voice assets

## Candidate for later shipping review

### `en_US-ljspeech-medium` from `rhasspy/piper-voices`

- Status for Phase 0 runtime: Not used
- Status for future review: Candidate
- Repository license signal: MIT
- Dataset license signal: Public Domain
- Why it is not the current Phase 0 default:
  - the current harness uses official pre-packaged `sherpa-onnx` TTS archives
  - raw Piper voices need extra packaging work for the chosen runtime path

### `MeloTTS`

- Status for Phase 0 runtime: Not used
- Status for future review: Candidate
- Repository license signal: MIT
- Dataset license signal: Mixed and checkpoint-dependent
- Why it is not a current app model:
  - this repo currently targets `sherpa-onnx` packaged models
  - integrating MeloTTS cleanly would likely require a new runtime path or a maintained export workflow

### `OpenVoice V2`

- Status for Phase 0 runtime: Not used
- Status for future review: Candidate
- Repository license signal: MIT
- Dataset license signal: Mixed and checkpoint-dependent
- Why it is not a current app model:
  - it is a voice-cloning and style-transfer path, not a drop-in replacement for the current shared runtime
  - desktop-only integration complexity is significantly higher than Piper, Kokoro, or KittenTTS

### `OmniVoice`

- Status for Phase 0 runtime: Not used
- Status for future review: Candidate
- Repository license signal: Apache-2.0
- Hugging Face model card license signal: Apache-2.0
- Why it is not a current shared app model:
  - it is a PyTorch and Transformers runtime, not a drop-in `sherpa-onnx` model
  - desktop-only integration currently fits best as a separate backend path
  - redistribution of the exact downloaded backend assets still needs a shipping review even though the license signal is promising

## Rule for the repo

If a model license or redistribution status is Unknown, we can use it for local evaluation only. We do not bundle or distribute it with the applications until the missing license evidence is captured.
