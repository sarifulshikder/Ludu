import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/ludo_color.dart';
import '../../models/token.dart';
import '../../services/haptics_service.dart';

/// A token rendered as a physical, domed game piece: metallic rim, lit dome,
/// specular hotspot, bounce light and a soft contact shadow.
class TokenWidget extends StatefulWidget {
  final Token token;
  final double size;
  final bool isMovable;
  final VoidCallback? onTap;

  const TokenWidget({
    super.key,
    required this.token,
    required this.size,
    this.isMovable = false,
    this.onTap,
  });

  @override
  State<TokenWidget> createState() => _TokenWidgetState();
}

class _TokenWidgetState extends State<TokenWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.16).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isMovable) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant TokenWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isMovable != oldWidget.isMovable) {
      if (widget.isMovable) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.isMovable) return;
    HapticsService.medium();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    // Keep a comfortable minimum touch target even when the piece is small.
    final hit = math.max(widget.size, 44.0);

    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: hit,
        height: hit,
        child: Center(
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.isMovable ? _pulseScale.value : 1.0,
                child: CustomPaint(
                  size: Size.square(widget.size),
                  painter: _TokenPainter(
                    color: widget.token.color,
                    isHome: widget.token.isHome,
                    number: widget.token.id + 1,
                    glow: widget.isMovable ? 1.0 : 0.0,
                    size: widget.size,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TokenPainter extends CustomPainter {
  final LudoColor color;
  final bool isHome;
  final int number;
  final double glow;

  /// Diameter of the piece, so the glyph scales with it.
  final double size;

  _TokenPainter({
    required this.color,
    required this.isHome,
    required this.number,
    required this.glow,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2;
    if (r <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);

    // 1. Contact shadow on the board.
    canvas.drawCircle(
      center.translate(0, r * 0.14),
      r * 0.96,
      Paint()
        ..color = Colors.black.withOpacity(0.42)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.20),
    );

    // 2. Movable halo.
    if (glow > 0) {
      canvas.drawCircle(
        center,
        r * 1.10,
        Paint()
          ..color = color.lightGlow.withOpacity(0.42 * glow)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.26),
      );
    }

    // 3. Metallic rim, lit from the top-left.
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.45, -0.55),
          radius: 1.05,
          colors: const [
            Color(0xFFFFFFFF),
            Color(0xFFE2E8F0),
            Color(0xFF94A3B8),
            Color(0xFF475569),
            Color(0xFFCBD5E1),
          ],
          stops: const [0.0, 0.30, 0.62, 0.88, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );

    // 4. Domed face in the player colour.
    final faceR = r * 0.80;
    canvas.drawCircle(
      center,
      faceR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.45),
          radius: 1.15,
          colors: [
            color.lightGlow,
            color.primary,
            color.darkShade,
          ],
          stops: const [0.0, 0.52, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: faceR)),
    );

    // 5. Occlusion around the lower-right of the dome.
    canvas.drawCircle(
      center,
      faceR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.55, 0.65),
          radius: 0.95,
          colors: [
            Colors.black.withOpacity(0.34),
            Colors.transparent,
          ],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: faceR)),
    );

    // 6. Bounce light along the bottom-right edge.
    canvas.drawCircle(
      center,
      faceR,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.transparent, Colors.white.withOpacity(0.34)],
          stops: const [0.45, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: faceR))
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.10,
    );

    // 7. Specular hotspot.
    canvas.drawCircle(
      center.translate(-faceR * 0.34, -faceR * 0.40),
      faceR * 0.26,
      Paint()
        ..color = Colors.white.withOpacity(0.72)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, faceR * 0.12),
    );

    // 8. Glyph.
    if (isHome) {
      _paintStar(canvas, center, faceR * 0.62, const Color(0xFFFFD700));
    } else {
      _paintText(canvas, center, '$number');
    }
  }

  void _paintText(Canvas canvas, Offset center, String value) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.40,
          fontWeight: FontWeight.w900,
          height: 1.0,
          letterSpacing: -0.5,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.55),
              blurRadius: 3,
              offset: const Offset(0, 1.5),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  void _paintStar(Canvas canvas, Offset center, double outer, Color tint) {
    final inner = outer * 0.46;
    final path = Path();
    const points = 5;
    final step = math.pi / points;
    for (int i = 0; i < points * 2; i++) {
      final radius = (i.isEven) ? outer : inner;
      final angle = i * step - math.pi / 2;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(
      path.shift(const Offset(0, 1.2)),
      Paint()
        ..color = Colors.black.withOpacity(0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawPath(path, Paint()..color = tint);
  }

  @override
  bool shouldRepaint(covariant _TokenPainter old) =>
      old.color != color ||
      old.isHome != isHome ||
      old.number != number ||
      old.glow != glow ||
      old.size != size;
}
