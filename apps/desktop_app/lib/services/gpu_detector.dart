import 'dart:ffi';
import 'dart:io';

/// Detects which ONNX Runtime execution providers are available on the system.
///
/// This is a desktop-only utility. It checks for the presence of GPU runtime
/// libraries to determine which providers can be used with sherpa_onnx.
class GpuDetector {
  /// All providers that are always available.
  static const String cpu = 'cpu';
  static const String cuda = 'cuda';
  static const String rocm = 'rocm';

  /// Display labels for each provider.
  static const Map<String, String> providerLabels = {
    cpu: 'CPU',
    cuda: 'CUDA (NVIDIA GPU)',
    rocm: 'ROCm (AMD GPU)',
  };

  /// Detects available providers by checking for GPU runtime libraries.
  ///
  /// CPU is always available. CUDA and ROCm are available if their
  /// respective shared libraries can be found on the system.
  static List<String> detectAvailableProviders() {
    final providers = <String>[cpu];

    if (Platform.isLinux) {
      if (_canLoadLibrary('libcudart.so') ||
          _canLoadLibrary('libcudart.so.11') ||
          _canLoadLibrary('libcudart.so.12')) {
        providers.add(cuda);
      }
      if (_canLoadLibrary('libamdhip64.so') ||
          _canLoadLibrary('libamdhip64.so.5') ||
          _canLoadLibrary('libamdhip64.so.6')) {
        providers.add(rocm);
      }
    } else if (Platform.isWindows) {
      // On Windows, CUDA uses cudart64_*.dll and ROCm uses amdhip64.dll
      if (_canLoadLibrary('cudart64_110.dll') ||
          _canLoadLibrary('cudart64_12.dll')) {
        providers.add(cuda);
      }
      // DirectML could be added here in the future
    }

    return providers;
  }

  static bool _canLoadLibrary(String name) {
    try {
      DynamicLibrary.open(name);
      return true;
    } catch (_) {
      return false;
    }
  }
}
