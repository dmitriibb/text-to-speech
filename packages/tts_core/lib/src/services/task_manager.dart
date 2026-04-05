import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/long_running_task.dart';
import '../models/voice_model.dart';
import 'background_task_executor.dart';
import 'voice_model_task_payload.dart';

class TaskManager extends ChangeNotifier {
  TaskManager({required BackgroundTaskExecutor executor})
    : _executor = executor;

  final BackgroundTaskExecutor _executor;
  final Map<String, LongRunningTask> _tasks = {};
  int _speechCounter = 0;
  int _modelLoadCounter = 0;
  Timer? _ticker;
  StreamSubscription<TaskResult>? _resultsSub;
  bool _initialized = false;

  List<LongRunningTask> get tasks {
    final list = _tasks.values.toList(growable: false);
    list.sort((a, b) {
      final startedAtComparison = b.startedAt.compareTo(a.startedAt);
      if (startedAtComparison != 0) {
        return startedAtComparison;
      }

      final ap = _statusPriority(a.status);
      final bp = _statusPriority(b.status);
      if (ap != bp) {
        return ap.compareTo(bp);
      }

      return b.id.compareTo(a.id);
    });
    return list;
  }

  List<LongRunningTask> get activeTasks =>
      tasks.where((t) => t.isActive).toList(growable: false);

  bool get hasActiveTasks => _tasks.values.any((t) => t.isActive);

  bool get hasActiveSynthesisTasks => _tasks.values.any(
    (t) => t.type == LongRunningTaskType.synthesizeSpeech && t.isActive,
  );

  LongRunningTask? get activeInstallTask {
    for (final task in tasks) {
      if (task.type == LongRunningTaskType.installModel && task.isActive) {
        return task;
      }
    }
    return null;
  }

  LongRunningTask? get latestCompletedSynthesis {
    LongRunningTask? latest;
    for (final task in _tasks.values) {
      if (task.hasPlayableAudio) {
        if (latest == null || task.startedAt.isAfter(latest.startedAt)) {
          latest = task;
        }
      }
    }
    return latest;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _resultsSub = _executor.results.listen(_handleResult);
    await _executor.initialize();
    _initialized = true;
  }

  Future<String> submitSynthesis({
    required String modelDir,
    required VoiceModel voice,
    required String text,
    required double speed,
    required int speakerId,
    required String outputPath,
    String? providerOverride,
  }) async {
    _speechCounter++;
    final task = LongRunningTask(
      id: _nextTaskId(),
      type: LongRunningTaskType.synthesizeSpeech,
      label: 'speech-$_speechCounter',
      startedAt: DateTime.now(),
      status: LongRunningTaskStatus.queued,
    );

    _tasks[task.id] = task;
    _startTicker();
    notifyListeners();

    await _executor.submit(
      TaskRequest(
        taskId: task.id,
        type: task.type,
        payload: {
          ..._buildModelPayload(
            modelDir: modelDir,
            voice: voice,
            providerOverride: providerOverride,
          ),
          'text': text,
          'speed': speed,
          'speakerId': speakerId,
          'outputPath': outputPath,
        },
      ),
    );

    return task.id;
  }

  /// Submits a voice-cloning synthesis task (Pocket TTS with reference audio).
  Future<String> submitClonedSynthesis({
    required String modelDir,
    required VoiceModel voice,
    required String text,
    required double speed,
    required String outputPath,
    required Float32List referenceAudio,
    required int referenceSampleRate,
    String? providerOverride,
  }) async {
    _speechCounter++;
    final task = LongRunningTask(
      id: _nextTaskId(),
      type: LongRunningTaskType.synthesizeSpeech,
      label: 'cloned-speech-$_speechCounter',
      startedAt: DateTime.now(),
      status: LongRunningTaskStatus.queued,
    );

    _tasks[task.id] = task;
    _startTicker();
    notifyListeners();

    await _executor.submit(
      TaskRequest(
        taskId: task.id,
        type: task.type,
        payload: {
          ..._buildModelPayload(
            modelDir: modelDir,
            voice: voice,
            providerOverride: providerOverride,
          ),
          'text': text,
          'speed': speed,
          'speakerId': 0,
          'outputPath': outputPath,
          'useReferenceAudio': true,
          'referenceAudio': referenceAudio,
          'referenceSampleRate': referenceSampleRate,
        },
      ),
    );

    return task.id;
  }

  Future<String> submitModelPreload({
    required String modelDir,
    required VoiceModel voice,
    String? providerOverride,
  }) async {
    _modelLoadCounter++;
    final task = LongRunningTask(
      id: _nextTaskId(),
      type: LongRunningTaskType.preloadModel,
      label: 'model-loading-$_modelLoadCounter',
      startedAt: DateTime.now(),
      status: LongRunningTaskStatus.queued,
    );

    _tasks[task.id] = task;
    _startTicker();
    notifyListeners();

    await _executor.submit(
      TaskRequest(
        taskId: task.id,
        type: task.type,
        payload: _buildModelPayload(
          modelDir: modelDir,
          voice: voice,
          providerOverride: providerOverride,
        ),
      ),
    );

    return task.id;
  }

  String startModelInstall({required String label, String? statusText}) {
    final task = LongRunningTask(
      id: _nextTaskId(),
      type: LongRunningTaskType.installModel,
      label: label,
      startedAt: DateTime.now(),
      status: LongRunningTaskStatus.running,
      statusText: statusText,
    );

    _tasks[task.id] = task;
    _startTicker();
    notifyListeners();
    return task.id;
  }

  void updateInstallTask(
    String taskId, {
    String? statusText,
    double? progress,
    int? transferredBytes,
    int? totalBytes,
  }) {
    final task = _tasks[taskId];
    if (task == null || task.type != LongRunningTaskType.installModel) {
      return;
    }

    _tasks[taskId] = task.copyWith(
      status: LongRunningTaskStatus.running,
      statusText: statusText,
      progress: progress,
      transferredBytes: transferredBytes,
      totalBytes: totalBytes,
    );
    notifyListeners();
  }

  void markInstallTaskCancelling(String taskId, {String? statusText}) {
    final task = _tasks[taskId];
    if (task == null || task.type != LongRunningTaskType.installModel) {
      return;
    }

    _tasks[taskId] = task.copyWith(
      status: LongRunningTaskStatus.cancelling,
      statusText: statusText,
    );
    notifyListeners();
  }

  void completeInstallTask(
    String taskId, {
    String? statusText,
    double? progress = 1.0,
    int? transferredBytes,
    int? totalBytes,
  }) {
    final task = _tasks[taskId];
    if (task == null || task.type != LongRunningTaskType.installModel) {
      return;
    }

    _tasks[taskId] = task.copyWith(
      status: LongRunningTaskStatus.completed,
      finishedAt: DateTime.now(),
      statusText: statusText,
      progress: progress,
      transferredBytes: transferredBytes,
      totalBytes: totalBytes,
    );
    _stopTickerIfIdle();
    notifyListeners();
  }

  void failInstallTask(
    String taskId, {
    required String errorMessage,
    String? statusText,
    double? progress,
    int? transferredBytes,
    int? totalBytes,
  }) {
    final task = _tasks[taskId];
    if (task == null || task.type != LongRunningTaskType.installModel) {
      return;
    }

    _tasks[taskId] = task.copyWith(
      status: LongRunningTaskStatus.failed,
      finishedAt: DateTime.now(),
      errorMessage: errorMessage,
      statusText: statusText,
      progress: progress,
      transferredBytes: transferredBytes,
      totalBytes: totalBytes,
    );
    _stopTickerIfIdle();
    notifyListeners();
  }

  void cancelInstallTask(
    String taskId, {
    String? statusText,
    int? transferredBytes,
    int? totalBytes,
  }) {
    final task = _tasks[taskId];
    if (task == null || task.type != LongRunningTaskType.installModel) {
      return;
    }

    _tasks[taskId] = task.copyWith(
      status: LongRunningTaskStatus.cancelled,
      finishedAt: DateTime.now(),
      statusText: statusText,
      transferredBytes: transferredBytes,
      totalBytes: totalBytes,
    );
    _stopTickerIfIdle();
    notifyListeners();
  }

  Future<void> cancelTask(String taskId) async {
    final task = _tasks[taskId];
    if (task == null || !task.canCancel) return;

    _tasks[taskId] = task.copyWith(status: LongRunningTaskStatus.cancelling);
    notifyListeners();

    _executor.requestCancel(taskId);
  }

  void cancelAllActiveTasks() {
    var changed = false;

    for (final task in _tasks.values.toList(growable: false)) {
      if (!task.canCancel) {
        continue;
      }

      _tasks[task.id] = task.copyWith(status: LongRunningTaskStatus.cancelling);
      _executor.requestCancel(task.id);
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }

  void dismissTask(String taskId) {
    final task = _tasks[taskId];
    if (task == null || task.isActive) return;
    _tasks.remove(taskId);
    _stopTickerIfIdle();
    notifyListeners();
  }

  String formatElapsed(LongRunningTask task) {
    final endTime = task.finishedAt ?? DateTime.now();
    final totalSeconds = endTime.difference(task.startedAt).inSeconds;
    final seconds = totalSeconds < 0 ? 0 : totalSeconds;
    if (seconds < 60) return '${seconds}s';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  String describeStatus(LongRunningTask task) {
    if (task.statusText != null && task.statusText!.trim().isNotEmpty) {
      return task.statusText!;
    }

    switch (task.status) {
      case LongRunningTaskStatus.queued:
        return 'Queued';
      case LongRunningTaskStatus.running:
        return 'Running';
      case LongRunningTaskStatus.cancelling:
        return 'Cancelling';
      case LongRunningTaskStatus.completed:
        return 'Completed';
      case LongRunningTaskStatus.failed:
        return 'Failed';
      case LongRunningTaskStatus.cancelled:
        return 'Cancelled';
    }
  }

  @override
  void dispose() {
    cancelAllActiveTasks();
    _ticker?.cancel();
    unawaited(_resultsSub?.cancel());
    _executor.dispose();
    super.dispose();
  }

  // ---- Private ----

  void _handleResult(TaskResult result) {
    final task = _tasks[result.taskId];
    if (task == null) return;

    switch (result.status) {
      case TaskResultStatus.completed:
        _tasks[result.taskId] = task.copyWith(
          status: LongRunningTaskStatus.completed,
          finishedAt: DateTime.now(),
          outputPath: result.outputPath,
        );
      case TaskResultStatus.failed:
        _tasks[result.taskId] = task.copyWith(
          status: LongRunningTaskStatus.failed,
          finishedAt: DateTime.now(),
          errorMessage: result.errorMessage,
        );
      case TaskResultStatus.cancelled:
        _tasks[result.taskId] = task.copyWith(
          status: LongRunningTaskStatus.cancelled,
          finishedAt: DateTime.now(),
        );
    }

    _stopTickerIfIdle();
    notifyListeners();
  }

  void _startTicker() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
  }

  void _stopTickerIfIdle() {
    if (!hasActiveTasks) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  String _nextTaskId() {
    return 'task-${DateTime.now().microsecondsSinceEpoch}';
  }

  Map<String, Object?> _buildModelPayload({
    required String modelDir,
    required VoiceModel voice,
    String? providerOverride,
  }) {
    return VoiceModelTaskPayload.build(
      modelDir: modelDir,
      voice: voice,
      providerOverride: providerOverride,
    );
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
        return 3;
      case LongRunningTaskStatus.failed:
        return 4;
      case LongRunningTaskStatus.cancelled:
        return 5;
    }
  }
}
