from __future__ import annotations

import json
from typing import Any

import uvicorn
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse, RedirectResponse

from .config import Settings, load_settings
from .engine import VoxCPM2Engine
from .job_store import JobStore
from .models import CreateJobResponse, HealthResponse, JobStatus
from .storage import StorageManager


def create_app(
    *,
    settings: Settings | None = None,
    storage: StorageManager | None = None,
    engine: VoxCPM2Engine | None = None,
    job_store: JobStore | None = None,
) -> FastAPI:
    settings = settings or load_settings()
    storage = storage or StorageManager(settings)
    storage.ensure_directories()
    engine = engine or VoxCPM2Engine(settings)
    job_store = job_store or JobStore(settings, storage, engine)
    app = FastAPI(title='VoxCPM2 Backend', version=settings.version)

    @app.get('/', include_in_schema=False)
    async def root() -> RedirectResponse:
        return RedirectResponse(url='/health')

    @app.get('/health', response_model=HealthResponse)
    async def health() -> HealthResponse:
        return HealthResponse(
            ok=engine.is_ready,
            backend=settings.app_name,
            version=settings.version,
            engine=engine.engine_name,
            engine_display_name=engine.engine_display_name,
            engine_ready=engine.is_ready,
            models_loaded=engine.is_loaded,
            jobs_in_progress=await job_store.count_in_progress(),
            current_model_id=settings.model_id,
            current_model_name='OpenBMB VoxCPM2',
            runtime_assets_ready=engine.is_loaded,
            initialization_error=engine.initialization_error,
            features=['multilingual', 'voice_design', 'voice_cloning', 'model_settings', 'cpu_fallback'],
            supported_job_modes=['synthesis', 'design', 'clone'],
            device=engine.device,
            device_backend=engine.device_backend,
        )

    @app.post('/jobs', response_model=CreateJobResponse, status_code=202)
    async def create_job(
        text: str = Form(...),
        language: str = Form('de'),
        speed: float = Form(1.0),
        settings_json: str = Form('{}', alias='settings'),
        reference_audio: UploadFile | None = File(None),
    ) -> CreateJobResponse:
        if not text.strip():
            raise HTTPException(status_code=400, detail='Text is required.')
        if speed < 0.5 or speed > 2.0:
            raise HTTPException(status_code=400, detail='Speed must be between 0.5 and 2.0.')
        model_settings = _parse_settings(settings_json)
        _validate_settings(model_settings, reference_audio is not None)
        try:
            job = await job_store.create_job(
                text=text.strip(),
                language=language.strip() or 'de',
                speed=speed,
                settings=model_settings,
                reference_audio=reference_audio,
            )
        except ValueError as error:
            raise HTTPException(status_code=400, detail=str(error)) from error
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

    return app


def _parse_settings(raw: str) -> dict[str, Any]:
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as error:
        raise HTTPException(status_code=400, detail='settings must be valid JSON.') from error
    if not isinstance(parsed, dict):
        raise HTTPException(status_code=400, detail='settings must be a JSON object.')
    return parsed


def _validate_settings(settings: dict[str, Any], has_reference_audio: bool) -> None:
    cfg = float(settings.get('cfg_value', 2.0))
    steps = int(settings.get('inference_timesteps', 10))
    if cfg <= 0 or cfg > 10:
        raise HTTPException(status_code=400, detail='settings.cfg_value must be greater than 0 and at most 10.')
    if steps < 1 or steps > 100:
        raise HTTPException(status_code=400, detail='settings.inference_timesteps must be between 1 and 100.')
    if settings.get('use_reference_as_prompt') and not has_reference_audio:
        raise HTTPException(status_code=400, detail='Reference audio is required when settings.use_reference_as_prompt is true.')
    if settings.get('use_reference_as_prompt') and not str(settings.get('prompt_text', '')).strip():
        raise HTTPException(status_code=400, detail='settings.prompt_text is required when settings.use_reference_as_prompt is true.')


settings = load_settings()
storage = StorageManager(settings)
engine = VoxCPM2Engine(settings)
job_store = JobStore(settings, storage, engine)
app = create_app(settings=settings, storage=storage, engine=engine, job_store=job_store)


def main() -> None:
    uvicorn.run('src.main:app', app_dir='.', host=settings.host, port=settings.port)


if __name__ == '__main__':
    main()

