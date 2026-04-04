import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:tts_core/tts_core.dart';

import '../models/cloned_voice.dart';
import '../services/audio_service.dart';
import '../services/voice_library_service.dart';
import 'app_state.dart';

class VoiceLabState extends ChangeNotifier {
  VoiceLabState({
    required AppState appState,
  }) : _appState = appState;

  final AppState _appState;
  final VoiceLibraryService _libraryService = VoiceLibraryService();

  List<ClonedVoice> _voices = [];
  bool _isLoading = true;
  String? _errorMessage;

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

  void setError(String message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// The Pocket TTS model from the catalog, if installed and ready.
  InstalledModel? get pocketModel {
    return _appState.installedModels
        .where((m) =>
            m.voice.family == 'pocket' && m.status == ModelStatus.ready)
        .firstOrNull;
  }

  bool get hasPocketModel => pocketModel != null;

  Future<void> initialize() async {
    _previewSub = _previewAudio.onStateChanged.listen((state) {
      _isPreviewPlaying = state == PlaybackState.playing;
      if (state == PlaybackState.stopped) {
        _previewingVoiceId = null;
      }
      notifyListeners();
    });

    await loadVoices();
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

  /// Adds a new cloned voice from a WAV file path.
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

  /// Generates speech using a cloned voice via the Pocket TTS model.
  Future<void> generateWithClonedVoice({
    required ClonedVoice voice,
    required String text,
    required double speed,
  }) async {
    final model = pocketModel;
    if (model == null || model.modelDir == null) {
      _errorMessage = 'Pocket TTS model is not installed';
      notifyListeners();
      return;
    }

    if (text.trim().isEmpty) {
      _errorMessage = 'Please enter text to synthesize';
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

      final outputDir =
          Directory(p.join(Directory.systemTemp.path, 'tts_generated'));
      await outputDir.create(recursive: true);
      final outputPath = p.join(
        outputDir.path,
        'cloned-${DateTime.now().microsecondsSinceEpoch}.wav',
      );

      await _appState.taskManager.submitClonedSynthesis(
        modelDir: model.modelDir!,
        voice: model.voice,
        text: text.trim(),
        speed: speed,
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

  @override
  void dispose() {
    unawaited(_previewSub?.cancel());
    _previewAudio.dispose();
    super.dispose();
  }
}
