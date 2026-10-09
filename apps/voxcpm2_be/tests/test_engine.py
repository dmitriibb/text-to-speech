from concurrent.futures import ThreadPoolExecutor
from types import SimpleNamespace
import threading

import numpy as np
import soundfile as sf
import torch

from src.engine import VoxCPM2Engine


class PinnedApiModel:
    tts_model = SimpleNamespace(sample_rate=48000)

    # Match the pinned API: an accidental seed kwarg must fail this test.
    def generate(self, *, text, prompt_wav_path, prompt_text, reference_wav_path,
                 cfg_value, inference_timesteps, normalize, denoise, retry_badcase,
                 retry_badcase_max_times, retry_badcase_ratio_threshold):
        self.text = text
        self.normalize = normalize
        return torch.rand(480).numpy() * 0.2


def ready_engine(model):
    engine = VoxCPM2Engine()
    engine._initialized = True
    engine._torch = torch
    engine._model = model
    engine._soundfile = sf
    return engine


def test_seed_is_repeatable_and_restores_rng_with_pinned_api(tmp_path):
    model = PinnedApiModel()
    engine = ready_engine(model)
    before = torch.get_rng_state().clone()
    for name in ('first', 'second'):
        engine.generate(text='Ещё: привет, Алёша!', settings={'seed': 42},
                        reference_audio_path=None, output_path=tmp_path / f'{name}.wav')
    assert torch.equal(before, torch.get_rng_state())
    assert model.text == 'Ещё: привет, Алёша!'
    assert model.normalize is False
    first, rate = sf.read(tmp_path / 'first.wav')
    second, _ = sf.read(tmp_path / 'second.wav')
    assert rate == 48000
    np.testing.assert_array_equal(first, second)


def test_inference_is_serialized_and_lock_released_after_failure(tmp_path):
    entered = threading.Event()
    release = threading.Event()
    second_attempted = threading.Event()
    second_entered = threading.Event()

    class BlockingModel(PinnedApiModel):
        def generate(self, **kwargs):
            if kwargs['text'] == 'first':
                entered.set()
                assert release.wait(5)
                raise RuntimeError('intentional inference failure')
            second_entered.set()
            return super().generate(**kwargs)

    engine = ready_engine(BlockingModel())

    def run(text):
        if text == 'second':
            second_attempted.set()
        return engine.generate(text=text, settings={}, reference_audio_path=None,
                               output_path=tmp_path / f'{text}.wav')

    with ThreadPoolExecutor(max_workers=2) as pool:
        first = pool.submit(run, 'first')
        assert entered.wait(5)
        second = pool.submit(run, 'second')
        try:
            assert second_attempted.wait(5)
            assert not second_entered.wait(0.1)
        finally:
            release.set()
        try:
            first.result(timeout=5)
        except RuntimeError as error:
            assert str(error) == 'intentional inference failure'
        else:
            raise AssertionError('First inference should fail')
        assert second.result(timeout=5) == 48000
    assert second_entered.is_set()
