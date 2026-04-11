import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_ui/shared_ui.dart';

import '../state/app_state.dart';
import '../widgets/app_navigation_drawer.dart';
import '../widgets/error_banner.dart';
import 'about_screen.dart';
import 'home_screen.dart';

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
                    selectedModelId: state.selectedModel?.voice.id,
                    isDownloading: state.isDownloading,
                    currentInstallProgress: state.currentInstallProgress,
                    canManageModels: state.canManageModels,
                    storageDescription:
                        'Models are stored privately under ${state.modelsDirectory ?? 'the app support directory'}.',
                    onRefresh: state.refreshModels,
                    onInstall: state.downloadModel,
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
      case AppDestination.models:
        break;
      case AppDestination.about:
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (context) => const AboutScreen()),
        );
    }
  }
}
