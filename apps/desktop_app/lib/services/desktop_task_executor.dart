import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:tts_core/tts_core.dart';

class DesktopTaskExecutor implements BackgroundTaskExecutor {
  Isolate? _isolate;
  SendPort? _commandPort;
  final _resultsController = StreamController<TaskResult>.broadcast();

  @override
  Stream<TaskResult> get results => _resultsController.stream;

  @override
  Future<void> initialize() async {
    final receivePort = ReceivePort();

    _isolate = await Isolate.spawn(
      _isolateMain,
      receivePort.sendPort,
    );

    final completer = Completer<SendPort>();
    receivePort.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      } else if (message is Map) {
        _resultsController.add(
          TaskResult.fromMap(Map<Object?, Object?>.from(message)),
        );
      }
    });

    _commandPort = await completer.future;
  }

  @override
  Future<void> submit(TaskRequest request) async {
    _commandPort!.send({'action': 'submit', ...request.toMap()});
  }

  @override
  void requestCancel(String taskId) {
    _commandPort!.send({'action': 'cancel', 'taskId': taskId});
  }

  @override
  void dispose() {
    _isolate?.kill(priority: Isolate.beforeNextEvent);
    _isolate = null;
    _commandPort = null;
    unawaited(_resultsController.close());
  }

  static void _isolateMain(SendPort mainPort) {
    final commandPort = ReceivePort();
    mainPort.send(commandPort.sendPort);

    final tts = TtsService();
    tts.initBindings();
    String? loadedCacheKey;

    final queue = <Map<String, Object?>>[];
    final cancelledIds = <String>{};
    var processing = false;

    void processNext() {
      if (processing || queue.isEmpty) return;
      processing = true;

      final msg = queue.removeAt(0);
      final request = TaskRequest.fromMap(Map<Object?, Object?>.from(msg));
      final taskId = request.taskId;
      final payload = request.payload;

      if (cancelledIds.remove(taskId)) {
        mainPort.send(TaskResult(
          taskId: taskId,
          type: request.type,
          status: TaskResultStatus.cancelled,
        ).toMap());
        processing = false;
        Timer.run(processNext);
        return;
      }

      try {
        // Load model if needed.
        final cacheKey = payload['cacheKey']! as String;
        if (loadedCacheKey != cacheKey) {
          final model = _voiceModelFromPayload(payload);
          tts.loadModel(payload['modelDir']! as String, model);
          loadedCacheKey = cacheKey;
        }

        if (request.type == LongRunningTaskType.synthesizeSpeech) {
          final result = tts.synthesize(
            payload['text']! as String,
            speed: (payload['speed']! as num).toDouble(),
            speakerId: payload['speakerId']! as int,
          );

          // Check cancel after synthesis (can't interrupt FFI).
          if (cancelledIds.remove(taskId)) {
            mainPort.send(TaskResult(
              taskId: taskId,
              type: request.type,
              status: TaskResultStatus.cancelled,
            ).toMap());
          } else {
            final outputPath = payload['outputPath']! as String;
            final dir = Directory(p.dirname(outputPath));
            dir.createSync(recursive: true);
            final saved = tts.saveWav(result, outputPath);
            if (!saved) throw Exception('Failed to write WAV file');

            mainPort.send(TaskResult(
              taskId: taskId,
              type: request.type,
              status: TaskResultStatus.completed,
              outputPath: outputPath,
            ).toMap());
          }
        } else {
          // preloadModel — just loading is enough.
          mainPort.send(TaskResult(
            taskId: taskId,
            type: request.type,
            status: TaskResultStatus.completed,
          ).toMap());
        }
      } catch (e) {
        final wasCancelled = cancelledIds.remove(taskId);
        mainPort.send(TaskResult(
          taskId: taskId,
          type: request.type,
          status: wasCancelled
              ? TaskResultStatus.cancelled
              : TaskResultStatus.failed,
          errorMessage: wasCancelled ? null : e.toString(),
        ).toMap());
      }

      processing = false;
      Timer.run(processNext);
    }

    commandPort.listen((message) {
      final msg = Map<String, Object?>.from(message as Map);
      final action = msg['action'] as String;

      if (action == 'cancel') {
        cancelledIds.add(msg['taskId']! as String);
        return;
      }

      // 'submit' — extract the request data (minus the 'action' key).
      msg.remove('action');
      queue.add(msg);
      processNext();
    });
  }

  static VoiceModel _voiceModelFromPayload(Map<String, Object?> payload) {
    return VoiceModel.fromJson({
      'id': payload['modelId'],
      'display_name': payload['displayName'],
      'family': payload['family'],
      'runtime': payload['runtime'],
      'status': const {'approved_for_distribution': false},
      'source': const {'archive_url': ''},
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
  }
}
