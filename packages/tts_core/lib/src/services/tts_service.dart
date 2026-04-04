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
    final tokensPath =
        model.tokensFile.isNotEmpty ? p.join(modelDir, model.tokensFile) : '';
    final lexiconPath =
        model.lexiconFile.isNotEmpty ? p.join(modelDir, model.lexiconFile) : '';
    final dataDirPath =
        model.dataDir.isNotEmpty ? p.join(modelDir, model.dataDir) : '';

    final sherpa.OfflineTtsModelConfig modelConfig;

    switch (model.family) {
      case 'kokoro':
        final voicesPath =
            model.voicesFile.isNotEmpty ? p.join(modelDir, model.voicesFile) : '';
        final kokoroConfig = sherpa.OfflineTtsKokoroModelConfig(
          model: modelPath,
          voices: voicesPath,
          tokens: tokensPath,
          dataDir: dataDirPath,
          lexicon: lexiconPath,
        );
        modelConfig = sherpa.OfflineTtsModelConfig(
          kokoro: kokoroConfig,
          numThreads: model.numThreads,
          debug: false,
          provider: model.provider,
        );
        break;
      case 'pocket':
        final pocketConfig = sherpa.OfflineTtsPocketModelConfig(
          lmFlow: modelPath,
          lmMain: p.join(modelDir, model.pocketLmMain),
          encoder: p.join(modelDir, model.pocketEncoder),
          decoder: p.join(modelDir, model.pocketDecoder),
          textConditioner: p.join(modelDir, model.pocketTextConditioner),
          vocabJson: p.join(modelDir, model.pocketVocabJson),
          tokenScoresJson: p.join(modelDir, model.pocketTokenScoresJson),
        );
        modelConfig = sherpa.OfflineTtsModelConfig(
          pocket: pocketConfig,
          numThreads: model.numThreads,
          debug: false,
          provider: model.provider,
        );
        break;
      default: // 'vits' and any other family
        final vitsConfig = sherpa.OfflineTtsVitsModelConfig(
          model: modelPath,
          lexicon: lexiconPath,
          tokens: tokensPath,
          dataDir: dataDirPath,
        );
        modelConfig = sherpa.OfflineTtsModelConfig(
          vits: vitsConfig,
          numThreads: model.numThreads,
          debug: false,
          provider: model.provider,
        );
    }

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

  /// Synthesize speech using a reference audio clip for zero-shot voice cloning.
  SynthesisResult synthesizeWithReference(
    String text, {
    required Float32List referenceAudio,
    required int referenceSampleRate,
    double speed = 1.0,
    int numSteps = 2,
  }) {
    if (_tts == null) {
      throw StateError('TTS engine not initialized. Call loadModel first.');
    }

    final config = sherpa.OfflineTtsGenerationConfig(
      speed: speed,
      referenceAudio: referenceAudio,
      referenceSampleRate: referenceSampleRate,
      numSteps: numSteps,
    );

    final audio = _tts!.generateWithConfig(text: text, config: config);
    return SynthesisResult(samples: audio.samples, sampleRate: audio.sampleRate);
  }

  bool saveWav(SynthesisResult result, String outputPath) {
    return sherpa.writeWave(
      filename: outputPath,
      samples: result.samples,
      sampleRate: result.sampleRate,
    );
  }

  /// Reads a WAV file and returns its samples and sample rate.
  static SynthesisResult readWavFile(String path) {
    final wave = sherpa.readWave(path);
    return SynthesisResult(samples: wave.samples, sampleRate: wave.sampleRate);
  }

  void dispose() {
    _tts?.free();
    _tts = null;
  }
}