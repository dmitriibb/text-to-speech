import 'dart:async';

import 'package:just_audio/just_audio.dart';

enum PlaybackState { stopped, playing, paused }

class AudioService {
  AudioService() {
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      if (state.playing) {
        _setState(PlaybackState.playing);
      } else if (state.processingState == ProcessingState.ready) {
        _setState(PlaybackState.paused);
      } else {
        _setState(PlaybackState.stopped);
      }
    });
  }

  final AudioPlayer _player = AudioPlayer();
  final _stateController = StreamController<PlaybackState>.broadcast();
  late final StreamSubscription<PlayerState> _playerStateSubscription;

  PlaybackState _state = PlaybackState.stopped;

  Stream<PlaybackState> get onStateChanged => _stateController.stream;
  PlaybackState get state => _state;

  void _setState(PlaybackState newState) {
    if (_state == newState) {
      return;
    }

    _state = newState;
    _stateController.add(newState);
  }

  Future<void> play(String filePath) async {
    await _player.stop();
    await _player.setFilePath(filePath);
    await _player.play();
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> dispose() async {
    await _playerStateSubscription.cancel();
    await _player.dispose();
    await _stateController.close();
  }
}