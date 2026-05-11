# Task Checkpoints

## Checkpoint 1
- Added a separate `apps/omnivoice_be` FastAPI backend so OmniVoice can run in its own Python environment without conflicting with OpenVoice and MeloTTS dependencies.
- Kept the desktop-facing backend contract aligned to `GET /health`, `POST /jobs`, `GET /jobs/{job_id}`, and `GET /jobs/{job_id}/result`.
- Added OmniVoice backend config, storage, job persistence, and runtime generation flow with local WAV reference input and WAV result output.
- Updated repo docs and task memory to describe the split between `apps/open_voice_be` and `apps/omnivoice_be`.
- Renamed the Voice Lab user-facing backend toggle from `Voice cloning OpenVoice` to `Voice cloning External backend` so it fits either OpenVoice or OmniVoice.
- Updated the Voice Lab widget tests for the new wording and verified the test file passes.

## Checkpoint 2
- Replaced the single generic backend UI with separate `Voice cloning OpenVoice` and `Voice cloning OmniVoice` sections in Voice Lab.
- Added separate desktop state for OpenVoice and OmniVoice backend URLs, connection health, selected reference audio, submission state, and latest job tracking.
- Kept the existing backend HTTP contract reusable so both sections still work through the same health and job API shape.
- Updated Voice Lab widget tests for the two-section backend UI and verified the test file passes.
- Shortened `apps/omnivoice_be/how-to-run.md` and made the venv requirement explicit, including the need to start with `./.venv/bin/python -m src.main`.
