import 'dart:async';

import 'package:android_app/services/audio_player_backend.dart';
import 'package:android_app/services/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('play returns before backend playback future completes', () async {
    final backend = _FakeAudioPlayerBackend();
    final service = AudioService(player: backend);
    addTearDown(service.dispose);

    await service
        .play('/tmp/audio.wav')
        .timeout(const Duration(milliseconds: 100));

    expect(backend.setFilePathCalls, ['/tmp/audio.wav']);
    expect(backend.playCalls, 1);
  });

  test('pause is not blocked by an active playback future', () async {
    final backend = _FakeAudioPlayerBackend();
    final service = AudioService(player: backend);
    addTearDown(service.dispose);

    await service
        .play('/tmp/audio.wav')
        .timeout(const Duration(milliseconds: 100));
    await service.pause();

    expect(backend.pauseCalls, 1);
    expect(service.state, PlaybackState.paused);
  });

  test('seek while paused keeps the paused state', () async {
    final backend = _FakeAudioPlayerBackend(
      duration: const Duration(seconds: 5),
    );
    final service = AudioService(player: backend);
    addTearDown(service.dispose);

    await service
        .play('/tmp/audio.wav')
        .timeout(const Duration(milliseconds: 100));
    await service.pause();
    await service.seek(const Duration(seconds: 2));

    expect(backend.lastSeekPosition, const Duration(seconds: 2));
    expect(service.position, const Duration(seconds: 2));
    expect(service.state, PlaybackState.paused);
  });
}

class _FakeAudioPlayerBackend implements AudioPlayerBackend {
  _FakeAudioPlayerBackend({Duration? duration}) : _duration = duration;

  final StreamController<AudioPlayerSnapshot> _playerStateController =
      StreamController<AudioPlayerSnapshot>.broadcast();
  final StreamController<Duration> _positionController =
      StreamController<Duration>.broadcast();
  final StreamController<Duration?> _durationController =
      StreamController<Duration?>.broadcast();
  final Completer<void> _playCompleter = Completer<void>();

  final List<String> setFilePathCalls = [];
  int playCalls = 0;
  int pauseCalls = 0;
  Duration _position = Duration.zero;
  final Duration? _duration;
  Duration? lastSeekPosition;
  AudioProcessingState _processingState = AudioProcessingState.ready;

  @override
  Stream<AudioPlayerSnapshot> get playerStateStream =>
      _playerStateController.stream;

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<Duration?> get durationStream => _durationController.stream;

  @override
  AudioProcessingState get processingState => _processingState;

  @override
  Duration get position => _position;

  @override
  Duration? get duration => _duration;

  @override
  Future<void> setFilePath(String filePath) async {
    setFilePathCalls.add(filePath);
  }

  @override
  Future<void> play() {
    playCalls++;
    _processingState = AudioProcessingState.ready;
    _playerStateController.add(
      const AudioPlayerSnapshot(
        playing: true,
        processingState: AudioProcessingState.ready,
      ),
    );
    return _playCompleter.future;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    _playerStateController.add(
      const AudioPlayerSnapshot(
        playing: false,
        processingState: AudioProcessingState.ready,
      ),
    );
  }

  @override
  Future<void> seek(Duration position) async {
    _position = position;
    lastSeekPosition = position;
    _positionController.add(position);
    _playerStateController.add(
      const AudioPlayerSnapshot(
        playing: false,
        processingState: AudioProcessingState.ready,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    if (!_playCompleter.isCompleted) {
      _playCompleter.complete();
    }
    await _playerStateController.close();
    await _positionController.close();
    await _durationController.close();
  }
}
