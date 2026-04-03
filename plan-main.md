# Main Plan: Local Text-to-Speech Monorepo

Updated: 2026-04-03

## 1. Goal Summary

We will build **two local text-to-speech applications in one monorepo**:

1. A **desktop app** for **Ubuntu and Windows**.
2. An **Android app** for local text-to-speech. 

The delivery order is fixed:

1. Build the **desktop app basic functionality** first.
2. Build the **Android app basic functionality** second.
3. Extend the **desktop app** with more advanced speech features third.

The main business rule is also fixed:

- We use **freely available, local, open technologies and models**.
- We do **not** depend on paid cloud TTS APIs.
- We aim for **$0 recurring model/API cost**. The only ongoing cost should be local compute, storage, and optional distribution costs.

Assumptions used in this plan:

- Assumption: **English-only MVP** is acceptable.
- Assumption: first releases can use **direct local distribution or sideloading**, not immediate public app-store publication.
- Assumption: reducing duplicate code between desktop and Android is more important than starting with two completely separate native UI stacks.

## 2. What We Build

### Desktop app MVP

The desktop app is the first target and implements the **middle goal** from `idea.md`:

- Runs on **Windows and Ubuntu**
- Works on **CPU-only machines with around 16 GB RAM**
- Converts typed or pasted English text into **understandable English speech**
- Works **fully offline** after the model is present on the machine

Desktop MVP features:

- Text input area
- Generate speech button
- Audio playback
- Save generated audio as `.wav`
- One default English voice
- Speed control
- Basic model management
- No Internet requirement during synthesis

### Android app MVP

The Android app is the second target and focuses on the same core promise:

- Local English TTS
- Offline speech generation
- One default English voice
- Playback inside the app
- Save or share generated `.wav`

### Desktop advanced phase

After both basic apps exist and are stable, we extend the desktop app with:

- Better voice packs
- More voice options
- Better speech quality
- Experimental tone/style controls
- Experimental voice cloning, only if it remains fully local and legally safe

## 3. Main Technical Decision

We will use **one shared offline speech foundation** across both apps:

- **App framework:** Flutter
- **Speech runtime:** `sherpa-onnx`
- **Baseline TTS model family:** Piper-compatible English ONNX voices
- **Later desktop quality upgrade:** Kokoro
- **Later desktop cloning/style experiment:** OpenVoice V2

This is the most practical stack for the current goals because:

- It stays local and avoids monthly API costs.
- It has a realistic path for **Windows + Ubuntu + Android**.
- It gives us a lightweight CPU-first baseline first.
- It does not force voice cloning into the MVP.
- It lets us reuse a large part of the app and speech logic between desktop and Android.

## 4. Why This Stack

### Flutter

We need two apps in one monorepo, but we do not need two completely different UI stacks if we can avoid it.

Flutter is the recommended app layer because:

- It is **free and open source**.
- It supports **Windows, Linux, and Android** from one codebase family.
- It reduces duplicate work between desktop and Android.
- It supports native integrations when we need them later.

### sherpa-onnx

We use `sherpa-onnx` as the core local inference layer because:

- It is **Apache-2.0** licensed.
- It is designed for **offline speech tasks**.
- It already supports **desktop and Android**.
- It already documents **TTS model packaging and deployment**.
- It supports **Piper and Kokoro model families**, which fits our phased plan.

### Piper-compatible English models for MVP

We use Piper-compatible English ONNX models for the baseline because:

- They are lightweight enough for CPU-first deployment.
- They are already used in offline local TTS setups.
- They are realistic for desktop and Android packaging.
- They are a better MVP fit than heavier voice cloning models.

Important licensing rule:

- We only ship voices with **clear permissive licensing provenance**.
- MVP default voice should be a clearly safe voice such as `en_US-ljspeech-medium`, whose model card points to the **public-domain LJ Speech dataset**.
- We do **not** blindly ship every Piper voice, because some voices have non-commercial or unclear upstream dataset terms.

### Kokoro for later desktop quality upgrades

Kokoro is a good later upgrade because:

- It is available under **Apache-2.0**
- It supports multiple voices
- It fits the "better quality desktop voice pack" phase

We do **not** choose Kokoro as the first baseline because it is larger and should be benchmarked after the smaller MVP is stable.

### OpenVoice V2 for later desktop experiments

OpenVoice V2 is the preferred later cloning/style candidate because:

- It is **MIT** licensed
- It explicitly supports **voice cloning** and **style control**
- It is better aligned with the long-term "tone and cloning" goal than Piper alone

We do **not** put OpenVoice into MVP because it adds major complexity, heavier runtime requirements, and more product/legal risk.

## 5. What We Are Not Building First

We are intentionally **not** starting with:

- Cloud TTS APIs
- Per-character paid inference services
- Android voice cloning
- Complex multi-model routing
- Fine-tuning our own model
- GPU-only assumptions

This is deliberate. The first success criterion is simple:

- **Generate understandable English speech locally on common CPUs**

## 6. Recommended Monorepo Structure

```text
apps/
  desktop_app/
  android_app/

packages/
  tts_core/
  shared_ui/
  model_catalog/
  quality_suite/

tools/
  model_fetch/
  benchmark/
  release/

docs/
  architecture.md
  licensing.md

plan-main.md
```

### Folder responsibilities

- `apps/desktop_app`: Flutter desktop app for Windows and Ubuntu
- `apps/android_app`: Flutter Android app
- `packages/tts_core`: shared speech settings, text chunking, synthesis flow, waveform persistence, error handling
- `packages/shared_ui`: shared screens/components where practical
- `packages/model_catalog`: model manifest, checksums, license metadata, allowed voices list
- `packages/quality_suite`: benchmark texts, smoke tests, acceptance samples
- `tools/model_fetch`: scripts for downloading approved models outside Git
- `tools/benchmark`: scripts for latency, RAM, and output checks
- `tools/release`: packaging and artifact generation

## 7. Tools We Use

### Core development tools

- Flutter SDK
- Dart
- Android Studio and Gradle
- Git
- Root project scripts for build/test/release automation

### Speech tools

- `sherpa-onnx` runtime
- Piper-compatible ONNX English voices
- Kokoro ONNX model later
- OpenVoice V2 later for desktop-only experimental work

### Optional platform acceleration

Desktop MVP is **CPU-first**.

If Windows CPU performance is later insufficient, we can evaluate:

- ONNX Runtime on Windows
- DirectML / Windows ML acceleration

This stays outside the MVP because the desktop app is meant to satisfy the **middle goal**, not the Windows AMD GPU goal first.

## 8. How We Build It

### Phase 0: Foundation and validation

Before building polished UI, we validate the stack with a small internal spike:

- Create the monorepo structure
- Add one approved English MVP voice
- Add a small command-line synthesis harness
- Confirm offline synthesis on Ubuntu and Windows
- Confirm model download, checksum, and cache behavior
- Freeze the initial licensing allowlist
- Build a benchmark text corpus for short, medium, and long inputs

Expected result:

- We know the baseline model actually works locally before we invest in UI polish.

### Phase 1: Desktop app basic functionality

This is the first real product milestone.

Build:

- Desktop Flutter shell
- Shared `tts_core` integration
- Text input and generate flow
- Audio playback
- `.wav` export
- Speed control
- Voice selection for approved local voices
- Local model management and caching
- Error states for missing model, bad text, or generation failure

Desktop acceptance criteria:

- Runs on Ubuntu and Windows
- Runs offline after model installation
- Generates understandable English speech
- Saves valid `.wav` files
- Supports at least one safe, bundled or downloadable English voice
- Handles short and medium text reliably

Expected result:

- A basic desktop app that already satisfies the practical MVP goal.

### Phase 2: Android app basic functionality

This is the second major milestone.

Build:

- Android Flutter shell
- Reuse shared `tts_core`
- Android-safe model storage strategy
- Playback
- `.wav` save/share
- Same baseline English voice path
- Basic settings screen

Android acceptance criteria:

- Runs on a supported Android device without network access
- Generates understandable English speech locally
- Uses an approved lightweight model
- Plays audio in-app
- Saves or shares generated `.wav`

Expected result:

- A second application that proves the same local-first TTS concept works on Android.

### Phase 3: Desktop extension

Only after Phases 1 and 2 are stable:

- Add better desktop voice packs
- Add Kokoro as a higher-quality optional model path if benchmarks are acceptable
- Add longer-text handling improvements
- Add better sentence splitting and synthesis queueing
- Add experimental "Voice Lab" features behind a clear experimental flag
- Evaluate OpenVoice V2 for desktop-only reference-voice cloning and style control

Desktop advanced acceptance criteria:

- Basic desktop workflow remains stable
- Advanced features are optional and do not break the base CPU-first mode
- Advanced models are separable downloads, not a hard dependency

Expected result:

- The desktop app grows from "works locally" to "offers better quality and experimental control."

## 9. Known and Accepted Limitations

These limitations are accepted by design:

- MVP is **English-first**.
- MVP targets **understandable** speech, not perfect human-level naturalness.
- Desktop MVP is **CPU-first**, not GPU-first.
- Android MVP does **not** include voice cloning.
- Voice cloning is **desktop-only experimental work** until proven practical.
- Large models will increase installer size, download size, RAM use, and generation time.
- Some open TTS voices are **not safe to redistribute** because of their upstream dataset terms.
- We will likely need **model downloads outside Git**, because large model files should not live in the repo.
- Long text may require chunking and queueing to avoid memory spikes.

## 10. Unknowns

Unknown:

- Exact target Android minimum version
- Exact supported Android device class
- Exact acceptable latency on reference hardware
- Preferred desktop artifact type (`.deb`, AppImage, portable zip, installer)
- Whether commercial redistribution is required from day one

Needed to decide:

- One or two reference Windows machines
- One reference Ubuntu machine
- One reference Android device
- A target release format decision
- A decision on whether public app-store distribution is needed early

## 11. Licensing and Cost Policy

This project should remain financially predictable.

### Accepted choices

- Flutter: free, open source
- sherpa-onnx: free, open source
- Piper-compatible ONNX voices: free to use, but **voice-by-voice license review is mandatory**
- Kokoro: free, open source
- OpenVoice V2: free, open source

### Rejected baseline choices

- Paid cloud TTS services: rejected because of recurring cost and online dependency
- XTTS v2 as the main plan: rejected for now because its model license is **Coqui Public Model License**, not the simple permissive MIT/Apache route we want
- Heavy cloning-first architectures: rejected because they increase risk before the MVP exists

### Cost note

Model/API recurring cost target:

- **$0 per month**

Possible non-model costs outside the core technical plan:

- Optional code signing
- Optional app-store fees
- Optional CI or artifact hosting costs

Those are deployment choices, not model/runtime dependencies.

## 12. Order of Execution

This is the exact order we follow:

1. Validate the baseline local stack and licensing.
2. Build the desktop app basic functionality.
3. Stabilize and benchmark the desktop app on CPU-first hardware.
4. Build the Android app basic functionality using the same offline speech foundation.
5. Extend the desktop app with better voices and optional advanced voice features.

## 13. Expected Final Outcome

If we follow this plan, the monorepo should end with:

- One desktop app for Ubuntu and Windows that works locally and speaks understandable English
- One Android app that also works locally and speaks understandable English
- A shared offline speech foundation across both apps
- No dependency on paid monthly TTS providers
- A safe path to later desktop-only upgrades such as better voices, style control, and voice cloning

## 14. Source Notes Used For This Plan

Official sources checked on 2026-04-03:

- Flutter desktop and platform support: https://docs.flutter.dev/platform-integration/desktop
- Flutter supported platforms: https://docs.flutter.dev/reference/supported-platforms
- Flutter repository and license: https://github.com/flutter/flutter
- sherpa-onnx repository and license: https://github.com/k2-fsa/sherpa-onnx
- sherpa-onnx Android docs: https://k2-fsa.github.io/sherpa/onnx/android/index.html
- sherpa-onnx pre-trained TTS models: https://k2-fsa.github.io/sherpa/onnx/pretrained_models/index.html
- sherpa-onnx Kokoro models: https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/kokoro.html
- sherpa-onnx Flutter Android TTS APK examples: https://k2-fsa.github.io/sherpa/onnx/flutter/tts-android-cn.html
- Piper repository status and license: https://github.com/rhasspy/piper
- Piper English voice cards: https://huggingface.co/rhasspy/piper-voices/tree/main/en/en_US
- `en_US-ljspeech-medium` model card: https://huggingface.co/rhasspy/piper-voices/blob/main/en/en_US/ljspeech/medium/MODEL_CARD
- `en_US-libritts_r-medium` model card: https://huggingface.co/rhasspy/piper-voices/blob/main/en/en_US/libritts_r/medium/MODEL_CARD
- OpenVoice repository and license: https://github.com/myshell-ai/OpenVoice
- XTTS v2 model page and license: https://huggingface.co/coqui/XTTS-v2
- Windows ML / DirectML guidance: https://learn.microsoft.com/en-us/windows/ai/directml/dml-get-started
