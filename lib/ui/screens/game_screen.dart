import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/game_state.dart';
import '../../models/ludo_color.dart';
import '../../services/audio_service.dart';
import '../../services/haptics_service.dart';
import '../../state/game_controller.dart';
import '../../state/settings_controller.dart';
import '../board/ludo_board.dart';
import '../widgets/player_panel.dart';
import 'ranking_screen.dart';
import 'settings_sheet.dart';

/// Tall-board game screen (§8), top to bottom:
///
/// slim top bar (back, sound, settings) → Player 1 & 2 panels with big
/// dice → tall edge-to-edge board → Player 3 & 4 panels with big dice.
///
/// Only the active player's dice is highlighted and tappable; their panel
/// and base glow with a "Your turn" label. The hop animation, auto-move
/// and auto-pass beats are coordinated here so taps never act on stale
/// state.
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

  static const double _topBarHeight = 44.0;
  static const double _gap = 8.0;

  @override
  void dispose() {
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

  void _confirmRestart() {
    HapticsService.light();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
            widget.isDark ? const Color(0xFF141D2E) : Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        );
  }

  void _confirmExit() {
    HapticsService.light();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor:
            widget.isDark ? const Color(0xFF141D2E) : Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Exit to Setup?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
            'Leave the game? Your progress is saved and can be resumed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onNewGame();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF2C14E)),
            child:
                const Text('Exit', style: TextStyle(color: Colors.black)),
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
      _freezeTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _passFreeze = false);
      });
      return;
    }
    final autoMove =
        ref.read(settingsControllerProvider).autoMove;
    if (autoMove && state.mustSelectToken) {
      final idx = state.currentPlayerIndex;
      final roll = state.currentDiceRoll!;
      final only = state.movableTokenIds.length == 1
          ? state.movableTokenIds.first
          : null;
      if (only == null) return;
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
                  height: _topBarHeight, child: _buildTopBar()),
              const SizedBox(height: _gap),
              _buildPanelRow(gameState, controller, [0, 1]),
              const SizedBox(height: _gap),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    // Tall board: 15 columns × 1:1.33 cells (§8).
                    aspectRatio: 15 / (15 * 1.33),
                    child: LudoBoard(
                      gameState: gameState,
                      onTokenSelected: (tokenId) {
                        if (_boardAnimating || _passFreeze) return;
                        _autoMoveTimer?.cancel();
                        controller.moveToken(tokenId);
                      },
                      onAnimatingChanged: (v) =>
                          setState(() => _boardAnimating = v),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: _gap),
              _buildBottomRow(gameState, controller),
              const SizedBox(height: _gap),
              SizedBox(
                height: 22,
                child: Center(child: _buildStatusText(gameState)),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPanelRow(
      GameState gameState, GameController controller, List<int> indices) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          for (int i = 0; i < indices.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _buildPanel(
                  gameState, controller, indices[i]),
            ),
          ],
        ],
      ),
    );
  }

  /// Bottom row: remaining player panels, or a slim status card when the
  /// match has only two players.
  Widget _buildBottomRow(GameState gameState, GameController controller) {
    final rest = List.generate(
        gameState.players.length - 2, (i) => i + 2);
    if (rest.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isDark
                ? const Color(0xFF141D2E)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.isDark
                  ? const Color(0xFF283650)
                  : const Color(0xFFD6CEBD),
            ),
          ),
          child: Text(
            gameState.statusMessage,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: widget.isDark
                  ? Colors.white70
                  : const Color(0xFF64748B),
            ),
          ),
        ),
      );
    }
    return _buildPanelRow(gameState, controller, rest);
  }

  Widget _buildPanel(
      GameState gameState, GameController controller, int index) {
    final player = gameState.players[index];
    final isActive = index == gameState.currentPlayerIndex &&
        player.finishRank == null;
    final singleMovable = gameState.mustSelectToken &&
        gameState.movableTokenIds.length == 1;
    final canRoll = isActive &&
        (gameState.canRollDice || singleMovable) &&
        !_boardAnimating &&
        !_passFreeze;
    return PlayerPanel(
      player: player,
      playerIndex: index,
      isActive: isActive,
      diceValue: gameState.currentDiceRoll,
      canRoll: canRoll,
      onRoll: () => _primaryAction(gameState, controller),
      isDark: widget.isDark,
    );
  }

  /// Plain hint line — text only, not tappable. The panel dice are the
  /// single roll control.
  Widget _buildStatusText(GameState gameState) {
    final me = gameState.currentPlayer;
    final String text;
    if (_boardAnimating) {
      text = 'MOVING…';
    } else if (_passFreeze) {
      text = 'NO MOVES — PASSING…';
    } else if (gameState.canRollDice) {
      text = 'TAP YOUR DICE TO ROLL';
    } else if (gameState.mustSelectToken) {
      text = gameState.movableTokenIds.length == 1
          ? 'TAP YOUR DICE TO MOVE'
          : 'TAP A GLOWING ${me.color.emblemGlyph} TO MOVE';
    } else {
      text = '';
    }
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: widget.isDark ? Colors.white70 : const Color(0xFF475569),
      ),
    );
  }

  /// Slim top bar (§8): back, sound, settings.
  Widget _buildTopBar() {
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
              width: 38,
              height: 38,
              child: Icon(icon, size: 20, color: fg),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          roundButton(Icons.arrow_back_ios_new_rounded,
              'Exit to Setup', _confirmExit),
          const SizedBox(width: 8),
          const Text(
            'LUDU',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              height: 1.0,
            ),
          ),
          const Spacer(),
          roundButton(
            _isMuted
                ? Icons.volume_off_rounded
                : Icons.volume_up_rounded,
            _isMuted ? 'Unmute Sound' : 'Mute Sound',
            _toggleMute,
          ),
          const SizedBox(width: 6),
          roundButton(Icons.settings_rounded, 'Settings', _openSettings),
        ],
      ),
    );
  }
}
