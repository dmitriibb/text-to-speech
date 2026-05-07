enum LongRunningTaskType { synthesizeSpeech, preloadModel, installModel }

enum LongRunningTaskStatus {
  queued,
  running,
  cancelling,
  completed,
  failed,
  cancelled,
}

class LongRunningTask {
  const LongRunningTask({
    required this.id,
    required this.type,
    required this.label,
    required this.startedAt,
    required this.status,
    this.statusText,
    this.progress,
    this.transferredBytes,
    this.totalBytes,
    this.errorMessage,
    this.inputCharacterCount,
    this.speechSpeed,
    this.modelId,
    this.modelName,
    this.finishedAt,
    this.outputPath,
  });

  final String id;
  final LongRunningTaskType type;
  final String label;
  final DateTime startedAt;
  final LongRunningTaskStatus status;
  final String? statusText;
  final double? progress;
  final int? transferredBytes;
  final int? totalBytes;
  final String? errorMessage;
  final int? inputCharacterCount;
  final double? speechSpeed;
  final String? modelId;
  final String? modelName;
  final DateTime? finishedAt;
  final String? outputPath;

  bool get isActive =>
      status == LongRunningTaskStatus.queued ||
      status == LongRunningTaskStatus.running ||
      status == LongRunningTaskStatus.cancelling;

  bool get canCancel =>
      status == LongRunningTaskStatus.queued ||
      status == LongRunningTaskStatus.running;

  bool get hasPlayableAudio =>
      type == LongRunningTaskType.synthesizeSpeech &&
      status == LongRunningTaskStatus.completed &&
      outputPath != null &&
      outputPath!.trim().isNotEmpty;

  bool get hasExpandableDetails =>
      type == LongRunningTaskType.installModel ||
      errorMessage != null ||
      hasPlayableAudio;

  LongRunningTask copyWith({
    LongRunningTaskType? type,
    String? label,
    DateTime? startedAt,
    LongRunningTaskStatus? status,
    Object? statusText = _sentinel,
    Object? progress = _sentinel,
    Object? transferredBytes = _sentinel,
    Object? totalBytes = _sentinel,
    Object? errorMessage = _sentinel,
    Object? inputCharacterCount = _sentinel,
    Object? speechSpeed = _sentinel,
    Object? modelId = _sentinel,
    Object? modelName = _sentinel,
    Object? finishedAt = _sentinel,
    Object? outputPath = _sentinel,
  }) {
    return LongRunningTask(
      id: id,
      type: type ?? this.type,
      label: label ?? this.label,
      startedAt: startedAt ?? this.startedAt,
      status: status ?? this.status,
      statusText: identical(statusText, _sentinel)
          ? this.statusText
          : statusText as String?,
      progress: identical(progress, _sentinel)
          ? this.progress
          : progress as double?,
      transferredBytes: identical(transferredBytes, _sentinel)
          ? this.transferredBytes
          : transferredBytes as int?,
      totalBytes: identical(totalBytes, _sentinel)
          ? this.totalBytes
          : totalBytes as int?,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      inputCharacterCount: identical(inputCharacterCount, _sentinel)
          ? this.inputCharacterCount
          : inputCharacterCount as int?,
      speechSpeed: identical(speechSpeed, _sentinel)
          ? this.speechSpeed
          : speechSpeed as double?,
      modelId: identical(modelId, _sentinel) ? this.modelId : modelId as String?,
      modelName: identical(modelName, _sentinel)
          ? this.modelName
          : modelName as String?,
      finishedAt: identical(finishedAt, _sentinel)
          ? this.finishedAt
          : finishedAt as DateTime?,
      outputPath: identical(outputPath, _sentinel)
          ? this.outputPath
          : outputPath as String?,
    );
  }
}

class TaskRequest {
  const TaskRequest({
    required this.taskId,
    required this.type,
    required this.payload,
  });

  final String taskId;
  final LongRunningTaskType type;
  final Map<String, Object?> payload;

  Map<String, Object?> toMap() {
    return {
      'taskId': taskId,
      'type': type.name,
      'payload': payload,
    };
  }

  factory TaskRequest.fromMap(Map<Object?, Object?> map) {
    return TaskRequest(
      taskId: map['taskId'] as String? ?? '',
      type: _taskTypeFromName(map['type'] as String?),
      payload: map['payload'] is Map
          ? Map<String, Object?>.from(
              map['payload'] as Map<Object?, Object?>,
            )
          : <String, Object?>{},
    );
  }
}

class TaskResult {
  const TaskResult({
    required this.taskId,
    required this.type,
    required this.status,
    this.outputPath,
    this.errorMessage,
  });

  final String taskId;
  final LongRunningTaskType type;
  final TaskResultStatus status;
  final String? outputPath;
  final String? errorMessage;

  Map<String, Object?> toMap() {
    return {
      'taskId': taskId,
      'type': type.name,
      'status': status.name,
      'outputPath': outputPath,
      'errorMessage': errorMessage,
    };
  }

  factory TaskResult.fromMap(Map<Object?, Object?> map) {
    return TaskResult(
      taskId: map['taskId'] as String? ?? '',
      type: _taskTypeFromName(map['type'] as String?),
      status: _taskResultStatusFromName(map['status'] as String?),
      outputPath: map['outputPath'] as String?,
      errorMessage: map['errorMessage'] as String?,
    );
  }
}

enum TaskResultStatus { completed, failed, cancelled }

const Object _sentinel = Object();

LongRunningTaskType _taskTypeFromName(String? name) {
  return LongRunningTaskType.values.firstWhere(
    (value) => value.name == name,
    orElse: () => LongRunningTaskType.synthesizeSpeech,
  );
}

TaskResultStatus _taskResultStatusFromName(String? name) {
  return TaskResultStatus.values.firstWhere(
    (value) => value.name == name,
    orElse: () => TaskResultStatus.failed,
  );
}
