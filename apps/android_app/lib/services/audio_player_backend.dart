import 'package:just_audio/just_audio.dart' as just_audio;

enum AudioProcessingState { idle, loading, buffering, ready, completed }

class AudioPlayerSnapshot {
  const AudioPlayerSnapshot({
    required this.playing,
    required this.processingState,
  });

  final bool playing;
  final AudioProcessingState processingState;
}

abstract class AudioPlayerBackend {
  Stream<AudioPlayerSnapshot> get playerStateStream;
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;

  AudioProcessingState get processingState;
  Duration get position;
  Duration? get duration;

  Future<void> setFilePath(String filePath);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

class JustAudioPlayerBackend implements AudioPlayerBackend {
  JustAudioPlayerBackend({just_audio.AudioPlayer? player})
    : _player = player ?? just_audio.AudioPlayer();

  final just_audio.AudioPlayer _player;

  @override
  Stream<AudioPlayerSnapshot> get playerStateStream =>
      _player.playerStateStream.map(
        (state) => AudioPlayerSnapshot(
          playing: state.playing,
          processingState: _mapProcessingState(state.processingState),
        ),
      );

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  AudioProcessingState get processingState =>
      _mapProcessingState(_player.processingState);

  @override
  Duration get position => _player.position;

  @override
  Duration? get duration => _player.duration;

  @override
  Future<void> setFilePath(String filePath) => _player.setFilePath(filePath);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> dispose() => _player.dispose();

  AudioProcessingState _mapProcessingState(just_audio.ProcessingState state) {
    switch (state) {
      case just_audio.ProcessingState.idle:
        return AudioProcessingState.idle;
      case just_audio.ProcessingState.loading:
        return AudioProcessingState.loading;
      case just_audio.ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case just_audio.ProcessingState.ready:
        return AudioProcessingState.ready;
      case just_audio.ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }
}
