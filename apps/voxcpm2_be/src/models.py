from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Any

from pydantic import BaseModel, Field


class JobStatus(str, Enum):
    queued = 'queued'
    running = 'running'
    succeeded = 'succeeded'
    failed = 'failed'


class HealthResponse(BaseModel):
    ok: bool
    backend: str
    version: str
    engine: str
    engine_display_name: str
    engine_ready: bool
    models_loaded: bool
    jobs_in_progress: int
    current_model_id: str
    current_model_name: str
    runtime_assets_ready: bool
    initialization_error: str | None = None
    features: list[str] = Field(default_factory=list)
    supported_job_modes: list[str] = Field(default_factory=list)
    voices_endpoint: str | None = None
    device: str
    device_backend: str


class JobResultPayload(BaseModel):
    audio_ready: bool = False
    download_path: str | None = None
    sample_rate: int | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


class JobRecord(BaseModel):
    job_id: str
    job_type: str
    status: JobStatus
    text: str
    language: str
    speed: float
    model_id: str
    settings: dict[str, Any] = Field(default_factory=dict)
    reference_audio_path: str | None = None
    result_audio_path: str | None = None
    error: str | None = None
    submitted_at: datetime
    started_at: datetime | None = None
    completed_at: datetime | None = None
    result: JobResultPayload = Field(default_factory=JobResultPayload)


class CreateJobResponse(BaseModel):
    job_id: str
    status: JobStatus
    status_url: str
    result_url: str

