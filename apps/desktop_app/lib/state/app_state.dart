import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:tts_core/tts_core.dart';

import '../models/voice_model.dart';
import '../services/audio_service.dart';
import '../services/desktop_task_executor.dart';
import '../services/model_service.dart';

/// Synthesis workflow state.
enum SynthesisStatus { idle, generating, done, error }

/// Top-level application state.
class AppState extends ChangeNotifier {
  final ModelService _modelService = ModelService();
  final AudioService _audioService = AudioService();
  final TaskManager taskManager = TaskManager(
    executor: DesktopTaskExecutor(),
  );

  // ---- Model state ----
  List<InstalledModel> _installedModels = [];
  InstalledModel? _selectedModel;
  bool _isLoadingModels = true;
  double _downloadProgress = 0;
  bool _isDownloading = false;

  // ---- Synthesis state ----
  String _inputText = '';
  double _speed = 1.0;
  SynthesisStatus _synthesisStatus = SynthesisStatus.idle;
  String? _errorMessage;

  // ---- Audio state ----
  String? _generatedWavPath;
  String? _playingTaskId;
  PlaybackState _playbackState = PlaybackState.stopped;
  StreamSubscription<PlaybackState>? _audioSubscription;

  // ---- Getters ----
  List<InstalledModel> get installedModels => _installedModels;
  InstalledModel? get selectedModel => _selectedModel;
  bool get isLoadingModels => _isLoadingModels;
  double get downloadProgress => _downloadProgress;
  bool get isDownloading => _isDownloading;

  String get inputText => _inputText;
  double get speed => _speed;
  SynthesisStatus get synthesisStatus => _synthesisStatus;
  String? get errorMessage => _errorMessage;

  String? get generatedWavPath => _generatedWavPath;
  PlaybackState get playbackState => _playbackState;
  String? get playingTaskId => _playingTaskId;

  /// True when a ready model is selected and text is non-empty.
  bool get canGenerate =>
      _selectedModel != null &&
      _selectedModel!.status == ModelStatus.ready &&
      _inputText.trim().isNotEmpty;

  /// True when generated audio exists.
  bool get hasAudio => _generatedWavPath != null;

  /// List of models that have not been installed yet.
  List<InstalledModel> get downloadableModels =>
      _installedModels
          .where((m) => m.status == ModelStatus.notInstalled)
          .toList();

  /// List of models that are ready.
  List<InstalledModel> get readyModels =>
      _installedModels.where((m) => m.status == ModelStatus.ready).toList();

  // ---- Initialization ----

  /// Call once at startup to init bindings and scan models.
  Future<void> initialize() async {
    taskManager.addListener(_handleTaskManagerChanged);

    _audioSubscription = _audioService.onStateChanged.listen((state) {
      _playbackState = state;
      if (state == PlaybackState.stopped) {
        _playingTaskId = null;
      }
      notifyListeners();
    });

    await taskManager.initialize();
    await refreshModels();
  }

  /// Re-scans installed models.
  Future<void> refreshModels() async {
    _isLoadingModels = true;
    notifyListeners();

    try {
      _installedModels = await _modelService.getInstalledModels();

      // Auto-select first ready model if none selected.
      if (_selectedModel == null ||
          _selectedModel!.status != ModelStatus.ready) {
        final ready = readyModels;
        if (ready.isNotEmpty) {
          await selectModel(ready.first);
        } else {
          _selectedModel = null;
        }
      }
    } catch (e) {
      _errorMessage = 'Failed to scan models: $e';
    } finally {
      _isLoadingModels = false;
      notifyListeners();
    }
  }

  // ---- Model actions ----

  /// Selects a model and queues a background preload.
  Future<void> selectModel(InstalledModel model) async {
    if (model.status != ModelStatus.ready || model.modelDir == null) return;

    _selectedModel = model;
    _errorMessage = null;
    notifyListeners();

    try {
      await taskManager.submitModelPreload(
        modelDir: model.modelDir!,
        voice: model.voice,
      );
    } catch (e) {
      _errorMessage = 'Failed to start background voice load: $e';
      notifyListeners();
    }
  }

  /// Downloads a model from the catalog.
  Future<void> downloadModel(VoiceModel voice) async {
    if (_isDownloading) return;
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
    } catch (e) {
      _errorMessage = 'Download failed: $e';
    } finally {
      _isDownloading = false;
      notifyListeners();
    }
  }

  // ---- Text / Settings ----

  void setInputText(String text) {
    _inputText = text;
    notifyListeners();
  }

  void setSpeed(double speed) {
    _speed = speed.clamp(0.25, 3.0);
    notifyListeners();
  }

  // ---- Synthesis ----

  /// Generates speech from the current input text via background task.
  Future<void> generate() async {
    if (!canGenerate) return;

    _errorMessage = null;
    await _audioService.stop();
    notifyListeners();

    final selectedModel = _selectedModel!;
    final modelsDir = await _modelService.getModelsDirectory();
    final outputDir = Directory(p.join(Directory.systemTemp.path, 'tts_generated'));
    await outputDir.create(recursive: true);
    final outputPath = p.join(
      outputDir.path,
      'speech-${DateTime.now().microsecondsSinceEpoch}.wav',
    );

    try {
      await taskManager.submitSynthesis(
        modelDir: selectedModel.modelDir!,
        voice: selectedModel.voice,
        text: _inputText.trim(),
        speed: _speed,
        speakerId: selectedModel.voice.defaultSpeakerId,
        outputPath: outputPath,
      );
    } catch (e) {
      _errorMessage = 'Failed to start synthesis task: $e';
      notifyListeners();
    }
  }

  // ---- Playback ----

  Future<void> play() async {
    if (_generatedWavPath == null) return;
    try {
      await _audioService.play(_generatedWavPath!);
    } catch (e) {
      _errorMessage = 'Playback failed: $e';
      notifyListeners();
    }
  }

  Future<void> playTaskAudio(String outputPath) async {
    // Find the task ID for this output path.
    for (final task in taskManager.tasks) {
      if (task.outputPath == outputPath) {
        _playingTaskId = task.id;
        break;
      }
    }
    _generatedWavPath = outputPath;
    notifyListeners();
    try {
      await _audioService.play(outputPath);
    } catch (e) {
      _errorMessage = 'Playback failed: $e';
      _playingTaskId = null;
      notifyListeners();
    }
  }

  Future<void> stopPlayback() async {
    await _audioService.stop();
  }

  // ---- Export ----

  /// Copies the generated WAV to [outputPath].
  Future<bool> exportWav(String outputPath) async {
    if (_generatedWavPath == null) return false;
    try {
      await File(_generatedWavPath!).copy(outputPath);
      return true;
    } catch (e) {
      _errorMessage = 'Save failed: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> saveTaskAudio(String sourcePath) async {
    // For desktop, we just export to the same path (it's already on disk).
    // The user could be shown a file picker in the UI layer.
    return true;
  }

  // ---- Task Manager Integration ----

  void _handleTaskManagerChanged() {
    final hasSynthesis = taskManager.hasActiveSynthesisTasks;
    if (hasSynthesis) {
      _synthesisStatus = SynthesisStatus.generating;
    } else if (_synthesisStatus == SynthesisStatus.generating) {
      // Check if any synthesis completed.
      final latest = taskManager.latestCompletedSynthesis;
      if (latest != null) {
        _generatedWavPath = latest.outputPath;
        _synthesisStatus = SynthesisStatus.done;
      } else {
        _synthesisStatus = SynthesisStatus.idle;
      }
    }
    notifyListeners();
  }

  // ---- Cleanup ----

  @override
  void dispose() {
    taskManager.removeListener(_handleTaskManagerChanged);
    unawaited(_audioSubscription?.cancel());
    taskManager.dispose();
    _audioService.dispose();
    super.dispose();
  }
}
