from __future__ import annotations

import asyncio

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import RedirectResponse, FileResponse
import uvicorn

from .config import Settings, load_settings
from .engine import OmniVoiceEngine
from .job_store import JobStore
from .models import CreateJobResponse, HealthResponse, JobStatus
from .storage import StorageManager


def create_app(
    *,
    settings: Settings | None = None,
    storage: StorageManager | None = None,
    engine: OmniVoiceEngine | None = None,
    job_store: JobStore | None = None,
) -> FastAPI:
    settings = settings or load_settings()
    storage = storage or StorageManager(settings)
    storage.ensure_directories()
    engine = engine or OmniVoiceEngine(settings)
    job_store = job_store or JobStore(storage=storage, engine=engine)

    app = FastAPI(title='OmniVoice Backend', version=settings.version)

    @app.get('/', include_in_schema=False)
    async def root() -> RedirectResponse:
        return RedirectResponse(url='/health')

    @app.get('/health', response_model=HealthResponse)
    async def health() -> HealthResponse:
        return HealthResponse(
            ok=engine.is_ready,
            backend=settings.app_name,
            version=settings.version,
            engine='omnivoice',
            engine_ready=engine.is_ready,
            models_loaded=True,
            jobs_in_progress=await job_store.count_in_progress(),
            current_model_id='omnivoice-multilingual',
            current_model_name='OmniVoice Multilingual',
            runtime_assets_ready=True,
            initialization_error=engine.initialization_error,
        )

    @app.post('/jobs', response_model=CreateJobResponse, status_code=202)
    async def create_job(
        text: str = Form(...),
        language: str = Form('en'),
        speed: float = Form(1.0),
        reference_audio: UploadFile = File(...),
    ) -> CreateJobResponse:
        if not text.strip():
            raise HTTPException(status_code=400, detail='Text is required.')
        if speed < 0.5 or speed > 2.0:
            raise HTTPException(status_code=400, detail='Speed must be between 0.5 and 2.0.')

        job = await job_store.create_job(
            text=text.strip(),
            language=language.strip() or 'en',
            speed=speed,
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

    return app


settings = load_settings()
storage = StorageManager(settings)
engine = OmniVoiceEngine(settings)
job_store = JobStore(storage=storage, engine=engine)
app = create_app(
    settings=settings,
    storage=storage,
    engine=engine,
    job_store=job_store,
)


def main() -> None:
    uvicorn.run(
        'src.main:app',
        app_dir='.',
        host=settings.host,
        port=settings.port,
    )


if __name__ == '__main__':
    main()
