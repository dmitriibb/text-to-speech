import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../models/cloned_voice.dart';

typedef ProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

enum _ImportedAudioFormat { wav, mp3, unsupported }

/// Manages the on-disk voice library: stores reference audio
/// and a metadata JSON index.
class VoiceLibraryService {
  VoiceLibraryService({String? libraryRootPath, ProcessRunner? processRunner})
    : _libraryRootPath = libraryRootPath,
      _processRunner = processRunner ?? Process.run;

  static const _libraryDir = 'voice_library';
  static const _indexFile = 'voices.json';

  final String? _libraryRootPath;
  final ProcessRunner _processRunner;
  String? _libraryPath;

  /// Returns the voice library directory, creating it if needed.
  Future<String> _ensureLibraryDir() async {
    if (_libraryPath != null) return _libraryPath!;

    final configuredRoot = _libraryRootPath;
    if (configuredRoot != null && configuredRoot.isNotEmpty) {
      _libraryPath = p.join(configuredRoot, _libraryDir);
    } else {
      final home =
          Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '';
      if (home.isEmpty) throw StateError('Cannot determine home directory');
      _libraryPath = p.join(home, '.tts_app', _libraryDir);
    }
    await Directory(_libraryPath!).create(recursive: true);
    return _libraryPath!;
  }

  /// Loads all cloned voices from the library.
  Future<List<ClonedVoice>> loadVoices() async {
    final dir = await _ensureLibraryDir();
    final indexFile = File(p.join(dir, _indexFile));
    if (!await indexFile.exists()) return [];

    try {
      final content = await indexFile.readAsString();
      return ClonedVoice.listFromJson(content);
    } catch (_) {
      return [];
    }
  }

  /// Saves a new cloned voice: copies the reference audio into the library
  /// and updates the index.
  Future<ClonedVoice> addVoice({
    required String name,
    required String sourceAudioPath,
  }) async {
    final dir = await _ensureLibraryDir();
    final id = 'voice-${DateTime.now().microsecondsSinceEpoch}';
    final sourceFile = File(sourceAudioPath);
    if (!await sourceFile.exists()) {
      throw StateError('Voice sample file not found: $sourceAudioPath');
    }

    // Normalize all imported reference audio to WAV so preview and cloning
    // can keep using the existing WAV-based pipeline.
    final destPath = p.join(dir, '$id.wav');
    final format = await _detectAudioFormat(sourceAudioPath);
    switch (format) {
      case _ImportedAudioFormat.wav:
        await sourceFile.copy(destPath);
        break;
      case _ImportedAudioFormat.mp3:
        await _convertMp3ToWav(
          sourceAudioPath: sourceAudioPath,
          destinationWavPath: destPath,
        );
        break;
      case _ImportedAudioFormat.unsupported:
        throw UnsupportedError(
          'Unsupported voice sample format. Choose a WAV or MP3 file.',
        );
    }

    final voice = ClonedVoice(
      id: id,
      name: name,
      referenceAudioPath: destPath,
      createdAt: DateTime.now(),
    );

    final voices = await loadVoices();
    voices.add(voice);
    await _saveIndex(dir, voices);

    return voice;
  }

  /// Removes a cloned voice from the library.
  Future<void> removeVoice(String voiceId) async {
    final dir = await _ensureLibraryDir();
    final voices = await loadVoices();
    final voice = voices.where((v) => v.id == voiceId).firstOrNull;

    if (voice != null) {
      // Delete reference audio file.
      final audioFile = File(voice.referenceAudioPath);
      if (await audioFile.exists()) {
        await audioFile.delete();
      }
      voices.removeWhere((v) => v.id == voiceId);
      await _saveIndex(dir, voices);
    }
  }

  Future<void> _saveIndex(String dir, List<ClonedVoice> voices) async {
    final indexFile = File(p.join(dir, _indexFile));
    await indexFile.writeAsString(ClonedVoice.listToJson(voices));
  }

  Future<_ImportedAudioFormat> _detectAudioFormat(String path) async {
    final bytes = await File(path)
        .openRead(0, 12)
        .fold<BytesBuilder>(
          BytesBuilder(copy: false),
          (builder, chunk) => builder..add(chunk),
        );
    final header = bytes.takeBytes();
    if (_looksLikeWav(header)) {
      return _ImportedAudioFormat.wav;
    }
    if (_looksLikeMp3(header)) {
      return _ImportedAudioFormat.mp3;
    }
    return _ImportedAudioFormat.unsupported;
  }

  bool _looksLikeWav(Uint8List header) {
    if (header.length < 12) {
      return false;
    }
    return _ascii(header, 0, 4) == 'RIFF' && _ascii(header, 8, 12) == 'WAVE';
  }

  bool _looksLikeMp3(Uint8List header) {
    if (header.length < 3) {
      return false;
    }
    if (_ascii(header, 0, 3) == 'ID3') {
      return true;
    }
    if (header.length < 2) {
      return false;
    }
    return header[0] == 0xff && (header[1] & 0xe0) == 0xe0;
  }

  String _ascii(Uint8List bytes, int start, int end) {
    return String.fromCharCodes(bytes.sublist(start, end));
  }

  Future<void> _convertMp3ToWav({
    required String sourceAudioPath,
    required String destinationWavPath,
  }) async {
    try {
      final result = await _processRunner('ffmpeg', [
        '-y',
        '-i',
        sourceAudioPath,
        '-vn',
        '-ac',
        '1',
        '-c:a',
        'pcm_s16le',
        destinationWavPath,
      ]);

      if (result.exitCode != 0 || !await File(destinationWavPath).exists()) {
        final stderr = '${result.stderr}'.trim();
        final detail = stderr.isEmpty
            ? 'Unknown ffmpeg conversion failure.'
            : stderr;
        throw StateError(
          'Failed to convert MP3 voice sample to WAV. Ensure ffmpeg is installed and the file is valid.\n$detail',
        );
      }
    } on ProcessException catch (error) {
      throw StateError(
        'Failed to convert MP3 voice sample to WAV. Install ffmpeg and try again.\n$error',
      );
    }
  }
}
