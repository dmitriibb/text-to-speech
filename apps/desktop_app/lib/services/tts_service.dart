import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../models/voice_model.dart';

/// Result of a TTS synthesis operation.
class SynthesisResult {
  final Float32List samples;
  final int sampleRate;

  const SynthesisResult({required this.samples, required this.sampleRate});
}

/// Wraps the sherpa_onnx TTS engine.
class TtsService {
  sherpa.OfflineTts? _tts;
  VoiceModel? _loadedModel;
  bool _bindingsInitialized = false;

  /// Whether the engine is ready to synthesize.
  bool get isReady => _tts != null;

  /// The sample rate of the loaded model.
  int get sampleRate => _tts?.sampleRate ?? 0;

  /// The number of speakers in the loaded model.
  int get numSpeakers => _tts?.numSpeakers ?? 0;

  /// Initialize the native bindings. Must be called once before [loadModel].
  void initBindings() {
    if (_bindingsInitialized) return;
    sherpa.initBindings();
    _bindingsInitialized = true;
  }

  /// Loads a VITS model from the given directory.
  void loadModel(String modelDir, VoiceModel model) {
    // Free previous engine if any.
    _tts?.free();
    _tts = null;
    _loadedModel = null;

    final modelPath = p.join(modelDir, model.modelFile);
    final tokensPath = p.join(modelDir, model.tokensFile);
    final dataDirPath =
        model.dataDir.isNotEmpty ? p.join(modelDir, model.dataDir) : '';

    final vitsConfig = sherpa.OfflineTtsVitsModelConfig(
      model: modelPath,
      tokens: tokensPath,
      dataDir: dataDirPath,
    );

    final modelConfig = sherpa.OfflineTtsModelConfig(
      vits: vitsConfig,
      numThreads: model.numThreads,
      debug: false,
      provider: 'cpu',
    );

    final ttsConfig = sherpa.OfflineTtsConfig(
      model: modelConfig,
      maxNumSenetences: model.maxNumSentences,
    );

    _tts = sherpa.OfflineTts(ttsConfig);
    _loadedModel = model;
  }

  /// Synthesizes speech from text.
  ///
  /// [speed] controls playback speed (1.0 = normal, >1 = faster, <1 = slower).
  /// [speakerId] selects the speaker for multi-speaker models.
  SynthesisResult synthesize(
    String text, {
    double speed = 1.0,
    int speakerId = 0,
  }) {
    if (_tts == null) {
      throw StateError('TTS engine not initialized. Call loadModel first.');
    }

    final audio = _tts!.generate(
      text: text,
      sid: speakerId,
      speed: speed,
    );

    return SynthesisResult(
      samples: audio.samples,
      sampleRate: audio.sampleRate,
    );
  }

  /// Writes synthesis output to a WAV file.
  bool saveWav(SynthesisResult result, String outputPath) {
    return sherpa.writeWave(
      filename: outputPath,
      samples: result.samples,
      sampleRate: result.sampleRate,
    );
  }

  /// Releases native resources.
  void dispose() {
    _tts?.free();
    _tts = null;
    _loadedModel = null;
  }
}
