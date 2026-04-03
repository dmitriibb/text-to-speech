import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tts_core/tts_core.dart';

import '../models/long_running_task.dart';
import '../services/audio_service.dart';
import '../services/long_running_task_service.dart';
import '../services/model_service.dart';

enum SynthesisStatus { idle, generating, done, error }

class AppState extends ChangeNotifier {
  final ModelService _modelService = ModelService();
  final AudioService _audioService = AudioService();
  final LongRunningTaskService _taskService = LongRunningTaskService();

  StreamSubscription<PlaybackState>? _audioSubscription;
  StreamSubscription<LongRunningTaskResult>? _taskResultSubscription;
  Timer? _taskElapsedTicker;

  List<InstalledModel> _installedModels = [];
  InstalledModel? _selectedModel;
  bool _isLoadingModels = true;
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _modelsDirectory;

  String _inputText = '';
  double _speed = 1.0;
  SynthesisStatus _synthesisStatus = SynthesisStatus.idle;
  String? _errorMessage;

  String? _generatedWavPath;
  PlaybackState _playbackState = PlaybackState.stopped;

  List<InstalledModel> get installedModels => _installedModels;
  InstalledModel? get selectedModel => _selectedModel;
  bool get isLoadingModels => _isLoadingModels;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String? get modelsDirectory => _modelsDirectory;

  String get inputText => _inputText;
  double get speed => _speed;
  SynthesisStatus get synthesisStatus => _synthesisStatus;
  String? get errorMessage => _errorMessage;

  String? get generatedWavPath => _generatedWavPath;
  PlaybackState get playbackState => _playbackState;

  List<LongRunningTask> get activeTasks => _taskService.activeTasks;
  int get activeSynthesisTaskCount =>
      activeTasks.where((task) => task.type == LongRunningTaskType.synthesizeSpeech).length;
  bool get hasActiveTasks => activeTasks.isNotEmpty;
  bool get hasActiveSynthesisTasks => activeSynthesisTaskCount > 0;
  bool get canManageModels => !_isLoadingModels && !_isDownloading;
  bool get canSelectModel => canManageModels && readyModels.isNotEmpty;
  bool get canAdjustSpeed => !_isLoadingModels && !_isDownloading;

  bool get hasAudio => _generatedWavPath != null;
  bool get canGenerate =>
      !_isDownloading &&
      _selectedModel?.status == ModelStatus.ready &&
      TextInputValidator.validate(_inputText) == null;

  List<InstalledModel> get readyModels =>
      _installedModels.where((model) => model.status == ModelStatus.ready).toList();

  List<InstalledModel> get installableModels =>
      _installedModels.where((model) => model.status != ModelStatus.ready).toList();

  Future<void> initialize() async {
    _taskService.addListener(_handleTaskServiceChanged);
    _taskResultSubscription = _taskService.results.listen(_handleTaskResult);
    await _taskService.initialize();
    _modelsDirectory = await _modelService.getModelsDirectory();
    _audioSubscription = _audioService.onStateChanged.listen((state) {
      _playbackState = state;
      notifyListeners();
    });
    await refreshModels();
  }

  Future<void> refreshModels() async {
    _isLoadingModels = true;
    notifyListeners();

    try {
      _installedModels = await _modelService.getInstalledModels();
      final nextSelection = _resolveSelection();
      if (nextSelection != null) {
        _speed = nextSelection.voice.defaultSpeed;
      }
      _selectedModel = nextSelection;
      _errorMessage = null;
    } catch (error) {
      _errorMessage = 'Failed to scan models: $error';
    } finally {
      _isLoadingModels = false;
      notifyListeners();
    }
  }

  InstalledModel? _resolveSelection() {
    final ready = readyModels;
    if (ready.isEmpty) {
      return null;
    }

    final selectedId = _selectedModel?.voice.id;
    if (selectedId != null) {
      for (final model in ready) {
        if (model.voice.id == selectedId) {
          return model;
        }
      }
    }

    return ready.first;
  }

  Future<void> selectModel(InstalledModel model) async {
    if (!canSelectModel || model.status != ModelStatus.ready || model.modelDir == null) {
      return;
    }

    if (_selectedModel?.voice.id == model.voice.id) {
      return;
    }

    _selectedModel = model;
    _speed = model.voice.defaultSpeed;
    _errorMessage = null;
    notifyListeners();

    unawaited(_queueModelPreload(model));
  }

  Future<void> downloadModel(VoiceModel voice) async {
    if (_isDownloading) {
      return;
    }

    _isDownloading = true;
    _downloadProgress = 0;
    _errorMessage = null;
    notifyListeners();

    try {
      await _modelService.downloadModel(
        voice,
        onProgress: (progress) {
          _downloadProgress = progress;
          notifyListeners();
        },
      );
      await refreshModels();
    } catch (error) {
      _errorMessage = 'Download failed: $error';
    } finally {
      _isDownloading = false;
      notifyListeners();
    }
  }

  void setInputText(String text) {
    _inputText = text;
    if (_errorMessage != null && TextInputValidator.validate(text) == null) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  void setSpeed(double speed) {
    _speed = speed.clamp(0.25, 3.0);
    notifyListeners();
  }

  Future<void> generate() async {
    final inputError = TextInputValidator.validate(_inputText);
    if (inputError != null) {
      _errorMessage = inputError;
      notifyListeners();
      return;
    }

    if (_selectedModel?.modelDir == null) {
      _errorMessage = 'Install and select a model before generating speech.';
      notifyListeners();
      return;
    }

    final selectedModel = _selectedModel!;
    final inputText = _inputText.trim();
    final speed = _speed;

    await _audioService.stop();

    try {
      await _taskService.submitSpeechSynthesis(
        modelDir: selectedModel.modelDir!,
        voice: selectedModel.voice,
        text: inputText,
        speed: speed,
        speakerId: selectedModel.voice.defaultSpeakerId,
        outputPath: await _resolveOutputPath(),
      );
      _errorMessage = null;
    } catch (error) {
      _errorMessage = 'Failed to start synthesis task: $error';
    }

    notifyListeners();
  }

  Future<String> _resolveOutputPath() async {
    final supportDir = await getApplicationSupportDirectory();
    final outputDir = Directory(p.join(supportDir.path, 'generated_audio'));
    await outputDir.create(recursive: true);

    return p.join(
      outputDir.path,
      'speech-${DateTime.now().microsecondsSinceEpoch}.wav',
    );
  }

  Future<void> cancelTask(String taskId) async {
    try {
      await _taskService.cancelTask(taskId);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = 'Failed to cancel task: $error';
      notifyListeners();
    }
  }

  String formatTaskElapsed(LongRunningTask task) {
    final elapsed = DateTime.now().difference(task.startedAt).inSeconds;
    return '${elapsed < 0 ? 0 : elapsed}s';
  }

  String describeTaskStatus(LongRunningTask task) {
    switch (task.status) {
      case LongRunningTaskStatus.queued:
        return 'Queued';
      case LongRunningTaskStatus.running:
        return 'Running';
      case LongRunningTaskStatus.cancelling:
        return 'Cancelling';
    }
  }

  Future<void> play() async {
    if (_generatedWavPath == null) {
      return;
    }

    try {
      await _audioService.play(_generatedWavPath!);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = 'Playback failed: $error';
      notifyListeners();
    }
  }

  Future<void> stopPlayback() async {
    await _audioService.stop();
  }

  Future<bool> shareGeneratedAudio() async {
    if (_generatedWavPath == null) {
      return false;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(_generatedWavPath!)],
          text: 'Generated speech from Text to Speech',
          subject: 'Generated speech',
        ),
      );
      _errorMessage = null;
      return true;
    } catch (error) {
      _errorMessage = 'Share failed: $error';
      notifyListeners();
      return false;
    }
  }

  Future<void> _queueModelPreload(InstalledModel model) async {
    try {
      await _taskService.submitModelPreload(
        modelDir: model.modelDir!,
        voice: model.voice,
      );
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Failed to start background voice load: $error';
      notifyListeners();
    }
  }

  void _handleTaskServiceChanged() {
    final hasActiveTasks = _taskService.activeTasks.isNotEmpty;
    final hasActiveSynthesis = _taskService.activeTasks.any(
      (task) => task.type == LongRunningTaskType.synthesizeSpeech,
    );

    if (hasActiveSynthesis) {
      _synthesisStatus = SynthesisStatus.generating;
    } else if (_synthesisStatus == SynthesisStatus.generating) {
      _synthesisStatus = SynthesisStatus.idle;
    }

    if (hasActiveTasks) {
      _taskElapsedTicker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        notifyListeners();
      });
    } else {
      _taskElapsedTicker?.cancel();
      _taskElapsedTicker = null;
    }

    notifyListeners();
  }

  void _handleTaskResult(LongRunningTaskResult result) {
    switch (result.type) {
      case LongRunningTaskType.preloadModel:
        if (result.status == LongRunningTaskResultStatus.failed &&
            result.modelId == _selectedModel?.voice.id) {
          _errorMessage =
              'Failed to load ${_selectedModel?.voice.displayName ?? 'the selected voice'} in the background: ${result.errorMessage ?? 'Unknown error'}';
        }
        break;
      case LongRunningTaskType.synthesizeSpeech:
        switch (result.status) {
          case LongRunningTaskResultStatus.completed:
            _generatedWavPath = result.outputPath;
            _synthesisStatus = SynthesisStatus.done;
            _errorMessage = null;
            break;
          case LongRunningTaskResultStatus.failed:
            _synthesisStatus = SynthesisStatus.error;
            _errorMessage =
                'Synthesis failed: ${result.errorMessage ?? 'Unknown error'}';
            break;
          case LongRunningTaskResultStatus.cancelled:
            if (!hasActiveSynthesisTasks) {
              _synthesisStatus = SynthesisStatus.idle;
            }
            break;
        }
        break;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _taskService.removeListener(_handleTaskServiceChanged);
    _taskElapsedTicker?.cancel();
    unawaited(_taskResultSubscription?.cancel());
    unawaited(_audioSubscription?.cancel());
    _taskService.dispose();
    _modelService.dispose();
    unawaited(_audioService.dispose());
    super.dispose();
  }
}