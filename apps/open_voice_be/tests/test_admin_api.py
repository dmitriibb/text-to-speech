from __future__ import annotations

import json
import tempfile
import unittest
import wave
from datetime import datetime, timezone
from pathlib import Path

from fastapi.testclient import TestClient

from src.config import Settings
from src.job_store import JobStore
from src.main import create_app
from src.model_manager import BackendModelManager
from src.models import JobRecord, JobStatus
from src.storage import StorageManager


class FakeEngine:
    is_ready = True
    initialization_error = None

    def generate_preview(self, **_: object) -> None:
        raise AssertionError('generate_preview should not be called in admin tests')


class AdminApiTests(unittest.TestCase):
    def setUp(self) -> None:
        self._temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self._temp_dir.name)
        (self.root / 'src' / 'static').mkdir(parents=True, exist_ok=True)
        (self.root / 'src' / 'static' / 'index.html').write_text(
            '<!doctype html><html><body>admin</body></html>',
            encoding='utf-8',
        )

        self.settings = Settings(
            app_name='open_voice_be',
            version='test',
            host='127.0.0.1',
            port=8008,
            root_dir=self.root,
            models_dir=self.root / 'models',
            storage_dir=self.root / 'storage',
            working_dir=self.root / 'storage' / 'working',
            jobs_dir=self.root / 'storage' / 'jobs',
            reference_audio_dir=self.root / 'storage' / 'reference_audio',
            results_dir=self.root / 'storage' / 'results',
            presets_dir=self.root / 'storage' / 'presets',
        )
        self.storage = StorageManager(self.settings)
        self.storage.ensure_directories()
        self.model_manager = BackendModelManager(self.settings, self.storage)
        self._stub_model_downloads()
        self.job_store = JobStore(
            storage=self.storage,
            engine=FakeEngine(),
            model_manager=self.model_manager,
        )
        self.client = TestClient(
            create_app(
                settings=self.settings,
                storage=self.storage,
                model_manager=self.model_manager,
                engine=FakeEngine(),
                job_store=self.job_store,
            )
        )

    def tearDown(self) -> None:
        self.client.close()
        self._temp_dir.cleanup()

    def test_models_can_be_downloaded_and_selected(self) -> None:
        response = self.client.get('/api/models')
        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertFalse(payload['runtime_assets_ready'])
        self.assertFalse(payload['models'][1]['downloaded'])

        download_response = self.client.post('/api/models/en-us/download')
        self.assertEqual(download_response.status_code, 200)
        self.assertTrue(download_response.json()['downloaded'])

        select_response = self.client.put(
            '/api/models/current',
            json={'model_id': 'en-us'},
        )
        self.assertEqual(select_response.status_code, 200)
        self.assertTrue(select_response.json()['is_current'])

        refreshed = self.client.get('/api/models').json()
        self.assertTrue(refreshed['runtime_assets_ready'])
        current_model = next(
            model for model in refreshed['models'] if model['id'] == 'en-us'
        )
        self.assertTrue(current_model['is_current'])

    def test_deleting_job_removes_saved_artifacts(self) -> None:
        job_id = 'job-test-delete'
        reference_path = self.storage.reference_audio_path(job_id)
        result_path = self.storage.result_audio_path(job_id)
        working_dir = self.storage.working_directory(job_id)
        job_path = self.storage.job_path(job_id)

        self._write_wav(reference_path)
        self._write_wav(result_path)
        working_dir.mkdir(parents=True, exist_ok=True)
        (working_dir / 'temp.txt').write_text('work', encoding='utf-8')

        job = JobRecord(
            job_id=job_id,
            job_type='clone',
            status=JobStatus.succeeded,
            text='hello world',
            language='en',
            speed=1.0,
            model_id='en-us',
            reference_audio_path=str(reference_path),
            result_audio_path=str(result_path),
            submitted_at=datetime.now(tz=timezone.utc),
        )
        job_path.write_text(
            json.dumps(job.model_dump(mode='json'), indent=2),
            encoding='utf-8',
        )

        list_response = self.client.get('/api/jobs')
        self.assertEqual(list_response.status_code, 200)
        listed_job = list_response.json()[0]
        referenced_kinds = {item['kind'] for item in listed_job['referenced_files']}
        self.assertEqual(
            referenced_kinds,
            {'job_record', 'reference_audio', 'working_directory', 'result_audio'},
        )

        delete_response = self.client.delete(f'/api/jobs/{job_id}')
        self.assertEqual(delete_response.status_code, 200)
        self.assertFalse(job_path.exists())
        self.assertFalse(reference_path.exists())
        self.assertFalse(result_path.exists())
        self.assertFalse(working_dir.exists())

    def test_model_delete_is_blocked_when_job_is_running(self) -> None:
        self.client.post('/api/models/en-us/download')
        job_id = 'job-test-running'
        reference_path = self.storage.reference_audio_path(job_id)
        self._write_wav(reference_path)

        job = JobRecord(
            job_id=job_id,
            job_type='clone',
            status=JobStatus.running,
            text='busy',
            language='en',
            speed=1.0,
            model_id='en-us',
            reference_audio_path=str(reference_path),
            submitted_at=datetime.now(tz=timezone.utc),
        )
        self.storage.job_path(job_id).write_text(
            json.dumps(job.model_dump(mode='json'), indent=2),
            encoding='utf-8',
        )

        response = self.client.delete('/api/models/en-us')
        self.assertEqual(response.status_code, 409)

    def _stub_model_downloads(self) -> None:
        def ensure_assets(assets) -> None:
            for asset in assets:
                destination = self.model_manager._bootstrapper.asset_destination(asset)
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_text('asset', encoding='utf-8')

        self.model_manager._bootstrapper.ensure_assets = ensure_assets

    def _write_wav(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        with wave.open(str(path), 'wb') as wav_file:
            wav_file.setnchannels(1)
            wav_file.setsampwidth(2)
            wav_file.setframerate(22050)
            wav_file.writeframes(b'\x00\x00' * 32)


if __name__ == '__main__':
    unittest.main()
