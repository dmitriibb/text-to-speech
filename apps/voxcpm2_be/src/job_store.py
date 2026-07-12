from __future__ import annotations

import asyncio
import json
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from fastapi import UploadFile

from .config import Settings
from .engine import VoxCPM2Engine
from .models import JobRecord, JobResultPayload, JobStatus
from .storage import StorageManager


def _utc_now() -> datetime:
    return datetime.now(tz=timezone.utc)


class JobStore:
    def __init__(self, settings: Settings, storage: StorageManager, engine: VoxCPM2Engine) -> None:
        self._settings = settings
        self._storage = storage
        self._engine = engine
        self._lock = asyncio.Lock()
        self._jobs: dict[str, JobRecord] = {}

    async def count_in_progress(self) -> int:
        jobs = await self.list_jobs()
        return sum(job.status in (JobStatus.queued, JobStatus.running) for job in jobs)

    async def create_job(
        self,
        *,
        text: str,
        language: str,
        speed: float,
        settings: dict[str, Any],
        reference_audio: UploadFile | None,
    ) -> JobRecord:
        job_id = f'job-{uuid.uuid4()}'
        reference_path = await self._save_upload(reference_audio, job_id)
        job = JobRecord(
            job_id=job_id,
            job_type='synthesis',
            status=JobStatus.queued,
            text=text,
            language=language,
            speed=speed,
            model_id=self._settings.model_id,
            settings=settings,
            reference_audio_path=str(reference_path) if reference_path else None,
            submitted_at=_utc_now(),
        )
        await self._write_job(job)
        asyncio.create_task(self._run_job(job_id))
        return job

    async def get_job(self, job_id: str) -> JobRecord | None:
        async with self._lock:
            cached = self._jobs.get(job_id)
        if cached is not None:
            return cached
        path = self._storage.job_path(job_id)
        if not path.exists():
            return None
        job = JobRecord.model_validate_json(await asyncio.to_thread(path.read_text, encoding='utf-8'))
        async with self._lock:
            self._jobs[job_id] = job
        return job

    async def list_jobs(self) -> list[JobRecord]:
        paths = list(self._settings.jobs_dir.glob('*.json'))
        jobs: list[JobRecord] = []
        for path in paths:
            try:
                jobs.append(JobRecord.model_validate_json(path.read_text(encoding='utf-8')))
            except (OSError, ValueError):
                continue
        jobs.sort(key=lambda job: job.submitted_at, reverse=True)
        return jobs

    async def _run_job(self, job_id: str) -> None:
        job = await self.get_job(job_id)
        if job is None:
            return
        job.status = JobStatus.running
        job.started_at = _utc_now()
        await self._write_job(job)
        output_path = self._storage.result_audio_path(job_id)
        try:
            sample_rate = await asyncio.to_thread(
                self._engine.generate,
                text=job.text,
                settings=job.settings,
                reference_audio_path=Path(job.reference_audio_path) if job.reference_audio_path else None,
                output_path=output_path,
            )
            job.status = JobStatus.succeeded
            job.result_audio_path = str(output_path)
            job.result = JobResultPayload(
                audio_ready=True,
                download_path=f'/jobs/{job_id}/result',
                sample_rate=sample_rate,
                metadata={'device': self._engine.device, 'device_backend': self._engine.device_backend},
            )
        except Exception as error:
            job.status = JobStatus.failed
            job.error = str(error)
        job.completed_at = _utc_now()
        await self._write_job(job)

    async def _write_job(self, job: JobRecord) -> None:
        async with self._lock:
            self._jobs[job.job_id] = job
            payload = job.model_dump_json(indent=2)
        await asyncio.to_thread(self._storage.job_path(job.job_id).write_text, payload, encoding='utf-8')

    async def _save_upload(self, upload: UploadFile | None, job_id: str) -> Path | None:
        if upload is None:
            return None
        destination = self._storage.reference_audio_path(job_id)
        data = await upload.read()
        if not data:
            raise ValueError('Reference audio is empty.')
        await asyncio.to_thread(destination.write_bytes, data)
        return destination

