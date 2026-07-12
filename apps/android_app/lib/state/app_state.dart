import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  static const String _modelSettingsFileName = 'model_settings.json';

  final ModelService _modelService = ModelService();
  final AudioService _audioService = AudioService();
  final TaskManager taskManager = TaskManager(executor: IsolateTaskExecutor());
  GeneratedAudioStore? _generatedAudioStore;
  Map<String, GeneratedAudioStatistics> _generatedAudioStatistics = const {};
  final Set<String> _persistedGeneratedAudioPaths = <String>{};
  int _generatedAudioPathCounter = 0;

  StreamSubscription<PlaybackState>? _audioSubscription;
  StreamSubscription<Duration>? _audioPositionSubscription;
  StreamSubscription<Duration?>? _audioDurationSubscription;
  StreamSubscription<Object>? _audioErrorSubscription;
  String? _currentTaskId;

  List<InstalledModel> _installedModels = [];
  InstalledModel? _selectedModel;
  final Map<String, ModelSynthesisSettings> _modelSettingsById = {};
  Map<String, Object?> _persistedModelSettingsJson = {};
  bool _isLoadingModels = true;
  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _modelsDirectory;
  ModelInstallProgress? _currentInstallProgress;
  String? _activeInstallTaskId;

  String _inputText = '';
  double _speed = speechSpeedDefault;
  int _selectedSpeakerId = 0;
  String _selectedGenerationLanguage = '';
  int _inputCursorOffset = 0;
  SynthesisStatus _synthesisStatus = SynthesisStatus.idle;
  String? _errorMessage;
  bool _isLiveTtsEnabled = false;
  int _liveChunkSizeWords = 10;
  LiveTtsSession? _liveTtsSession;
  bool _isStartingLivePlayback = false;
  bool _isStoppingLiveTts = false;
  final DialogModeParser _dialogParser = const DialogModeParser();
  List<DialogLineItem> _dialogLines = const <DialogLineItem>[];
  Map<String, DialogSpeakerSettings> _dialogSpeakerSettings =
      const <String, DialogSpeakerSettings>{};
  String? _dialogErrorMessage;
  int? _dialogPlaybackIndex;
  bool _dialogAutoAdvance = false;
  bool _dialogPlaybackStarted = false;
  bool _isAdvancingDialogPlayback = false;
  bool _isStoppingDialogPlayback = false;
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
  double get volume => modelSettings.volume;
  ModelSynthesisSettings get modelSettings {
    final model = _selectedModel;
    if (model == null) return const ModelSynthesisSettings();
    return _settingsFor(model.voice);
  }

  int get selectedSpeakerId => _selectedSpeakerId;
  String get selectedGenerationLanguage => _selectedGenerationLanguage;
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
  List<DialogLineItem> get dialogLines => _dialogLines;
  Map<String, DialogSpeakerSettings> get dialogSpeakerSettings =>
      _dialogSpeakerSettings;
  String? get dialogErrorMessage => _dialogErrorMessage;
  bool get isDialogGenerating => _dialogLines.any(
    (line) =>
        line.status == DialogLineStatus.queued ||
        line.status == DialogLineStatus.generating,
  );
  bool get isDialogPlaying =>
      _dialogPlaybackIndex != null && _playbackState == PlaybackState.playing;
  String? get activeDialogLineId {
    final index = _dialogPlaybackIndex;
    if (index == null || index < 0 || index >= _dialogLines.length) {
      return null;
    }
    return _dialogLines[index].id;
  }

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
      unawaited(_handleDialogPlaybackStateChange(previousState, state));
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
    _persistedModelSettingsJson = await _loadModelSettingsJson();
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
        _applySettingsFields(_settingsFor(nextSelection.voice));
      } else {
        _selectedGenerationLanguage = '';
      }
      _selectedModel = nextSelection;
      _normalizeDialogSpeakerSettings();
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
    _applySettingsFields(_settingsFor(model.voice));
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
    applyModelSettings(modelSettings.copyWith(speed: speed));
  }

  void setSpeakerId(int speakerId) {
    final selectedModel = _selectedModel;
    if (selectedModel == null) {
      return;
    }

    final resolved = _resolveSpeakerId(
      selectedModel.voice,
      preferredSpeakerId: speakerId,
    );
    applyModelSettings(modelSettings.copyWith(speakerId: resolved));
  }

  void setGenerationLanguage(String language) {
    final selectedModel = _selectedModel;
    if (selectedModel == null) {
      return;
    }

    final nextLanguage = selectedModel.voice.resolveGenerationLanguage(
      language,
    );
    if (_selectedGenerationLanguage == nextLanguage) {
      return;
    }

    applyModelSettings(
      modelSettings.copyWith(generationLanguage: nextLanguage),
    );
  }

  void applyModelSettings(ModelSynthesisSettings settings) {
    final model = _selectedModel;
    if (model == null) return;
    final normalized = ModelSynthesisSettings.fromJson(
      settings.toJson(),
      model.voice,
    );
    _modelSettingsById[model.voice.id] = normalized;
    _applySettingsFields(normalized);
    if (isLiveTtsStreaming) unawaited(stopLiveTts());
    unawaited(_saveModelSettings());
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
    if (_dialogPlaybackIndex != null) {
      await stopDialogPlayback();
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
        volumeGain: volume,
        generationLanguage: _selectedGenerationLanguage,
        outputPath: await createGeneratedAudioOutputPath(),
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
    if (_dialogPlaybackIndex != null) {
      await stopDialogPlayback();
    }
    await _audioService.stop();

    final session = LiveTtsSession(
      executorFactory: () => IsolateTaskExecutor(),
      modelDir: selectedModel!.modelDir!,
      voice: selectedModel.voice,
      text: _inputText,
      speed: _speed,
      speakerId: _selectedSpeakerId,
      volumeGain: volume,
      generationLanguage: _selectedGenerationLanguage,
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

  Future<String> createGeneratedAudioOutputPath({
    String prefix = 'speech',
  }) async {
    final outputDir = await _generatedAudioDirectory();
    await outputDir.create(recursive: true);
    _generatedAudioPathCounter++;

    return p.join(
      outputDir.path,
      '$prefix-${DateTime.now().microsecondsSinceEpoch}-$_generatedAudioPathCounter.wav',
    );
  }

  // ---- Dialog mode ----

  Future<void> pasteDialogFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final parsedLines = _dialogParser.parse(data?.text ?? '');
    if (parsedLines.isEmpty) {
      _dialogErrorMessage =
          'Clipboard does not contain lines in the form "Speaker: text".';
      notifyListeners();
      return;
    }

    await stopDialogPlayback();
    _dialogLines = parsedLines;
    _dialogSpeakerSettings = _buildDialogSpeakerSettings(parsedLines);
    _dialogErrorMessage = null;
    notifyListeners();
  }

  Future<void> generateDialog() async {
    final linesToGenerate = _dialogLines
        .where((line) => line.hasText)
        .toList(growable: false);
    if (linesToGenerate.isEmpty) {
      _dialogErrorMessage = 'Keep at least one dialog line with text.';
      notifyListeners();
      return;
    }

    if (isLiveTtsStreaming) {
      await stopLiveTts();
    }
    if (_dialogPlaybackIndex != null) {
      await stopDialogPlayback();
    }
    await _audioService.stop();

    final taskUpdates = <String, DialogLineItem>{};
    for (final line in linesToGenerate) {
      final model = _dialogModelForSpeaker(line.speakerName);
      if (model?.modelDir == null || model?.status != ModelStatus.ready) {
        _dialogErrorMessage =
            'Select a ready AI model for ${line.speakerName}.';
        notifyListeners();
        return;
      }
      taskUpdates[line.id] = line.copyWith(
        status: DialogLineStatus.queued,
        taskId: null,
        outputPath: null,
        errorMessage: null,
      );
    }
    _dialogLines = _dialogLines
        .map((line) => taskUpdates[line.id] ?? line)
        .toList(growable: false);
    _dialogErrorMessage = null;
    notifyListeners();

    for (final line in linesToGenerate) {
      final current = _dialogLineById(line.id);
      if (current == null || !current.hasText) {
        continue;
      }

      final model = _dialogModelForSpeaker(current.speakerName);
      if (model?.modelDir == null) {
        continue;
      }

      try {
        final taskId = await taskManager.submitSynthesis(
          modelDir: model!.modelDir!,
          voice: model.voice,
          text: current.text.trim(),
          speed: _speed,
          speakerId: _dialogSpeakerIdFor(current.speakerName, model.voice),
          generationLanguage: _dialogGenerationLanguageFor(
            current.speakerName,
            model.voice,
          ),
          volume: _dialogVolumeForSpeaker(current.speakerName),
          outputPath: await createGeneratedAudioOutputPath(prefix: 'dialog'),
          providerOverride: _selectedInferenceProvider,
        );
        _replaceDialogLine(
          current.id,
          current.copyWith(
            taskId: taskId,
            status: DialogLineStatus.queued,
            errorMessage: null,
          ),
        );
      } catch (error) {
        _replaceDialogLine(
          current.id,
          current.copyWith(
            status: DialogLineStatus.failed,
            errorMessage: 'Failed to start synthesis: $error',
          ),
        );
      }
    }
    notifyListeners();
  }

  Future<void> playPauseDialog() async {
    if (_dialogPlaybackIndex != null) {
      if (_playbackState == PlaybackState.playing) {
        await pausePlayback();
        return;
      }
      if (_playbackState == PlaybackState.paused) {
        await _playDialogFromIndex(
          _dialogPlaybackIndex!,
          autoAdvance: _dialogAutoAdvance,
        );
        return;
      }
    }

    await _playDialogFromIndex(0, autoAdvance: true);
  }

  Future<void> stopDialogPlayback() async {
    if (_isStoppingDialogPlayback) {
      return;
    }

    _isStoppingDialogPlayback = true;
    try {
      _dialogPlaybackIndex = null;
      _dialogAutoAdvance = false;
      _dialogPlaybackStarted = false;
      await _audioService.stop();
      notifyListeners();
    } finally {
      _isStoppingDialogPlayback = false;
    }
  }

  Future<void> playDialogLine(DialogLineItem line) async {
    final index = _dialogLines.indexWhere((item) => item.id == line.id);
    if (index < 0) {
      return;
    }
    if (_dialogPlaybackIndex == index) {
      if (_playbackState == PlaybackState.playing) {
        await pausePlayback();
        return;
      }
      if (_playbackState == PlaybackState.paused) {
        await _playDialogFromIndex(index, autoAdvance: false);
        return;
      }
    }
    await _playDialogFromIndex(index, autoAdvance: false);
  }

  Future<void> removeDialogLine(DialogLineItem line) async {
    if (activeDialogLineId == line.id) {
      await stopDialogPlayback();
    }
    _dialogLines = _dialogLines
        .where((item) => item.id != line.id)
        .toList(growable: false);
    _removeUnusedDialogSpeakerSettings();
    notifyListeners();
  }

  void clearDialogLineText(DialogLineItem line) {
    final current = _dialogLineById(line.id);
    if (current == null) {
      return;
    }
    _replaceDialogLine(
      line.id,
      current.copyWith(
        text: '',
        taskId: null,
        outputPath: null,
        status: DialogLineStatus.idle,
        errorMessage: null,
      ),
    );
    notifyListeners();
  }

  void setDialogSpeakerModel(String speakerName, InstalledModel model) {
    if (model.status != ModelStatus.ready || model.modelDir == null) {
      return;
    }
    final settings =
        _dialogSpeakerSettings[speakerName] ??
        _defaultDialogSpeakerSettings(speakerName);
    final speakerId = _resolveSpeakerId(
      model.voice,
      preferredSpeakerId: model.voice.defaultSpeakerId,
    );
    _dialogSpeakerSettings = {
      ..._dialogSpeakerSettings,
      speakerName: settings.copyWith(
        modelId: model.voice.id,
        speakerId: speakerId,
        generationLanguage: model.voice.resolveGenerationLanguage(
          settings.generationLanguage,
        ),
      ),
    };
    _resetDialogLinesForSpeaker(speakerName);
    notifyListeners();

    unawaited(
      taskManager.submitModelPreload(
        modelDir: model.modelDir!,
        voice: model.voice,
        providerOverride: _selectedInferenceProvider,
      ),
    );
  }

  void setDialogSpeakerVoice(String speakerName, int speakerId) {
    final settings =
        _dialogSpeakerSettings[speakerName] ??
        _defaultDialogSpeakerSettings(speakerName);
    _dialogSpeakerSettings = {
      ..._dialogSpeakerSettings,
      speakerName: settings.copyWith(speakerId: speakerId),
    };
    _resetDialogLinesForSpeaker(speakerName);
    notifyListeners();
  }

  void setDialogSpeakerLanguage(String speakerName, String language) {
    final settings =
        _dialogSpeakerSettings[speakerName] ??
        _defaultDialogSpeakerSettings(speakerName);
    final model = _dialogModelForSpeaker(speakerName);
    final nextLanguage =
        model?.voice.resolveGenerationLanguage(language) ?? language;
    if (settings.generationLanguage == nextLanguage) {
      return;
    }

    _dialogSpeakerSettings = {
      ..._dialogSpeakerSettings,
      speakerName: settings.copyWith(generationLanguage: nextLanguage),
    };
    _resetDialogLinesForSpeaker(speakerName);
    notifyListeners();
  }

  void setDialogSpeakerVolume(String speakerName, int volume) {
    final settings =
        _dialogSpeakerSettings[speakerName] ??
        _defaultDialogSpeakerSettings(speakerName);
    final nextSettings = settings.copyWith(volume: volume);
    if (nextSettings.volume == settings.volume) {
      return;
    }

    _dialogSpeakerSettings = {
      ..._dialogSpeakerSettings,
      speakerName: nextSettings,
    };
    _resetDialogLinesForSpeaker(speakerName);
    notifyListeners();
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

  Future<void> clearAllManagedTasks() async {
    try {
      if (taskManager.activeInstallTask != null) {
        await _modelService.cancelActiveDownload();
      }

      await _audioService.stop();
      await taskManager.clearAllTasks();
      await _generatedAudioStore?.clearAllAudio();

      _persistedGeneratedAudioPaths.clear();
      _generatedWavPath = null;
      _currentTaskId = null;
      _playbackPosition = Duration.zero;
      _playbackDuration = null;
      _synthesisStatus = SynthesisStatus.idle;
      _activeInstallTaskId = null;
      _isDownloading = false;
      _downloadProgress = 0;
      _currentInstallProgress = null;
      _dialogPlaybackIndex = null;
      _dialogAutoAdvance = false;
      _dialogPlaybackStarted = false;
      _dialogLines = _dialogLines
          .map(
            (line) => line.copyWith(
              taskId: null,
              outputPath: null,
              status: DialogLineStatus.idle,
              errorMessage: null,
            ),
          )
          .toList(growable: false);
      _errorMessage = null;
      notifyListeners();
    } catch (error) {
      _errorMessage = 'Failed to clear tasks: $error';
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
    if (_dialogPlaybackIndex != null) {
      _dialogPlaybackIndex = null;
      _dialogAutoAdvance = false;
    }
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
    if (_dialogPlaybackIndex != null) {
      _dialogPlaybackIndex = null;
      _dialogAutoAdvance = false;
    }
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
    _syncDialogLinesWithTasks();
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

  Future<void> _handleDialogPlaybackStateChange(
    PlaybackState previousState,
    PlaybackState nextState,
  ) async {
    if (_isStoppingDialogPlayback || _dialogPlaybackIndex == null) {
      return;
    }
    if (nextState == PlaybackState.playing) {
      _dialogPlaybackStarted = true;
      return;
    }
    if (_isAdvancingDialogPlayback ||
        !_dialogAutoAdvance ||
        nextState != PlaybackState.stopped) {
      return;
    }
    if (!_dialogPlaybackStarted || previousState != PlaybackState.playing) {
      return;
    }

    final nextIndex = _dialogPlaybackIndex! + 1;
    _isAdvancingDialogPlayback = true;
    try {
      final playedNext = await _playDialogFromIndex(
        nextIndex,
        autoAdvance: true,
        reportMissingAudio: false,
      );
      if (!playedNext) {
        _dialogPlaybackIndex = null;
        _dialogAutoAdvance = false;
        _dialogPlaybackStarted = false;
        notifyListeners();
      }
    } finally {
      _isAdvancingDialogPlayback = false;
    }
  }

  Map<String, DialogSpeakerSettings> _buildDialogSpeakerSettings(
    List<DialogLineItem> lines,
  ) {
    final settings = <String, DialogSpeakerSettings>{};
    for (final line in lines) {
      settings.putIfAbsent(
        line.speakerName,
        () =>
            _dialogSpeakerSettings[line.speakerName] ??
            _defaultDialogSpeakerSettings(line.speakerName),
      );
    }
    return settings;
  }

  DialogSpeakerSettings _defaultDialogSpeakerSettings(String speakerName) {
    final model = _selectedModel?.status == ModelStatus.ready
        ? _selectedModel
        : (readyModels.isNotEmpty ? readyModels.first : null);
    return DialogSpeakerSettings(
      speakerName: speakerName,
      modelId: model?.voice.id,
      generationLanguage: model?.voice.resolveGenerationLanguage(null),
      speakerId: model == null
          ? null
          : _resolveSpeakerId(
              model.voice,
              preferredSpeakerId: model.voice.defaultSpeakerId,
            ),
    );
  }

  void _normalizeDialogSpeakerSettings() {
    if (_dialogLines.isEmpty) {
      return;
    }
    _dialogSpeakerSettings = _buildDialogSpeakerSettings(_dialogLines);
  }

  InstalledModel? _dialogModelForSpeaker(String speakerName) {
    final modelId = _dialogSpeakerSettings[speakerName]?.modelId;
    if (modelId == null) {
      return null;
    }
    for (final model in readyModels) {
      if (model.voice.id == modelId) {
        return model;
      }
    }
    return null;
  }

  int _dialogSpeakerIdFor(String speakerName, VoiceModel voice) {
    return _resolveSpeakerId(
      voice,
      preferredSpeakerId: _dialogSpeakerSettings[speakerName]?.speakerId,
    );
  }

  String _dialogGenerationLanguageFor(String speakerName, VoiceModel voice) {
    return voice.resolveGenerationLanguage(
      _dialogSpeakerSettings[speakerName]?.generationLanguage,
    );
  }

  int _dialogVolumeForSpeaker(String speakerName) {
    return clampDialogVolume(
      _dialogSpeakerSettings[speakerName]?.volume ?? dialogVolumeDefault,
    );
  }

  DialogLineItem? _dialogLineById(String id) {
    for (final line in _dialogLines) {
      if (line.id == id) {
        return line;
      }
    }
    return null;
  }

  void _replaceDialogLine(String id, DialogLineItem replacement) {
    _dialogLines = _dialogLines
        .map((line) => line.id == id ? replacement : line)
        .toList(growable: false);
  }

  void _resetDialogLinesForSpeaker(String speakerName) {
    _dialogLines = _dialogLines
        .map(
          (line) => line.speakerName == speakerName
              ? line.copyWith(
                  taskId: null,
                  outputPath: null,
                  status: DialogLineStatus.idle,
                  errorMessage: null,
                )
              : line,
        )
        .toList(growable: false);
  }

  void _removeUnusedDialogSpeakerSettings() {
    final activeSpeakers = _dialogLines.map((line) => line.speakerName).toSet();
    _dialogSpeakerSettings = Map<String, DialogSpeakerSettings>.fromEntries(
      _dialogSpeakerSettings.entries.where(
        (entry) => activeSpeakers.contains(entry.key),
      ),
    );
  }

  bool _syncDialogLinesWithTasks() {
    final tasksById = {for (final task in taskManager.tasks) task.id: task};
    var changed = false;
    final nextLines = <DialogLineItem>[];
    for (final line in _dialogLines) {
      final taskId = line.taskId;
      final task = taskId == null ? null : tasksById[taskId];
      if (task == null) {
        nextLines.add(line);
        continue;
      }

      final nextLine = switch (task.status) {
        LongRunningTaskStatus.queued => line.copyWith(
          status: DialogLineStatus.queued,
        ),
        LongRunningTaskStatus.running || LongRunningTaskStatus.cancelling =>
          line.copyWith(status: DialogLineStatus.generating),
        LongRunningTaskStatus.completed => line.copyWith(
          status: DialogLineStatus.ready,
          outputPath: task.outputPath,
          errorMessage: null,
        ),
        LongRunningTaskStatus.failed => line.copyWith(
          status: DialogLineStatus.failed,
          errorMessage: task.errorMessage ?? 'Generation failed.',
        ),
        LongRunningTaskStatus.cancelled => line.copyWith(
          status: DialogLineStatus.failed,
          errorMessage: 'Generation cancelled.',
        ),
      };
      changed =
          changed ||
          nextLine.status != line.status ||
          nextLine.outputPath != line.outputPath ||
          nextLine.errorMessage != line.errorMessage;
      nextLines.add(nextLine);
    }

    if (changed) {
      _dialogLines = nextLines;
    }
    return changed;
  }

  Future<bool> _playDialogFromIndex(
    int startIndex, {
    required bool autoAdvance,
    bool reportMissingAudio = true,
  }) async {
    for (var index = startIndex; index < _dialogLines.length; index++) {
      final line = _dialogLines[index];
      final outputPath = line.outputPath;
      if (!line.hasText || outputPath == null || outputPath.trim().isEmpty) {
        continue;
      }

      _dialogPlaybackIndex = index;
      _dialogAutoAdvance = autoAdvance;
      _dialogPlaybackStarted = false;
      _currentTaskId = null;
      _generatedWavPath = outputPath;
      notifyListeners();

      try {
        await _audioService.play(outputPath);
        _dialogErrorMessage = null;
        notifyListeners();
        return true;
      } catch (error) {
        _dialogErrorMessage = 'Dialog playback failed: $error';
        _dialogPlaybackIndex = null;
        _dialogAutoAdvance = false;
        _dialogPlaybackStarted = false;
        notifyListeners();
        return false;
      }
    }

    if (reportMissingAudio) {
      _dialogErrorMessage = 'Generate dialog audio before playback.';
      notifyListeners();
    }
    return false;
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

  Future<File> _modelSettingsFile() async {
    final settingsFile = await _settingsFile();
    return File(p.join(settingsFile.parent.path, _modelSettingsFileName));
  }

  ModelSynthesisSettings _settingsFor(VoiceModel voice) {
    final cached = _modelSettingsById[voice.id];
    if (cached != null) return cached;
    final raw = _persistedModelSettingsJson[voice.id];
    final settings = raw is Map
        ? ModelSynthesisSettings.fromJson(Map<String, Object?>.from(raw), voice)
        : ModelSynthesisSettings.defaultsFor(voice);
    _modelSettingsById[voice.id] = settings;
    return settings;
  }

  void _applySettingsFields(ModelSynthesisSettings settings) {
    _speed = settings.speed;
    _selectedSpeakerId = settings.speakerId;
    _selectedGenerationLanguage = settings.generationLanguage;
  }

  Future<Map<String, Object?>> _loadModelSettingsJson() async {
    try {
      final file = await _modelSettingsFile();
      if (!await file.exists()) return {};
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map ? Map<String, Object?>.from(decoded) : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveModelSettings() async {
    try {
      final file = await _modelSettingsFile();
      await file.parent.create(recursive: true);
      final values = <String, Object?>{
        ..._persistedModelSettingsJson,
        for (final entry in _modelSettingsById.entries)
          entry.key: entry.value.toJson(),
      };
      await file.writeAsString(jsonEncode(values), flush: true);
      _persistedModelSettingsJson = values;
    } catch (_) {}
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
