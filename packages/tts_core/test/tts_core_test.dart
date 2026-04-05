import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tts_core/tts_core.dart';

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
    expect(catalog.models.single.pocketDefaultReferenceAudio, isEmpty);
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
        pocketDefaultReferenceAudio: 'test_wavs/bria.wav',
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
        ModelStatus.incomplete,
      );

      await Directory('${tempDir.path}/test_wavs').create(recursive: true);
      await File('${tempDir.path}/test_wavs/bria.wav').writeAsString('wav');

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
      pocketDefaultReferenceAudio: 'test_wavs/bria.wav',
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
    await Directory('${nestedDir.path}/test_wavs').create(recursive: true);
    await File('${nestedDir.path}/test_wavs/bria.wav').writeAsString('wav');

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

  test(
    'model preload tasks complete when async executor results arrive',
    () async {
      final executor = _FakeBackgroundTaskExecutor();
      final manager = TaskManager(executor: executor);
      addTearDown(manager.dispose);

      await manager.initialize();
      final taskId = await manager.submitModelPreload(
        modelDir: '/tmp/demo-model',
        voice: _demoVoiceModel,
      );

      final queuedTask = manager.tasks.firstWhere((task) => task.id == taskId);
      expect(queuedTask.type, LongRunningTaskType.preloadModel);
      expect(queuedTask.status, LongRunningTaskStatus.queued);
      expect(manager.hasActiveTasks, isTrue);

      executor.completeTask(taskId, LongRunningTaskType.preloadModel);
      await Future<void>.delayed(Duration.zero);

      final completedTask = manager.tasks.firstWhere(
        (task) => task.id == taskId,
      );
      expect(completedTask.status, LongRunningTaskStatus.completed);
      expect(completedTask.finishedAt, isNotNull);
      expect(manager.hasActiveTasks, isFalse);
    },
  );

  test('voice model task payload preserves Pocket runtime metadata', () {
    const pocketModel = VoiceModel(
      id: 'pocket-tts-en',
      displayName: 'Pocket TTS English (Voice Cloning)',
      family: 'pocket',
      runtime: 'sherpa-onnx',
      approvedForDistribution: false,
      archiveUrl: 'https://example.com/pocket.tar.bz2',
      archiveFormat: 'tar.bz2',
      installDirName: 'sherpa-onnx-pocket-tts-int8-2026-01-26',
      modelFile: '',
      tokensFile: '',
      lexiconFile: '',
      voicesFile: '',
      dataDir: '',
      provider: 'cpu',
      numThreads: 2,
      defaultSpeed: 1,
      defaultSpeakerId: 7,
      maxNumSentences: 1,
      voiceCloning: true,
      pocketLmMain: 'lm_main.int8.onnx',
      pocketEncoder: 'encoder.onnx',
      pocketDecoder: 'decoder.int8.onnx',
      pocketTextConditioner: 'text_conditioner.onnx',
      pocketVocabJson: 'vocab.json',
      pocketTokenScoresJson: 'token_scores.json',
      pocketDefaultReferenceAudio: 'test_wavs/bria.wav',
    );

    final payload = VoiceModelTaskPayload.build(
      modelDir: '/tmp/pocket-model',
      voice: pocketModel,
    );
    final decoded = VoiceModelTaskPayload.decode(payload);

    expect(payload['defaultSpeakerId'], 7);
    expect(payload['pocketDefaultReferenceAudio'], 'test_wavs/bria.wav');
    expect(decoded.defaultSpeakerId, 7);
    expect(decoded.pocketDefaultReferenceAudio, 'test_wavs/bria.wav');
    expect(decoded.pocketTokenScoresJson, 'token_scores.json');
  });

  test('extracts tar.bz2 archives with nested model files', () async {
    final tempDir = await Directory.systemTemp.createTemp('tts-core-test');
    addTearDown(() => tempDir.delete(recursive: true));

    final archive = Archive();
    final directoryEntry = ArchiveFile('demo-model/espeak-ng-data/', 0, null)
      ..isFile = false;
    archive.addFile(directoryEntry);
    archive.addFile(
      ArchiveFile('demo-model/MODEL_CARD', 4, Uint8List.fromList([1, 2, 3, 4])),
    );
    archive.addFile(
      ArchiveFile(
        'demo-model/demo.onnx',
        1024 * 1024,
        Uint8List.fromList(List<int>.filled(1024 * 1024, 7)),
      ),
    );
    archive.addFile(
      ArchiveFile(
        'demo-model/tokens.txt',
        6,
        Uint8List.fromList('tokens'.codeUnits),
      ),
    );
    archive.addFile(
      ArchiveFile(
        'demo-model/espeak-ng-data/en_dict',
        5,
        Uint8List.fromList('dicts'.codeUnits),
      ),
    );

    final tarBytes = TarEncoder().encode(archive);
    final compressedBytes = BZip2Encoder().encode(tarBytes);
    final archivePath = '${tempDir.path}/demo-model.tar.bz2';
    await File(archivePath).writeAsBytes(compressedBytes);

    final outputDir = '${tempDir.path}/out';
    await ModelArchiveExtractor.extractArchive(
      archivePath: archivePath,
      archiveFormat: 'tar.bz2',
      outputDir: outputDir,
    );

    expect(await File('$outputDir/demo-model/demo.onnx').exists(), isTrue);
    expect(await File('$outputDir/demo-model/tokens.txt').exists(), isTrue);
    expect(
      await Directory('$outputDir/demo-model/espeak-ng-data').exists(),
      isTrue,
    );
    expect(
      await File('$outputDir/demo-model/espeak-ng-data/en_dict').exists(),
      isTrue,
    );
  });
}

class _FakeBackgroundTaskExecutor implements BackgroundTaskExecutor {
  final StreamController<TaskResult> _controller =
      StreamController<TaskResult>.broadcast();
  final List<TaskRequest> submittedRequests = <TaskRequest>[];

  @override
  Stream<TaskResult> get results => _controller.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> submit(TaskRequest request) async {
    submittedRequests.add(request);
  }

  @override
  void requestCancel(String taskId) {}

  void completeTask(String taskId, LongRunningTaskType type) {
    _controller.add(
      TaskResult(
        taskId: taskId,
        type: type,
        status: TaskResultStatus.completed,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
  }
}

const VoiceModel _demoVoiceModel = VoiceModel(
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
