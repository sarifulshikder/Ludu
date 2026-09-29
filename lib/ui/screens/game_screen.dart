import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game_state.dart';
import '../../models/ludo_color.dart';
import '../../models/player.dart';
import '../../services/audio_service.dart';
import '../../services/haptics_service.dart';
import '../../state/game_controller.dart';
import '../board/board_backdrop.dart';
import '../board/ludo_board.dart';
import '../board/token_widget.dart';
import 'victory_screen.dart';

/// Full edge-to-edge board: the 15×15 grid spans the full screen width.
/// Player 1 top-left, Player 2 top-right, Player 3 bottom-left, Player 4
/// bottom-right — each corner box holds its 4 tokens with that player's
/// own dice in the middle of the pieces. No bottom roll box: tap your
/// dice to roll.
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
  bool _vibrationOn = HapticsService.isEnabled;
  bool _boardAnimating = false;

  static const double _topBarHeight = 44.0;
  static const double _gap = 6.0;

  void _toggleMute() {
    HapticsService.light();
    setState(() {
      AudioService.toggleMute();
      _isMuted = AudioService.isMuted;
    });
  }

  void _toggleVibration() {
    setState(() {
      _vibrationOn = !_vibrationOn;
      HapticsService.setEnabled(_vibrationOn);
    });
    HapticsService.light();
  }

  void _confirmRestart() {
    HapticsService.light();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF141D2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Restart Game?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to restart the current match?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              final st = ref.read(gameControllerProvider);
              ref.read(gameControllerProvider.notifier).startNewGame(
                    playerCount: st.players.length,
                    playerNames: st.players.map((p) => p.name).toList(),
                    playerColors: st.players.map((p) => p.color).toList(),
                    teamMode: st.teamMode,
                  );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE63946)),
            child: const Text('Restart', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmExit() {
    HapticsService.light();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.isDark ? const Color(0xFF141D2E) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Exit to Setup?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Leave current game and return to player setup?'),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF2C14E)),
            child: const Text('Exit', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  /// The one big tap target: rolls the dice, or confirms a forced single
  /// move. Disabled while a hop animation is running so a tap can never
  /// act on a stale board position.
  void _primaryAction(GameState gameState, GameController controller) {
    if (_boardAnimating || gameState.isMovingToken) return;
    if (gameState.canRollDice) {
      controller.rollDice();
    } else if (gameState.mustSelectToken &&
        gameState.movableTokenIds.length == 1) {
      controller.moveToken(gameState.movableTokenIds.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    if (gameState.phase == GamePhase.finished) {
      return VictoryScreen(
        gameState: gameState,
        onPlayAgain: () {
          controller.startNewGame(
            playerCount: gameState.players.length,
            playerNames: gameState.players.map((p) => p.name).toList(),
            playerColors: gameState.players.map((p) => p.color).toList(),
            teamMode: gameState.teamMode,
          );
        },
        onNewGame: widget.onNewGame,
      );
    }

    return Scaffold(
      backgroundColor: widget.isDark ? const Color(0xFF070B14) : const Color(0xFFEDE7DC),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: widget.isDark
                      ? const [Color(0xFF0B1A33), Color(0xFF060C18), Color(0xFF0A1526)]
                      : const [Color(0xFFEAF1F8), Color(0xFFDDE7F1), Color(0xFFE6EEF6)],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: BoardBackdropPainter(
                isDark: widget.isDark,
                accent: widget.isDark
                    ? const Color(0xFF4DA3FF)
                    : const Color(0xFF1E5FA8),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                SizedBox(height: _topBarHeight, child: _buildTopBar(gameState)),
                const SizedBox(height: _gap),
                // Edge-to-edge: no horizontal padding, the board spans the
                // full screen width. Leftover vertical space stays backdrop.
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1.0,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                        Positioned.fill(
                          child: LudoBoard(
                            gameState: gameState,
                            onTokenSelected: (tokenId) =>
                                controller.moveToken(tokenId),
                            onRollDice: () => controller.rollDice(),
                            onDiceTap: () =>
                                _primaryAction(gameState, controller),
                            onAnimatingChanged: (v) =>
                                setState(() => _boardAnimating = v),
                          ),
                        ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: _gap),
                // Plain hint text only — not a box, not tappable.
                // The center dice is the single roll control.
                SizedBox(
                  height: 24,
                  child: Center(child: _buildStatusText(gameState)),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Plain hint line under the board — text only, no box, not tappable.
  Widget _buildStatusText(GameState gameState) {
    final me = gameState.currentPlayer;
    final String text;
    if (_boardAnimating || gameState.isMovingToken) {
      text = 'MOVING…';
    } else if (gameState.canRollDice) {
      text = 'TAP THE DICE TO ROLL';
    } else if (gameState.mustSelectToken) {
      text = gameState.movableTokenIds.length == 1
          ? 'TAP THE DICE TO MOVE'
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

  Widget _buildTopBar(GameState gameState) {
    final fg = widget.isDark ? Colors.white : const Color(0xFF0F172A);

    Widget roundButton(IconData icon, String tooltip, VoidCallback onTap) {
      return Tooltip(
        message: tooltip,
        child: Material(
          color: widget.isDark
              ? Colors.white.withOpacity(0.07)
              : Colors.white.withOpacity(0.75),
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

    // The bottom roll box is gone, so the top bar carries the turn chip:
    // active orb avatar + name (+ team). Mode chip only fits wide screens.
    final me = gameState.currentPlayer;
    final turnLabel = gameState.teamMode
        ? '${me.name} • ${Player.teamName(me.teamId)}'
        : me.name;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showChip = constraints.maxWidth >= 430;
          final modeLabel = gameState.teamMode ? 'TEAM 2v2' : 'SOLO';
          return Row(
            children: [
              roundButton(Icons.arrow_back_ios_new_rounded, 'Exit to Setup',
                  _confirmExit),
              const SizedBox(width: 6),
              const Text(
                'LUDU',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: me.color.primary.withOpacity(
                        widget.isDark ? 0.25 : 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: me.color.lightGlow.withOpacity(0.7), width: 1),
                  ),
                  // Collapses to avatar-only when the bar is crowded so
                  // the Row can never overflow on narrow phones.
                  child: LayoutBuilder(
                    builder: (context, chipConstraints) {
                      final showName = chipConstraints.maxWidth >= 60;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          PinAvatar(
                              color: me.color,
                              size: 22,
                              isDark: widget.isDark),
                          if (showName) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                '${me.color.emblemGlyph} $turnLabel',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: fg,
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
              if (showChip) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2C14E).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFFF2C14E), width: 1),
                  ),
                  child: Text(
                    modeLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                      color: Color(0xFFF2C14E),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              roundButton(
                _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                _isMuted ? 'Unmute Sound' : 'Mute Sound',
                _toggleMute,
              ),
              const SizedBox(width: 4),
              roundButton(
                _vibrationOn
                    ? Icons.vibration_rounded
                    : Icons.mobile_off_rounded,
                _vibrationOn ? 'Disable Vibration' : 'Enable Vibration',
                _toggleVibration,
              ),
              const SizedBox(width: 4),
              roundButton(
                widget.isDark
                    ? Icons.light_mode_rounded
                    : Icons.dark_mode_rounded,
                'Toggle Theme',
                widget.onToggleTheme,
              ),
              const SizedBox(width: 4),
              roundButton(
                  Icons.refresh_rounded, 'Restart Match', _confirmRestart),
            ],
          );
        },
      ),
    );
  }

}
