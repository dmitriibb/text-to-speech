from __future__ import annotations

import threading
from dataclasses import dataclass
from pathlib import Path

from .config import Settings, load_settings
from .models import VoiceMode


@dataclass(frozen=True)
class OmniVoiceVoiceDefinition:
    id: str
    display_name: str
    description: str
    mode: VoiceMode
    requires_reference_audio: bool = False
    supports_instruction_editing: bool = False
    preset_instruction: str | None = None


VOICE_DEFINITIONS: tuple[OmniVoiceVoiceDefinition, ...] = (
    OmniVoiceVoiceDefinition(
        id='clone-reference',
        display_name='Clone From Reference Audio',
        description='Use a short reference clip to clone that speaker in the target language.',
        mode=VoiceMode.clone,
        requires_reference_audio=True,
    ),
    OmniVoiceVoiceDefinition(
        id='auto-random',
        display_name='Auto Voice',
        description='Let OmniVoice choose a voice automatically without a reference clip.',
        mode=VoiceMode.auto,
    ),
    OmniVoiceVoiceDefinition(
        id='narrator-female',
        display_name='Narrator Female',
        description='Calm, clear narration tuned for longer passages and explainers.',
        mode=VoiceMode.design,
        supports_instruction_editing=True,
        preset_instruction='female, calm, clear narration, medium pitch',
    ),
    OmniVoiceVoiceDefinition(
        id='narrator-male',
        display_name='Narrator Male',
        description='Steady male narration voice with lower pitch and a measured pace.',
        mode=VoiceMode.design,
        supports_instruction_editing=True,
        preset_instruction='male, calm, low pitch, documentary narrator',
    ),
    OmniVoiceVoiceDefinition(
        id='conversational-warm',
        display_name='Warm Conversational',
        description='Friendly, approachable voice for demos, chats, and assistants.',
        mode=VoiceMode.design,
        supports_instruction_editing=True,
        preset_instruction='warm, friendly, conversational, natural pacing',
    ),
    OmniVoiceVoiceDefinition(
        id='british-female',
        display_name='British Female',
        description='Voice design preset with a British English accent.',
        mode=VoiceMode.design,
        supports_instruction_editing=True,
        preset_instruction='female, british accent, articulate, medium pitch',
    ),
    OmniVoiceVoiceDefinition(
        id='british-male',
        display_name='British Male',
        description='Voice design preset with a British English accent and lower pitch.',
        mode=VoiceMode.design,
        supports_instruction_editing=True,
        preset_instruction='male, british accent, low pitch, articulate',
    ),
    OmniVoiceVoiceDefinition(
        id='whisper-female',
        display_name='Whisper Female',
        description='Soft whisper-style voice design preset for expressive short lines.',
        mode=VoiceMode.design,
        supports_instruction_editing=True,
        preset_instruction='female, whisper, soft, intimate',
    ),
)


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

    @property
    def engine_display_name(self) -> str:
        return 'OmniVoice Multilingual'

    def list_voice_definitions(self) -> list[OmniVoiceVoiceDefinition]:
        return list(VOICE_DEFINITIONS)

    def get_voice_definition(
        self,
        voice_id: str | None,
    ) -> OmniVoiceVoiceDefinition:
        if voice_id is None:
            return VOICE_DEFINITIONS[0]

        for voice in VOICE_DEFINITIONS:
            if voice.id == voice_id:
                return voice
        raise ValueError(f'Unknown OmniVoice voice: {voice_id}')

    def generate_preview(
        self,
        *,
        text: str,
        voice_id: str | None,
        language: str,
        speed: float,
        reference_audio_path: Path | None,
        reference_text: str | None = None,
        instruct: str | None = None,
        duration: float | None = None,
        num_step: int | None = None,
        output_path: Path,
    ) -> None:
        self._ensure_initialized()
        output_path.parent.mkdir(parents=True, exist_ok=True)

        selected_voice = self.get_voice_definition(voice_id)
        normalized_language = language.strip() or None
        clamped_speed = max(0.5, min(2.0, float(speed)))
        generation_kwargs: dict[str, object] = {'text': text, 'speed': clamped_speed}

        if normalized_language is not None:
            generation_kwargs['language'] = normalized_language
        if duration is not None:
            generation_kwargs['duration'] = float(duration)
        if num_step is not None:
            generation_kwargs['num_step'] = int(num_step)

        if selected_voice.mode == VoiceMode.clone:
            if reference_audio_path is None:
                raise RuntimeError('OmniVoice clone mode requires reference audio.')
            generation_kwargs['ref_audio'] = str(reference_audio_path)
            cleaned_reference_text = reference_text.strip() if reference_text else ''
            if cleaned_reference_text:
                generation_kwargs['ref_text'] = cleaned_reference_text
        elif selected_voice.mode == VoiceMode.design:
            effective_instruct = (instruct or selected_voice.preset_instruction or '').strip()
            if not effective_instruct:
                raise RuntimeError('OmniVoice voice design requires a prompt.')
            generation_kwargs['instruct'] = effective_instruct

        generated_audio = self._model.generate(**generation_kwargs)
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
