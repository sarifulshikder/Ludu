import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/ludo_color.dart';
import '../../models/token.dart';
import '../../services/haptics_service.dart';

/// Height of a piece as a multiple of its width. The board uses this to anchor
/// the pin's head on the square it occupies.
const double kTokenPinAspect = 1.06;

/// Fraction of the piece height at which the head sits, used by the board to
/// line the head up with the square centre.
const double kTokenHeadOffset = 0.37;

/// A piece drawn as a map-pin / location marker, matching the sample games:
/// a light bevelled pin body with a coloured disc in the head, its point
/// landing on the seat in the middle of the piece.
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
    _pulseScale = Tween<double>(begin: 1.0, end: 1.12).animate(
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
    final w = widget.size;
    final h = w * kTokenPinAspect;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // A comfortable minimum touch target, expanded outside the paint bounds so
    // it never changes where the piece appears to sit.
    final pad = (math.max(44.0, w) - w) / 2;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: w,
          height: h,
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: widget.isMovable ? _pulseScale.value : 1.0,
                child: CustomPaint(
                  size: Size(w, h),
                  painter: _PinPainter(
                    color: widget.token.color,
                    isHome: widget.token.isHome,
                    number: widget.token.id + 1,
                    size: w,
                    selectable: widget.isMovable,
                    shadow: isDark ? 0.34 : 0.22,
                  ),
                ),
              );
            },
          ),
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

class _PinPainter extends CustomPainter {
  final LudoColor color;
  final bool isHome;
  final int number;
  final double size;
  final bool selectable;
  final double shadow;
  final bool showGlyph;

  _PinPainter({
    required this.color,
    required this.isHome,
    required this.number,
    required this.size,
    required this.selectable,
    required this.shadow,
    this.showGlyph = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Geometry of the marker. The head is a circle sitting above a short
    // tapered point, matching the reference pieces.
    final headR = w * 0.42;
    final headCx = w / 2;
    final headCy = h * kTokenHeadOffset;
    final tipY = h * 0.98;
    final shoulderY = headCy + headR * 0.30;

    final head = Offset(headCx, headCy);

    // Soft drop shadow under the whole marker.
    canvas.drawCircle(
      Offset(headCx, headCy + h * 0.05),
      headR * 0.98,
      Paint()
        ..color = Colors.black.withOpacity(shadow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.07),
    );

    if (selectable) {
      canvas.drawCircle(
        head,
        headR * 1.30,
        Paint()
          ..color = color.primary.withOpacity(0.85)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.05),
      );
    }

    // Pin silhouette: circle head joined to a point.
    final body = Path()
      ..addOval(Rect.fromCircle(center: head, radius: headR))
      ..moveTo(headCx - headR * 0.78, shoulderY)
      ..lineTo(headCx, tipY)
      ..lineTo(headCx + headR * 0.78, shoulderY)
      ..close();


    // Light bevelled shell.
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const [Color(0xFFFFFFFF), Color(0xFFE8EDF4), Color(0xFFB4BECC)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Subtle inner shade along the lower-right of the shell.
    canvas.save();
    canvas.clipPath(body);
    canvas.drawCircle(
      Offset(headCx + w * 0.30, headCy + h * 0.30),
      headR * 1.5,
      Paint()..color = Colors.black.withOpacity(0.10),
    );
    canvas.restore();

    // Outline.
    canvas.drawPath(
      body,
      Paint()
        ..color = const Color(0xFF7C8899)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, w * 0.035),
    );

    // Coloured disc in the head.
    final discR = headR * 0.62;
    canvas.drawCircle(head, discR, Paint()..color = color.primary);
    canvas.drawCircle(
      head.translate(0, -discR * 0.30),
      discR * 0.62,
      Paint()..color = color.lightGlow.withOpacity(0.45),
    );
    canvas.drawCircle(
      head,
      discR,
      Paint()
        ..color = const Color(0xFF3A3F4B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, w * 0.030),
    );

    // Glyph.
    if (isHome) {
      _star(canvas, head, discR * 0.72, Paint()..color = Colors.white);
    } else if (showGlyph) {
      _text(canvas, head, '$number', discR);
    }
  }

  void _text(Canvas canvas, Offset centre, String value, double discR) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: Colors.white,
          fontSize: discR * 1.05,
          fontWeight: FontWeight.w900,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, centre - Offset(painter.width / 2, painter.height / 2));
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
  bool shouldRepaint(covariant _PinPainter old) =>
      old.color != color ||
      old.isHome != isHome ||
      old.number != number ||
      old.size != size ||
      old.selectable != selectable ||
      old.showGlyph != showGlyph ||
      old.shadow != shadow;
}

/// A small map-pin used as a player's avatar on the compact cards.
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
    final w = size * 0.80;
    return SizedBox(
      width: w,
      height: size,
      child: CustomPaint(
        painter: _PinPainter(
          color: color,
          isHome: false,
          number: 0,
          size: w,
          selectable: false,
          showGlyph: false,
          shadow: isDark ? 0.34 : 0.20,
        ),
      ),
    );
  }
}
