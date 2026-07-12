import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:tts_core/tts_core.dart';

import '../models/cloned_voice.dart';
import '../services/audio_service.dart';
import '../services/open_voice_backend_service.dart';
import '../services/open_voice_preferences_service.dart';
import '../services/voice_library_service.dart';
import 'app_state.dart';

const List<ExternalBackendVoice> _fallbackOmniVoiceVoices = [
  ExternalBackendVoice(
    id: 'clone-reference',
    displayName: 'Clone From Reference Audio',
    description:
        'Use a short reference clip to clone that speaker in the target language.',
    mode: ExternalBackendVoiceMode.clone,
    requiresReferenceAudio: true,
    supportsInstructionEditing: false,
    presetInstruction: null,
  ),
];

class VoiceLabState extends ChangeNotifier {
  VoiceLabState({
    required AppState appState,
    VoiceLibraryService? libraryService,
    OpenVoiceBackendService? openVoiceBackendService,
    OpenVoicePreferencesService? openVoicePreferencesService,
  }) : _appState = appState,
       _libraryService = libraryService ?? VoiceLibraryService(),
       _openVoiceBackendService =
           openVoiceBackendService ?? OpenVoiceBackendService(),
       _openVoicePreferencesService =
           openVoicePreferencesService ?? OpenVoicePreferencesService();

  final AppState _appState;
  final VoiceLibraryService _libraryService;
  final OpenVoiceBackendService _openVoiceBackendService;
  final OpenVoicePreferencesService _openVoicePreferencesService;

  List<ClonedVoice> _voices = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _openVoiceBackendUrl = OpenVoiceBackendService.defaultBaseUrl;
  String _omniVoiceBackendUrl = 'http://127.0.0.1:8010';
  OpenVoiceBackendConnectionState _openVoiceConnectionState =
      OpenVoiceBackendConnectionState.disconnected;
  OpenVoiceBackendConnectionState _omniVoiceConnectionState =
      OpenVoiceBackendConnectionState.disconnected;
  String? _openVoiceBackendMessage;
  String? _omniVoiceBackendMessage;
  String? _openVoiceSamplePath;
  String? _omniVoiceSamplePath;
  List<ExternalBackendVoice> _omniVoiceVoices = _fallbackOmniVoiceVoices;
  List<String> _omniVoiceFeatures = const <String>[];
  String? _omniVoiceEngineDisplayName;
  String _selectedOmniVoiceId = _fallbackOmniVoiceVoices.first.id;
  String _omniVoiceLanguage = 'en';
  String _omniVoiceReferenceText = '';
  String _omniVoiceInstruction = '';
  String _omniVoiceDurationSeconds = '';
  String _omniVoiceNumStep = '';
  bool _isOpenVoiceEnabled = false;
  bool _isOmniVoiceEnabled = false;
  bool _isOpenVoiceGenerationSubmitting = false;
  bool _isOmniVoiceGenerationSubmitting = false;
  String? _activeOpenVoiceJobId;
  String? _activeOmniVoiceJobId;
  Timer? _openVoiceHealthTimer;
  Timer? _omniVoiceHealthTimer;

  // Preview playback
  String? _previewingVoiceId;
  bool _isPreviewPlaying = false;
  StreamSubscription<PlaybackState>? _previewSub;
  final AudioService _previewAudio = AudioService();

  List<ClonedVoice> get voices => _voices;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get previewingVoiceId => _previewingVoiceId;
  bool get isPreviewPlaying => _isPreviewPlaying;
  bool get isPocketVoiceCloningEnabled => _appState.isVoiceCloningEnabled;
  bool get isOpenVoiceEnabled => _isOpenVoiceEnabled;
  bool get isOmniVoiceEnabled => _isOmniVoiceEnabled;
  bool get hasSharedInputText => _appState.inputText.trim().isNotEmpty;
  String get openVoiceBackendUrl => _openVoiceBackendUrl;
  String get omniVoiceBackendUrl => _omniVoiceBackendUrl;
  OpenVoiceBackendConnectionState get openVoiceConnectionState =>
      _openVoiceConnectionState;
  OpenVoiceBackendConnectionState get omniVoiceConnectionState =>
      _omniVoiceConnectionState;
  String? get openVoiceBackendMessage => _openVoiceBackendMessage;
  String? get omniVoiceBackendMessage => _omniVoiceBackendMessage;
  String? get openVoiceSamplePath => _openVoiceSamplePath;
  String? get omniVoiceSamplePath => _omniVoiceSamplePath;
  List<ExternalBackendVoice> get omniVoiceVoices => _omniVoiceVoices;
  List<String> get omniVoiceFeatures => _omniVoiceFeatures;
  String? get omniVoiceEngineDisplayName => _omniVoiceEngineDisplayName;
  String get selectedOmniVoiceId => _selectedOmniVoiceId;
  String get omniVoiceLanguage => _omniVoiceLanguage;
  String get omniVoiceReferenceText => _omniVoiceReferenceText;
  String get omniVoiceInstruction => _omniVoiceInstruction;
  String get omniVoiceDurationSeconds => _omniVoiceDurationSeconds;
  String get omniVoiceNumStep => _omniVoiceNumStep;
  ExternalBackendVoice get selectedOmniVoice {
    return _omniVoiceVoices
            .where((voice) => voice.id == _selectedOmniVoiceId)
            .firstOrNull ??
        _omniVoiceVoices.first;
  }

  bool get omniVoiceRequiresReferenceAudio =>
      selectedOmniVoice.requiresReferenceAudio;
  bool get omniVoiceSupportsReferenceText =>
      omniVoiceRequiresReferenceAudio &&
      _omniVoiceFeatures.contains('reference_transcript');
  bool get omniVoiceSupportsInstruction =>
      selectedOmniVoice.supportsInstruction;
  bool get omniVoiceSupportsDuration =>
      _omniVoiceFeatures.contains('duration_control');
  bool get omniVoiceSupportsNumStep =>
      _omniVoiceFeatures.contains('num_step_control');
  bool get omniVoiceSupportsNonVerbalTokens =>
      _omniVoiceFeatures.contains('non_verbal_tokens');
  bool get omniVoiceSupportsPronunciationControl =>
      _omniVoiceFeatures.contains('pronunciation_control');
  String get omniVoiceEffectiveInstruction {
    final customInstruction = _omniVoiceInstruction.trim();
    if (customInstruction.isNotEmpty) {
      return customInstruction;
    }
    return selectedOmniVoice.presetInstruction?.trim() ?? '';
  }

  bool get hasOpenVoiceSample =>
      _openVoiceSamplePath != null && _openVoiceSamplePath!.trim().isNotEmpty;
  bool get hasOmniVoiceSample =>
      _omniVoiceSamplePath != null && _omniVoiceSamplePath!.trim().isNotEmpty;
  bool get isOpenVoiceGenerationSubmitting => _isOpenVoiceGenerationSubmitting;
  bool get isOmniVoiceGenerationSubmitting => _isOmniVoiceGenerationSubmitting;
  String? get activeOpenVoiceJobId => _activeOpenVoiceJobId;
  String? get activeOmniVoiceJobId => _activeOmniVoiceJobId;
  bool get canGenerateWithOpenVoice =>
      _isOpenVoiceEnabled &&
      hasSharedInputText &&
      hasOpenVoiceSample &&
      !_isOpenVoiceGenerationSubmitting &&
      _openVoiceConnectionState == OpenVoiceBackendConnectionState.connected;
  bool get canGenerateWithOmniVoice =>
      _isOmniVoiceEnabled &&
      hasSharedInputText &&
      !_isOmniVoiceGenerationSubmitting &&
      _omniVoiceConnectionState == OpenVoiceBackendConnectionState.connected &&
      (!omniVoiceRequiresReferenceAudio || hasOmniVoiceSample) &&
      (selectedOmniVoice.mode != ExternalBackendVoiceMode.design ||
          omniVoiceEffectiveInstruction.isNotEmpty);

  void setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// The Pocket TTS model from the catalog, if installed and ready.
  InstalledModel? get pocketModel {
    return _appState.installedModels
        .where(
          (m) => m.voice.family == 'pocket' && m.status == ModelStatus.ready,
        )
        .firstOrNull;
  }

  bool get hasPocketModel => pocketModel != null;

  Future<void> initialize() async {
    _appState.addListener(_handleAppStateChanged);
    _openVoiceBackendUrl = await _openVoicePreferencesService.loadBackendUrl();
    _omniVoiceBackendUrl = await _openVoicePreferencesService
        .loadOmniVoiceBackendUrl(_omniVoiceBackendUrl);
    _isOpenVoiceEnabled = await _openVoicePreferencesService
        .loadOpenVoiceEnabled();
    _isOmniVoiceEnabled = await _openVoicePreferencesService
        .loadOmniVoiceEnabled();
    _previewSub = _previewAudio.onStateChanged.listen((state) {
      _isPreviewPlaying = state == PlaybackState.playing;
      if (state == PlaybackState.stopped) {
        _previewingVoiceId = null;
      }
      notifyListeners();
    });

    await loadVoices();
    if (_isOpenVoiceEnabled) {
      unawaited(checkOpenVoiceConnection());
      _startOpenVoiceHealthPolling();
    }
    if (_isOmniVoiceEnabled) {
      unawaited(checkOmniVoiceConnection());
      _startOmniVoiceHealthPolling();
    }
  }

  Future<void> setVoiceCloningEnabled(bool enabled) {
    return _appState.setVoiceCloningEnabled(enabled);
  }

  Future<void> setOpenVoiceEnabled(bool enabled) async {
    if (!enabled) {
      if (_isOpenVoiceEnabled) {
        _isOpenVoiceEnabled = false;
        _stopOpenVoiceHealthPolling();
        await _openVoicePreferencesService.saveOpenVoiceEnabled(false);
        notifyListeners();
      }
      return;
    }

    if (_isOpenVoiceEnabled) {
      return;
    }

    _isOpenVoiceEnabled = true;
    await _openVoicePreferencesService.saveOpenVoiceEnabled(true);
    _openVoiceBackendMessage = 'Checking backend connection...';
    _openVoiceConnectionState = OpenVoiceBackendConnectionState.checking;
    notifyListeners();
    unawaited(checkOpenVoiceConnection());
    _startOpenVoiceHealthPolling();
  }

  Future<void> setOmniVoiceEnabled(bool enabled) async {
    if (!enabled) {
      if (_isOmniVoiceEnabled) {
        _isOmniVoiceEnabled = false;
        _stopOmniVoiceHealthPolling();
        await _openVoicePreferencesService.saveOmniVoiceEnabled(false);
        notifyListeners();
      }
      return;
    }

    if (_isOmniVoiceEnabled) {
      return;
    }

    _isOmniVoiceEnabled = true;
    await _openVoicePreferencesService.saveOmniVoiceEnabled(true);
    _omniVoiceBackendMessage = 'Checking backend connection...';
    _omniVoiceConnectionState = OpenVoiceBackendConnectionState.checking;
    notifyListeners();
    unawaited(checkOmniVoiceConnection());
    _startOmniVoiceHealthPolling();
  }

  Future<void> setOpenVoiceBackendUrl(String backendUrl) async {
    _openVoiceBackendUrl = backendUrl;
    _openVoiceConnectionState = OpenVoiceBackendConnectionState.disconnected;
    _openVoiceBackendMessage = null;
    notifyListeners();
    await _openVoicePreferencesService.saveBackendUrl(backendUrl);
    if (_isOpenVoiceEnabled) {
      unawaited(checkOpenVoiceConnection());
    }
  }

  Future<void> setOmniVoiceBackendUrl(String backendUrl) async {
    _omniVoiceBackendUrl = backendUrl;
    _omniVoiceConnectionState = OpenVoiceBackendConnectionState.disconnected;
    _omniVoiceBackendMessage = null;
    notifyListeners();
    await _openVoicePreferencesService.saveOmniVoiceBackendUrl(backendUrl);
    if (_isOmniVoiceEnabled) {
      unawaited(checkOmniVoiceConnection());
    }
  }

  void setOpenVoiceSamplePath(String? samplePath) {
    _openVoiceSamplePath = samplePath;
    notifyListeners();
  }

  void setOmniVoiceSamplePath(String? samplePath) {
    _omniVoiceSamplePath = samplePath;
    notifyListeners();
  }

  void setSelectedOmniVoiceId(String? voiceId) {
    if (voiceId == null || voiceId.trim().isEmpty) {
      return;
    }
    final selectedVoice = _omniVoiceVoices
        .where((voice) => voice.id == voiceId)
        .firstOrNull;
    if (selectedVoice == null) {
      return;
    }

    final changed = _selectedOmniVoiceId != selectedVoice.id;
    _selectedOmniVoiceId = selectedVoice.id;
    if (selectedVoice.mode == ExternalBackendVoiceMode.design &&
        (changed || _omniVoiceInstruction.trim().isEmpty)) {
      _omniVoiceInstruction = selectedVoice.presetInstruction ?? '';
    }
    notifyListeners();
  }

  void setOmniVoiceLanguage(String language) {
    _omniVoiceLanguage = language;
    notifyListeners();
  }

  void setOmniVoiceReferenceText(String referenceText) {
    _omniVoiceReferenceText = referenceText;
    notifyListeners();
  }

  void setOmniVoiceInstruction(String instruction) {
    _omniVoiceInstruction = instruction;
    notifyListeners();
  }

  void setOmniVoiceDurationSeconds(String durationSeconds) {
    _omniVoiceDurationSeconds = durationSeconds;
    notifyListeners();
  }

  void setOmniVoiceNumStep(String numStep) {
    _omniVoiceNumStep = numStep;
    notifyListeners();
  }

  Future<void> checkOpenVoiceConnection({bool showAsError = false}) async {
    _openVoiceConnectionState = OpenVoiceBackendConnectionState.checking;
    _openVoiceBackendMessage = 'Checking backend connection...';
    notifyListeners();

    try {
      final baseUri = _openVoiceBackendService.parseBaseUri(
        _openVoiceBackendUrl,
      );
      final health = await _openVoiceBackendService.fetchHealth(baseUri);
      if (health.engineReady) {
        _openVoiceConnectionState = OpenVoiceBackendConnectionState.connected;
        _openVoiceBackendMessage =
            'Backend is healthy at ${_openVoiceBackendUrl.trim()}.';
        if (showAsError) {
          _errorMessage = null;
        }
      } else {
        _openVoiceConnectionState = OpenVoiceBackendConnectionState.error;
        _openVoiceBackendMessage =
            'Backend is not healthy at ${_openVoiceBackendUrl.trim()}.';
        if (showAsError) {
          _errorMessage =
              'Connected to ${health.backend} ${health.version}, but speech generation is not ready yet.';
        }
      }
    } on OpenVoiceBackendException catch (error) {
      _openVoiceConnectionState = OpenVoiceBackendConnectionState.error;
      _openVoiceBackendMessage =
          'Backend is down at ${_openVoiceBackendUrl.trim()}.';
      if (showAsError) {
        _errorMessage = error.message;
      }
    } catch (error) {
      _openVoiceConnectionState = OpenVoiceBackendConnectionState.error;
      _openVoiceBackendMessage =
          'Backend is down at ${_openVoiceBackendUrl.trim()}.';
      if (showAsError) {
        _errorMessage = error.toString();
      }
    }

    notifyListeners();
  }

  Future<void> checkOmniVoiceConnection({bool showAsError = false}) async {
    _omniVoiceConnectionState = OpenVoiceBackendConnectionState.checking;
    _omniVoiceBackendMessage = 'Checking backend connection...';
    notifyListeners();

    try {
      final baseUri = _openVoiceBackendService.parseBaseUri(
        _omniVoiceBackendUrl,
      );
      final health = await _openVoiceBackendService.fetchHealth(baseUri);
      if (health.engineReady) {
        _omniVoiceFeatures = health.features;
        _omniVoiceEngineDisplayName =
            health.engineDisplayName?.trim().isNotEmpty == true
            ? health.engineDisplayName
            : health.backend;
        var usingFallbackVoices = false;
        try {
          final fetchedVoices = await _openVoiceBackendService.fetchVoices(
            baseUri,
          );
          if (fetchedVoices.isNotEmpty) {
            _replaceOmniVoiceVoices(fetchedVoices);
          } else {
            usingFallbackVoices = true;
            _replaceOmniVoiceVoices(_fallbackOmniVoiceVoices);
          }
        } on OpenVoiceBackendException {
          usingFallbackVoices = true;
          _replaceOmniVoiceVoices(_fallbackOmniVoiceVoices);
        }
        _omniVoiceConnectionState = OpenVoiceBackendConnectionState.connected;
        _omniVoiceBackendMessage = usingFallbackVoices
            ? '${_omniVoiceEngineDisplayName ?? 'Backend'} is healthy at ${_omniVoiceBackendUrl.trim()}, but only clone mode metadata is available.'
            : '${_omniVoiceEngineDisplayName ?? 'Backend'} is healthy at ${_omniVoiceBackendUrl.trim()} with ${_omniVoiceVoices.length} voice options.';
        if (showAsError) {
          _errorMessage = null;
        }
      } else {
        _omniVoiceConnectionState = OpenVoiceBackendConnectionState.error;
        _omniVoiceBackendMessage =
            'Backend is not healthy at ${_omniVoiceBackendUrl.trim()}.';
        if (showAsError) {
          _errorMessage =
              'Connected to ${health.backend} ${health.version}, but speech generation is not ready yet.';
        }
      }
    } on OpenVoiceBackendException catch (error) {
      _omniVoiceConnectionState = OpenVoiceBackendConnectionState.error;
      _omniVoiceFeatures = const <String>[];
      _omniVoiceBackendMessage =
          'Backend is down at ${_omniVoiceBackendUrl.trim()}.';
      if (showAsError) {
        _errorMessage = error.message;
      }
    } catch (error) {
      _omniVoiceConnectionState = OpenVoiceBackendConnectionState.error;
      _omniVoiceFeatures = const <String>[];
      _omniVoiceBackendMessage =
          'Backend is down at ${_omniVoiceBackendUrl.trim()}.';
      if (showAsError) {
        _errorMessage = error.toString();
      }
    }

    notifyListeners();
  }

  Future<void> loadVoices() async {
    _isLoading = true;
    notifyListeners();

    try {
      _voices = await _libraryService.loadVoices();
    } catch (e) {
      _errorMessage = 'Failed to load voice library: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Adds a new cloned voice from a selected audio file path.
  Future<void> addVoice({
    required String name,
    required String audioPath,
  }) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final voice = await _libraryService.addVoice(
        name: name,
        sourceAudioPath: audioPath,
      );
      _voices = List.from(_voices)..add(voice);
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to add voice: $e';
      notifyListeners();
    }
  }

  /// Removes a cloned voice.
  Future<void> removeVoice(String voiceId) async {
    try {
      await _libraryService.removeVoice(voiceId);
      _voices = _voices.where((v) => v.id != voiceId).toList();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to remove voice: $e';
      notifyListeners();
    }
  }

  /// Previews a cloned voice's reference audio.
  Future<void> previewVoice(ClonedVoice voice) async {
    await _previewAudio.stop();
    _previewingVoiceId = voice.id;
    notifyListeners();

    try {
      await _previewAudio.play(voice.referenceAudioPath);
    } catch (e) {
      _errorMessage = 'Preview failed: $e';
      _previewingVoiceId = null;
      notifyListeners();
    }
  }

  Future<void> stopPreview() async {
    await _previewAudio.stop();
  }

  Future<void> generateWithOpenVoice() async {
    final sharedText = _appState.inputText.trim();
    if (sharedText.isEmpty) {
      _errorMessage =
          'Enter text on the Home screen before generating OpenVoice speech';
      notifyListeners();
      return;
    }

    final samplePath = _openVoiceSamplePath;
    if (samplePath == null || samplePath.trim().isEmpty) {
      _errorMessage =
          'Select a reference WAV or MP3 file for OpenVoice speech generation.';
      notifyListeners();
      return;
    }

    if (_openVoiceConnectionState !=
        OpenVoiceBackendConnectionState.connected) {
      await checkOpenVoiceConnection(showAsError: true);
      if (_openVoiceConnectionState !=
          OpenVoiceBackendConnectionState.connected) {
        return;
      }
    }

    _isOpenVoiceGenerationSubmitting = true;
    _errorMessage = null;
    _openVoiceBackendMessage = 'Submitting OpenVoice speech job...';
    notifyListeners();

    try {
      final baseUri = _openVoiceBackendService.parseBaseUri(
        _openVoiceBackendUrl,
      );
      final normalizedSamplePath = await _normalizeOpenVoiceSample(samplePath);
      final startedAt = DateTime.now();
      final submission = await _openVoiceBackendService.submitJob(
        baseUri: baseUri,
        text: sharedText,
        referenceAudioPath: normalizedSamplePath,
        speed: _appState.speed,
      );
      _activeOpenVoiceJobId = submission.jobId;
      _openVoiceBackendMessage =
          'OpenVoice speech job ${submission.jobId} submitted.';
      notifyListeners();

      final completedJob = await _openVoiceBackendService.waitForJobCompletion(
        baseUri: baseUri,
        jobId: submission.jobId,
      );

      if (completedJob.status == OpenVoiceJobStatus.failed) {
        _errorMessage = completedJob.error ?? 'OpenVoice speech job failed.';
        _openVoiceBackendMessage =
            'OpenVoice speech job ${submission.jobId} failed.';
        return;
      }
      final outputPath = await _appState.createGeneratedAudioOutputPath(
        prefix: 'openvoice-speech',
      );
      final outputFile = await _openVoiceBackendService.downloadJobResult(
        baseUri: baseUri,
        jobId: submission.jobId,
        outputPath: outputPath,
      );

      _appState.registerExternalGeneratedAudio(
        label: 'openvoice-${submission.jobId}',
        modelId: 'openvoice',
        modelName: 'OpenVoice',
        inputCharacterCount: sharedText.length,
        speechSpeed: _appState.speed,
        outputPath: outputFile.path,
        startedAt: startedAt,
      );
      _openVoiceBackendMessage =
          'OpenVoice speech job ${submission.jobId} is ready on the Home screen.';
    } on OpenVoiceBackendException catch (error) {
      _errorMessage = error.message;
      _openVoiceBackendMessage = 'OpenVoice speech generation failed.';
    } catch (error) {
      _errorMessage = 'OpenVoice speech generation failed: $error';
      _openVoiceBackendMessage = 'OpenVoice speech generation failed.';
    } finally {
      _isOpenVoiceGenerationSubmitting = false;
      notifyListeners();
    }
  }

  Future<String> _normalizeOpenVoiceSample(String sourceAudioPath) async {
    return _normalizeBackendSample(
      sourceAudioPath,
      tempDirName: 'openvoice-reference',
      filePrefix: 'openvoice-reference',
    );
  }

  Future<String> _normalizeOmniVoiceSample(String sourceAudioPath) async {
    return _normalizeBackendSample(
      sourceAudioPath,
      tempDirName: 'omnivoice-reference',
      filePrefix: 'omnivoice-reference',
    );
  }

  Future<String> _normalizeBackendSample(
    String sourceAudioPath, {
    required String tempDirName,
    required String filePrefix,
  }) async {
    final outputDir = Directory(p.join(Directory.systemTemp.path, tempDirName));
    await outputDir.create(recursive: true);

    final normalizedPath = p.join(
      outputDir.path,
      '$filePrefix-${DateTime.now().microsecondsSinceEpoch}.wav',
    );
    await _libraryService.normalizeAudioToWav(
      sourceAudioPath: sourceAudioPath,
      destinationWavPath: normalizedPath,
    );
    return normalizedPath;
  }

  Future<void> generateWithOmniVoice() async {
    final selectedVoice = selectedOmniVoice;
    final sharedText = _appState.inputText.trim();
    if (sharedText.isEmpty) {
      _errorMessage =
          'Enter text on the Home screen before generating OmniVoice speech';
      notifyListeners();
      return;
    }

    final samplePath = _omniVoiceSamplePath;
    if (selectedVoice.requiresReferenceAudio &&
        (samplePath == null || samplePath.trim().isEmpty)) {
      _errorMessage =
          'Select a reference WAV or MP3 file for OmniVoice speech generation.';
      notifyListeners();
      return;
    }

    final language = _omniVoiceLanguage.trim().isEmpty
        ? 'en'
        : _omniVoiceLanguage.trim();
    final referenceText = _omniVoiceReferenceText.trim();
    final effectiveInstruction = omniVoiceEffectiveInstruction;
    if (selectedVoice.mode == ExternalBackendVoiceMode.design &&
        effectiveInstruction.isEmpty) {
      _errorMessage =
          'Enter a voice design prompt or pick an OmniVoice preset voice.';
      notifyListeners();
      return;
    }

    final durationText = _omniVoiceDurationSeconds.trim();
    final duration = durationText.isEmpty
        ? null
        : double.tryParse(durationText);
    if (durationText.isNotEmpty && duration == null) {
      _errorMessage = 'Enter a valid OmniVoice duration in seconds.';
      notifyListeners();
      return;
    }

    final numStepText = _omniVoiceNumStep.trim();
    final numStep = numStepText.isEmpty ? null : int.tryParse(numStepText);
    if (numStepText.isNotEmpty && numStep == null) {
      _errorMessage = 'Enter a valid OmniVoice step count.';
      notifyListeners();
      return;
    }

    if (_omniVoiceConnectionState !=
        OpenVoiceBackendConnectionState.connected) {
      await checkOmniVoiceConnection(showAsError: true);
      if (_omniVoiceConnectionState !=
          OpenVoiceBackendConnectionState.connected) {
        return;
      }
    }

    _isOmniVoiceGenerationSubmitting = true;
    _errorMessage = null;
    _omniVoiceBackendMessage = 'Submitting OmniVoice speech job...';
    notifyListeners();

    try {
      final baseUri = _openVoiceBackendService.parseBaseUri(
        _omniVoiceBackendUrl,
      );
      final normalizedSamplePath = selectedVoice.requiresReferenceAudio
          ? await _normalizeOmniVoiceSample(samplePath!)
          : null;
      final startedAt = DateTime.now();
      final submission = await _openVoiceBackendService.submitJob(
        baseUri: baseUri,
        text: sharedText,
        voiceId: selectedVoice.id,
        referenceAudioPath: normalizedSamplePath,
        referenceText: referenceText.isEmpty ? null : referenceText,
        instruct: selectedVoice.mode == ExternalBackendVoiceMode.design
            ? effectiveInstruction
            : null,
        language: language,
        speed: _appState.speed,
        duration: duration,
        numStep: numStep,
      );
      _activeOmniVoiceJobId = submission.jobId;
      _omniVoiceBackendMessage =
          'OmniVoice speech job ${submission.jobId} submitted.';
      notifyListeners();

      final completedJob = await _openVoiceBackendService.waitForJobCompletion(
        baseUri: baseUri,
        jobId: submission.jobId,
      );

      if (completedJob.status == OpenVoiceJobStatus.failed) {
        _errorMessage = completedJob.error ?? 'OmniVoice speech job failed.';
        _omniVoiceBackendMessage =
            'OmniVoice speech job ${submission.jobId} failed.';
        return;
      }
      final outputPath = await _appState.createGeneratedAudioOutputPath(
        prefix: 'omnivoice-speech',
      );
      final outputFile = await _openVoiceBackendService.downloadJobResult(
        baseUri: baseUri,
        jobId: submission.jobId,
        outputPath: outputPath,
      );

      _appState.registerExternalGeneratedAudio(
        label: 'omnivoice-${selectedVoice.id}-${submission.jobId}',
        modelId: 'omnivoice',
        modelName: 'OmniVoice ${selectedVoice.displayName}',
        inputCharacterCount: sharedText.length,
        speechSpeed: _appState.speed,
        outputPath: outputFile.path,
        startedAt: startedAt,
      );
      _omniVoiceBackendMessage =
          'OmniVoice speech job ${submission.jobId} is ready on the Home screen.';
    } on OpenVoiceBackendException catch (error) {
      _errorMessage = error.message;
      _omniVoiceBackendMessage = 'OmniVoice speech generation failed.';
    } catch (error) {
      _errorMessage = 'OmniVoice speech generation failed: $error';
      _omniVoiceBackendMessage = 'OmniVoice speech generation failed.';
    } finally {
      _isOmniVoiceGenerationSubmitting = false;
      notifyListeners();
    }
  }

  /// Generates speech using a cloned voice via the Pocket TTS model.
  Future<void> generateWithClonedVoice({required ClonedVoice voice}) async {
    final model = pocketModel;
    if (model == null || model.modelDir == null) {
      _errorMessage = 'Pocket TTS model is not installed';
      notifyListeners();
      return;
    }

    final sharedText = _appState.inputText.trim();
    if (sharedText.isEmpty) {
      _errorMessage = 'Enter text on the Home screen before cloning speech';
      notifyListeners();
      return;
    }

    _errorMessage = null;
    notifyListeners();

    try {
      // Read the reference audio.
      final wave = TtsService.readWavFile(voice.referenceAudioPath);
      if (wave.samples.isEmpty) {
        _errorMessage = 'Failed to read reference audio';
        notifyListeners();
        return;
      }

      final outputDir = Directory(
        p.join(Directory.systemTemp.path, 'tts_generated'),
      );
      await outputDir.create(recursive: true);
      final outputPath = p.join(
        outputDir.path,
        'cloned-${DateTime.now().microsecondsSinceEpoch}.wav',
      );

      await _appState.taskManager.submitClonedSynthesis(
        modelDir: model.modelDir!,
        voice: model.voice,
        text: sharedText,
        speed: _appState.speed,
        outputPath: outputPath,
        referenceAudio: wave.samples,
        referenceSampleRate: wave.sampleRate,
        providerOverride: _appState.selectedProvider,
      );
    } catch (e) {
      _errorMessage = 'Failed to start cloned synthesis: $e';
      notifyListeners();
    }
  }

  void _handleAppStateChanged() {
    notifyListeners();
  }

  void _startOpenVoiceHealthPolling() {
    _stopOpenVoiceHealthPolling();
    _openVoiceHealthTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_isOpenVoiceEnabled &&
          _openVoiceConnectionState !=
              OpenVoiceBackendConnectionState.checking) {
        unawaited(checkOpenVoiceConnection());
      }
    });
  }

  void _startOmniVoiceHealthPolling() {
    _stopOmniVoiceHealthPolling();
    _omniVoiceHealthTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_isOmniVoiceEnabled &&
          _omniVoiceConnectionState !=
              OpenVoiceBackendConnectionState.checking) {
        unawaited(checkOmniVoiceConnection());
      }
    });
  }

  void _stopOpenVoiceHealthPolling() {
    _openVoiceHealthTimer?.cancel();
    _openVoiceHealthTimer = null;
  }

  void _stopOmniVoiceHealthPolling() {
    _omniVoiceHealthTimer?.cancel();
    _omniVoiceHealthTimer = null;
  }

  void _replaceOmniVoiceVoices(List<ExternalBackendVoice> voices) {
    final nextVoices = voices.isEmpty ? _fallbackOmniVoiceVoices : voices;
    final previousSelectionId = _selectedOmniVoiceId;
    _omniVoiceVoices = nextVoices;
    final selectedVoice =
        _omniVoiceVoices
            .where((voice) => voice.id == previousSelectionId)
            .firstOrNull ??
        _omniVoiceVoices.first;
    final selectionChanged = selectedVoice.id != previousSelectionId;
    _selectedOmniVoiceId = selectedVoice.id;
    if (selectedVoice.mode == ExternalBackendVoiceMode.design &&
        (selectionChanged || _omniVoiceInstruction.trim().isEmpty)) {
      _omniVoiceInstruction = selectedVoice.presetInstruction ?? '';
    }
  }

  @override
  void dispose() {
    _appState.removeListener(_handleAppStateChanged);
    unawaited(_previewSub?.cancel());
    _stopOpenVoiceHealthPolling();
    _stopOmniVoiceHealthPolling();
    _openVoiceBackendService.dispose();
    _previewAudio.dispose();
    super.dispose();
  }
}
