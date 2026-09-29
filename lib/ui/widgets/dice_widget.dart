import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/ludo_color.dart';
import '../../services/haptics_service.dart';

/// Aurora grand dice — 84dp default, ivory cube with player-tinted glow.
///
/// * Smooth 700ms 3D tumble (rotateX/Y + scale punch + face shuffle).
/// * Glossy 3D pips in the active player's color.
/// * Pulsing glow ring when rollable so the current player spots it instantly.
class DiceWidget extends StatefulWidget {
  final int? value;
  final bool isRolling;
  final bool canRoll;
  final LudoColor activeColor;
  final VoidCallback onRoll;
  final double size;

  const DiceWidget({
    super.key,
    required this.value,
    required this.isRolling,
    required this.canRoll,
    required this.activeColor,
    required this.onRoll,
    this.size = 84,
  });

  @override
  State<DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends State<DiceWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _rotationX;
  late Animation<double> _rotationY;
  late Animation<double> _scale;
  late Animation<double> _glowPulse;

  int _displayValue = 1;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value ?? 1;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _setupAnimation();
    _animController.addListener(() {
      if (_animController.isAnimating && _random.nextDouble() > 0.55) {
        setState(() => _displayValue = _random.nextInt(6) + 1);
      }
    });
    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _displayValue = widget.value ?? 1);
        HapticsService.light();
      }
    });
  }

  void _setupAnimation() {
    final curved = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _rotationX = Tween<double>(begin: 0, end: 4 * pi).animate(curved);
    _rotationY = Tween<double>(begin: 0, end: 4 * pi).animate(curved);
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.22), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 1.22, end: 0.90), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 0.90, end: 1.0), weight: 30),
    ]).animate(curved);
    _glowPulse = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant DiceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != null && widget.value != oldWidget.value) {
      _displayValue = widget.value!;
    }
    if (widget.canRoll != oldWidget.canRoll) {
      if (widget.canRoll && !_animController.isAnimating) {
        // Idle breathing glow; real tumble is triggered on tap.
      }
    }
  }

  void _handleTap() {
    if (!widget.canRoll || _animController.isAnimating) return;
    HapticsService.medium();
    _animController.forward(from: 0.0);
    widget.onRoll();
  }

  @override
  void dispose() {
    _animController.dispose();
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
        animation: _animController,
        builder: (context, child) {
          final tumbling = _animController.isAnimating;
          final angleX = tumbling ? _rotationX.value : 0.0;
          final angleY = tumbling ? _rotationY.value : 0.0;
          final scale = tumbling ? _scale.value : 1.0;
          final glow = widget.canRoll ? (0.55 + 0.45 * _glowPulse.value) : 0.0;

          return Transform.scale(
            scale: scale,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0022)
                ..rotateX(angleX)
                ..rotateY(angleY),
              child: Container(
                width: s,
                height: s,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFF4EDDD), Color(0xFFD9D2C0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(s * 0.26),
                  border: Border.all(
                    color: widget.canRoll ? color.lightGlow : Colors.white.withOpacity(0.85),
                    width: widget.canRoll ? 3.5 : 2.0,
                  ),
                  boxShadow: [
                    if (widget.canRoll)
                      BoxShadow(
                        color: color.primary.withOpacity(0.55 * glow + 0.25),
                        blurRadius: 22,
                        spreadRadius: 3,
                        offset: const Offset(0, 6),
                      ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                    const BoxShadow(
                      color: Color(0xFFFFFFFF),
                      blurRadius: 2,
                      offset: Offset(0, -1),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Top glass sheen.
                    Positioned(
                      left: s * 0.12,
                      right: s * 0.12,
                      top: s * 0.07,
                      height: s * 0.22,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.white.withOpacity(0.75), Colors.transparent],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(s * 0.11),
                        ),
                      ),
                    ),
                    Center(child: _buildFace(_displayValue, color, s)),
                    if (widget.canRoll)
                      Positioned(
                        right: s * 0.08,
                        top: s * 0.08,
                        child: Container(
                          width: s * 0.13,
                          height: s * 0.13,
                          decoration: BoxDecoration(
                            color: color.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                  color: color.primary.withOpacity(0.8), blurRadius: 8),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFace(int val, LudoColor color, double s) {
    return SizedBox(
      width: s * 0.72,
      height: s * 0.72,
      child: CustomPaint(painter: _DiceFacePainter(val, color)),
    );
  }
}

class _DiceFacePainter extends CustomPainter {
  final int value;
  final LudoColor color;
  _DiceFacePainter(this.value, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final dotR = size.width * 0.13;
    void pip(double x, double y) {
      final c = Offset(x * size.width, y * size.height);
      // Shadow.
      canvas.drawCircle(c + const Offset(0, 1.6), dotR,
          Paint()..color = Colors.black.withOpacity(0.30));
      // Glossy sphere: base + highlight.
      canvas.drawCircle(
        c,
        dotR,
        Paint()
          ..shader = RadialGradient(
            colors: [color.lightGlow, color.primary, color.darkShade],
            stops: const [0.0, 0.55, 1.0],
            center: const Alignment(-0.3, -0.35),
            radius: 1.0,
          ).createShader(Rect.fromCircle(center: c, radius: dotR)),
      );
      canvas.drawCircle(
        c + Offset(-dotR * 0.3, -dotR * 0.35),
        dotR * 0.32,
        Paint()..color = Colors.white.withOpacity(0.85),
      );
    }

    switch (value) {
      case 1:
        pip(0.5, 0.5);
        break;
      case 2:
        pip(0.26, 0.26);
        pip(0.74, 0.74);
        break;
      case 3:
        pip(0.26, 0.26);
        pip(0.5, 0.5);
        pip(0.74, 0.74);
        break;
      case 4:
        pip(0.26, 0.26);
        pip(0.74, 0.26);
        pip(0.26, 0.74);
        pip(0.74, 0.74);
        break;
      case 5:
        pip(0.26, 0.26);
        pip(0.74, 0.26);
        pip(0.5, 0.5);
        pip(0.26, 0.74);
        pip(0.74, 0.74);
        break;
      case 6:
      default:
        pip(0.27, 0.20);
        pip(0.73, 0.20);
        pip(0.27, 0.50);
        pip(0.73, 0.50);
        pip(0.27, 0.80);
        pip(0.73, 0.80);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _DiceFacePainter old) =>
      old.value != value || old.color != color;
}
