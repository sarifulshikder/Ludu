import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/ludo_color.dart';
import '../../models/player.dart';
import '../../services/haptics_service.dart';

/// A premium player panel: avatar, name, live token progress and the player's
/// own dice. Every player always shows a dice so each box reads as a complete,
/// playable station rather than only the active turn being lit up.
class PlayerBoxWidget extends StatefulWidget {
  final Player player;
  final double cardHeight;
  final bool isCurrentTurn;
  final bool canRoll;
  final bool mustSelectToken;

  /// The roll to display. Only the current player's box receives a value; other
  /// boxes keep showing that player's own most recent result.
  final int? showDiceRoll;

  final bool isRolling;
  final VoidCallback onRoll;
  final VoidCallback? onAutoMoveSingle;
  final bool isDark;

  const PlayerBoxWidget({
    super.key,
    required this.player,
    required this.cardHeight,
    required this.isCurrentTurn,
    required this.canRoll,
    required this.mustSelectToken,
    this.showDiceRoll,
    this.isRolling = false,
    required this.onRoll,
    this.onAutoMoveSingle,
    required this.isDark,
  });

  @override
  State<PlayerBoxWidget> createState() => _PlayerBoxWidgetState();
}

class _PlayerBoxWidgetState extends State<PlayerBoxWidget>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  late AnimationController _diceRollController;
  late Animation<double> _diceRotateX;
  late Animation<double> _diceRotateY;
  late Animation<double> _diceScale;

  int _displayDice = 1;
  int? _lastRoll;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _lastRoll = widget.showDiceRoll;
    _displayDice = widget.showDiceRoll ?? (widget.player.id + 1).clamp(1, 6);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _glowAnimation = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    if (widget.isCurrentTurn) {
      _startGlow();
    }

    // 3D dice tumbling animation
    _diceRollController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    final curved = CurvedAnimation(
      parent: _diceRollController,
      curve: Curves.easeOutBack,
    );
    _diceRotateX = Tween<double>(begin: 0, end: 4 * pi).animate(curved);
    _diceRotateY = Tween<double>(begin: 0, end: 4 * pi).animate(curved);
    _diceScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.22), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 1.22, end: 0.92), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 0.92, end: 1.0), weight: 30),
    ]).animate(curved);

    _diceRollController.addListener(() {
      if (_diceRollController.isAnimating && _random.nextDouble() > 0.5) {
        setState(() {
          _displayDice = _random.nextInt(6) + 1;
        });
      }
    });

    _diceRollController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _displayDice = widget.showDiceRoll ?? _lastRoll ?? 1;
        });
        HapticsService.light();
      }
    });
  }

  @override
  void didUpdateWidget(covariant PlayerBoxWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.cardHeight != oldWidget.cardHeight) {
      // Sizes are derived from cardHeight, so a rebuild is enough.
      setState(() {});
    }

    if (widget.isCurrentTurn != oldWidget.isCurrentTurn) {
      if (widget.isCurrentTurn) {
        _startGlow();
      } else {
        _glowController.stop();
        _glowController.reset();
      }
    }

    if (widget.showDiceRoll != null && widget.showDiceRoll != oldWidget.showDiceRoll) {
      _lastRoll = widget.showDiceRoll;
      setState(() {
        _displayDice = widget.showDiceRoll!;
      });
      if (widget.isCurrentTurn && !_diceRollController.isAnimating) {
        _diceRollController.forward(from: 0.0);
      }
    }
  }

  void _startGlow() {
    // In widget tests an endlessly repeating animation would make
    // pumpAndSettle() hang, so settle the controller once instead.
    bool inTest = false;
    assert(() {
      if (WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
        inTest = true;
      }
      return true;
    }());

    if (inTest) {
      _glowController.forward();
    } else {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _diceRollController.dispose();
    super.dispose();
  }

  void _handleDiceTap() {
    if (!widget.isCurrentTurn) return;
    if (widget.canRoll && !widget.isRolling && !_diceRollController.isAnimating) {
      HapticsService.medium();
      _diceRollController.forward(from: 0.0);
      widget.onRoll();
    } else if (widget.mustSelectToken && widget.onAutoMoveSingle != null) {
      widget.onAutoMoveSingle!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.player.color;
    final isFinished = widget.player.finishRank != null;

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final glow = widget.isCurrentTurn ? _glowAnimation.value : 0.0;

        return GestureDetector(
          onTap: _handleDiceTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            height: widget.cardHeight,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.isDark
                    ? (widget.isCurrentTurn
                        ? [
                            Color.alphaBlend(color.primary.withOpacity(0.34), const Color(0xFF17223C)),
                            Color.alphaBlend(color.primary.withOpacity(0.14), const Color(0xFF10192B)),
                          ]
                        : const [Color(0xFF16203A), Color(0xFF0E1626)])
                    : (widget.isCurrentTurn
                        ? [
                            Color.alphaBlend(color.primary.withOpacity(0.20), Colors.white),
                            Color.alphaBlend(color.primary.withOpacity(0.07), const Color(0xFFF8F4EC)),
                          ]
                        : const [Colors.white, Color(0xFFF3EEE4)]),
              ),
              borderRadius: BorderRadius.circular(widget.cardHeight * 0.26),
              border: Border.all(
                color: widget.isCurrentTurn
                    ? color.lightGlow.withOpacity(glow)
                    : (widget.isDark ? const Color(0xFF26334F) : const Color(0xFFDFD7C8)),
                width: widget.isCurrentTurn ? 2.4 : 1.2,
              ),
              boxShadow: [
                if (widget.isCurrentTurn)
                  BoxShadow(
                    color: color.primary.withOpacity(0.45 * glow),
                    blurRadius: 20,
                    spreadRadius: 1.5,
                    offset: const Offset(0, 4),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withOpacity(widget.isDark ? 0.30 : 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            // Sizes are derived from the real inner box so the card can never
            // overflow on narrow phones or in landscape.
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availH = constraints.maxHeight;
                final availW = constraints.maxWidth;

                // Cap the dice by width too, so it can never crowd out the
                // identity column on a narrow card.
                final widthCap = availW * 0.44;
                final diceCap = widthCap < 36.0 ? 36.0 : min(86.0, widthCap);
                final gap = (availH * 0.06).clamp(4.0, 12.0).toDouble();
                // The two stacked rows plus the gap must fit the card exactly.
                final rowSpace = availH - gap;
                final diceSize = (rowSpace * 0.58).clamp(34.0, diceCap).toDouble();
                final avatarSize = (rowSpace * 0.40).clamp(28.0, 68.0).toDouble();
                final dotSize = (diceSize * 0.16).clamp(8.0, 14.0).toDouble();
                final nameSize = (availH * 0.17).clamp(12.0, 22.0).toDouble();

                return Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _buildAvatar(color, isFinished, avatarSize),
                        SizedBox(width: gap * 1.4),
                        Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.player.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: nameSize,
                                    height: 1.1,
                                    fontWeight: FontWeight.w900,
                                    color: widget.isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              if (widget.isCurrentTurn) ...[
                                SizedBox(width: gap * 0.7),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [color.lightGlow, color.primary],
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'TURN',
                                    style: TextStyle(
                                      fontSize: max(8.0, nameSize * 0.5),
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      height: 1.1,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(child: _buildTokenProgress(color, dotSize)),
                        _buildDice(color, diceSize),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatar(LudoColor color, bool isFinished, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.lightGlow, color.primary, color.darkShade],
          center: const Alignment(-0.2, -0.25),
          radius: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: color.primary.withOpacity(0.55),
            blurRadius: size * 0.22,
            offset: Offset(0, size * 0.06),
          ),
        ],
        border: Border.all(
          color: widget.isCurrentTurn ? const Color(0xFFFFD700) : Colors.white70,
          width: widget.isCurrentTurn ? 2.6 : 1.8,
        ),
      ),
      child: Center(
        child: isFinished
            ? Text(
                _rankMedal(widget.player.finishRank ?? 1),
                style: TextStyle(fontSize: size * 0.5),
              )
            : Text(
                widget.player.name.isNotEmpty
                    ? widget.player.name.substring(0, 1).toUpperCase()
                    : 'P',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: size * 0.44,
                  shadows: const [
                    Shadow(color: Colors.black54, blurRadius: 3, offset: Offset(0, 1)),
                  ],
                ),
              ),
      ),
    );
  }

  String _rankMedal(int rank) {
    switch (rank) {
      case 1:
        return '🥇';
      case 2:
        return '🥈';
      case 3:
        return '🥉';
      default:
        return '#$rank';
    }
  }

  Widget _buildTokenProgress(LudoColor color, double dotSize) {
    final tokens = widget.player.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: tokens.map((t) {
        Color dotColor;
        IconData? icon;

        if (t.isHome) {
          dotColor = const Color(0xFFFFD700);
          icon = Icons.star_rounded;
        } else if (t.isInBase) {
          dotColor = widget.isDark ? const Color(0xFF3B4A63) : const Color(0xFFCBD5E1);
        } else {
          dotColor = color.primary;
        }

        return Container(
          margin: EdgeInsets.only(right: dotSize * 0.34),
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: t.isInBase
                  ? (widget.isDark ? Colors.white24 : Colors.black12)
                  : Colors.white70,
              width: 0.8,
            ),
          ),
          child: icon != null
              ? Center(
                  child: Icon(icon, size: dotSize * 0.7, color: Colors.black87),
                )
              : null,
        );
      }).toList(),
    );
  }

  Widget _buildDice(LudoColor color, double size) {
    final isActive = widget.isCurrentTurn;

    return AnimatedBuilder(
      animation: _diceRollController,
      builder: (context, child) {
        final isAnimating = _diceRollController.isAnimating;
        final rotX = isAnimating ? _diceRotateX.value : 0.0;
        final rotY = isAnimating ? _diceRotateY.value : 0.0;
        final scale = isAnimating ? _diceScale.value : 1.0;

        return Transform.scale(
          scale: scale,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.003)
              ..rotateX(rotX)
              ..rotateY(rotY),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.24),
                gradient: LinearGradient(
                  colors: isActive
                      ? const [Colors.white, Color(0xFFF8FAFC), Color(0xFFDCE3EE)]
                      : [
                          widget.isDark ? const Color(0xFF3A4A68) : const Color(0xFFEFF2F6),
                          widget.isDark ? const Color(0xFF212C42) : const Color(0xFFD2D9E4),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: isActive
                      ? (widget.canRoll ? const Color(0xFFFFD700) : color.primary)
                      : (widget.isDark ? const Color(0xFF55688C) : const Color(0xFF8C99AC)),
                  width: isActive ? 2.4 : 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isActive
                        ? (widget.canRoll
                            ? const Color(0xFFFFD700).withOpacity(0.55)
                            : color.primary.withOpacity(0.45))
                        : Colors.black.withOpacity(widget.isDark ? 0.30 : 0.14),
                    blurRadius: isActive ? size * 0.24 : 5,
                    offset: Offset(0, size * 0.06),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.all(size * 0.18),
                    child: _renderPips(
                      _displayDice,
                      isActive
                          ? (widget.isDark ? const Color(0xFF0B1220) : const Color(0xFF1E293B))
                          : (widget.isDark ? const Color(0xFFD3DCEB) : const Color(0xFF5A6879)),
                      size * 0.17,
                    ),
                  ),

                  // Small corner affordance, kept clear of the pips so the face
                  // stays readable.
                  if (isActive && widget.canRoll && !isAnimating)
                    Positioned(
                      right: -size * 0.02,
                      bottom: -size * 0.02,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: size * 0.10,
                          vertical: size * 0.03,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700),
                          borderRadius: BorderRadius.circular(size * 0.10),
                          border: Border.all(
                            color: widget.isDark ? const Color(0xFF0B1220) : Colors.white,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          'TAP',
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: max(7.0, size * 0.14),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _renderPips(int val, Color dotColor, double pipSize) {
    Widget pip([double scale = 1.0]) => Container(
          width: pipSize * scale,
          height: pipSize * scale,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.28),
                blurRadius: pipSize * 0.16,
                offset: Offset(0, pipSize * 0.07),
              ),
            ],
          ),
        );

    Widget pairRow() => Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [pip(), pip()],
        );

    switch (val) {
      case 1:
        return Center(child: pip(1.4));
      case 2:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(children: [pip(), const Spacer()]),
            Column(children: [const Spacer(), pip()]),
          ],
        );
      case 3:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(children: [pip(), const Spacer()]),
            Center(child: pip()),
            Column(children: [const Spacer(), pip()]),
          ],
        );
      case 4:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [pairRow(), pairRow()],
        );
      case 5:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [pairRow(), Center(child: pip()), pairRow()],
        );
      case 6:
      default:
        return Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [pairRow(), pairRow(), pairRow()],
        );
    }
  }
}
