import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:tts_core/tts_core.dart';

import 'long_running_task_handler.dart';

class AndroidTaskExecutor implements BackgroundTaskExecutor {
  final _resultsController = StreamController<TaskResult>.broadcast();
  bool _initialized = false;

  @override
  Stream<TaskResult> get results => _resultsController.stream;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

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
  }

  @override
  Future<void> submit(TaskRequest request) async {
    await _ensureServiceRunning();

    final task = LongRunningTask(
      id: request.taskId,
      type: request.type,
      label: request.taskId,
      startedAt: DateTime.now(),
      status: LongRunningTaskStatus.queued,
    );

    FlutterForegroundTask.sendDataToTask({
      commandTypeKey: commandEnqueueTask,
      taskKey: task.toMap(),
      payloadKey: request.payload,
    });
  }

  @override
  void requestCancel(String taskId) {
    FlutterForegroundTask.sendDataToTask({
      commandTypeKey: commandCancelTask,
      taskIdKey: taskId,
    });
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_handleTaskData);
    unawaited(FlutterForegroundTask.stopService());
    unawaited(_resultsController.close());
  }

  void _handleTaskData(Object data) {
    if (data is! Map<Object?, Object?>) return;

    switch (data[eventKey]) {
      case eventTaskResult:
        final resultData = data['result'];
        if (resultData is! Map<Object?, Object?>) return;

        final taskId = resultData['taskId']! as String;
        final type = LongRunningTaskTypeWire.fromWireName(
          resultData['type']! as String,
        );
        final statusStr = resultData['status']! as String;

        final TaskResultStatus status;
        switch (statusStr) {
          case 'completed':
            status = TaskResultStatus.completed;
          case 'failed':
            status = TaskResultStatus.failed;
          case 'cancelled':
            status = TaskResultStatus.cancelled;
          default:
            return;
        }

        _resultsController.add(TaskResult(
          taskId: taskId,
          type: type,
          status: status,
          outputPath: resultData['outputPath'] as String?,
          errorMessage: resultData['errorMessage'] as String?,
        ));
    }
  }

  Future<void> _ensureServiceRunning() async {
    final permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
      final refreshed =
          await FlutterForegroundTask.checkNotificationPermission();
      if (refreshed != NotificationPermission.granted) {
        throw StateError(
          'Notification permission is required to run background speech tasks.',
        );
      }
    }

    if (await FlutterForegroundTask.isRunningService) return;

    final result = await FlutterForegroundTask.startService(
      serviceId: 3104,
      serviceTypes: const [ForegroundServiceTypes.mediaProcessing],
      notificationTitle: taskServiceNotificationTitle,
      notificationText: taskServiceIdleNotificationText,
      callback: startLongRunningTaskHandler,
    );

    if (result is ServiceRequestFailure) {
      throw Exception(
        'Failed to start background task service: ${result.error}',
      );
    }
  }
}
