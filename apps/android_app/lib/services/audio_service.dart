import 'dart:async';

import 'package:just_audio/just_audio.dart';

enum PlaybackState { stopped, playing, paused }

class AudioService {
  AudioService() {
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _treatReadyAsStopped = true;
        _setState(PlaybackState.stopped);
      } else if (state.playing) {
        _treatReadyAsStopped = false;
        _setState(PlaybackState.playing);
      } else if (state.processingState == ProcessingState.ready) {
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

  final AudioPlayer _player = AudioPlayer();
  final _stateController = StreamController<PlaybackState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  late final StreamSubscription<PlayerState> _playerStateSubscription;
  late final StreamSubscription<Duration> _positionSubscription;
  late final StreamSubscription<Duration?> _durationSubscription;
  Future<void> _pendingOperation = Future<void>.value();

  PlaybackState _state = PlaybackState.stopped;
  Duration _position = Duration.zero;
  Duration? _duration;
  String? _currentFilePath;
  bool _treatReadyAsStopped = true;

  Stream<PlaybackState> get onStateChanged => _stateController.stream;
  Stream<Duration> get onPositionChanged => _positionController.stream;
  Stream<Duration?> get onDurationChanged => _durationController.stream;
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
      } else if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }

      _treatReadyAsStopped = false;
      await _player.play();
    });
  }

  Future<void> stop() async {
    await _queueOperation(() async {
      _treatReadyAsStopped = true;
      await _player.pause();
      await _player.seek(Duration.zero);
      _updatePosition(Duration.zero);
      _setState(PlaybackState.stopped);
    });
  }

  Future<void> seek(Duration position) async {
    await _queueOperation(() async {
      final total = _duration ?? _player.duration;
      if (total == null || total.inMicroseconds <= 0) {
        return;
      }

      _treatReadyAsStopped = _state != PlaybackState.playing;
      final clamped = Duration(
        milliseconds: position.inMilliseconds.clamp(0, total.inMilliseconds),
      );
      await _player.seek(clamped);
      _updatePosition(clamped);
    });
  }

  Future<void> dispose() async {
    _currentFilePath = null;
    await _playerStateSubscription.cancel();
    await _positionSubscription.cancel();
    await _durationSubscription.cancel();
    await _player.dispose();
    await _stateController.close();
    await _positionController.close();
    await _durationController.close();
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
