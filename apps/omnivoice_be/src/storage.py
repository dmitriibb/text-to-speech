from __future__ import annotations

import shutil
import wave
from pathlib import Path

from .config import Settings


class StorageManager:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def ensure_directories(self) -> None:
        for directory in (
            self._settings.storage_dir,
            self._settings.jobs_dir,
            self._settings.reference_audio_dir,
            self._settings.results_dir,
            self._settings.working_dir,
        ):
            directory.mkdir(parents=True, exist_ok=True)

    def job_path(self, job_id: str) -> Path:
        return self._settings.jobs_dir / f'{job_id}.json'

    def reference_audio_path(self, job_id: str) -> Path:
        return self._settings.reference_audio_dir / f'{job_id}.wav'

    def result_audio_path(self, job_id: str) -> Path:
        return self._settings.results_dir / f'{job_id}.wav'

    def working_directory(self, job_id: str) -> Path:
        return self._settings.working_dir / job_id

    def delete_file(self, path: Path | None) -> None:
        if path is None:
            return
        path.unlink(missing_ok=True)

    def copy_wav(self, source: Path, destination: Path) -> None:
        self.validate_wav(source)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)

    def validate_wav(self, path: Path) -> None:
        with wave.open(str(path), 'rb') as wav_file:
            if wav_file.getnframes() <= 0:
                raise ValueError('Reference audio WAV file is empty.')
