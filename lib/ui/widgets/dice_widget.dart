import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/ludo_color.dart';
import '../../services/haptics_service.dart';

class DiceWidget extends StatefulWidget {
  final int? value;
  final bool isRolling;
  final bool canRoll;
  final LudoColor activeColor;
  final VoidCallback onRoll;

  const DiceWidget({
    super.key,
    required this.value,
    required this.isRolling,
    required this.canRoll,
    required this.activeColor,
    required this.onRoll,
  });

  @override
  State<DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends State<DiceWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _rotationX;
  late Animation<double> _rotationY;
  late Animation<double> _rotationZ;
  late Animation<double> _scale;

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
      if (_animController.isAnimating && _random.nextDouble() > 0.6) {
        setState(() {
          _displayValue = _random.nextInt(6) + 1;
        });
      }
    });

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _displayValue = widget.value ?? 1;
        });
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
    _rotationZ = Tween<double>(begin: 0, end: 2 * pi).animate(curved);
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.25), weight: 30),
      TweenSequenceItem(tween: Tween<double>(begin: 1.25, end: 0.9), weight: 40),
      TweenSequenceItem(tween: Tween<double>(begin: 0.9, end: 1.0), weight: 30),
    ]).animate(curved);
  }

  @override
  void didUpdateWidget(covariant DiceWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != null && widget.value != oldWidget.value) {
      _displayValue = widget.value!;
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

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          final isAnimating = _animController.isAnimating;
          final angleX = isAnimating ? _rotationX.value : 0.0;
          final angleY = isAnimating ? _rotationY.value : 0.0;
          final angleZ = isAnimating ? _rotationZ.value : 0.0;
          final scale = isAnimating ? _scale.value : 1.0;

          return Transform.scale(
            scale: scale,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.002) // Perspective depth
                ..rotateX(angleX)
                ..rotateY(angleY)
                ..rotateZ(angleZ),
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white,
                      const Color(0xFFF0F4F8),
                      const Color(0xFFD9E2EC),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: widget.canRoll ? color.lightGlow : Colors.white.withOpacity(0.8),
                    width: widget.canRoll ? 3.0 : 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.canRoll
                          ? color.primary.withOpacity(0.5)
                          : Colors.black.withOpacity(0.3),
                      blurRadius: widget.canRoll ? 16 : 8,
                      spreadRadius: widget.canRoll ? 2 : 0,
                      offset: const Offset(0, 4),
                    ),
                    const BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: _buildDiceFace(_displayValue, color),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDiceFace(int val, LudoColor color) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: CustomPaint(
          painter: _DiceFacePainter(val, color.primary),
        ),
      ),
    );
  }
}

class _DiceFacePainter extends CustomPainter {
  final int value;
  final Color dotColor;

  _DiceFacePainter(this.value, this.dotColor);

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = dotColor
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..style = PaintingStyle.fill;

    final dotRadius = size.width * 0.12;

    void drawPip(double x, double y) {
      final center = Offset(x * size.width, y * size.height);
      // Inset drop shadow
      canvas.drawCircle(center + const Offset(0, 1.2), dotRadius, shadowPaint);
      canvas.drawCircle(center, dotRadius, dotPaint);
    }

    switch (value) {
      case 1:
        drawPip(0.5, 0.5);
        break;
      case 2:
        drawPip(0.25, 0.25);
        drawPip(0.75, 0.75);
        break;
      case 3:
        drawPip(0.25, 0.25);
        drawPip(0.5, 0.5);
        drawPip(0.75, 0.75);
        break;
      case 4:
        drawPip(0.25, 0.25);
        drawPip(0.75, 0.25);
        drawPip(0.25, 0.75);
        drawPip(0.75, 0.75);
        break;
      case 5:
        drawPip(0.25, 0.25);
        drawPip(0.75, 0.25);
        drawPip(0.5, 0.5);
        drawPip(0.25, 0.75);
        drawPip(0.75, 0.75);
        break;
      case 6:
        drawPip(0.25, 0.2);
        drawPip(0.75, 0.2);
        drawPip(0.25, 0.5);
        drawPip(0.75, 0.5);
        drawPip(0.25, 0.8);
        drawPip(0.75, 0.8);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _DiceFacePainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.dotColor != dotColor;
}
