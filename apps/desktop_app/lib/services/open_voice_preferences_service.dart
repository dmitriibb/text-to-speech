import 'dart:io';

import 'package:path/path.dart' as p;

import 'open_voice_backend_service.dart';

class OpenVoicePreferencesService {
  static const _backendUrlFile = '.tts_open_voice_backend_url';
  static const _omniVoiceBackendUrlFile = '.tts_omnivoice_backend_url';
  static const _voxCpm2BackendUrlFile = '.tts_voxcpm2_backend_url';
  static const _openVoiceEnabledFile = '.tts_open_voice_enabled';
  static const _omniVoiceEnabledFile = '.tts_omnivoice_enabled';
  static const _voxCpm2EnabledFile = '.tts_voxcpm2_enabled';

  Future<String> loadBackendUrl() async {
    try {
      final home =
          Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '';
      if (home.isEmpty) {
        return OpenVoiceBackendService.defaultBaseUrl;
      }

      final file = File(p.join(home, _backendUrlFile));
      if (!await file.exists()) {
        return OpenVoiceBackendService.defaultBaseUrl;
      }

      final saved = (await file.readAsString()).trim();
      return saved.isEmpty ? OpenVoiceBackendService.defaultBaseUrl : saved;
    } catch (_) {
      return OpenVoiceBackendService.defaultBaseUrl;
    }
  }

  Future<void> saveBackendUrl(String backendUrl) async {
    try {
      final home =
          Platform.environment['HOME'] ??
          Platform.environment['USERPROFILE'] ??
          '';
      if (home.isEmpty) {
        return;
      }

      final file = File(p.join(home, _backendUrlFile));
      await file.writeAsString(backendUrl.trim(), flush: true);
    } catch (_) {}
  }

  Future<String> loadOmniVoiceBackendUrl(String fallback) =>
      _loadString(_omniVoiceBackendUrlFile, fallback);

  Future<void> saveOmniVoiceBackendUrl(String backendUrl) =>
      _saveString(_omniVoiceBackendUrlFile, backendUrl.trim());

  Future<String> loadVoxCpm2BackendUrl(String fallback) =>
      _loadString(_voxCpm2BackendUrlFile, fallback);

  Future<void> saveVoxCpm2BackendUrl(String backendUrl) =>
      _saveString(_voxCpm2BackendUrlFile, backendUrl.trim());

  Future<bool> loadOpenVoiceEnabled() => _loadBool(_openVoiceEnabledFile);

  Future<void> saveOpenVoiceEnabled(bool enabled) =>
      _saveString(_openVoiceEnabledFile, enabled.toString());

  Future<bool> loadOmniVoiceEnabled() => _loadBool(_omniVoiceEnabledFile);

  Future<void> saveOmniVoiceEnabled(bool enabled) =>
      _saveString(_omniVoiceEnabledFile, enabled.toString());

  Future<bool> loadVoxCpm2Enabled() => _loadBool(_voxCpm2EnabledFile);

  Future<void> saveVoxCpm2Enabled(bool enabled) =>
      _saveString(_voxCpm2EnabledFile, enabled.toString());

  Future<String> _loadString(String fileName, String fallback) async {
    try {
      final home = _homeDirectory();
      if (home.isEmpty) return fallback;
      final file = File(p.join(home, fileName));
      if (!await file.exists()) return fallback;
      final value = (await file.readAsString()).trim();
      return value.isEmpty ? fallback : value;
    } catch (_) {
      return fallback;
    }
  }

  Future<bool> _loadBool(String fileName) async {
    return (await _loadString(fileName, 'false')).toLowerCase() == 'true';
  }

  Future<void> _saveString(String fileName, String value) async {
    try {
      final home = _homeDirectory();
      if (home.isEmpty) return;
      await File(p.join(home, fileName)).writeAsString(value, flush: true);
    } catch (_) {}
  }

  String _homeDirectory() =>
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
}
