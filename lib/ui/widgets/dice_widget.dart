import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/env.dart';
import '../../core/theme/ludu_theme.dart';
import '../../models/game_settings.dart';
import '../../models/ludo_color.dart';
import '../../services/audio_service.dart';
import '../../services/haptics_service.dart';

/// Grand 3D Single Dice (96–110 dp).
///
/// * Only ONE large dice exists on screen.
/// * Glides smoothly to the active player's corner.
/// * Null [value] draws a neutral face before the roll.
/// * Pulses gently while waiting for a tap.
/// * Supports face-to-face rotation [isRotated].
/// * Styled to match the active theme (Royal Gold, Neon Glass, Wooden Luxe).
class DiceWidget extends StatefulWidget {
  final int? value;
  final bool isRolling;
  final bool canRoll;
  final LudoColor activeColor;
  final VoidCallback onRoll;
  final double size;
  final double timeScale;
  final bool isRotated;
  final AppThemeMode themeMode;
  final LuduThemeConfig? themeConfig;

  const DiceWidget({
    super.key,
    required this.value,
    required this.isRolling,
    required this.canRoll,
    required this.activeColor,
    required this.onRoll,
    this.size = 100,
    this.timeScale = 1.0,
    this.isRotated = false,
    this.themeMode = AppThemeMode.royalGold,
    this.themeConfig,
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
  final math.Random _random = math.Random();

  static bool get _inTest => isFlutterTest;

  Duration get _tossDuration => Duration(
      milliseconds: (1100 * widget.timeScale).round().clamp(400, 2000));

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value;
    _tossController = AnimationController(
      vsync: this,
      duration: _tossDuration,
    );
    _jump = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.0, end: -22.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 22),
      TweenSequenceItem(
          tween: Tween<double>(begin: -22.0, end: 0.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 26),
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.0, end: -12.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 22),
      TweenSequenceItem(
          tween: Tween<double>(begin: -12.0, end: 0.0)
              .chain(CurveTween(curve: Curves.bounceOut)),
          weight: 30),
    ]).animate(_tossController);

    _wobble = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.0, end: 0.24), weight: 25),
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.24, end: -0.20), weight: 25),
      TweenSequenceItem(
          tween: Tween<double>(begin: -0.20, end: 0.12), weight: 25),
      TweenSequenceItem(
          tween: Tween<double>(begin: 0.12, end: 0.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _tossController, curve: Curves.easeInOut));

    _punch = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.0, end: 1.18), weight: 55),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1.18, end: 1.0)
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
    if (!_tossController.isAnimating && widget.value != oldWidget.value) {
      setState(() => _displayValue = widget.value);
    }
    _syncIdlePulse();
  }

  void _handleTap() {
    if (!widget.canRoll || _tossController.isAnimating) return;
    HapticsService.medium();
    _shuffleTimer?.cancel();
    final interval = (120 * widget.timeScale).round().clamp(60, 200);
    _shuffleTimer = Timer.periodic(Duration(milliseconds: interval), (_) {
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
    final cfg = widget.themeConfig ?? LuduTheme.forMode(widget.themeMode);
    final themeColor = cfg.colorOf(widget.activeColor);
    final s = widget.size;

    Widget diceWidget = GestureDetector(
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
          final idleLift = idle ? -3.5 * (_idlePulse.value - 1.0) / 0.06 : 0.0;

          // Theme styling colors
          final bodyColors = widget.themeMode == AppThemeMode.neonGlass
              ? [const Color(0xFF132244), const Color(0xFF091428)]
              : widget.themeMode == AppThemeMode.woodenLuxe
                  ? [const Color(0xFFFAF3E3), const Color(0xFFE5D5BA)]
                  : [const Color(0xFFFFFFFF), const Color(0xFFF5EEDB), const Color(0xFFDDD2BA)];

          final borderColor = widget.canRoll
              ? themeColor.primary
              : cfg.diceBorderColor;

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
                    gradient: LinearGradient(
                      colors: bodyColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(s * 0.22),
                    border: Border.all(
                      color: borderColor,
                      width: widget.canRoll ? 3.5 : 1.8,
                    ),
                    boxShadow: [
                      if (widget.canRoll)
                        BoxShadow(
                          color: themeColor.primary.withOpacity(0.55),
                          blurRadius: 28,
                          spreadRadius: 3,
                          offset: const Offset(0, 6),
                        ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.42),
                        blurRadius: 14,
                        offset: Offset(0, 5 + (tossing ? 6 : 0)),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Specular gloss reflection across top
                      Positioned(
                        left: s * 0.10,
                        right: s * 0.10,
                        top: s * 0.06,
                        height: s * 0.26,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0.75),
                                Colors.transparent
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(s * 0.12),
                          ),
                        ),
                      ),
                      // Pips or neutral face
                      Center(
                        child: SizedBox(
                          width: s * 0.74,
                          height: s * 0.74,
                          child: CustomPaint(
                            painter: _DiceFacePainter(
                              _displayValue,
                              themeColor,
                              cfg,
                              widget.themeMode,
                            ),
                          ),
                        ),
                      ),
                      // Active turn glowing indicator dot
                      if (widget.canRoll)
                        Positioned(
                          right: s * 0.09,
                          top: s * 0.09,
                          child: Container(
                            width: s * 0.12,
                            height: s * 0.12,
                            decoration: BoxDecoration(
                              color: themeColor.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: themeColor.primary.withOpacity(0.9),
                                  blurRadius: 8,
                                ),
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

    if (widget.isRotated) {
      diceWidget = Transform.rotate(
        angle: math.pi,
        child: diceWidget,
      );
    }

    return diceWidget;
  }
}

class _DiceFacePainter extends CustomPainter {
  /// Null draws the neutral blank/emblem face (shown before rolling).
  final int? value;
  final ThemePlayerColor themeColor;
  final LuduThemeConfig config;
  final AppThemeMode themeMode;

  _DiceFacePainter(
    this.value,
    this.themeColor,
    this.config,
    this.themeMode,
  );

  @override
  void paint(Canvas canvas, Size size) {
    if (value == null) {
      // Neutral face: clean luxury emblem (star/diamond/medallion)
      _drawNeutralFace(canvas, size);
      return;
    }

    final dotR = size.width * 0.135;
    void pip(double x, double y) {
      final c = Offset(x * size.width, y * size.height);
      // Soft pip drop shadow
      canvas.drawCircle(
        c + const Offset(0, 1.5),
        dotR,
        Paint()..color = Colors.black.withOpacity(0.28),
      );

      final pipColor = themeMode == AppThemeMode.neonGlass
          ? themeColor.primary
          : themeColor.darkShade;

      canvas.drawCircle(c, dotR, Paint()..color = pipColor);

      // Specular highlight on pip
      canvas.drawCircle(
        c + Offset(-dotR * 0.28, -dotR * 0.32),
        dotR * 0.34,
        Paint()..color = Colors.white.withOpacity(0.85),
      );

      // Pip rim
      canvas.drawCircle(
        c,
        dotR,
        Paint()
          ..color = themeColor.primary
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

  void _drawNeutralFace(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.30;

    // Outer subtle ring
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = config.diceNeutralEmblem.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Centered luxury star/diamond emblem
    final path = Path();
    const points = 4;
    final step = math.pi / points;
    for (int i = 0; i < points * 2; i++) {
      final rad = i.isEven ? r * 0.80 : r * 0.35;
      final angle = i * step - math.pi / 2;
      final x = c.dx + rad * math.cos(angle);
      final y = c.dy + rad * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(
      path,
      Paint()..color = config.diceNeutralEmblem.withOpacity(0.85),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withOpacity(0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant _DiceFacePainter old) =>
      old.value != value ||
      old.themeColor != themeColor ||
      old.themeMode != themeMode;
}
