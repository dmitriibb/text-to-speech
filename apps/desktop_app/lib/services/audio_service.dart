import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Playback state matching common player states.
enum PlaybackState { stopped, playing, paused }

class AudioService {
  Process? _process;
  Timer? _progressTimer;
  DateTime? _startedAt;
  Duration _startPosition = Duration.zero;
  int _playbackGeneration = 0;

  PlaybackState _state = PlaybackState.stopped;
  Duration _position = Duration.zero;
  Duration? _duration;
  String? _currentFilePath;
  Future<void> _pendingOperation = Future<void>.value();

  final _stateController = StreamController<PlaybackState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();

  Stream<PlaybackState> get onStateChanged => _stateController.stream;
  Stream<Duration> get onPositionChanged => _positionController.stream;
  Stream<Duration?> get onDurationChanged => _durationController.stream;

  PlaybackState get state => _state;
  Duration get position => _position;
  Duration? get duration => _duration;

  Future<void> play(String filePath) {
    return _queueOperation(() async {
      if (_currentFilePath != filePath) {
        _currentFilePath = filePath;
        _updateDuration(await _readWavDuration(filePath));
        _updatePosition(Duration.zero);
      } else if (_hasReachedEnd) {
        _updatePosition(Duration.zero);
      }

      await _restartPlayback(from: _position);
    });
  }

  Future<void> stop() {
    return _queueOperation(() async {
      await _stopCurrentProcess(resetPosition: true);
      _setState(PlaybackState.stopped);
    });
  }

  Future<void> seek(Duration position) {
    return _queueOperation(() async {
      final total = _duration;
      if (total == null || total.inMicroseconds <= 0) {
        return;
      }

      final clamped = Duration(
        milliseconds: position.inMilliseconds.clamp(0, total.inMilliseconds),
      );
      _updatePosition(clamped);

      if (_state == PlaybackState.playing && _currentFilePath != null) {
        await _restartPlayback(from: clamped);
      } else {
        _setState(PlaybackState.stopped);
      }
    });
  }

  void dispose() {
    unawaited(_disposeInternal());
  }

  bool get _hasReachedEnd =>
      _duration != null && _position.compareTo(_duration!) >= 0;

  Future<void> _disposeInternal() async {
    await _stopCurrentProcess(resetPosition: false);
    _currentFilePath = null;
    await _stateController.close();
    await _positionController.close();
    await _durationController.close();
  }

  Future<void> _restartPlayback({required Duration from}) async {
    final filePath = _currentFilePath;
    if (filePath == null) {
      return;
    }

    await _stopCurrentProcess(resetPosition: false);

    final process = await _startProcess(filePath, from);
    final generation = ++_playbackGeneration;
    _process = process;
    _startPosition = from;
    _startedAt = DateTime.now();
    _startProgressTimer(generation);
    _setState(PlaybackState.playing);

    unawaited(process.exitCode.then((_) {
      if (_playbackGeneration != generation) {
        return;
      }

      _process = null;
      _startedAt = null;
      _stopProgressTimer();

      final total = _duration;
      if (total != null && _position.compareTo(total) < 0) {
        _updatePosition(total);
      }

      _setState(PlaybackState.stopped);
    }));
  }

  Future<void> _stopCurrentProcess({required bool resetPosition}) async {
    _playbackGeneration++;
    _startedAt = null;
    _stopProgressTimer();

    final process = _process;
    _process = null;
    if (process != null) {
      process.kill(ProcessSignal.sigkill);
      try {
        await process.exitCode.timeout(const Duration(milliseconds: 500));
      } catch (_) {}
    }

    if (resetPosition) {
      _updatePosition(Duration.zero);
    }
  }

  void _startProgressTimer(int generation) {
    _stopProgressTimer();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_playbackGeneration != generation || _startedAt == null) {
        return;
      }

      final elapsed = DateTime.now().difference(_startedAt!);
      final nextPosition = _startPosition + elapsed;
      final total = _duration;
      if (total != null && nextPosition.compareTo(total) >= 0) {
        _updatePosition(total);
      } else {
        _updatePosition(nextPosition);
      }
    });
  }

  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  Future<Process> _startProcess(String filePath, Duration from) async {
    if (Platform.isLinux) {
      return _startLinuxProcess(filePath, from);
    }
    if (Platform.isWindows) {
      return _startWindowsProcess(filePath, from);
    }
    throw UnsupportedError('Desktop playback is only implemented for Linux and Windows.');
  }

  Future<Process> _startLinuxProcess(String filePath, Duration from) async {
    try {
      return await Process.start(
        'ffplay',
        [
          '-nodisp',
          '-autoexit',
          '-loglevel',
          'quiet',
          if (from.inMicroseconds > 0) ...['-ss', _formatSeconds(from)],
          filePath,
        ],
      );
    } catch (_) {
      if (from.inMicroseconds > 0) {
        throw Exception('Seeking on Linux requires ffplay from ffmpeg.');
      }

      try {
        return await Process.start('aplay', [filePath]);
      } catch (error) {
        throw Exception(
          'No supported audio player found. Install ffmpeg (for ffplay) or alsa-utils (for aplay).\n$error',
        );
      }
    }
  }

  Future<Process> _startWindowsProcess(String filePath, Duration from) async {
    try {
      return await Process.start(
        'ffplay',
        [
          '-nodisp',
          '-autoexit',
          '-loglevel',
          'quiet',
          if (from.inMicroseconds > 0) ...['-ss', _formatSeconds(from)],
          filePath,
        ],
      );
    } catch (_) {
      if (from.inMicroseconds > 0) {
        throw Exception('Seeking on Windows requires ffplay from ffmpeg.');
      }

      final escapedPath = filePath.replaceAll("'", "''");
      final script =
          "(New-Object Media.SoundPlayer '$escapedPath').PlaySync()";
      return Process.start(
        'powershell',
        ['-NoProfile', '-Command', script],
      );
    }
  }

  String _formatSeconds(Duration value) {
    return (value.inMilliseconds / 1000).toStringAsFixed(3);
  }

  Future<Duration?> _readWavDuration(String filePath) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      if (bytes.length < 44) {
        return null;
      }

      final data = ByteData.sublistView(bytes);
      if (_chunkId(bytes, 0) != 'RIFF' || _chunkId(bytes, 8) != 'WAVE') {
        return null;
      }

      int? byteRate;
      int? dataSize;
      var offset = 12;

      while (offset + 8 <= bytes.length) {
        final chunkType = _chunkId(bytes, offset);
        final chunkSize = data.getUint32(offset + 4, Endian.little);
        final chunkDataOffset = offset + 8;

        if (chunkType == 'fmt ' && chunkSize >= 16 && chunkDataOffset + 16 <= bytes.length) {
          byteRate = data.getUint32(chunkDataOffset + 8, Endian.little);
        } else if (chunkType == 'data') {
          dataSize = chunkSize;
          break;
        }

        offset = chunkDataOffset + chunkSize + (chunkSize.isOdd ? 1 : 0);
      }

      if (byteRate == null || byteRate <= 0 || dataSize == null || dataSize < 0) {
        return null;
      }

      return Duration(
        microseconds: dataSize * Duration.microsecondsPerSecond ~/ byteRate,
      );
    } catch (_) {
      return null;
    }
  }

  String _chunkId(Uint8List bytes, int offset) {
    return String.fromCharCodes(bytes.sublist(offset, offset + 4));
  }

  Future<void> _queueOperation(Future<void> Function() action) {
    final operation = _pendingOperation.then((_) => action());
    _pendingOperation = operation.catchError((_) {});
    return operation;
  }

  void _setState(PlaybackState newState) {
    if (_state == newState) {
      return;
    }

    _state = newState;
    _stateController.add(newState);
  }

  void _updatePosition(Duration position) {
    if (_position == position) {
      return;
    }

    _position = position;
    _positionController.add(position);
  }

  void _updateDuration(Duration? duration) {
    if (_duration == duration) {
      return;
    }

    _duration = duration;
    _durationController.add(duration);
  }
}
