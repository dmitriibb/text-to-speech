import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/long_running_task.dart';
import 'tts_service.dart';

class GeneratedAudioStatistics {
  const GeneratedAudioStatistics({
    required this.generationSecondsPer100Chars,
    required this.outputSecondsPer100Chars,
    required this.totalChars,
    required this.generationTotalSeconds,
    required this.outputTotalSeconds,
  });

  static const int charCap = 1000000;

  final double generationSecondsPer100Chars;
  final double outputSecondsPer100Chars;
  final int totalChars;
  final double generationTotalSeconds;
  final double outputTotalSeconds;

  const GeneratedAudioStatistics.empty()
    : generationSecondsPer100Chars = 0,
      outputSecondsPer100Chars = 0,
      totalChars = 0,
      generationTotalSeconds = 0,
      outputTotalSeconds = 0;

  GeneratedAudioStatistics recordGeneration({
    required int inputCharacters,
    required double generationSeconds,
    required double outputSeconds,
  }) {
    if (inputCharacters <= 0) {
      return this;
    }

    var nextTotalChars = totalChars + inputCharacters;
    var nextGenerationTotalSeconds = generationTotalSeconds + generationSeconds;
    var nextOutputTotalSeconds = outputTotalSeconds + outputSeconds;

    var nextGenerationSecondsPer100Chars =
        nextGenerationTotalSeconds / nextTotalChars * 100;
    var nextOutputSecondsPer100Chars =
        nextOutputTotalSeconds / nextTotalChars * 100;

    if (nextTotalChars > charCap) {
      nextTotalChars = charCap;
      nextGenerationTotalSeconds =
          nextTotalChars / 100 * nextGenerationSecondsPer100Chars;
      nextOutputTotalSeconds =
          nextTotalChars / 100 * nextOutputSecondsPer100Chars;
    }

    if (nextTotalChars <= 0) {
      nextGenerationSecondsPer100Chars = 0;
      nextOutputSecondsPer100Chars = 0;
    }

    return GeneratedAudioStatistics(
      generationSecondsPer100Chars: nextGenerationSecondsPer100Chars,
      outputSecondsPer100Chars: nextOutputSecondsPer100Chars,
      totalChars: nextTotalChars,
      generationTotalSeconds: nextGenerationTotalSeconds,
      outputTotalSeconds: nextOutputTotalSeconds,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'generationSecondsPer100Chars': generationSecondsPer100Chars,
      'outputSecondsPer100Chars': outputSecondsPer100Chars,
      'totalChars': totalChars,
      'generationTotalSeconds': generationTotalSeconds,
      'outputTotalSeconds': outputTotalSeconds,
    };
  }

  factory GeneratedAudioStatistics.fromJson(Map<String, Object?> json) {
    return GeneratedAudioStatistics(
      generationSecondsPer100Chars:
          (json['generationSecondsPer100Chars'] as num?)?.toDouble() ?? 0,
      outputSecondsPer100Chars:
          (json['outputSecondsPer100Chars'] as num?)?.toDouble() ?? 0,
      totalChars: json['totalChars'] as int? ?? 0,
      generationTotalSeconds:
          (json['generationTotalSeconds'] as num?)?.toDouble() ?? 0,
      outputTotalSeconds: (json['outputTotalSeconds'] as num?)?.toDouble() ?? 0,
    );
  }
}

class GeneratedAudioRecord {
  const GeneratedAudioRecord({
    required this.taskId,
    required this.taskName,
    required this.outputPath,
    required this.startedAt,
    required this.finishedAt,
    this.inputCharacterCount,
    this.modelId,
    this.modelName,
  });

  final String taskId;
  final String taskName;
  final String outputPath;
  final DateTime startedAt;
  final DateTime finishedAt;
  final int? inputCharacterCount;
  final String? modelId;
  final String? modelName;

  Duration get generationDuration {
    final duration = finishedAt.difference(startedAt);
    return duration.isNegative ? Duration.zero : duration;
  }

  Map<String, Object?> toJson() {
    return {
      'taskId': taskId,
      'taskName': taskName,
      'timestamp': finishedAt.toIso8601String(),
      'startedAt': startedAt.toIso8601String(),
      'finishedAt': finishedAt.toIso8601String(),
      'generationDurationMs': generationDuration.inMilliseconds,
      'outputPath': outputPath,
      if (inputCharacterCount != null)
        'inputCharacterCount': inputCharacterCount,
      if (modelId != null) 'modelId': modelId,
      if (modelName != null) 'modelName': modelName,
    };
  }

  factory GeneratedAudioRecord.fromJson(Map<String, Object?> json) {
    final outputPath = json['outputPath'] as String?;
    if (outputPath == null || outputPath.trim().isEmpty) {
      throw const FormatException(
        'Generated audio record is missing outputPath.',
      );
    }

    final taskId = json['taskId'] as String?;
    final taskName = json['taskName'] as String?;
    final startedAtRaw = json['startedAt'] as String?;
    final finishedAtRaw = json['finishedAt'] as String?;

    if (taskId == null ||
        taskName == null ||
        startedAtRaw == null ||
        finishedAtRaw == null) {
      throw const FormatException(
        'Generated audio record is missing required metadata.',
      );
    }

    return GeneratedAudioRecord(
      taskId: taskId,
      taskName: taskName,
      outputPath: outputPath,
      startedAt: DateTime.parse(startedAtRaw),
      finishedAt: DateTime.parse(finishedAtRaw),
      inputCharacterCount: json['inputCharacterCount'] as int?,
      modelId: json['modelId'] as String?,
      modelName: json['modelName'] as String?,
    );
  }

  factory GeneratedAudioRecord.fromTask(LongRunningTask task) {
    if (!task.hasPlayableAudio || task.outputPath == null) {
      throw ArgumentError.value(
        task.id,
        'task',
        'Task must be a completed synthesis task with an output path.',
      );
    }

    final finishedAt = task.finishedAt;
    if (finishedAt == null) {
      throw ArgumentError.value(
        task.id,
        'task',
        'Completed synthesis task must have finishedAt metadata.',
      );
    }

    return GeneratedAudioRecord(
      taskId: task.id,
      taskName: task.label,
      outputPath: task.outputPath!,
      startedAt: task.startedAt,
      finishedAt: finishedAt,
      inputCharacterCount: task.inputCharacterCount,
      modelId: task.modelId,
      modelName: task.modelName,
    );
  }

  LongRunningTask toTask() {
    return LongRunningTask(
      id: taskId,
      type: LongRunningTaskType.synthesizeSpeech,
      label: taskName,
      startedAt: startedAt,
      status: LongRunningTaskStatus.completed,
      inputCharacterCount: inputCharacterCount,
      modelId: modelId,
      modelName: modelName,
      finishedAt: finishedAt,
      outputPath: outputPath,
    );
  }
}

class GeneratedAudioStore {
  GeneratedAudioStore({required File libraryFile, required File statsFile})
    : _libraryFile = libraryFile,
      _statsFile = statsFile;

  static const int schemaVersion = 1;
  static const String defaultStatsPath = 'generated_audio_stats.json';
  static const String defaultLibraryPath = 'generated_audio_records.json';

  final File _libraryFile;
  final File _statsFile;
  Future<void> _pendingOperation = Future<void>.value();

  Future<void> ensureInitialized() {
    return _queueOperation(_ensureInitializedUnlocked);
  }

  Future<List<LongRunningTask>> loadTasks() {
    return _queueOperation(() async {
      await _ensureInitializedUnlocked();
      final records = await _readRecords();
      final validRecords = <GeneratedAudioRecord>[];
      var changed = false;

      for (final record in records) {
        final file = File(record.outputPath);
        final exists = await file.exists();
        final size = exists ? (await file.stat()).size : 0;
        if (!exists || size <= 0) {
          changed = true;
          continue;
        }
        validRecords.add(record);
      }

      if (changed) {
        await _writeRecords(validRecords);
      }

      return validRecords
          .map((record) => record.toTask())
          .toList(growable: false);
    });
  }

  Future<void> upsertTask(LongRunningTask task) {
    return _queueOperation(() async {
      await _ensureInitializedUnlocked();
      final newRecord = GeneratedAudioRecord.fromTask(task);
      final records = await _readRecords();
      final updated = <GeneratedAudioRecord>[];
      var replaced = false;

      for (final record in records) {
        if (record.outputPath == newRecord.outputPath) {
          updated.add(newRecord);
          replaced = true;
        } else {
          updated.add(record);
        }
      }

      if (!replaced) {
        updated.add(newRecord);
      }

      updated.sort((a, b) => b.startedAt.compareTo(a.startedAt));
      await _writeRecords(updated);
    });
  }

  Future<Map<String, GeneratedAudioStatistics>> loadStatistics() {
    return _queueOperation(() async {
      await _ensureInitializedUnlocked();
      return _readStatistics();
    });
  }

  Future<void> updateStatisticsForTask(
    LongRunningTask task, {
    double? outputSecondsOverride,
  }) {
    return _queueOperation(() async {
      await _ensureInitializedUnlocked();
      if (!task.hasPlayableAudio) {
        return;
      }

      final modelName = task.modelName?.trim();
      final outputPath = task.outputPath;
      final finishedAt = task.finishedAt;
      final inputCharacterCount = task.inputCharacterCount;

      if (modelName == null ||
          modelName.isEmpty ||
          outputPath == null ||
          finishedAt == null ||
          inputCharacterCount == null ||
          inputCharacterCount <= 0) {
        return;
      }

      final statistics = await _readStatistics();
      final current =
          statistics[modelName] ?? const GeneratedAudioStatistics.empty();
      final generationSeconds = _durationToSeconds(
        finishedAt.difference(task.startedAt),
      );
      final outputSeconds =
          outputSecondsOverride ?? await _readOutputDurationSeconds(outputPath);

      statistics[modelName] = current.recordGeneration(
        inputCharacters: inputCharacterCount,
        generationSeconds: generationSeconds,
        outputSeconds: outputSeconds,
      );
      await _writeStatistics(statistics);
    });
  }

  Future<void> removeByOutputPath(String outputPath) {
    return _queueOperation(() async {
      await _ensureInitializedUnlocked();
      final records = await _readRecords();
      final updated = records
          .where((record) => record.outputPath != outputPath)
          .toList(growable: false);
      if (updated.length == records.length) {
        return;
      }
      await _writeRecords(updated);
    });
  }

  Future<List<GeneratedAudioRecord>> _readRecords() async {
    final payload = await _readJsonObject(_libraryFile);
    final rawItems = payload['items'];
    if (rawItems is! List) {
      return const <GeneratedAudioRecord>[];
    }

    final records = <GeneratedAudioRecord>[];
    for (final item in rawItems) {
      if (item is! Map) {
        continue;
      }
      records.add(
        GeneratedAudioRecord.fromJson(
          Map<String, Object?>.from(item as Map<Object?, Object?>),
        ),
      );
    }
    return records;
  }

  Future<void> _writeRecords(List<GeneratedAudioRecord> records) {
    return _writeJsonFile(_libraryFile, <String, Object?>{
      'version': schemaVersion,
      'items': records.map((record) => record.toJson()).toList(growable: false),
    });
  }

  Future<Map<String, GeneratedAudioStatistics>> _readStatistics() async {
    final payload = await _readJsonObject(_statsFile);
    final rawModels = payload['models'];
    if (rawModels is! Map) {
      return <String, GeneratedAudioStatistics>{};
    }

    final statistics = <String, GeneratedAudioStatistics>{};
    for (final entry in rawModels.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String || value is! Map) {
        continue;
      }

      statistics[key] = GeneratedAudioStatistics.fromJson(
        Map<String, Object?>.from(value as Map<Object?, Object?>),
      );
    }

    return statistics;
  }

  Future<void> _writeStatistics(
    Map<String, GeneratedAudioStatistics> statistics,
  ) {
    final sortedEntries = statistics.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));

    return _writeJsonFile(_statsFile, <String, Object?>{
      'version': schemaVersion,
      'models': <String, Object?>{
        for (final entry in sortedEntries) entry.key: entry.value.toJson(),
      },
    });
  }

  Future<Map<String, Object?>> _readJsonObject(File file) async {
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return <String, Object?>{};
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Expected a JSON object.');
    }
    return Map<String, Object?>.from(decoded as Map<Object?, Object?>);
  }

  Future<void> _writeJsonFile(File file, Map<String, Object?> payload) async {
    final tempFile = File('${file.path}.tmp');
    await tempFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    if (await file.exists()) {
      await file.delete();
    }
    await tempFile.rename(file.path);
  }

  Future<T> _queueOperation<T>(Future<T> Function() action) {
    final operation = _pendingOperation.then((_) => action());
    _pendingOperation = operation.then<void>((_) {}).catchError((_) {});
    return operation;
  }

  double _durationToSeconds(Duration duration) {
    final microseconds = duration.inMicroseconds;
    if (microseconds <= 0) {
      return 0;
    }
    return microseconds / Duration.microsecondsPerSecond;
  }

  Future<double> _readOutputDurationSeconds(String outputPath) async {
    final wave = TtsService.readWavFile(outputPath);
    if (wave.sampleRate <= 0 || wave.samples.isEmpty) {
      return 0;
    }
    return wave.samples.length / wave.sampleRate;
  }

  Future<void> _ensureInitializedUnlocked() async {
    await _libraryFile.parent.create(recursive: true);
    await _statsFile.parent.create(recursive: true);
    if (!await _libraryFile.exists()) {
      await _writeJsonFile(_libraryFile, <String, Object?>{
        'version': schemaVersion,
        'items': const <Object?>[],
      });
    }
    if (!await _statsFile.exists()) {
      await _writeJsonFile(_statsFile, <String, Object?>{
        'version': schemaVersion,
        'models': const <Object?>[],
      });
    }
  }
}
