from __future__ import annotations

import threading
from pathlib import Path

from .config import Settings, load_settings


class OmniVoiceEngine:
    def __init__(self, settings: Settings | None = None) -> None:
        self._settings = settings or load_settings()
        self._lock = threading.Lock()
        self._initialized = False
        self._initialization_error: str | None = None
        self._device = 'cpu'
        self._model = None
        self._soundfile = None

    @property
    def is_ready(self) -> bool:
        return self._initialization_error is None

    @property
    def initialization_error(self) -> str | None:
        return self._initialization_error

    def generate_preview(
        self,
        *,
        text: str,
        language: str,
        speed: float,
        reference_audio_path: Path,
        output_path: Path,
    ) -> None:
        self._ensure_initialized()
        output_path.parent.mkdir(parents=True, exist_ok=True)

        normalized_language = language.strip() or None
        clamped_speed = max(0.5, min(2.0, float(speed)))

        generated_audio = self._model.generate(
            text=text,
            language=normalized_language,
            ref_audio=str(reference_audio_path),
            speed=clamped_speed,
        )
        if not generated_audio:
            raise RuntimeError('OmniVoice did not return generated audio.')

        self._soundfile.write(
            str(output_path),
            generated_audio[0],
            self._model.sampling_rate,
        )

    def _ensure_initialized(self) -> None:
        if self._initialized:
            return

        with self._lock:
            if self._initialized:
                return

            try:
                import soundfile as sf
                import torch
                from omnivoice import OmniVoice

                if torch.cuda.is_available():
                    self._device = 'cuda'
                    dtype = torch.float16
                elif getattr(torch.backends, 'mps', None) and torch.backends.mps.is_available():
                    self._device = 'mps'
                    dtype = torch.float16
                else:
                    self._device = 'cpu'
                    dtype = torch.float32

                self._model = OmniVoice.from_pretrained(
                    'k2-fsa/OmniVoice',
                    device_map=self._device,
                    dtype=dtype,
                    load_asr=True,
                )
                self._soundfile = sf
            except Exception as error:
                self._initialization_error = str(error)
                raise

            self._initialized = True
            self._initialization_error = None
