import 'dart:async';
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

  test(
    'detects incomplete and complete lexicon-based model directories',
    () async {
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
    },
  );

  test(
    'validates pocket tts model directories without requiring tokens.txt',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('tts-core-test');
      addTearDown(() => tempDir.delete(recursive: true));

      const model = VoiceModel(
        id: 'pocket-tts-en',
        displayName: 'Pocket TTS English (Voice Cloning)',
        family: 'pocket',
        runtime: 'sherpa-onnx',
        approvedForDistribution: false,
        archiveUrl: 'https://example.com/pocket.tar.bz2',
        archiveFormat: 'tar.bz2',
        installDirName: 'sherpa-onnx-pocket-tts-int8-2026-01-26',
        modelFile: 'lm_flow.int8.onnx',
        tokensFile: '',
        lexiconFile: '',
        voicesFile: '',
        dataDir: '',
        provider: 'cpu',
        numThreads: 1,
        defaultSpeed: 1,
        defaultSpeakerId: 0,
        maxNumSentences: 1,
        pocketLmMain: 'lm_main.int8.onnx',
        pocketEncoder: 'encoder.onnx',
        pocketDecoder: 'decoder.int8.onnx',
        pocketTextConditioner: 'text_conditioner.onnx',
        pocketVocabJson: 'vocab.json',
        pocketTokenScoresJson: 'token_scores.json',
      );

      await File('${tempDir.path}/lm_flow.int8.onnx').writeAsString('flow');

      expect(
        await ModelFileValidator.missingEntries(tempDir.path, model),
        isNot(contains('')),
      );
      expect(
        await ModelFileValidator.getStatus(tempDir.path, model),
        ModelStatus.incomplete,
      );

      await File('${tempDir.path}/lm_main.int8.onnx').writeAsString('main');
      await File('${tempDir.path}/encoder.onnx').writeAsString('encoder');
      await File('${tempDir.path}/decoder.int8.onnx').writeAsString('decoder');
      await File(
        '${tempDir.path}/text_conditioner.onnx',
      ).writeAsString('conditioner');
      await File('${tempDir.path}/vocab.json').writeAsString('{}');
      await File('${tempDir.path}/token_scores.json').writeAsString('{}');

      expect(
        await ModelFileValidator.getStatus(tempDir.path, model),
        ModelStatus.ready,
      );
    },
  );

  test('normalizes a nested extracted model directory', () async {
    final tempDir = await Directory.systemTemp.createTemp('tts-core-test');
    addTearDown(() => tempDir.delete(recursive: true));

    const model = VoiceModel(
      id: 'pocket-tts-en',
      displayName: 'Pocket TTS English (Voice Cloning)',
      family: 'pocket',
      runtime: 'sherpa-onnx',
      approvedForDistribution: false,
      archiveUrl: 'https://example.com/pocket.tar.bz2',
      archiveFormat: 'tar.bz2',
      installDirName: 'sherpa-onnx-pocket-tts-int8-2026-01-26',
      modelFile: 'lm_flow.int8.onnx',
      tokensFile: '',
      lexiconFile: '',
      voicesFile: '',
      dataDir: '',
      provider: 'cpu',
      numThreads: 1,
      defaultSpeed: 1,
      defaultSpeakerId: 0,
      maxNumSentences: 1,
      pocketLmMain: 'lm_main.int8.onnx',
      pocketEncoder: 'encoder.onnx',
      pocketDecoder: 'decoder.int8.onnx',
      pocketTextConditioner: 'text_conditioner.onnx',
      pocketVocabJson: 'vocab.json',
      pocketTokenScoresJson: 'token_scores.json',
    );

    final expectedDir = Directory('${tempDir.path}/${model.installDirName}');
    final nestedDir = Directory('${expectedDir.path}/nested');
    await nestedDir.create(recursive: true);

    await File('${nestedDir.path}/lm_flow.int8.onnx').writeAsString('flow');
    await File('${nestedDir.path}/lm_main.int8.onnx').writeAsString('main');
    await File('${nestedDir.path}/encoder.onnx').writeAsString('encoder');
    await File('${nestedDir.path}/decoder.int8.onnx').writeAsString('decoder');
    await File(
      '${nestedDir.path}/text_conditioner.onnx',
    ).writeAsString('conditioner');
    await File('${nestedDir.path}/vocab.json').writeAsString('{}');
    await File('${nestedDir.path}/token_scores.json').writeAsString('{}');

    expect(
      await ModelFileValidator.getStatus(expectedDir.path, model),
      ModelStatus.incomplete,
    );

    await ModelFileValidator.normalizeExtractedModelDir(
      expectedDir.path,
      model,
    );

    expect(
      await ModelFileValidator.getStatus(expectedDir.path, model),
      ModelStatus.ready,
    );
    expect(await Directory('${expectedDir.path}/nested').exists(), isFalse);
    expect(
      await File('${expectedDir.path}/lm_flow.int8.onnx').exists(),
      isTrue,
    );
  });

  test(
    'model install tasks keep progress details and freeze elapsed time once completed',
    () async {
      final manager = TaskManager(executor: _FakeBackgroundTaskExecutor());
      addTearDown(manager.dispose);

      final taskId = manager.startModelInstall(
        label: 'Install Pocket TTS English (Voice Cloning)',
        statusText: 'Downloading',
      );

      manager.updateInstallTask(
        taskId,
        statusText: 'Extracting',
        progress: 0.8,
        transferredBytes: 80,
        totalBytes: 100,
      );

      final runningTask = manager.tasks.firstWhere((task) => task.id == taskId);
      expect(runningTask.type, LongRunningTaskType.installModel);
      expect(runningTask.statusText, 'Extracting');
      expect(runningTask.progress, 0.8);
      expect(runningTask.transferredBytes, 80);
      expect(runningTask.totalBytes, 100);

      await Future<void>.delayed(const Duration(seconds: 1));
      manager.completeInstallTask(
        taskId,
        statusText: 'Installed',
        transferredBytes: 100,
        totalBytes: 100,
      );

      final completedTask = manager.tasks.firstWhere(
        (task) => task.id == taskId,
      );
      expect(completedTask.finishedAt, isNotNull);
      expect(completedTask.statusText, 'Installed');

      final firstElapsed = manager.formatElapsed(completedTask);
      await Future<void>.delayed(const Duration(seconds: 1));
      final secondElapsed = manager.formatElapsed(
        manager.tasks.firstWhere((task) => task.id == taskId),
      );
      expect(secondElapsed, firstElapsed);
    },
  );
}

class _FakeBackgroundTaskExecutor implements BackgroundTaskExecutor {
  final StreamController<TaskResult> _controller =
      StreamController<TaskResult>.broadcast();

  @override
  Stream<TaskResult> get results => _controller.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> submit(TaskRequest request) async {}

  @override
  void requestCancel(String taskId) {}

  @override
  void dispose() {
    _controller.close();
  }
}
