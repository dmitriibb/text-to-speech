import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

import '../models/voice_model.dart';

class SynthesisResult {
  final Float32List samples;
  final int sampleRate;

  const SynthesisResult({required this.samples, required this.sampleRate});
}

class TtsService {
  sherpa.OfflineTts? _tts;
  bool _bindingsInitialized = false;

  bool get isReady => _tts != null;
  int get sampleRate => _tts?.sampleRate ?? 0;
  int get numSpeakers => _tts?.numSpeakers ?? 0;

  void initBindings() {
    if (_bindingsInitialized) {
      return;
    }

    sherpa.initBindings();
    _bindingsInitialized = true;
  }

  void loadModel(String modelDir, VoiceModel model) {
    _tts?.free();
    _tts = null;

    final modelPath = p.join(modelDir, model.modelFile);
    final tokensPath = p.join(modelDir, model.tokensFile);
    final lexiconPath =
        model.lexiconFile.isNotEmpty ? p.join(modelDir, model.lexiconFile) : '';
    final dataDirPath =
        model.dataDir.isNotEmpty ? p.join(modelDir, model.dataDir) : '';

    final vitsConfig = sherpa.OfflineTtsVitsModelConfig(
      model: modelPath,
      lexicon: lexiconPath,
      tokens: tokensPath,
      dataDir: dataDirPath,
    );

    final modelConfig = sherpa.OfflineTtsModelConfig(
      vits: vitsConfig,
      numThreads: model.numThreads,
      debug: false,
      provider: model.provider,
    );

    final ttsConfig = sherpa.OfflineTtsConfig(
      model: modelConfig,
      maxNumSenetences: model.maxNumSentences,
    );

    _tts = sherpa.OfflineTts(ttsConfig);
  }

  SynthesisResult synthesize(
    String text, {
    double speed = 1.0,
    int speakerId = 0,
  }) {
    if (_tts == null) {
      throw StateError('TTS engine not initialized. Call loadModel first.');
    }

    final audio = _tts!.generate(text: text, sid: speakerId, speed: speed);
    return SynthesisResult(samples: audio.samples, sampleRate: audio.sampleRate);
  }

  bool saveWav(SynthesisResult result, String outputPath) {
    return sherpa.writeWave(
      filename: outputPath,
      samples: result.samples,
      sampleRate: result.sampleRate,
    );
  }

  void dispose() {
    _tts?.free();
    _tts = null;
  }
}