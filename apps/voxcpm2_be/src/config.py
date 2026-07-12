from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    app_name: str
    version: str
    host: str
    port: int
    model_id: str
    device: str
    load_denoiser: bool
    optimize: bool
    root_dir: Path
    storage_dir: Path
    jobs_dir: Path
    reference_audio_dir: Path
    results_dir: Path


def _env_bool(name: str, default: bool) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {'1', 'true', 'yes', 'on'}


def load_settings() -> Settings:
    root_dir = Path(__file__).resolve().parents[1]
    storage_dir = root_dir / 'storage'
    return Settings(
        app_name='voxcpm2_be',
        version='0.1.0',
        host=os.getenv('VOXCPM_HOST', '127.0.0.1'),
        port=int(os.getenv('VOXCPM_PORT', '8011')),
        model_id=os.getenv('VOXCPM_MODEL_ID', 'openbmb/VoxCPM2'),
        device=os.getenv('VOXCPM_DEVICE', 'auto'),
        load_denoiser=_env_bool('VOXCPM_LOAD_DENOISER', False),
        optimize=_env_bool('VOXCPM_OPTIMIZE', True),
        root_dir=root_dir,
        storage_dir=storage_dir,
        jobs_dir=storage_dir / 'jobs',
        reference_audio_dir=storage_dir / 'reference_audio',
        results_dir=storage_dir / 'results',
    )

