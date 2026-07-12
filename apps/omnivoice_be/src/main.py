from __future__ import annotations

import asyncio
import json

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.responses import RedirectResponse, FileResponse
import uvicorn

from .config import Settings, load_settings
from .engine import OmniVoiceEngine
from .job_store import JobStore
from .models import (
    CreateJobResponse,
    HealthResponse,
    JobStatus,
    VoiceMode,
    VoiceOptionResponse,
)
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
            engine_display_name=engine.engine_display_name,
            engine_ready=engine.is_ready,
            models_loaded=True,
            jobs_in_progress=await job_store.count_in_progress(),
            current_model_id='omnivoice-multilingual',
            current_model_name='OmniVoice Multilingual',
            runtime_assets_ready=True,
            initialization_error=engine.initialization_error,
            features=[
                'voice_cloning',
                'voice_design',
                'auto_voice',
                'multilingual',
                'non_verbal_tokens',
                'pronunciation_control',
                'reference_transcript',
                'duration_control',
                'num_step_control',
            ],
            supported_job_modes=[VoiceMode.clone, VoiceMode.design, VoiceMode.auto],
            voices_endpoint='/voices',
        )

    @app.get('/voices', response_model=list[VoiceOptionResponse])
    async def voices() -> list[VoiceOptionResponse]:
        return [
            VoiceOptionResponse(
                id=voice.id,
                display_name=voice.display_name,
                description=voice.description,
                mode=voice.mode,
                requires_reference_audio=voice.requires_reference_audio,
                supports_instruction_editing=voice.supports_instruction_editing,
                preset_instruction=voice.preset_instruction,
            )
            for voice in engine.list_voice_definitions()
        ]

    @app.post('/jobs', response_model=CreateJobResponse, status_code=202)
    async def create_job(
        text: str = Form(...),
        voice_id: str | None = Form(None),
        language: str = Form('en'),
        speed: float = Form(1.0),
        settings_json: str = Form('{}', alias='settings'),
        reference_text: str | None = Form(None),
        instruct: str | None = Form(None),
        duration: float | None = Form(None),
        num_step: int | None = Form(None),
        reference_audio: UploadFile | None = File(None),
    ) -> CreateJobResponse:
        if not text.strip():
            raise HTTPException(status_code=400, detail='Text is required.')
        if speed < 0.5 or speed > 2.0:
            raise HTTPException(status_code=400, detail='Speed must be between 0.5 and 2.0.')
        if duration is not None and duration <= 0:
            raise HTTPException(
                status_code=400,
                detail='Duration must be greater than 0 seconds.',
            )
        if num_step is not None and (num_step < 1 or num_step > 64):
            raise HTTPException(
                status_code=400,
                detail='Num steps must be between 1 and 64.',
            )

        try:
            model_settings = json.loads(settings_json)
        except json.JSONDecodeError as error:
            raise HTTPException(status_code=400, detail='settings must be valid JSON.') from error
        if not isinstance(model_settings, dict):
            raise HTTPException(status_code=400, detail='settings must be a JSON object.')

        voice_id = str(model_settings.get('voice_id', voice_id or '')).strip() or None
        reference_text = str(
            model_settings.get('reference_text', reference_text or '')
        ).strip() or None
        instruct = str(model_settings.get('instruct', instruct or '')).strip() or None
        duration_value = model_settings.get('duration', duration)
        duration = float(duration_value) if duration_value is not None else None
        num_step_value = model_settings.get('num_step', num_step)
        num_step = int(num_step_value) if num_step_value is not None else None
        if duration is not None and duration <= 0:
            raise HTTPException(
                status_code=400,
                detail='Duration must be greater than 0 seconds.',
            )
        if num_step is not None and (num_step < 1 or num_step > 64):
            raise HTTPException(
                status_code=400,
                detail='Num steps must be between 1 and 64.',
            )

        try:
            selected_voice = engine.get_voice_definition(voice_id)
        except ValueError as error:
            raise HTTPException(status_code=400, detail=str(error)) from error

        if selected_voice.requires_reference_audio and reference_audio is None:
            raise HTTPException(
                status_code=400,
                detail='Reference audio is required for the selected OmniVoice voice.',
            )

        cleaned_instruct = instruct.strip() if instruct is not None else ''
        if selected_voice.mode == VoiceMode.design:
            effective_instruct = cleaned_instruct or (selected_voice.preset_instruction or '')
            if not effective_instruct.strip():
                raise HTTPException(
                    status_code=400,
                    detail='Voice design requires a prompt or preset voice instruction.',
                )
        else:
            effective_instruct = None

        job = await job_store.create_job(
            text=text.strip(),
            language=language.strip() or 'en',
            speed=speed,
            settings=model_settings,
            voice_id=selected_voice.id,
            voice_label=selected_voice.display_name,
            reference_text=(reference_text.strip() or None)
            if reference_text is not None
            else None,
            instruct=effective_instruct.strip() if effective_instruct else None,
            duration=duration,
            num_step=num_step,
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
