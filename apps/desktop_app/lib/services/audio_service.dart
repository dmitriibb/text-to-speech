import 'dart:async';
import 'dart:ffi' as ffi;
import 'dart:io';
import 'dart:typed_data';

// ignore: depend_on_referenced_packages
import 'package:ffi/ffi.dart';

/// Playback state matching common player states.
enum PlaybackState { stopped, playing, paused }

/// Lightweight Windows playback mode used by the desktop audio service.
enum WindowsAudioMode { stopped, playing, paused }

/// Windows audio control contract used for the MCI-backed player and tests.
abstract class WindowsAudioController {
  void load(String filePath);
  Duration? duration();
  Duration position();
  WindowsAudioMode mode();
  void play({Duration from = Duration.zero});
  void resume();
  void pause();
  void stop();
  void seek(Duration position);
  void close();
}

class AudioService {
  AudioService({WindowsAudioController? windowsController})
    : _windowsController =
          windowsController ??
          (Platform.isWindows ? _WindowsMciAudioController() : null);

  final WindowsAudioController? _windowsController;
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
      final windowsController = _windowsController;
      if (windowsController != null) {
        _playOnWindows(windowsController, filePath);
        return;
      }

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
      final windowsController = _windowsController;
      if (windowsController != null) {
        _playbackGeneration++;
        _stopProgressTimer();
        if (_currentFilePath != null) {
          windowsController.stop();
          windowsController.seek(Duration.zero);
        }
        _updatePosition(Duration.zero);
        _setState(PlaybackState.stopped);
        return;
      }

      await _stopCurrentProcess(resetPosition: true);
      _setState(PlaybackState.stopped);
    });
  }

  Future<void> pause() {
    return _queueOperation(() async {
      final windowsController = _windowsController;
      if (windowsController != null) {
        if (_state != PlaybackState.playing || _currentFilePath == null) {
          return;
        }

        _playbackGeneration++;
        _stopProgressTimer();
        windowsController.pause();
        _updatePosition(windowsController.position());
        _setState(PlaybackState.paused);
        return;
      }

      if (_state != PlaybackState.playing) {
        return;
      }

      final pausedPosition = _currentPlaybackPosition();
      await _stopCurrentProcess(resetPosition: false);
      _updatePosition(pausedPosition);
      _setState(PlaybackState.paused);
    });
  }

  Future<void> seek(Duration position) {
    return _queueOperation(() async {
      final windowsController = _windowsController;
      if (windowsController != null) {
        final total = _duration ?? windowsController.duration();
        if (total == null || total.inMicroseconds <= 0 || _currentFilePath == null) {
          return;
        }

        final clamped = Duration(
          milliseconds: position.inMilliseconds.clamp(0, total.inMilliseconds),
        );
        windowsController.seek(clamped);
        _updatePosition(clamped);

        if (_state == PlaybackState.playing) {
          windowsController.play(from: clamped);
          _startWindowsProgressTimer(windowsController);
        } else if (_state == PlaybackState.paused) {
          _setState(PlaybackState.paused);
        } else {
          _setState(PlaybackState.stopped);
        }
        return;
      }

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

  Duration _currentPlaybackPosition() {
    if (_startedAt == null) {
      return _position;
    }

    final elapsed = DateTime.now().difference(_startedAt!);
    final nextPosition = _startPosition + elapsed;
    final total = _duration;
    if (total != null && nextPosition.compareTo(total) >= 0) {
      return total;
    }

    return nextPosition;
  }

  Future<void> _disposeInternal() async {
    final windowsController = _windowsController;
    if (windowsController != null) {
      _playbackGeneration++;
      _stopProgressTimer();
      windowsController.close();
    } else {
      await _stopCurrentProcess(resetPosition: false);
    }
    _currentFilePath = null;
    await _stateController.close();
    await _positionController.close();
    await _durationController.close();
  }

  void _playOnWindows(
    WindowsAudioController windowsController,
    String filePath,
  ) {
    final isNewFile = _currentFilePath != filePath;
    if (isNewFile) {
      windowsController.load(filePath);
      _currentFilePath = filePath;
      _updateDuration(windowsController.duration());
      _updatePosition(Duration.zero);
    } else if (_hasReachedEnd) {
      windowsController.seek(Duration.zero);
      _updatePosition(Duration.zero);
    }

    if (!isNewFile &&
        _state == PlaybackState.paused &&
        !_hasReachedEnd) {
      windowsController.resume();
    } else {
      windowsController.play(from: _position);
    }

    _startWindowsProgressTimer(windowsController);
    _setState(PlaybackState.playing);
  }

  void _startWindowsProgressTimer(WindowsAudioController windowsController) {
    final generation = ++_playbackGeneration;
    _stopProgressTimer();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (_playbackGeneration != generation) {
        return;
      }

      final total = windowsController.duration();
      if (total != null) {
        _updateDuration(total);
      }

      final nextPosition = _clampPosition(
        windowsController.position(),
        total,
      );
      _updatePosition(nextPosition);

      final mode = windowsController.mode();
      if (mode == WindowsAudioMode.playing) {
        return;
      }

      _stopProgressTimer();
      if (_playbackGeneration != generation) {
        return;
      }

      if (mode == WindowsAudioMode.paused) {
        _setState(PlaybackState.paused);
        return;
      }

      if (total != null) {
        _updatePosition(total);
      }
      _setState(PlaybackState.stopped);
    });
  }

  Duration _clampPosition(Duration position, Duration? total) {
    if (total == null || position.compareTo(total) <= 0) {
      return position;
    }
    return total;
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

    unawaited(
      process.exitCode.then((_) {
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
      }),
    );
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

      _updatePosition(_currentPlaybackPosition());
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
    throw UnsupportedError(
      'Desktop playback is only implemented for Linux and Windows.',
    );
  }

  Future<Process> _startLinuxProcess(String filePath, Duration from) async {
    try {
      return await Process.start('ffplay', [
        '-nodisp',
        '-autoexit',
        '-loglevel',
        'quiet',
        if (from.inMicroseconds > 0) ...['-ss', _formatSeconds(from)],
        filePath,
      ]);
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

        if (chunkType == 'fmt ' &&
            chunkSize >= 16 &&
            chunkDataOffset + 16 <= bytes.length) {
          byteRate = data.getUint32(chunkDataOffset + 8, Endian.little);
        } else if (chunkType == 'data') {
          dataSize = chunkSize;
          break;
        }

        offset = chunkDataOffset + chunkSize + (chunkSize.isOdd ? 1 : 0);
      }

      if (byteRate == null ||
          byteRate <= 0 ||
          dataSize == null ||
          dataSize < 0) {
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

class _WindowsMciAudioController implements WindowsAudioController {
  _WindowsMciAudioController({ffi.DynamicLibrary? library})
    : this._(library ?? ffi.DynamicLibrary.open('winmm.dll'));

  _WindowsMciAudioController._(ffi.DynamicLibrary library)
    : _mciSendString =
          library.lookupFunction<_MciSendStringNative, _MciSendStringDart>(
            'mciSendStringW',
          ),
      _mciGetErrorString = library.lookupFunction<
        _MciGetErrorStringNative,
        _MciGetErrorStringDart
      >('mciGetErrorStringW');

  static const String _alias = 'tts_audio_output';

  final _MciSendStringDart _mciSendString;
  final _MciGetErrorStringDart _mciGetErrorString;

  String? _loadedFilePath;

  @override
  void load(String filePath) {
    final normalizedPath = File(filePath).absolute.path;
    if (_loadedFilePath == normalizedPath) {
      return;
    }

    close();
    _sendCommand(
      'open "${_escapeFilePath(normalizedPath)}" type waveaudio alias $_alias',
    );
    _sendCommand('set $_alias time format milliseconds');
    _loadedFilePath = normalizedPath;
  }

  @override
  Duration? duration() {
    if (_loadedFilePath == null) {
      return null;
    }

    return Duration(milliseconds: _readMilliseconds('status $_alias length'));
  }

  @override
  Duration position() {
    if (_loadedFilePath == null) {
      return Duration.zero;
    }

    return Duration(milliseconds: _readMilliseconds('status $_alias position'));
  }

  @override
  WindowsAudioMode mode() {
    if (_loadedFilePath == null) {
      return WindowsAudioMode.stopped;
    }

    final rawMode = _sendQuery('status $_alias mode').toLowerCase();
    switch (rawMode) {
      case 'playing':
        return WindowsAudioMode.playing;
      case 'paused':
        return WindowsAudioMode.paused;
      default:
        return WindowsAudioMode.stopped;
    }
  }

  @override
  void play({Duration from = Duration.zero}) {
    if (_loadedFilePath == null) {
      return;
    }

    final fromMillis = from.inMilliseconds < 0 ? 0 : from.inMilliseconds;
    _sendCommand('play $_alias from $fromMillis');
  }

  @override
  void resume() {
    if (_loadedFilePath == null) {
      return;
    }

    _sendCommand('resume $_alias');
  }

  @override
  void pause() {
    if (_loadedFilePath == null) {
      return;
    }

    _sendCommand('pause $_alias');
  }

  @override
  void stop() {
    if (_loadedFilePath == null) {
      return;
    }

    _sendCommand('stop $_alias');
  }

  @override
  void seek(Duration position) {
    if (_loadedFilePath == null) {
      return;
    }

    final millis = position.inMilliseconds < 0 ? 0 : position.inMilliseconds;
    _sendCommand('seek $_alias to $millis');
  }

  @override
  void close() {
    if (_loadedFilePath == null) {
      return;
    }

    try {
      _sendCommand('close $_alias');
    } catch (_) {
      // Ignore close failures while replacing or disposing the player.
    } finally {
      _loadedFilePath = null;
    }
  }

  void _sendCommand(String command) {
    _send(command, expectsResponse: false);
  }

  String _sendQuery(String command) {
    return _send(command, expectsResponse: true);
  }

  String _send(String command, {required bool expectsResponse}) {
    final commandPtr = command.toNativeUtf16();
    final responseLength = expectsResponse ? 256 : 0;
    final responsePtr = calloc<ffi.Uint16>(responseLength > 0 ? responseLength : 1);

    try {
      final result = _mciSendString(
        commandPtr,
        responsePtr.cast<Utf16>(),
        responseLength,
        0,
      );
      if (result != 0) {
        throw StateError(
          'Windows audio command failed: $command (${_describeError(result)})',
        );
      }

      if (!expectsResponse) {
        return '';
      }

      return responsePtr.cast<Utf16>().toDartString();
    } finally {
      calloc.free(commandPtr);
      calloc.free(responsePtr);
    }
  }

  int _readMilliseconds(String command) {
    final rawValue = _sendQuery(command).trim();
    return int.tryParse(rawValue) ?? 0;
  }

  String _describeError(int code) {
    final bufferPtr = calloc<ffi.Uint16>(256);
    try {
      final success = _mciGetErrorString(code, bufferPtr.cast<Utf16>(), 256);
      if (success == 0) {
        return 'MCI error $code';
      }

      return bufferPtr.cast<Utf16>().toDartString();
    } finally {
      calloc.free(bufferPtr);
    }
  }

  String _escapeFilePath(String filePath) {
    return filePath.replaceAll('"', '""');
  }
}

typedef _MciSendStringNative =
    ffi.Int32 Function(
      ffi.Pointer<Utf16> command,
      ffi.Pointer<Utf16> returnValue,
      ffi.Uint32 returnLength,
      ffi.IntPtr callbackWindow,
    );
typedef _MciSendStringDart =
    int Function(
      ffi.Pointer<Utf16> command,
      ffi.Pointer<Utf16> returnValue,
      int returnLength,
      int callbackWindow,
    );

typedef _MciGetErrorStringNative =
    ffi.Int32 Function(
      ffi.Uint32 errorCode,
      ffi.Pointer<Utf16> errorText,
      ffi.Uint32 errorTextLength,
    );
typedef _MciGetErrorStringDart =
    int Function(
      int errorCode,
      ffi.Pointer<Utf16> errorText,
      int errorTextLength,
    );
