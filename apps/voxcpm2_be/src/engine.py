from __future__ import annotations

import threading
from pathlib import Path
from typing import Any

from .config import Settings, load_settings


class VoxCPM2Engine:
    engine_name = 'voxcpm2'
    engine_display_name = 'VoxCPM2'

    def __init__(self, settings: Settings | None = None) -> None:
        self._settings = settings or load_settings()
        self._lock = threading.Lock()
        self._initialized = False
        self._initialization_error: str | None = None
        self._model = None
        self._soundfile = None
        self._device = 'cpu'
        self._device_backend = 'cpu'

    @property
    def is_ready(self) -> bool:
        return self._initialization_error is None

    @property
    def is_loaded(self) -> bool:
        return self._initialized

    @property
    def initialization_error(self) -> str | None:
        return self._initialization_error

    @property
    def device(self) -> str:
        return self._device

    @property
    def device_backend(self) -> str:
        return self._device_backend

    def generate(
        self,
        *,
        text: str,
        settings: dict[str, Any],
        reference_audio_path: Path | None,
        output_path: Path,
    ) -> int:
        self._ensure_initialized()
        output_path.parent.mkdir(parents=True, exist_ok=True)

        style = _optional_string(settings, 'style')
        effective_text = f'({style}){text}' if style else text
        prompt_text = _optional_string(settings, 'prompt_text')
        use_reference_as_prompt = bool(settings.get('use_reference_as_prompt', False))
        reference_path = str(reference_audio_path) if reference_audio_path else None

        wav = self._model.generate(
            text=effective_text,
            prompt_wav_path=reference_path if use_reference_as_prompt else None,
            prompt_text=prompt_text if use_reference_as_prompt else None,
            reference_wav_path=reference_path,
            cfg_value=float(settings.get('cfg_value', 2.0)),
            inference_timesteps=int(settings.get('inference_timesteps', 10)),
            normalize=bool(settings.get('normalize', True)),
            denoise=bool(settings.get('denoise', False)),
            retry_badcase=bool(settings.get('retry_badcase', True)),
            retry_badcase_max_times=int(settings.get('retry_badcase_max_times', 3)),
            retry_badcase_ratio_threshold=float(
                settings.get('retry_badcase_ratio_threshold', 6.0)
            ),
            seed=_optional_int(settings, 'seed'),
        )
        sample_rate = int(self._model.tts_model.sample_rate)
        self._soundfile.write(str(output_path), wav, sample_rate)
        if not output_path.exists():
            raise RuntimeError('VoxCPM2 did not create output audio.')
        return sample_rate

    def _ensure_initialized(self) -> None:
        if self._initialized:
            return
        with self._lock:
            if self._initialized:
                return
            try:
                import soundfile as sf
                import torch
                from voxcpm import VoxCPM

                requested_device, backend = self._resolve_device(torch)
                try:
                    model = VoxCPM.from_pretrained(
                        self._settings.model_id,
                        load_denoiser=self._settings.load_denoiser,
                        optimize=self._settings.optimize,
                        device=requested_device,
                    )
                except Exception:
                    if requested_device == 'cpu':
                        raise
                    requested_device, backend = 'cpu', 'cpu-fallback'
                    model = VoxCPM.from_pretrained(
                        self._settings.model_id,
                        load_denoiser=self._settings.load_denoiser,
                        optimize=False,
                        device='cpu',
                    )

                self._model = model
                self._soundfile = sf
                self._device = requested_device
                self._device_backend = backend
                self._initialized = True
                self._initialization_error = None
            except Exception as error:
                self._initialization_error = str(error)
                raise

    def _resolve_device(self, torch: Any) -> tuple[str, str]:
        requested = self._settings.device.strip().lower()
        if requested not in {'', 'auto'}:
            if requested.startswith('cuda') and not torch.cuda.is_available():
                return 'cpu', 'cpu-fallback'
            if requested == 'mps':
                mps = getattr(torch.backends, 'mps', None)
                if mps is None or not mps.is_available():
                    return 'cpu', 'cpu-fallback'
            backend = (
                'rocm'
                if requested.startswith('cuda')
                and getattr(torch.version, 'hip', None)
                else requested
            )
            return requested, backend

        if torch.cuda.is_available():
            return (
                'cuda',
                'rocm' if getattr(torch.version, 'hip', None) else 'cuda',
            )
        mps = getattr(torch.backends, 'mps', None)
        if mps is not None and mps.is_available():
            return 'mps', 'mps'
        return 'cpu', 'cpu'


def _optional_string(settings: dict[str, Any], key: str) -> str | None:
    value = settings.get(key)
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _optional_int(settings: dict[str, Any], key: str) -> int | None:
    value = settings.get(key)
    return None if value is None else int(value)
