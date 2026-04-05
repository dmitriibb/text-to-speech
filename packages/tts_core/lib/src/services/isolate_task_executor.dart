import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../models/long_running_task.dart';
import '../models/voice_model.dart';
import 'background_task_executor.dart';
import 'tts_service.dart';

class IsolateTaskExecutor implements BackgroundTaskExecutor {
  Isolate? _isolate;
  SendPort? _commandPort;
  ReceivePort? _receivePort;
  StreamSubscription<Object?>? _receiveSubscription;
  final _resultsController = StreamController<TaskResult>.broadcast();
  Future<void>? _initialization;

  @override
  Stream<TaskResult> get results => _resultsController.stream;

  @override
  Future<void> initialize() {
    return _initialization ??= _initializeInternal();
  }

  Future<void> _initializeInternal() async {
    final receivePort = ReceivePort();
    _receivePort = receivePort;

    _isolate = await Isolate.spawn(_isolateMain, receivePort.sendPort);

    final completer = Completer<SendPort>();
    _receiveSubscription = receivePort.listen((message) {
      if (message is SendPort) {
        if (!completer.isCompleted) {
          completer.complete(message);
        }
        return;
      }

      if (message is Map<Object?, Object?>) {
        _resultsController.add(TaskResult.fromMap(message));
      }
    });

    _commandPort = await completer.future;
  }

  @override
  Future<void> submit(TaskRequest request) async {
    await initialize();
    _commandPort!.send({'action': 'submit', ...request.toMap()});
  }

  @override
  void requestCancel(String taskId) {
    _commandPort?.send({'action': 'cancel', 'taskId': taskId});
  }

  @override
  void dispose() {
    _isolate?.kill(priority: Isolate.beforeNextEvent);
    _isolate = null;
    _commandPort = null;
    _receivePort?.close();
    _receivePort = null;
    unawaited(_receiveSubscription?.cancel());
    _receiveSubscription = null;
    _initialization = null;
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
      if (processing || queue.isEmpty) {
        return;
      }

      processing = true;
      final message = queue.removeAt(0);
      final request = TaskRequest.fromMap(message);
      final taskId = request.taskId;
      final payload = request.payload;

      if (cancelledIds.remove(taskId)) {
        mainPort.send(
          TaskResult(
            taskId: taskId,
            type: request.type,
            status: TaskResultStatus.cancelled,
          ).toMap(),
        );
        processing = false;
        Timer.run(processNext);
        return;
      }

      try {
        final cacheKey = payload['cacheKey']! as String;
        if (loadedCacheKey != cacheKey) {
          tts.loadModel(
            payload['modelDir']! as String,
            _voiceModelFromPayload(payload),
          );
          loadedCacheKey = cacheKey;
        }

        if (request.type == LongRunningTaskType.synthesizeSpeech) {
          final useReferenceAudio = payload['useReferenceAudio'] == true;
          final SynthesisResult result;

          if (useReferenceAudio) {
            result = tts.synthesizeWithReference(
              payload['text']! as String,
              referenceAudio: payload['referenceAudio']! as Float32List,
              referenceSampleRate: payload['referenceSampleRate']! as int,
              speed: (payload['speed']! as num).toDouble(),
            );
          } else {
            result = tts.synthesize(
              payload['text']! as String,
              speed: (payload['speed']! as num).toDouble(),
              speakerId: payload['speakerId']! as int,
            );
          }

          if (cancelledIds.remove(taskId)) {
            mainPort.send(
              TaskResult(
                taskId: taskId,
                type: request.type,
                status: TaskResultStatus.cancelled,
              ).toMap(),
            );
          } else {
            final outputPath = payload['outputPath']! as String;
            final outputDir = Directory(p.dirname(outputPath));
            outputDir.createSync(recursive: true);
            final saved = tts.saveWav(result, outputPath);
            if (!saved) {
              throw Exception('Failed to write WAV file');
            }

            mainPort.send(
              TaskResult(
                taskId: taskId,
                type: request.type,
                status: TaskResultStatus.completed,
                outputPath: outputPath,
              ).toMap(),
            );
          }
        } else {
          mainPort.send(
            TaskResult(
              taskId: taskId,
              type: request.type,
              status: TaskResultStatus.completed,
            ).toMap(),
          );
        }
      } catch (error) {
        final wasCancelled = cancelledIds.remove(taskId);
        mainPort.send(
          TaskResult(
            taskId: taskId,
            type: request.type,
            status: wasCancelled
                ? TaskResultStatus.cancelled
                : TaskResultStatus.failed,
            errorMessage: wasCancelled ? null : error.toString(),
          ).toMap(),
        );
      }

      processing = false;
      Timer.run(processNext);
    }

    commandPort.listen((message) {
      final data = Map<String, Object?>.from(message as Map<Object?, Object?>);
      final action = data.remove('action') as String;

      if (action == 'cancel') {
        cancelledIds.add(data['taskId']! as String);
        return;
      }

      queue.add(data);
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
        'pocket_lm_main': payload['pocketLmMain'],
        'pocket_encoder': payload['pocketEncoder'],
        'pocket_decoder': payload['pocketDecoder'],
        'pocket_text_conditioner': payload['pocketTextConditioner'],
        'pocket_vocab_json': payload['pocketVocabJson'],
        'pocket_token_scores_json': payload['pocketTokenScoresJson'],
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
