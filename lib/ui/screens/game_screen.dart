import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game_state.dart';
import '../../models/ludo_color.dart';
import '../../services/haptics_service.dart';
import '../../state/game_controller.dart';
import '../board/ludo_board.dart';
import '../widgets/dice_widget.dart';
import '../widgets/turn_indicator_banner.dart';
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

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);

    // If game is finished, present Victory screen
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('LUDU'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Exit to Setup',
          onPressed: _confirmExit,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Restart Match',
            onPressed: _confirmRestart,
          ),
          IconButton(
            icon: Icon(widget.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            tooltip: 'Toggle Theme',
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            children: [
              // Top Turn Indicator Banner
              TurnIndicatorBanner(gameState: gameState),
              const SizedBox(height: 12),

              // Responsive Ludo Board
              Expanded(
                child: LudoBoard(
                  gameState: gameState,
                  onTokenSelected: (tokenId) {
                    controller.moveToken(tokenId);
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Bottom Dice & Action Controls
              _buildBottomControls(gameState, controller, activeColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls(
    GameState gameState,
    GameController controller,
    LudoColor activeColor,
  ) {
    final canRoll = gameState.canRollDice;
    final mustSelectToken = gameState.mustSelectToken;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF141C2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.isDark ? const Color(0xFF283650) : const Color(0xFFE2DDD2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Instructions & Status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  canRoll
                      ? 'TAP DICE TO ROLL'
                      : (mustSelectToken ? 'SELECT TOKEN TO MOVE' : 'WAITING...'),
                  style: TextStyle(
                    color: canRoll ? activeColor.lightGlow : (widget.isDark ? Colors.white70 : Colors.black87),
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  canRoll
                      ? 'Pure Random.secure() dice roll'
                      : (mustSelectToken
                          ? (gameState.movableTokenIds.length == 1
                              ? 'Tap token #${gameState.movableTokenIds.first + 1} or tap dice to move'
                              : 'Tap one of the highlighted tokens')
                          : gameState.statusMessage),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // 3D Animated Tumbling Dice
          GestureDetector(
            onTap: () {
              if (canRoll) {
                controller.rollDice();
              } else if (mustSelectToken && gameState.movableTokenIds.length == 1) {
                // Quick tap on dice to auto-execute single valid move
                controller.moveToken(gameState.movableTokenIds.first);
              }
            },
            child: DiceWidget(
              value: gameState.currentDiceRoll,
              isRolling: gameState.isRolling,
              canRoll: canRoll,
              activeColor: activeColor,
              onRoll: () {
                controller.rollDice();
              },
            ),
          ),
        ],
      ),
    );
  }
}
