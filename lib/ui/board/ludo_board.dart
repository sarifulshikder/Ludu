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

/// Perfectly Square 15×15 Ludo Board — premium polish pass.
///
/// * Path tokens fill ~90% of the cell, centered, never overlapping.
/// * Base tokens are larger (1.20 cells) on an evenly spaced 2x2 grid that
///   fills ~75% of the inner panel width per row.
/// * Stacks: 2 side by side at ~60% each, 3-4 in a 2x2 cluster at ~48%
///   each with readable numbers; tapping a multi-movable stack opens a
///   small fan-out picker.
/// * Movement is step-by-step along cell centers with a short arc hop per
///   square (~200 ms/step, smooth easing, continuous flow, no pause):
///   lift + shrinking shadow mid-hop, tiny squash on landing, pop from
///   base, capture flights back to base, center glide with sparkle.
/// * The moving token renders in an overlay driven by [AnimationController]
///   with hardware-accelerated transforms only (no layout per frame) at a
///   steady 60 fps. Input is locked during animations; double taps can
///   never cause a double move.
class LudoBoard extends StatefulWidget {
  final GameState gameState;
  final Function(int tokenId) onTokenSelected;
  final ValueChanged<bool>? onAnimatingChanged;

  /// Animation duration multiplier (1.0 normal, ~0.55 fast).
  final double timeScale;

  /// Active premium theme.
  final AppThemeMode themeMode;
  final LuduThemeConfig? themeConfig;
  final bool isDark;

  const LudoBoard({
    super.key,
    required this.gameState,
    required this.onTokenSelected,
    this.onAnimatingChanged,
    this.timeScale = 1.0,
    this.themeMode = AppThemeMode.royalGold,
    this.themeConfig,
    this.isDark = false,
  });

  @override
  State<LudoBoard> createState() => _LudoBoardState();
}

class _BucketItem {
  final Token token;
  final BoardPoint boardPoint;
  final bool isMovable;
  _BucketItem(this.token, this.boardPoint, this.isMovable);
}

class _CaptureFlight {
  final LudoColor color;
  final int tokenId;
  final BoardPoint from;
  final BoardPoint to;
  final AnimationController controller;
  _CaptureFlight({
    required this.color,
    required this.tokenId,
    required this.from,
    required this.to,
    required this.controller,
  });
}

class _LudoBoardState extends State<LudoBoard>
    with TickerProviderStateMixin {
  int? _animatingTokenKey;
  Token? _animatingToken;
  int _animatingFrom = -1;
  int _animatingTo = 0;
  List<BoardPoint> _waypoints = const [];
  BoardPoint? _animStartPos;
  AnimationController? _moveController;
  int _lastSoundStep = -1;
  int _hopGeneration = 0;

  final List<_CaptureFlight> _captureFlights = [];
  final Set<int> _flyingKeys = {};

  String? _burstEmoji;
  late AnimationController _burstController;
  late Animation<double> _burstScale;
  late AnimationController _sparkleController;
  bool _showSparkle = false;
  Offset _sparkleCenter = Offset.zero;
  int _lastCaptures = 0;
  final Map<String, int> _lastHomeCounts = {};

  List<_BucketItem>? _stackPick;
  BoardPoint? _stackPickAnchor;

  /// ~200 ms per hop step (spec 180-220 ms), scaled by timeScale.
  static const int _stepMs = 200;

  LuduThemeConfig get _cfg =>
      widget.themeConfig ??
      LuduTheme.forMode(widget.themeMode, isDark: widget.isDark);

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
        if (mounted) setState(() => _burstEmoji = null);
      }
    });
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    );
    _sparkleController.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        if (mounted) setState(() => _showSparkle = false);
      }
    });
  }

  @override
  void didUpdateWidget(covariant LudoBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.gameState.totalCaptures > _lastCaptures) {
      _fireBurst('⚔️');
      _spawnCaptureFlights(oldWidget.gameState, widget.gameState);
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

  /// Animate captured tokens flying smoothly back to their base slots.
  void _spawnCaptureFlights(GameState oldGs, GameState newGs) {
    // Landing square of the mover (only outer-track landings capture).
    final int? lmColor = newGs.lastMoveColor;
    final int? lmTo = newGs.lastMoveTo;
    BoardPoint? landing;
    if (lmColor != null &&
        lmTo != null &&
        lmTo >= 0 &&
        lmTo <= 50 &&
        lmColor >= 0 &&
        lmColor < LudoColor.values.length) {
      final moverColor = LudoColor.values[lmColor];
      final global = (moverColor.startSquare + lmTo) % 52;
      landing = BoardCoordinates.outerTrack[global];
    }
    if (landing == null) return;
    final double ts = widget.timeScale.clamp(0.4, 1.5);
    // Previous steps per player/token, to find tokens that just left the
    // track for their base (captures).
    final Map<int, Map<int, int>> oldSteps = {
      for (final p in oldGs.players) p.id: {for (final t in p.tokens) t.id: t.step}
    };
    for (final p in newGs.players) {
      final Map<int, int>? oldP = oldSteps[p.id];
      for (final t in p.tokens) {
        if (!t.isInBase) continue;
        final int? oldStep = oldP?[t.id];
        if (oldStep == null || oldStep < 0 || oldStep > 50) continue;
        // This token was on the track and is now in base: it was captured.
        final key = _tokenKey(t.color, t.id);
        if (_flyingKeys.contains(key)) continue;
        final to = BoardCoordinates.getTokenPosition(
            color: t.color, tokenId: t.id, step: -1);
        final ctl = AnimationController(
          vsync: this,
          duration: Duration(milliseconds: (450 * ts).round()),
        );
        final flight = _CaptureFlight(
          color: t.color,
          tokenId: t.id,
          from: landing,
          to: to,
          controller: ctl,
        );
        _flyingKeys.add(key);
        _captureFlights.add(flight);
        ctl.forward().then((_) {
          if (!mounted) return;
          setState(() {
            _captureFlights.remove(flight);
            _flyingKeys.remove(key);
          });
          try {
            ctl.dispose();
          } catch (_) {}
        });
      }
    }
    if (_captureFlights.isNotEmpty && mounted) setState(() {});
  }

  @override
  void dispose() {
    _hopGeneration++;
    _moveController?.dispose();
    for (final f in _captureFlights) {
      try {
        f.controller.dispose();
      } catch (_) {}
    }
    _burstController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  int _tokenKey(LudoColor color, int id) => color.index * 10 + id;

  void _setAnimating(bool v) {
    widget.onAnimatingChanged?.call(v);
  }

  void _commitMove(int key, int tokenId) {
    if (!mounted || _animatingTokenKey != key) return;
    final ctl = _moveController;
    _moveController = null;
    try {
      ctl?.dispose();
    } catch (_) {}
    setState(() {
      _animatingTokenKey = null;
      _animatingToken = null;
      _waypoints = const [];
      _animStartPos = null;
    });
    _setAnimating(false);
    widget.onTokenSelected(tokenId);
  }

  void _startStepByStepMovement(Token token, int roll) {
    // Lock input during animations; queue nothing; no double-move.
    if (_animatingTokenKey != null || _captureFlights.isNotEmpty) return;
    if (_stackPick != null) {
      setState(() => _stackPick = null);
    }
    final startStep = token.step;
    final int finalStep = (startStep == -1) ? 0 : startStep + roll;
    final key = _tokenKey(token.color, token.id);
    _hopGeneration++;

    final bool isBaseExit = startStep == -1;
    final List<BoardPoint> wps = [];
    BoardPoint? startPos;
    if (isBaseExit) {
      startPos = BoardCoordinates.getTokenPosition(
          color: token.color, tokenId: token.id, step: -1);
      wps.add(BoardCoordinates.getTokenPosition(
          color: token.color, tokenId: token.id, step: 0));
    } else {
      startPos = BoardCoordinates.getTokenPosition(
          color: token.color, tokenId: token.id, step: startStep);
      for (int s = startStep + 1; s <= finalStep; s++) {
        wps.add(BoardCoordinates.getTokenPosition(
            color: token.color, tokenId: token.id, step: s));
      }
    }
    if (wps.isEmpty) return;

    final double ts = widget.timeScale.clamp(0.4, 1.5);
    final int totalMs = isBaseExit
        ? (350 * ts).round().clamp(150, 600)
        : (_stepMs * wps.length * ts).round().clamp(120, 4000);

    setState(() {
      _animatingTokenKey = key;
      _animatingToken = token;
      _animatingFrom = startStep;
      _animatingTo = finalStep;
      _waypoints = wps;
      _animStartPos = startPos;
      _lastSoundStep = -1;
    });
    _setAnimating(true);

    if (isBaseExit) {
      AudioService.playTokenOut();
      HapticsService.medium();
    }

    final ctl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );
    _moveController = ctl;
    ctl.addListener(() {
      if (!mounted || _animatingTokenKey != key) return;
      if (isBaseExit) return; // pop sound already played at start
      final double v = ctl.value * wps.length;
      final int idx = v.floor().clamp(0, wps.length - 1);
      if (idx != _lastSoundStep) {
        _lastSoundStep = idx;
        AudioService.playTokenStep(idx, wps.length);
        HapticsService.selection();
      }
    });
    ctl.forward().then((_) {
      if (!mounted || _animatingTokenKey != key) return;
      if (_animatingTo == 56) {
        AudioService.playSafe();
        HapticsService.victory();
        if (mounted) {
          setState(() {
            _showSparkle = true;
            final last = _waypoints.isNotEmpty ? _waypoints.last : null;
            if (last != null) _sparkleCenter = Offset(last.col, last.row);
          });
          _sparkleController.forward(from: 0.0);
        }
      }
      _commitMove(key, token.id);
    });
  }

  void _openStackPicker(List<_BucketItem> items, BoardPoint anchor) {
    AudioService.playUiClick();
    setState(() {
      _stackPick = items.where((e) => e.isMovable).toList();
      _stackPickAnchor = anchor;
    });
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

        // Path tokens: ~90% of the cell width, centered.
        final double tokenSize = tu * 0.90;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(tu * 0.40),
                child: CustomPaint(
                  painter: BoardPainter(
                    isDark: widget.isDark,
                    activeColor: widget.gameState.currentPlayer.color,
                    themeMode: widget.themeMode,
                    themeConfig: _cfg,
                  ),
                ),
              ),
            ),
            ..._buildAllTokens(tw, th, tu, tokenSize),
            if (_moveController != null &&
                _animatingToken != null &&
                _animStartPos != null)
              _buildMovingOverlay(tw, th, tu),
            ..._buildCaptureOverlays(tw, th, tu, tokenSize),
            ..._buildLastMoveMarker(tw, th, tu),
            ..._buildYardLabels(tw, th, tu),
            if (_showSparkle) _buildSparkle(tw, th, tu),
            if (_stackPick != null && _stackPickAnchor != null)
              _buildStackPicker(tw, th, tu, width, height),
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
        );
      },
    );
  }

  Widget _buildMovingOverlay(double tw, double th, double tu) {
    final token = _animatingToken!;
    final bool isBaseExit = _animatingFrom == -1;
    final themeColor = _cfg.colorOf(token.color);
    final double tokenSize = tu * 0.90;
    final double hopH = tu * 0.32;

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _moveController!,
          builder: (context, _) {
            final double t = _moveController!.value;
            final int n = _waypoints.length;
            double row, col, lift, squash;
            double scale = 1.0;
            if (isBaseExit) {
              // Quick pop onto the start square with overshoot.
              final a = _animStartPos!;
              final b = _waypoints.first;
              row = a.row + (b.row - a.row) * t;
              col = a.col + (b.col - a.col) * t;
              lift = sin(pi * t.clamp(0.0, 1.0)) * 0.6;
              squash = 0.0;
              scale = t < 0.65
                  ? 0.55 + 0.75 * (t / 0.65)
                  : 1.30 - 0.30 * ((t - 0.65) / 0.35);
            } else {
              final double v = (t * n).clamp(0.0, n - 0.0001);
              final int seg = v.floor().clamp(0, n - 1);
              final double f = (v - seg).clamp(0.0, 1.0);
              final BoardPoint a =
                  seg == 0 ? _animStartPos! : _waypoints[seg - 1];
              final BoardPoint b = _waypoints[seg];
              // Continuous linear glide between cell centers (no pause),
              // arc hop for height.
              row = a.row + (b.row - a.row) * f;
              col = a.col + (b.col - a.col) * f;
              lift = sin(pi * f);
              squash = f > 0.88 ? (f - 0.88) / 0.12 : 0.0;
            }
            final Offset c = Offset((col + 0.5) * tw, (row + 0.5) * th);
            return Stack(
              children: [
                Positioned(
                  left: c.dx - tokenSize / 2,
                  top: c.dy - tokenSize / 2 - lift * hopH,
                  width: tokenSize,
                  height: tokenSize,
                  child: Transform.scale(
                    scale: scale,
                    child: TokenWidget(
                      token: token,
                      size: tokenSize,
                      isMovable: false,
                      themeMode: widget.themeMode,
                      themePlayerColor: themeColor,
                      animLift: lift,
                      squash: squash,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildCaptureOverlays(
      double tw, double th, double tu, double tokenSize) {
    final out = <Widget>[];
    for (final f in _captureFlights) {
      final themeColor = _cfg.colorOf(f.color);
      out.add(
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: f.controller,
              builder: (context, _) {
                final double t = Curves.easeInOutCubic
                    .transform(f.controller.value.clamp(0.0, 1.0));
                final double row = f.from.row + (f.to.row - f.from.row) * t;
                final double col = f.from.col + (f.to.col - f.from.col) * t;
                // Gentle arc while flying home.
                final double hop = sin(pi * t) * tu * 0.6;
                final Offset c =
                    Offset((col + 0.5) * tw, (row + 0.5) * th - hop);
                final double s = tokenSize * 0.9;
                return Stack(
                  children: [
                    Positioned(
                      left: c.dx - s / 2,
                      top: c.dy - s / 2,
                      width: s,
                      height: s,
                      child: Opacity(
                        opacity: 1.0 - t * 0.15,
                        child: TokenWidget(
                          token: Token(
                              id: f.tokenId, color: f.color, step: 10),
                          size: s,
                          themeMode: widget.themeMode,
                          themePlayerColor: themeColor,
                          animLift: sin(pi * t) * 0.7,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    }
    return out;
  }

  Widget _buildSparkle(double tw, double th, double tu) {
    final Offset c = Offset(
        (_sparkleCenter.dx + 0.5) * tw, (_sparkleCenter.dy + 0.5) * th);
    final double r = tu * 1.6;
    return Positioned(
      left: c.dx - r,
      top: c.dy - r,
      width: r * 2,
      height: r * 2,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _sparkleController,
          builder: (context, _) => CustomPaint(
            painter: _SparklePainter(_sparkleController.value),
          ),
        ),
      ),
    );
  }

  Widget _buildStackPicker(
      double tw, double th, double tu, double bw, double bh) {
    final items = _stackPick!;
    final anchor = _stackPickAnchor!;
    final Offset c = anchor.toOffsetXY(tw, th);
    const double pickSize = 56.0;
    const double gap = 8.0;
    final double w = items.length * pickSize + (items.length - 1) * gap + 20;
    double left = (c.dx - w / 2).clamp(6.0, max(6.0, bw - w - 6.0));
    // Fan out above the cell when there is room, else below.
    double top = c.dy - tu * 0.5 - 10 - (pickSize + 30);
    if (top < 4) top = c.dy + tu * 0.5 + 10;
    if (top + pickSize + 30 > bh - 4) {
      top = max(4.0, bh - pickSize - 34);
    }
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _stackPick = null),
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: w,
          child: Material(
            color: Colors.black.withOpacity(0.88),
            borderRadius: BorderRadius.circular(16),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Choose a token',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int i = 0; i < items.length; i++) ...[
                        if (i > 0) SizedBox(width: gap),
                        GestureDetector(
                          onTap: () {
                            final tok = items[i].token;
                            final roll =
                                widget.gameState.currentDiceRoll ?? 0;
                            setState(() => _stackPick = null);
                            _startStepByStepMovement(tok, roll);
                          },
                          child: TokenWidget(
                            token: items[i].token,
                            size: pickSize,
                            isMovable: true,
                            themeMode: widget.themeMode,
                            themePlayerColor:
                                _cfg.colorOf(items[i].token.color),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
    final Map<String, List<_BucketItem>> buckets = {};

    // Base coins use the larger yard slot size (1.20 cells).
    final double baseTokenSize = BoardLayout.baseTokenSize(tw * 15.0);
    final int? animKey = _animatingTokenKey;

    for (int pIdx = 0; pIdx < widget.gameState.players.length; pIdx++) {
      final player = widget.gameState.players[pIdx];
      final isCurrent = (pIdx == widget.gameState.currentPlayerIndex);
      for (final token in player.tokens) {
        final key = _tokenKey(token.color, token.id);
        // The moving token lives in the overlay; hide its static twin.
        if (animKey != null && key == animKey) continue;
        // Captured tokens in flight are hidden until they land.
        if (_flyingKeys.contains(key) && token.isInBase) continue;
        final isMovable = isCurrent &&
            widget.gameState.mustSelectToken &&
            widget.gameState.movableTokenIds.contains(token.id) &&
            animKey == null &&
            _captureFlights.isEmpty;
        final bp = BoardCoordinates.getTokenPosition(
          color: token.color,
          tokenId: token.id,
          step: token.step,
        );

        final coordKey = token.step >= 56
            ? 'home_${token.color.name}'
            : '${bp.row.toStringAsFixed(1)}_${bp.col.toStringAsFixed(1)}';
        buckets
            .putIfAbsent(coordKey, () => [])
            .add(_BucketItem(token, bp, isMovable));
      }
    }

    for (final bucket in buckets.values) {
      final count = bucket.length;
      final bool isBaseBucket = bucket.first.token.step == -1;
      final bool isHomeBucket = bucket.first.token.step >= 56;
      final int movableCount = bucket.where((e) => e.isMovable).length;

      for (int i = 0; i < count; i++) {
        final item = bucket[i];
        final Token token = item.token;
        final boardPoint = item.boardPoint;
        final bool isMovable = item.isMovable;

        double displaySize;
        Offset offset = Offset.zero;
        if (isBaseBucket) {
          displaySize = min(tokenSize, baseTokenSize);
        } else if (isHomeBucket) {
          displaySize = tokenSize * 0.70;
          const dx = [0, -1, 1, 0];
          const dy = [-1, 0, 0, 1];
          final k = token.id % 4;
          offset = Offset(dx[k] * tw * 0.35, dy[k] * th * 0.35);
        } else if (count == 1) {
          displaySize = tokenSize;
        } else if (count == 2) {
          // Two tokens side by side at ~60% each — fits inside the cell.
          displaySize = tokenSize * 0.60;
          offset = Offset((i == 0 ? -1 : 1) * tw * 0.21, 0);
        } else {
          // 3-4 tokens in a 2x2 cluster at ~48% each.
          displaySize = tokenSize * 0.48;
          const dx = [-1, 1, -1, 1];
          const dy = [-1, -1, 1, 1];
          final k = i % 4;
          offset = Offset(dx[k] * tw * 0.22, dy[k] * th * 0.22);
        }

        final center = boardPoint.toOffsetXY(tw, th);
        final targetLeft = center.dx - displaySize / 2 + offset.dx;
        final targetTop = center.dy - displaySize / 2 + offset.dy;

        final gs = widget.gameState;
        final isLastMoved = _animatingTokenKey == null &&
            gs.lastMoveColor == token.color.index &&
            gs.lastMoveToken == token.id &&
            gs.lastMoveTo == token.step;

        final themeColor = _cfg.colorOf(token.color);

        tokenWidgets.add(
          Positioned(
            key: ValueKey('token_${token.color.name}_${token.id}'),
            left: targetLeft,
            top: targetTop,
            width: displaySize,
            height: displaySize,
            child: TokenWidget(
              token: token,
              size: displaySize,
              isMovable: isMovable,
              isLastMoved: isLastMoved,
              themeMode: widget.themeMode,
              themePlayerColor: themeColor,
              onTap: () {
                if (_animatingTokenKey != null ||
                    _captureFlights.isNotEmpty) {
                  return;
                }
                final roll = widget.gameState.currentDiceRoll;
                if (roll == null) return;
                // Stacked cell with several movables: fan out to choose.
                if (count > 1 && movableCount > 1) {
                  _openStackPicker(bucket, boardPoint);
                  return;
                }
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

/// Small twinkling sparkle shown when a token glides into the center.
class _SparklePainter extends CustomPainter {
  final double progress;
  _SparklePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final double fade =
        progress < 0.7 ? 1.0 : 1.0 - (progress - 0.7) / 0.3;
    final rnd = Random(7);
    for (int i = 0; i < 10; i++) {
      final double ang = rnd.nextDouble() * 2 * pi;
      final double dist =
          size.width * 0.5 * (0.25 + 0.75 * progress) * rnd.nextDouble();
      final p = c + Offset(cos(ang) * dist, sin(ang) * dist);
      final double r = (2.0 + rnd.nextDouble() * 3.0) * (1.0 - progress * 0.5);
      final paint = Paint()
        ..color = Colors.white.withOpacity(0.9 * fade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(p, r, paint);
      // 4-point glint
      final glint = Path()
        ..moveTo(p.dx - r * 1.8, p.dy)
        ..lineTo(p.dx + r * 1.8, p.dy)
        ..moveTo(p.dx, p.dy - r * 1.8)
        ..lineTo(p.dx, p.dy + r * 1.8);
      canvas.drawPath(
        glint,
        Paint()
          ..color = const Color(0xFFFFE9A8).withOpacity(0.85 * fade)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter old) =>
      old.progress != progress;
}
