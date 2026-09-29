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
import '../widgets/dice_widget.dart';
import '../widgets/player_box_widget.dart';
import 'victory_screen.dart';

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

  // Big-board layout: minimal margins so the 15×15 grid fills ~98% width.
  static const double _topBarHeight = 44.0;
  static const double _statusHeight = 52.0;
  static const double _gap = 6.0;
  static const double _arrowSlot = 30.0;
  static const double _boardMargin = 6.0;
  static const double _minCardHeight = 88.0;
  static const double _maxCardHeight = 112.0;

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
              final currentPlayers = ref.read(gameControllerProvider).players;
              ref.read(gameControllerProvider.notifier).startNewGame(
                    playerCount: currentPlayers.length,
                    playerNames: currentPlayers.map((p) => p.name).toList(),
                    playerColors: currentPlayers.map((p) => p.color).toList(),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE9C46A)),
            child: const Text('Exit', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Player? _getPlayer(GameState state, LudoColor color) {
    final idx = state.players.indexWhere((p) => p.color == color);
    return (idx != -1) ? state.players[idx] : null;
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    // If game is finished, show Victory screen
    if (gameState.phase == GamePhase.finished) {
      return VictoryScreen(
        gameState: gameState,
        onPlayAgain: () {
          final currentPlayers = gameState.players;
          controller.startNewGame(
            playerCount: currentPlayers.length,
            playerNames: currentPlayers.map((p) => p.name).toList(),
            playerColors: currentPlayers.map((p) => p.color).toList(),
          );
        },
        onNewGame: widget.onNewGame,
      );
    }

    final currentPlayer = gameState.currentPlayer;
    final activeColor = currentPlayer.color;

    final redPlayer = _getPlayer(gameState, LudoColor.red);
    final greenPlayer = _getPlayer(gameState, LudoColor.green);
    final yellowPlayer = _getPlayer(gameState, LudoColor.yellow);
    final bluePlayer = _getPlayer(gameState, LudoColor.blue);

    return Scaffold(
      backgroundColor: widget.isDark ? const Color(0xFF070B14) : const Color(0xFFEDE7DC),
      body: _buildBackdrop(
        gameState: gameState,
        controller: controller,
        activeColor: activeColor,
        redPlayer: redPlayer,
        greenPlayer: greenPlayer,
        yellowPlayer: yellowPlayer,
        bluePlayer: bluePlayer,
      ),
    );
  }

  /// Ambient themed backdrop so the board floats on something designed rather
  /// than a flat colour.
  Widget _buildBackdrop({
    required GameState gameState,
    required GameController controller,
    required LudoColor activeColor,
    required Player? redPlayer,
    required Player? greenPlayer,
    required Player? yellowPlayer,
    required Player? bluePlayer,
  }) {
    return Stack(
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardHeight = _computeCardHeight(constraints);
              final topRowActive = currentPlayerIndexIsTopRow(gameState);

              return Column(
                children: [
                  SizedBox(height: _topBarHeight, child: _buildTopBar()),
                  const SizedBox(height: _gap),
                  _buildPlayerRow(
                    gameState: gameState,
                    controller: controller,
                    left: redPlayer,
                    right: greenPlayer,
                    cardHeight: cardHeight,
                    showArrow: topRowActive,
                    arrowRight: false,
                  ),
                  const SizedBox(height: _gap),

                  // Big board: fills almost the full width with minimal
                  // margins; grand dice floats near the active corner.
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: _boardMargin),
                      child: LayoutBuilder(
                        builder: (context, boardConstraints) {
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned.fill(
                                child: LudoBoard(
                                  gameState: gameState,
                                  onTokenSelected: (tokenId) =>
                                      controller.moveToken(tokenId),
                                  onRollDice: () => controller.rollDice(),
                                ),
                              ),
                              // Grand dice docked near the current player's
                              // corner so up to 4 players can reach it.
                              _buildCornerDice(
                                  gameState, controller, activeColor),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: _gap),
                  SizedBox(
                    height: _statusHeight,
                    child: _buildStatusBanner(gameState, activeColor, controller),
                  ),
                  const SizedBox(height: _gap),
                  _buildPlayerRow(
                    gameState: gameState,
                    controller: controller,
                    left: bluePlayer,
                    right: yellowPlayer,
                    cardHeight: cardHeight,
                    showArrow: !topRowActive,
                    arrowRight: true,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// Play runs right-to-left along the top row and left-to-right along the
  /// bottom, so the turn arrow sits on whichever row is active.
  bool currentPlayerIndexIsTopRow(GameState gameState) {
    final color = gameState.currentPlayer.color;
    return color == LudoColor.red || color == LudoColor.green;
  }

  /// Spends whatever vertical space is left over on making the player cards
  /// taller. The board is width-bound once its margin is taken off, so spare
  /// vertical space is free.
  double _computeCardHeight(BoxConstraints constraints) {
    final fixed = _topBarHeight + _statusHeight + (_gap * 4);
    final usable = constraints.maxWidth - (_boardMargin * 2);
    final slack = constraints.maxHeight - fixed - usable;
    return (slack / 2).clamp(_minCardHeight, _maxCardHeight).toDouble();
  }

  Widget _buildPlayerRow({
    required GameState gameState,
    required GameController controller,
    required Player? left,
    required Player? right,
    required double cardHeight,
    required bool showArrow,
    required bool arrowRight,
  }) {
    Widget buildCard(Player? player) {
      if (player == null) return const SizedBox.shrink();
      final isTurn = gameState.currentPlayer.color == player.color;
      return PlayerBoxWidget(
        key: ValueKey('card_${player.color.name}'),
        player: player,
        cardHeight: cardHeight,
        isCurrentTurn: isTurn,
        canRoll: isTurn && gameState.canRollDice,
        mustSelectToken: isTurn && gameState.mustSelectToken,
        showDiceRoll: isTurn ? gameState.currentDiceRoll : null,
        isRolling: gameState.isRolling,
        onRoll: () => controller.rollDice(),
        onAutoMoveSingle: (gameState.mustSelectToken && gameState.movableTokenIds.length == 1)
            ? () => controller.moveToken(gameState.movableTokenIds.first)
            : null,
        isDark: widget.isDark,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Row(
        children: [
          Expanded(child: buildCard(left)),
          SizedBox(
            width: _arrowSlot,
            child: Center(
              child: AnimatedOpacity(
                opacity: showArrow ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: _buildTurnArrow(arrowRight),
              ),
            ),
          ),
          Expanded(child: buildCard(right)),
        ],
      ),
    );
  }

  Widget _buildTurnArrow(bool pointsRight) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: const Color(0xFFFFA726),
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFA726).withOpacity(0.55),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        pointsRight ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
        size: 15,
        color: Colors.white,
      ),
    );
  }

  Widget _buildTopBar() {
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
              width: 40,
              height: 40,
              child: Icon(icon, size: 21, color: fg),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          roundButton(Icons.arrow_back_ios_new_rounded, 'Exit to Setup', _confirmExit),
          const SizedBox(width: 10),
          const Text(
            'LUDU',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 3.0,
              height: 1.0,
            ),
          ),
          const Spacer(),
          roundButton(
            _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            _isMuted ? 'Unmute Sound' : 'Mute Sound',
            _toggleMute,
          ),
          const SizedBox(width: 6),
          roundButton(
            _vibrationOn ? Icons.vibration_rounded : Icons.mobile_off_rounded,
            _vibrationOn ? 'Disable Vibration' : 'Enable Vibration',
            _toggleVibration,
          ),
          const SizedBox(width: 6),
          roundButton(
            widget.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            'Toggle Theme',
            widget.onToggleTheme,
          ),
          const SizedBox(width: 6),
          roundButton(Icons.refresh_rounded, 'Restart Match', _confirmRestart),
        ],
      ),
    );
  }

  /// Grand 84dp dice floating near the active player's corner of the board.
  /// Red = top-left, Green = top-right, Yellow = bottom-right,
  /// Blue = bottom-left. Large tap area prevents mis-taps in pass-and-play.
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
        left = 2;
        top = 2;
        break;
      case LudoColor.green:
        right = 2;
        top = 2;
        break;
      case LudoColor.yellow:
        right = 2;
        bottom = 2;
        break;
      case LudoColor.blue:
        left = 2;
        bottom = 2;
        break;
    }
    // Show the live roll if present, else the player's id-based idle face.
    final idleFace =
        (gameState.currentPlayerIndex + 1).clamp(1, 6);
    // Corner dice doubles as a big "confirm single move" button so
    // mis-taps are impossible: one large target near your own base.
    final bool singleMovable = gameState.mustSelectToken &&
        gameState.movableTokenIds.length == 1;
    return Positioned(
      left: left,
      top: top,
      right: right,
      bottom: bottom,
      child: DiceWidget(
        value: gameState.currentDiceRoll ?? idleFace,
        isRolling: gameState.isRolling,
        canRoll: gameState.canRollDice || singleMovable,
        activeColor: activeColor,
        size: 84,
        onRoll: () {
          if (gameState.canRollDice) {
            controller.rollDice();
          } else if (singleMovable) {
            controller.moveToken(gameState.movableTokenIds.first);
          }
        },
      ),
    );
  }

  Widget _buildStatusBanner(
    GameState gameState,
    LudoColor activeColor,
    GameController controller,
  ) {
    final canRoll = gameState.canRollDice;
    final mustSelectToken = gameState.mustSelectToken;

    final String bannerText;
    final me = gameState.currentPlayer;
    final prefix = '${me.color.emblemGlyph} ${me.name} — ';
    if (canRoll) {
      bannerText = '$prefix TAP DICE TO ROLL';
    } else if (mustSelectToken) {
      bannerText = gameState.movableTokenIds.length == 1
          ? '$prefix TAP YOUR GLOWING TOKEN'
          : '$prefix SELECT A GLOWING TOKEN';
    } else {
      bannerText = gameState.statusMessage;
    }

    final isInteractive = canRoll || (mustSelectToken && gameState.movableTokenIds.length == 1);

    return GestureDetector(
      onTap: () {
        if (canRoll) {
          controller.rollDice();
        } else if (mustSelectToken && gameState.movableTokenIds.length == 1) {
          controller.moveToken(gameState.movableTokenIds.first);
        }
      },
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.alphaBlend(
                activeColor.primary.withOpacity(widget.isDark ? 0.30 : 0.18),
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
            color: activeColor.lightGlow.withOpacity(isInteractive ? 0.85 : 0.35),
            width: isInteractive ? 1.8 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: activeColor.primary.withOpacity(widget.isDark ? 0.32 : 0.18),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: activeColor.lightGlow,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: activeColor.lightGlow.withOpacity(0.8), blurRadius: 8),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                bannerText,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 14,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
