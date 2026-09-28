import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/game_state.dart';
import '../../models/ludo_color.dart';
import '../../models/player.dart';
import '../../services/audio_service.dart';
import '../../services/haptics_service.dart';
import '../../state/game_controller.dart';
import '../board/ludo_board.dart';
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

  // Layout constants for the adaptive, edge-to-edge play area.
  static const double _topBarHeight = 48.0;
  static const double _statusHeight = 56.0;
  static const double _gap = 7.0;
  static const double _minCardHeight = 100.0;
  static const double _maxCardHeight = 140.0;

  void _toggleMute() {
    HapticsService.light();
    setState(() {
      AudioService.toggleMute();
      _isMuted = AudioService.isMuted;
    });
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

  /// Rich ambient background so the board and cards sit on something premium
  /// instead of a flat colour.
  Widget _buildBackdrop({
    required GameState gameState,
    required GameController controller,
    required LudoColor activeColor,
    required Player? redPlayer,
    required Player? greenPlayer,
    required Player? yellowPlayer,
    required Player? bluePlayer,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: widget.isDark
              ? const [Color(0xFF0C1424), Color(0xFF070B14), Color(0xFF0B1220)]
              : const [Color(0xFFF6F1E8), Color(0xFFEDE7DC), Color(0xFFF3EDE3)],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardHeight = _computeCardHeight(constraints);

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
                ),
                const SizedBox(height: _gap),

                // The board takes every remaining pixel and is free to grow
                // up to the full screen width.
                Expanded(
                  child: LudoBoard(
                    gameState: gameState,
                    onTokenSelected: (tokenId) => controller.moveToken(tokenId),
                    onRollDice: () => controller.rollDice(),
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
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Spends whatever vertical space is left over on making the player cards
  /// taller, so the board stays full-width while the cards grow.
  double _computeCardHeight(BoxConstraints constraints) {
    final fixed = _topBarHeight + _statusHeight + (_gap * 4);
    final slack = constraints.maxHeight - fixed - constraints.maxWidth;
    return (slack / 2).clamp(_minCardHeight, _maxCardHeight).toDouble();
  }

  Widget _buildPlayerRow({
    required GameState gameState,
    required GameController controller,
    required Player? left,
    required Player? right,
    required double cardHeight,
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
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          Expanded(child: buildCard(left)),
          const SizedBox(width: _gap),
          Expanded(child: buildCard(right)),
        ],
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

  Widget _buildStatusBanner(
    GameState gameState,
    LudoColor activeColor,
    GameController controller,
  ) {
    final canRoll = gameState.canRollDice;
    final mustSelectToken = gameState.mustSelectToken;

    final String bannerText;
    if (canRoll) {
      bannerText = 'TAP DICE TO ROLL';
    } else if (mustSelectToken) {
      bannerText = gameState.movableTokenIds.length == 1
          ? 'SELECT TOKEN TO MOVE (or tap dice)'
          : 'SELECT TOKEN TO MOVE';
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
