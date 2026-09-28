import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/board_coordinates.dart';
import '../../models/game_state.dart';
import '../../models/ludo_color.dart';
import '../../models/token.dart';
import '../../services/haptics_service.dart';
import 'board_painter.dart';
import 'token_widget.dart';

class LudoBoard extends StatefulWidget {
  final GameState gameState;
  final Function(int tokenId) onTokenSelected;

  const LudoBoard({
    super.key,
    required this.gameState,
    required this.onTokenSelected,
  });

  @override
  State<LudoBoard> createState() => _LudoBoardState();
}

class _LudoBoardState extends State<LudoBoard> {
  // Tracking animated token movement step-by-step
  int? _animatingTokenKey; // hash of player color & token id
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
      // Direct hop from base to entry tile
      _hopTimer?.cancel();
      _hopTimer = Timer(const Duration(milliseconds: 260), () {
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
    const int stepDurationMs = 110;

    _hopTimer?.cancel();
    _hopTimer = Timer.periodic(const Duration(milliseconds: stepDurationMs), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      currentStep++;
      HapticsService.light();

      if (currentStep >= finalStep) {
        timer.cancel();
        setState(() {
          _animatingCurrentStep = finalStep;
        });

        // Small pause at landing tile then commit move
        Future.delayed(const Duration(milliseconds: 140), () {
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double boardDimension = min(constraints.maxWidth, constraints.maxHeight);
        final double tileSize = boardDimension / 15.0;
        final double tokenSize = tileSize * 0.78;

        return Center(
          child: Container(
            width: boardDimension,
            height: boardDimension,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 18,
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

                // Tokens layer
                ..._buildAllTokens(boardDimension, tileSize, tokenSize),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildAllTokens(double boardDimension, double tileSize, double tokenSize) {
    final List<Widget> tokenWidgets = [];

    // Group tokens by their rendered coordinate key to calculate offsets for stacked tokens
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

    // Render tokens with offsets when clustered
    for (final bucket in positionBuckets.values) {
      final count = bucket.length;

      for (int i = 0; i < count; i++) {
        final item = bucket[i];
        final Token token = item['token'];
        final BoardPoint pt = item['boardPoint'];
        final bool isMovable = item['isMovable'];
        final bool isAnimating = item['isAnimating'];

        Offset offset = Offset.zero;
        if (count > 1 && !token.isInBase) {
          final angle = (2 * pi / count) * i;
          final radius = tileSize * 0.18;
          offset = Offset(cos(angle) * radius, sin(angle) * radius);
        }

        final targetLeft = pt.col * tileSize + (tileSize - tokenSize) / 2 + offset.dx;
        final targetTop = pt.row * tileSize + (tileSize - tokenSize) / 2 + offset.dy;

        tokenWidgets.add(
          AnimatedPositioned(
            key: ValueKey('token_${token.color.name}_${token.id}'),
            duration: isAnimating ? const Duration(milliseconds: 90) : const Duration(milliseconds: 220),
            curve: isAnimating ? Curves.easeOutQuad : Curves.easeInOut,
            left: targetLeft,
            top: targetTop,
            child: TokenWidget(
              token: token,
              size: tokenSize,
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
