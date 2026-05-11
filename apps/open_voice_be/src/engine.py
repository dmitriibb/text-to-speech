from __future__ import annotations

import threading
from pathlib import Path
from typing import Protocol

from .bootstrap import CORE_RUNTIME_ASSETS, ModelBootstrapper
from .config import Settings, load_settings
from .model_manager import BackendModelDefinition, BackendModelManager


class BackendRuntimeEngine(Protocol):
    engine_name: str
    engine_display_name: str

    @property
    def is_ready(self) -> bool: ...

    @property
    def initialization_error(self) -> str | None: ...

    def supports_model(self, model: BackendModelDefinition) -> bool: ...

    def generate_preview(
        self,
        *,
        text: str,
        language: str,
        speed: float,
        model: BackendModelDefinition,
        reference_audio_path: Path,
        output_path: Path,
    ) -> None: ...


class OpenVoiceRuntimeEngine:
    engine_name = 'openvoice'
    engine_display_name = 'OpenVoice'

    def __init__(
        self,
        settings: Settings,
        model_manager: BackendModelManager,
    ) -> None:
        self._settings = settings
        self._bootstrapper = ModelBootstrapper(settings)
        self._model_manager = model_manager
        self._lock = threading.Lock()
        self._initialized = False
        self._initialization_error: str | None = None
        self._device = 'cpu'
        self._melo_language = 'EN_V2'
        self._tone_color_converter = None
        self._melo_tts = None
        self._speaker_ids: dict[str, int] = {}
        self._torch = None

    @property
    def is_ready(self) -> bool:
        return self._initialization_error is None

    @property
    def initialization_error(self) -> str | None:
        return self._initialization_error

    def supports_model(self, model: BackendModelDefinition) -> bool:
        return model.engine == self.engine_name

    def generate_preview(
        self,
        *,
        text: str,
        language: str,
        speed: float,
        model: BackendModelDefinition,
        reference_audio_path: Path,
        output_path: Path,
    ) -> None:
        self._model_manager.ensure_model_ready(model.id)
        self._ensure_initialized()

        normalized_language = language.strip().lower()
        if normalized_language not in ('en', 'en-us', 'english'):
            raise RuntimeError(
                'This OpenVoice backend path currently supports English only.'
            )

        clamped_speed = max(0.5, min(2.0, float(speed)))

        working_dir = self._settings.working_dir / output_path.stem
        working_dir.mkdir(parents=True, exist_ok=True)
        source_audio_path = working_dir / 'source.wav'
        target_se_path = working_dir / 'target_se.pth'

        target_se = self._tone_color_converter.extract_se(
            str(reference_audio_path),
            se_save_path=str(target_se_path),
        )

        speaker_id = self._resolve_speaker_id(model)
        self._melo_tts.tts_to_file(
            text,
            speaker_id,
            str(source_audio_path),
            speed=clamped_speed,
            quiet=True,
        )

        source_se_name = model.id
        source_se_path = (
            self._settings.models_dir
            / 'checkpoints_v2'
            / 'base_speakers'
            / 'ses'
            / f'{source_se_name}.pth'
        )
        source_se = self._torch.load(source_se_path, map_location=self._device)

        output_path.parent.mkdir(parents=True, exist_ok=True)
        self._tone_color_converter.convert(
            audio_src_path=str(source_audio_path),
            src_se=source_se,
            tgt_se=target_se,
            output_path=str(output_path),
            message='openvoice',
        )

        if not output_path.exists():
            raise RuntimeError('OpenVoice preview generation did not create output audio.')

    def _ensure_initialized(self) -> None:
        if self._initialized:
            return

        with self._lock:
            if self._initialized:
                return

            try:
                self._bootstrapper.ensure_runtime_dependencies()
                self._bootstrapper.ensure_assets(CORE_RUNTIME_ASSETS)

                import torch
                from melo.api import TTS
                from openvoice.api import ToneColorConverter

                converter_dir = self._settings.models_dir / 'checkpoints_v2' / 'converter'
                melo_dir = self._settings.models_dir / 'melotts' / 'english-v2'

                tone_color_converter = ToneColorConverter(
                    str(converter_dir / 'config.json'),
                    device=self._device,
                )
                tone_color_converter.load_ckpt(str(converter_dir / 'checkpoint.pth'))

                melo_tts = TTS(
                    language=self._melo_language,
                    device=self._device,
                    config_path=str(melo_dir / 'config.json'),
                    ckpt_path=str(melo_dir / 'checkpoint.pth'),
                )
            except Exception as error:
                self._initialization_error = str(error)
                raise

            self._torch = torch
            self._tone_color_converter = tone_color_converter
            self._melo_tts = melo_tts
            self._speaker_ids = dict(melo_tts.hps.data.spk2id)
            self._initialized = True
            self._initialization_error = None

    def _resolve_speaker_id(self, model: BackendModelDefinition) -> int:
        candidates = (
            model.speaker_key,
            model.speaker_key.upper(),
            model.speaker_key.replace('-', '_').upper(),
            model.speaker_key.replace('-', ''),
        )
        for candidate in candidates:
            if candidate in self._speaker_ids:
                return self._speaker_ids[candidate]

        available = ', '.join(sorted(self._speaker_ids.keys()))
        raise RuntimeError(
            f'Configured speaker {model.speaker_key} is not available. '
            f'Backend speaker IDs: {available}'
        )


class OmniVoiceRuntimeEngine:
    engine_name = 'omnivoice'
    engine_display_name = 'OmniVoice'

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._lock = threading.Lock()
        self._initialized = False
        self._initialization_error: str | None = None
        self._model = None
        self._torch = None
        self._soundfile = None
        self._device = 'cpu'

    @property
    def is_ready(self) -> bool:
        return self._initialization_error is None

    @property
    def initialization_error(self) -> str | None:
        return self._initialization_error

    def supports_model(self, model: BackendModelDefinition) -> bool:
        return model.engine == self.engine_name

    def generate_preview(
        self,
        *,
        text: str,
        language: str,
        speed: float,
        model: BackendModelDefinition,
        reference_audio_path: Path,
        output_path: Path,
    ) -> None:
        self._ensure_initialized()

        output_path.parent.mkdir(parents=True, exist_ok=True)
        clamped_speed = max(0.5, min(2.0, float(speed)))
        normalized_language = language.strip()
        if not normalized_language:
            normalized_language = None

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
        if not output_path.exists():
            raise RuntimeError('OmniVoice generation did not create output audio.')

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
            except Exception as error:
                self._initialization_error = str(error)
                raise

            self._torch = torch
            self._soundfile = sf
            self._initialized = True
            self._initialization_error = None


class OpenVoiceEngine:
    def __init__(
        self,
        settings: Settings | None = None,
        model_manager: BackendModelManager | None = None,
    ) -> None:
        self._settings = settings or load_settings()
        self._model_manager = model_manager
        if self._model_manager is None:
            raise RuntimeError('Backend model manager is required.')

        self._engines: tuple[BackendRuntimeEngine, ...] = (
            OpenVoiceRuntimeEngine(self._settings, self._model_manager),
            OmniVoiceRuntimeEngine(self._settings),
        )

    @property
    def is_ready(self) -> bool:
        current_engine = self._resolve_current_engine()
        return current_engine.is_ready

    @property
    def initialization_error(self) -> str | None:
        current_engine = self._resolve_current_engine()
        return current_engine.initialization_error

    @property
    def engine_name(self) -> str:
        return self._resolve_current_engine().engine_name

    @property
    def engine_display_name(self) -> str:
        return self._resolve_current_engine().engine_display_name

    def generate_preview(
        self,
        *,
        text: str,
        language: str,
        speed: float,
        model_id: str | None,
        reference_audio_path: Path,
        output_path: Path,
    ) -> None:
        current_model = self._resolve_model(model_id)
        engine = self._engine_for_model(current_model)
        engine.generate_preview(
            text=text,
            language=language,
            speed=speed,
            model=current_model,
            reference_audio_path=reference_audio_path,
            output_path=output_path,
        )

    def _resolve_current_engine(self) -> BackendRuntimeEngine:
        return self._engine_for_model(self._model_manager.get_current_model())

    def _engine_for_model(self, model: BackendModelDefinition) -> BackendRuntimeEngine:
        for engine in self._engines:
            if engine.supports_model(model):
                return engine
        raise RuntimeError(f'No backend engine is configured for model {model.id}.')

    def _resolve_model(self, model_id: str | None) -> BackendModelDefinition:
        if model_id:
            return self._model_manager.get_model(model_id)
        return self._model_manager.get_current_model()
