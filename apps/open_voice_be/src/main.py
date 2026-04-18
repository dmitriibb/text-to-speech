from __future__ import annotations

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse

from .config import load_settings
from .engine import OpenVoiceEngine
from .job_store import JobStore
from .models import CapabilitiesResponse, CreateJobResponse, HealthResponse, JobStatus
from .storage import StorageManager

settings = load_settings()
storage = StorageManager(settings)
storage.ensure_directories()
engine = OpenVoiceEngine(settings)
job_store = JobStore(storage=storage, engine=engine)

app = FastAPI(title='OpenVoice Backend', version=settings.version)


@app.get('/health', response_model=HealthResponse)
async def health() -> HealthResponse:
    return HealthResponse(
        ok=engine.is_ready,
        backend=settings.app_name,
        version=settings.version,
        engine='openvoice',
        engine_ready=engine.is_ready,
        models_loaded=engine.is_ready,
        jobs_in_progress=await job_store.count_in_progress(),
    )


@app.get('/capabilities', response_model=CapabilitiesResponse)
async def capabilities() -> CapabilitiesResponse:
    return CapabilitiesResponse(
        supports_preview=engine.is_ready,
        polling_strategy={
            'initial_seconds': 1,
            'increment_seconds': 1,
            'max_seconds': 10,
        },
    )


@app.post('/jobs/clone-preview', response_model=CreateJobResponse, status_code=202)
async def create_clone_preview_job(
    text: str = Form(...),
    language: str = Form('en'),
    reference_audio: UploadFile = File(...),
) -> CreateJobResponse:
    if not text.strip():
        raise HTTPException(status_code=400, detail='Text is required.')

    job = await job_store.create_clone_preview_job(
        text=text.strip(),
        language=language.strip() or 'en',
        reference_audio=reference_audio,
    )
    return CreateJobResponse(
        job_id=job.job_id,
        status=job.status,
        status_url=f'/jobs/{job.job_id}',
        result_url=f'/jobs/{job.job_id}/result',
    )


@app.get('/jobs/{job_id}')
async def get_job(job_id: str):
    job = await job_store.get_job(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail='Job not found.')
    return job


@app.get('/jobs/{job_id}/result')
async def get_job_result(job_id: str):
    job = await job_store.get_job(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail='Job not found.')
    if job.status != JobStatus.succeeded or job.result_audio_path is None:
        raise HTTPException(status_code=409, detail='Job result is not ready.')
    return FileResponse(job.result_audio_path, media_type='audio/wav')