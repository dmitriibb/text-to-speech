import 'dart:async';
import 'dart:convert';
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
      "size_mb": 64,
      "supported_languages": ["English"],
      "description": "Demo description",
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
    expect(catalog.models.single.sizeMb, 64);
    expect(catalog.models.single.supportedLanguages, ['English']);
    expect(catalog.models.single.description, 'Demo description');
    expect(catalog.models.single.pocketDefaultReferenceAudio, isEmpty);
  });

  test('clamps speech speed to the supported range', () {
    expect(clampSpeechSpeed(0.1), speechSpeedMin);
    expect(clampSpeechSpeed(1.0), speechSpeedDefault);
    expect(clampSpeechSpeed(2.5), speechSpeedMax);
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

  test('newer tasks sort ahead of older tasks regardless of status', () async {
    final executor = _FakeBackgroundTaskExecutor();
    final manager = TaskManager(executor: executor);
    addTearDown(manager.dispose);

    final installTaskId = manager.startModelInstall(
      label: 'Install demo model',
      statusText: 'Downloading',
    );

    await Future<void>.delayed(const Duration(milliseconds: 1));
    await manager.initialize();
    final preloadTaskId = await manager.submitModelPreload(
      modelDir: '/tmp/demo-model',
      voice: _demoVoiceModel,
    );

    expect(manager.tasks.map((task) => task.id).toList(growable: false), [
      preloadTaskId,
      installTaskId,
    ]);
  });

  test(
    'restored completed synthesis tasks are surfaced in newest-first order',
    () {
      final manager = TaskManager(executor: _FakeBackgroundTaskExecutor());
      addTearDown(manager.dispose);

      final olderTask = LongRunningTask(
        id: 'restored-speech-1',
        type: LongRunningTaskType.synthesizeSpeech,
        label: 'speech-1',
        startedAt: DateTime(2026, 4, 6, 10, 0, 0),
        status: LongRunningTaskStatus.completed,
        finishedAt: DateTime(2026, 4, 6, 10, 0, 2),
        outputPath: '/tmp/generated_audio/speech-1.wav',
      );
      final newerTask = LongRunningTask(
        id: 'restored-speech-2',
        type: LongRunningTaskType.synthesizeSpeech,
        label: 'speech-2',
        startedAt: DateTime(2026, 4, 6, 10, 1, 0),
        status: LongRunningTaskStatus.completed,
        finishedAt: DateTime(2026, 4, 6, 10, 1, 3),
        outputPath: '/tmp/generated_audio/speech-2.wav',
      );

      manager.restoreTasks([olderTask, newerTask]);

      expect(manager.tasks.map((task) => task.id).toList(growable: false), [
        'restored-speech-2',
        'restored-speech-1',
      ]);
      expect(
        manager.latestCompletedSynthesis?.outputPath,
        '/tmp/generated_audio/speech-2.wav',
      );
    },
  );

  test('restoring tasks ignores duplicate output paths and active tasks', () {
    final manager = TaskManager(executor: _FakeBackgroundTaskExecutor());
    addTearDown(manager.dispose);

    final completedTask = LongRunningTask(
      id: 'restored-speech-1',
      type: LongRunningTaskType.synthesizeSpeech,
      label: 'speech-1',
      startedAt: DateTime(2026, 4, 6, 10, 0, 0),
      status: LongRunningTaskStatus.completed,
      finishedAt: DateTime(2026, 4, 6, 10, 0, 2),
      outputPath: '/tmp/generated_audio/speech-1.wav',
    );
    final duplicateTask = LongRunningTask(
      id: 'restored-speech-1-duplicate',
      type: LongRunningTaskType.synthesizeSpeech,
      label: 'speech-1-duplicate',
      startedAt: DateTime(2026, 4, 6, 10, 2, 0),
      status: LongRunningTaskStatus.completed,
      finishedAt: DateTime(2026, 4, 6, 10, 2, 1),
      outputPath: '/tmp/generated_audio/speech-1.wav',
    );
    final activeTask = LongRunningTask(
      id: 'restored-active',
      type: LongRunningTaskType.synthesizeSpeech,
      label: 'speech-active',
      startedAt: DateTime(2026, 4, 6, 10, 3, 0),
      status: LongRunningTaskStatus.running,
      outputPath: '/tmp/generated_audio/speech-active.wav',
    );

    manager.restoreTasks([completedTask, duplicateTask, activeTask]);

    expect(manager.tasks, hasLength(1));
    expect(manager.tasks.single.id, 'restored-speech-1');
  });

  test('restored speech labels advance the next generated task name', () async {
    final executor = _FakeBackgroundTaskExecutor();
    final manager = TaskManager(executor: executor);
    addTearDown(manager.dispose);

    manager.restoreTasks([
      LongRunningTask(
        id: 'restored-speech-2',
        type: LongRunningTaskType.synthesizeSpeech,
        label: 'speech-2',
        startedAt: DateTime(2026, 4, 6, 10, 1, 0),
        status: LongRunningTaskStatus.completed,
        finishedAt: DateTime(2026, 4, 6, 10, 1, 3),
        outputPath: '/tmp/generated_audio/speech-2.wav',
      ),
    ]);

    await manager.initialize();
    final taskId = await manager.submitSynthesis(
      modelDir: '/tmp/demo-model',
      voice: _demoVoiceModel,
      text: 'hello',
      speed: 1,
      speakerId: 0,
      outputPath: '/tmp/generated_audio/speech-3.wav',
    );

    final queuedTask = manager.tasks.firstWhere((task) => task.id == taskId);
    expect(queuedTask.label, 'speech-3');
    expect(queuedTask.modelName, _demoVoiceModel.displayName);
  });

  test(
    'generated audio store persists records and initializes stats',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('tts-core-test');
      addTearDown(() => tempDir.delete(recursive: true));

      final outputFile = File('${tempDir.path}/speech-1.wav');
      await outputFile.writeAsString('wav');

      final store = GeneratedAudioStore(
        libraryFile: File(
          '${tempDir.path}/${GeneratedAudioStore.defaultLibraryPath}',
        ),
        statsFile: File(
          '${tempDir.path}/${GeneratedAudioStore.defaultStatsPath}',
        ),
      );

      final task = LongRunningTask(
        id: 'task-1',
        type: LongRunningTaskType.synthesizeSpeech,
        label: 'speech-1',
        startedAt: DateTime(2026, 4, 6, 10, 0, 0),
        status: LongRunningTaskStatus.completed,
        inputCharacterCount: 200,
        modelId: 'demo-model',
        modelName: 'Demo Model',
        finishedAt: DateTime(2026, 4, 6, 10, 0, 4),
        outputPath: outputFile.path,
      );

      await store.upsertTask(task);
      final loadedTasks = await store.loadTasks();

      expect(loadedTasks, hasLength(1));
      expect(loadedTasks.single.label, 'speech-1');
      expect(loadedTasks.single.inputCharacterCount, 200);
      expect(loadedTasks.single.modelId, 'demo-model');
      expect(loadedTasks.single.modelName, 'Demo Model');
      expect(
        loadedTasks.single.finishedAt?.difference(loadedTasks.single.startedAt),
        const Duration(seconds: 4),
      );

      final statsPayload =
          jsonDecode(
                await File(
                  '${tempDir.path}/${GeneratedAudioStore.defaultStatsPath}',
                ).readAsString(),
              )
              as Map<String, Object?>;
      expect(statsPayload['version'], GeneratedAudioStore.schemaVersion);
      expect(statsPayload['models'], isEmpty);
    },
  );

  test('generated audio store updates per-model statistics', () async {
    final tempDir = await Directory.systemTemp.createTemp('tts-core-test');
    addTearDown(() => tempDir.delete(recursive: true));

    final outputFile = File('${tempDir.path}/speech-1.wav');
    await outputFile.writeAsString('wav');

    final store = GeneratedAudioStore(
      libraryFile: File(
        '${tempDir.path}/${GeneratedAudioStore.defaultLibraryPath}',
      ),
      statsFile: File(
        '${tempDir.path}/${GeneratedAudioStore.defaultStatsPath}',
      ),
    );

    final task = LongRunningTask(
      id: 'task-1',
      type: LongRunningTaskType.synthesizeSpeech,
      label: 'speech-1',
      startedAt: DateTime(2026, 4, 6, 10, 0, 0),
      status: LongRunningTaskStatus.completed,
      inputCharacterCount: 200,
      speechSpeed: 0.5,
      modelName: 'Demo Model',
      finishedAt: DateTime(2026, 4, 6, 10, 0, 4),
      outputPath: outputFile.path,
    );

    await store.updateStatisticsForTask(task, outputSecondsOverride: 8);
    final statistics = await store.loadStatistics();
    final demoStats = statistics['Demo Model'];

    expect(demoStats, isNotNull);
    expect(demoStats!.totalChars, 200);
    expect(demoStats.generationTotalSeconds, 4);
    expect(demoStats.outputTotalSeconds, 4);
    expect(demoStats.generationSecondsPer100Chars, 2);
    expect(demoStats.outputSecondsPer100Chars, 2);
    expect(demoStats.expectedOutputSecondsForChars(250, speechSpeed: 0.5), 10);
  });

  test('generated audio store caps aggregated model statistics', () async {
    final tempDir = await Directory.systemTemp.createTemp('tts-core-test');
    addTearDown(() => tempDir.delete(recursive: true));

    final outputFile = File('${tempDir.path}/speech-1.wav');
    await outputFile.writeAsString('wav');

    final store = GeneratedAudioStore(
      libraryFile: File(
        '${tempDir.path}/${GeneratedAudioStore.defaultLibraryPath}',
      ),
      statsFile: File(
        '${tempDir.path}/${GeneratedAudioStore.defaultStatsPath}',
      ),
    );

    final firstTask = LongRunningTask(
      id: 'task-1',
      type: LongRunningTaskType.synthesizeSpeech,
      label: 'speech-1',
      startedAt: DateTime(2026, 4, 6, 10, 0, 0),
      status: LongRunningTaskStatus.completed,
      inputCharacterCount: 900000,
      modelName: 'Demo Model',
      finishedAt: DateTime(2026, 4, 6, 10, 30, 0),
      outputPath: outputFile.path,
    );
    final secondTask = LongRunningTask(
      id: 'task-2',
      type: LongRunningTaskType.synthesizeSpeech,
      label: 'speech-2',
      startedAt: DateTime(2026, 4, 6, 11, 0, 0),
      status: LongRunningTaskStatus.completed,
      inputCharacterCount: 200000,
      modelName: 'Demo Model',
      finishedAt: DateTime(2026, 4, 6, 11, 10, 0),
      outputPath: outputFile.path,
    );

    await store.updateStatisticsForTask(firstTask, outputSecondsOverride: 3600);
    await store.updateStatisticsForTask(
      secondTask,
      outputSecondsOverride: 1200,
    );

    final statistics = await store.loadStatistics();
    final demoStats = statistics['Demo Model'];

    expect(demoStats, isNotNull);
    expect(demoStats!.totalChars, GeneratedAudioStatistics.charCap);
    expect(
      demoStats.generationSecondsPer100Chars,
      closeTo(0.2181818181818182, 0.000001),
    );
    expect(
      demoStats.outputSecondsPer100Chars,
      closeTo(0.43636363636363634, 0.000001),
    );
    expect(
      demoStats.generationTotalSeconds,
      closeTo(2181.818181818182, 0.000001),
    );
    expect(demoStats.outputTotalSeconds, closeTo(4363.636363636364, 0.000001));
  });

  test('generated audio store prunes records whose wav file is gone', () async {
    final tempDir = await Directory.systemTemp.createTemp('tts-core-test');
    addTearDown(() => tempDir.delete(recursive: true));

    final outputFile = File('${tempDir.path}/speech-1.wav');
    await outputFile.writeAsString('wav');

    final store = GeneratedAudioStore(
      libraryFile: File(
        '${tempDir.path}/${GeneratedAudioStore.defaultLibraryPath}',
      ),
      statsFile: File(
        '${tempDir.path}/${GeneratedAudioStore.defaultStatsPath}',
      ),
    );

    await store.upsertTask(
      LongRunningTask(
        id: 'task-1',
        type: LongRunningTaskType.synthesizeSpeech,
        label: 'speech-1',
        startedAt: DateTime(2026, 4, 6, 10, 0, 0),
        status: LongRunningTaskStatus.completed,
        inputCharacterCount: 200,
        finishedAt: DateTime(2026, 4, 6, 10, 0, 4),
        outputPath: outputFile.path,
      ),
    );

    await outputFile.delete();
    final loadedTasks = await store.loadTasks();

    expect(loadedTasks, isEmpty);

    final libraryPayload =
        jsonDecode(
              await File(
                '${tempDir.path}/${GeneratedAudioStore.defaultLibraryPath}',
              ).readAsString(),
            )
            as Map<String, Object?>;
    expect(libraryPayload['items'], isEmpty);
  });

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

  test('live text chunker rounds chunks up to sentence boundaries', () {
    final chunks = LiveTextChunker.splitText(
      'One two three. Four five six seven. Eight nine ten.',
      chunkSizeWords: 5,
    );

    expect(chunks, hasLength(2));
    expect(chunks.first.text, 'One two three. Four five six seven. ');
    expect(chunks.first.wordCount, 7);
    expect(chunks.last.text, 'Eight nine ten.');
    expect(chunks.last.wordCount, 3);
  });

  test('live text chunker can start from a later cursor offset', () {
    const text = 'Intro words. And then I continue here. Final sentence.';
    final startOffset = text.indexOf('And then I');
    final chunks = LiveTextChunker.splitText(
      text,
      chunkSizeWords: 3,
      startOffset: startOffset,
    );

    expect(chunks, hasLength(2));
    expect(chunks.first.text, 'And then I continue here. ');
    expect(chunks.first.startOffset, startOffset);
    expect(chunks.last.text, 'Final sentence.');
  });

  test(
    'live tts session keeps a ready chunk with two future generations',
    () async {
      final tempDir = await Directory.systemTemp.createTemp('live-tts-test');
      addTearDown(() => tempDir.delete(recursive: true));

      final factory = _RecordingExecutorFactory();
      final session = LiveTtsSession(
        executorFactory: factory.create,
        modelDir: '/tmp/demo-model',
        voice: _demoVoiceModel,
        text: 'One two. Three four. Five six. Seven eight.',
        speed: 1,
        speakerId: 0,
        chunkSizeWords: 2,
        outputDirectoryPath: tempDir.path,
      );
      addTearDown(session.dispose);

      await session.start();

      expect(factory.createdExecutors, hasLength(2));
      expect(
        factory.createdExecutors
            .map(
              (executor) => executor.submittedRequests.single.payload['text'],
            )
            .toList(growable: false),
        ['One two.', 'Three four.'],
      );

      final firstExecutor = factory.createdExecutors[0];
      final secondExecutor = factory.createdExecutors[1];
      final firstTaskId = firstExecutor.submittedRequests.single.taskId;
      final secondTaskId = secondExecutor.submittedRequests.single.taskId;

      firstExecutor.completeTask(
        firstTaskId,
        LongRunningTaskType.synthesizeSpeech,
        outputPath: '${tempDir.path}/chunk-1.wav',
      );
      await Future<void>.delayed(Duration.zero);

      session.markChunkPlaying(0);
      expect(firstExecutor.submittedRequests.last.payload['text'], 'Five six.');

      secondExecutor.completeTask(
        secondTaskId,
        LongRunningTaskType.synthesizeSpeech,
        outputPath: '${tempDir.path}/chunk-2.wav',
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        secondExecutor.submittedRequests.last.payload['text'],
        'Seven eight.',
      );
      expect(
        session.chunks.map((chunk) => chunk.status).toList(growable: false),
        [
          LiveTtsChunkStatus.playing,
          LiveTtsChunkStatus.ready,
          LiveTtsChunkStatus.generating,
          LiveTtsChunkStatus.generating,
        ],
      );
    },
  );

  test('live tts session submits only text after the caret offset', () async {
    final tempDir = await Directory.systemTemp.createTemp('live-tts-test');
    addTearDown(() => tempDir.delete(recursive: true));

    final factory = _RecordingExecutorFactory();
    const text = 'Intro words. And then I continue here. Final sentence.';
    final session = LiveTtsSession(
      executorFactory: factory.create,
      modelDir: '/tmp/demo-model',
      voice: _demoVoiceModel,
      text: text,
      speed: 1,
      speakerId: 0,
      chunkSizeWords: 3,
      outputDirectoryPath: tempDir.path,
      startOffset: text.indexOf('And then I'),
    );
    addTearDown(session.dispose);

    await session.start();

    expect(factory.createdExecutors, hasLength(2));
    expect(
      factory.createdExecutors
          .map((executor) => executor.submittedRequests.single.payload['text'])
          .toList(growable: false),
      ['And then I continue here.', 'Final sentence.'],
    );
    expect(session.chunks.first.startOffset, text.indexOf('And then I'));
  });

  test('live tts session caps the ready buffer at four chunks', () async {
    final tempDir = await Directory.systemTemp.createTemp('live-tts-test');
    addTearDown(() => tempDir.delete(recursive: true));

    final factory = _RecordingExecutorFactory();
    final session = LiveTtsSession(
      executorFactory: factory.create,
      modelDir: '/tmp/demo-model',
      voice: _demoVoiceModel,
      text:
          'One two. Three four. Five six. Seven eight. Nine ten. Eleven twelve.',
      speed: 1,
      speakerId: 0,
      chunkSizeWords: 2,
      outputDirectoryPath: tempDir.path,
    );
    addTearDown(session.dispose);

    await session.start();

    final firstExecutor = factory.createdExecutors[0];
    final secondExecutor = factory.createdExecutors[1];

    firstExecutor.completeTask(
      firstExecutor.submittedRequests[0].taskId,
      LongRunningTaskType.synthesizeSpeech,
      outputPath: '${tempDir.path}/chunk-1.wav',
    );
    await Future<void>.delayed(Duration.zero);

    secondExecutor.completeTask(
      secondExecutor.submittedRequests[0].taskId,
      LongRunningTaskType.synthesizeSpeech,
      outputPath: '${tempDir.path}/chunk-2.wav',
    );
    await Future<void>.delayed(Duration.zero);

    firstExecutor.completeTask(
      firstExecutor.submittedRequests[1].taskId,
      LongRunningTaskType.synthesizeSpeech,
      outputPath: '${tempDir.path}/chunk-3.wav',
    );
    await Future<void>.delayed(Duration.zero);

    secondExecutor.completeTask(
      secondExecutor.submittedRequests[1].taskId,
      LongRunningTaskType.synthesizeSpeech,
      outputPath: '${tempDir.path}/chunk-4.wav',
    );
    await Future<void>.delayed(Duration.zero);

    expect(
      firstExecutor.submittedRequests
          .map((request) => request.payload['text'])
          .toList(growable: false),
      ['One two.', 'Five six.'],
    );
    expect(
      secondExecutor.submittedRequests
          .map((request) => request.payload['text'])
          .toList(growable: false),
      ['Three four.', 'Seven eight.'],
    );
    expect(session.readyChunkCount, liveTtsReadyBufferMax);
    expect(session.generatingChunkCount, 0);
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

  void completeTask(
    String taskId,
    LongRunningTaskType type, {
    String? outputPath,
  }) {
    _controller.add(
      TaskResult(
        taskId: taskId,
        type: type,
        status: TaskResultStatus.completed,
        outputPath: outputPath,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
  }
}

class _RecordingExecutorFactory {
  final List<_FakeBackgroundTaskExecutor> createdExecutors =
      <_FakeBackgroundTaskExecutor>[];

  BackgroundTaskExecutor create() {
    final executor = _FakeBackgroundTaskExecutor();
    createdExecutors.add(executor);
    return executor;
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
