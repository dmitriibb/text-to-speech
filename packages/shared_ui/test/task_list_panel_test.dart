import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';
import 'package:tts_core/tts_core.dart';

void main() {
  testWidgets('generation estimate summary hides empty estimates', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: GenerationEstimateSummary())),
    );

    expect(find.textContaining('Expected generation time:'), findsNothing);
    expect(find.textContaining('Expected audio length:'), findsNothing);
  });

  testWidgets('generation estimate summary formats seconds and minutes', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GenerationEstimateSummary(
            expectedGenerationDuration: Duration(seconds: 30),
            expectedOutputDuration: Duration(minutes: 3, seconds: 15),
          ),
        ),
      ),
    );

    expect(find.text('Expected generation time: 30 sec'), findsOneWidget);
    expect(find.text('Expected audio length: 3:15'), findsOneWidget);
  });

  testWidgets('playing task row shows a pause button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AudioPlaybackControls(
            isPlaying: true,
            position: Duration(seconds: 2),
            duration: Duration(seconds: 5),
            onTogglePlayback: _noop,
          ),
        ),
      ),
    );

    expect(find.text('Pause'), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsOneWidget);
  });

  testWidgets(
    'dismissing generated audio pauses playback before confirmation',
    (tester) async {
      final executor = _FakeBackgroundTaskExecutor();
      final manager = TaskManager(executor: executor);
      addTearDown(manager.dispose);

      await manager.initialize();
      final taskId = await manager.submitSynthesis(
        modelDir: '/tmp/model',
        voice: _voiceModel,
        text: 'hello',
        speed: 1,
        speakerId: 0,
        outputPath: '/tmp/output.wav',
      );
      executor.emit(
        TaskResult(
          taskId: taskId,
          type: LongRunningTaskType.synthesizeSpeech,
          status: TaskResultStatus.completed,
          outputPath: '/tmp/output.wav',
        ),
      );
      await tester.pump();

      var pauseCalls = 0;
      LongRunningTask? dismissedTask;

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<TaskManager>.value(
            value: manager,
            child: Scaffold(
              body: TaskListPanel(
                playbackInfo: TaskPlaybackInfo(
                  playingTaskId: taskId,
                  activeTaskId: taskId,
                  isPlaying: true,
                  position: const Duration(seconds: 1),
                  duration: const Duration(seconds: 3),
                ),
                onPausePlayback: () async {
                  pauseCalls++;
                },
                onDismissTask: (task) async {
                  dismissedTask = task;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();

      expect(pauseCalls, 1);
      expect(find.text('Remove generated audio?'), findsOneWidget);
      expect(dismissedTask, isNull);

      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();

      expect(dismissedTask, isNull);

      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(pauseCalls, 2);
      expect(dismissedTask?.id, taskId);
    },
  );

  testWidgets('clearing all tasks pauses playback and requires confirmation', (
    tester,
  ) async {
    final manager = TaskManager(executor: _FakeBackgroundTaskExecutor());
    addTearDown(manager.dispose);
    manager.restoreTasks([
      LongRunningTask(
        id: 'restored-speech-1',
        type: LongRunningTaskType.synthesizeSpeech,
        label: 'speech-1',
        startedAt: DateTime(2026, 4, 6, 10, 0, 0),
        status: LongRunningTaskStatus.completed,
        finishedAt: DateTime(2026, 4, 6, 10, 0, 3),
        outputPath: '/tmp/output.wav',
      ),
    ]);
    var pauseCalls = 0;
    var clearCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<TaskManager>.value(
          value: manager,
          child: Scaffold(
            body: TaskListPanel(
              playbackInfo: TaskPlaybackInfo(),
              onPausePlayback: () async {
                pauseCalls++;
              },
              onClearAllTasks: () async {
                clearCalls++;
                await manager.clearAllTasks();
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();

    expect(pauseCalls, 1);
    expect(find.text('Clear all tasks?'), findsOneWidget);
    expect(clearCalls, 0);

    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(clearCalls, 0);

    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Clear all'));
    await tester.pumpAndSettle();

    expect(clearCalls, 1);
    expect(manager.tasks, isEmpty);
  });

  testWidgets('expanded generated audio row shows model and duration', (
    tester,
  ) async {
    final manager = TaskManager(executor: _FakeBackgroundTaskExecutor());
    addTearDown(manager.dispose);

    manager.restoreTasks([
      LongRunningTask(
        id: 'restored-speech-1',
        type: LongRunningTaskType.synthesizeSpeech,
        label: 'speech-1',
        startedAt: DateTime(2026, 4, 6, 10, 0, 0),
        status: LongRunningTaskStatus.completed,
        modelName: 'Test Voice',
        finishedAt: DateTime(2026, 4, 6, 10, 0, 3),
        outputPath: '/tmp/output.wav',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<TaskManager>.value(
          value: manager,
          child: const Scaffold(
            body: TaskListPanel(playbackInfo: TaskPlaybackInfo()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('speech-1'));
    await tester.pumpAndSettle();

    expect(find.text('Generated in 3s'), findsOneWidget);
    expect(find.text('Model: Test Voice'), findsOneWidget);
  });
}

void _noop() {}

const _voiceModel = VoiceModel(
  id: 'test-voice',
  displayName: 'Test Voice',
  family: 'piper',
  runtime: 'sherpa-onnx',
  approvedForDistribution: false,
  archiveUrl: 'https://example.invalid/model.tar.gz',
  archiveFormat: 'tar.gz',
  installDirName: 'test-voice',
  modelFile: 'model.onnx',
  tokensFile: 'tokens.txt',
  lexiconFile: '',
  voicesFile: '',
  dataDir: '',
  provider: 'cpu',
  numThreads: 1,
  defaultSpeed: 1,
  defaultSpeakerId: 0,
  maxNumSentences: 1,
);

class _FakeBackgroundTaskExecutor implements BackgroundTaskExecutor {
  final StreamController<TaskResult> _controller =
      StreamController<TaskResult>.broadcast();

  @override
  Future<void> initialize() async {}

  @override
  Stream<TaskResult> get results => _controller.stream;

  @override
  Future<void> submit(TaskRequest request) async {}

  @override
  void requestCancel(String taskId) {}

  @override
  void dispose() {
    unawaited(_controller.close());
  }

  void emit(TaskResult result) {
    _controller.add(result);
  }
}
