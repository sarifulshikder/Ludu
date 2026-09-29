import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/board_coordinates.dart';
import '../../core/theme/ludu_theme.dart';
import '../../models/game_settings.dart';
import '../../models/game_state.dart';
import '../../models/ludo_color.dart';
import '../../models/player.dart';
import '../../models/token.dart';
import '../../services/audio_service.dart';
import '../../services/haptics_service.dart';
import 'board_painter.dart';
import 'token_widget.dart';

/// Perfectly Square 15×15 Ludo Board.
///
/// * Edge to edge across screen width, with no outer margin.
/// * Maximized path cells and tokens (tokens fill ~94% of cell width).
/// * Discrete hop animation lands and settles on each square.
/// * Integrated with Royal Gold, Neon Glass, and Wooden Luxe themes.
class LudoBoard extends StatefulWidget {
  final GameState gameState;
  final Function(int tokenId) onTokenSelected;
  final ValueChanged<bool>? onAnimatingChanged;

  /// Animation duration multiplier (1.0 normal, ~0.55 fast).
  final double timeScale;

  /// Active premium theme.
  final AppThemeMode themeMode;
  final LuduThemeConfig? themeConfig;

  const LudoBoard({
    super.key,
    required this.gameState,
    required this.onTokenSelected,
    this.onAnimatingChanged,
    this.timeScale = 1.0,
    this.themeMode = AppThemeMode.royalGold,
    this.themeConfig,
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

  static const int _baseStepMs = 150;
  static const int _baseSettleMs = 160;
  static const int _baseOutMs = 280;

  int get _stepMs =>
      (_baseStepMs * widget.timeScale).round().clamp(40, 400);
  int get _settleMs =>
      (_baseSettleMs * widget.timeScale).round().clamp(40, 400);
  int get _outMs =>
      (_baseOutMs * widget.timeScale).round().clamp(60, 600);

  LuduThemeConfig get _cfg =>
      widget.themeConfig ?? LuduTheme.forMode(widget.themeMode);

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
    _hopGeneration++;
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
      AudioService.playTokenOut();
      HapticsService.medium();
      _hopTimer = Timer(Duration(milliseconds: _outMs), () {
        if (!mounted || _hopGeneration != gen) return;
        setState(() => _animatingCurrentStep = 0);
        _hopTimer = Timer(Duration(milliseconds: _settleMs), () {
          _commitMove(key, token.id);
        });
      });
      return;
    }

    AudioService.playTokenStep();
    HapticsService.light();

    int current = startStep;
    void hopNext() {
      if (!mounted || _hopGeneration != gen) return;
      if (current < finalStep) {
        current++;
        setState(() => _animatingCurrentStep = current);
        AudioService.playTokenStep();
        HapticsService.selection();
        _hopTimer = Timer(Duration(milliseconds: _stepMs), hopNext);
      } else {
        _hopTimer = Timer(Duration(milliseconds: _settleMs), () {
          _commitMove(key, token.id);
        });
      }
    }

    _hopTimer = Timer(Duration(milliseconds: _stepMs), hopNext);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        final double tw = width / 15.0;
        final double th = height / 15.0;
        final double tu = min(tw, th);

        // Tokens almost fill the cell width (94%)
        final double tokenSize = tw * 0.94;

        return ClipRRect(
          borderRadius: BorderRadius.circular(tu * 0.40),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: BoardPainter(
                    isDark: true,
                    activeColor: widget.gameState.currentPlayer.color,
                    themeMode: widget.themeMode,
                    themeConfig: _cfg,
                  ),
                ),
              ),
              ..._buildAllTokens(tw, th, tu, tokenSize),
              ..._buildLastMoveMarker(tw, th, tu),
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
                              color: Colors.black.withOpacity(0.65),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              _burstEmoji!,
                              style: TextStyle(
                                fontSize: tu * 2.4,
                                height: 1.0,
                              ),
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
      final isTurn = widget.gameState.currentPlayer.color == color;
      final themeColor = _cfg.colorOf(color);
      final w = tw * 3.6;
      final h = th * 0.58;

      widgets.add(
        Positioned(
          left: cx * tw - w / 2,
          top: cy * th - h / 2,
          width: w,
          height: h,
          child: Center(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: tu * 0.22,
                vertical: tu * 0.06,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(isTurn ? 0.65 : 0.42),
                borderRadius: BorderRadius.circular(tu * 0.2),
                border: isTurn
                    ? Border.all(color: themeColor.lightGlow, width: 1.4)
                    : null,
              ),
              child: Text(
                '${color.emblemGlyph} ${player.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: tu * 0.36,
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

  List<Widget> _buildLastMoveMarker(double tw, double th, double tu) {
    final gs = widget.gameState;
    final from = gs.lastMoveFrom;
    final colorIdx = gs.lastMoveColor;
    final tokenId = gs.lastMoveToken;
    if (from == null || colorIdx == null || tokenId == null) {
      return const [];
    }
    if (from < 0 ||
        colorIdx < 0 ||
        colorIdx >= LudoColor.values.length) {
      return const [];
    }
    final bp = BoardCoordinates.getTokenPosition(
      color: LudoColor.values[colorIdx],
      tokenId: tokenId,
      step: from,
    );
    final c = bp.toOffsetXY(tw, th);
    final d = tu * 0.92;
    return [
      Positioned(
        left: c.dx - d / 2,
        top: c.dy - d / 2,
        width: d,
        height: d,
        child: IgnorePointer(
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _cfg.boardInlayLine.withOpacity(0.85),
                width: max(2.0, tu * 0.09),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildAllTokens(
      double tw, double th, double tu, double tokenSize) {
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

        // Compact base tokens and square path tokens fill ~94% of cell
        double displaySize = tokenSize;
        Offset offset = Offset.zero;
        if (count > 1 && token.step != -1) {
          if (count == 2) {
            displaySize = tokenSize * 0.74;
            offset = Offset((i == 0 ? -1 : 1) * tw * 0.25, 0);
          } else {
            displaySize = tokenSize * 0.65;
            const dx = [-1, 1, -1, 1];
            const dy = [-1, -1, 1, 1];
            final k = i % 4;
            offset = Offset(dx[k] * tw * 0.25, dy[k] * th * 0.25);
          }
        }
        // Home medallion: 4 mini pawns in diamond
        if (token.step >= 56) {
          displaySize = tokenSize * 0.62;
          const dx = [0, -1, 1, 0];
          const dy = [-1, 0, 0, 1];
          final k = token.id % 4;
          offset = Offset(dx[k] * tw * 0.35, dy[k] * th * 0.35);
        }

        final center = boardPoint.toOffsetXY(tw, th);
        final targetLeft = center.dx - displaySize / 2 + offset.dx;
        final targetTop = center.dy - displaySize / 2 + offset.dy;

        final gs = widget.gameState;
        final isLastMoved = !isAnimating &&
            _animatingTokenKey == null &&
            gs.lastMoveColor == token.color.index &&
            gs.lastMoveToken == token.id &&
            gs.lastMoveTo == token.step;

        final themeColor = _cfg.colorOf(token.color);

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
              isLastMoved: isLastMoved,
              themeMode: widget.themeMode,
              themePlayerColor: themeColor,
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
