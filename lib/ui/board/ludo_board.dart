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

/// Tall premium board (§8).
///
/// * Classic 15×15 cross layout on tall 1:1.33 cells — fills a portrait
///   phone edge to edge. Dice live in the player panels above/below, so
///   the board carries only yards, track, tokens and labels.
/// * Chunky 3D pawns with a neat 2×2 mini-grid on shared squares.
/// * Discrete hop animation: each step lands and settles before the next.
///   The move commits to game state only after the visual lands, and all
///   other inputs are locked out via [onAnimatingChanged] while hopping so
///   a tap can never act on a stale position.
class LudoBoard extends StatefulWidget {
  final GameState gameState;
  final Function(int tokenId) onTokenSelected;
  final ValueChanged<bool>? onAnimatingChanged;

  const LudoBoard({
    super.key,
    required this.gameState,
    required this.onTokenSelected,
    this.onAnimatingChanged,
  });

  @override
  State<LudoBoard> createState() => _LudoBoardState();
}

class _LudoBoardState extends State<LudoBoard>
    with SingleTickerProviderStateMixin {
  int? _animatingTokenKey;
  int? _animatingCurrentStep;
  Timer? _hopTimer;
  int _hopGeneration = 0;

  String? _burstEmoji;
  late AnimationController _burstController;
  late Animation<double> _burstScale;
  int _lastCaptures = 0;
  final Map<String, int> _lastHomeCounts = {};

  static const int _stepMs = 150;
  static const int _settleMs = 160;

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
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.4, end: 1.25), weight: 35),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.25, end: 1.0), weight: 30),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.0), weight: 35),
    ]).animate(
        CurvedAnimation(parent: _burstController, curve: Curves.easeOut));
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
      _fireBurst('⚔️');
    }
    _lastCaptures = widget.gameState.totalCaptures;
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
    _hopGeneration++; // Invalidate any in-flight hop callbacks.
    _hopTimer?.cancel();
    _burstController.dispose();
    super.dispose();
  }

  int _tokenKey(LudoColor color, int id) => color.index * 10 + id;

  void _setAnimating(bool v) {
    widget.onAnimatingChanged?.call(v);
  }

  void _commitMove(int key, int tokenId) {
    if (!mounted || _animatingTokenKey != key) return;
    setState(() {
      _animatingTokenKey = null;
      _animatingCurrentStep = null;
    });
    _setAnimating(false);
    widget.onTokenSelected(tokenId);
  }

  void _startStepByStepMovement(Token token, int roll) {
    if (_animatingTokenKey != null) return;
    final startStep = token.step;
    final int finalStep = (startStep == -1) ? 0 : startStep + roll;
    final key = _tokenKey(token.color, token.id);
    final gen = ++_hopGeneration;

    setState(() {
      _animatingTokenKey = key;
      _animatingCurrentStep = startStep;
    });
    _setAnimating(true);

    if (startStep == -1) {
      _hopTimer?.cancel();
      AudioService.playTokenOut();
      HapticsService.medium();
      _hopTimer = Timer(const Duration(milliseconds: 280), () {
        if (gen != _hopGeneration) return;
        _commitMove(key, token.id);
      });
      return;
    }

    int currentStep = startStep;
    _hopTimer?.cancel();
    _hopTimer =
        Timer.periodic(const Duration(milliseconds: _stepMs), (timer) {
      if (!mounted || gen != _hopGeneration) {
        timer.cancel();
        return;
      }
      currentStep++;
      HapticsService.light();
      AudioService.playTokenStep();
      if (currentStep >= finalStep) {
        timer.cancel();
        setState(() => _animatingCurrentStep = finalStep);
        // Let the pawn visibly settle on its landing square before the
        // state commit moves turn/dice forward.
        Future.delayed(const Duration(milliseconds: _settleMs), () {
          if (gen != _hopGeneration) return;
          _commitMove(key, token.id);
        });
      } else {
        setState(() => _animatingCurrentStep = currentStep);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double tw = constraints.maxWidth / 15.0;
        final double th = constraints.maxHeight / 15.0;
        final double tu = min(tw, th);
        // Pawns read large but stay clearly smaller than a cell.
        final double tokenSize = tw * 0.98;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tu * 0.55),
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
              ..._buildAllTokens(tw, th, tokenSize),
              ..._buildYardLabels(tw, th, tu),
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
                                  fontSize: tu * 2.4, height: 1.0),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildYardLabels(double tw, double th, double tu) {
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
      final w = tw * 3.6;
      final h = th * 0.62;
      widgets.add(
        Positioned(
          left: cx * tw - w / 2,
          top: cy * th - h / 2,
          width: w,
          height: h,
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: tu * 0.24, vertical: tu * 0.07),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(isTurn ? 0.55 : 0.38),
                borderRadius: BorderRadius.circular(tu * 0.2),
                border: isTurn
                    ? Border.all(color: color.lightGlow, width: 1.4)
                    : null,
              ),
              child: Text(
                '${color.emblemGlyph} ${player.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: tu * 0.38,
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

  List<Widget> _buildAllTokens(double tw, double th, double tokenSize) {
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

        // Neat mini-grid when sharing: big, no messy overlap.
        double displaySize = tokenSize;
        Offset offset = Offset.zero;
        if (count > 1 && token.step != -1) {
          if (count == 2) {
            displaySize = tokenSize * 0.66;
            offset = Offset((i == 0 ? -1 : 1) * tw * 0.22, 0);
          } else {
            displaySize = tokenSize * 0.60;
            const dx = [-1, 1, -1, 1];
            const dy = [-1, -1, 1, 1];
            final k = i % 4;
            offset = Offset(dx[k] * tw * 0.22, dy[k] * th * 0.16);
          }
        }
        // Home medallion: 4 mini pawns in a diamond.
        if (token.step >= 56) {
          displaySize = tokenSize * 0.56;
          const dx = [0, -1, 1, 0];
          const dy = [-1, 0, 0, 1];
          final k = token.id % 4;
          offset = Offset(dx[k] * tw * 0.34, dy[k] * th * 0.26);
        }

        final center = boardPoint.toOffsetXY(tw, th);
        final targetLeft =
            center.dx - displaySize / 2 + offset.dx;
        final targetTop =
            center.dy - displaySize / 2 + offset.dy;

        tokenWidgets.add(
          AnimatedPositioned(
            key: ValueKey('token_${token.color.name}_${token.id}'),
            duration: isAnimating
                ? const Duration(milliseconds: 80)
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
