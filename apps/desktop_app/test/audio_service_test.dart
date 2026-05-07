import 'package:desktop_app/services/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows playback resumes the loaded clip after pause', () async {
    final controller = _FakeWindowsAudioController(
      durationValue: const Duration(seconds: 5),
    );
    final service = AudioService(windowsController: controller);

    await service.play('first.wav');
    controller.positionValue = const Duration(seconds: 2);
    await service.pause();
    await service.play('first.wav');

    expect(
      controller.log,
      ['load:first.wav', 'play:0', 'pause', 'resume'],
    );
    expect(service.state, PlaybackState.playing);
    expect(service.position, const Duration(seconds: 2));

    service.dispose();
  });

  test('Windows seek repositions the active clip without reloading it', () async {
    final controller = _FakeWindowsAudioController(
      durationValue: const Duration(seconds: 10),
    );
    final service = AudioService(windowsController: controller);

    await service.play('first.wav');
    await service.seek(const Duration(seconds: 3));

    expect(
      controller.log,
      ['load:first.wav', 'play:0', 'seek:3000', 'play:3000'],
    );
    expect(service.state, PlaybackState.playing);
    expect(service.position, const Duration(seconds: 3));

    service.dispose();
  });
}

class _FakeWindowsAudioController implements WindowsAudioController {
  _FakeWindowsAudioController({required this.durationValue});

  final List<String> log = <String>[];

  Duration? durationValue;
  Duration positionValue = Duration.zero;
  WindowsAudioMode modeValue = WindowsAudioMode.stopped;

  @override
  void load(String filePath) {
    log.add('load:$filePath');
    positionValue = Duration.zero;
    modeValue = WindowsAudioMode.stopped;
  }

  @override
  Duration? duration() => durationValue;

  @override
  Duration position() => positionValue;

  @override
  WindowsAudioMode mode() => modeValue;

  @override
  void play({Duration from = Duration.zero}) {
    log.add('play:${from.inMilliseconds}');
    positionValue = from;
    modeValue = WindowsAudioMode.playing;
  }

  @override
  void resume() {
    log.add('resume');
    modeValue = WindowsAudioMode.playing;
  }

  @override
  void pause() {
    log.add('pause');
    modeValue = WindowsAudioMode.paused;
  }

  @override
  void stop() {
    log.add('stop');
    modeValue = WindowsAudioMode.stopped;
  }

  @override
  void seek(Duration position) {
    log.add('seek:${position.inMilliseconds}');
    positionValue = position;
  }

  @override
  void close() {
    log.add('close');
    modeValue = WindowsAudioMode.stopped;
  }
}
