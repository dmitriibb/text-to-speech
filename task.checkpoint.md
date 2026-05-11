# Task Checkpoints

## Checkpoint 1
- Added a separate `apps/omnivoice_be` FastAPI backend so OmniVoice can run in its own Python environment without conflicting with OpenVoice and MeloTTS dependencies.
- Kept the desktop-facing backend contract aligned to `GET /health`, `POST /jobs`, `GET /jobs/{job_id}`, and `GET /jobs/{job_id}/result`.
- Added OmniVoice backend config, storage, job persistence, and runtime generation flow with local WAV reference input and WAV result output.
- Updated repo docs and task memory to describe the split between `apps/open_voice_be` and `apps/omnivoice_be`.
- Renamed the Voice Lab user-facing backend toggle from `Voice cloning OpenVoice` to `Voice cloning External backend` so it fits either OpenVoice or OmniVoice.
- Updated the Voice Lab widget tests for the new wording and verified the test file passes.
