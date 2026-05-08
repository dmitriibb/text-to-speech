import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:tts_core/tts_core.dart';

import '../services/audio_service.dart';
import '../services/model_service.dart';

enum SynthesisStatus { idle, generating, done, error }

class AppState extends ChangeNotifier {
  static const String cpuProvider = 'cpu';
  static const String nnapiProvider = 'nnapi';
  static const List<String> androidInferenceProviders = <String>[
    cpuProvider,
    nnapiProvider,
  ];
  static const String _settingsFileName = 'app_settings.json';
  static const String _inferenceProviderKey = 'inferenceProvider';

  final ModelService _modelService = ModelService();
  final AudioService _audioService = AudioService();
  final TaskManager taskManager = TaskManager(executor: IsolateTaskExecutor());
  GeneratedAudioStore? _generatedAudioStore;
  Map<String, GeneratedAudioStatistics> _generatedAudioStatistics = const {};
  final Set<String> _persistedGeneratedAudioPaths = <String>{};

  StreamSubscription<PlaybackState>? _audioSubscription;
  StreamSubscription<Duration>? _audioPositionSubscription;
  StreamSubscription<Duration?>? _audioDurationSubscription;
  StreamSubscription<Object>? _audioErrorSubscription;
  String? _currentTaskId;

  List<InstalledModel> _installedModels = [];
  InstalledModel? _selectedModel;
  bool _isLoadingModels = true;
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _modelsDirectory;
  ModelInstallProgress? _currentInstallProgress;
  String? _activeInstallTaskId;

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
  String _selectedInferenceProvider = cpuProvider;

  String? _generatedWavPath;
  PlaybackState _playbackState = PlaybackState.stopped;
  Duration _playbackPosition = Duration.zero;
  Duration? _playbackDuration;

  List<InstalledModel> get installedModels => _installedModels;
  InstalledModel? get selectedModel => _selectedModel;
  bool get isLoadingModels => _isLoadingModels;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String? get modelsDirectory => _modelsDirectory;
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
  VoidCallback? get livePlayPauseAction {
    if (!isLiveTtsStreaming) {
      return canGenerate ? startLiveTts : null;
    }
    return _playbackState == PlaybackState.playing
        ? pauseLiveTts
        : resumeLiveTts;
  }

  String get selectedInferenceProvider => _selectedInferenceProvider;
  List<String> get availableInferenceProviders => androidInferenceProviders;
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

  bool get hasActiveTasks => taskManager.hasActiveTasks;
  bool get hasActiveSynthesisTasks => taskManager.hasActiveSynthesisTasks;
  bool get canManageModels => !_isLoadingModels && !_isDownloading;
  bool get canSelectModel => canManageModels && readyModels.isNotEmpty;
  bool get canAdjustSpeed => !_isLoadingModels && !_isDownloading;

  bool get hasAudio => _generatedWavPath != null;
  bool get canGenerate =>
      !_isDownloading &&
      _selectedModel?.status == ModelStatus.ready &&
      TextInputValidator.validate(_inputText) == null;

  List<InstalledModel> get readyModels => _installedModels
      .where((model) => model.status == ModelStatus.ready)
      .toList();

  List<InstalledModel> get installableModels => _installedModels
      .where((model) => model.status != ModelStatus.ready)
      .toList();

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
    _audioErrorSubscription = _audioService.onError.listen((error) {
      _errorMessage = 'Playback failed: $error';
      notifyListeners();
    });
    _modelsDirectory = await _modelService.getModelsDirectory();
    _selectedInferenceProvider = await _loadInferenceProviderPreference();
    _generatedAudioStore = await _createGeneratedAudioStore();
    await _generatedAudioStore!.ensureInitialized();
    await _reloadGeneratedAudioStatistics();
    await taskManager.initialize();
    await _restoreGeneratedAudioTasks();
    await refreshModels();
  }

  Future<void> refreshModels() async {
    _isLoadingModels = true;
    notifyListeners();

    try {
      _installedModels = await _modelService.getInstalledModels();
      final nextSelection = _resolveSelection();
      if (nextSelection != null) {
        final preserveSpeaker =
            _selectedModel?.voice.id == nextSelection.voice.id;
        _speed = clampSpeechSpeed(nextSelection.voice.defaultSpeed);
        _selectedSpeakerId = _resolveSpeakerId(
          nextSelection.voice,
          preferredSpeakerId: preserveSpeaker ? _selectedSpeakerId : null,
        );
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
    if (!canSelectModel ||
        model.status != ModelStatus.ready ||
        model.modelDir == null) {
      return;
    }

    if (isLiveTtsStreaming) {
      await stopLiveTts();
    }

    _selectedModel = model;
    _speed = clampSpeechSpeed(model.voice.defaultSpeed);
    _selectedSpeakerId = _resolveSpeakerId(
      model.voice,
      preferredSpeakerId: model.voice.defaultSpeakerId,
    );
    _errorMessage = null;
    notifyListeners();

    unawaited(_queueModelPreload(model));
  }

  Future<void> downloadModel(VoiceModel voice) async {
    if (_isDownloading) {
      return;
    }

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
    } catch (error) {
      _errorMessage = 'Download failed: $error';
      taskManager.failInstallTask(
        installTaskId,
        errorMessage: error.toString(),
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
    } catch (error) {
      _errorMessage = 'Failed to delete model: $error';
      notifyListeners();
    }
  }

  void setInputText(String text) {
    if (_inputText == text) {
      return;
    }

    _inputText = text;
    if (_inputCursorOffset > text.length) {
      _inputCursorOffset = text.length;
    }
    if (_errorMessage != null && TextInputValidator.validate(text) == null) {
      _errorMessage = null;
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

  Future<void> setInferenceProvider(String provider) async {
    if (!androidInferenceProviders.contains(provider) ||
        provider == _selectedInferenceProvider) {
      return;
    }

    if (isLiveTtsStreaming) {
      await stopLiveTts();
    }

    _selectedInferenceProvider = provider;
    _errorMessage = null;
    notifyListeners();

    try {
      await _saveInferenceProviderPreference(provider);
    } catch (error) {
      _errorMessage = 'Failed to save settings: $error';
      notifyListeners();
    }

    final selectedModel = _selectedModel;
    if (selectedModel?.status == ModelStatus.ready &&
        selectedModel?.modelDir != null) {
      unawaited(_queueModelPreload(selectedModel!));
    }
  }

  Future<void> generate() async {
    final inputError = TextInputValidator.validate(_inputText);
    if (inputError != null) {
      _errorMessage = inputError;
      notifyListeners();
      return;
    }

    if (isLiveTtsStreaming) {
      await stopLiveTts();
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
      await taskManager.submitSynthesis(
        modelDir: selectedModel.modelDir!,
        voice: selectedModel.voice,
        text: inputText,
        speed: speed,
        speakerId: _selectedSpeakerId,
        outputPath: await _resolveOutputPath(),
        providerOverride: _selectedInferenceProvider,
      );
      _errorMessage = null;
    } catch (error) {
      _errorMessage = 'Failed to start synthesis task: $error';
    }

    notifyListeners();
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
      providerOverride: _selectedInferenceProvider,
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

  Future<void> pauseLiveTts() async {
    if (!isLiveTtsStreaming || _playbackState != PlaybackState.playing) {
      return;
    }
    await pausePlayback();
  }

  Future<void> resumeLiveTts() async {
    final session = _liveTtsSession;
    if (session == null || _isStoppingLiveTts) {
      return;
    }

    final playingChunk = session.playingChunk;
    if (playingChunk != null) {
      final outputPath = playingChunk.outputPath;
      if (outputPath == null || outputPath.trim().isEmpty) {
        return;
      }

      try {
        _generatedWavPath = outputPath;
        _currentTaskId = null;
        notifyListeners();
        await _audioService.play(outputPath);
        _errorMessage = null;
        notifyListeners();
      } catch (error) {
        _errorMessage = 'Live playback failed: $error';
        notifyListeners();
      }
      return;
    }

    await _playNextLiveChunkIfReady();
  }

  Future<String> _resolveOutputPath() async {
    final outputDir = await _generatedAudioDirectory();
    await outputDir.create(recursive: true);

    return p.join(
      outputDir.path,
      'speech-${DateTime.now().microsecondsSinceEpoch}.wav',
    );
  }

  Future<Directory> _generatedAudioDirectory() async {
    final modelsDirectory =
        _modelsDirectory ?? await _modelService.getModelsDirectory();
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

      final legacyTasks = await _restoreLegacyGeneratedAudioTasks(
        existingOutputPaths: _persistedGeneratedAudioPaths,
      );
      for (final task in legacyTasks) {
        await store.upsertTask(task);
        final outputPath = task.outputPath;
        if (outputPath != null) {
          _persistedGeneratedAudioPaths.add(outputPath);
        }
      }

      taskManager.restoreTasks([...persistedTasks, ...legacyTasks]);
      _generatedWavPath = taskManager.latestCompletedSynthesis?.outputPath;
      if (_generatedWavPath != null) {
        _synthesisStatus = SynthesisStatus.done;
      }
    } catch (error) {
      _errorMessage = 'Failed to restore generated audio: $error';
    }
  }

  Future<LongRunningTask?> _buildRestoredGeneratedAudioTask(File file) async {
    final stat = await file.stat();
    if (stat.size <= 0) {
      return null;
    }

    final basename = p.basenameWithoutExtension(file.path);
    final startedAt = _inferGeneratedAudioStartedAt(
      basename,
      fallback: stat.modified,
    );
    final finishedAt = stat.modified.isAfter(startedAt)
        ? stat.modified
        : startedAt;

    return LongRunningTask(
      id: 'restored-$basename',
      type: LongRunningTaskType.synthesizeSpeech,
      label: basename,
      startedAt: startedAt,
      status: LongRunningTaskStatus.completed,
      modelName: 'Unknown',
      finishedAt: finishedAt,
      outputPath: file.path,
    );
  }

  DateTime _inferGeneratedAudioStartedAt(
    String basename, {
    required DateTime fallback,
  }) {
    const prefix = 'speech-';
    if (!basename.startsWith(prefix)) {
      return fallback;
    }

    final timestamp = int.tryParse(basename.substring(prefix.length));
    if (timestamp == null) {
      return fallback;
    }

    return DateTime.fromMicrosecondsSinceEpoch(timestamp);
  }

  Future<void> cancelTask(String taskId) async {
    try {
      await taskManager.cancelTask(taskId);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = 'Failed to cancel task: $error';
      notifyListeners();
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
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Failed to cancel task: $error';
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
    } catch (error) {
      _errorMessage = 'Failed to dismiss task: $error';
      notifyListeners();
    }
  }

  String formatTaskElapsed(LongRunningTask task) {
    return taskManager.formatElapsed(task);
  }

  String describeTaskStatus(LongRunningTask task) {
    return taskManager.describeStatus(task);
  }

  Future<void> play() async {
    if (_generatedWavPath == null) return;
    try {
      _currentTaskId = null;
      await _audioService.play(_generatedWavPath!);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = 'Playback failed: $error';
      notifyListeners();
    }
  }

  Future<void> playTaskAudio(String outputPath) async {
    String? nextTaskId;
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
      _errorMessage = null;
    } catch (error) {
      _errorMessage = 'Playback failed: $error';
      _currentTaskId = null;
      notifyListeners();
    }
  }

  Future<void> pausePlayback() async {
    try {
      await _audioService.pause();
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Pause failed: $error';
      notifyListeners();
    }
  }

  Future<void> stopPlayback() async {
    await _audioService.stop();
  }

  Future<void> seekPlayback(Duration position) async {
    try {
      await _audioService.seek(position);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = 'Seek failed: $error';
      notifyListeners();
    }
  }

  Future<bool> shareGeneratedAudio() async {
    if (_generatedWavPath == null) return false;
    return shareTaskAudio(_generatedWavPath!);
  }

  Future<bool> shareTaskAudio(String outputPath) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(outputPath)],
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
      await taskManager.submitModelPreload(
        modelDir: model.modelDir!,
        voice: model.voice,
        providerOverride: _selectedInferenceProvider,
      );
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Failed to start background voice load: $error';
      notifyListeners();
    }
  }

  void _handleTaskManagerChanged() {
    unawaited(_persistCompletedGeneratedAudioTasks());
    final hasSynthesis = taskManager.hasActiveSynthesisTasks;
    if (hasSynthesis) {
      _synthesisStatus = SynthesisStatus.generating;
    } else if (_synthesisStatus == SynthesisStatus.generating) {
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
    } catch (error) {
      _errorMessage = 'Live playback failed: $error';
      await stopLiveTts();
    } finally {
      _isStartingLivePlayback = false;
      notifyListeners();
    }
  }

  Future<List<LongRunningTask>> _restoreLegacyGeneratedAudioTasks({
    required Set<String> existingOutputPaths,
  }) async {
    final outputDir = await _generatedAudioDirectory();
    if (!await outputDir.exists()) {
      return const <LongRunningTask>[];
    }

    final restoredTasks = <LongRunningTask>[];
    await for (final entity in outputDir.list(followLinks: false)) {
      if (entity is! File ||
          p.extension(entity.path).toLowerCase() != '.wav' ||
          existingOutputPaths.contains(entity.path)) {
        continue;
      }

      final restoredTask = await _buildRestoredGeneratedAudioTask(entity);
      if (restoredTask != null) {
        restoredTasks.add(restoredTask);
      }
    }

    return restoredTasks;
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
    } catch (error) {
      _errorMessage = 'Failed to persist generated audio metadata: $error';
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

  Future<File> _settingsFile() async {
    final modelsDirectory =
        _modelsDirectory ?? await _modelService.getModelsDirectory();
    return File(
      p.join(Directory(modelsDirectory).parent.path, _settingsFileName),
    );
  }

  Future<String> _loadInferenceProviderPreference() async {
    try {
      final file = await _settingsFile();
      if (!await file.exists()) {
        return cpuProvider;
      }

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) {
        return cpuProvider;
      }

      final provider = decoded[_inferenceProviderKey] as String?;
      if (provider != null && androidInferenceProviders.contains(provider)) {
        return provider;
      }
    } catch (_) {
      return cpuProvider;
    }

    return cpuProvider;
  }

  Future<void> _saveInferenceProviderPreference(String provider) async {
    final file = await _settingsFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode(<String, Object?>{_inferenceProviderKey: provider}),
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

  @override
  void dispose() {
    taskManager.removeListener(_handleTaskManagerChanged);
    _liveTtsSession?.removeListener(_handleLiveTtsSessionChanged);
    unawaited(_liveTtsSession?.stop());
    unawaited(_audioSubscription?.cancel());
    unawaited(_audioPositionSubscription?.cancel());
    unawaited(_audioDurationSubscription?.cancel());
    unawaited(_audioErrorSubscription?.cancel());
    taskManager.dispose();
    _modelService.dispose();
    unawaited(_audioService.dispose());
    super.dispose();
  }
}
