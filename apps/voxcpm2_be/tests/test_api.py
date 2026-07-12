from __future__ import annotations

import json
from pathlib import Path

from fastapi.testclient import TestClient

from src.config import Settings
from src.engine import VoxCPM2Engine
from src.main import create_app
from src.models import JobRecord, JobStatus
from src.storage import StorageManager


class FakeEngine:
    engine_name = 'voxcpm2'
    engine_display_name = 'VoxCPM2'
    is_ready = True
    is_loaded = False
    initialization_error = None
    device = 'cpu'
    device_backend = 'cpu'


class FakeJobStore:
    async def count_in_progress(self) -> int:
        return 0

    async def create_job(self, **kwargs):
        self.kwargs = kwargs
        return JobRecord(
            job_id='job-1', job_type='synthesis', status=JobStatus.queued,
            text=kwargs['text'], language=kwargs['language'], speed=kwargs['speed'],
            model_id='openbmb/VoxCPM2', settings=kwargs['settings'],
            submitted_at='2026-07-12T12:00:00Z',
        )

    async def get_job(self, job_id: str):
        return None


def _settings(tmp_path: Path) -> Settings:
    storage = tmp_path / 'storage'
    return Settings(
        app_name='voxcpm2_be', version='test', host='127.0.0.1', port=8011,
        model_id='openbmb/VoxCPM2', device='auto', load_denoiser=False,
        optimize=False, root_dir=tmp_path, storage_dir=storage,
        jobs_dir=storage / 'jobs', reference_audio_dir=storage / 'reference_audio',
        results_dir=storage / 'results',
    )


def test_health_uses_common_backend_shape(tmp_path: Path) -> None:
    settings = _settings(tmp_path)
    client = TestClient(create_app(settings=settings, storage=StorageManager(settings), engine=FakeEngine(), job_store=FakeJobStore()))
    payload = client.get('/health').json()
    assert payload['backend'] == 'voxcpm2_be'
    assert payload['engine'] == 'voxcpm2'
    assert payload['device_backend'] == 'cpu'
    assert 'model_settings' in payload['features']


def test_job_accepts_model_specific_settings(tmp_path: Path) -> None:
    settings = _settings(tmp_path)
    jobs = FakeJobStore()
    client = TestClient(create_app(settings=settings, storage=StorageManager(settings), engine=FakeEngine(), job_store=jobs))
    response = client.post('/jobs', data={
        'text': 'Guten Tag', 'language': 'de', 'speed': '1.0',
        'settings': json.dumps({'cfg_value': 2.5, 'inference_timesteps': 12, 'seed': 42}),
    })
    assert response.status_code == 202
    assert jobs.kwargs['settings']['inference_timesteps'] == 12


def test_job_rejects_non_object_settings(tmp_path: Path) -> None:
    settings = _settings(tmp_path)
    client = TestClient(create_app(settings=settings, storage=StorageManager(settings), engine=FakeEngine(), job_store=FakeJobStore()))
    response = client.post('/jobs', data={'text': 'Hallo', 'settings': '[]'})
    assert response.status_code == 400
    assert response.json()['detail'] == 'settings must be a JSON object.'


def test_auto_device_recognizes_rocm_as_gpu(tmp_path: Path) -> None:
    class FakeCuda:
        @staticmethod
        def is_available() -> bool:
            return True

    class FakeVersion:
        hip = '6.4'

    class FakeTorch:
        cuda = FakeCuda()
        version = FakeVersion()

    engine = VoxCPM2Engine(_settings(tmp_path))
    assert engine._resolve_device(FakeTorch()) == ('cuda', 'rocm')


def test_explicit_unavailable_gpu_falls_back_to_cpu(tmp_path: Path) -> None:
    class FakeCuda:
        @staticmethod
        def is_available() -> bool:
            return False

    class FakeVersion:
        hip = None

    class FakeMps:
        @staticmethod
        def is_available() -> bool:
            return False

    class FakeBackends:
        mps = FakeMps()

    class FakeTorch:
        cuda = FakeCuda()
        version = FakeVersion()
        backends = FakeBackends()

    configured = _settings(tmp_path)
    configured = Settings(**{**configured.__dict__, 'device': 'cuda'})
    engine = VoxCPM2Engine(configured)
    assert engine._resolve_device(FakeTorch()) == ('cpu', 'cpu-fallback')
