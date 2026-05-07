from __future__ import annotations

import shutil
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from .config import Settings


@dataclass(frozen=True)
class ModelAsset:
    relative_path: str
    url: str


OPENVOICE_V2_CORE_ASSETS = (
    ModelAsset(
        relative_path='checkpoints_v2/converter/config.json',
        url='https://huggingface.co/myshell-ai/OpenVoiceV2/resolve/main/converter/config.json?download=true',
    ),
    ModelAsset(
        relative_path='checkpoints_v2/converter/checkpoint.pth',
        url='https://huggingface.co/myshell-ai/OpenVoiceV2/resolve/main/converter/checkpoint.pth?download=true',
    ),
)

BASE_SPEAKER_ASSETS = {
    'en-default': ModelAsset(
        relative_path='checkpoints_v2/base_speakers/ses/en-default.pth',
        url='https://huggingface.co/myshell-ai/OpenVoiceV2/resolve/main/base_speakers/ses/en-default.pth?download=true',
    ),
    'en-us': ModelAsset(
        relative_path='checkpoints_v2/base_speakers/ses/en-us.pth',
        url='https://huggingface.co/myshell-ai/OpenVoiceV2/resolve/main/base_speakers/ses/en-us.pth?download=true',
    ),
    'en-br': ModelAsset(
        relative_path='checkpoints_v2/base_speakers/ses/en-br.pth',
        url='https://huggingface.co/myshell-ai/OpenVoiceV2/resolve/main/base_speakers/ses/en-br.pth?download=true',
    ),
    'en-au': ModelAsset(
        relative_path='checkpoints_v2/base_speakers/ses/en-au.pth',
        url='https://huggingface.co/myshell-ai/OpenVoiceV2/resolve/main/base_speakers/ses/en-au.pth?download=true',
    ),
    'en-india': ModelAsset(
        relative_path='checkpoints_v2/base_speakers/ses/en-india.pth',
        url='https://huggingface.co/myshell-ai/OpenVoiceV2/resolve/main/base_speakers/ses/en-india.pth?download=true',
    ),
}

MELOTTS_ENGLISH_V2_ASSETS = (
    ModelAsset(
        relative_path='melotts/english-v2/config.json',
        url='https://huggingface.co/myshell-ai/MeloTTS-English-v2/resolve/main/config.json?download=true',
    ),
    ModelAsset(
        relative_path='melotts/english-v2/checkpoint.pth',
        url='https://huggingface.co/myshell-ai/MeloTTS-English-v2/resolve/main/checkpoint.pth?download=true',
    ),
)

CORE_RUNTIME_ASSETS = (*OPENVOICE_V2_CORE_ASSETS, *MELOTTS_ENGLISH_V2_ASSETS)


class ModelBootstrapper:
    def __init__(self, settings: Settings) -> None:
        self._settings = settings

    def ensure_models(self) -> None:
        self.ensure_assets((*CORE_RUNTIME_ASSETS, *BASE_SPEAKER_ASSETS.values()))

    def ensure_assets(self, assets: Iterable[ModelAsset]) -> None:
        self._settings.models_dir.mkdir(parents=True, exist_ok=True)
        for asset in assets:
            destination = self.asset_destination(asset)
            if destination.exists() and destination.stat().st_size > 0:
                continue
            self._download(asset.url, destination)

    def ensure_runtime_dependencies(self) -> None:
        self._ensure_nltk_resources()

    def asset_destination(self, asset: ModelAsset) -> Path:
        return self._settings.models_dir / asset.relative_path

    def _ensure_nltk_resources(self) -> None:
        import nltk

        required_resources = {
            'taggers/averaged_perceptron_tagger': 'averaged_perceptron_tagger',
            'taggers/averaged_perceptron_tagger_eng':
                'averaged_perceptron_tagger_eng',
            'corpora/cmudict': 'cmudict',
        }

        for lookup_path, download_name in required_resources.items():
            try:
                nltk.data.find(lookup_path)
            except LookupError:
                nltk.download(download_name, quiet=True)

    def _download(self, url: str, destination: Path) -> None:
        destination.parent.mkdir(parents=True, exist_ok=True)
        temporary_path = destination.with_suffix(destination.suffix + '.download')
        with urllib.request.urlopen(url) as response:
            with temporary_path.open('wb') as sink:
                shutil.copyfileobj(response, sink)
        temporary_path.replace(destination)
