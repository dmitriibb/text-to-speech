from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from fastapi.testclient import TestClient

from src.config import Settings
from src.job_store import JobStore
from src.main import create_app
from src.storage import StorageManager


class FakeEngine:
    is_ready = True
    initialization_error = None
    engine_display_name = 'OmniVoice Multilingual'

    def list_voice_definitions(self):
        from src.engine import VOICE_DEFINITIONS

        return list(VOICE_DEFINITIONS)

    def get_voice_definition(self, voice_id: str | None):
        from src.engine import VOICE_DEFINITIONS

        if voice_id is None:
            return VOICE_DEFINITIONS[0]
        for voice in VOICE_DEFINITIONS:
            if voice.id == voice_id:
                return voice
        raise ValueError(f'Unknown OmniVoice voice: {voice_id}')

    def generate_preview(self, **_: object) -> None:
        raise AssertionError('generate_preview should not run in API tests')


class OmniVoiceApiTests(unittest.TestCase):
    def setUp(self) -> None:
        self._temp_dir = tempfile.TemporaryDirectory()
        self.root = Path(self._temp_dir.name)
        self.settings = Settings(
            app_name='omnivoice_be',
            version='test',
            host='127.0.0.1',
            port=8010,
            root_dir=self.root,
            storage_dir=self.root / 'storage',
            working_dir=self.root / 'storage' / 'working',
            jobs_dir=self.root / 'storage' / 'jobs',
            reference_audio_dir=self.root / 'storage' / 'reference_audio',
            results_dir=self.root / 'storage' / 'results',
        )
        self.storage = StorageManager(self.settings)
        self.storage.ensure_directories()
        self.engine = FakeEngine()
        self.job_store = JobStore(storage=self.storage, engine=self.engine)
        self.client = TestClient(
            create_app(
                settings=self.settings,
                storage=self.storage,
                engine=self.engine,
                job_store=self.job_store,
            )
        )

    def tearDown(self) -> None:
        self.client.close()
        self._temp_dir.cleanup()

    def test_health_reports_supported_modes_and_features(self) -> None:
        response = self.client.get('/health')
        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload['engine_display_name'], 'OmniVoice Multilingual')
        self.assertEqual(payload['voices_endpoint'], '/voices')
        self.assertIn('voice_design', payload['features'])
        self.assertEqual(payload['supported_job_modes'], ['clone', 'design', 'auto'])

    def test_voices_lists_clone_design_and_auto_options(self) -> None:
        response = self.client.get('/voices')
        self.assertEqual(response.status_code, 200)
        payload = response.json()
        voice_ids = {voice['id'] for voice in payload}
        self.assertIn('clone-reference', voice_ids)
        self.assertIn('auto-random', voice_ids)
        self.assertIn('narrator-female', voice_ids)

    def test_design_job_can_be_submitted_without_reference_audio(self) -> None:
        response = self.client.post(
            '/jobs',
            data={
                'text': 'hello there',
                'voice_id': 'narrator-female',
                'language': 'en',
                'instruct': 'female, moderate pitch',
                'num_step': '16',
            },
        )
        self.assertEqual(response.status_code, 202)

    def test_clone_job_requires_reference_audio(self) -> None:
        response = self.client.post(
            '/jobs',
            data={
                'text': 'hello there',
                'voice_id': 'clone-reference',
                'language': 'en',
            },
        )
        self.assertEqual(response.status_code, 400)
        self.assertEqual(
            response.json()['detail'],
            'Reference audio is required for the selected OmniVoice voice.',
        )


if __name__ == '__main__':
    unittest.main()
