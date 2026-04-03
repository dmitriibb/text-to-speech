import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tts_core/tts_core.dart';

import '../services/audio_service.dart';
import '../services/model_service.dart';

enum SynthesisStatus { idle, generating, done, error }

class AppState extends ChangeNotifier {
  final ModelService _modelService = ModelService();
  final TtsService _ttsService = TtsService();
  final AudioService _audioService = AudioService();

  StreamSubscription<PlaybackState>? _audioSubscription;

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

  bool get hasAudio => _generatedWavPath != null;
  bool get canGenerate =>
      !_isDownloading &&
      _synthesisStatus != SynthesisStatus.generating &&
      _selectedModel?.status == ModelStatus.ready &&
      TextInputValidator.validate(_inputText) == null;

  List<InstalledModel> get readyModels =>
      _installedModels.where((model) => model.status == ModelStatus.ready).toList();

  List<InstalledModel> get installableModels =>
      _installedModels.where((model) => model.status != ModelStatus.ready).toList();

  Future<void> initialize() async {
    _ttsService.initBindings();
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
        _ttsService.loadModel(nextSelection.modelDir!, nextSelection.voice);
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
    if (model.status != ModelStatus.ready || model.modelDir == null) {
      return;
    }

    try {
      _ttsService.loadModel(model.modelDir!, model.voice);
      _selectedModel = model;
      _speed = model.voice.defaultSpeed;
      _errorMessage = null;
    } catch (error) {
      _errorMessage = 'Failed to load model: $error';
    }

    notifyListeners();
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

    _synthesisStatus = SynthesisStatus.generating;
    _errorMessage = null;
    await _audioService.stop();
    notifyListeners();

    try {
      final result = await Future(() {
        return _ttsService.synthesize(
          _inputText.trim(),
          speed: _speed,
          speakerId: _selectedModel!.voice.defaultSpeakerId,
        );
      });

      final wavPath = await _resolveOutputPath();
      final saved = _ttsService.saveWav(result, wavPath);
      if (!saved) {
        throw Exception('Failed to write WAV file');
      }

      _generatedWavPath = wavPath;
      _synthesisStatus = SynthesisStatus.done;
    } catch (error) {
      _synthesisStatus = SynthesisStatus.error;
      _errorMessage = 'Synthesis failed: $error';
    }

    notifyListeners();
  }

  Future<String> _resolveOutputPath() async {
    final supportDir = await getApplicationSupportDirectory();
    final outputDir = Directory(p.join(supportDir.path, 'generated_audio'));
    await outputDir.create(recursive: true);

    return p.join(outputDir.path, 'latest_output.wav');
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

  @override
  void dispose() {
    unawaited(_audioSubscription?.cancel());
    _ttsService.dispose();
    _modelService.dispose();
    unawaited(_audioService.dispose());
    super.dispose();
  }
}