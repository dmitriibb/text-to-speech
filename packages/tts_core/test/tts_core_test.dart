import 'package:flutter_test/flutter_test.dart';

import 'package:tts_core/tts_core.dart';

import 'dart:io';

void main() {
  test('parses the approved model catalog shape', () {
    const rawCatalog = '''
{
  "catalog_version": 1,
  "updated_on": "2026-04-03",
  "default_model_id": "demo-model",
  "models": [
    {
      "id": "demo-model",
      "display_name": "Demo Model",
      "family": "vits",
      "runtime": "sherpa-onnx",
      "status": {
        "approved_for_distribution": false
      },
      "source": {
        "archive_url": "https://example.com/demo.tar.bz2"
      },
      "install": {
        "install_dir_name": "demo-model",
        "archive_format": "tar.bz2"
      },
      "files": {
        "model": "demo.onnx",
        "lexicon": "lexicon.txt",
        "tokens": "tokens.txt",
        "data_dir": "espeak-ng-data"
      },
      "defaults": {
        "provider": "cpu",
        "num_threads": 1,
        "speed": 1.0,
        "speaker_id": 0,
        "max_num_sentences": 1
      }
    }
  ]
}
''';

    final catalog = ModelCatalog.fromRawJson(rawCatalog);

    expect(catalog.catalogVersion, 1);
    expect(catalog.defaultModelId, 'demo-model');
    expect(catalog.models, hasLength(1));
    expect(catalog.models.single.installDirName, 'demo-model');
    expect(catalog.models.single.lexiconFile, 'lexicon.txt');
  });

  test('detects incomplete and complete model directories', () async {
    final tempDir = await Directory.systemTemp.createTemp('tts-core-test');
    addTearDown(() => tempDir.delete(recursive: true));

    const model = VoiceModel(
      id: 'demo-model',
      displayName: 'Demo Model',
      family: 'vits',
      runtime: 'sherpa-onnx',
      approvedForDistribution: false,
      archiveUrl: 'https://example.com/demo.tar.bz2',
      archiveFormat: 'tar.bz2',
      installDirName: 'demo-model',
      modelFile: 'demo.onnx',
      tokensFile: 'tokens.txt',
      lexiconFile: '',
      voicesFile: '',
      dataDir: 'espeak-ng-data',
      provider: 'cpu',
      numThreads: 1,
      defaultSpeed: 1,
      defaultSpeakerId: 0,
      maxNumSentences: 1,
    );

    await File('${tempDir.path}/demo.onnx').writeAsString('onnx');
    expect(
      await ModelFileValidator.getStatus(tempDir.path, model),
      ModelStatus.incomplete,
    );

    await File('${tempDir.path}/tokens.txt').writeAsString('tokens');
    await Directory('${tempDir.path}/espeak-ng-data').create();

    expect(
      await ModelFileValidator.getStatus(tempDir.path, model),
      ModelStatus.ready,
    );
  });

  test('detects incomplete and complete lexicon-based model directories', () async {
    final tempDir = await Directory.systemTemp.createTemp('tts-core-test');
    addTearDown(() => tempDir.delete(recursive: true));

    const model = VoiceModel(
      id: 'vits-ljs',
      displayName: 'VITS LJSpeech',
      family: 'vits',
      runtime: 'sherpa-onnx',
      approvedForDistribution: false,
      archiveUrl: 'https://example.com/vits-ljs.tar.bz2',
      archiveFormat: 'tar.bz2',
      installDirName: 'vits-ljs',
      modelFile: 'vits-ljs.onnx',
      tokensFile: 'tokens.txt',
      lexiconFile: 'lexicon.txt',
      voicesFile: '',
      dataDir: '',
      provider: 'cpu',
      numThreads: 1,
      defaultSpeed: 1,
      defaultSpeakerId: 0,
      maxNumSentences: 1,
    );

    await File('${tempDir.path}/vits-ljs.onnx').writeAsString('onnx');
    await File('${tempDir.path}/tokens.txt').writeAsString('tokens');

    expect(
      await ModelFileValidator.getStatus(tempDir.path, model),
      ModelStatus.incomplete,
    );

    await File('${tempDir.path}/lexicon.txt').writeAsString('lexicon');

    expect(
      await ModelFileValidator.getStatus(tempDir.path, model),
      ModelStatus.ready,
    );
  });
}
