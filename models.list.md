# Open And Free TTS Models For This Repo

Updated: 2026-04-11

This file captures the current short list of open or free-to-use TTS models that are realistic candidates for this app, especially for the desktop build.

The app currently uses the `sherpa-onnx` runtime. That matters because the easiest integrations are models that already have an official or widely used `sherpa-onnx` package. When this file says `size`, it means the approximate package size that matters for this repo, not the smallest raw checkpoint that might exist upstream.

## Current Recommendation Summary

- Easiest additions: more `Piper` voices, multilingual `Kokoro` via `sherpa-onnx`, and `KittenTTS Mini`
- Best near-term path for Chinese support: `kokoro-multi-lang-v1_0`
- Best near-term path for richer English voices without major architecture changes: `KittenTTS Mini`
- Best future path for narrator-like, neutral, or enthusiastic delivery: a style-transfer or voice-cloning model such as `OpenVoice V2`, because plain `Piper`/`Kokoro`/`KittenTTS` mostly give speaker choice, not true emotion knobs

## Model List

### 1. Piper Voices

- Model name: `Piper` voices, for example `en_US-lessac-medium`
- Engine: `sherpa-onnx` over Piper/VITS exports
- Size in MB: usually about `20 MB` to `120+ MB` per voice, depending on the selected voice
- Functionality:
  - standard text-to-speech
  - single-speaker per voice package
  - no built-in voice cloning
  - no true voice-tuning controls
- Languages support:
  - broad coverage across many languages and regional variants
  - practical support depends on which specific Piper voice package is added
- Resource requirements:
  - CPU-friendly
  - good choice for desktop and mobile
  - no GPU requirement
- Voice-tune possibilities:
  - mostly speed only
  - style comes from choosing a different voice, not from mood or tone controls
- Desktop integration difficulty: `Easy`
  - the app already supports the `vits` family
  - adding more Piper voices is mostly catalog work plus licensing review

### 2. Kokoro English via Sherpa

- Model name: `kokoro-en-v0_19`
- Engine: `sherpa-onnx`
- Size in MB: about `369 MB`
- Functionality:
  - standard text-to-speech
  - multi-speaker English model
  - speaker switching
  - no voice cloning
- Languages support:
  - `English` only in the package currently used by this repo
- Resource requirements:
  - CPU-friendly on desktop
  - heavier than Piper, but still usable without a GPU
- Voice-tune possibilities:
  - speaker choice
  - speed
  - no direct narrator, mood, tone, or emphasis slider
- Desktop integration difficulty: `Already integrated`

### 3. Kokoro Multilingual via Sherpa

- Model name: `kokoro-multi-lang-v1_0`
- Engine: `sherpa-onnx`
- Size in MB: about `350 MB`
- Functionality:
  - standard text-to-speech
  - multi-speaker model
  - speaker switching
  - multilingual text normalization assets bundled for Chinese handling
- Languages support:
  - `English`
  - `Chinese`
- Resource requirements:
  - CPU-friendly on desktop
  - no GPU requirement
  - heavier than Piper, but still practical for desktop
- Voice-tune possibilities:
  - speaker choice
  - speed
  - no explicit emotion or style controls
- Desktop integration difficulty: `Easy to Medium`
  - fits the existing `sherpa-onnx` runtime
  - required extra lexicon files, `dict/`, and rule FST assets
- Repo status:
  - added to the model catalog
  - shared runtime updated to support its extra assets

### 4. Official Kokoro 82M

- Model name: `Kokoro-82M`
- Engine:
  - official weights from `hexgrad/Kokoro-82M`
  - practical desktop use in this repo would likely be through `kokoro-onnx` or another ONNX export path
- Size in MB:
  - roughly `320 MB` to `350+ MB` depending on ONNX export and bundled voice assets
  - this is an estimate, because package shape depends on the chosen export path
- Functionality:
  - standard text-to-speech
  - many built-in voices
  - multilingual voice set
  - no built-in zero-shot voice cloning in the same sense as `OpenVoice` or `Pocket TTS`
- Languages support:
  - `English`
  - `Japanese`
  - `Mandarin Chinese`
  - `Spanish`
  - `French`
  - `Hindi`
  - `Italian`
  - `Brazilian Portuguese`
- Resource requirements:
  - can run on CPU
  - desktop is the practical target
  - GPU is optional, not mandatory
- Voice-tune possibilities:
  - mostly voice selection and delivery differences between speakers
  - no simple built-in mood slider
  - you can get narrator-like or more energetic results by picking a fitting speaker, but not with a guaranteed explicit style API
- Desktop integration difficulty: `Medium`
  - the core model is attractive
  - the main work is choosing a stable ONNX packaging/runtime path that matches this repo
  - if we stay on `sherpa-onnx`, the sherpa-packaged multilingual release is lower risk than a custom official ONNX path

### 5. KittenTTS Mini

- Model name: `kitten-mini-en-v0_1-fp16`
- Engine: `sherpa-onnx` package built from KittenTTS
- Size in MB: about `166 MB` for the package used by this repo
- Functionality:
  - standard text-to-speech
  - multiple expressive English voices
  - no built-in voice cloning
- Languages support:
  - `English`
- Resource requirements:
  - CPU-friendly
  - good desktop candidate
  - no GPU requirement
- Voice-tune possibilities:
  - mostly voice selection and speed
  - some voices are naturally more expressive than plain Piper voices
  - still no direct mood or narrator slider
- Desktop integration difficulty: `Easy to Medium`
  - `sherpa-onnx` already exposes a dedicated Kitten model config
  - needed a small shared-runtime extension, not a new app architecture
- Repo status:
  - added to the model catalog
  - shared runtime updated to support the `kitten` family

### 6. MeloTTS

- Model name: `MeloTTS`
- Engine:
  - native `MeloTTS`
  - not a first-class current runtime in this repo
- Size in MB:
  - varies by checkpoint and language
  - expect roughly `60 MB` to `200+ MB` depending on export and selected language pack
- Functionality:
  - standard text-to-speech
  - good multilingual coverage
  - speaker and accent variation depending on checkpoint
  - not focused on voice cloning
- Languages support:
  - includes multilingual support with strong attention to Chinese and English
  - additional language availability depends on the specific checkpoint
- Resource requirements:
  - can run on CPU
  - GPU helps for heavier or faster desktop inference
- Voice-tune possibilities:
  - some voice and delivery variation by speaker
  - limited direct style control
  - not a clear mood-control model
- Desktop integration difficulty: `Medium to Hard`
  - easiest if a stable ONNX/runtime path is chosen
  - harder than sherpa-packaged models because this repo would need another runtime path or model export workflow

### 7. OpenVoice V2

- Model name: `OpenVoice V2`
- Engine:
  - native `OpenVoice`
  - usually paired with a base TTS model such as `MeloTTS`
- Size in MB:
  - combined deployment is usually `hundreds of MB`
  - exact size depends on the selected base model and conversion assets
- Functionality:
  - voice cloning
  - style transfer from a reference clip
  - cross-lingual voice transfer
  - standard synthesis when paired with a base model
- Languages support:
  - depends on the paired base TTS model
  - commonly used for multilingual scenarios
- Resource requirements:
  - CPU is possible for smaller workloads
  - desktop GPU is strongly helpful for good speed
  - not mobile-friendly for this repo's near-term scope
- Voice-tune possibilities:
  - strongest candidate in this list for narrator-like, neutral, enthusiastic, calm, and similar delivery goals
  - tuning is mostly indirect through the reference clip and style transfer, not through a simple mood dropdown
  - can transfer tone, pacing, emphasis style, and voice identity from reference audio
- Desktop integration difficulty: `Hard`
  - this would be a new extended desktop path
  - likely needs a separate runtime pipeline from the current shared `sherpa-onnx` path

## Practical Meaning For Voice Tuning

If the goal is to let the user pick delivery styles such as `narrator-like`, `neutral`, or `enthusiastic`, there are two different levels of support:

- Voice selection level:
  - `Piper`, `Kokoro`, and `KittenTTS` mostly work this way
  - you pick a speaker whose default delivery sounds closer to the target style
  - you can also adjust speed
- Real style-transfer level:
  - `OpenVoice V2` is the strongest candidate here
  - instead of a simple speaker switch, it can copy style cues from reference audio

For this repo, the most practical short-term path is:

1. add more speaker-rich models such as multilingual `Kokoro` and `KittenTTS`
2. later add a desktop-only advanced style path if we want real narrator or mood control

## Kokoro: Current Repo Version vs Official Kokoro

### Current repo Kokoro

- Uses `kokoro-en-v0_19` through `sherpa-onnx`
- English only
- small integration surface because the packaging already matches the runtime used in this app

### Official Kokoro

- Refers to the upstream `Kokoro-82M` model and voice set
- Wider language coverage
- More packaging choices, which is powerful but means more integration decisions

### Simple difference

- Current repo Kokoro: the ready-to-use `sherpa-onnx` package that fits this app now
- Official Kokoro: the broader upstream model family, which may need a separate export or packaging path before it plugs into this repo cleanly

## Kokoro Languages Beyond English

The upstream official Kokoro voice list currently includes:

- English
- Japanese
- Mandarin Chinese
- Spanish
- French
- Hindi
- Italian
- Brazilian Portuguese

For this repo, the multilingual `sherpa-onnx` package we added now is the low-risk next step because it gives `English + Chinese` with a packaging format that already fits the app.

## What "Sherpa-Converted" Means

Simple version:

- the original model did not necessarily come in the exact file layout that `sherpa-onnx` wants
- the `sherpa-onnx` project converted or repackaged it into a ready-to-run ONNX bundle
- that bundle usually includes not only the model weights, but also helper files such as tokens, lexicons, speaker files, `espeak-ng-data`, dictionaries, and normalization rules

So when this file says `sherpa-converted`, it usually means:

- same underlying model idea
- different packaging
- easier to run inside apps that already use `sherpa-onnx`

## Models Not Recommended Right Now

These are interesting, but they are not good default candidates for this repo right now:

- `XTTS-v2`
  - strong feature set
  - licensing and redistribution need extra scrutiny
- `F5-TTS`
  - high-quality research model
  - desktop-only heavy path and more integration work
- `ChatTTS`
  - expressive
  - better suited to dialogue-style generation than simple offline app integration

## Sources

- Sherpa ONNX TTS model index: <https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/index.html>
- Sherpa ONNX VITS/Piper models: <https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/vits.html>
- Sherpa ONNX Kokoro models: <https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/kokoro.html>
- Sherpa ONNX Kitten models: <https://k2-fsa.github.io/sherpa/onnx/tts/pretrained_models/kitten.html>
- Piper voices: <https://huggingface.co/rhasspy/piper-voices>
- Official Kokoro model: <https://huggingface.co/hexgrad/Kokoro-82M>
- Official Kokoro voices list: <https://huggingface.co/hexgrad/Kokoro-82M/blob/main/VOICES.md>
- Kokoro ONNX packaging project: <https://github.com/thewh1teagle/kokoro-onnx>
- MeloTTS: <https://github.com/myshell-ai/MeloTTS>
- MeloTTS Chinese checkpoint: <https://huggingface.co/myshell-ai/MeloTTS-Chinese>
- OpenVoice: <https://github.com/myshell-ai/OpenVoice>
- OpenVoice V2: <https://huggingface.co/myshell-ai/OpenVoiceV2>
- KittenTTS: <https://github.com/KittenML/KittenTTS>
- KittenTTS Mini checkpoint: <https://huggingface.co/KittenML/kitten-tts-mini-0.1>
