import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/env.dart';
import '../../models/ludo_color.dart';
import '../../services/audio_service.dart';
import '../../services/haptics_service.dart';

/// Aurora grand dice — big ivory cube with player-tinted glow.
///
/// * Null [value] draws a neutral blank face: shown until a player rolls.
/// * The active player's dice gently pulses/bounces while tappable.
/// * Roll animation reads like a real tabletop toss: faces shuffle while
///   the die jumps twice with a wobble, then lands with an elastic pop
///   plus a result sound. Repeating pulse controllers never run in widget
///   tests, so they can always settle.
class DiceWidget extends StatefulWidget {
  final int? value;
  final bool isRolling;
  final bool canRoll;
  final LudoColor activeColor;
  final VoidCallback onRoll;
  final double size;

  /// Animation duration multiplier (1.0 normal, ~0.55 fast).
  final double timeScale;

  const DiceWidget({
    super.key,
    required this.value,
    required this.isRolling,
    required this.canRoll,
    required this.activeColor,
    required this.onRoll,
    this.size = 96,
    this.timeScale = 1.0,
  });

  @override
  State<DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends State<DiceWidget>
    with TickerProviderStateMixin {
  late AnimationController _tossController;
  late Animation<double> _jump;
  late Animation<double> _wobble;
  late Animation<double> _punch;

  /// Gentle attract pulse while the dice awaits a tap.
  late AnimationController _idleController;
  late Animation<double> _idlePulse;

  int? _displayValue = 1;
  Timer? _shuffleTimer;
  final Random _random = Random();

  static bool get _inTest => isFlutterTest;

  Duration get _tossDuration => Duration(
      milliseconds: (720 * widget.timeScale).round().clamp(200, 1200));

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value;
    _tossController = AnimationController(
      vsync: this,
      duration: _tossDuration,
    );
    // Two jumps: up-down-up-down over the toss.
    _jump = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.0, end: -20.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 22),
      TweenSequenceItem(
          tween: Tween<double>(begin: -20.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 26),
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.0, end: -11.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 22),
      TweenSequenceItem(
          tween: Tween<double>(begin: -11.0, end: 0.0)
              .chain(CurveTween(curve: Curves.bounceOut)),
          weight: 30),
    ]).animate(_tossController);
    // Playful tilt wobble while airborne.
    _wobble = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.0, end: 0.22), weight: 25),
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.22, end: -0.18), weight: 25),
      TweenSequenceItem(
          tween: Tween<double>(begin: -0.18, end: 0.10), weight: 25),
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.10, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _tossController, curve: Curves.easeInOut));
    // Elastic landing pop.
    _punch = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.16), weight: 55),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.16, end: 1.0)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 45),
    ]).animate(_tossController);

    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _idlePulse = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _idleController, curve: Curves.easeInOut),
    );
    _syncIdlePulse();

    _tossController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shuffleTimer?.cancel();
        setState(() => _displayValue = widget.value);
        HapticsService.light();
        AudioService.playDiceResult();
        _syncIdlePulse();
      }
    });
  }

  /// The attract pulse runs only while a tap is awaited (never mid-toss,
  /// never in widget tests so they can settle).
  void _syncIdlePulse() {
    final want = widget.canRoll &&
        !_tossController.isAnimating &&
        !_inTest;
    if (want && !_idleController.isAnimating) {
      _idleController.repeat(reverse: true);
    } else if (!want && _idleController.isAnimating) {
      _idleController.stop();
      _idleController.reset();
    }
  }

  @override
  void didUpdateWidget(covariant DiceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timeScale != widget.timeScale) {
      _tossController.duration = _tossDuration;
    }
    // Keep the settled face in sync; never fight the running shuffle.
    if (!_tossController.isAnimating && widget.value != oldWidget.value) {
      setState(() => _displayValue = widget.value);
    }
    _syncIdlePulse();
  }

  void _handleTap() {
    if (!widget.canRoll || _tossController.isAnimating) return;
    HapticsService.medium();
    // Shuffle faces like a tumbling die until it lands.
    _shuffleTimer?.cancel();
    final interval =
        (70 * widget.timeScale).round().clamp(30, 120);
    _shuffleTimer =
        Timer.periodic(Duration(milliseconds: interval), (_) {
      setState(() => _displayValue = _random.nextInt(6) + 1);
    });
    _tossController.forward(from: 0.0);
    widget.onRoll();
    _syncIdlePulse();
  }

  @override
  void dispose() {
    _shuffleTimer?.cancel();
    _tossController.dispose();
    _idleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.activeColor;
    final s = widget.size;

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([_tossController, _idleController]),
        builder: (context, child) {
          final tossing = _tossController.isAnimating;
          final idle = !tossing &&
              widget.canRoll &&
              _idleController.isAnimating;
          final idleScale = idle ? _idlePulse.value : 1.0;
          final idleLift = idle ? -3.0 * (_idlePulse.value - 1.0) / 0.06 : 0.0;
          return Transform.translate(
            offset: Offset(0, (tossing ? _jump.value : 0.0) + idleLift),
            child: Transform.rotate(
              angle: tossing ? _wobble.value : 0.0,
              child: Transform.scale(
                scale: (tossing ? _punch.value : 1.0) * idleScale,
                child: Container(
                  width: s,
                  height: s,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFFFFF),
                        Color(0xFFF6EFDD),
                        Color(0xFFD5CDB6)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(s * 0.24),
                    border: Border.all(
                      color: widget.canRoll
                          ? color.lightGlow
                          : Colors.white.withOpacity(0.85),
                      width: widget.canRoll ? 4.0 : 2.0,
                    ),
                    boxShadow: [
                      if (widget.canRoll)
                        BoxShadow(
                          color: color.primary.withOpacity(0.55),
                          blurRadius: 26,
                          spreadRadius: 4,
                          offset: const Offset(0, 8),
                        ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 12,
                        offset: Offset(0, 5 + (tossing ? 6 : 0)),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Glass sheen across the top.
                      Positioned(
                        left: s * 0.12,
                        right: s * 0.12,
                        top: s * 0.07,
                        height: s * 0.24,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.8),
                                Colors.transparent
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius:
                                BorderRadius.circular(s * 0.12),
                          ),
                        ),
                      ),
                      Center(
                        child: SizedBox(
                          width: s * 0.74,
                          height: s * 0.74,
                          child: CustomPaint(
                            painter: _DiceFacePainter(
                                _displayValue, color),
                          ),
                        ),
                      ),
                      if (widget.canRoll)
                        Positioned(
                          right: s * 0.09,
                          top: s * 0.09,
                          child: Container(
                            width: s * 0.13,
                            height: s * 0.13,
                            decoration: BoxDecoration(
                              color: color.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color: color.primary
                                        .withOpacity(0.8),
                                    blurRadius: 8),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DiceFacePainter extends CustomPainter {
  /// Null draws the neutral blank face (shown before the first roll).
  final int? value;
  final LudoColor color;
  _DiceFacePainter(this.value, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (value == null) return;
    // Flat, high-contrast pips — readable mid-tumble and at a glance.
    final dotR = size.width * 0.135;
    void pip(double x, double y) {
      final c = Offset(x * size.width, y * size.height);
      canvas.drawCircle(c + const Offset(0, 1.6), dotR,
          Paint()..color = Colors.black.withOpacity(0.28));
      canvas.drawCircle(c, dotR, Paint()..color = color.primary);
      canvas.drawCircle(
        c + Offset(-dotR * 0.28, -dotR * 0.32),
        dotR * 0.34,
        Paint()..color = Colors.white.withOpacity(0.9),
      );
      canvas.drawCircle(
        c,
        dotR,
        Paint()
          ..color = color.darkShade
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    switch (value) {
      case 1:
        pip(0.5, 0.5);
        break;
      case 2:
        pip(0.27, 0.27);
        pip(0.73, 0.73);
        break;
      case 3:
        pip(0.27, 0.27);
        pip(0.5, 0.5);
        pip(0.73, 0.73);
        break;
      case 4:
        pip(0.27, 0.27);
        pip(0.73, 0.27);
        pip(0.27, 0.73);
        pip(0.73, 0.73);
        break;
      case 5:
        pip(0.27, 0.27);
        pip(0.73, 0.27);
        pip(0.5, 0.5);
        pip(0.27, 0.73);
        pip(0.73, 0.73);
        break;
      case 6:
      default:
        pip(0.28, 0.20);
        pip(0.72, 0.20);
        pip(0.28, 0.50);
        pip(0.72, 0.50);
        pip(0.28, 0.80);
        pip(0.72, 0.80);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _DiceFacePainter old) =>
      old.value != value || old.color != color;
}
