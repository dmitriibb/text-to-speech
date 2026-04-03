import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:tts_core/tts_core.dart';

import '../models/long_running_task.dart';
import 'long_running_task_handler.dart';

class LongRunningTaskService extends ChangeNotifier {
  final Map<String, LongRunningTask> _activeTasks = <String, LongRunningTask>{};
  final StreamController<LongRunningTaskResult> _resultsController =
      StreamController<LongRunningTaskResult>.broadcast();

  bool _initialized = false;

  List<LongRunningTask> get activeTasks {
    final tasks = _activeTasks.values.toList(growable: false);
    tasks.sort((left, right) {
      final leftPriority = _statusPriority(left.status);
      final rightPriority = _statusPriority(right.status);
      if (leftPriority != rightPriority) {
        return leftPriority.compareTo(rightPriority);
      }
      return left.startedAt.compareTo(right.startedAt);
    });
    return tasks;
  }

  Stream<LongRunningTaskResult> get results => _resultsController.stream;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    FlutterForegroundTask.addTaskDataCallback(_handleTaskData);
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'tts_background_tasks',
        channelName: 'Background speech tasks',
        channelDescription:
            'Shows background local speech generation and model loading tasks.',
        onlyAlertOnce: true,
        playSound: false,
        enableVibration: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
        allowAutoRestart: false,
      ),
    );

    _initialized = true;

    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask(
        const {commandTypeKey: commandRequestSnapshot},
      );
    }
  }

  Future<String> submitModelPreload({
    required String modelDir,
    required VoiceModel voice,
  }) async {
    final task = LongRunningTask(
      id: _nextTaskId(),
      type: LongRunningTaskType.preloadModel,
      label: 'Load ${voice.displayName}',
      startedAt: DateTime.now(),
      status: LongRunningTaskStatus.queued,
    );
    await _submitTask(
      task,
      _buildModelPayload(modelDir: modelDir, voice: voice),
    );
    return task.id;
  }

  Future<String> submitSpeechSynthesis({
    required String modelDir,
    required VoiceModel voice,
    required String text,
    required double speed,
    required int speakerId,
    required String outputPath,
  }) async {
    final task = LongRunningTask(
      id: _nextTaskId(),
      type: LongRunningTaskType.synthesizeSpeech,
      label: 'Generate ${voice.displayName}',
      startedAt: DateTime.now(),
      status: LongRunningTaskStatus.queued,
    );

    final payload = _buildModelPayload(modelDir: modelDir, voice: voice)
      ..addAll({
        'text': text,
        'speed': speed,
        'speakerId': speakerId,
        'outputPath': outputPath,
      });

    await _submitTask(task, payload);
    return task.id;
  }

  Future<void> cancelTask(String taskId) async {
    if (!_activeTasks.containsKey(taskId)) {
      return;
    }

    final task = _activeTasks[taskId]!;
    _activeTasks[taskId] = task.copyWith(
      status: LongRunningTaskStatus.cancelling,
    );
    notifyListeners();

    await _ensureServiceRunning();
    FlutterForegroundTask.sendDataToTask({
      commandTypeKey: commandCancelTask,
      taskIdKey: taskId,
    });
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_handleTaskData);
    unawaited(_resultsController.close());
    super.dispose();
  }

  Future<void> _submitTask(
    LongRunningTask task,
    Map<String, Object?> payload,
  ) async {
    await _ensureServiceRunning();

    _activeTasks[task.id] = task;
    notifyListeners();

    FlutterForegroundTask.sendDataToTask({
      commandTypeKey: commandEnqueueTask,
      taskKey: task.toMap(),
      payloadKey: payload,
    });
  }

  Future<void> _ensureServiceRunning() async {
    final permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
      final refreshedPermission =
          await FlutterForegroundTask.checkNotificationPermission();
      if (refreshedPermission != NotificationPermission.granted) {
        throw StateError(
          'Notification permission is required to run background speech tasks.',
        );
      }
    }

    if (await FlutterForegroundTask.isRunningService) {
      return;
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: 3104,
      serviceTypes: const [ForegroundServiceTypes.mediaProcessing],
      notificationTitle: taskServiceNotificationTitle,
      notificationText: taskServiceIdleNotificationText,
      callback: startLongRunningTaskHandler,
    );

    if (result is ServiceRequestFailure) {
      final error = result.error;
      throw Exception('Failed to start background task service: $error');
    }
  }

  void _handleTaskData(Object data) {
    if (data is! Map<Object?, Object?>) {
      return;
    }

    switch (data[eventKey]) {
      case eventSnapshot:
        final tasksData = data['tasks'];
        if (tasksData is! List<Object?>) {
          return;
        }

        _activeTasks
          ..clear()
          ..addEntries(
            tasksData.whereType<Map<Object?, Object?>>().map((taskMap) {
              final task = LongRunningTask.fromMap(taskMap);
              return MapEntry(task.id, task);
            }),
          );
        notifyListeners();
        return;
      case eventTaskResult:
        final resultData = data['result'];
        if (resultData is! Map<Object?, Object?>) {
          return;
        }

        final result = LongRunningTaskResult.fromMap(resultData);
        _activeTasks.remove(result.taskId);
        _resultsController.add(result);
        notifyListeners();
        return;
    }
  }

  Map<String, Object?> _buildModelPayload({
    required String modelDir,
    required VoiceModel voice,
  }) {
    return {
      'cacheKey': '${voice.id}::$modelDir',
      'modelId': voice.id,
      'displayName': voice.displayName,
      'family': voice.family,
      'runtime': voice.runtime,
      'installDirName': voice.installDirName,
      'modelDir': modelDir,
      'modelFile': voice.modelFile,
      'tokensFile': voice.tokensFile,
      'lexiconFile': voice.lexiconFile,
      'dataDir': voice.dataDir,
      'provider': voice.provider,
      'numThreads': voice.numThreads,
      'speakerId': voice.defaultSpeakerId,
      'maxNumSentences': voice.maxNumSentences,
    };
  }

  String _nextTaskId() {
    return 'task-${DateTime.now().microsecondsSinceEpoch}';
  }

  int _statusPriority(LongRunningTaskStatus status) {
    switch (status) {
      case LongRunningTaskStatus.running:
        return 0;
      case LongRunningTaskStatus.cancelling:
        return 1;
      case LongRunningTaskStatus.queued:
        return 2;
    }
  }
}