import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/board_coordinates.dart';
import '../../models/game_state.dart';
import '../../models/ludo_color.dart';
import '../../models/player.dart';
import '../../models/token.dart';
import '../../services/audio_service.dart';
import '../../services/haptics_service.dart';
import 'board_painter.dart';
import 'token_widget.dart';

class LudoBoard extends StatefulWidget {
  final GameState gameState;
  final Function(int tokenId) onTokenSelected;
  final VoidCallback? onRollDice;

  const LudoBoard({
    super.key,
    required this.gameState,
    required this.onTokenSelected,
    this.onRollDice,
  });

  @override
  State<LudoBoard> createState() => _LudoBoardState();
}

class _LudoBoardState extends State<LudoBoard> {
  int? _animatingTokenKey;
  int? _animatingCurrentStep;
  Timer? _hopTimer;

  int _tokenKey(LudoColor color, int id) => color.index * 10 + id;

  void _startStepByStepMovement(Token token, int roll) {
    final startStep = token.step;
    final int finalStep = (startStep == -1) ? 0 : startStep + roll;
    final key = _tokenKey(token.color, token.id);

    setState(() {
      _animatingTokenKey = key;
      _animatingCurrentStep = startStep;
    });

    if (startStep == -1) {
      // Direct hop from base to track entry tile
      _hopTimer?.cancel();
      AudioService.playTokenOut();
      _hopTimer = Timer(const Duration(milliseconds: 240), () {
        HapticsService.medium();
        setState(() {
          _animatingTokenKey = null;
          _animatingCurrentStep = null;
        });
        widget.onTokenSelected(token.id);
      });
      return;
    }

    // Step-by-step sequential hops
    int currentStep = startStep;
    const int stepDurationMs = 100;

    _hopTimer?.cancel();
    _hopTimer = Timer.periodic(const Duration(milliseconds: stepDurationMs), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      currentStep++;
      HapticsService.light();
      AudioService.playTokenStep();

      if (currentStep >= finalStep) {
        timer.cancel();
        setState(() {
          _animatingCurrentStep = finalStep;
        });

        // Small pause at landing tile then commit move
        Future.delayed(const Duration(milliseconds: 120), () {
          if (!mounted) return;
          setState(() {
            _animatingTokenKey = null;
            _animatingCurrentStep = null;
          });
          widget.onTokenSelected(token.id);
        });
      } else {
        setState(() {
          _animatingCurrentStep = currentStep;
        });
      }
    });
  }

  @override
  void dispose() {
    _hopTimer?.cancel();
    super.dispose();
  }

  void _handleBaseTap(LudoColor color) {
    if (widget.gameState.canRollDice &&
        widget.gameState.currentPlayer.color == color) {
      widget.onRollDice?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double boardDimension = min(constraints.maxWidth, constraints.maxHeight);
        final double tileSize = boardDimension / 15.0;
        // Pieces are deliberately chunky: they fill their tile on the track and
        // spill slightly into the yard in the home bases.
        final double trackTokenSize = tileSize * 0.98;
        final double baseTokenSize = tileSize * 1.04;

        return Center(
          child: Container(
            width: boardDimension,
            height: boardDimension,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.40),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Custom Canvas Board
                Positioned.fill(
                  child: CustomPaint(
                    painter: BoardPainter(isDark: isDark),
                  ),
                ),

                // Interactive tap detection over the 4 corner bases to roll dice
                if (widget.gameState.canRollDice) ...[
                  // Top-Left (Red)
                  Positioned(
                    left: 0,
                    top: 0,
                    width: tileSize * 6,
                    height: tileSize * 6,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => _handleBaseTap(LudoColor.red),
                    ),
                  ),
                  // Top-Right (Green)
                  Positioned(
                    right: 0,
                    top: 0,
                    width: tileSize * 6,
                    height: tileSize * 6,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => _handleBaseTap(LudoColor.green),
                    ),
                  ),
                  // Bottom-Right (Yellow)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    width: tileSize * 6,
                    height: tileSize * 6,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => _handleBaseTap(LudoColor.yellow),
                    ),
                  ),
                  // Bottom-Left (Blue)
                  Positioned(
                    left: 0,
                    bottom: 0,
                    width: tileSize * 6,
                    height: tileSize * 6,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () => _handleBaseTap(LudoColor.blue),
                    ),
                  ),
                ],

                // Tokens layer
                ..._buildAllTokens(boardDimension, tileSize, trackTokenSize, baseTokenSize),

                // Player names painted onto the yards, rotated per quadrant so
                // each one reads outward from the board.
                ..._buildYardLabels(tileSize),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildYardLabels(double tileSize) {
    final widgets = <Widget>[];

    void add(LudoColor color, double cx, double cy, int turns) {
      Player? player;
      for (final p in widget.gameState.players) {
        if (p.color == color) {
          player = p;
          break;
        }
      }
      if (player == null) return;

      final w = tileSize * 2.9;
      final h = tileSize * 0.66;

      widgets.add(
        Positioned(
          left: cx * tileSize - w / 2,
          top: cy * tileSize - h / 2,
          width: w,
          height: h,
          child: Transform.rotate(
            angle: turns * pi / 2,
            child: Center(
              child: Text(
                player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: tileSize * 0.40,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  shadows: const [
                    Shadow(
                      color: Color(0xCC000000),
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Clockwise around the board, each turned a further quarter turn.
    add(LudoColor.red, 0.42, 3.0, 1); // top-left yard, left edge
    add(LudoColor.green, 12.0, 0.42, 2); // top-right yard, top edge
    add(LudoColor.yellow, 14.58, 12.0, 3); // bottom-right yard, right edge
    add(LudoColor.blue, 3.0, 14.58, 0); // bottom-left yard, bottom edge

    return widgets;
  }

  List<Widget> _buildAllTokens(
    double boardDimension,
    double tileSize,
    double trackTokenSize,
    double baseTokenSize,
  ) {
    final List<Widget> tokenWidgets = [];

    // Group tokens by their rendered coordinate key
    final Map<String, List<Map<String, dynamic>>> positionBuckets = {};

    for (int pIdx = 0; pIdx < widget.gameState.players.length; pIdx++) {
      final player = widget.gameState.players[pIdx];
      final isCurrentPlayer = (pIdx == widget.gameState.currentPlayerIndex);

      for (final token in player.tokens) {
        final key = _tokenKey(token.color, token.id);
        final isMovingThis = (_animatingTokenKey == key);
        final effectiveStep = isMovingThis ? (_animatingCurrentStep ?? token.step) : token.step;

        final isMovable = isCurrentPlayer &&
            widget.gameState.mustSelectToken &&
            widget.gameState.movableTokenIds.contains(token.id) &&
            _animatingTokenKey == null;

        final boardPoint = BoardCoordinates.getTokenPosition(
          color: token.color,
          tokenId: token.id,
          step: effectiveStep,
        );

        final coordKey = '${boardPoint.row.toStringAsFixed(1)}_${boardPoint.col.toStringAsFixed(1)}';

        positionBuckets.putIfAbsent(coordKey, () => []).add({
          'token': token,
          'boardPoint': boardPoint,
          'isMovable': isMovable,
          'isAnimating': isMovingThis,
        });
      }
    }

    // Render tokens with offsets when multiple tokens occupy the same square
    for (final bucket in positionBuckets.values) {
      final count = bucket.length;

      for (int i = 0; i < count; i++) {
        final item = bucket[i];
        final Token token = item['token'];
        final BoardPoint pt = item['boardPoint'];
        final bool isMovable = item['isMovable'];
        final bool isAnimating = item['isAnimating'];

        final double currentTokenSize = token.isInBase ? baseTokenSize : trackTokenSize;
        // A pin is identified by its head, so the head is centred on the square
        // and the point hangs below it.
        final double headOffset = currentTokenSize * kTokenPinAspect * kTokenHeadOffset;

        Offset offset = Offset.zero;
        if (count > 1 && !token.isInBase) {
          final angle = (2 * pi / count) * i;
          final radius = tileSize * 0.22;
          offset = Offset(cos(angle) * radius, sin(angle) * radius);
        }

        final targetLeft = pt.col * tileSize + tileSize / 2 - currentTokenSize / 2 + offset.dx;
        final targetTop = pt.row * tileSize + tileSize / 2 - headOffset + offset.dy;

        tokenWidgets.add(
          AnimatedPositioned(
            key: ValueKey('token_${token.color.name}_${token.id}'),
            duration: isAnimating ? const Duration(milliseconds: 90) : const Duration(milliseconds: 200),
            curve: isAnimating ? Curves.easeOutQuad : Curves.easeInOut,
            left: targetLeft,
            top: targetTop,
            child: TokenWidget(
              token: token,
              size: currentTokenSize,
              isMovable: isMovable,
              onTap: () {
                if (_animatingTokenKey != null) return;
                _startStepByStepMovement(token, widget.gameState.currentDiceRoll!);
              },
            ),
          ),
        );
      }
    }

    return tokenWidgets;
  }
}
