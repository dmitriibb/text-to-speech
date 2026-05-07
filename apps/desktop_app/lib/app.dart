import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tts_core/tts_core.dart';

import 'screens/home_screen.dart';
import 'state/app_state.dart';
import 'state/voice_lab_state.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  late final AppState _appState;
  late final VoiceLabState _voiceLabState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appState = AppState();
    _voiceLabState = VoiceLabState(appState: _appState);
    unawaited(_appState.initialize());
    unawaited(_voiceLabState.initialize());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _appState.taskManager.cancelAllActiveTasks();
      unawaited(_appState.stopPlayback());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appState.taskManager.cancelAllActiveTasks();
    _voiceLabState.dispose();
    _appState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: _appState),
        ChangeNotifierProvider<VoiceLabState>.value(value: _voiceLabState),
      ],
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          return ChangeNotifierProvider<TaskManager>.value(
            value: appState.taskManager,
            child: MaterialApp(
              title: 'Text to Speech',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.indigo,
                  brightness: Brightness.light,
                ),
                useMaterial3: true,
              ),
              darkTheme: ThemeData(
                colorScheme: ColorScheme.fromSeed(
                  seedColor: Colors.indigo,
                  brightness: Brightness.dark,
                ),
                useMaterial3: true,
              ),
              themeMode: ThemeMode.system,
              home: const HomeScreen(),
            ),
          );
        },
      ),
    );
  }
}
