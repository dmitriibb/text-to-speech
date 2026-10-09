import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tts_core/tts_core.dart';

Uint8List waveBytes(
  int rate,
  int frames,
  double Function(int) value, {
  int channels = 1,
}) {
  final bytes = Uint8List(44 + frames * channels * 2);
  bytes.setRange(0, 44, PcmWave.header(frames * channels, rate));
  final data = ByteData.sublistView(bytes);
  data.setUint16(22, channels, Endian.little);
  data.setUint32(28, rate * channels * 2, Endian.little);
  data.setUint16(32, channels * 2, Endian.little);
  for (var frame = 0; frame < frames; frame++) {
    for (var c = 0; c < channels; c++) {
      data.setInt16(
        44 + (frame * channels + c) * 2,
        (value(frame) * 32767).round(),
        Endian.little,
      );
    }
  }
  return bytes;
}

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('conversation-test-');
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  Future<ConversationRenderInput> input(
    String id,
    Uint8List bytes,
    int pause,
  ) async {
    final file = File('${directory.path}/$id.wav');
    await file.writeAsBytes(bytes);
    return ConversationRenderInput(
      turnId: id,
      actorId: 'actor-$id',
      path: file.path,
      sha256: sha256.convert(bytes).toString(),
      pauseAfterMs: pause,
    );
  }

  test(
    'mixed rates/stereo preserve order, exact pauses, and global headroom',
    () async {
      final first = await input(
        'first',
        waveBytes(16000, 1600, (_) => .3, channels: 2),
        250,
      );
      final second = await input(
        'second',
        waveBytes(24000, 2400, (_) => -.5),
        2000,
      );
      final path = '${directory.path}/master.wav';
      await ConversationRenderer().render(
        inputs: [first, second],
        outputPath: path,
        projectId: 'project',
        revision: 2,
      );
      final wave = PcmWave.decode(await File(path).readAsBytes());
      expect(wave.sampleRate, 48000);
      expect(wave.samples.length, 21600); // .1 + .25 + .1, no final pause.
      expect(wave.samples[2400], closeTo(.3, .001));
      expect(
        wave.samples.sublist(4800, 16800).every((value) => value == 0),
        isTrue,
      );
      expect(wave.samples[19000], closeTo(-.5, .001));
      final manifest = jsonDecode(
        await File('$path.manifest.json').readAsString(),
      );
      expect(manifest['turns'][1]['offsetFrames'], 16800);
      expect(manifest['turns'][1]['inputHash'], second.sha256);
    },
  );
  test(
    'attenuates whole conversation to -1 dBFS, without raising quiet replies',
    () async {
      final loud = await input('loud', waveBytes(48000, 480, (_) => .99), 0);
      final quiet = await input('quiet', waveBytes(48000, 480, (_) => .01), 0);
      final path = '${directory.path}/master.wav';
      await ConversationRenderer().render(
        inputs: [loud, quiet],
        outputPath: path,
        projectId: 'p',
        revision: 1,
      );
      final wave = PcmWave.decode(await File(path).readAsBytes());
      expect(wave.samples[10], lessThanOrEqualTo(math.pow(10, -1 / 20)));
      expect(wave.samples[600] / wave.samples[10], closeTo(.01 / .99, .0001));
    },
  );
  test('downsampling suppresses content above output Nyquist', () async {
    final high = await input(
      'high',
      waveBytes(
        96000,
        9600,
        (i) => .5 * math.sin(2 * math.pi * 35000 * i / 96000),
      ),
      0,
    );
    final path = '${directory.path}/master.wav';
    await ConversationRenderer().render(
      inputs: [high],
      outputPath: path,
      projectId: 'p',
      revision: 1,
    );
    final wave = PcmWave.decode(await File(path).readAsBytes());
    final rms = math.sqrt(
      wave.samples
              .sublist(100, 4700)
              .map((x) => x * x)
              .reduce((a, b) => a + b) /
          4600,
    );
    expect(rms, lessThan(.005));
  });
  test(
    'corrupt, changed, missing and cancelled sources never publish a master',
    () async {
      final valid = await input('turn', waveBytes(16000, 1600, (_) => .2), 0);
      final path = '${directory.path}/bad.wav';
      await File(valid.path).writeAsBytes([1, 2, 3]);
      await expectLater(
        ConversationRenderer().render(
          inputs: [valid],
          outputPath: path,
          projectId: 'p',
          revision: 1,
        ),
        throwsStateError,
      );
      expect(await File(path).exists(), isFalse);
      await File(valid.path).delete();
      await expectLater(
        ConversationRenderer().render(
          inputs: [valid],
          outputPath: path,
          projectId: 'p',
          revision: 1,
        ),
        throwsStateError,
      );
      await expectLater(
        ConversationRenderer().render(
          inputs: [valid],
          outputPath: path,
          projectId: 'p',
          revision: 1,
          isCancelled: () => true,
        ),
        throwsStateError,
      );
      expect(await File('$path.part').exists(), isFalse);
      expect(() => PcmWave.decode(Uint8List(50)), throwsFormatException);
    },
  );
  test(
    'revision/cancel during progress deletes temporary and final output',
    () async {
      final valid = await input('turn', waveBytes(16000, 16000, (_) => .2), 0);
      var cancelled = false;
      final path = '${directory.path}/cancel.wav';
      await expectLater(
        ConversationRenderer().render(
          inputs: [valid],
          outputPath: path,
          projectId: 'p',
          revision: 1,
          onProgress: (_) => cancelled = true,
          isCancelled: () => cancelled,
        ),
        throwsStateError,
      );
      expect(await File(path).exists(), isFalse);
      expect(await File('$path.manifest.json').exists(), isFalse);
    },
  );
  test('ten-minute conversation streams 600 turns', () async {
    final source = await input(
      'long-source',
      waveBytes(
        48000,
        48000,
        (i) => .1 * math.sin(2 * math.pi * 440 * i / 48000),
      ),
      0,
    );
    final path = '${directory.path}/long.wav';
    final inputs = List.generate(
      600,
      (i) => ConversationRenderInput(
        turnId: 'turn-$i',
        actorId: 'actor',
        path: source.path,
        sha256: source.sha256,
        pauseAfterMs: 0,
      ),
    );
    await ConversationRenderer().render(
      inputs: inputs,
      outputPath: path,
      projectId: 'long',
      revision: 1,
    );
    expect(await File(path).length(), 44 + 600 * 48000 * 2);
    final manifest = jsonDecode(
      await File('$path.manifest.json').readAsString(),
    );
    expect(manifest['turns'].length, 600);
    expect(manifest['totalFrames'], 600 * 48000);
  });
}
