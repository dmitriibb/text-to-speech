# OpenVoice Backend Plan

Updated: 2026-04-12

## Goal

Add a desktop-only advanced voice cloning path based on OpenVoice without disturbing the current embedded `sherpa-onnx` flow used by the existing models.

This plan intentionally separates:

- the Flutter desktop UI
- the OpenVoice execution backend
- the backend hosting method

That separation keeps the app stable while we iterate on the backend implementation and later move from local Python execution to Docker.

## Why We Need A Separate Backend

The current app runs built-in models directly through `sherpa-onnx`.

That works because those models are packaged for the current runtime and can be loaded inside the app process.

OpenVoice is different:

- it is not part of the current embedded `sherpa-onnx` path
- it is more naturally run in its own Python environment
- it has heavier dependencies and a different execution stack

Because of that, the clean architecture is:

- Flutter desktop app stays the UI and orchestration layer
- OpenVoice runs as a separate local backend
- the desktop app talks to that backend over HTTP

This is the simplest way to add OpenVoice without turning the desktop app into a Python dependency manager.

## Core Architecture

### Existing path

- Desktop app
- `tts_core`
- embedded `sherpa-onnx`
- local built-in models such as Piper, Kokoro, Kitten, Pocket

### New path

- Desktop app
- OpenVoice section in Voice Lab
- local HTTP API
- OpenVoice backend process

The desktop app does not need to know whether the backend is launched by:

- raw Python on the local machine
- Docker
- some later packaged local service

The desktop app only needs to know:

- backend URL
- API contract
- health state

## Why We Start With Local Python First

Docker is the long-term host, but not the first implementation target.

We start with local Python because:

- faster iteration while the backend API is still changing
- easier debugging of logs, stack traces, model loading, and file paths
- easier to verify model quality before packaging and containerization work
- avoids solving Docker-specific problems before the core backend behavior is proven

So the rollout is:

1. local Python backend on Windows
2. desktop app integration against the local HTTP API
3. once stable, containerize the backend
4. publish the Docker image

## Why Docker Is Still The Right Second Step

After the backend behavior is stable, Docker becomes the preferred host because it solves environment drift.

Why Docker is good:

- one pinned backend environment
- one place to define Python version and dependencies
- easier repeatability across Windows, Ubuntu, and macOS
- easier sharing through Docker Hub
- easier rollback to an older known-good backend image

Why we do not start with Docker:

- it slows down early debugging
- it adds another failure layer while the backend behavior is still unknown
- it makes iteration on logs and local file mounts slower at the start

## Recommended Repo Placement

Create a third app under `apps/`:

- `apps/open_voice_be`

Why it belongs under `apps/`:

- it is an executable application, not a shared package
- it has its own runtime, dependencies, startup command, and deployment path
- it is a platform-facing app used by the desktop product, even though it is not Flutter

Expected contents:

- `apps/open_voice_be/README.md`
- `apps/open_voice_be/requirements.txt` or equivalent locked dependency file
- `apps/open_voice_be/src/`
- `apps/open_voice_be/src/server.py` or `main.py`
- `apps/open_voice_be/src/config.py`
- `apps/open_voice_be/src/services/`
- `apps/open_voice_be/src/models/`
- `apps/open_voice_be/docker/`
- `apps/open_voice_be/docker/Dockerfile`
- `apps/open_voice_be/docker/docker-compose.example.yml` or run examples

## Desktop UI Plan

The existing Voice Lab already contains the cloning-oriented desktop-only controls.

We should extend it instead of creating a separate top-level screen.

### High-level UI structure

Voice Lab should have two cloning sections:

1. `Pocket TTS`
2. `OpenVoice`

These should be clearly separated so the user understands they are two different engines with different tradeoffs.

### Recommended layout

- `Voice Cloning` area header
- short explanation text
- engine selector or two expandable sections:
  - `Pocket TTS`
  - `OpenVoice`

Recommended UI behavior:

- keep Pocket TTS as the lightweight built-in cloning flow
- show OpenVoice as the advanced quality path
- only one cloning engine should be active at a time

### OpenVoice section should include

- backend status row
  - `Connected`
  - `Not reachable`
  - `Starting` if we later add auto-start support
- configured backend URL
- `Check Connection` button
- reference audio import
- preset name input
- language selector if backend supports multiple languages
- optional style controls only if the backend exposes stable ones
- `Preview`
- `Save Preset`
- existing saved OpenVoice preset list

### Error behavior

If the user enables OpenVoice and the backend is unavailable:

- do not crash
- keep Pocket TTS available
- show a concrete message such as:
  - `OpenVoice backend is not reachable at http://127.0.0.1:8008`
  - `Start the local backend and try again`

Optional later improvement:

- show short local startup instructions
- show detected version from `/health`

## Why The UI Should Use A Backend Status Model

The user needs a clear distinction between:

- Voice Lab UI is fine
- OpenVoice backend is down

Without that separation, failures will look like broken voice cloning instead of backend connectivity problems.

So the desktop app should keep explicit state such as:

- `disconnected`
- `checking`
- `connected`
- `error`

This state belongs to the desktop app, not to `tts_core`, because OpenVoice is a desktop-only extended feature.

## Interaction Model

### Pocket TTS path

- embedded in app
- no external backend
- always available if model is installed

### OpenVoice path

1. user opens Voice Lab
2. app checks backend health
3. if healthy, OpenVoice controls are enabled
4. user imports or selects reference audio
5. user sets text and options
6. app sends request to backend
7. backend returns generated audio or stores it and returns metadata
8. app shows preview and allows save or reuse

## Backend Responsibilities

The OpenVoice backend should own:

- model loading
- backend configuration
- inference
- optional preset persistence
- validation of uploaded reference audio for backend purposes

The Flutter app should own:

- UI state
- user interaction
- local backend health display
- choosing when to call backend endpoints

This split is important because the backend must remain usable regardless of how the desktop UI changes.

## Storage Responsibilities

There are two reasonable choices for persistence.

### Recommended split

Flutter stores:

- local UI preferences
- selected backend URL
- maybe the last used OpenVoice preset ID

Backend stores:

- OpenVoice presets
- backend-side reference audio copies
- generated preview files if the backend needs them
- backend model cache

### MVP storage layout

For the MVP, store backend-owned files directly inside `apps/open_voice_be/storage/`.

Recommended folders:

- `storage/jobs/` for job metadata `.json`
- `storage/reference_audio/` for stored `.wav` uploads
- `storage/results/` for generated `.wav` preview or result audio
- `storage/presets/` for later preset metadata

This keeps the first implementation simple and local-first while staying compatible with later Docker-mounted volumes.

Why:

- the backend can keep its own stable file layout
- Docker migration becomes easier
- Flutter stays independent of backend internals

## Initial Backend API Contract

The app should target a small stable HTTP API.

### `GET /health`

Purpose:

- verify that backend is alive
- return backend version and status

Suggested response fields:

- `ok`
- `backend`
- `version`
- `engine`
- `models_loaded`

### `GET /capabilities`

Purpose:

- tell Flutter which features are currently enabled

Suggested response fields:

- `languages`
- `supports_preview`
- `supports_preset_save`
- `supports_style_controls`
- `style_controls`

### `GET /presets`

Purpose:

- list saved OpenVoice presets

### `POST /presets`

Purpose:

- create or update a reusable OpenVoice preset

Suggested request contents:

- `name`
- `language`
- `reference_audio`
- optional tuning or style parameters

### `DELETE /presets/{id}`

Purpose:

- remove a saved preset

### `POST /clone-preview`

Purpose:

- create an async preview job without committing it as a final saved preset

Suggested request contents:

- `text`
- `language`
- `reference_audio` or `preset_id`
- optional style parameters

Suggested response:

- `202 Accepted`
- `job_id`
- status URL
- result URL

### `POST /generate`

Purpose:

- generate final output intended for playback or export

Suggested response:

- audio bytes directly, or
- a file URL or temporary file token plus metadata

## Async Job Decision

OpenVoice requests should be async from the start.

Recommended flow:

1. desktop app submits preview or generate request
2. backend returns `job_id`
3. desktop app polls job status with intervals of 1s, 2s, 3s, 4s and so on
4. polling interval increases by 1 second per attempt
5. maximum polling interval is 10 seconds
6. desktop app fetches the result only after the job reaches a terminal state

Recommended endpoints:

- `POST /jobs/clone-preview`
- `GET /jobs/{id}`
- `GET /jobs/{id}/result`

Suggested job statuses:

- `queued`
- `running`
- `succeeded`
- `failed`

## Backend Technology Recommendation

Use a small Python web service.

Good practical choices:

- FastAPI
- Uvicorn

Why:

- easy health and JSON endpoints
- simple file upload support
- fast iteration
- easy Dockerization later

## Phase Plan

### Phase 1: Local Python Proof Of Concept

Goal:

- prove that OpenVoice can be run locally on Windows and serve a simple API

Deliverables:

- `apps/open_voice_be` skeleton
- health endpoint
- one working inference endpoint
- manual local launch instructions
- desktop app can detect backend availability

Why:

- validates architecture before Docker work
- proves quality and latency

### Phase 2: Desktop UI Integration

Goal:

- integrate OpenVoice into Voice Lab without disturbing Pocket TTS

Deliverables:

- OpenVoice section in Voice Lab
- backend status indicator
- connection check
- import reference audio
- preview and generate flow
- user-visible backend error handling

Why:

- gives real product value before deployment polish

### Phase 3: Preset Persistence

Goal:

- make custom voices reusable

Deliverables:

- backend preset storage
- preset list in desktop UI
- rename and delete preset support

Why:

- this is the actual user-facing "my custom voices" feature

### Phase 4: Dockerization

Goal:

- package the backend environment and remove machine-specific Python setup

Deliverables:

- Dockerfile
- local run command
- mounted volumes for presets and cache
- documented fixed local port

Why:

- stable deployment environment
- easier multi-machine reuse

### Phase 5: Docker Hub Distribution

Goal:

- publish a reusable backend image

Deliverables:

- tagged images
- versioning strategy
- startup documentation for Windows, Ubuntu, and macOS

Why:

- makes local deployment reproducible for future machines

## Suggested Desktop Behavior During Rollout

Before OpenVoice is available:

- keep Pocket TTS fully working
- show OpenVoice section as experimental or unavailable

After Phase 1:

- show `Check Connection`
- show manual backend URL field if needed
- assume the user starts the backend manually

After Phase 2:

- allow full preview and generation

After Phase 3:

- allow saving named OpenVoice presets

## Risks

### Backend quality risk

- OpenVoice may require more tuning than expected for good results

Mitigation:

- validate quality manually before finalizing UI behavior

### Latency risk

- preview generation may be slow on CPU-only machines

Mitigation:

- start with preview-oriented UX and explicit loading states

### Cross-platform host risk

- Docker behavior differs across Windows, Ubuntu, and macOS

Mitigation:

- keep Flutter bound only to local HTTP
- treat Docker as deployment, not business logic

### Scope risk

- trying to add too much tuning UI before backend behavior is understood

Mitigation:

- expose only stable controls first

## Recommended First Implementation Scope

Keep the first cut small.

Do first:

- `apps/open_voice_be`
- FastAPI backend
- `GET /health`
- one working preview endpoint
- desktop Voice Lab OpenVoice section with:
  - status
  - check connection
  - reference audio import
  - preview

Do later:

- advanced tuning controls
- preset management
- Docker
- Docker Hub publishing
- GPU support

## Why This Plan Is Better Than Direct Docker Coupling

If Flutter were designed around Docker itself, the app would need to understand:

- container names
- Docker daemon state
- image names
- start and stop logic
- platform-specific Docker behavior

That would make the app harder to maintain.

By targeting only a local HTTP backend, the app stays clean and stable while Docker remains only the deployment method.

## Final Recommendation

Proceed with:

1. `apps/open_voice_be` as a Python backend app
2. desktop-only OpenVoice integration in Voice Lab
3. local Python first on Windows
4. Docker as the second step after the backend API and inference flow are stable

This is the best balance between speed, maintainability, and future cross-platform reuse.
