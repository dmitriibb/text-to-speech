from __future__ import annotations

from pathlib import Path

from .config import Settings


class StorageManager:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def ensure_directories(self) -> None:
        for path in (
            self._settings.jobs_dir,
            self._settings.reference_audio_dir,
            self._settings.results_dir,
        ):
            path.mkdir(parents=True, exist_ok=True)

    def job_path(self, job_id: str) -> Path:
        return self._settings.jobs_dir / f'{job_id}.json'

    def reference_audio_path(self, job_id: str) -> Path:
        return self._settings.reference_audio_dir / f'{job_id}.wav'

    def result_audio_path(self, job_id: str) -> Path:
        return self._settings.results_dir / f'{job_id}.wav'

