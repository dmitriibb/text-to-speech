from __future__ import annotations

import json
import shutil
from dataclasses import dataclass

from .bootstrap import (
    CORE_RUNTIME_ASSETS,
    BASE_SPEAKER_ASSETS,
    ModelAsset,
    ModelBootstrapper,
)
from .config import Settings
from .storage import StorageManager


@dataclass(frozen=True)
class BackendModelDefinition:
    id: str
    display_name: str
    description: str
    speaker_key: str
    asset: ModelAsset


BACKEND_MODELS = (
    BackendModelDefinition(
        id='en-default',
        display_name='English Default',
        description='Balanced OpenVoice base speaker checkpoint.',
        speaker_key='EN-Default',
        asset=BASE_SPEAKER_ASSETS['en-default'],
    ),
    BackendModelDefinition(
        id='en-us',
        display_name='English US',
        description='US English OpenVoice base speaker checkpoint.',
        speaker_key='EN-US',
        asset=BASE_SPEAKER_ASSETS['en-us'],
    ),
    BackendModelDefinition(
        id='en-au',
        display_name='English AU',
        description='Australian English OpenVoice base speaker checkpoint.',
        speaker_key='EN-AU',
        asset=BASE_SPEAKER_ASSETS['en-au'],
    ),
    BackendModelDefinition(
        id='en-br',
        display_name='English BR',
        description='Brazil-flavored English OpenVoice base speaker checkpoint.',
        speaker_key='EN-BR',
        asset=BASE_SPEAKER_ASSETS['en-br'],
    ),
    BackendModelDefinition(
        id='en-india',
        display_name='English India',
        description='Indian English OpenVoice base speaker checkpoint.',
        speaker_key='EN-INDIA',
        asset=BASE_SPEAKER_ASSETS['en-india'],
    ),
)

DEFAULT_MODEL_ID = 'en-us'
_MODEL_BY_ID = {model.id: model for model in BACKEND_MODELS}


class BackendModelManager:
    def __init__(self, settings: Settings, storage: StorageManager) -> None:
        self._storage = storage
        self._bootstrapper = ModelBootstrapper(settings)

    def list_models(self) -> list[dict[str, object]]:
        current_model_id = self.get_current_model_id()
        runtime_ready = self.runtime_assets_ready()
        return [
            {
                'id': model.id,
                'display_name': model.display_name,
                'description': model.description,
                'downloaded': self.is_model_downloaded(model.id),
                'is_current': model.id == current_model_id,
                'runtime_ready': runtime_ready,
            }
            for model in BACKEND_MODELS
        ]

    def list_runtime_assets(self) -> list[dict[str, object]]:
        assets = []
        for asset in CORE_RUNTIME_ASSETS:
            destination = self._bootstrapper.asset_destination(asset)
            assets.append(
                {
                    'name': asset.relative_path,
                    'path': str(destination),
                    'downloaded': destination.exists() and destination.stat().st_size > 0,
                }
            )
        return assets

    def get_model(self, model_id: str) -> BackendModelDefinition:
        model = _MODEL_BY_ID.get(model_id)
        if model is None:
            raise ValueError(f'Unknown backend model: {model_id}')
        return model

    def get_current_model_id(self) -> str:
        state_path = self._storage.backend_state_path()
        if not state_path.exists():
            return DEFAULT_MODEL_ID

        try:
            payload = json.loads(state_path.read_text(encoding='utf-8'))
        except (OSError, ValueError, TypeError):
            return DEFAULT_MODEL_ID

        model_id = payload.get('current_model_id')
        if isinstance(model_id, str) and model_id in _MODEL_BY_ID:
            return model_id
        return DEFAULT_MODEL_ID

    def get_current_model(self) -> BackendModelDefinition:
        return self.get_model(self.get_current_model_id())

    def set_current_model(self, model_id: str) -> dict[str, object]:
        model = self.get_model(model_id)
        if not self.is_model_downloaded(model.id):
            raise ValueError('Download the model before selecting it.')

        state_path = self._storage.backend_state_path()
        state_path.parent.mkdir(parents=True, exist_ok=True)
        state_path.write_text(
            json.dumps({'current_model_id': model.id}, indent=2),
            encoding='utf-8',
        )
        return self.describe_model(model.id)

    def describe_model(self, model_id: str) -> dict[str, object]:
        model = self.get_model(model_id)
        current_model_id = self.get_current_model_id()
        return {
            'id': model.id,
            'display_name': model.display_name,
            'description': model.description,
            'downloaded': self.is_model_downloaded(model.id),
            'is_current': model.id == current_model_id,
            'runtime_ready': self.runtime_assets_ready(),
        }

    def download_model(self, model_id: str) -> dict[str, object]:
        model = self.get_model(model_id)
        self._bootstrapper.ensure_assets((*CORE_RUNTIME_ASSETS, model.asset))
        return self.describe_model(model.id)

    def delete_model(self, model_id: str) -> dict[str, object]:
        model = self.get_model(model_id)
        destination = self._bootstrapper.asset_destination(model.asset)
        if destination.exists():
            destination.unlink(missing_ok=True)

        if self.get_current_model_id() == model.id:
            fallback = self._pick_fallback_model_id(excluding=model.id)
            state_path = self._storage.backend_state_path()
            if fallback is None:
                state_path.unlink(missing_ok=True)
            else:
                state_path.parent.mkdir(parents=True, exist_ok=True)
                state_path.write_text(
                    json.dumps({'current_model_id': fallback}, indent=2),
                    encoding='utf-8',
                )

        return self.describe_model(model.id)

    def is_model_downloaded(self, model_id: str) -> bool:
        model = self.get_model(model_id)
        destination = self._bootstrapper.asset_destination(model.asset)
        return destination.exists() and destination.stat().st_size > 0

    def runtime_assets_ready(self) -> bool:
        for asset in CORE_RUNTIME_ASSETS:
            destination = self._bootstrapper.asset_destination(asset)
            if not destination.exists() or destination.stat().st_size <= 0:
                return False
        return True

    def ensure_model_ready(self, model_id: str) -> BackendModelDefinition:
        self.download_model(model_id)
        return self.get_model(model_id)

    def delete_runtime_working_directory(self, job_id: str) -> None:
        working_directory = self._storage.working_directory(job_id)
        if working_directory.exists():
            shutil.rmtree(working_directory, ignore_errors=True)

    def _pick_fallback_model_id(self, *, excluding: str) -> str | None:
        for model in BACKEND_MODELS:
            if model.id == excluding:
                continue
            if self.is_model_downloaded(model.id):
                return model.id
        return None
