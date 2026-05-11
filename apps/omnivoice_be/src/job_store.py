from __future__ import annotations

import asyncio
import json
import tempfile
import uuid
from datetime import datetime, timezone
from pathlib import Path

from fastapi import UploadFile

from .engine import OmniVoiceEngine
from .models import JobRecord, JobResultPayload, JobStatus
from .storage import StorageManager


def _utc_now() -> datetime:
    return datetime.now(tz=timezone.utc)


class JobStore:
    def __init__(
        self,
        storage: StorageManager,
        engine: OmniVoiceEngine,
    ) -> None:
        self._storage = storage
        self._engine = engine
        self._lock = asyncio.Lock()
        self._jobs: dict[str, JobRecord] = {}
        self._deleted_jobs: set[str] = set()

    async def count_in_progress(self) -> int:
        jobs = await self.list_jobs()
        return sum(
            1 for job in jobs if job.status in (JobStatus.queued, JobStatus.running)
        )

    async def create_job(
        self,
        *,
        text: str,
        language: str,
        speed: float,
        reference_audio: UploadFile,
    ) -> JobRecord:
        job_id = f'job-{uuid.uuid4()}'
        reference_audio_path = self._storage.reference_audio_path(job_id)
        stored_reference_path = await self._save_upload_as_wav(
            upload=reference_audio,
            destination=reference_audio_path,
        )

        job = JobRecord(
            job_id=job_id,
            job_type='clone',
            status=JobStatus.queued,
            text=text,
            language=language,
            speed=speed,
            model_id='omnivoice-multilingual',
            reference_audio_path=str(stored_reference_path),
            submitted_at=_utc_now(),
        )
        await self._write_job(job)
        asyncio.create_task(self._run_job(job_id))
        return job

    async def get_job(self, job_id: str) -> JobRecord | None:
        async with self._lock:
            if job_id in self._deleted_jobs:
                return None
            cached = self._jobs.get(job_id)
            if cached is not None:
                return cached

        job_path = self._storage.job_path(job_id)
        if not job_path.exists():
            return None

        raw = await asyncio.to_thread(job_path.read_text, encoding='utf-8')
        job = JobRecord.model_validate(json.loads(raw))
        async with self._lock:
            if job_id in self._deleted_jobs:
                return None
            self._jobs[job_id] = job
        return job

    async def list_jobs(self) -> list[JobRecord]:
        disk_jobs = await asyncio.to_thread(self._read_jobs_from_disk)
        async with self._lock:
            deleted_jobs = set(self._deleted_jobs)
            memory_jobs = dict(self._jobs)

        jobs_by_id = {job.job_id: job for job in disk_jobs if job.job_id not in deleted_jobs}
        for job_id, job in memory_jobs.items():
            if job_id in deleted_jobs:
                continue
            jobs_by_id[job_id] = job

        jobs = list(jobs_by_id.values())
        jobs.sort(key=lambda job: job.submitted_at, reverse=True)
        return jobs

    async def _run_job(self, job_id: str) -> None:
        job = await self.get_job(job_id)
        if job is None:
            return

        job.status = JobStatus.running
        job.started_at = _utc_now()
        await self._write_job(job)

        result_audio_path = self._storage.result_audio_path(job_id)
        try:
            await asyncio.to_thread(
                self._engine.generate_preview,
                text=job.text,
                language=job.language,
                speed=job.speed,
                reference_audio_path=Path(job.reference_audio_path),
                output_path=result_audio_path,
            )
            job.status = JobStatus.succeeded
            job.result_audio_path = str(result_audio_path)
            job.completed_at = _utc_now()
            job.result = JobResultPayload(
                audio_ready=True,
                download_path=f'/jobs/{job_id}/result',
                metadata={'job_type': job.job_type},
            )
        except Exception as error:
            job.status = JobStatus.failed
            job.completed_at = _utc_now()
            job.error = str(error)
            job.result = JobResultPayload(
                audio_ready=False,
                metadata={'job_type': job.job_type},
            )

        await self._write_job(job)

    async def _save_upload_as_wav(
        self,
        *,
        upload: UploadFile,
        destination: Path,
    ) -> Path:
        suffix = Path(upload.filename or 'reference.wav').suffix or '.wav'
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as temp_file:
            temp_path = Path(temp_file.name)

        try:
            with temp_path.open('wb') as sink:
                while True:
                    chunk = await upload.read(1024 * 1024)
                    if not chunk:
                        break
                    sink.write(chunk)

            await upload.close()
            await asyncio.to_thread(self._storage.copy_wav, temp_path, destination)
            return destination
        finally:
            if temp_path.exists():
                temp_path.unlink(missing_ok=True)

    async def _write_job(self, job: JobRecord) -> None:
        payload = job.model_dump(mode='json')
        job_path = self._storage.job_path(job.job_id)
        async with self._lock:
            if job.job_id in self._deleted_jobs:
                return
            self._jobs[job.job_id] = job
        await asyncio.to_thread(
            job_path.write_text,
            json.dumps(payload, indent=2),
            encoding='utf-8',
        )

    def _read_jobs_from_disk(self) -> list[JobRecord]:
        jobs_dir = self._storage.job_path('placeholder').parent
        if not jobs_dir.exists():
            return []

        jobs: list[JobRecord] = []
        for job_path in jobs_dir.glob('*.json'):
            try:
                raw = job_path.read_text(encoding='utf-8')
                jobs.append(JobRecord.model_validate(json.loads(raw)))
            except Exception:
                continue
        return jobs
