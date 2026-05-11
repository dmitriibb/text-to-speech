from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    app_name: str
    version: str
    host: str
    port: int
    root_dir: Path
    storage_dir: Path
    working_dir: Path
    jobs_dir: Path
    reference_audio_dir: Path
    results_dir: Path


def load_settings() -> Settings:
    root_dir = Path(__file__).resolve().parents[1]
    storage_dir = root_dir / 'storage'
    return Settings(
        app_name='omnivoice_be',
        version='0.1.0-mvp',
        host='127.0.0.1',
        port=8010,
        root_dir=root_dir,
        storage_dir=storage_dir,
        working_dir=storage_dir / 'working',
        jobs_dir=storage_dir / 'jobs',
        reference_audio_dir=storage_dir / 'reference_audio',
        results_dir=storage_dir / 'results',
    )
