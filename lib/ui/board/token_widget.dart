import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/ludo_color.dart';
import '../../models/token.dart';
import '../../services/haptics_service.dart';

/// Geometry helpers used by the board to anchor orbs on squares.
const double kTokenPinAspect = 1.0;
const double kTokenHeadOffset = 0.5;

/// Large 3D glossy orb — completely different from the old map-pin.
///
/// * Diameter fills ~96% of a track cell, 48dp minimum tap target.
/// * Radial orb gradient + white specular + bottom bounce-light.
/// * Color-blind double-coding: unique emblem glyph (▲ ● ★ ■) watermarked
///   behind the token number, plus staggered luminance per color.
/// * Movable tokens get a pulsing golden halo + gentle bounce.
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
      duration: const Duration(milliseconds: 720),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.14).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isMovable) _pulseController.repeat(reverse: true);
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
              // Slight vertical hop while selectable so it reads from afar.
              child: Transform.translate(
                offset: widget.isMovable
                    ? Offset(0, -2.0 * (_pulseScale.value - 1.0) * 10)
                    : Offset.zero,
                child: SizedBox(
                  width: w,
                  height: w,
                  child: CustomPaint(
                    size: Size(w, w),
                    painter: _OrbPainter(
                      color: widget.token.color,
                      isHome: widget.token.isHome,
                      number: widget.token.id + 1,
                      selectable: widget.isMovable,
                      shadow: isDark ? 0.42 : 0.28,
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

class _OrbPainter extends CustomPainter {
  final LudoColor color;
  final bool isHome;
  final int number;
  final bool selectable;
  final double shadow;

  _OrbPainter({
    required this.color,
    required this.isHome,
    required this.number,
    required this.selectable,
    required this.shadow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final c = Offset(w / 2, w / 2);
    final r = w / 2;

    // Drop shadow.
    canvas.drawCircle(
      c + Offset(0, w * 0.07),
      r * 0.94,
      Paint()
        ..color = Colors.black.withOpacity(shadow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.08),
    );

    // Selectable golden halo.
    if (selectable) {
      canvas.drawCircle(
        c,
        r * 1.18,
        Paint()
          ..color = const Color(0xFFF2C14E).withOpacity(0.85)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.07),
      );
      canvas.drawCircle(
        c,
        r * 1.06,
        Paint()
          ..color = Colors.white.withOpacity(0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.0, w * 0.06),
      );
    }

    // Orb body: radial 3D gradient.
    canvas.drawCircle(
      c,
      r * 0.96,
      Paint()..shader = color.orbGradient.createShader(
        Rect.fromCircle(center: c, radius: r),
      ),
    );
    // Inner depth: darken lower-right crescent.
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r * 0.96)));
    canvas.drawCircle(
      c + Offset(r * 0.42, r * 0.46),
      r * 1.05,
      Paint()..color = Colors.black.withOpacity(0.22),
    );
    canvas.restore();

    // Crisp rim.
    canvas.drawCircle(
      c,
      r * 0.96,
      Paint()
        ..color = color.darkShade
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.6, w * 0.055),
    );
    canvas.drawCircle(
      c,
      r * 0.88,
      Paint()
        ..color = Colors.white.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, w * 0.03),
    );

    // Specular highlight (top-left gloss).
    canvas.drawEllipse(
      Rect.fromCenter(
        center: c + Offset(-r * 0.34, -r * 0.40),
        width: r * 0.95,
        height: r * 0.62,
      ),
      Paint()..color = Colors.white.withOpacity(0.75),
    );
    canvas.drawCircle(
      c + Offset(-r * 0.42, -r * 0.46),
      r * 0.14,
      Paint()..color = Colors.white.withOpacity(0.95),
    );

    // Shape-coded emblem watermark (color-blind aid).
    _emblemText(
      canvas, c + Offset(0, -r * 0.06), color.emblemGlyph, r * 1.15,
      Colors.white.withOpacity(0.30),
    );

    if (number == 0) {
      // Avatar mode: show the shape emblem boldly.
      _emblemText(canvas, c, color.emblemGlyph, r * 0.95, Colors.white);
    } else if (isHome) {
      _star(canvas, c, r * 0.52, Paint()..color = Colors.white);
      _star(canvas, c, r * 0.38, Paint()..color = color.darkShade);
    } else {
      // Token number — big, readable from across the table.
      _number(canvas, c, '$number', r);
    }
  }

  void _number(Canvas canvas, Offset centre, String value, double r) {
    // Dark outline for legibility on amber.
    final outline = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color.darkShade,
          fontSize: r * 0.95,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // Stroke via multiple offsets (cheap outline).
    for (final o in [
      const Offset(1.5, 0), const Offset(-1.5, 0),
      const Offset(0, 1.5), const Offset(0, -1.5),
    ]) {
      outline.paint(canvas, centre - Offset(outline.width / 2, outline.height / 2) + o);
    }
    final face = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: Colors.white,
          fontSize: r * 0.95,
          fontWeight: FontWeight.w900,
          height: 1.0,
          shadows: const [Shadow(color: Colors.black45, blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    face.paint(canvas, centre - Offset(face.width / 2, face.height / 2));
  }

  void _emblemText(Canvas canvas, Offset centre, String glyph, double fontSize, Color col) {
    final tp = TextPainter(
      text: TextSpan(
        text: glyph,
        style: TextStyle(color: col, fontSize: fontSize, fontWeight: FontWeight.w900, height: 1.0),
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
  bool shouldRepaint(covariant _OrbPainter old) =>
      old.color != color ||
      old.isHome != isHome ||
      old.number != number ||
      old.selectable != selectable;
}

/// Compact orb avatar for player cards.
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
        painter: _OrbPainter(
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
