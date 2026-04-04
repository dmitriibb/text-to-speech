import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/cloned_voice.dart';

/// Manages the on-disk voice library: stores reference audio
/// and a metadata JSON index.
class VoiceLibraryService {
  static const _libraryDir = 'voice_library';
  static const _indexFile = 'voices.json';

  String? _libraryPath;

  /// Returns the voice library directory, creating it if needed.
  Future<String> _ensureLibraryDir() async {
    if (_libraryPath != null) return _libraryPath!;

    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        '';
    if (home.isEmpty) throw StateError('Cannot determine home directory');

    _libraryPath = p.join(home, '.tts_app', _libraryDir);
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

    // Copy reference audio into library.
    final ext = p.extension(sourceAudioPath);
    final destPath = p.join(dir, '$id$ext');
    await File(sourceAudioPath).copy(destPath);

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
}
