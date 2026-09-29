import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/env.dart';
import '../../models/game_settings.dart';
import '../../models/game_state.dart';
import '../../models/ludo_color.dart';
import '../../models/player.dart';
import '../../services/audio_service.dart';
import '../../services/haptics_service.dart';
import '../../state/game_controller.dart';
import '../../state/settings_controller.dart';
import '../board/board_painter.dart';
import '../board/ludo_board.dart';
import '../widgets/player_panel.dart';
import 'ranking_screen.dart';
import 'rules_screen.dart';
import 'settings_sheet.dart';

/// Tall-board game screen (§8), top to bottom:
///
/// slim top bar (back, sound, pause) → player panels for the top bases →
/// tall edge-to-edge board → player panels for the bottom bases.
///
/// Every panel is anchored to the colour of the base it sits next to
/// (§A1): top-left Red, top-right Green, bottom-left Blue, bottom-right
/// Yellow — so a panel is never on the wrong side of the board.
/// Only the active player's dice is highlighted and tappable and it pulses
/// while it waits; there is no "tap to roll" text line (removed in §B).
class GameScreen extends ConsumerStatefulWidget {
  final VoidCallback onNewGame;
  final VoidCallback onToggleTheme;
  final bool isDark;

  const GameScreen({
    super.key,
    required this.onNewGame,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _isMuted = AudioService.isMuted;
  bool _boardAnimating = false;

  /// Short input freeze after an automatic pass (§4: "short delay").
  bool _passFreeze = false;
  Timer? _freezeTimer;
  Timer? _autoMoveTimer;

  static const double _topBarHeight = 40.0;
  static const double _gap = 5.0;

  /// Panels are placed by base colour, not seat index (§A1).
  static const LudoColor topLeft = LudoColor.red;
  static const LudoColor topRight = LudoColor.green;
  static const LudoColor bottomLeft = LudoColor.blue;
  static const LudoColor bottomRight = LudoColor.yellow;

  @override
  void initState() {
    super.initState();
    // Keep the screen awake for the whole match (§F). No platform channel
    // exists in widget tests, so skip it there.
    if (!isFlutterTest) WakelockPlus.enable().catchError((_) {});
  }

  @override
  void dispose() {
    if (!isFlutterTest) WakelockPlus.disable().catchError((_) {});
    _freezeTimer?.cancel();
    _autoMoveTimer?.cancel();
    super.dispose();
  }

  void _toggleMute() {
    HapticsService.light();
    setState(() {
      AudioService.toggleMute();
      _isMuted = AudioService.isMuted;
    });
  }

  void _openSettings() {
    HapticsService.light();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          widget.isDark ? const Color(0xFF141D2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SettingsSheet(
        isDark: widget.isDark,
        onToggleTheme: widget.onToggleTheme,
        onRestartMatch: _confirmRestart,
      ),
    );
  }

  /// Pause menu (§F): Resume, Restart, Settings, Quit.
  void _openPauseMenu() {
    HapticsService.light();
    showModalBottomSheet(
      context: context,
      backgroundColor:
          widget.isDark ? const Color(0xFF141D2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'PAUSED',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.0,
                  color: Color(0xFFE9C46A),
                ),
              ),
              const SizedBox(height: 12),
              _PauseAction(
                icon: Icons.play_arrow_rounded,
                label: 'Resume',
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
              _PauseAction(
                icon: Icons.settings_rounded,
                label: 'Settings',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openSettings();
                },
              ),
              _PauseAction(
                icon: Icons.menu_book_rounded,
                label: 'Rules',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => RulesScreen(isDark: widget.isDark),
                  ));
                },
              ),
              _PauseAction(
                icon: Icons.refresh_rounded,
                label: 'Restart match',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmRestart();
                },
              ),
              _PauseAction(
                icon: Icons.logout_rounded,
                label: 'Quit to home',
                danger: true,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmExit();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmRestart() {
    HapticsService.light();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
            widget.isDark ? const Color(0xFF141D2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Restart Game?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
            'Are you sure you want to restart the current match?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _rematchWith(ref.read(gameControllerProvider));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63946)),
            child:
                const Text('Restart', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _rematchWith(GameState st) {
    ref.read(gameControllerProvider.notifier).startNewGame(
          playerCount: st.players.length,
          playerNames: st.players.map((p) => p.name).toList(),
          playerColors: st.players.map((p) => p.color).toList(),
          teamMode: st.teamMode,
        );
  }

  void _confirmExit() {
    HapticsService.light();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
            widget.isDark ? const Color(0xFF141D2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Quit this game?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
            'Your progress is saved, so you can resume from the home screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep playing'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onNewGame();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63946)),
            child:
                const Text('Quit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Rolls the dice, or confirms a forced single move. Locked out while a
  /// hop animation or an auto-pass beat is running.
  void _primaryAction(GameState gameState, GameController controller) {
    if (_boardAnimating || _passFreeze) return;
    _autoMoveTimer?.cancel();
    if (gameState.canRollDice) {
      controller.rollDice();
      _afterRoll(ref.read(gameControllerProvider));
    } else if (gameState.mustSelectToken &&
        gameState.movableTokenIds.length == 1) {
      controller.moveToken(gameState.movableTokenIds.first);
    }
  }

  /// Coordinates the beats after a roll resolves (§4–§5):
  /// auto-pass freeze when nobody can move, auto-move when the setting is
  /// on and exactly one move is legal.
  void _afterRoll(GameState state) {
    if (state.phase != GamePhase.playing) return;
    if (state.currentDiceRoll == null) {
      // No legal moves — the engine already passed the turn; hold inputs
      // for a short beat so the pass reads clearly.
      setState(() => _passFreeze = true);
      _freezeTimer?.cancel();
      _freezeTimer = Timer(
          const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _passFreeze = false);
      });
      return;
    }
    final autoMove = ref.read(settingsControllerProvider).autoMove;
    if (autoMove && state.mustSelectToken) {
      final idx = state.currentPlayerIndex;
      final roll = state.currentDiceRoll!;
      if (state.movableTokenIds.length != 1) return;
      _autoMoveTimer?.cancel();
      _autoMoveTimer = Timer(const Duration(milliseconds: 650), () {
        if (!mounted) return;
        final fresh = ref.read(gameControllerProvider);
        final controller = ref.read(gameControllerProvider.notifier);
        if (fresh.phase == GamePhase.playing &&
            fresh.currentPlayerIndex == idx &&
            fresh.currentDiceRoll == roll &&
            fresh.mustSelectToken &&
            fresh.movableTokenIds.length == 1 &&
            !_boardAnimating &&
            !_passFreeze) {
          controller.moveToken(fresh.movableTokenIds.first);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final settings = ref.watch(settingsControllerProvider);

    // §A2: dark status-bar icons and text so the system bar stays readable
    // on the light board.
    SystemChrome.setSystemUIOverlayStyle(widget.isDark
        ? SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: const Color(0xFF070B14),
            systemNavigationBarIconBrightness: Brightness.light,
          )
        : SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: const Color(0xFFEDE4D2),
            systemNavigationBarIconBrightness: Brightness.dark,
          ));

    if (gameState.phase == GamePhase.finished) {
      return RankingScreen(
        gameState: gameState,
        onRematch: () => _rematchWith(gameState),
        onNewGame: widget.onNewGame,
      );
    }

    return Scaffold(
      backgroundColor: widget.isDark
          ? const Color(0xFF070B14)
          : const Color(0xFFF4EEE1),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: widget.isDark
                ? const [
                    Color(0xFF0B1A33),
                    Color(0xFF060C18),
                    Color(0xFF0A1526)
                  ]
                : const [
                    Color(0xFFFBF8F0),
                    Color(0xFFF4EEE1),
                    Color(0xFFEDE4D2)
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(
                  height: _topBarHeight, child: _buildTopBar(gameState)),
              const SizedBox(height: _gap),
              _buildPanelRow(gameState, controller, settings,
                  const [topLeft, topRight]),
              const SizedBox(height: _gap),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    // Tall board: 15 columns × 1:1.45 cells (§D).
                    aspectRatio: 15 / (15 * BoardPainter.cellAspect),
                    child: LudoBoard(
                      gameState: gameState,
                      timeScale: settings.timeScale,
                      onTokenSelected: (tokenId) {
                        if (_boardAnimating || _passFreeze) return;
                        _autoMoveTimer?.cancel();
                        controller.moveToken(tokenId);
                      },
                      onAnimatingChanged: (v) {
                        if (mounted) {
                          setState(() => _boardAnimating = v);
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: _gap),
              _buildPanelRow(gameState, controller, settings,
                  const [bottomLeft, bottomRight]),
              const SizedBox(height: 2),
            ],
          ),
        ),
      ),
    );
  }

  /// Two panel slots for one board row, in left-to-right order.
  Widget _buildPanelRow(
    GameState gameState,
    GameController controller,
    GameSettings settings,
    List<LudoColor> slotColors,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: Row(
        children: [
          for (int i = 0; i < slotColors.length; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: _slot(gameState, controller, settings, slotColors[i]),
            ),
          ],
        ],
      ),
    );
  }

  /// The panel for a base colour, or nothing when that colour isn't in play
  /// (e.g. 2-player games leave the other two slots empty).
  Widget _slot(
    GameState gameState,
    GameController controller,
    GameSettings settings,
    LudoColor color,
  ) {
    int index = gameState.players.indexWhere((p) => p.color == color);
    if (index == -1) return const SizedBox.shrink();
    final player = gameState.players[index];
    final isActive = index == gameState.currentPlayerIndex &&
        player.finishRank == null;
    final singleMovable = gameState.mustSelectToken &&
        gameState.movableTokenIds.length == 1;
    final canRoll = isActive &&
        (gameState.canRollDice || singleMovable) &&
        !_boardAnimating &&
        !_passFreeze;

    // §A5: the active panel shows the live roll; everyone else shows their
    // own last roll, or the neutral blank face before their first roll.
    final int? diceValue = isActive
        ? gameState.currentDiceRoll
        : (index < gameState.lastRolls.length
            ? gameState.lastRolls[index]
            : null);

    Player? partner;
    if (gameState.teamMode) {
      for (final p in gameState.players) {
        if (p.teamId == player.teamId && p.id != player.id) {
          partner = p;
        }
      }
    }

    return PlayerPanel(
      player: player,
      playerIndex: index,
      isActive: isActive,
      diceValue: diceValue,
      canRoll: canRoll,
      onRoll: () => _primaryAction(gameState, controller),
      isDark: widget.isDark,
      teamMode: gameState.teamMode,
      partner: partner,
      timeScale: settings.timeScale,
    );
  }

  /// Slim top bar (§8): back, sound, pause menu.
  Widget _buildTopBar(GameState gameState) {
    final fg = widget.isDark ? Colors.white : const Color(0xFF0F172A);

    Widget roundButton(IconData icon, String tooltip, VoidCallback onTap) {
      return Tooltip(
        message: tooltip,
        child: Material(
          color: widget.isDark
              ? Colors.white.withOpacity(0.07)
              : Colors.white.withOpacity(0.85),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(icon, size: 19, color: fg),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: Row(
        children: [
          roundButton(Icons.arrow_back_ios_new_rounded,
              'Quit to home', _confirmExit),
          const SizedBox(width: 6),
          const Text(
            'LUDU',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              height: 1.0,
            ),
          ),
          const Spacer(),
          // Compact turn pill: active emblem + name (never truncated away).
          Flexible(child: _buildTurnPill(gameState, fg)),
          const Spacer(),
          roundButton(
            _isMuted
                ? Icons.volume_off_rounded
                : Icons.volume_up_rounded,
            _isMuted ? 'Unmute Sound' : 'Mute Sound',
            _toggleMute,
          ),
          const SizedBox(width: 5),
          roundButton(Icons.pause_rounded, 'Pause menu', _openPauseMenu),
        ],
      ),
    );
  }

  Widget _buildTurnPill(GameState gameState, Color fg) {
    final me = gameState.currentPlayer;
    final label = _passFreeze
        ? 'Passing…'
        : '${me.color.emblemGlyph} ${me.name}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: me.color.primary.withOpacity(
            widget.isDark ? 0.28 : 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: me.color.primary.withOpacity(0.8), width: 1),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: fg,
        ),
      ),
    );
  }
}

class _PauseAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool danger;
  final VoidCallback onTap;

  const _PauseAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon,
          color: danger ? const Color(0xFFE63946) : null),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: danger ? const Color(0xFFE63946) : null,
        ),
      ),
      onTap: onTap,
    );
  }
}
