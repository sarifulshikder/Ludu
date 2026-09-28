import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/ludu_theme.dart';
import 'models/ludo_color.dart';
import 'state/game_controller.dart';
import 'ui/screens/game_screen.dart';
import 'ui/screens/setup_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations for pass-and-play tablet/phone
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

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
  ThemeMode _themeMode = ThemeMode.dark;

  void _toggleTheme() {
    setState(() {
      _themeMode = (_themeMode == ThemeMode.dark) ? ThemeMode.light : ThemeMode.dark;
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
  ConsumerState<LuduMainNavigator> createState() => _LuduMainNavigatorState();
}

class _LuduMainNavigatorState extends ConsumerState<LuduMainNavigator> {
  bool _isPlaying = false;

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
      onToggleTheme: widget.onToggleTheme,
      isDark: widget.isDark,
    );
  }
}
