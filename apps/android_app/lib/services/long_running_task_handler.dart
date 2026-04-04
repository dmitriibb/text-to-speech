import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:path/path.dart' as p;
import 'package:tts_core/tts_core.dart';

const String commandTypeKey = 'command';
const String taskKey = 'task';
const String payloadKey = 'payload';
const String taskIdKey = 'taskId';
const String eventKey = 'event';

const String commandEnqueueTask = 'enqueue_task';
const String commandCancelTask = 'cancel_task';
const String commandRequestSnapshot = 'request_snapshot';

const String eventSnapshot = 'snapshot';
const String eventTaskResult = 'task_result';

const String taskServiceNotificationTitle = 'Text to Speech task running';
const String taskServiceIdleNotificationText = 'Preparing background speech work';

@pragma('vm:entry-point')
void startLongRunningTaskHandler() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  FlutterForegroundTask.setTaskHandler(LongRunningTaskHandler());
}

class LongRunningTaskHandler extends TaskHandler {
  final TtsService _ttsService = TtsService();
  final List<_QueuedTask> _queue = <_QueuedTask>[];
  final Map<String, LongRunningTask> _activeTasks = <String, LongRunningTask>{};
  final Set<String> _cancelRequestedTaskIds = <String>{};

  bool _isProcessing = false;
  String? _loadedModelCacheKey;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _ttsService.initBindings();
    _sendSnapshot();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _queue.clear();
    _activeTasks.clear();
    _cancelRequestedTaskIds.clear();
    _loadedModelCacheKey = null;
    _ttsService.dispose();
  }

  @override
  void onReceiveData(Object data) {
    if (data is! Map<Object?, Object?>) {
      return;
    }

    final command = data[commandTypeKey];
    if (command is! String) {
      return;
    }

    switch (command) {
      case commandEnqueueTask:
        final taskMap = data[taskKey];
        final payloadMap = data[payloadKey];
        if (taskMap is! Map<Object?, Object?> ||
            payloadMap is! Map<Object?, Object?>) {
          return;
        }
        _enqueueTask(
          _QueuedTask(
            task: LongRunningTask.fromMap(taskMap),
            payload: Map<String, Object?>.from(payloadMap),
          ),
        );
        return;
      case commandCancelTask:
        final taskId = data[taskIdKey];
        if (taskId is! String) {
          return;
        }
        _cancelTask(taskId);
        return;
      case commandRequestSnapshot:
        _sendSnapshot();
        return;
    }
  }

  void _enqueueTask(_QueuedTask queuedTask) {
    _queue.add(queuedTask);
    _activeTasks[queuedTask.task.id] = queuedTask.task;
    _sendSnapshot();
    unawaited(_processQueue());
  }

  void _cancelTask(String taskId) {
    final queueIndex = _queue.indexWhere((queuedTask) => queuedTask.task.id == taskId);
    if (queueIndex >= 0) {
      final cancelledTask = _queue.removeAt(queueIndex).task;
      _activeTasks.remove(taskId);
      _sendSnapshot();
      _sendResult(
        TaskResult(
          taskId: cancelledTask.id,
          type: cancelledTask.type,
          status: TaskResultStatus.cancelled,
        ),
      );
      return;
    }

    final activeTask = _activeTasks[taskId];
    if (activeTask == null) {
      return;
    }

    _cancelRequestedTaskIds.add(taskId);
    _activeTasks[taskId] = activeTask.copyWith(
      status: LongRunningTaskStatus.cancelling,
    );
    _sendSnapshot();
  }

  Future<void> _processQueue() async {
    if (_isProcessing) {
      return;
    }

    _isProcessing = true;
    try {
      while (_queue.isNotEmpty) {
        final queuedTask = _queue.removeAt(0);
        final taskId = queuedTask.task.id;

        if (_cancelRequestedTaskIds.remove(taskId)) {
          _activeTasks.remove(taskId);
          _sendSnapshot();
          _sendResult(
            TaskResult(
              taskId: taskId,
              type: queuedTask.task.type,
              status: TaskResultStatus.cancelled,
            ),
          );
          continue;
        }

        _activeTasks[taskId] = queuedTask.task.copyWith(
          status: LongRunningTaskStatus.running,
        );
        await _updateNotification(
          queuedTask.task.label,
          _buildNotificationText(queuedTask.task.label),
        );
        _sendSnapshot();

        try {
          final taskResult = await _runTask(queuedTask);
          final wasCancelled = _cancelRequestedTaskIds.remove(taskId);

          if (wasCancelled) {
            final outputPath = taskResult.outputPath;
            if (outputPath != null) {
              final outputFile = File(outputPath);
              if (await outputFile.exists()) {
                await outputFile.delete();
              }
            }

            _sendResult(
              TaskResult(
                taskId: taskId,
                type: queuedTask.task.type,
                status: TaskResultStatus.cancelled,
              ),
            );
          } else {
            _sendResult(taskResult);
          }
        } catch (error) {
          final wasCancelled = _cancelRequestedTaskIds.remove(taskId);
          _sendResult(
            TaskResult(
              taskId: taskId,
              type: queuedTask.task.type,
              status: wasCancelled
                  ? TaskResultStatus.cancelled
                  : TaskResultStatus.failed,
              errorMessage: wasCancelled ? null : error.toString(),
            ),
          );
        } finally {
          _activeTasks.remove(taskId);
          _sendSnapshot();
        }
      }
    } finally {
      _isProcessing = false;
      if (_activeTasks.isEmpty) {
        unawaited(FlutterForegroundTask.stopService());
      } else {
        await _updateNotification(
          taskServiceNotificationTitle,
          _buildNotificationText(taskServiceIdleNotificationText),
        );
      }
    }
  }

  Future<TaskResult> _runTask(_QueuedTask queuedTask) async {
    switch (queuedTask.task.type) {
      case LongRunningTaskType.preloadModel:
        await _ensureModelLoaded(queuedTask.payload);
        return TaskResult(
          taskId: queuedTask.task.id,
          type: queuedTask.task.type,
          status: TaskResultStatus.completed,
        );
      case LongRunningTaskType.synthesizeSpeech:
        await _ensureModelLoaded(queuedTask.payload);
        final result = _ttsService.synthesize(
          queuedTask.payload['text']! as String,
          speed: queuedTask.payload['speed']! as double,
          speakerId: queuedTask.payload['speakerId']! as int,
        );
        final outputPath = queuedTask.payload['outputPath']! as String;
        final outputDir = Directory(p.dirname(outputPath));
        await outputDir.create(recursive: true);
        final didSave = _ttsService.saveWav(result, outputPath);
        if (!didSave) {
          throw Exception('Failed to write WAV file');
        }

        return TaskResult(
          taskId: queuedTask.task.id,
          type: queuedTask.task.type,
          status: TaskResultStatus.completed,
          outputPath: outputPath,
        );
    }
  }

  Future<void> _ensureModelLoaded(Map<String, Object?> payload) async {
    final cacheKey = payload['cacheKey']! as String;
    if (_loadedModelCacheKey == cacheKey) {
      return;
    }

    final model = VoiceModel.fromJson({
      'id': payload['modelId'],
      'display_name': payload['displayName'],
      'family': payload['family'],
      'runtime': payload['runtime'],
      'status': const {
        'approved_for_distribution': false,
      },
      'source': const {
        'archive_url': '',
      },
      'install': {
        'archive_format': 'tar.bz2',
        'install_dir_name': payload['installDirName'],
      },
      'files': {
        'model': payload['modelFile'],
        'tokens': payload['tokensFile'],
        'lexicon': payload['lexiconFile'],
        'voices': payload['voicesFile'],
        'data_dir': payload['dataDir'],
      },
      'defaults': {
        'provider': payload['provider'],
        'num_threads': payload['numThreads'],
        'speed': 1.0,
        'speaker_id': payload['speakerId'],
        'max_num_sentences': payload['maxNumSentences'],
      },
    });

    _ttsService.loadModel(payload['modelDir']! as String, model);
    _loadedModelCacheKey = cacheKey;
  }

  Future<void> _updateNotification(String title, String text) async {
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  String _buildNotificationText(String currentLabel) {
    final queuedCount = _queue.length;
    if (queuedCount == 0) {
      return currentLabel;
    }

    return '$currentLabel • $queuedCount queued';
  }

  void _sendSnapshot() {
    final tasks = _activeTasks.values.toList()
      ..sort((left, right) {
        final leftPriority = _statusPriority(left.status);
        final rightPriority = _statusPriority(right.status);
        if (leftPriority != rightPriority) {
          return leftPriority.compareTo(rightPriority);
        }
        return left.startedAt.compareTo(right.startedAt);
      });

    FlutterForegroundTask.sendDataToMain({
      eventKey: eventSnapshot,
      'tasks': tasks.map((task) => task.toMap()).toList(growable: false),
    });
  }

  void _sendResult(TaskResult result) {
    FlutterForegroundTask.sendDataToMain({
      eventKey: eventTaskResult,
      'result': result.toMap(),
    });
  }

  int _statusPriority(LongRunningTaskStatus status) {
    switch (status) {
      case LongRunningTaskStatus.running:
        return 0;
      case LongRunningTaskStatus.cancelling:
        return 1;
      case LongRunningTaskStatus.queued:
        return 2;
      case LongRunningTaskStatus.completed:
      case LongRunningTaskStatus.failed:
      case LongRunningTaskStatus.cancelled:
        return 3;
    }
  }
}

class _QueuedTask {
  const _QueuedTask({
    required this.task,
    required this.payload,
  });

  final LongRunningTask task;
  final Map<String, Object?> payload;

  String? get modelId => payload['modelId'] as String?;
}