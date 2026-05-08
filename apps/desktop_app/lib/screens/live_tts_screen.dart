import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/app_navigation_drawer.dart';
import '../widgets/live_tts_panel.dart';
import 'home_screen.dart';
import 'models_screen.dart';
import 'voice_lab_screen.dart';

class LiveTtsScreen extends StatelessWidget {
  const LiveTtsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppNavigationDrawer(
        selectedDestination: AppDestination.liveTts,
        onDestinationSelected: (destination) =>
            _navigateToDestination(context, destination),
      ),
      appBar: AppBar(title: const Text('Live TTS'), centerTitle: false),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          if (state.isLoadingModels) {
            return const Center(child: CircularProgressIndicator());
          }

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: const LiveTtsPanel(),
              ),
            ),
          );
        },
      ),
    );
  }

  void _navigateToDestination(
    BuildContext context,
    AppDestination destination,
  ) {
    final state = context.read<AppState>();
    Navigator.of(context).pop();

    switch (destination) {
      case AppDestination.home:
        state.stopLiveTts();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (context) => const HomeScreen()),
        );
      case AppDestination.liveTts:
        break;
      case AppDestination.models:
        state.stopLiveTts();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (context) => const ModelsScreen()),
        );
      case AppDestination.voiceLab:
        state.stopLiveTts();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (context) => const VoiceLabScreen()),
        );
    }
  }
}
