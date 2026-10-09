import asyncio
import threading
from pathlib import Path

from src.job_store import JobStore
from src.storage import StorageManager
from test_api import _settings


def test_queue_serializes_jobs_and_deleted_inflight_output_cannot_resurrect(tmp_path: Path):
    class Engine:
        device = device_backend = 'cpu'
        entered = threading.Event()
        release = threading.Event()
        active = maximum = calls = 0

        def generate(self, *, output_path, **kwargs):
            self.calls += 1
            self.active += 1
            self.maximum = max(self.maximum, self.active)
            self.entered.set()
            self.release.wait(timeout=5)
            output_path.write_bytes(b'wave')
            self.active -= 1
            return 48000

    async def scenario():
        settings = _settings(tmp_path)
        storage = StorageManager(settings)
        storage.ensure_directories()
        engine = Engine()
        jobs = JobStore(settings, storage, engine)
        args = dict(text='Алло?', language='ru', speed=1, settings={}, reference_audio=None)
        first = await jobs.create_job(**args)
        second = await jobs.create_job(**args)
        assert await asyncio.to_thread(engine.entered.wait, 5)
        assert await jobs.delete_job(first.job_id)
        assert await jobs.delete_job(second.job_id)
        engine.release.set()
        for _ in range(100):
            await asyncio.sleep(.01)
            if not storage.job_path(first.job_id).exists() and not storage.result_audio_path(first.job_id).exists():
                break
        assert engine.calls == engine.maximum == 1
        assert await jobs.get_job(first.job_id) is None
        assert not storage.result_audio_path(first.job_id).exists()
        assert not storage.job_path(first.job_id).exists()
        assert await jobs.get_job('../outside') is None

    asyncio.run(scenario())
