import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/ludu_theme.dart';
import 'models/game_settings.dart';
import 'models/ludo_color.dart';
import 'services/audio_service.dart';
import 'services/haptics_service.dart';
import 'services/persistence.dart';
import 'state/game_controller.dart';
import 'state/settings_controller.dart';
import 'ui/screens/game_screen.dart';
import 'ui/screens/setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Load persisted settings before the first frame so sound/vibration
  // backends and toggles start in the saved state (§10).
  GameSettings initialSettings = const GameSettings();
  try {
    initialSettings =
        await const SharedPrefsPersistence().loadSettings() ??
            initialSettings;
  } catch (_) {
    // Defaults stand.
  }
  AudioService.setMuted(!initialSettings.sound);
  HapticsService.setEnabled(initialSettings.vibration);

  // Warm up the audio backend before the first dice roll.
  AudioService.init();

  runApp(const LuduApp());
}

/// Top-level app widget. ProviderScope is embedded here so that
/// LuduApp is self-contained and works correctly in widget tests.
class LuduApp extends StatefulWidget {
  const LuduApp({super.key});

  @override
  State<LuduApp> createState() => _LuduAppState();
}

class _LuduAppState extends State<LuduApp> {
  // Clean light look by default (§9); midnight arena one tap away.
  ThemeMode _themeMode = ThemeMode.light;

  void _toggleTheme() {
    HapticsService.selection();
    setState(() {
      _themeMode = (_themeMode == ThemeMode.dark)
          ? ThemeMode.light
          : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Ludu',
        debugShowCheckedModeBanner: false,
        theme: LuduTheme.lightTheme,
        darkTheme: LuduTheme.darkTheme,
        themeMode: _themeMode,
        home: LuduMainNavigator(
          onToggleTheme: _toggleTheme,
          isDark: _themeMode == ThemeMode.dark,
        ),
      ),
    );
  }
}

class LuduMainNavigator extends ConsumerStatefulWidget {
  final VoidCallback onToggleTheme;
  final bool isDark;

  const LuduMainNavigator({
    super.key,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  ConsumerState<LuduMainNavigator> createState() =>
      _LuduMainNavigatorState();
}

class _LuduMainNavigatorState extends ConsumerState<LuduMainNavigator> {
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    // Push preloaded settings into the engine once it exists.
    Future.microtask(() {
      if (!mounted) return;
      ref
          .read(gameControllerProvider.notifier)
          .setSettings(ref.read(settingsControllerProvider));
    });
  }

  void _handleStartGame({
    required int playerCount,
    required List<String> playerNames,
    required List<LudoColor> playerColors,
  }) {
    ref.read(gameControllerProvider.notifier).startNewGame(
          playerCount: playerCount,
          playerNames: playerNames,
          playerColors: playerColors,
        );
    setState(() {
      _isPlaying = true;
    });
  }

  void _handleResumeGame() {
    // The save was already restored into the controller by SetupScreen.
    setState(() {
      _isPlaying = true;
    });
  }

  void _handleExitToSetup() {
    setState(() {
      _isPlaying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isPlaying) {
      return GameScreen(
        onNewGame: _handleExitToSetup,
        onToggleTheme: widget.onToggleTheme,
        isDark: widget.isDark,
      );
    }

    return SetupScreen(
      onStartGame: _handleStartGame,
      onResumeGame: _handleResumeGame,
      onToggleTheme: widget.onToggleTheme,
      isDark: widget.isDark,
    );
  }
}
