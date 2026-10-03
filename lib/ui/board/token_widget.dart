import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/env.dart';
import '../../core/theme/ludu_theme.dart';
import '../../models/game_settings.dart';
import '../../models/ludo_color.dart';
import '../../models/token.dart';
import '../../services/haptics_service.dart';

/// Gem Pawn (§10): Original tall standing pawn design.
///
/// Features:
/// - Bell-shaped glossy body with 3D cylindrical lighting and specular sheen.
/// - Faceted gem on top rising ~40-50% of a cell above it.
/// - Thin gold collar ring at the neck.
/// - Round base (~80% of cell width) with soft contact shadow.
/// - Movable tokens: gentle bob and glowing ring around the base.
/// - Color-blind double-coding: distinct symbol on body per color (▲ Red ruby,
///   ● Green emerald, ★ Yellow amber, ■ Blue sapphire) with clear number.
/// - Reached center: golden victory star emblem.
/// - Touch target covers base footprint and body without stealing neighboring taps.
class TokenWidget extends StatefulWidget {
  final Token token;
  final double size;
  final bool isMovable;
  final bool isLastMoved;
  final VoidCallback? onTap;
  final AppThemeMode themeMode;
  final ThemePlayerColor? themePlayerColor;

  /// 0..1 lift during a hop (shadow shrinks as this grows).
  final double animLift;

  /// 0..1 landing squash.
  final double squash;

  const TokenWidget({
    super.key,
    required this.token,
    required this.size,
    this.isMovable = false,
    this.isLastMoved = false,
    this.onTap,
    this.themeMode = AppThemeMode.royalGold,
    this.themePlayerColor,
    this.animLift = 0.0,
    this.squash = 0.0,
  });

  @override
  State<TokenWidget> createState() => _TokenWidgetState();
}

class _TokenWidgetState extends State<TokenWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  void _startPulse() {
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
      duration: const Duration(milliseconds: 700),
    );
    _pulseScale = Tween<double>(begin: 0.0, end: 1.0).animate(
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
    final pad = math.max(0.0, (56.0 - w) / 2);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final pulseProgress = widget.isMovable ? _pulseScale.value : 0.0;
            // Gentle bob: translates vertically up and down ~4 dp when movable
            final bob = widget.isMovable ? -4.0 * pulseProgress : 0.0;
            final lift = widget.animLift.clamp(0.0, 1.0);
            final squash = widget.squash.clamp(0.0, 1.0);

            final hopScale = 1.0 + lift * 0.08;
            final sx = hopScale * (1.0 + squash * 0.08);
            final sy = hopScale * (1.0 - squash * 0.12);

            return Transform.translate(
              offset: Offset(0, bob - lift * w * 0.28),
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.diagonal3Values(sx, sy, 1.0),
                child: SizedBox(
                  width: w,
                  height: w,
                  child: CustomPaint(
                    size: Size(w, w),
                    painter: _GemPawnPainter(
                      color: widget.token.color,
                      themePlayerColor: widget.themePlayerColor,
                      themeMode: widget.themeMode,
                      isHome: widget.token.isHome,
                      number: widget.token.id + 1,
                      selectable: widget.isMovable,
                      isLastMoved: widget.isLastMoved,
                      animLift: lift,
                      pulseProgress: pulseProgress,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        // Touch target covering the body and base footprint
        Positioned(
          left: -pad,
          top: -w * 0.45 - pad,
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

class _GemPawnPainter extends CustomPainter {
  final LudoColor color;
  final ThemePlayerColor? themePlayerColor;
  final AppThemeMode themeMode;
  final bool isHome;
  final int number;
  final bool selectable;
  final bool isLastMoved;
  final double animLift;
  final double pulseProgress;

  _GemPawnPainter({
    required this.color,
    this.themePlayerColor,
    this.themeMode = AppThemeMode.royalGold,
    required this.isHome,
    required this.number,
    required this.selectable,
    this.isLastMoved = false,
    this.animLift = 0.0,
    this.pulseProgress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double cx = w / 2;

    // Palette resolution
    final primary = themePlayerColor?.primary ?? color.primary;
    final dark = themePlayerColor?.darkShade ?? color.darkShade;
    final glow = themePlayerColor?.lightGlow ?? color.lightGlow;
    final highlight = themePlayerColor?.highlight ?? color.orbHighlight;
    final goldCollar = const Color(0xFFFFD700);
    final goldHighlight = const Color(0xFFFFF9D2);
    final goldDark = const Color(0xFF9E772E);

    // Geometry (§10):
    // Round base: ~80% of cell width (radius = 0.40 * w)
    final double baseRx = w * 0.40;
    final double baseRy = w * 0.18;
    final double baseCy = w * 0.74;

    // 1. Soft contact shadow on ground (under round base)
    final double shadowScale = (selectable ? 1.15 : 1.0) * (1.0 - animLift * 0.40);
    final double shadowY = baseCy + baseRy * 0.45 - animLift * w * 0.02;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, shadowY),
        width: baseRx * 2.1 * shadowScale,
        height: baseRy * 1.2 * shadowScale,
      ),
      Paint()
        ..color = Colors.black.withOpacity(0.38 * (1.0 - animLift * 0.45))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(1.5, w * 0.08)),
    );

    // 2. Movable glowing ring around the base footprint
    if (selectable) {
      final double ringGrow = 1.08 + pulseProgress * 0.12;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, baseCy),
          width: baseRx * 2.0 * ringGrow,
          height: baseRy * 2.0 * ringGrow,
        ),
        Paint()
          ..color = (themePlayerColor?.accentRing ?? const Color(0xFFF2C14E))
              .withOpacity(0.50 + pulseProgress * 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.2, w * 0.06)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(2.0, w * 0.07)),
      );

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, baseCy),
          width: baseRx * 2.0 * 1.04,
          height: baseRy * 2.0 * 1.04,
        ),
        Paint()
          ..color = Colors.white.withOpacity(0.92)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.8, w * 0.045),
      );
    } else if (isLastMoved) {
      // Last-move follow ring around base
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, baseCy),
          width: baseRx * 2.0 * 1.06,
          height: baseRy * 2.0 * 1.06,
        ),
        Paint()
          ..color = const Color(0xFFF2C14E).withOpacity(0.92)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.0, w * 0.05),
      );
    }

    // 3. Round base pedestal (stepped 3D coin/disk base)
    final baseRect = Rect.fromCenter(
      center: Offset(cx, baseCy),
      width: baseRx * 2.0,
      height: baseRy * 2.0,
    );

    // Base rim bevel (bright golden/bright rim edge)
    final baseBevelPaint = Paint()
      ..shader = LinearGradient(
        colors: [const Color(0xFFFFF6D8), goldDark, const Color(0xFF4A3408)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(baseRect);
    canvas.drawOval(baseRect, baseBevelPaint);

    // Inner base top disk (jewel toned with glossy gradient)
    final innerBaseRect = Rect.fromCenter(
      center: Offset(cx, baseCy - w * 0.02),
      width: baseRx * 1.84,
      height: baseRy * 1.76,
    );
    final baseFacePaint = Paint()
      ..shader = RadialGradient(
        colors: [highlight, primary, dark],
        stops: const [0.0, 0.45, 1.0],
        center: const Alignment(-0.35, -0.4),
      ).createShader(innerBaseRect);
    canvas.drawOval(innerBaseRect, baseFacePaint);

    // Base upper rim highlight line
    canvas.drawOval(
      innerBaseRect,
      Paint()
        ..color = Colors.white.withOpacity(0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, w * 0.024),
    );

    // 4. Bell-shaped glossy body
    // Neck coordinates (where body meets collar ring)
    final double neckY = w * 0.12;
    final double neckHalfW = w * 0.13;
    final double bodyBottomY = baseCy;
    final double bodyBottomHalfW = baseRx * 0.76;

    final bodyPath = Path()
      ..moveTo(cx - bodyBottomHalfW, bodyBottomY)
      ..cubicTo(
        cx - bodyBottomHalfW * 0.85,
        bodyBottomY - w * 0.26,
        cx - neckHalfW * 1.4,
        neckY + w * 0.16,
        cx - neckHalfW,
        neckY,
      )
      ..lineTo(cx + neckHalfW, neckY)
      ..cubicTo(
        cx + neckHalfW * 1.4,
        neckY + w * 0.16,
        cx + bodyBottomHalfW * 0.85,
        bodyBottomY - w * 0.26,
        cx + bodyBottomHalfW,
        bodyBottomY,
      )
      ..close();

    final bodyRect = Rect.fromLTRB(
      cx - bodyBottomHalfW,
      neckY,
      cx + bodyBottomHalfW,
      bodyBottomY,
    );

    // Cylindrical 3D glossy gradient for the bell body
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          dark,
          primary,
          highlight,
          primary,
          dark,
        ],
        stops: const [0.0, 0.22, 0.45, 0.75, 1.0],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(bodyRect);
    canvas.drawPath(bodyPath, bodyPaint);

    // Glossy specular highlight streak along the left bell curve
    final highlightPath = Path()
      ..moveTo(cx - bodyBottomHalfW * 0.45, bodyBottomY - w * 0.04)
      ..cubicTo(
        cx - bodyBottomHalfW * 0.40,
        bodyBottomY - w * 0.24,
        cx - neckHalfW * 0.80,
        neckY + w * 0.14,
        cx - neckHalfW * 0.50,
        neckY + w * 0.02,
      )
      ..lineTo(cx - neckHalfW * 0.20, neckY + w * 0.02)
      ..cubicTo(
        cx - neckHalfW * 0.50,
        neckY + w * 0.14,
        cx - bodyBottomHalfW * 0.22,
        bodyBottomY - w * 0.22,
        cx - bodyBottomHalfW * 0.25,
        bodyBottomY - w * 0.04,
      )
      ..close();
    canvas.drawPath(
      highlightPath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withOpacity(0.55),
            Colors.white.withOpacity(0.15),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(bodyRect),
    );

    // 5. Distinct symbol and readable token number on the body (§10)
    final double symbolY = neckY + (bodyBottomY - neckY) * 0.32;
    final double numberY = neckY + (bodyBottomY - neckY) * 0.68;

    if (number == 0) {
      // Pin avatar: centered gold emblem
      _drawRoyalCrown(canvas, Offset(cx, (neckY + bodyBottomY) / 2), w * 0.34, goldCollar);
    } else if (isHome) {
      // Reached center home: gold 5-point victory star
      final starCenter = Offset(cx, (neckY + bodyBottomY) / 2);
      _star(canvas, starCenter, w * 0.22, Paint()..color = goldCollar);
      _star(canvas, starCenter, w * 0.14, Paint()..color = Colors.white.withOpacity(0.92));
    } else {
      // Shape emblem + readable number
      _drawEmblem(canvas, Offset(cx, symbolY), w * 0.22);
      _drawNumber(canvas, Offset(cx, numberY), '$number', w);
    }

    // 6. Thin gold collar ring at the neck (§10)
    final collarRect = Rect.fromCenter(
      center: Offset(cx, neckY),
      width: neckHalfW * 2.4,
      height: w * 0.075,
    );
    final collarPaint = Paint()
      ..shader = LinearGradient(
        colors: [goldHighlight, goldCollar, goldDark],
        stops: const [0.0, 0.45, 1.0],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(collarRect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(collarRect, Radius.circular(w * 0.035)),
      collarPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(collarRect, Radius.circular(w * 0.035)),
      Paint()
        ..color = Colors.white.withOpacity(0.70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, w * 0.016),
    );

    // 7. Faceted gem on top (§10)
    // The gem rises ~40-50% of cell width above cell (neckY up to topY)
    final double gemTopY = -w * 0.42;
    final double gemCenterY = (neckY + gemTopY) / 2;
    final double gemW = w * 0.38;
    final double gemH = (neckY - gemTopY);

    _drawFacetedGem(
      canvas: canvas,
      center: Offset(cx, gemCenterY),
      width: gemW,
      height: gemH,
      primary: primary,
      dark: dark,
      glow: glow,
      highlight: highlight,
    );
  }

  /// Brilliant faceted gem drawn on top of the pawn (§10).
  void _drawFacetedGem({
    required Canvas canvas,
    required Offset center,
    required double width,
    required double height,
    required Color primary,
    required Color dark,
    required Color glow,
    required Color highlight,
  }) {
    final double cx = center.dx;
    final double top = center.dy - height / 2;
    final double bottom = center.dy + height / 2;
    final double halfW = width / 2;
    final double midY = center.dy - height * 0.08;

    // Gem faceted polygon vertices:
    // Top table facet: flat top edge
    final tableP1 = Offset(cx - halfW * 0.48, top);
    final tableP2 = Offset(cx + halfW * 0.48, top);
    // Outer side corners at girdle (midY)
    final leftCorner = Offset(cx - halfW, midY);
    final rightCorner = Offset(cx + halfW, midY);
    // Upper facet midpoints
    final upperLeft = Offset(cx - halfW * 0.65, top + (midY - top) * 0.45);
    final upperRight = Offset(cx + halfW * 0.65, top + (midY - top) * 0.45);
    // Bottom culet / point meeting the collar
    final bottomPoint = Offset(cx, bottom);


    // Draw individual facets with varying luminance for real 3D crystal depth:
    void drawFacet(List<Offset> points, Color col, [double opacity = 1.0]) {
      final p = Path()..addPolygon(points, true);
      canvas.drawPath(p, Paint()..color = col.withOpacity(opacity));
      canvas.drawPath(
        p,
        Paint()
          ..color = Colors.white.withOpacity(0.38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.75,
      );
    }

    // 1. Lower facets (culet to girdle)
    drawFacet([bottomPoint, leftCorner, Offset(cx - halfW * 0.25, midY)], dark.withOpacity(0.95));
    drawFacet([bottomPoint, Offset(cx - halfW * 0.25, midY), Offset(cx + halfW * 0.25, midY)], primary);
    drawFacet([bottomPoint, Offset(cx + halfW * 0.25, midY), rightCorner], dark);

    // 2. Crown side facets (girdle to table)
    drawFacet([leftCorner, upperLeft, tableP1, Offset(cx - halfW * 0.25, midY)], highlight.withOpacity(0.90));
    drawFacet([upperLeft, tableP1, tableP2, upperRight], glow);
    drawFacet([tableP2, upperRight, rightCorner, Offset(cx + halfW * 0.25, midY)], primary);
    drawFacet([Offset(cx - halfW * 0.25, midY), tableP1, tableP2, Offset(cx + halfW * 0.25, midY)], highlight);

    // 3. Top table facet (hexagonal / trapezoidal gleaming table)
    final tablePath = Path()
      ..moveTo(tableP1.dx, tableP1.dy)
      ..lineTo(tableP2.dx, tableP2.dy)
      ..lineTo(upperRight.dx * 0.85 + cx * 0.15, midY * 0.55 + top * 0.45)
      ..lineTo(upperLeft.dx * 0.85 + cx * 0.15, midY * 0.55 + top * 0.45)
      ..close();
    canvas.drawPath(
      tablePath,
      Paint()
        ..shader = LinearGradient(
          colors: [Colors.white.withOpacity(0.95), highlight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTRB(tableP1.dx, top, tableP2.dx, midY)),
    );
    canvas.drawPath(
      tablePath,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // 4. Brilliant specular glint on the top-left facet corner
    canvas.drawCircle(
      tableP1 + const Offset(1.5, 2.0),
      math.max(1.8, width * 0.05),
      Paint()
        ..color = Colors.white
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );
  }

  /// Distinct shape per color so hue is never the only cue (§10).
  void _drawEmblem(Canvas canvas, Offset c, double size) {
    final Paint fill = Paint()..color = Colors.white.withOpacity(0.95);
    final Paint shadowP = Paint()..color = Colors.black.withOpacity(0.40);
    final double s = size;
    switch (color) {
      case LudoColor.red:
        // ▲ triangle
        final path = Path()
          ..moveTo(c.dx, c.dy - s * 0.55)
          ..lineTo(c.dx + s * 0.55, c.dy + s * 0.40)
          ..lineTo(c.dx - s * 0.55, c.dy + s * 0.40)
          ..close();
        canvas.drawPath(path.shift(const Offset(0, 1.0)), shadowP);
        canvas.drawPath(path, fill);
        break;
      case LudoColor.green:
        // ● circle
        canvas.drawCircle(c + const Offset(0, 1.0), s * 0.42, shadowP);
        canvas.drawCircle(c, s * 0.42, fill);
        canvas.drawCircle(
          c,
          s * 0.22,
          Paint()
            ..color = Colors.black.withOpacity(0.25)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
        break;
      case LudoColor.yellow:
        // ★ star
        _star(canvas, c + const Offset(0, 1.0), s * 0.55, shadowP);
        _star(canvas, c, s * 0.52, fill);
        break;
      case LudoColor.blue:
        // ■ square
        final r = Rect.fromCenter(center: c, width: s * 0.80, height: s * 0.80);
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, Radius.circular(s * 0.12)).shift(const Offset(0, 1.0)),
          shadowP,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, Radius.circular(s * 0.12)),
          fill,
        );
        break;
    }
  }

  void _drawRoyalCrown(Canvas canvas, Offset c, double size, Color col) {
    final w = size;
    final h = size * 0.72;
    final top = c.dy - h / 2;
    final bottom = c.dy + h / 2;
    final left = c.dx - w / 2;
    final right = c.dx + w / 2;

    final path = Path()
      ..moveTo(left, bottom)
      ..lineTo(right, bottom)
      ..lineTo(right * 0.96 + left * 0.04, top + h * 0.22)
      ..lineTo(c.dx + w * 0.22, top + h * 0.52)
      ..lineTo(c.dx, top)
      ..lineTo(c.dx - w * 0.22, top + h * 0.52)
      ..lineTo(left * 0.96 + right * 0.04, top + h * 0.22)
      ..close();

    canvas.drawPath(path.shift(const Offset(0, 1.2)), Paint()..color = Colors.black.withOpacity(0.38));
    canvas.drawPath(path, Paint()..color = col);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withOpacity(0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );

    final pearlR = size * 0.09;
    canvas.drawCircle(Offset(c.dx, top), pearlR, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(left * 0.96 + right * 0.04, top + h * 0.22), pearlR * 0.85, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(right * 0.96 + left * 0.04, top + h * 0.22), pearlR * 0.85, Paint()..color = Colors.white);
  }

  void _drawNumber(Canvas canvas, Offset centre, String value, double w) {
    final double fs = math.max(9.0, w * 0.26);
    final face = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: Colors.white,
          fontSize: fs,
          fontWeight: FontWeight.w900,
          height: 1.0,
          shadows: const [
            Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1.5)),
            Shadow(color: Colors.black45, blurRadius: 8),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    face.paint(canvas, centre - Offset(face.width / 2, face.height / 2));
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
  bool shouldRepaint(covariant _GemPawnPainter old) =>
      old.color != color ||
      old.themePlayerColor != themePlayerColor ||
      old.themeMode != themeMode ||
      old.isHome != isHome ||
      old.number != number ||
      old.selectable != selectable ||
      old.isLastMoved != isLastMoved ||
      old.animLift != animLift ||
      old.pulseProgress != pulseProgress;
}

/// Compact Gem Pawn avatar for player chips and cards.
class PinAvatar extends StatelessWidget {
  final LudoColor color;
  final double size;
  final bool isDark;
  final ThemePlayerColor? themePlayerColor;

  const PinAvatar({
    super.key,
    required this.color,
    required this.size,
    this.isDark = true,
    this.themePlayerColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GemPawnPainter(
          color: color,
          themePlayerColor: themePlayerColor,
          isHome: false,
          number: 0,
          selectable: false,
        ),
      ),
    );
  }
}
