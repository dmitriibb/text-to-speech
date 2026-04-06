import 'dart:async';

import 'audio_player_backend.dart';

enum PlaybackState { stopped, playing, paused }

class AudioService {
  AudioService({AudioPlayerBackend? player})
    : _player = player ?? JustAudioPlayerBackend() {
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (state.processingState == AudioProcessingState.completed) {
        _treatReadyAsStopped = true;
        _setState(PlaybackState.stopped);
      } else if (state.playing) {
        _treatReadyAsStopped = false;
        _setState(PlaybackState.playing);
      } else if (state.processingState == AudioProcessingState.ready) {
        _setState(
          _treatReadyAsStopped ? PlaybackState.stopped : PlaybackState.paused,
        );
      } else {
        _treatReadyAsStopped = true;
        _setState(PlaybackState.stopped);
      }
    });
    _positionSubscription = _player.positionStream.listen(_updatePosition);
    _durationSubscription = _player.durationStream.listen(_updateDuration);
  }

  final AudioPlayerBackend _player;
  final _stateController = StreamController<PlaybackState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _errorController = StreamController<Object>.broadcast();
  late final StreamSubscription<AudioPlayerSnapshot> _playerStateSubscription;
  late final StreamSubscription<Duration> _positionSubscription;
  late final StreamSubscription<Duration?> _durationSubscription;
  Future<void> _pendingOperation = Future<void>.value();
  bool _isDisposed = false;

  PlaybackState _state = PlaybackState.stopped;
  Duration _position = Duration.zero;
  Duration? _duration;
  String? _currentFilePath;
  bool _treatReadyAsStopped = true;

  Stream<PlaybackState> get onStateChanged => _stateController.stream;
  Stream<Duration> get onPositionChanged => _positionController.stream;
  Stream<Duration?> get onDurationChanged => _durationController.stream;
  Stream<Object> get onError => _errorController.stream;
  PlaybackState get state => _state;
  Duration get position => _position;
  Duration? get duration => _duration;

  void _setState(PlaybackState newState) {
    if (_state == newState) {
      return;
    }

    _state = newState;
    _stateController.add(newState);
  }

  Future<void> play(String filePath) async {
    await _queueOperation(() async {
      if (_currentFilePath != filePath) {
        _updatePosition(Duration.zero);
        _updateDuration(null);
        await _player.setFilePath(filePath);
        _currentFilePath = filePath;
      } else if (_player.processingState == AudioProcessingState.completed) {
        await _player.seek(Duration.zero);
      }

      _treatReadyAsStopped = false;
    });

    _startPlayback();
  }

  Future<void> stop() async {
    await _queueOperation(() async {
      if (_currentFilePath == null) {
        return;
      }

      _treatReadyAsStopped = true;
      await _player.pause();
      await _player.seek(Duration.zero);
      _updatePosition(Duration.zero);
      _setState(PlaybackState.stopped);
    });
  }

  Future<void> pause() async {
    await _queueOperation(() async {
      if (_currentFilePath == null) {
        return;
      }

      _treatReadyAsStopped = false;
      await _player.pause();
      _updatePosition(_player.position);
      _setState(PlaybackState.paused);
    });
  }

  Future<void> seek(Duration position) async {
    await _queueOperation(() async {
      final total = _duration ?? _player.duration;
      if (total == null || total.inMicroseconds <= 0) {
        return;
      }

      final keepPlaying = _state == PlaybackState.playing;
      _treatReadyAsStopped = _state == PlaybackState.stopped;
      final clamped = Duration(
        milliseconds: position.inMilliseconds.clamp(0, total.inMilliseconds),
      );
      await _player.seek(clamped);
      _updatePosition(clamped);
      if (!keepPlaying) {
        _setState(
          _treatReadyAsStopped ? PlaybackState.stopped : PlaybackState.paused,
        );
      }
    });
  }

  Future<void> dispose() async {
    _isDisposed = true;
    _currentFilePath = null;
    await _playerStateSubscription.cancel();
    await _positionSubscription.cancel();
    await _durationSubscription.cancel();
    await _player.dispose();
    await _errorController.close();
    await _stateController.close();
    await _positionController.close();
    await _durationController.close();
  }

  void _startPlayback() {
    unawaited(
      _player.play().catchError((Object error, StackTrace stackTrace) {
        if (_isDisposed) {
          return;
        }
        _treatReadyAsStopped = true;
        _setState(PlaybackState.stopped);
        _errorController.addError(error, stackTrace);
      }),
    );
  }

  Future<void> _queueOperation(Future<void> Function() action) {
    final operation = _pendingOperation.then((_) => action());
    _pendingOperation = operation.catchError((_) {});
    return operation;
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
