import 'dart:async';
import 'dart:io';

/// Playback state matching common player states.
enum PlaybackState { stopped, playing, paused }

/// Manages audio playback using system audio tools.
///
/// On Linux, uses `ffplay` (from ffmpeg) or `aplay` (ALSA).
/// On Windows, uses PowerShell media playback.
class AudioService {
  Process? _process;
  PlaybackState _state = PlaybackState.stopped;

  final _stateController = StreamController<PlaybackState>.broadcast();

  /// Stream of playback state changes.
  Stream<PlaybackState> get onStateChanged => _stateController.stream;

  /// Current playback state.
  PlaybackState get state => _state;

  void _setState(PlaybackState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  /// Plays audio from a local WAV file path.
  Future<void> play(String filePath) async {
    await stop();

    if (Platform.isLinux) {
      await _playLinux(filePath);
    } else if (Platform.isWindows) {
      await _playWindows(filePath);
    }
  }

  Future<void> _playLinux(String filePath) async {
    // Try ffplay first (most reliable, shows no window with -nodisp).
    try {
      _process = await Process.start(
        'ffplay',
        ['-nodisp', '-autoexit', '-loglevel', 'quiet', filePath],
      );
      _setState(PlaybackState.playing);
      _process!.exitCode.then((_) {
        if (_state == PlaybackState.playing) {
          _setState(PlaybackState.stopped);
        }
        _process = null;
      });
      return;
    } catch (_) {
      // ffplay not available, try aplay.
    }

    try {
      _process = await Process.start('aplay', [filePath]);
      _setState(PlaybackState.playing);
      _process!.exitCode.then((_) {
        if (_state == PlaybackState.playing) {
          _setState(PlaybackState.stopped);
        }
        _process = null;
      });
    } catch (e) {
      _setState(PlaybackState.stopped);
      throw Exception(
        'No audio player found. Install ffmpeg (for ffplay) or alsa-utils (for aplay).\n$e',
      );
    }
  }

  Future<void> _playWindows(String filePath) async {
    // Use PowerShell to play audio via Windows Media Player COM object.
    final script =
        '(New-Object Media.SoundPlayer "$filePath").PlaySync()';
    _process = await Process.start(
      'powershell',
      ['-NoProfile', '-Command', script],
    );
    _setState(PlaybackState.playing);
    _process!.exitCode.then((_) {
      if (_state == PlaybackState.playing) {
        _setState(PlaybackState.stopped);
      }
      _process = null;
    });
  }

  /// Stops playback.
  Future<void> stop() async {
    if (_process != null) {
      _process!.kill();
      _process = null;
    }
    _setState(PlaybackState.stopped);
  }

  /// Releases resources.
  void dispose() {
    stop();
    _stateController.close();
  }
}
