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
import '../widgets/dice_widget.dart';
import 'victory_screen.dart';

/// Full-board game screen: no side boxes, the 15×15 grid takes the whole
/// play area. A slim top bar, one floating grand dice docked at the active
/// player's corner, and a compact turn dock at the bottom.
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
  static const double _dockHeight = 76.0;
  static const double _gap = 6.0;
  static const double _boardMargin = 4.0;

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

    final activeColor = gameState.currentPlayer.color;

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
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _boardMargin),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: LudoBoard(
                            gameState: gameState,
                            onTokenSelected: (tokenId) =>
                                controller.moveToken(tokenId),
                            onRollDice: () => controller.rollDice(),
                            onAnimatingChanged: (v) =>
                                setState(() => _boardAnimating = v),
                          ),
                        ),
                        _buildCornerDice(gameState, controller, activeColor),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: _gap),
                SizedBox(
                  height: _dockHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: _buildTurnDock(gameState, controller, activeColor),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Grand dice floating over the active player's corner of the board.
  /// Red = top-left, Green = top-right, Yellow = bottom-right,
  /// Blue = bottom-left.
  Widget _buildCornerDice(
    GameState gameState,
    GameController controller,
    LudoColor activeColor,
  ) {
    double? left;
    double? top;
    double? right;
    double? bottom;
    switch (activeColor) {
      case LudoColor.red:
        left = 4;
        top = 4;
        break;
      case LudoColor.green:
        right = 4;
        top = 4;
        break;
      case LudoColor.yellow:
        right = 4;
        bottom = 4;
        break;
      case LudoColor.blue:
        left = 4;
        bottom = 4;
        break;
    }
    final idleFace = (gameState.currentPlayerIndex + 1).clamp(1, 6);
    final singleMovable = gameState.mustSelectToken &&
        gameState.movableTokenIds.length == 1;
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      child: DiceWidget(
        value: gameState.currentDiceRoll ?? idleFace,
        isRolling: gameState.isRolling,
        canRoll:
            (gameState.canRollDice || singleMovable) && !_boardAnimating,
        activeColor: activeColor,
        size: 96,
        onRoll: () => _primaryAction(gameState, controller),
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

    // Narrow phones can't fit the mode chip next to 4 action buttons —
    // the turn dock already shows the mode, so hide the chip there.
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

  /// Compact turn dock: active orb avatar, name + team, home progress, and
  /// one big ROLL pill. The whole dock is tappable.
  Widget _buildTurnDock(
    GameState gameState,
    GameController controller,
    LudoColor activeColor,
  ) {
    final me = gameState.currentPlayer;
    final canAct = (gameState.canRollDice ||
            (gameState.mustSelectToken &&
                gameState.movableTokenIds.length == 1)) &&
        !_boardAnimating;

    final String actionText;
    if (_boardAnimating) {
      actionText = 'MOVING…';
    } else if (gameState.canRollDice) {
      actionText = 'TAP TO ROLL';
    } else if (gameState.mustSelectToken) {
      actionText = gameState.movableTokenIds.length == 1
          ? 'TAP TO MOVE'
          : 'PICK A GLOWING ${me.color.emblemGlyph}';
    } else {
      actionText = '…';
    }

    final teamSuffix =
        gameState.teamMode ? ' • ${Player.teamName(me.teamId)}' : '';

    return GestureDetector(
      onTap: () => _primaryAction(gameState, controller),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.alphaBlend(
                activeColor.primary.withOpacity(widget.isDark ? 0.32 : 0.20),
                widget.isDark ? const Color(0xFF16203A) : Colors.white,
              ),
              Color.alphaBlend(
                activeColor.primary.withOpacity(widget.isDark ? 0.16 : 0.08),
                widget.isDark ? const Color(0xFF111A2E) : const Color(0xFFFDFDFB),
              ),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: activeColor.lightGlow.withOpacity(canAct ? 0.9 : 0.35),
            width: canAct ? 2.0 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: activeColor.primary.withOpacity(widget.isDark ? 0.35 : 0.20),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            PinAvatar(color: me.color, size: 46, isDark: widget.isDark),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${me.color.emblemGlyph} ${me.name}$teamSuffix',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildProgressDots(me, activeColor),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _buildRollPill(actionText, activeColor, canAct),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressDots(Player me, LudoColor color) {
    // 4 segments: grey = base, color = out, gold star = home.
    return Row(
      children: [
        ...me.tokens.map((t) {
          Color fill;
          if (t.isHome) {
            fill = const Color(0xFFF2C14E);
          } else if (t.isInBase) {
            fill = widget.isDark
                ? const Color(0xFF39465E)
                : const Color(0xFFC8CFD9);
          } else {
            fill = color.primary;
          }
          return Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              height: 9,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          );
        }),
        const SizedBox(width: 6),
        Text(
          '${me.tokensHomeCount}/4',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: widget.isDark ? Colors.white70 : const Color(0xFF475569),
          ),
        ),
      ],
    );
  }

  Widget _buildRollPill(String text, LudoColor color, bool canAct) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: canAct
              ? [color.lightGlow, color.primary]
              : [Colors.grey.shade400, Colors.grey.shade500],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          if (canAct)
            BoxShadow(
              color: color.primary.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
          shadows: [Shadow(color: Colors.black45, blurRadius: 3)],
        ),
      ),
    );
  }
}
