import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/env.dart';
import '../../models/ludo_color.dart';
import '../../models/token.dart';
import '../../services/haptics_service.dart';

/// Large 3D glossy pawn (§9) — a real game-piece silhouette, not a circle.
///
/// * Classic pawn profile: round head, tapered body, stepped base.
/// * Vertical gloss gradient + top-left specular + soft ground shadow.
/// * Color-blind double-coding: a unique emblem glyph (▲ ● ★ ■) baked onto
///   the body, plus staggered luminance per color.
/// * Movable pawns get a pulsing golden halo + gentle bounce.
class TokenWidget extends StatefulWidget {
  final Token token;
  final double size;
  final bool isMovable;

  /// Gold follow ring for the last committed move (§F).
  final bool isLastMoved;
  final VoidCallback? onTap;

  const TokenWidget({
    super.key,
    required this.token,
    required this.size,
    this.isMovable = false,
    this.isLastMoved = false,
    this.onTap,
  });

  @override
  State<TokenWidget> createState() => _TokenWidgetState();
}

class _TokenWidgetState extends State<TokenWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  void _startPulse() {
    // In widget tests an endlessly repeating animation would make
    // pumpAndSettle() hang, so settle the controller once instead.
    if (isFlutterTest) {
      _pulseController.forward();
    } else {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isMovable) _startPulse();
  }

  @override
  void didUpdateWidget(covariant TokenWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isMovable != oldWidget.isMovable) {
      if (widget.isMovable) {
        _startPulse();
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
    final w = widget.size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pad = (math.max(48.0, w) - w) / 2;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final bounce = widget.isMovable ? _pulseScale.value : 1.0;
            return Transform.scale(
              scale: bounce,
              // Pop-up lift while selectable so it reads from afar.
              child: Transform.translate(
                offset: widget.isMovable
                    ? Offset(0, -w * 0.9 * (_pulseScale.value - 1.0))
                    : Offset.zero,
                child: SizedBox(
                  width: w,
                  height: w,
                  child: CustomPaint(
                    size: Size(w, w),
                    painter: _PawnPainter(
                      color: widget.token.color,
                      isHome: widget.token.isHome,
                      number: widget.token.id + 1,
                      selectable: widget.isMovable,
                      isLastMoved: widget.isLastMoved,
                      shadow: isDark ? 0.42 : 0.30,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Positioned(
          left: -pad,
          top: -pad,
          right: -pad,
          bottom: -pad,
          child: GestureDetector(
            onTap: _handleTap,
            behavior: HitTestBehavior.opaque,
          ),
        ),
      ],
    );
  }
}

class _PawnPainter extends CustomPainter {
  final LudoColor color;
  final bool isHome;
  final int number;
  final bool selectable;
  final bool isLastMoved;
  final double shadow;

  _PawnPainter({
    required this.color,
    required this.isHome,
    required this.number,
    required this.selectable,
    this.isLastMoved = false,
    required this.shadow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final cx = w / 2;

    // Soft ground shadow.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, w * 0.90),
        width: w * 0.66,
        height: w * 0.15,
      ),
      Paint()
        ..color = Colors.black.withOpacity(shadow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.06),
    );

    // Last-move follow ring (§F): a crisp gold oval at the pawn's feet.
    if (isLastMoved && !selectable) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, w * 0.50),
            width: w * 1.04,
            height: w * 1.08),
        Paint()
          ..color = const Color(0xFFF2C14E).withOpacity(0.95)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.2, w * 0.06),
      );
    }

    // Selectable golden halo.
    if (selectable) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, w * 0.50),
            width: w * 1.18,
            height: w * 1.22),
        Paint()
          ..color = const Color(0xFFF2C14E).withOpacity(0.55)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.08),
      );
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, w * 0.50),
            width: w * 1.02,
            height: w * 1.06),
        Paint()
          ..color = Colors.white.withOpacity(0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.0, w * 0.05),
      );
    }

    // Body: tapered pawn torso with rounded shoulders.
    final body = Path()
      ..moveTo(cx - w * 0.30, w * 0.86)
      ..lineTo(cx - w * 0.155, w * 0.46)
      ..quadraticBezierTo(
          cx - w * 0.14, w * 0.40, cx - w * 0.10, w * 0.385)
      ..lineTo(cx + w * 0.10, w * 0.385)
      ..quadraticBezierTo(
          cx + w * 0.14, w * 0.40, cx + w * 0.155, w * 0.46)
      ..lineTo(cx + w * 0.30, w * 0.86)
      ..quadraticBezierTo(cx, w * 0.92, cx - w * 0.30, w * 0.86)
      ..close();
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          colors: [color.lightGlow, color.primary, color.darkShade],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(body.getBounds()),
    );
    // Belly shading (lower crescent) for roundness.
    canvas.save();
    canvas.clipPath(body);
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx + w * 0.10, w * 0.86),
          width: w * 0.62,
          height: w * 0.50),
      Paint()..color = Colors.black.withOpacity(0.20),
    );
    // Gloss stripe down the left of the torso.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx - w * 0.13, w * 0.62),
          width: w * 0.10,
          height: w * 0.30),
      Paint()..color = Colors.white.withOpacity(0.45),
    );
    canvas.restore();
    // Crisp rim.
    canvas.drawPath(
      body,
      Paint()
        ..color = color.darkShade
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.6, w * 0.045),
    );

    // Collar ring under the head.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, w * 0.40), width: w * 0.30, height: w * 0.10),
      Paint()..color = color.darkShade,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, w * 0.392),
          width: w * 0.30,
          height: w * 0.085),
      Paint()..color = color.lightGlow,
    );

    // Head: glossy ball.
    final headC = Offset(cx, w * 0.245);
    final headR = w * 0.155;
    canvas.drawCircle(
      headC,
      headR,
      Paint()
        ..shader = RadialGradient(
          colors: [color.orbHighlight, color.primary, color.darkShade],
          stops: const [0.0, 0.5, 1.0],
          center: const Alignment(-0.35, -0.4),
          radius: 1.1,
        ).createShader(Rect.fromCircle(center: headC, radius: headR)),
    );
    canvas.drawCircle(
      headC,
      headR,
      Paint()
        ..color = color.darkShade
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, w * 0.04),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: headC + Offset(-headR * 0.32, -headR * 0.38),
        width: headR * 0.85,
        height: headR * 0.55,
      ),
      Paint()..color = Colors.white.withOpacity(0.8),
    );

    // Stepped base.
    final base = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - w * 0.30, w * 0.82, w * 0.60, w * 0.10),
      Radius.circular(w * 0.05),
    );
    canvas.drawRRect(
      base,
      Paint()
        ..shader = LinearGradient(
          colors: [color.primary, color.darkShade],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(base.outerRect),
    );
    canvas.drawRRect(
      base,
      Paint()
        ..color = Colors.white.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, w * 0.025),
    );

    // Shape-coded emblem on the belly (color-blind aid).
    _emblemText(
      canvas,
      Offset(cx, w * 0.60),
      color.emblemGlyph,
      w * 0.20,
      Colors.white.withOpacity(0.92),
    );

    if (number == 0) {
      // Avatar mode: bold emblem, nothing else.
      _emblemText(canvas, Offset(cx, w * 0.62), color.emblemGlyph,
          w * 0.30, Colors.white);
    } else if (isHome) {
      _star(canvas, Offset(cx, w * 0.74), w * 0.10,
          Paint()..color = Colors.white);
    } else {
      _number(canvas, Offset(cx, w * 0.755), '$number', w);
    }
  }

  void _number(Canvas canvas, Offset centre, String value, double w) {
    final face = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: Colors.white,
          fontSize: w * 0.15,
          fontWeight: FontWeight.w900,
          height: 1.0,
          shadows: const [Shadow(color: Colors.black54, blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    face.paint(canvas, centre - Offset(face.width / 2, face.height / 2));
  }

  void _emblemText(
      Canvas canvas, Offset centre, String glyph, double fontSize, Color col) {
    final tp = TextPainter(
      text: TextSpan(
        text: glyph,
        style: TextStyle(
            color: col,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            height: 1.0,
            shadows: const [Shadow(color: Colors.black38, blurRadius: 2)]),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
  }

  void _star(Canvas canvas, Offset centre, double outer, Paint paint) {
    final inner = outer * 0.46;
    final path = Path();
    const points = 5;
    final step = math.pi / points;
    for (int i = 0; i < points * 2; i++) {
      final rad = i.isEven ? outer : inner;
      final angle = i * step - math.pi / 2;
      final x = centre.dx + rad * math.cos(angle);
      final y = centre.dy + rad * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PawnPainter old) =>
      old.color != color ||
      old.isHome != isHome ||
      old.number != number ||
      old.selectable != selectable ||
      old.isLastMoved != isLastMoved;
}

/// Compact pawn avatar for player cards.
class PinAvatar extends StatelessWidget {
  final LudoColor color;
  final double size;
  final bool isDark;

  const PinAvatar({
    super.key,
    required this.color,
    required this.size,
    this.isDark = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PawnPainter(
          color: color,
          isHome: false,
          number: 0,
          selectable: false,
          shadow: isDark ? 0.35 : 0.22,
        ),
      ),
    );
  }
}
