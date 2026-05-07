import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:tts_core/tts_core.dart';

import '../services/audio_service.dart';
import '../services/gpu_detector.dart';
import '../services/model_service.dart';

/// Synthesis workflow state.
enum SynthesisStatus { idle, generating, done, error }

/// Top-level application state.
class AppState extends ChangeNotifier {
  final ModelService _modelService = ModelService();
  final AudioService _audioService = AudioService();
  final TaskManager taskManager = TaskManager(executor: IsolateTaskExecutor());
  GeneratedAudioStore? _generatedAudioStore;
  Map<String, GeneratedAudioStatistics> _generatedAudioStatistics = const {};
  final Set<String> _persistedGeneratedAudioPaths = <String>{};

  // ---- Model state ----
  List<InstalledModel> _installedModels = [];
  InstalledModel? _selectedModel;
  bool _isLoadingModels = true;
  double _downloadProgress = 0;
  bool _isDownloading = false;
  ModelInstallProgress? _currentInstallProgress;
  String? _activeInstallTaskId;

  // ---- Synthesis state ----
  String _inputText = '';
  double _speed = speechSpeedDefault;
  int _selectedSpeakerId = 0;
  int _inputCursorOffset = 0;
  SynthesisStatus _synthesisStatus = SynthesisStatus.idle;
  String? _errorMessage;
  bool _isLiveTtsEnabled = false;
  int _liveChunkSizeWords = 10;
  LiveTtsSession? _liveTtsSession;
  bool _isStartingLivePlayback = false;
  bool _isStoppingLiveTts = false;

  // ---- Audio state ----
  String? _generatedWavPath;
  String? _currentTaskId;
  PlaybackState _playbackState = PlaybackState.stopped;
  StreamSubscription<PlaybackState>? _audioSubscription;
  StreamSubscription<Duration>? _audioPositionSubscription;
  StreamSubscription<Duration?>? _audioDurationSubscription;
  Duration _playbackPosition = Duration.zero;
  Duration? _playbackDuration;

  // ---- Provider state ----
  List<String> _availableProviders = const ['cpu'];
  String _selectedProvider = 'cpu';
  bool _isAdvancedLabEnabled = false;
  bool _isVoiceCloningEnabled = false;

  // ---- Getters ----
  List<InstalledModel> get installedModels => _installedModels;
  InstalledModel? get selectedModel => _selectedModel;
  bool get isLoadingModels => _isLoadingModels;
  double get downloadProgress => _downloadProgress;
  bool get isDownloading => _isDownloading;
  ModelInstallProgress? get currentInstallProgress => _currentInstallProgress;

  String get inputText => _inputText;
  double get speed => _speed;
  int get selectedSpeakerId => _selectedSpeakerId;
  int get inputCursorOffset => _inputCursorOffset;
  SynthesisStatus get synthesisStatus => _synthesisStatus;
  String? get errorMessage => _errorMessage;
  bool get isLiveTtsEnabled => _isLiveTtsEnabled;
  int get liveChunkSizeWords => _liveChunkSizeWords;
  bool get isLiveTtsStreaming => _liveTtsSession != null;
  List<LiveTtsChunk> get liveTtsChunks =>
      _liveTtsSession?.chunks ?? const <LiveTtsChunk>[];

  String? get generatedWavPath => _generatedWavPath;
  PlaybackState get playbackState => _playbackState;
  String? get playingTaskId =>
      _playbackState == PlaybackState.playing ? _currentTaskId : null;
  String? get activeTaskId => _currentTaskId;
  Duration get playbackPosition => _playbackPosition;
  Duration? get playbackDuration => _playbackDuration;
  Duration? get expectedGenerationDuration =>
      _expectedGenerationDurationForCurrentInput();
  Duration? get expectedOutputDuration =>
      _expectedOutputDurationForCurrentInput();

  List<String> get availableProviders => _availableProviders;
  String get selectedProvider => _selectedProvider;
  bool get isAdvancedLabEnabled => _isAdvancedLabEnabled;
  bool get isVoiceCloningEnabled => _isVoiceCloningEnabled;
  bool get hasPocketModel => pocketModel != null;
  bool get canManageModels => !_isLoadingModels && !_isDownloading;

  InstalledModel? get pocketModel {
    for (final model in installedModels) {
      if (model.voice.family == 'pocket' &&
          model.status == ModelStatus.ready &&
          model.modelDir != null) {
        return model;
      }
    }
    return null;
  }

  /// True when a ready model is selected and text is non-empty.
  bool get canGenerate =>
      _selectedModel != null &&
      _selectedModel!.status == ModelStatus.ready &&
      _inputText.trim().isNotEmpty;

  /// True when generated audio exists.
  bool get hasAudio => _generatedWavPath != null;

  /// List of models that have not been installed yet.
  List<InstalledModel> get downloadableModels => _installedModels
      .where((m) => m.status == ModelStatus.notInstalled)
      .toList();

  /// List of models that are ready.
  List<InstalledModel> get readyModels =>
      _installedModels.where((m) => m.status == ModelStatus.ready).toList();

  /// List of models that still need install or repair work.
  List<InstalledModel> get installableModels =>
      _installedModels.where((m) => m.status != ModelStatus.ready).toList();

  // ---- Initialization ----

  /// Call once at startup to init bindings and scan models.
  Future<void> initialize() async {
    taskManager.addListener(_handleTaskManagerChanged);

    _audioSubscription = _audioService.onStateChanged.listen((state) {
      final previousState = _playbackState;
      _playbackState = state;
      unawaited(_handleLivePlaybackStateChange(previousState, state));
      notifyListeners();
    });
    _audioPositionSubscription = _audioService.onPositionChanged.listen((
      position,
    ) {
      _playbackPosition = position;
      notifyListeners();
    });
    _audioDurationSubscription = _audioService.onDurationChanged.listen((
      duration,
    ) {
      _playbackDuration = duration;
      notifyListeners();
    });

    // Detect available GPU providers.
    _availableProviders = GpuDetector.detectAvailableProviders();
    _selectedProvider = await _loadProviderPreference();

    _generatedAudioStore = await _createGeneratedAudioStore();
    await _generatedAudioStore!.ensureInitialized();
    await _reloadGeneratedAudioStatistics();
    await taskManager.initialize();
    await _restoreGeneratedAudioTasks();
    await refreshModels();
  }

  /// Re-scans installed models.
  Future<void> refreshModels() async {
    _isLoadingModels = true;
    notifyListeners();

    try {
      _installedModels = await _modelService.getInstalledModels();
      if (_isVoiceCloningEnabled && pocketModel == null) {
        _isVoiceCloningEnabled = false;
      }

      final readyPocketModel = pocketModel;

      // Auto-select the current ready model, preferring Pocket TTS while
      // cloning mode is enabled.
      if (_selectedModel == null ||
          _selectedModel!.status != ModelStatus.ready) {
        final ready = readyModels;
        if (ready.isNotEmpty) {
          await selectModel(
            _isVoiceCloningEnabled && readyPocketModel != null
                ? readyPocketModel
                : ready.first,
          );
        } else {
          _selectedModel = null;
        }
      }
      if (_isVoiceCloningEnabled &&
          readyPocketModel != null &&
          _selectedModel?.voice.id != readyPocketModel.voice.id) {
        await selectModel(readyPocketModel);
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

    if (isLiveTtsStreaming) {
      await stopLiveTts();
    }

    if (_isVoiceCloningEnabled && model.voice.family != 'pocket') {
      _isVoiceCloningEnabled = false;
    }
    _selectedModel = model;
    _selectedSpeakerId = _resolveSpeakerId(
      model.voice,
      preferredSpeakerId: model.voice.defaultSpeakerId,
    );
    _errorMessage = null;
    notifyListeners();

    try {
      await taskManager.submitModelPreload(
        modelDir: model.modelDir!,
        voice: model.voice,
        providerOverride: _selectedProvider,
      );
    } catch (e) {
      _errorMessage = 'Failed to start background voice load: $e';
      notifyListeners();
    }
  }

  void setAdvancedLabEnabled(bool enabled) {
    if (_isAdvancedLabEnabled == enabled) return;
    _isAdvancedLabEnabled = enabled;
    if (!enabled) {
      _isVoiceCloningEnabled = false;
    }
    notifyListeners();
  }

  Future<void> setVoiceCloningEnabled(bool enabled) async {
    if (!enabled) {
      if (_isVoiceCloningEnabled) {
        _isVoiceCloningEnabled = false;
        notifyListeners();
      }
      return;
    }

    final readyPocketModel = pocketModel;
    if (readyPocketModel == null) {
      _isVoiceCloningEnabled = false;
      notifyListeners();
      return;
    }

    _isVoiceCloningEnabled = true;
    notifyListeners();

    if (_selectedModel?.voice.id == readyPocketModel.voice.id) {
      return;
    }

    await selectModel(readyPocketModel);
  }

  /// Downloads a model from the catalog.
  Future<void> downloadModel(VoiceModel voice) async {
    if (_isDownloading) return;
    final installTaskId = taskManager.startModelInstall(
      label: 'Install ${voice.displayName}',
      statusText: ModelInstallStage.downloading.label,
    );
    _activeInstallTaskId = installTaskId;
    _isDownloading = true;
    _downloadProgress = 0;
    _currentInstallProgress = const ModelInstallProgress(
      stage: ModelInstallStage.downloading,
      progress: 0,
    );
    _errorMessage = null;
    notifyListeners();

    try {
      await _modelService.downloadModel(
        voice,
        onProgress: (progress) {
          _currentInstallProgress = progress;
          _downloadProgress = progress.progress ?? _downloadProgress;
          taskManager.updateInstallTask(
            installTaskId,
            statusText: progress.stage.label,
            progress: progress.progress,
            transferredBytes: progress.downloadedBytes,
            totalBytes: progress.totalBytes,
          );
          notifyListeners();
        },
      );
      taskManager.completeInstallTask(
        installTaskId,
        statusText: 'Installed',
        progress: 1.0,
        transferredBytes: _currentInstallProgress?.downloadedBytes,
        totalBytes: _currentInstallProgress?.totalBytes,
      );
      await refreshModels();
    } on ModelDownloadCancelledException {
      taskManager.cancelInstallTask(
        installTaskId,
        statusText: 'Cancelled',
        transferredBytes: _currentInstallProgress?.downloadedBytes,
        totalBytes: _currentInstallProgress?.totalBytes,
      );
      await refreshModels();
    } catch (e) {
      _errorMessage = 'Download failed: $e';
      taskManager.failInstallTask(
        installTaskId,
        errorMessage: e.toString(),
        statusText: _currentInstallProgress?.stage.label ?? 'Failed',
        progress: _currentInstallProgress?.progress,
        transferredBytes: _currentInstallProgress?.downloadedBytes,
        totalBytes: _currentInstallProgress?.totalBytes,
      );
    } finally {
      _isDownloading = false;
      _currentInstallProgress = null;
      _activeInstallTaskId = null;
      notifyListeners();
    }
  }

  Future<void> deleteModel(VoiceModel voice) async {
    if (!canManageModels) {
      return;
    }

    _errorMessage = null;
    notifyListeners();

    try {
      await _modelService.deleteModel(voice);
      await refreshModels();
    } catch (e) {
      _errorMessage = 'Failed to delete model: $e';
      notifyListeners();
    }
  }

  // ---- Text / Settings ----

  void setInputText(String text) {
    if (_inputText == text) {
      return;
    }

    _inputText = text;
    if (_inputCursorOffset > text.length) {
      _inputCursorOffset = text.length;
    }
    if (isLiveTtsStreaming) {
      unawaited(stopLiveTts());
    }
    notifyListeners();
  }

  void setInputCursorOffset(int offset) {
    final nextOffset = offset < 0
        ? 0
        : (offset > _inputText.length ? _inputText.length : offset);
    if (_inputCursorOffset == nextOffset) {
      return;
    }
    _inputCursorOffset = nextOffset;
  }

  void setSpeed(double speed) {
    _speed = clampSpeechSpeed(speed);
    if (isLiveTtsStreaming) {
      unawaited(stopLiveTts());
    }
    notifyListeners();
  }

  void setSpeakerId(int speakerId) {
    final selectedModel = _selectedModel;
    if (selectedModel == null) {
      return;
    }

    _selectedSpeakerId = _resolveSpeakerId(
      selectedModel.voice,
      preferredSpeakerId: speakerId,
    );
    if (isLiveTtsStreaming) {
      unawaited(stopLiveTts());
    }
    notifyListeners();
  }

  void setLiveTtsEnabled(bool enabled) {
    if (_isLiveTtsEnabled == enabled) {
      return;
    }

    _isLiveTtsEnabled = enabled;
    if (!enabled) {
      unawaited(stopLiveTts());
    }
    notifyListeners();
  }

  void setLiveChunkSizeWords(int chunkSizeWords) {
    final nextValue = chunkSizeWords < 1 ? 1 : chunkSizeWords;
    if (_liveChunkSizeWords == nextValue) {
      return;
    }

    _liveChunkSizeWords = nextValue;
    if (isLiveTtsStreaming) {
      unawaited(stopLiveTts());
    }
    notifyListeners();
  }

  /// Changes the inference provider (cpu, cuda, rocm).
  /// Triggers a model reload so the new provider takes effect.
  Future<void> setProvider(String provider) async {
    if (provider == _selectedProvider) return;
    if (!_availableProviders.contains(provider)) return;

    if (isLiveTtsStreaming) {
      await stopLiveTts();
    }

    _selectedProvider = provider;
    notifyListeners();
    await _saveProviderPreference(provider);

    // Reload the model with the new provider if one is selected.
    if (_selectedModel != null &&
        _selectedModel!.status == ModelStatus.ready &&
        _selectedModel!.modelDir != null) {
      try {
        await taskManager.submitModelPreload(
          modelDir: _selectedModel!.modelDir!,
          voice: _selectedModel!.voice,
          providerOverride: _selectedProvider,
        );
      } catch (e) {
        _errorMessage = 'Failed to reload model with $provider: $e';
        _selectedProvider = 'cpu';
        notifyListeners();
      }
    }
  }

  // ---- Synthesis ----

  /// Generates speech from the current input text via background task.
  Future<void> generate() async {
    if (!canGenerate) return;

    if (isLiveTtsStreaming) {
      await stopLiveTts();
    }

    _errorMessage = null;
    await _audioService.stop();
    notifyListeners();

    final selectedModel = _selectedModel!;
    final outputDir = await _generatedAudioDirectory();
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
        speakerId: _selectedSpeakerId,
        outputPath: outputPath,
        providerOverride: _selectedProvider,
      );
    } catch (e) {
      _errorMessage = 'Failed to start synthesis task: $e';
      notifyListeners();
    }
  }

  Future<String> createGeneratedAudioOutputPath({
    String prefix = 'speech',
  }) async {
    final outputDir = await _generatedAudioDirectory();
    await outputDir.create(recursive: true);
    return p.join(
      outputDir.path,
      '$prefix-${DateTime.now().microsecondsSinceEpoch}.wav',
    );
  }

  Future<void> startLiveTts() async {
    final inputError = TextInputValidator.validate(_inputText);
    if (inputError != null) {
      _errorMessage = inputError;
      notifyListeners();
      return;
    }

    final selectedModel = _selectedModel;
    if (selectedModel?.status != ModelStatus.ready ||
        selectedModel?.modelDir == null) {
      _errorMessage = 'Install and select a model before starting live TTS.';
      notifyListeners();
      return;
    }

    await stopLiveTts();
    await _audioService.stop();

    final session = LiveTtsSession(
      executorFactory: () => IsolateTaskExecutor(),
      modelDir: selectedModel!.modelDir!,
      voice: selectedModel.voice,
      text: _inputText,
      speed: _speed,
      speakerId: _selectedSpeakerId,
      chunkSizeWords: _liveChunkSizeWords,
      outputDirectoryPath: (await _generatedAudioDirectory()).path,
      startOffset: _inputCursorOffset,
      providerOverride: _selectedProvider,
    );
    if (session.chunks.isEmpty) {
      _errorMessage =
          'Move the text cursor before some text to start live playback there.';
      notifyListeners();
      return;
    }
    session.addListener(_handleLiveTtsSessionChanged);
    _liveTtsSession = session;
    _errorMessage = null;
    notifyListeners();

    await session.start();
    await _playNextLiveChunkIfReady();
  }

  Future<void> stopLiveTts() async {
    if (_isStoppingLiveTts) {
      return;
    }

    _isStoppingLiveTts = true;
    try {
      final session = _liveTtsSession;
      if (session != null) {
        session.removeListener(_handleLiveTtsSessionChanged);
        _liveTtsSession = null;
        await _audioService.stop();
        await session.stop();
        session.dispose();
      }
      _isStartingLivePlayback = false;
      notifyListeners();
    } finally {
      _isStoppingLiveTts = false;
    }
  }

  void registerExternalGeneratedAudio({
    required String label,
    required String modelId,
    required String modelName,
    required int inputCharacterCount,
    required double speechSpeed,
    required String outputPath,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) {
    final completedTask = LongRunningTask(
      id: 'task-${DateTime.now().microsecondsSinceEpoch}',
      type: LongRunningTaskType.synthesizeSpeech,
      label: label,
      startedAt: startedAt ?? DateTime.now(),
      status: LongRunningTaskStatus.completed,
      inputCharacterCount: inputCharacterCount,
      speechSpeed: clampSpeechSpeed(speechSpeed),
      modelId: modelId,
      modelName: modelName,
      finishedAt: finishedAt ?? DateTime.now(),
      outputPath: outputPath,
    );

    taskManager.restoreTasks([completedTask]);
    _generatedWavPath = outputPath;
    _synthesisStatus = SynthesisStatus.done;
    _errorMessage = null;
    notifyListeners();
  }

  // ---- Playback ----

  Future<void> play() async {
    if (_generatedWavPath == null) return;
    try {
      _currentTaskId = null;
      await _audioService.play(_generatedWavPath!);
    } catch (e) {
      _errorMessage = 'Playback failed: $e';
      notifyListeners();
    }
  }

  Future<void> playTaskAudio(String outputPath) async {
    String? nextTaskId;
    // Find the task ID for this output path.
    for (final task in taskManager.tasks) {
      if (task.outputPath == outputPath) {
        nextTaskId = task.id;
        break;
      }
    }

    final isSameActiveAudio =
        _currentTaskId == nextTaskId && _playbackState == PlaybackState.paused;
    _currentTaskId = nextTaskId;
    _generatedWavPath = outputPath;
    if (!isSameActiveAudio) {
      _playbackPosition = Duration.zero;
    }
    notifyListeners();
    try {
      await _audioService.play(outputPath);
    } catch (e) {
      _errorMessage = 'Playback failed: $e';
      _currentTaskId = null;
      notifyListeners();
    }
  }

  Future<void> pausePlayback() async {
    try {
      await _audioService.pause();
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Pause failed: $e';
      notifyListeners();
    }
  }

  Future<void> stopPlayback() async {
    await _audioService.stop();
  }

  Future<void> seekPlayback(Duration position) async {
    try {
      await _audioService.seek(position);
    } catch (e) {
      _errorMessage = 'Seek failed: $e';
      notifyListeners();
    }
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
    String? savePath;

    if (Platform.isLinux) {
      savePath = await _zenitySaveDialog(
        initialFilename: p.basename(sourcePath),
      );
    } else if (Platform.isWindows) {
      final home = Platform.environment['USERPROFILE'] ?? '.';
      savePath = p.join(home, 'Documents', p.basename(sourcePath));
    } else {
      final home =
          Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '.';
      savePath = p.join(home, p.basename(sourcePath));
    }

    if (savePath == null || savePath.trim().isEmpty) {
      return false;
    }

    if (!savePath.toLowerCase().endsWith('.wav')) {
      savePath = '$savePath.wav';
    }

    try {
      final destination = File(savePath);
      if (await destination.exists()) {
        await destination.delete();
      }
      await File(sourcePath).copy(savePath);
      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Save failed: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> cancelManagedTask(LongRunningTask task) async {
    try {
      if (task.type == LongRunningTaskType.installModel) {
        if (_activeInstallTaskId != task.id) {
          return;
        }
        taskManager.markInstallTaskCancelling(
          task.id,
          statusText: 'Cancelling',
        );
        await _modelService.cancelActiveDownload();
      } else {
        await taskManager.cancelTask(task.id);
      }
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to cancel task: $e';
      notifyListeners();
    }
  }

  Future<void> dismissManagedTask(LongRunningTask task) async {
    final outputPath = task.outputPath;

    try {
      if (outputPath != null) {
        if (_generatedWavPath == outputPath) {
          await _audioService.stop();
          _currentTaskId = null;
          _generatedWavPath = null;
          _playbackPosition = Duration.zero;
          _playbackDuration = null;
        }

        final file = File(outputPath);
        if (await file.exists()) {
          await file.delete();
        }

        await _generatedAudioStore?.removeByOutputPath(outputPath);
        _persistedGeneratedAudioPaths.remove(outputPath);
      }

      taskManager.dismissTask(task.id);
      _generatedWavPath = taskManager.latestCompletedSynthesis?.outputPath;
      _errorMessage = null;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to dismiss task: $e';
      notifyListeners();
    }
  }

  // ---- Task Manager Integration ----

  void _handleTaskManagerChanged() {
    unawaited(_persistCompletedGeneratedAudioTasks());
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

  void _handleLiveTtsSessionChanged() {
    final session = _liveTtsSession;
    if (session == null) {
      return;
    }

    if (session.errorMessage != null) {
      _errorMessage = session.errorMessage;
      unawaited(stopLiveTts());
      notifyListeners();
      return;
    }

    unawaited(_playNextLiveChunkIfReady());
    notifyListeners();
  }

  Future<void> _handleLivePlaybackStateChange(
    PlaybackState previousState,
    PlaybackState nextState,
  ) async {
    if (_isStoppingLiveTts ||
        previousState != PlaybackState.playing ||
        nextState != PlaybackState.stopped) {
      return;
    }

    final session = _liveTtsSession;
    final playingChunk = session?.playingChunk;
    if (session == null || playingChunk == null) {
      return;
    }

    session.markChunkCompleted(playingChunk.index);
    if (session.isFinished) {
      await stopLiveTts();
      return;
    }

    await _playNextLiveChunkIfReady();
  }

  Future<void> _playNextLiveChunkIfReady() async {
    final session = _liveTtsSession;
    if (session == null ||
        _isStoppingLiveTts ||
        _isStartingLivePlayback ||
        session.playingChunk != null) {
      return;
    }

    final nextChunk = session.nextReadyChunk;
    final outputPath = nextChunk?.outputPath;
    if (nextChunk == null || outputPath == null || outputPath.trim().isEmpty) {
      return;
    }

    _isStartingLivePlayback = true;
    session.markChunkPlaying(nextChunk.index);
    _generatedWavPath = outputPath;
    _currentTaskId = null;
    notifyListeners();

    try {
      await _audioService.play(outputPath);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Live playback failed: $e';
      await stopLiveTts();
    } finally {
      _isStartingLivePlayback = false;
      notifyListeners();
    }
  }

  Future<Directory> _generatedAudioDirectory() async {
    final modelsDirectory = await _modelService.getModelsDirectory();
    return Directory(
      p.join(Directory(modelsDirectory).parent.path, 'generated_audio'),
    );
  }

  Future<GeneratedAudioStore> _createGeneratedAudioStore() async {
    final outputDir = await _generatedAudioDirectory();
    return GeneratedAudioStore(
      libraryFile: File(
        p.join(outputDir.path, GeneratedAudioStore.defaultLibraryPath),
      ),
      statsFile: File(
        p.join(outputDir.path, GeneratedAudioStore.defaultStatsPath),
      ),
    );
  }

  Future<void> _restoreGeneratedAudioTasks() async {
    try {
      final store = _generatedAudioStore;
      if (store == null) {
        return;
      }

      final persistedTasks = await store.loadTasks();
      _persistedGeneratedAudioPaths
        ..clear()
        ..addAll(
          persistedTasks.map((task) => task.outputPath).whereType<String>(),
        );

      taskManager.restoreTasks(persistedTasks);
      _generatedWavPath = taskManager.latestCompletedSynthesis?.outputPath;
      if (_generatedWavPath != null) {
        _synthesisStatus = SynthesisStatus.done;
      }
    } catch (e) {
      _errorMessage = 'Failed to restore generated audio: $e';
    }
  }

  Future<void> _persistCompletedGeneratedAudioTasks() async {
    final store = _generatedAudioStore;
    if (store == null) {
      return;
    }

    try {
      for (final task in taskManager.completedSynthesisTasks) {
        final outputPath = task.outputPath;
        if (outputPath == null ||
            _persistedGeneratedAudioPaths.contains(outputPath)) {
          continue;
        }

        _persistedGeneratedAudioPaths.add(outputPath);
        try {
          await store.upsertTask(task);
          await store.updateStatisticsForTask(task);
        } catch (_) {
          _persistedGeneratedAudioPaths.remove(outputPath);
          rethrow;
        }
      }
      await _reloadGeneratedAudioStatistics();
    } catch (e) {
      _errorMessage = 'Failed to persist generated audio metadata: $e';
      notifyListeners();
    }
  }

  Future<void> _reloadGeneratedAudioStatistics() async {
    final store = _generatedAudioStore;
    if (store == null) {
      _generatedAudioStatistics = const {};
      return;
    }

    _generatedAudioStatistics = await store.loadStatistics();
  }

  Duration? _expectedGenerationDurationForCurrentInput() {
    final stats = _currentModelStatistics;
    final characterCount = _trimmedInputCharacterCount;
    if (stats == null || characterCount <= 0) {
      return null;
    }

    final seconds = stats.expectedGenerationSecondsForChars(characterCount);
    return _secondsToDurationOrNull(seconds);
  }

  Duration? _expectedOutputDurationForCurrentInput() {
    final stats = _currentModelStatistics;
    final characterCount = _trimmedInputCharacterCount;
    if (stats == null || characterCount <= 0) {
      return null;
    }

    final seconds = stats.expectedOutputSecondsForChars(
      characterCount,
      speechSpeed: _speed,
    );
    return _secondsToDurationOrNull(seconds);
  }

  GeneratedAudioStatistics? get _currentModelStatistics {
    final modelName = _selectedModel?.voice.displayName;
    if (modelName == null) {
      return null;
    }
    return _generatedAudioStatistics[modelName];
  }

  int get _trimmedInputCharacterCount => _inputText.trim().length;

  Duration? _secondsToDurationOrNull(double seconds) {
    if (seconds <= 0) {
      return null;
    }

    return Duration(
      microseconds: (seconds * Duration.microsecondsPerSecond).round(),
    );
  }

  int _resolveSpeakerId(VoiceModel voice, {int? preferredSpeakerId}) {
    final speakers = voice.speakers;
    if (speakers.isEmpty) {
      return voice.defaultSpeakerId;
    }

    if (preferredSpeakerId != null &&
        speakers.any((speaker) => speaker.id == preferredSpeakerId)) {
      return preferredSpeakerId;
    }

    if (speakers.any((speaker) => speaker.id == voice.defaultSpeakerId)) {
      return voice.defaultSpeakerId;
    }

    return speakers.first.id;
  }

  // ---- Provider Persistence ----

  static const String _providerPrefFile = '.tts_provider_pref';

  Future<String> _loadProviderPreference() async {
    try {
      final home =
          Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '';
      if (home.isEmpty) return 'cpu';
      final file = File(p.join(home, _providerPrefFile));
      if (await file.exists()) {
        final saved = (await file.readAsString()).trim();
        if (_availableProviders.contains(saved)) return saved;
      }
    } catch (_) {}
    return 'cpu';
  }

  Future<void> _saveProviderPreference(String provider) async {
    try {
      final home =
          Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '';
      if (home.isEmpty) return;
      final file = File(p.join(home, _providerPrefFile));
      await file.writeAsString(provider);
    } catch (_) {}
  }

  Future<String?> _zenitySaveDialog({required String initialFilename}) async {
    try {
      final result = await Process.run('zenity', [
        '--file-selection',
        '--save',
        '--confirm-overwrite',
        '--title=Save WAV file',
        '--filename=$initialFilename',
        '--file-filter=WAV files (*.wav) | *.wav',
      ]);
      if (result.exitCode == 0) {
        return (result.stdout as String).trim();
      }
    } catch (_) {}
    return null;
  }

  // ---- Cleanup ----

  @override
  void dispose() {
    taskManager.removeListener(_handleTaskManagerChanged);
    _liveTtsSession?.removeListener(_handleLiveTtsSessionChanged);
    unawaited(_liveTtsSession?.stop());
    unawaited(_audioSubscription?.cancel());
    unawaited(_audioPositionSubscription?.cancel());
    unawaited(_audioDurationSubscription?.cancel());
    taskManager.dispose();
    _modelService.dispose();
    _audioService.dispose();
    super.dispose();
  }
}
