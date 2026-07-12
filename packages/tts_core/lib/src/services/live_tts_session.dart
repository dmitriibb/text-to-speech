import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/live_tts_chunk.dart';
import '../models/long_running_task.dart';
import '../models/voice_model.dart';
import 'background_task_executor.dart';
import 'live_text_chunker.dart';
import 'synthesis_settings.dart';
import 'voice_model_task_payload.dart';

typedef BackgroundTaskExecutorFactory = BackgroundTaskExecutor Function();

const int liveTtsReadyBufferMin = 2;
const int liveTtsReadyBufferMax = 4;

class LiveTtsSession extends ChangeNotifier {
  LiveTtsSession({
    required BackgroundTaskExecutorFactory executorFactory,
    required this.modelDir,
    required this.voice,
    required this.text,
    required this.speed,
    required this.speakerId,
    required this.chunkSizeWords,
    required this.outputDirectoryPath,
    this.startOffset = 0,
    this.providerOverride,
    this.generationLanguage,
    this.maxConcurrentGenerations = 2,
  }) : _executorFactory = executorFactory,
       _sessionId = DateTime.now().microsecondsSinceEpoch.toString(),
       _chunks = LiveTextChunker.splitText(
         text,
         chunkSizeWords: chunkSizeWords,
         startOffset: startOffset,
       );

  final BackgroundTaskExecutorFactory _executorFactory;
  final String _sessionId;
  final String modelDir;
  final VoiceModel voice;
  final String text;
  final double speed;
  final int speakerId;
  final int chunkSizeWords;
  final String outputDirectoryPath;
  final int startOffset;
  final String? providerOverride;
  final String? generationLanguage;
  final int maxConcurrentGenerations;

  final List<LiveTtsChunk> _chunks;
  final List<_LiveTtsWorker> _workers = <_LiveTtsWorker>[];
  final Set<String> _knownOutputPaths = <String>{};
  var _started = false;
  var _stopped = false;
  int? _playingChunkIndex;
  String? _errorMessage;

  List<LiveTtsChunk> get chunks => List<LiveTtsChunk>.unmodifiable(_chunks);
  String? get errorMessage => _errorMessage;
  bool get isStarted => _started;
  bool get isStopped => _stopped;
  bool get hasFailure => _errorMessage != null;

  LiveTtsChunk? get playingChunk {
    final index = _playingChunkIndex;
    if (index == null || index < 0 || index >= _chunks.length) {
      return null;
    }
    return _chunks[index];
  }

  LiveTtsChunk? get nextReadyChunk {
    final startIndex = (_playingChunkIndex ?? -1) + 1;
    for (var index = startIndex; index < _chunks.length; index++) {
      final chunk = _chunks[index];
      if (chunk.status == LiveTtsChunkStatus.ready) {
        return chunk;
      }
    }
    return null;
  }

  bool get isFinished =>
      _chunks.isNotEmpty &&
      _chunks.every((chunk) => chunk.status == LiveTtsChunkStatus.completed);

  bool get hasPendingPlayback => _chunks.any(
    (chunk) =>
        chunk.status == LiveTtsChunkStatus.ready ||
        chunk.status == LiveTtsChunkStatus.playing,
  );

  int get readyChunkCount => _chunks.where(_isReadyChunk).length;

  int get generatingChunkCount =>
      _workers.where((worker) => worker.isBusy).length;

  Future<void> start() async {
    if (_started || _stopped || _chunks.isEmpty) {
      return;
    }

    _started = true;
    await Directory(outputDirectoryPath).create(recursive: true);

    final workerCount = maxConcurrentGenerations < 1
        ? 1
        : maxConcurrentGenerations;
    for (var index = 0; index < workerCount; index++) {
      final executor = _executorFactory();
      await executor.initialize();
      final worker = _LiveTtsWorker(executor: executor);
      worker.subscription = executor.results.listen(
        (result) => _handleWorkerResult(worker, result),
      );
      _workers.add(worker);
    }

    _scheduleMoreWork();
    notifyListeners();
  }

  void markChunkPlaying(int chunkIndex) {
    if (_stopped || chunkIndex < 0 || chunkIndex >= _chunks.length) {
      return;
    }

    final chunk = _chunks[chunkIndex];
    if (chunk.status != LiveTtsChunkStatus.ready) {
      return;
    }

    _playingChunkIndex = chunkIndex;
    _chunks[chunkIndex] = chunk.copyWith(status: LiveTtsChunkStatus.playing);
    notifyListeners();
  }

  void markChunkCompleted(int chunkIndex) {
    if (_stopped || chunkIndex < 0 || chunkIndex >= _chunks.length) {
      return;
    }

    _chunks[chunkIndex] = _chunks[chunkIndex].copyWith(
      status: LiveTtsChunkStatus.completed,
    );
    if (_playingChunkIndex == chunkIndex) {
      _playingChunkIndex = null;
    }
    notifyListeners();
  }

  Future<void> stop() async {
    if (_stopped) {
      return;
    }

    _stopped = true;
    final workers = List<_LiveTtsWorker>.from(_workers);
    _workers.clear();

    for (final worker in workers) {
      final activeTaskId = worker.activeTaskId;
      if (activeTaskId != null) {
        worker.executor.requestCancel(activeTaskId);
      }
      await worker.dispose();
    }

    for (final outputPath in _knownOutputPaths) {
      await _deleteFileIfPresent(outputPath);
    }
    _knownOutputPaths.clear();
    _playingChunkIndex = null;
  }

  @override
  void dispose() {
    unawaited(stop());
    super.dispose();
  }

  void _scheduleMoreWork() {
    if (_stopped || _errorMessage != null) {
      return;
    }

    if (readyChunkCount > liveTtsReadyBufferMin) {
      return;
    }

    for (final worker in _workers) {
      if (worker.isBusy || generatingChunkCount >= maxConcurrentGenerations) {
        continue;
      }

      final nextChunkIndex = _nextPendingChunkIndex();
      if (nextChunkIndex == null) {
        break;
      }

      unawaited(_submitChunk(worker, nextChunkIndex));
    }
  }

  int? _nextPendingChunkIndex() {
    for (var index = 0; index < _chunks.length; index++) {
      if (_chunks[index].status == LiveTtsChunkStatus.pending) {
        return index;
      }
    }
    return null;
  }

  Future<void> _submitChunk(_LiveTtsWorker worker, int chunkIndex) async {
    if (_stopped || worker.isBusy) {
      return;
    }

    final taskId = 'live-$_sessionId-$chunkIndex';
    final outputPath = p.join(
      outputDirectoryPath,
      'live-$_sessionId-chunk-${chunkIndex + 1}.wav',
    );
    final chunk = _chunks[chunkIndex];
    worker
      ..activeTaskId = taskId
      ..activeChunkIndex = chunkIndex
      ..isBusy = true;
    _knownOutputPaths.add(outputPath);
    _chunks[chunkIndex] = chunk.copyWith(
      status: LiveTtsChunkStatus.generating,
      outputPath: outputPath,
      errorMessage: null,
    );
    notifyListeners();

    try {
      await worker.executor.submit(
        TaskRequest(
          taskId: taskId,
          type: LongRunningTaskType.synthesizeSpeech,
          payload: {
            ...VoiceModelTaskPayload.build(
              modelDir: modelDir,
              voice: voice,
              providerOverride: providerOverride,
            ),
            'text': chunk.text.trim(),
            'speed': clampSpeechSpeed(speed),
            'speakerId': speakerId,
            'generationLanguage': voice.resolveGenerationLanguage(
              generationLanguage,
            ),
            'outputPath': outputPath,
          },
        ),
      );
    } catch (error) {
      worker
        ..activeTaskId = null
        ..activeChunkIndex = null
        ..isBusy = false;
      _errorMessage = 'Failed to start live synthesis: $error';
      _chunks[chunkIndex] = _chunks[chunkIndex].copyWith(
        status: LiveTtsChunkStatus.failed,
        errorMessage: _errorMessage,
      );
      notifyListeners();
    }
  }

  void _handleWorkerResult(_LiveTtsWorker worker, TaskResult result) {
    final chunkIndex = worker.activeChunkIndex;
    worker
      ..activeTaskId = null
      ..activeChunkIndex = null
      ..isBusy = false;

    if (chunkIndex == null || chunkIndex < 0 || chunkIndex >= _chunks.length) {
      return;
    }

    final currentChunk = _chunks[chunkIndex];
    if (_stopped) {
      final outputPath = result.outputPath ?? currentChunk.outputPath;
      if (outputPath != null) {
        unawaited(_deleteFileIfPresent(outputPath));
      }
      return;
    }

    switch (result.status) {
      case TaskResultStatus.completed:
        _chunks[chunkIndex] = currentChunk.copyWith(
          status: LiveTtsChunkStatus.ready,
          outputPath: result.outputPath ?? currentChunk.outputPath,
          errorMessage: null,
        );
      case TaskResultStatus.failed:
        _errorMessage = result.errorMessage ?? 'Live synthesis failed.';
        _chunks[chunkIndex] = currentChunk.copyWith(
          status: LiveTtsChunkStatus.failed,
          errorMessage: _errorMessage,
        );
      case TaskResultStatus.cancelled:
        _chunks[chunkIndex] = currentChunk.copyWith(
          status: LiveTtsChunkStatus.cancelled,
        );
    }

    _scheduleMoreWork();
    notifyListeners();
  }

  Future<void> _deleteFileIfPresent(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  bool _isReadyChunk(LiveTtsChunk chunk) {
    return chunk.status == LiveTtsChunkStatus.ready;
  }
}

class _LiveTtsWorker {
  _LiveTtsWorker({required this.executor});

  final BackgroundTaskExecutor executor;
  StreamSubscription<TaskResult>? subscription;
  bool isBusy = false;
  String? activeTaskId;
  int? activeChunkIndex;

  Future<void> dispose() async {
    await subscription?.cancel();
    executor.dispose();
  }
}
