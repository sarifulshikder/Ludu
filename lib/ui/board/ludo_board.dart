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

/// Edge-to-edge Aurora board.
///
/// * Board dimension is width-bound with only ~6dp side margins so path
///   cells stay big and readable from a distance.
/// * Orbs are centered on their squares (no pin offsets).
/// * Shared squares use a neat 2×2 mini-grid — never messy overlap.
/// * Hop animation moves square-by-square with sound + light haptics;
///   capture shows a ⚔️ burst, home arrival a 🎉 burst.
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

class _LudoBoardState extends State<LudoBoard>
    with SingleTickerProviderStateMixin {
  int? _animatingTokenKey;
  int? _animatingCurrentStep;
  Timer? _hopTimer;

  String? _burstEmoji;
  late AnimationController _burstController;
  late Animation<double> _burstScale;
  int _lastCaptures = 0;
  final Map<String, int> _lastHomeCounts = {};

  @override
  void initState() {
    super.initState();
    _lastCaptures = widget.gameState.totalCaptures;
    for (final p in widget.gameState.players) {
      _lastHomeCounts[p.color.name] = p.tokensHomeCount;
    }
    _burstController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _burstScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 0.4, end: 1.25), weight: 35),
      TweenSequenceItem(tween: Tween<double>(begin: 1.25, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 35),
    ]).animate(CurvedAnimation(parent: _burstController, curve: Curves.easeOut));
    _burstController.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        setState(() => _burstEmoji = null);
      }
    });
  }

  @override
  void didUpdateWidget(covariant LudoBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.gameState.totalCaptures > _lastCaptures) {
      _lastCaptures = widget.gameState.totalCaptures;
      _fireBurst('⚔️');
    } else {
      _lastCaptures = widget.gameState.totalCaptures;
    }
    for (final p in widget.gameState.players) {
      final prev = _lastHomeCounts[p.color.name] ?? 0;
      if (p.tokensHomeCount > prev) {
        _fireBurst('🎉');
      }
      _lastHomeCounts[p.color.name] = p.tokensHomeCount;
    }
  }

  void _fireBurst(String emoji) {
    setState(() => _burstEmoji = emoji);
    _burstController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _hopTimer?.cancel();
    _burstController.dispose();
    super.dispose();
  }

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
      _hopTimer?.cancel();
      AudioService.playTokenOut();
      HapticsService.medium();
      _hopTimer = Timer(const Duration(milliseconds: 260), () {
        if (!mounted) return;
        setState(() {
          _animatingTokenKey = null;
          _animatingCurrentStep = null;
        });
        widget.onTokenSelected(token.id);
      });
      return;
    }

    int currentStep = startStep;
    const int stepDurationMs = 110;
    _hopTimer?.cancel();
    _hopTimer = Timer.periodic(const Duration(milliseconds: stepDurationMs),
        (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      currentStep++;
      HapticsService.light();
      AudioService.playTokenStep();
      if (currentStep >= finalStep) {
        timer.cancel();
        setState(() => _animatingCurrentStep = finalStep);
        Future.delayed(const Duration(milliseconds: 130), () {
          if (!mounted) return;
          setState(() {
            _animatingTokenKey = null;
            _animatingCurrentStep = null;
          });
          widget.onTokenSelected(token.id);
        });
      } else {
        setState(() => _animatingCurrentStep = currentStep);
      }
    });
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
        final double boardDimension =
            min(constraints.maxWidth, constraints.maxHeight);
        final double tileSize = boardDimension / 15.0;
        // Big orbs: nearly fill their cell on track, sit inside wells in base.
        final double trackTokenSize = tileSize * 0.98;
        final double baseTokenSize = tileSize * 0.92;

        return Center(
          child: Container(
            width: boardDimension,
            height: boardDimension,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(tileSize * 0.55),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.55 : 0.30),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: widget.gameState.currentPlayer.color.primary
                      .withOpacity(0.25),
                  blurRadius: 32,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: BoardPainter(
                      isDark: isDark,
                      activeColor: widget.gameState.currentPlayer.color,
                    ),
                  ),
                ),
                if (widget.gameState.canRollDice) ...[
                  _baseTap(LudoColor.red, tileSize, left: 0, top: 0),
                  _baseTap(LudoColor.green, tileSize, right: 0, top: 0),
                  _baseTap(LudoColor.yellow, tileSize, right: 0, bottom: 0),
                  _baseTap(LudoColor.blue, tileSize, left: 0, bottom: 0),
                ],
                ..._buildAllTokens(
                    tileSize, trackTokenSize, baseTokenSize),
                ..._buildYardLabels(tileSize),
                if (_burstEmoji != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: AnimatedBuilder(
                          animation: _burstController,
                          builder: (context, _) => Transform.scale(
                            scale: _burstScale.value,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                _burstEmoji!,
                                style: TextStyle(
                                    fontSize: tileSize * 2.4, height: 1.0),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _baseTap(LudoColor color, double tile,
      {double? left, double? top, double? right, double? bottom}) {
    return Positioned(
      left: left != null ? 0 : null,
      top: top != null ? 0 : null,
      right: right != null ? 0 : null,
      bottom: bottom != null ? 0 : null,
      width: tile * 6,
      height: tile * 6,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => _handleBaseTap(color),
      ),
    );
  }

  List<Widget> _buildYardLabels(double tileSize) {
    final widgets = <Widget>[];
    void add(LudoColor color, double cx, double cy) {
      Player? player;
      for (final p in widget.gameState.players) {
        if (p.color == color) {
          player = p;
          break;
        }
      }
      if (player == null) return;
      final isTurn =
          widget.gameState.currentPlayer.color == color;
      final w = tileSize * 3.4;
      final h = tileSize * 0.72;
      widgets.add(
        Positioned(
          left: cx * tileSize - w / 2,
          top: cy * tileSize - h / 2,
          width: w,
          height: h,
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: tileSize * 0.22, vertical: tileSize * 0.06),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(isTurn ? 0.55 : 0.38),
                borderRadius: BorderRadius.circular(tileSize * 0.2),
                border: isTurn
                    ? Border.all(
                        color: color.lightGlow, width: 1.4)
                    : null,
              ),
              child: Text(
                '${color.emblemGlyph} ${player.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: tileSize * 0.36,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  shadows: const [
                    Shadow(color: Colors.black, blurRadius: 3),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    add(LudoColor.red, 3.0, 0.55);
    add(LudoColor.green, 12.0, 0.55);
    add(LudoColor.yellow, 12.0, 14.45);
    add(LudoColor.blue, 3.0, 14.45);
    return widgets;
  }

  List<Widget> _buildAllTokens(
    double tileSize,
    double trackTokenSize,
    double baseTokenSize,
  ) {
    final List<Widget> tokenWidgets = [];
    final Map<String, List<Map<String, dynamic>>> buckets = {};

    for (int pIdx = 0; pIdx < widget.gameState.players.length; pIdx++) {
      final player = widget.gameState.players[pIdx];
      final isCurrent = (pIdx == widget.gameState.currentPlayerIndex);
      for (final token in player.tokens) {
        final key = _tokenKey(token.color, token.id);
        final isMoving = (_animatingTokenKey == key);
        final effectiveStep =
            isMoving ? (_animatingCurrentStep ?? token.step) : token.step;
        final isMovable = isCurrent &&
            widget.gameState.mustSelectToken &&
            widget.gameState.movableTokenIds.contains(token.id) &&
            _animatingTokenKey == null;
        final bp = BoardCoordinates.getTokenPosition(
          color: token.color,
          tokenId: token.id,
          step: effectiveStep,
        );
        // Finished tokens share the medallion — bucket them per color.
        final coordKey = effectiveStep >= 56
            ? 'home_${token.color.name}'
            : '${bp.row.toStringAsFixed(1)}_${bp.col.toStringAsFixed(1)}';
        buckets.putIfAbsent(coordKey, () => []).add({
          'token': token,
          'boardPoint': bp,
          'isMovable': isMovable,
          'isAnimating': isMoving,
        });
      }
    }

    for (final bucket in buckets.values) {
      final count = bucket.length;
      for (int i = 0; i < count; i++) {
        final item = bucket[i];
        final Token token = item['token'];
        final boardPoint = item['boardPoint'] as BoardPoint;
        final bool isMovable = item['isMovable'];
        final bool isAnimating = item['isAnimating'];

        final double baseSize =
            token.isInBase ? baseTokenSize : trackTokenSize;
        // Neat mini-grid when sharing: no messy overlap.
        double displaySize = baseSize;
        Offset offset = Offset.zero;
        if (count > 1 && token.step != -1) {
          if (count == 2) {
            displaySize = baseSize * 0.62;
            offset = Offset((i == 0 ? -1 : 1) * tileSize * 0.20, 0);
          } else {
            displaySize = baseSize * 0.55;
            const dx = [-1, 1, -1, 1];
            const dy = [-1, -1, 1, 1];
            final k = i % 4;
            offset = Offset(
                dx[k] * tileSize * 0.20, dy[k] * tileSize * 0.20);
          }
        }
        // Home medallion: 4 mini orbs in a diamond.
        if (token.step >= 56) {
          displaySize = baseSize * 0.52;
          const dx = [0, -1, 1, 0];
          const dy = [-1, 0, 0, 1];
          final k = token.id % 4;
          offset = Offset(dx[k] * tileSize * 0.32, dy[k] * tileSize * 0.32);
        }

        final targetLeft =
            boardPoint.col * tileSize + tileSize / 2 - displaySize / 2 + offset.dx;
        final targetTop =
            boardPoint.row * tileSize + tileSize / 2 - displaySize / 2 + offset.dy;

        tokenWidgets.add(
          AnimatedPositioned(
            key: ValueKey('token_${token.color.name}_${token.id}'),
            duration: isAnimating
                ? const Duration(milliseconds: 95)
                : const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            left: targetLeft,
            top: targetTop,
            child: TokenWidget(
              token: token,
              size: displaySize,
              isMovable: isMovable,
              onTap: () {
                if (_animatingTokenKey != null) return;
                final roll = widget.gameState.currentDiceRoll;
                if (roll == null) return;
                _startStepByStepMovement(token, roll);
              },
            ),
          ),
        );
      }
    }
    return tokenWidgets;
  }
}
