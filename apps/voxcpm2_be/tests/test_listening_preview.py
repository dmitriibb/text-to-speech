import json
from pathlib import Path
import sys

import numpy as np
import pytest
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'tools/benchmark'))
from evaluate_russian_dialogue import inspect_wav, sha256
from prepare_russian_listening_preview import prepare


def inputs(tmp_path):
    fixture = tmp_path / 'fixture.json'
    fixture.write_text(json.dumps({'scripts': [{'id': 'test', 'turns': [{'id': 'one'}, {'id': 'two'}]}]}))
    time = np.arange(4800) / 48000
    turns = []
    for name, frequency in [('one', 1000), ('two', 6000)]:
        path = tmp_path / f'{name}.wav'
        sf.write(path, 0.95 * np.sin(2 * np.pi * frequency * time), 48000, subtype='PCM_16')
        turns.append({'id': name, 'status': 'succeeded', 'audio': inspect_wav(path)})
    report = {'status': 'awaiting_listening', 'fixture_sha256': sha256(fixture),
              'script': 'test', 'turn_limit': 0, 'turns': turns}
    report_path = tmp_path / 'report.json'
    report_path.write_text(json.dumps(report))
    return fixture, report_path, report


def test_preview_keeps_order_duration_silence_and_limits_peaks(tmp_path):
    fixture, report_path, _ = inputs(tmp_path)
    output = tmp_path / 'preview'
    manifest = prepare(report_path, output, fixture)
    clean, rate = sf.read(output / 'evaluation-clean.wav')
    phone, _ = sf.read(output / 'evaluation-phone-preview.wav')
    assert rate == 48000
    assert len(clean) == 4800 * 2 + 12000
    assert len(phone) == len(clean)
    assert manifest['turn_ids'] == ['one', 'two']
    assert np.max(np.abs(clean)) <= 10 ** (-1 / 20) + 1 / 32768
    assert np.max(np.abs(phone)) <= 10 ** (-1 / 20) + 1 / 32768
    np.testing.assert_array_equal(clean[4800:16800], 0)
    assert np.sqrt(np.mean(phone[17800:] ** 2)) < 0.1 * np.sqrt(np.mean(clean[17800:] ** 2))
    assert np.sqrt(np.mean(phone[1000:4800] ** 2)) > 0.8 * np.sqrt(np.mean(clean[1000:4800] ** 2))
    assert manifest['listening_status'] == 'pending'
    with pytest.raises(FileExistsError):
        prepare(report_path, output, fixture)


@pytest.mark.parametrize('fault', ['missing', 'changed', 'reordered'])
def test_preview_rejects_incomplete_stale_or_reordered_sources(tmp_path, fault):
    fixture, report_path, report = inputs(tmp_path)
    if fault == 'missing':
        report['turns'].pop()
    elif fault == 'reordered':
        report['turns'].reverse()
    else:
        (tmp_path / 'one.wav').write_bytes(b'changed')
    report_path.write_text(json.dumps(report))
    output = tmp_path / 'preview'
    with pytest.raises(ValueError):
        prepare(report_path, output, fixture)
    assert not output.exists()
