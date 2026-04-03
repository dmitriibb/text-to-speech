import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/voice_model.dart';
import '../services/audio_service.dart';
import '../services/model_service.dart';
import '../services/tts_service.dart';

/// Synthesis workflow state.
enum SynthesisStatus { idle, generating, done, error }

/// Top-level application state.
class AppState extends ChangeNotifier {
  final ModelService _modelService = ModelService();
  final TtsService _ttsService = TtsService();
  final AudioService _audioService = AudioService();

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
  PlaybackState _playbackState = PlaybackState.stopped;

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

  /// True when a ready model is selected and text is non-empty.
  bool get canGenerate =>
      _selectedModel != null &&
      _selectedModel!.status == ModelStatus.ready &&
      _inputText.trim().isNotEmpty &&
      _synthesisStatus != SynthesisStatus.generating;

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
    _ttsService.initBindings();

    // Listen to audio playback state.
    _audioService.onStateChanged.listen((state) {
      _playbackState = state;
      notifyListeners();
    });

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

  /// Selects a model and loads it into the TTS engine.
  Future<void> selectModel(InstalledModel model) async {
    if (model.status != ModelStatus.ready || model.modelDir == null) return;

    try {
      _ttsService.loadModel(model.modelDir!, model.voice);
      _selectedModel = model;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Failed to load model: $e';
    }
    notifyListeners();
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

  /// Generates speech from the current input text.
  Future<void> generate() async {
    if (!canGenerate) return;

    _synthesisStatus = SynthesisStatus.generating;
    _errorMessage = null;
    // Stop any playing audio.
    await _audioService.stop();
    notifyListeners();

    try {
      // Run synthesis (CPU-bound, runs on main isolate for now).
      final result = await Future(() {
        return _ttsService.synthesize(
          _inputText.trim(),
          speed: _speed,
          speakerId: _selectedModel!.voice.defaultSpeakerId,
        );
      });

      // Write to temp file for playback.
      final tempDir = Directory.systemTemp;
      final wavPath = p.join(tempDir.path, 'tts_output.wav');
      final ok = _ttsService.saveWav(result, wavPath);
      if (!ok) {
        throw Exception('Failed to write WAV file');
      }

      _generatedWavPath = wavPath;
      _synthesisStatus = SynthesisStatus.done;
    } catch (e) {
      _synthesisStatus = SynthesisStatus.error;
      _errorMessage = 'Synthesis failed: $e';
    }
    notifyListeners();
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

  // ---- Cleanup ----

  @override
  void dispose() {
    _ttsService.dispose();
    _audioService.dispose();
    super.dispose();
  }
}
