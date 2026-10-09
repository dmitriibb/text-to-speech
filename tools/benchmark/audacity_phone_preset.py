"""Apply the saved Audacity 3.7.7 macro over mod-script-pipe; preserve clean input.

Run against an empty Audacity project. This is a separate postprocessing tool,
not a shared app dependency. No noise, codec or per-turn normalization is added.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import queue
import sys
import threading

ROOT = Path(__file__).resolve().parents[2]
MACRO = ROOT / 'docs/presets/russian-phone-call.txt'


class AudacityPipe:
    def __init__(self):
        windows = sys.platform == 'win32'
        to_name = r'\\.\pipe\ToSrvPipe' if windows else f'/tmp/audacity_script_pipe.to.{os.getuid()}'
        from_name = r'\\.\pipe\FromSrvPipe' if windows else f'/tmp/audacity_script_pipe.from.{os.getuid()}'
        self.end = '\r\n\0' if windows else '\n'
        self.write = open(to_name, 'w', encoding='utf-8', newline='')
        self.read = open(from_name, 'rt', encoding='utf-8')
        self.responses = queue.Queue()
        def reader():
            try:
                result = ''
                for line in self.read:
                    result += line
                    if line == '\n' and result.strip():
                        self.responses.put(result)
                        result = ''
            except Exception as error:
                self.responses.put(error)
        threading.Thread(target=reader, daemon=True).start()

    def command(self, command: str) -> str:
        self.write.write(command + self.end)
        self.write.flush()
        response = self.responses.get(timeout=60)
        if isinstance(response, Exception):
            raise response
        if 'BatchCommand finished: OK' not in response:
            raise RuntimeError(f'{command}: {response}')
        return response


def quoted(path: Path) -> str:
    value = path.resolve().as_posix()
    if '"' in value or '\n' in value or '\r' in value:
        raise ValueError('Path cannot contain quotes or newlines.')
    return f'"{value}"'


def apply(clean: Path, output: Path) -> dict:
    if not clean.is_file() or clean.resolve() == output.resolve() or output.exists():
        raise ValueError('Use an existing clean WAV and a new, separate output path.')
    output.parent.mkdir(parents=True, exist_ok=True)
    original_hash = hashlib.sha256(clean.read_bytes()).hexdigest()
    pipe = AudacityPipe()
    pipe.command(f'Import2: Filename={quoted(clean)}')
    for command in MACRO.read_text(encoding='utf-8').splitlines():
        if command.strip():
            pipe.command(command)
    pipe.command('SetProject: Rate=16000')
    pipe.command(f'Export2: Filename={quoted(output)} NumChannels=1')
    project = output.with_suffix('.aup3')
    pipe.command(f'SaveProject2: Filename={quoted(project)}')
    pipe.command('Close:')
    pipe.command(f'OpenProject2: Filename={quoted(project)}')
    reopened = output.with_name(output.stem + '-reopened.wav')
    pipe.command(f'Export2: Filename={quoted(reopened)} NumChannels=1')
    pipe.command('Close:')
    if hashlib.sha256(clean.read_bytes()).hexdigest() != original_hash:
        raise RuntimeError('Clean input changed.')
    import soundfile as sf
    import numpy as np
    audio, rate = sf.read(output, dtype='float64')
    again, second_rate = sf.read(reopened, dtype='float64')
    info = sf.info(output)
    if info.channels != 1 or rate != 16000 or info.subtype != 'PCM_16' or not np.isfinite(audio).all():
        raise RuntimeError('Unexpected phone WAV format.')
    if second_rate != rate or audio.shape != again.shape or np.max(np.abs(audio - again)) > 2 / 32768:
        raise RuntimeError('Reopened project did not reproduce exported samples.')
    if np.max(np.abs(audio)) > 10 ** (-1 / 20) + 2 / 32768:
        raise RuntimeError('Phone output exceeds -1 dBFS ceiling.')
    report = {'audacity_version': '3.7.7', 'clean_sha256': original_hash,
        'preset_sha256': hashlib.sha256(MACRO.read_bytes()).hexdigest(),
        'sample_rate': rate, 'channels': info.channels, 'subtype': info.subtype,
        'duration_seconds': len(audio) / rate, 'reopened_sample_difference': float(np.max(np.abs(audio - again))),
        'status': 'technical_checks_passed_awaiting_user_listening', 'output': str(output.resolve())}
    output.with_suffix('.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('clean', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    print(json.dumps(apply(args.clean, args.output), indent=2))
