import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/ludo_color.dart';
import '../../models/player.dart';
import '../../services/haptics_service.dart';
import '../board/token_widget.dart';

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
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              // Flat surface: identity comes from the stripe and outline,
              // not a colour wash.
              color: widget.isDark
                  ? (widget.isCurrentTurn ? const Color(0xFF1B2942) : const Color(0xFF141E33))
                  : (widget.isCurrentTurn ? Colors.white : const Color(0xFFF3EEE4)),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.isCurrentTurn
                    ? color.primary
                    : (widget.isDark ? const Color(0xFF32415E) : const Color(0xFFD8D1C2)),
                width: widget.isCurrentTurn ? 2.6 : 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(widget.isDark ? 0.30 : 0.08),
                  blurRadius: widget.isCurrentTurn ? 12 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            // Sizes are derived from the real inner box so the card can never
            // overflow on narrow phones.
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availH = constraints.maxHeight;

                final gap = (availH * 0.05).clamp(3.0, 7.0).toDouble();
                final diceSize = (availH * 0.52).clamp(30.0, 54.0).toDouble();
                final pinSize = (availH * 0.46).clamp(24.0, 42.0).toDouble();
                final nameSize = (availH * 0.17).clamp(11.0, 17.0).toDouble();
                final dotSize = (availH * 0.10).clamp(6.0, 11.0).toDouble();

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name row, full width so it never has to be truncated.
                    SizedBox(
                      height: nameSize * 1.25,
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
                                color: widget.isDark
                                    ? Colors.white
                                    : const Color(0xFF111827),
                              ),
                            ),
                          ),
                          if (isFinished) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: color.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _rankMedal(widget.player.finishRank ?? 1),
                                style: TextStyle(
                                  fontSize: max(8.0, nameSize * 0.60),
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ] else if (widget.isCurrentTurn) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: color.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'TURN',
                                style: TextStyle(
                                  fontSize: max(7.0, nameSize * 0.52),
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
                    SizedBox(height: gap),
                    // Pin avatar, piece progress and the dice.
                    Row(
                      children: [
                        PinAvatar(
                          color: color,
                          size: pinSize,
                          isDark: widget.isDark,
                        ),
                        SizedBox(width: gap * 1.6),
                        Expanded(
                          child: _buildTokenProgress(color, dotSize),
                        ),
                        SizedBox(width: gap),
                        _buildDice(color, diceSize, glow),
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

  /// Four segments that share the available width, so the progress readout can
  /// never overflow the card however narrow it gets.
  Widget _buildTokenProgress(LudoColor color, double dotSize) {
    return Row(
      children: widget.player.tokens.map((t) {
        Color fill;
        IconData? icon;

        if (t.isHome) {
          fill = const Color(0xFFFFD43B);
          icon = Icons.star_rounded;
        } else if (t.isInBase) {
          fill = widget.isDark ? const Color(0xFF39465E) : const Color(0xFFC8CFD9);
        } else {
          fill = color.primary;
        }

        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: dotSize * 0.30),
            height: dotSize,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(dotSize * 0.5),
            ),
            child: icon == null
                ? null
                : Center(
                    child: Icon(icon, size: dotSize * 0.72, color: Colors.black87),
                  ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDice(LudoColor color, double size, double glow) {
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
                borderRadius: BorderRadius.circular(size * 0.22),
                color: isActive
                    ? Colors.white
                    : (widget.isDark ? const Color(0xFFC3CBD8) : const Color(0xFFDCE1E9)),
                border: Border.all(
                  color: isActive
                      ? color.primary
                      : (widget.isDark ? const Color(0xFF5C6E8E) : const Color(0xFF9AA4B4)),
                  width: isActive ? 2.6 : 1.6,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(widget.isDark ? 0.32 : 0.14),
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.all(size * 0.20),
                child: _renderPips(
                  _displayDice,
                  isActive
                      ? (widget.isDark ? const Color(0xFF16233B) : const Color(0xFF1F2937))
                      : const Color(0xFF5A6473),
                  size * 0.18,
                ),
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
        // Expanded middle makes the row overflow-proof by construction:
        // fixed content is only 2 pips wide, the rest is flexible.
        return Row(
          children: [
            Column(children: [pip(), const Spacer()]),
            Expanded(child: Center(child: pip())),
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
