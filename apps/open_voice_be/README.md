# OpenVoice Backend

Local FastAPI backend for the desktop app's OpenVoice integration.

## Current MVP scope

- Manual local startup by the user
- Async preview jobs with job IDs
- Disk-backed job metadata in `storage/jobs/*.json`
- Reference audio stored in `storage/reference_audio/*.wav`
- Result audio stored in `storage/results/*.wav`
- Health and capabilities endpoints for the desktop app

## Current limitation

The async backend contract is implemented, but real OpenVoice inference is not wired yet.
Jobs will fail with a clear backend error until an engine implementation is added.

## Run locally

```powershell
cd apps/open_voice_be
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
uvicorn src.main:app --app-dir . --host 127.0.0.1 --port 8008
```

## Storage layout

```text
storage/
  jobs/
    <job-id>.json
  reference_audio/
    <job-id>.wav
  results/
    <job-id>.wav
  presets/
```

## API

- `GET /health`
- `GET /capabilities`
- `POST /jobs/clone-preview`
- `GET /jobs/{job_id}`
- `GET /jobs/{job_id}/result`