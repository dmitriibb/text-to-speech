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


class VoiceMode(str, Enum):
    clone = 'clone'
    design = 'design'
    auto = 'auto'


class HealthResponse(BaseModel):
    ok: bool
    backend: str
    version: str
    engine: str
    engine_display_name: str | None = None
    engine_ready: bool
    models_loaded: bool
    jobs_in_progress: int
    current_model_id: str | None = None
    current_model_name: str | None = None
    runtime_assets_ready: bool | None = None
    initialization_error: str | None = None
    features: list[str] = Field(default_factory=list)
    supported_job_modes: list[VoiceMode] = Field(default_factory=list)
    voices_endpoint: str | None = None


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
    settings: dict[str, Any] = Field(default_factory=dict)
    model_id: str | None = None
    voice_id: str | None = None
    voice_label: str | None = None
    reference_audio_path: str | None = None
    reference_text: str | None = None
    instruct: str | None = None
    duration: float | None = None
    num_step: int | None = None
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


class VoiceOptionResponse(BaseModel):
    id: str
    display_name: str
    description: str
    mode: VoiceMode
    requires_reference_audio: bool = False
    supports_instruction_editing: bool = False
    preset_instruction: str | None = None
