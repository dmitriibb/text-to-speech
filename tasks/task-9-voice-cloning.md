# Voice Cloning – Voice Lab (Extended – Desktop Only)

## Goal

Let the desktop user clone a voice from a short audio sample and use the cloned voice for synthesis. This is the most advanced Extended feature and requires a voice embedding model in addition to the TTS model.

## Current Status

In progress. A desktop prototype exists for Voice Lab, imported reference audio, and Pocket TTS-based cloned synthesis. The main-screen model discovery issue is fixed, Pocket TTS installation hardening is in place, install-task UX now reports real download or extraction progress, desktop model discovery is aligned to a single app-managed storage path, task cleanup semantics remove temporary files on cancel or dismiss, desktop task-row save now exports a real copy of generated audio, the shared tar extraction path has been hardened so Piper installs preserve the full runtime payload, and the Voice Lab import flow now uses the desktop system file chooser instead of requiring manual path entry.

## Context

- Voice cloning in the sherpa_onnx ecosystem typically uses a speaker embedding model (e.g., 3D-Speaker, WeSpeaker, or ECAPA-TDNN) to extract a voice embedding from a reference audio clip.
- The embedding is then passed to a multi-speaker TTS model (like Kokoro) to synthesize in the cloned voice.
- sherpa_onnx provides `SpeakerEmbedding` / `SpeakerDiarization` APIs that can extract embeddings, but the Dart API surface for this may be limited.
- This feature is research-heavy: the exact pipeline depends on which models and APIs sherpa_onnx exposes.

## Scope

### In Scope

1. **Research phase** — determine the exact pipeline:
   - Which embedding model to use (must be ONNX-compatible, open-license).
   - How to pass custom embeddings to Kokoro's synthesis.
   - Whether sherpa_onnx Dart API supports custom speaker embeddings or if FFI extension is needed.
2. **Audio recording / import** — UI to record a voice sample (10–30 seconds) or import a WAV file.
3. **Embedding extraction** — run the embedding model on the sample to produce a speaker vector.
4. **Custom voice synthesis** — pass the extracted embedding to the TTS model for synthesis.
5. **Voice library** — save and manage cloned voices (name, embedding, sample audio) for reuse.
6. **Voice Lab screen** — dedicated desktop screen for managing cloned voices (record, preview, delete).

### Out of Scope

- Real-time voice conversion (streaming).
- Fine-tuning or training models.
- Mobile support.

## Dependencies

- **Task 6 (Kokoro model support)** — cloning targets Kokoro's multi-speaker architecture.
- **Task 8 (Voice tuning)** — the speaker selector should integrate cloned voices alongside built-in speakers.

## Implementation Steps (Preliminary)

1. **Research**: investigate sherpa_onnx speaker embedding APIs in Dart. Check if `OfflineTts.generateWithCallback` or similar accepts raw speaker embeddings.
2. **Research**: identify a suitable open-license speaker embedding model (e.g., `3dspeaker_speech_eres2net_base_sv_zh-cn_3dspeaker_16k.onnx` from sherpa-onnx models).
3. **Prototype**: build a minimal Dart script that extracts an embedding from a WAV file and feeds it to Kokoro synthesis.
4. **Audio input UI**: add recording (via `record` package or raw FFI) and file picker to a new Voice Lab screen. The desktop file chooser path is now implemented for WAV import.
5. **Embedding service**: create `VoiceEmbeddingService` in desktop app that loads the embedding model and extracts vectors.
6. **Voice storage**: save cloned voices as JSON metadata + embedding binary in a local directory.
7. **Integration**: add cloned voices to the speaker dropdown (task 8's UI) so they can be selected like built-in speakers.
8. **Voice Lab screen**: dedicated screen accessible from desktop app navigation for managing the voice library.

## Blockers

- **Unknown API surface**: it's unclear whether sherpa_onnx Dart bindings expose speaker embedding injection for TTS. This must be researched before committing to an implementation plan.
- Depends on tasks 6 and 8.

## Risk

This is the highest-risk Extended feature. If sherpa_onnx doesn't support custom embeddings via its Dart API, we may need:
- Direct FFI calls to the C API.
- A separate native helper binary.
- A different voice cloning approach entirely.

The research phase (steps 1–3) should be completed before committing to the full implementation.

## Next Steps

Start with step 1 (research sherpa_onnx speaker embedding Dart API).
