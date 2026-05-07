# Voice Cloning – Voice Lab (Extended – Desktop Only)

## Goal

Let the desktop user clone a voice from a short audio sample and use the cloned voice for synthesis. This is the most advanced Extended feature and requires a voice embedding model in addition to the TTS model.

## Current Status

In progress. A desktop prototype exists for Voice Lab, imported reference audio, and Pocket TTS-based cloned synthesis. The main-screen model discovery issue is fixed, Pocket TTS installation hardening is in place, install-task UX now reports real download or extraction progress, desktop model discovery is aligned to a single app-managed storage path, task cleanup semantics remove temporary files on cancel or dismiss, desktop task-row save now exports a real copy of generated audio, the shared tar extraction path has been hardened so Piper installs preserve the full runtime payload, the Voice Lab import flow now uses the desktop system file chooser instead of requiring manual path entry, Advanced Functionality now appears inline beside Basic Functionality instead of opening as a separate screen, Voice Lab now uses separate `Voice cloning Pocket TTS` and `Voice cloning OpenVoice` toggles that unfold their controls inline inside the same card, the OpenVoice section stays visible even when the backend is down so the backend URL can still be edited, OpenVoice health is refreshed in the background every 10 seconds while its toggle is on, the OpenVoice API contract is simplified to `GET /health`, `POST /jobs`, `GET /jobs/{job_id}`, and `GET /jobs/{job_id}/result`, the backend now has a dedicated `apps/open_voice_be/how-to-run.md` guide for Windows, Ubuntu, and macOS startup, the backend docs no longer require the large `unidic` download step, and the preferred local entrypoint is now `python -m src.main`, reference WAV loading now initializes sherpa bindings before cloned synthesis starts, regular Pocket TTS synthesis now falls back to the model's bundled default reference clip instead of writing an empty WAV, the shared background-task payload now preserves Pocket reference-audio metadata so standard synthesis can use that fallback in the isolate runtime, and Voice Lab import now accepts either WAV or MP3 while normalizing imported MP3 samples to stored WAV files automatically. The OpenVoice reference picker now accepts WAV or MP3 too, desktop normalizes any chosen MP3 to a temporary WAV before uploading it to the backend, the OpenVoice action is now `Generate Speech`, Voice Lab state survives navigation away from and back to the screen, completed OpenVoice results are registered into the shared Home-screen generated-audio task list instead of staying local to Voice Lab, and the Home-screen speed slider now propagates through the OpenVoice job API so backend-rendered speech uses the same speed value instead of a hardcoded `1.0`.

OpenVoice backend work is now wired to a real runtime. The repo contains a new `apps/open_voice_be` FastAPI app with async speech-job endpoints, disk-backed `.json` job metadata, `.wav` reference and result storage under `storage/`, deterministic model downloads under `models/`, and a desktop Voice Lab OpenVoice section for backend URL entry, health checks, WAV selection, and async job polling. The backend uses official OpenVoice V2 checkpoints plus official MeloTTS English-v2 in CPU mode as the first Windows-target runtime. The desktop client polls job status with 1s, 2s, 3s, and so on up to 10s. The backend now also serves a lightweight browser admin at `/admin` that lists the available OpenVoice base-speaker checkpoints, shows which ones are downloaded, lets the user choose the current backend model, and shows saved backend jobs with their referenced files. Deleting a backend job from that admin removes its job record and job-owned files.

The backend has also been tested end to end on Windows using a real reference WAV supplied in the repo root. Health checks succeed, speech jobs are accepted, jobs move through `queued -> running -> succeeded`, and the result endpoint returns a generated WAV. Windows setup needed two concrete fixes during validation: replacing the Python 3.11-only `StrEnum` usage with a Python 3.10-compatible enum, and avoiding the optional `faster-whisper`/`av` dependency chain by installing OpenVoice with `--no-deps` and extracting the speaker embedding directly from the uploaded WAV.

The OpenVoice backend runtime assets under `apps/open_voice_be/models/` and generated job data under `apps/open_voice_be/storage/` are local-only state. They must stay out of git and be recreated by backend startup or by rerunning local speech jobs.

A Windows-clone repository integrity issue was also found: the shared `src/models/` sources and desktop `lib/models/cloned_voice.dart` were missing from git because `.gitignore` used a recursive `models/` rule. The ignore rule now targets only the repo-root `/models/` directory so source-model files can be committed normally.

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
2. **Audio recording / import** — UI to record a voice sample (10–30 seconds) or import a WAV/MP3 file, converting MP3 to WAV automatically when needed.
3. **Embedding extraction** — run the embedding model on the sample to produce a speaker vector.
4. **Custom voice synthesis** — pass the extracted embedding to the TTS model for synthesis.
5. **Voice library** — save and manage cloned voices (name, embedding, sample audio) for reuse.
6. **Voice Lab UI** — inline desktop panel for managing cloned voices (import, preview, delete) beside the Basic panel.

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
4. **Audio input UI**: add recording (via `record` package or raw FFI) and file picker to the inline Voice Lab panel. The desktop file chooser path is now implemented for WAV import.
5. **Embedding service**: create `VoiceEmbeddingService` in desktop app that loads the embedding model and extracts vectors.
6. **Voice storage**: save cloned voices as JSON metadata + embedding binary in a local directory.
7. **Integration**: add cloned voices to the speaker dropdown (task 8's UI) so they can be selected like built-in speakers.
8. **Voice Lab layout**: inline Advanced panel beside the Basic panel, with shared text input and Pocket TTS-driven voice cloning mode.

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

1. Verify the full OpenVoice backend startup and speech-generation flow on a real Windows Python environment with the official dependencies installed.
2. Verify the browser admin against a real backend runtime, including model download, model switching, and backend-job deletion while work is running.
3. Decide whether OpenVoice presets stay backend-only or need desktop-side save and browse flows in this milestone.
4. Add end-to-end result export and preset persistence once speech generation succeeds consistently.
