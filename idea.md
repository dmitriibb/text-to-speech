# Idea desciption from ChatGPT 

#### Given prompt
I want to build text-to-speach app which can run locally with local AI models.
What tools and models can I use to achieve my goals? 

1 - minimal goal - run it locally on windows machine with 32Gb RAM and 16 Gb AMD radeon GPU
2 - middle goal - run on any machine (windows / ubuntu) 16Gb RAM on CPU
3 - advanced goal - run it on mobile - android app.

- Minimal requirements - app generates understandable English speech
- advanced requirement - I can tune speech spead, tone, voice or even mimic some uploaded voice


#### Agent response
I’m checking the current local TTS options with an eye on your three targets: Windows + AMD GPU, low-RAM CPU machines, and Android. Then I’ll map which models are realistic for speed control, voice selection, and voice cloning.

I’ve narrowed it down to three realistic families: very light ONNX models for CPU/mobile, higher-quality small models for desktop, and heavier cloning-focused models for advanced voice mimicry. I’m verifying which ones are actually practical on AMD/Windows versus only on Linux/NVIDIA.

Thought for 4m 18s

Yes — and the best way is not to use one model for everything.

For your goals, I would split the problem into base TTS and voice cloning/style control:

Base TTS: use a small ONNX model such as Piper or Kokoro.
Voice cloning / style / tone: add a second, heavier model such as XTTS v2 or OpenVoice V2.
Runtime layer: use ONNX Runtime wherever possible, because it has Android support and a Windows GPU path through DirectML, which is the most AMD-friendly option on Windows among the stacks I checked.

My practical recommendation:

1) Minimal goal: Windows, 32 GB RAM, 16 GB AMD Radeon GPU

Use this stack:

UI: Tauri, Electron, or a simple local web UI
Backend: Python first; later Rust/C++ if you want tighter packaging
Runtime: ONNX Runtime + DirectML
Model: Kokoro ONNX first, Piper as fallback

Why:

Kokoro is small for its quality at 82M parameters, has ONNX variants, supports voice selection and an explicit speed parameter in its official examples, and is Apache-2.0 licensed.
Piper is the safest “just works locally” option: it is a fast local TTS system, MIT licensed, has many voices, and its voices come in x_low / low / medium / high quality tiers; some models are also multi-speaker.
DirectML in ONNX Runtime is designed for inference on broad Windows GPU hardware, so it is a much better fit for your Radeon on Windows than PyTorch stacks that mostly assume CUDA.

For this goal, Kokoro is the better “pleasant English voice” choice, and Piper is the better “maximum reliability and small footprint” choice.

2) Middle goal: any machine, Windows/Ubuntu, 16 GB RAM, CPU only

Use this stack:

Model: Piper first
Optional second path: Pocket TTS if you want English-only voice cloning on CPU
Runtime: CPU ONNX Runtime for Piper/Kokoro; plain PyTorch CPU for Pocket TTS if needed

Why:

Piper is the best cross-platform CPU-first baseline. It is lightweight, local, and already used in deployment-oriented ecosystems.
Pocket TTS is surprisingly strong for your English-only CPU target: it is built to run on CPU, is about 100M parameters, supports streaming, voice cloning, and reports about 200 ms to first audio chunk in its README, but it is English only right now.

So for goal 2:

want the safest app → Piper
want CPU-only English voice cloning → Pocket TTS
want nicer baseline voice without going heavy → Kokoro
3) Advanced goal: Android app, fully local

Use this stack:

App: native Kotlin
Inference: ONNX Runtime Android or sherpa-onnx
Model: start with Piper or another sherpa-compatible ONNX TTS model
Later, experiment with cloning separately

Why:

ONNX Runtime has official Android support, including the Java/Kotlin dependency com.microsoft.onnxruntime:onnxruntime-android.
sherpa-onnx officially supports local TTS, has Android docs, prebuilt APKs, and its Android APK docs explicitly say it runs locally, without internet connection. It also has a dedicated TTS engine APK path and Flutter Android TTS APK examples.
sherpa’s Flutter Android docs show direct support for Piper-derived models in packaged APK naming.

The important caveat is this: plain local TTS on Android is realistic now; full voice cloning on Android is the hardest part. One sherpa-onnx issue explicitly notes that original Pocket TTS prompt-based voice cloning is not currently supported there, so you should not assume every desktop cloning model will transfer cleanly to mobile.

For speed / tone / voice / mimic

Here is the clean mapping:

Change speed: Kokoro and XTTS v2 both expose a speed parameter.
Choose different built-in voices: Kokoro, Piper, XTTS v2. Piper also has multi-speaker models.
Clone an uploaded voice: XTTS v2, OpenVoice V2, Pocket TTS, ZipVoice.
Control tone / emotion / accent / intonation: OpenVoice V2 is the strongest explicit fit from the models I checked. Its official materials call out style control, including emotion, accent, rhythm, pauses, and intonation.
Heavier cloning models worth knowing

XTTS v2

Good local cloning option
Supports single or multiple reference clips
Has speed control
Supports streaming
Official docs list 16 languages
License is Coqui Public Model License, not MIT/Apache.

OpenVoice V2

Very good for cloning + style control
MIT licensed
Officially highlights tone-color cloning, style control, and cross-lingual cloning
Native multilingual support includes English, Spanish, French, Chinese, Japanese, Korean.

F5-TTS

Strong newer cloning/research option
MIT licensed
Official docs mention AMD GPU via ROCm on Linux only
Much more comfortable on Linux research rigs than on Windows Radeon.

ZipVoice

Interesting if voice cloning becomes central
123M parameters
Officially positioned as fast, high-quality zero-shot TTS
Currently focused on English and Chinese.
What I would build in your place

I would do it in 3 phases:

Phase 1
Build a desktop app with Kokoro or Piper only.
Goal: generate understandable English speech locally, change voice, change speed.

Phase 2
Add a second “advanced voice” mode using XTTS v2 or OpenVoice V2.
Goal: uploaded reference voice, cloning, style control.

Phase 3
Port only the base ONNX TTS path to Android first.
Goal: Android app with local speech generation.
Treat mobile voice cloning as a separate R&D step, not as MVP.

Final choice

If you want the most practical stack:

Desktop MVP: Kokoro ONNX + ONNX Runtime
Safest low-resource fallback: Piper
CPU-only English cloning: Pocket TTS
Best advanced cloning/style module: OpenVoice V2 or XTTS v2
Android path: sherpa-onnx or ONNX Runtime Android
Do not make Android voice cloning part of v1

Also: only clone voices you have permission to use.

Next step could be a concrete MVP architecture for desktop first, Android later, with recommended folders, model-loading flow, and which parts to keep in Python vs ONNX vs mobile