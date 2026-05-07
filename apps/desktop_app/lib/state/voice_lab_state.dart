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
  OpenVoiceBackendConnectionState _openVoiceConnectionState =
      OpenVoiceBackendConnectionState.disconnected;
  String? _openVoiceBackendMessage;
  String? _openVoiceSamplePath;
  bool _isOpenVoiceEnabled = false;
  bool _isOpenVoiceGenerationSubmitting = false;
  String? _activeOpenVoiceJobId;
  Timer? _openVoiceHealthTimer;

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
  bool get hasSharedInputText => _appState.inputText.trim().isNotEmpty;
  String get openVoiceBackendUrl => _openVoiceBackendUrl;
  OpenVoiceBackendConnectionState get openVoiceConnectionState =>
      _openVoiceConnectionState;
  String? get openVoiceBackendMessage => _openVoiceBackendMessage;
  String? get openVoiceSamplePath => _openVoiceSamplePath;
  bool get hasOpenVoiceSample =>
      _openVoiceSamplePath != null && _openVoiceSamplePath!.trim().isNotEmpty;
  bool get isOpenVoiceGenerationSubmitting => _isOpenVoiceGenerationSubmitting;
  String? get activeOpenVoiceJobId => _activeOpenVoiceJobId;
  bool get canGenerateWithOpenVoice =>
      _isOpenVoiceEnabled &&
      hasSharedInputText &&
      hasOpenVoiceSample &&
      !_isOpenVoiceGenerationSubmitting &&
      _openVoiceConnectionState == OpenVoiceBackendConnectionState.connected;

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
    _previewSub = _previewAudio.onStateChanged.listen((state) {
      _isPreviewPlaying = state == PlaybackState.playing;
      if (state == PlaybackState.stopped) {
        _previewingVoiceId = null;
      }
      notifyListeners();
    });

    await loadVoices();
  }

  Future<void> setVoiceCloningEnabled(bool enabled) {
    return _appState.setVoiceCloningEnabled(enabled);
  }

  Future<void> setOpenVoiceEnabled(bool enabled) async {
    if (!enabled) {
      if (_isOpenVoiceEnabled) {
        _isOpenVoiceEnabled = false;
        _stopOpenVoiceHealthPolling();
        notifyListeners();
      }
      return;
    }

    if (_isOpenVoiceEnabled) {
      return;
    }

    _isOpenVoiceEnabled = true;
    _openVoiceBackendMessage = 'Checking backend connection...';
    _openVoiceConnectionState = OpenVoiceBackendConnectionState.checking;
    notifyListeners();
    unawaited(checkOpenVoiceConnection());
    _startOpenVoiceHealthPolling();
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

  void setOpenVoiceSamplePath(String? samplePath) {
    _openVoiceSamplePath = samplePath;
    notifyListeners();
  }

  Future<void> checkOpenVoiceConnection({bool showAsError = false}) async {
    _openVoiceConnectionState = OpenVoiceBackendConnectionState.checking;
    _openVoiceBackendMessage = 'Checking backend connection...';
    notifyListeners();

    try {
      final baseUri = _openVoiceBackendService.parseBaseUri(_openVoiceBackendUrl);
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

    if (_openVoiceConnectionState != OpenVoiceBackendConnectionState.connected) {
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
      final baseUri = _openVoiceBackendService.parseBaseUri(_openVoiceBackendUrl);
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
    final outputDir = Directory(
      p.join(Directory.systemTemp.path, 'openvoice-reference'),
    );
    await outputDir.create(recursive: true);

    final normalizedPath = p.join(
      outputDir.path,
      'openvoice-reference-${DateTime.now().microsecondsSinceEpoch}.wav',
    );
    await _libraryService.normalizeAudioToWav(
      sourceAudioPath: sourceAudioPath,
      destinationWavPath: normalizedPath,
    );
    return normalizedPath;
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

  void _stopOpenVoiceHealthPolling() {
    _openVoiceHealthTimer?.cancel();
    _openVoiceHealthTimer = null;
  }

  @override
  void dispose() {
    _appState.removeListener(_handleAppStateChanged);
    unawaited(_previewSub?.cancel());
    _stopOpenVoiceHealthPolling();
    _openVoiceBackendService.dispose();
    _previewAudio.dispose();
    super.dispose();
  }
}
