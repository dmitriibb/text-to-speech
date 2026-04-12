from __future__ import annotations

from pathlib import Path


class OpenVoiceEngine:
    @property
    def is_ready(self) -> bool:
        return False

    def generate_preview(
        self,
        *,
        text: str,
        language: str,
        reference_audio_path: Path,
        output_path: Path,
    ) -> None:
        raise RuntimeError(
            'OpenVoice inference is not wired yet. '
            'The async backend contract and storage layout are ready, '
            'but the engine implementation still needs to be connected.'
        )