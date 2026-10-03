import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/env.dart';
import '../../core/theme/ludu_theme.dart';
import '../../models/game_settings.dart';
import '../../models/ludo_color.dart';
import '../../models/token.dart';
import '../../services/haptics_service.dart';

/// Crown Pawn (§1: Original chess-pawn style, replacing Gem Pawn).
///
/// Features:
/// - Large glossy round head: diameter ~75% of cell width.
/// - Short narrow neck with a thin gold collar ring.
/// - Flared round foot ~65-70% of cell width, with a soft contact shadow.
/// - Total height ~1.25 to 1.3 cells; head rises above cell by at most ~20-25% of a cell.
/// - Token number printed large and centered on the head (clearly readable at a glance).
/// - Color-blind symbol placed on the collar or foot.
/// - Strong specular highlight on the head, thin dark outline, bright rim.
/// - Rich jewel colors: ruby, emerald, sapphire, deeper amber.
/// - Movable tokens: gentle bob and glowing ring around the foot.
/// - Hop animation: stretch in the air, shrinking shadow, small squash on landing.
/// - Touch target covers foot and body without stealing neighboring taps.
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
            // Gentle bob: translates vertically up and down ~4 dp when movable (§1)
            final bob = widget.isMovable ? -4.0 * pulseProgress : 0.0;
            final lift = widget.animLift.clamp(0.0, 1.0);
            final squash = widget.squash.clamp(0.0, 1.0);

            // Hop animation: stretch in the air, shrinking shadow, small squash on landing (§1)
            final hopStretchY = 1.0 + lift * 0.14 - squash * 0.14;
            final hopStretchX = (1.0 - lift * 0.06) * (1.0 + squash * 0.12);

            return Transform.translate(
              offset: Offset(0, bob - lift * w * 0.32),
              child: Transform(
                alignment: Alignment.bottomCenter,
                transform: Matrix4.diagonal3Values(hopStretchX, hopStretchY, 1.0),
                child: SizedBox(
                  width: w,
                  height: w,
                  child: CustomPaint(
                    size: Size(w, w),
                    painter: _CrownPawnPainter(
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
        // Touch target covering the flared foot and pawn body (§5)
        Positioned(
          left: -pad,
          top: -w * 0.25 - pad,
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

/// Painter for the Crown Pawn (§1: original chess-pawn style).
class _CrownPawnPainter extends CustomPainter {
  final LudoColor color;
  final ThemePlayerColor? themePlayerColor;
  final AppThemeMode themeMode;
  final bool isHome;
  final int number;
  final bool selectable;
  final bool isLastMoved;
  final double animLift;
  final double pulseProgress;

  _CrownPawnPainter({
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

    // Palette resolution (§1: ruby, emerald, sapphire, deeper amber)
    final primary = themePlayerColor?.primary ?? color.primary;
    final dark = themePlayerColor?.darkShade ?? color.darkShade;
    final glow = themePlayerColor?.lightGlow ?? color.lightGlow;
    final highlight = themePlayerColor?.highlight ?? color.orbHighlight;

    const goldCollar = Color(0xFFFFD700);
    const goldHighlight = Color(0xFFFFF9D2);
    const goldDark = Color(0xFF9E772E);

    // --- Proportions (§1):
    // Flared round foot: ~65 to 70% of cell width -> footRx ~0.33 to 0.35 * w
    final double footRx = w * 0.34;
    final double footRy = w * 0.15;
    final double footCy = w * 0.80;

    // 1. Soft contact shadow on ground (under foot, shrinks in air §1)
    final double shadowScale = (selectable ? 1.12 : 1.0) * (1.0 - animLift * 0.45);
    final double shadowY = footCy + footRy * 0.50 - animLift * w * 0.02;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, shadowY),
        width: footRx * 2.2 * shadowScale,
        height: footRy * 1.3 * shadowScale,
      ),
      Paint()
        ..color = Colors.black.withOpacity(0.42 * (1.0 - animLift * 0.50))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(1.5, w * 0.08)),
    );

    // 2. Movable glowing ring around the foot (§1: glowing ring around the foot)
    if (selectable) {
      final double ringGrow = 1.08 + pulseProgress * 0.14;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, footCy),
          width: footRx * 2.0 * ringGrow,
          height: footRy * 2.0 * ringGrow,
        ),
        Paint()
          ..color = (themePlayerColor?.accentRing ?? const Color(0xFFF2C14E))
              .withOpacity(0.52 + pulseProgress * 0.38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.2, w * 0.065)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, math.max(2.0, w * 0.07)),
      );

      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, footCy),
          width: footRx * 2.0 * 1.03,
          height: footRy * 2.0 * 1.03,
        ),
        Paint()
          ..color = Colors.white.withOpacity(0.92)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.8, w * 0.045),
      );
    } else if (isLastMoved) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, footCy),
          width: footRx * 2.0 * 1.06,
          height: footRy * 2.0 * 1.06,
        ),
        Paint()
          ..color = const Color(0xFFF2C14E).withOpacity(0.92)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.0, w * 0.05),
      );
    }

    // 3. Flared round foot pedestal (stepped 3D disk with gold trim)
    final footRect = Rect.fromCenter(
      center: Offset(cx, footCy),
      width: footRx * 2.0,
      height: footRy * 2.0,
    );

    // Bevel base rim (golden metallic edge)
    canvas.drawOval(
      footRect,
      Paint()
        ..shader = LinearGradient(
          colors: [goldHighlight, goldDark, const Color(0xFF3E2805)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(footRect),
    );

    // Foot top face (jewel gradient)
    final innerFootRect = Rect.fromCenter(
      center: Offset(cx, footCy - w * 0.015),
      width: footRx * 1.84,
      height: footRy * 1.76,
    );
    canvas.drawOval(
      innerFootRect,
      Paint()
        ..shader = RadialGradient(
          colors: [highlight, primary, dark],
          stops: const [0.0, 0.45, 1.0],
          center: const Alignment(-0.35, -0.4),
        ).createShader(innerFootRect),
    );

    // Foot bright rim highlight
    canvas.drawOval(
      innerFootRect,
      Paint()
        ..color = Colors.white.withOpacity(0.70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, w * 0.024),
    );

    // 4. Waist and Body (pawn trunk connecting foot to neck)
    // Neck coordinates:
    final double neckY = w * 0.22;
    final double neckHalfW = w * 0.11;
    final double waistY = w * 0.52;
    final double waistHalfW = w * 0.16;
    final double bodyBottomY = footCy;
    final double bodyBottomHalfW = footRx * 0.72;

    final trunkPath = Path()
      ..moveTo(cx - bodyBottomHalfW, bodyBottomY)
      ..cubicTo(
        cx - bodyBottomHalfW * 0.85,
        waistY + w * 0.10,
        cx - waistHalfW * 1.25,
        waistY,
        cx - waistHalfW,
        waistY,
      )
      ..cubicTo(
        cx - waistHalfW * 0.90,
        waistY - w * 0.12,
        cx - neckHalfW * 1.35,
        neckY + w * 0.06,
        cx - neckHalfW,
        neckY,
      )
      ..lineTo(cx + neckHalfW, neckY)
      ..cubicTo(
        cx + neckHalfW * 1.35,
        neckY + w * 0.06,
        cx + waistHalfW * 0.90,
        waistY - w * 0.12,
        cx + waistHalfW,
        waistY,
      )
      ..cubicTo(
        cx + waistHalfW * 1.25,
        waistY,
        cx + bodyBottomHalfW * 0.85,
        bodyBottomY + w * 0.10,
        cx + bodyBottomHalfW,
        bodyBottomY,
      )
      ..close();

    final trunkRect = Rect.fromLTRB(
      cx - bodyBottomHalfW,
      neckY,
      cx + bodyBottomHalfW,
      bodyBottomY,
    );

    // 3D cylindrical lighting on trunk
    canvas.drawPath(
      trunkPath,
      Paint()
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
        ).createShader(trunkRect),
    );

    // Thin dark outline on trunk (§1)
    canvas.drawPath(
      trunkPath,
      Paint()
        ..color = Colors.black.withOpacity(0.40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // Specular highlight streak on trunk left curve
    final trunkHighlight = Path()
      ..moveTo(cx - bodyBottomHalfW * 0.45, bodyBottomY - w * 0.04)
      ..cubicTo(
        cx - waistHalfW * 0.80,
        waistY + w * 0.08,
        cx - waistHalfW * 0.70,
        waistY - w * 0.06,
        cx - neckHalfW * 0.65,
        neckY + w * 0.02,
      )
      ..lineTo(cx - neckHalfW * 0.25, neckY + w * 0.02)
      ..cubicTo(
        cx - waistHalfW * 0.35,
        waistY - w * 0.06,
        cx - waistHalfW * 0.40,
        waistY + w * 0.08,
        cx - bodyBottomHalfW * 0.22,
        bodyBottomY - w * 0.04,
      )
      ..close();

    canvas.drawPath(
      trunkHighlight,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withOpacity(0.55),
            Colors.white.withOpacity(0.12),
            Colors.transparent,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(trunkRect),
    );

    // Color-blind symbol on the foot/waist (§1: color-blind symbol on collar or foot)
    final double symbolY = waistY + (bodyBottomY - waistY) * 0.40;
    _drawEmblem(canvas, Offset(cx, symbolY), w * 0.20);

    // 5. Short narrow neck with a thin gold collar ring (§1)
    final collarRect = Rect.fromCenter(
      center: Offset(cx, neckY),
      width: neckHalfW * 2.3,
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
        ..color = Colors.white.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, w * 0.016),
    );

    // 6. Large glossy round head (§1):
    // Diameter ~75% of cell width (headRadius = 0.375 * w)
    // Head rises above its cell by at most ~20 to 25% of a cell (top at ~ -0.22 * w)
    final double headRadius = w * 0.375;
    final double headCy = neckY - headRadius * 0.60; // head sits cleanly on the collar
    final Offset headCenter = Offset(cx, headCy);
    final Rect headRect = Rect.fromCircle(center: headCenter, radius: headRadius);

    // Soft drop shadow cast by head onto neck/body
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, neckY + w * 0.04),
        width: headRadius * 1.5,
        height: w * 0.08,
      ),
      Paint()
        ..color = Colors.black.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );

    // Head 3D glossy orb radial gradient (§1: strong specular, bright rim)
    final headPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          highlight,
          glow,
          primary,
          dark,
          Color.alphaBlend(Colors.black.withOpacity(0.35), dark),
        ],
        stops: const [0.0, 0.22, 0.52, 0.85, 1.0],
        center: const Alignment(-0.35, -0.40),
        radius: 1.05,
      ).createShader(headRect);
    canvas.drawCircle(headCenter, headRadius, headPaint);

    // Thin dark outline on head (§1)
    canvas.drawCircle(
      headCenter,
      headRadius,
      Paint()
        ..color = Colors.black.withOpacity(0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );

    // Bright rim highlight (§1: a bright rim)
    canvas.drawCircle(
      headCenter,
      headRadius - 0.5,
      Paint()
        ..color = Colors.white.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // Strong specular highlight on the head (§1)
    final specularCenter = Offset(cx - headRadius * 0.34, headCy - headRadius * 0.36);
    final double specRx = headRadius * 0.32;
    final double specRy = headRadius * 0.20;
    canvas.save();
    canvas.translate(specularCenter.dx, specularCenter.dy);
    canvas.rotate(-math.pi / 5);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: specRx * 2, height: specRy * 2),
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withOpacity(0.95),
            Colors.white.withOpacity(0.50),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(Rect.fromCenter(center: Offset.zero, width: specRx * 2, height: specRy * 2)),
    );
    canvas.restore();

    // 7. Token number printed large and centered on the head (§1)
    if (number == 0) {
      // Pin avatar: centered gold royal crown
      _drawRoyalCrown(canvas, headCenter, headRadius * 1.05, goldCollar);
    } else if (isHome) {
      // Reached center home: gold victory star
      _star(canvas, headCenter, headRadius * 0.65, Paint()..color = goldCollar);
      _star(canvas, headCenter, headRadius * 0.40, Paint()..color = Colors.white.withOpacity(0.95));
    } else {
      _drawNumber(canvas, headCenter, '$number', w);
    }
  }

  /// Distinct shape per color for color-blind accessibility (§1).
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

  /// Large readable token number printed centered on the head (§1).
  void _drawNumber(Canvas canvas, Offset centre, String value, double w) {
    final double fs = math.max(12.0, w * 0.38);
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
            Shadow(color: Colors.black54, blurRadius: 8),
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
  bool shouldRepaint(covariant _CrownPawnPainter old) =>
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

/// Compact Crown Pawn avatar for player chips and cards.
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
        painter: _CrownPawnPainter(
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
