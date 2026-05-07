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
    engine_ready: bool
    models_loaded: bool
    jobs_in_progress: int
    current_model_id: str | None = None
    current_model_name: str | None = None
    runtime_assets_ready: bool | None = None
    initialization_error: str | None = None


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
    model_id: str | None = None
    reference_audio_path: str
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


class ReferencedFileResponse(BaseModel):
    kind: str
    path: str
    exists: bool


class JobSummaryResponse(BaseModel):
    job_id: str
    job_type: str
    status: JobStatus
    text: str
    language: str
    speed: float
    model_id: str | None = None
    submitted_at: datetime
    started_at: datetime | None = None
    completed_at: datetime | None = None
    error: str | None = None
    referenced_files: list[ReferencedFileResponse] = Field(default_factory=list)


class ModelSummaryResponse(BaseModel):
    id: str
    display_name: str
    description: str
    downloaded: bool
    is_current: bool
    runtime_ready: bool


class RuntimeAssetResponse(BaseModel):
    name: str
    path: str
    downloaded: bool


class ModelCatalogResponse(BaseModel):
    current_model_id: str
    runtime_assets_ready: bool
    models: list[ModelSummaryResponse]
    runtime_assets: list[RuntimeAssetResponse]


class UpdateCurrentModelRequest(BaseModel):
    model_id: str
