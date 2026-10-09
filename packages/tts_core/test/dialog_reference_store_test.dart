import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tts_core/tts_core.dart';

void main() {
  late Directory temporary;
  late DialogReferenceStore store;
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('dialog-reference-test-');
    store = DialogReferenceStore(
      projectDirectory: Directory('${temporary.path}/project'),
    );
  });
  tearDown(() async => temporary.delete(recursive: true));

  test(
    'import owns bytes, reuses hashes, and preserves separate transcripts',
    () async {
      final source = File('${temporary.path}/source.wav');
      final wav = _wav();
      await source.writeAsBytes(wav);
      final first = await store.importWav(source, transcript: 'Ещё: да.');
      final second = await store.importWav(source, transcript: 'Другой текст.');
      await source.delete();
      expect(first.sha256, second.sha256);
      expect(first.transcript, 'Ещё: да.');
      expect(second.transcript, 'Другой текст.');
      expect(await store.readVerifiedBytes(first), wav);
      final files = await Directory(
        '${temporary.path}/project/references',
      ).list().toList();
      expect(files, hasLength(1));
    },
  );

  test('changed or missing managed reference fails before upload', () async {
    final source = File('${temporary.path}/source.wav');
    await source.writeAsBytes(_wav());
    final asset = await store.importWav(source, transcript: 'Алло?');
    final stored = File('${temporary.path}/project/${asset.relativePath}');
    await stored.writeAsBytes(_wav()..[44] = 1);
    await expectLater(store.readVerifiedBytes(asset), throwsStateError);
    await stored.delete();
    await expectLater(store.readVerifiedBytes(asset), throwsStateError);
  });

  test('invalid and oversized imports leave no partial reference', () async {
    final source = File('${temporary.path}/source.wav');
    await source.writeAsString('not a WAV');
    await expectLater(
      store.importWav(source, transcript: ''),
      throwsFormatException,
    );
    await source.writeAsBytes(_wav());
    final bounded = DialogReferenceStore(
      projectDirectory: store.projectDirectory,
      maxBytes: 16,
    );
    await expectLater(
      bounded.importWav(source, transcript: ''),
      throwsStateError,
    );
    expect(
      await Directory('${temporary.path}/project/references').list().toList(),
      isEmpty,
    );
  });
}

Uint8List _wav() {
  final bytes = Uint8List(48);
  final data = ByteData.sublistView(bytes);
  bytes.setRange(0, 4, 'RIFF'.codeUnits);
  data.setUint32(4, 40, Endian.little);
  bytes.setRange(8, 16, 'WAVEfmt '.codeUnits);
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 16000, Endian.little);
  data.setUint32(28, 32000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  bytes.setRange(36, 40, 'data'.codeUnits);
  data.setUint32(40, 4, Endian.little);
  return bytes;
}
