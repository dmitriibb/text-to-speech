import 'dart:io';
import 'dart:typed_data';

import 'package:desktop_app/services/voice_library_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('voice-library-test-');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'stores WAV imports as WAV even when the extension is missing',
    () async {
      final sourceFile = File(p.join(tempDir.path, 'sample-audio'));
      await sourceFile.writeAsBytes(_wavHeaderBytes());

      final service = VoiceLibraryService(libraryRootPath: tempDir.path);
      final voice = await service.addVoice(
        name: 'Narrator',
        sourceAudioPath: sourceFile.path,
      );

      expect(p.extension(voice.referenceAudioPath), '.wav');
      expect(
        await File(voice.referenceAudioPath).readAsBytes(),
        _wavHeaderBytes(),
      );

      final voices = await service.loadVoices();
      expect(voices, hasLength(1));
      expect(voices.single.referenceAudioPath, voice.referenceAudioPath);
    },
  );

  test(
    'converts MP3 imports to WAV before saving to the voice library',
    () async {
      final sourceFile = File(p.join(tempDir.path, 'sample-audio'));
      await sourceFile.writeAsBytes(_mp3HeaderBytes());

      String? executable;
      List<String>? arguments;
      final service = VoiceLibraryService(
        libraryRootPath: tempDir.path,
        processRunner: (processExecutable, processArguments) async {
          executable = processExecutable;
          arguments = processArguments;
          await File(processArguments.last).writeAsBytes(_wavHeaderBytes());
          return ProcessResult(0, 0, '', '');
        },
      );

      final voice = await service.addVoice(
        name: 'Narrator',
        sourceAudioPath: sourceFile.path,
      );

      expect(executable, 'ffmpeg');
      expect(arguments, isNotNull);
      expect(arguments, containsAllInOrder(['-i', sourceFile.path]));
      expect(arguments!.last, voice.referenceAudioPath);
      expect(p.extension(voice.referenceAudioPath), '.wav');
      expect(await File(voice.referenceAudioPath).exists(), isTrue);
    },
  );

  test('normalizes MP3 inputs to a standalone WAV file', () async {
    final sourceFile = File(p.join(tempDir.path, 'openvoice-sample.mp3'));
    await sourceFile.writeAsBytes(_mp3HeaderBytes());

    String? executable;
    List<String>? arguments;
    final service = VoiceLibraryService(
      libraryRootPath: tempDir.path,
      processRunner: (processExecutable, processArguments) async {
        executable = processExecutable;
        arguments = processArguments;
        await File(processArguments.last).writeAsBytes(_wavHeaderBytes());
        return ProcessResult(0, 0, '', '');
      },
    );

    final outputPath = p.join(tempDir.path, 'normalized', 'sample.wav');
    await service.normalizeAudioToWav(
      sourceAudioPath: sourceFile.path,
      destinationWavPath: outputPath,
    );

    expect(executable, 'ffmpeg');
    expect(arguments, isNotNull);
    expect(arguments, containsAllInOrder(['-i', sourceFile.path]));
    expect(arguments!.last, outputPath);
    expect(await File(outputPath).exists(), isTrue);
  });

  test('rejects unsupported import formats', () async {
    final sourceFile = File(p.join(tempDir.path, 'sample-audio'));
    await sourceFile.writeAsBytes(Uint8List.fromList([0x01, 0x02, 0x03, 0x04]));

    final service = VoiceLibraryService(libraryRootPath: tempDir.path);

    await expectLater(
      () =>
          service.addVoice(name: 'Narrator', sourceAudioPath: sourceFile.path),
      throwsA(isA<UnsupportedError>()),
    );
  });
}

Uint8List _wavHeaderBytes() => Uint8List.fromList([
  0x52,
  0x49,
  0x46,
  0x46,
  0x24,
  0x00,
  0x00,
  0x00,
  0x57,
  0x41,
  0x56,
  0x45,
]);

Uint8List _mp3HeaderBytes() => Uint8List.fromList([
  0x49,
  0x44,
  0x33,
  0x04,
  0x00,
  0x00,
  0x00,
  0x00,
  0x00,
  0x21,
]);
