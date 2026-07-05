import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';

import '../state/app_state.dart';
import '../widgets/app_navigation_drawer.dart';
import '../widgets/error_banner.dart';
import 'about_screen.dart';
import 'dialog_screen.dart';
import 'home_screen.dart';
import 'live_tts_screen.dart';
import 'settings_screen.dart';

class ModelsScreen extends StatelessWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppNavigationDrawer(
        selectedDestination: AppDestination.models,
        onDestinationSelected: (destination) =>
            _navigateToDestination(context, destination),
      ),
      appBar: AppBar(title: const Text('Models')),
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

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ModelManagementPanel(
                    models: state.installedModels,
                    isDownloading: state.isDownloading,
                    currentInstallProgress: state.currentInstallProgress,
                    canManageModels: state.canManageModels,
                    onRefresh: state.refreshModels,
                    onInstall: state.downloadModel,
                    onDelete: state.deleteModel,
                  ),
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
        break;
      case AppDestination.settings:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (context) => const SettingsScreen()),
        );
      case AppDestination.about:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (context) => const AboutScreen()),
        );
    }
  }
}
