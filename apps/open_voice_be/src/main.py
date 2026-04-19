from __future__ import annotations

import asyncio
from pathlib import Path

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse, RedirectResponse
from fastapi.staticfiles import StaticFiles
import uvicorn

from .config import Settings, load_settings
from .engine import OpenVoiceEngine
from .job_store import JobStore
from .model_manager import BackendModelManager
from .models import (
    CreateJobResponse,
    HealthResponse,
    JobStatus,
    JobSummaryResponse,
    ModelCatalogResponse,
    ModelSummaryResponse,
    ReferencedFileResponse,
    RuntimeAssetResponse,
    UpdateCurrentModelRequest,
)
from .storage import StorageManager


def create_app(
    *,
    settings: Settings | None = None,
    storage: StorageManager | None = None,
    model_manager: BackendModelManager | None = None,
    engine: OpenVoiceEngine | None = None,
    job_store: JobStore | None = None,
) -> FastAPI:
    settings = settings or load_settings()
    storage = storage or StorageManager(settings)
    storage.ensure_directories()
    model_manager = model_manager or BackendModelManager(settings, storage)
    engine = engine or OpenVoiceEngine(settings, model_manager=model_manager)
    job_store = job_store or JobStore(
        storage=storage,
        engine=engine,
        model_manager=model_manager,
    )

    app = FastAPI(title='OpenVoice Backend', version=settings.version)
    static_dir = settings.root_dir / 'src' / 'static'
    app.mount('/admin/static', StaticFiles(directory=static_dir), name='admin-static')

    @app.get('/', include_in_schema=False)
    async def root() -> RedirectResponse:
        return RedirectResponse(url='/admin')

    @app.get('/admin', include_in_schema=False)
    async def admin() -> FileResponse:
        return FileResponse(static_dir / 'index.html')

    @app.get('/health', response_model=HealthResponse)
    async def health() -> HealthResponse:
        current_model = model_manager.get_current_model()
        models_loaded = (
            model_manager.runtime_assets_ready()
            and model_manager.is_model_downloaded(current_model.id)
        )
        return HealthResponse(
            ok=engine.is_ready,
            backend=settings.app_name,
            version=settings.version,
            engine='openvoice',
            engine_ready=engine.is_ready,
            models_loaded=models_loaded,
            jobs_in_progress=await job_store.count_in_progress(),
            current_model_id=current_model.id,
            current_model_name=current_model.display_name,
            runtime_assets_ready=model_manager.runtime_assets_ready(),
            initialization_error=engine.initialization_error,
        )

    @app.get('/api/models', response_model=ModelCatalogResponse)
    async def list_models() -> ModelCatalogResponse:
        return ModelCatalogResponse(
            current_model_id=model_manager.get_current_model_id(),
            runtime_assets_ready=model_manager.runtime_assets_ready(),
            models=[
                ModelSummaryResponse.model_validate(model)
                for model in model_manager.list_models()
            ],
            runtime_assets=[
                RuntimeAssetResponse.model_validate(asset)
                for asset in model_manager.list_runtime_assets()
            ],
        )

    @app.post('/api/models/{model_id}/download', response_model=ModelSummaryResponse)
    async def download_model(model_id: str) -> ModelSummaryResponse:
        try:
            model = await asyncio.to_thread(model_manager.download_model, model_id)
        except ValueError as error:
            raise HTTPException(status_code=404, detail=str(error)) from error
        return ModelSummaryResponse.model_validate(model)

    @app.put('/api/models/current', response_model=ModelSummaryResponse)
    async def set_current_model(
        payload: UpdateCurrentModelRequest,
    ) -> ModelSummaryResponse:
        try:
            model = await asyncio.to_thread(
                model_manager.set_current_model,
                payload.model_id,
            )
        except ValueError as error:
            raise HTTPException(status_code=400, detail=str(error)) from error
        return ModelSummaryResponse.model_validate(model)

    @app.delete('/api/models/{model_id}', response_model=ModelSummaryResponse)
    async def delete_model(model_id: str) -> ModelSummaryResponse:
        if await job_store.has_in_progress_job_for_model(model_id):
            raise HTTPException(
                status_code=409,
                detail='Delete or finish the in-progress jobs for this model first.',
            )

        try:
            model = await asyncio.to_thread(model_manager.delete_model, model_id)
        except ValueError as error:
            raise HTTPException(status_code=404, detail=str(error)) from error
        return ModelSummaryResponse.model_validate(model)

    @app.get('/api/jobs', response_model=list[JobSummaryResponse])
    async def list_jobs() -> list[JobSummaryResponse]:
        jobs = await job_store.list_jobs()
        return [_job_summary(storage, job) for job in jobs]

    @app.delete('/api/jobs/{job_id}')
    async def delete_job(job_id: str) -> dict[str, bool]:
        deleted = await job_store.delete_job(job_id)
        if not deleted:
            raise HTTPException(status_code=404, detail='Job not found.')
        return {'deleted': True}

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
            raise HTTPException(
                status_code=400,
                detail='Speed must be between 0.5 and 2.0.',
            )

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


def _job_summary(storage: StorageManager, job) -> JobSummaryResponse:
    referenced_files = [
        ReferencedFileResponse(
            kind='job_record',
            path=str(storage.job_path(job.job_id)),
            exists=storage.job_path(job.job_id).exists(),
        ),
        ReferencedFileResponse(
            kind='reference_audio',
            path=job.reference_audio_path,
            exists=Path(job.reference_audio_path).exists(),
        ),
        ReferencedFileResponse(
            kind='working_directory',
            path=str(storage.working_directory(job.job_id)),
            exists=storage.working_directory(job.job_id).exists(),
        ),
    ]
    if job.result_audio_path is not None:
        referenced_files.append(
            ReferencedFileResponse(
                kind='result_audio',
                path=job.result_audio_path,
                exists=Path(job.result_audio_path).exists(),
            )
        )

    return JobSummaryResponse(
        job_id=job.job_id,
        job_type=job.job_type,
        status=job.status,
        text=job.text,
        language=job.language,
        speed=job.speed,
        model_id=job.model_id,
        submitted_at=job.submitted_at,
        started_at=job.started_at,
        completed_at=job.completed_at,
        error=job.error,
        referenced_files=referenced_files,
    )


settings = load_settings()
storage = StorageManager(settings)
model_manager = BackendModelManager(settings, storage)
engine = OpenVoiceEngine(settings, model_manager=model_manager)
job_store = JobStore(storage=storage, engine=engine, model_manager=model_manager)
app = create_app(
    settings=settings,
    storage=storage,
    model_manager=model_manager,
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
