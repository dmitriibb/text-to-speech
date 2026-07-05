import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/app_navigation_drawer.dart';
import '../widgets/error_banner.dart';
import 'about_screen.dart';
import 'dialog_screen.dart';
import 'home_screen.dart';
import 'live_tts_screen.dart';
import 'models_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppNavigationDrawer(
        selectedDestination: AppDestination.settings,
        onDestinationSelected: (destination) =>
            _navigateToDestination(context, destination),
      ),
      appBar: AppBar(title: const Text('Settings')),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF4F1E8), Color(0xFFE9F3F0)],
          ),
        ),
        child: Consumer<AppState>(
          builder: (context, state, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _InferenceProviderCard(state: state),
                  if (state.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    ErrorBanner(message: state.errorMessage!),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _navigateToDestination(
    BuildContext context,
    AppDestination destination,
  ) {
    Navigator.of(context).pop();

    switch (destination) {
      case AppDestination.home:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (context) => const HomeScreen()),
        );
      case AppDestination.liveTts:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (context) => const LiveTtsScreen()),
        );
      case AppDestination.dialog:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (context) => const DialogScreen()),
        );
      case AppDestination.models:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (context) => const ModelsScreen()),
        );
      case AppDestination.settings:
        break;
      case AppDestination.about:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (context) => const AboutScreen()),
        );
    }
  }
}

class _InferenceProviderCard extends StatelessWidget {
  const _InferenceProviderCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.memory, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text('Inference hardware', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Choose how sherpa-onnx loads models for speech generation. '
              'NNAPI may use GPU, NPU, DSP, or another accelerator depending '
              'on the Android device and model support; unsupported work falls '
              'back to CPU.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: state.selectedInferenceProvider,
              onChanged: (value) {
                if (value != null) {
                  state.setInferenceProvider(value);
                }
              },
              child: const Column(
                children: [
                  RadioListTile<String>(
                    value: AppState.cpuProvider,
                    contentPadding: EdgeInsets.zero,
                    title: Text('CPU'),
                    subtitle: Text('Most compatible. Runs entirely on CPU.'),
                  ),
                  RadioListTile<String>(
                    value: AppState.nnapiProvider,
                    contentPadding: EdgeInsets.zero,
                    title: Text('NNAPI acceleration'),
                    subtitle: Text(
                      'Lets Android route supported operations to available hardware acceleration.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
