import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/app_navigation_drawer.dart';
import '../widgets/live_tts_panel.dart';
import 'about_screen.dart';
import 'home_screen.dart';
import 'models_screen.dart';
import 'settings_screen.dart';

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
      appBar: AppBar(title: const Text('Live TTS')),
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
            if (state.isLoadingModels) {
              return const Center(child: CircularProgressIndicator());
            }

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: const LiveTtsPanel(),
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
      case AppDestination.settings:
        state.stopLiveTts();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (context) => const SettingsScreen()),
        );
      case AppDestination.about:
        state.stopLiveTts();
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (context) => const AboutScreen()),
        );
    }
  }
}
