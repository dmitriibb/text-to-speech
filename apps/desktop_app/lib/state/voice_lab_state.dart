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
  OpenVoiceCapabilities? _openVoiceCapabilities;
  String? _openVoiceSamplePath;
  bool _isOpenVoicePreviewSubmitting = false;
  String? _activeOpenVoiceJobId;

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
  bool get isVoiceCloningEnabled => _appState.isVoiceCloningEnabled;
  bool get hasSharedInputText => _appState.inputText.trim().isNotEmpty;
    String get openVoiceBackendUrl => _openVoiceBackendUrl;
    OpenVoiceBackendConnectionState get openVoiceConnectionState =>
      _openVoiceConnectionState;
    String? get openVoiceBackendMessage => _openVoiceBackendMessage;
    OpenVoiceCapabilities? get openVoiceCapabilities => _openVoiceCapabilities;
    String? get openVoiceSamplePath => _openVoiceSamplePath;
    bool get hasOpenVoiceSample =>
      _openVoiceSamplePath != null && _openVoiceSamplePath!.trim().isNotEmpty;
    bool get isOpenVoicePreviewSubmitting => _isOpenVoicePreviewSubmitting;
    String? get activeOpenVoiceJobId => _activeOpenVoiceJobId;
    bool get canPreviewWithOpenVoice =>
      isVoiceCloningEnabled &&
      hasSharedInputText &&
      hasOpenVoiceSample &&
      !_isOpenVoicePreviewSubmitting &&
      _openVoiceConnectionState == OpenVoiceBackendConnectionState.connected &&
      (_openVoiceCapabilities?.supportsPreview ?? false);

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

  Future<void> setOpenVoiceBackendUrl(String backendUrl) async {
    _openVoiceBackendUrl = backendUrl;
    _openVoiceConnectionState = OpenVoiceBackendConnectionState.disconnected;
    _openVoiceBackendMessage = null;
    notifyListeners();
    await _openVoicePreferencesService.saveBackendUrl(backendUrl);
  }

  void setOpenVoiceSamplePath(String? samplePath) {
    _openVoiceSamplePath = samplePath;
    notifyListeners();
  }

  Future<void> checkOpenVoiceConnection() async {
    _errorMessage = null;
    _openVoiceConnectionState = OpenVoiceBackendConnectionState.checking;
    _openVoiceBackendMessage = 'Checking backend connection...';
    notifyListeners();

    try {
      final baseUri = _openVoiceBackendService.parseBaseUri(_openVoiceBackendUrl);
      final health = await _openVoiceBackendService.fetchHealth(baseUri);
      final capabilities = await _openVoiceBackendService.fetchCapabilities(
        baseUri,
      );
      _openVoiceCapabilities = capabilities;
      _openVoiceConnectionState = OpenVoiceBackendConnectionState.connected;
      _openVoiceBackendMessage = health.engineReady
          ? 'Connected to ${health.backend} ${health.version}.'
          : 'Connected to ${health.backend} ${health.version}, but the OpenVoice engine is not wired yet.';
    } on OpenVoiceBackendException catch (error) {
      _openVoiceCapabilities = null;
      _openVoiceConnectionState = OpenVoiceBackendConnectionState.error;
      _openVoiceBackendMessage =
          'OpenVoice backend is not reachable at ${_openVoiceBackendUrl.trim()}.';
      _errorMessage = error.message;
    } catch (error) {
      _openVoiceCapabilities = null;
      _openVoiceConnectionState = OpenVoiceBackendConnectionState.error;
      _openVoiceBackendMessage =
          'OpenVoice backend is not reachable at ${_openVoiceBackendUrl.trim()}.';
      _errorMessage = error.toString();
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

  Future<void> previewWithOpenVoice() async {
    final sharedText = _appState.inputText.trim();
    if (sharedText.isEmpty) {
      _errorMessage =
          'Enter text on the Home screen before requesting an OpenVoice preview';
      notifyListeners();
      return;
    }

    final samplePath = _openVoiceSamplePath;
    if (samplePath == null || samplePath.trim().isEmpty) {
      _errorMessage = 'Select a reference WAV file for OpenVoice preview.';
      notifyListeners();
      return;
    }

    if (_openVoiceConnectionState != OpenVoiceBackendConnectionState.connected ||
        _openVoiceCapabilities == null) {
      await checkOpenVoiceConnection();
      if (_openVoiceConnectionState !=
              OpenVoiceBackendConnectionState.connected ||
          _openVoiceCapabilities == null) {
        return;
      }
    }

    _isOpenVoicePreviewSubmitting = true;
    _errorMessage = null;
    _openVoiceBackendMessage = 'Submitting OpenVoice preview job...';
    notifyListeners();

    try {
      final baseUri = _openVoiceBackendService.parseBaseUri(_openVoiceBackendUrl);
      final submission = await _openVoiceBackendService.submitPreviewJob(
        baseUri: baseUri,
        text: sharedText,
        referenceAudioPath: samplePath,
      );
      _activeOpenVoiceJobId = submission.jobId;
      _openVoiceBackendMessage =
          'OpenVoice preview job ${submission.jobId} submitted.';
      notifyListeners();

      final completedJob = await _openVoiceBackendService.waitForJobCompletion(
        baseUri: baseUri,
        jobId: submission.jobId,
        capabilities: _openVoiceCapabilities!,
      );

      if (completedJob.status == OpenVoiceJobStatus.failed) {
        _errorMessage = completedJob.error ?? 'OpenVoice preview job failed.';
        _openVoiceBackendMessage =
            'OpenVoice preview job ${submission.jobId} failed.';
        return;
      }

      final outputDir = Directory(
        p.join(Directory.systemTemp.path, 'openvoice-preview'),
      );
      final outputPath = p.join(
        outputDir.path,
        'openvoice-preview-${DateTime.now().microsecondsSinceEpoch}.wav',
      );
      final outputFile = await _openVoiceBackendService.downloadJobResult(
        baseUri: baseUri,
        jobId: submission.jobId,
        outputPath: outputPath,
      );

      await _previewAudio.stop();
      await _previewAudio.play(outputFile.path);
      _openVoiceBackendMessage =
          'OpenVoice preview job ${submission.jobId} is ready.';
    } on OpenVoiceBackendException catch (error) {
      _errorMessage = error.message;
      _openVoiceBackendMessage = 'OpenVoice preview failed.';
    } catch (error) {
      _errorMessage = 'OpenVoice preview failed: $error';
      _openVoiceBackendMessage = 'OpenVoice preview failed.';
    } finally {
      _isOpenVoicePreviewSubmitting = false;
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

  @override
  void dispose() {
    _appState.removeListener(_handleAppStateChanged);
    unawaited(_previewSub?.cancel());
    _openVoiceBackendService.dispose();
    _previewAudio.dispose();
    super.dispose();
  }
}
