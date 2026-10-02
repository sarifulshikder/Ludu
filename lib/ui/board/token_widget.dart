import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/env.dart';
import '../../core/theme/ludu_theme.dart';
import '../../models/game_settings.dart';
import '../../models/ludo_color.dart';
import '../../models/token.dart';
import '../../services/haptics_service.dart';

/// Large 3D Pawn Piece styled for the active theme.
///
/// Polish pass:
/// * Fills ~90% of a path cell, centered, never overlapping neighbours
///   (the board sizes clusters to fit — see [LudoBoard]).
/// * Strong contrast on every cell color: bright ivory/gold outer rim,
///   soft drop shadow, glossy highlight.
/// * Color-blind double-coding: each color keeps a distinct emblem shape
///   (Red ▲ triangle, Teal ● circle, Amber ★ star, Blue ■ square) drawn
///   above the readable token number.
/// * Movable tokens: gentle pulse plus a bright ring.
/// * [animLift] (0..1) raises the piece mid-hop and shrinks its shadow;
///   [squash] (0..1) applies a tiny landing squash. Both are driven by the
///   board's hop animation with hardware-accelerated transforms (no layout
///   work per frame).
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
      duration: const Duration(milliseconds: 720),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.08).animate(
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
    final pad = (math.max(48.0, w) - w) / 2;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final bounce = widget.isMovable ? _pulseScale.value : 1.0;
            final lift = widget.animLift.clamp(0.0, 1.0);
            final squash = widget.squash.clamp(0.0, 1.0);
            // Hop lift: rise + slight grow; landing: tiny vertical squash
            // with compensating horizontal stretch (juice, no layout work).
            final hopScale = 1.0 + lift * 0.10;
            final sx = bounce * hopScale * (1.0 + squash * 0.06);
            final sy = bounce * hopScale * (1.0 - squash * 0.10);
            return Transform.scale(
              scale: 1.0,
              child: Transform.translate(
                offset: Offset(
                  0,
                  (widget.isMovable ? -3.5 : 0.0) - lift * w * 0.16,
                ),
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.diagonal3Values(sx, sy, 1.0),
                  child: SizedBox(
                    width: w,
                    height: w,
                    child: CustomPaint(
                      size: Size(w, w),
                      painter: _PawnPainter(
                        color: widget.token.color,
                        themePlayerColor: widget.themePlayerColor,
                        themeMode: widget.themeMode,
                        isHome: widget.token.isHome,
                        number: widget.token.id + 1,
                        selectable: widget.isMovable,
                        isLastMoved: widget.isLastMoved,
                        shadow: 0.38,
                        animLift: lift,
                      ),
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
  final ThemePlayerColor? themePlayerColor;
  final AppThemeMode themeMode;
  final bool isHome;
  final int number;
  final bool selectable;
  final bool isLastMoved;
  final double shadow;
  final double animLift;

  _PawnPainter({
    required this.color,
    this.themePlayerColor,
    this.themeMode = AppThemeMode.royalGold,
    required this.isHome,
    required this.number,
    required this.selectable,
    this.isLastMoved = false,
    required this.shadow,
    this.animLift = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final cx = w / 2;
    final cy = w / 2;
    final center = Offset(cx, cy);

    final primary = themePlayerColor?.primary ?? color.primary;
    final dark = themePlayerColor?.darkShade ?? color.darkShade;
    final glow = themePlayerColor?.lightGlow ?? color.lightGlow;
    final highlight = themePlayerColor?.highlight ?? color.orbHighlight;
    final accentRing = themePlayerColor?.accentRing ?? const Color(0xFFF2C14E);

    final double coinR = w * 0.47;

    // 1. Ground drop shadow — softer, smaller and fainter while lifted.
    final shadowScale = (selectable ? 1.25 : 1.0) * (1.0 - animLift * 0.35);
    final shadowY = cy + w * 0.035 + (selectable ? w * 0.045 : 0.0) -
        animLift * w * 0.02;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, shadowY),
        width: coinR * 2.0 * shadowScale,
        height: coinR * 0.55 * shadowScale,
      ),
      Paint()
        ..color = Colors.black
            .withOpacity((selectable ? 0.45 : shadow) * (1.0 - animLift * 0.45))
        ..maskFilter =
            MaskFilter.blur(BlurStyle.normal, w * (selectable ? 0.12 : 0.06)),
    );

    // 2. Last-move follow ring
    if (isLastMoved && !selectable) {
      canvas.drawCircle(
        center,
        coinR * 1.08,
        Paint()
          ..color = accentRing.withOpacity(0.95)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.4, w * 0.065),
      );
    }

    // 3. Selectable pulsing aura + bright ring (instantly visible movables)
    if (selectable) {
      canvas.drawCircle(
        center,
        coinR * 1.18,
        Paint()
          ..color = accentRing.withOpacity(0.55)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.10),
      );
      canvas.drawCircle(
        center,
        coinR * 1.06,
        Paint()
          ..color = Colors.white.withOpacity(0.95)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.2, w * 0.055),
      );
    }

    // 4. Bright ivory outer rim — guarantees contrast on every cell color.
    canvas.drawCircle(
      center,
      coinR * 1.0,
      Paint()
        ..color = const Color(0xFFFFF8E7).withOpacity(0.98)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.6, w * 0.038),
    );

    // 5. Outer minted coin bevel rim (gold / neon / brass).
    final rimColors = themeMode == AppThemeMode.neonGlass
        ? [
            const Color(0xFFE0F7FA),
            const Color(0xFF00E5FF),
            const Color(0xFF0288D1),
            const Color(0xFF01579B),
          ]
        : themeMode == AppThemeMode.woodenLuxe
            ? [
                const Color(0xFFFFF3D6),
                const Color(0xFFD4AF37),
                const Color(0xFF9E772E),
                const Color(0xFF5A3E14),
              ]
            : [
                const Color(0xFFFFF6D8),
                const Color(0xFFE5B842),
                const Color(0xFFB8860B),
                const Color(0xFF6B4E0F),
              ];

    final outerRimPaint = Paint()
      ..shader = SweepGradient(
        colors: rimColors,
        stops: const [0.0, 0.35, 0.70, 1.0],
        transform: const GradientRotation(-math.pi / 4),
      ).createShader(Rect.fromCircle(center: center, radius: coinR));
    canvas.drawCircle(center, coinR * 0.96, outerRimPaint);

    // Coin serrated / grooved milled rim ring
    canvas.drawCircle(
      center,
      coinR * 0.89,
      Paint()
        ..color = Colors.white.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, w * 0.022),
    );

    // 6. Stepped recessed coin face (inner bevel)
    final innerR = coinR * 0.82;
    canvas.drawCircle(
      center,
      innerR,
      Paint()..color = Colors.black.withOpacity(0.35),
    );
    canvas.drawCircle(
      center + const Offset(0.8, 0.8),
      innerR,
      Paint()
        ..color = Colors.white.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // 7. Domed jewel core / enamel face
    final faceR = coinR * 0.79;
    final faceRect = Rect.fromCircle(center: center, radius: faceR);
    final coreGradient = RadialGradient(
      colors: [highlight, glow, primary, dark],
      stops: const [0.0, 0.28, 0.72, 1.0],
      center: const Alignment(-0.35, -0.40),
      radius: 1.15,
    );
    canvas.drawCircle(
        center, faceR, Paint()..shader = coreGradient.createShader(faceRect));

    // Concentric minted medallion inner ring
    final medallionR = coinR * 0.52;
    canvas.drawCircle(
      center,
      medallionR,
      Paint()
        ..color = accentRing.withOpacity(0.40)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );

    // 8. Color-blind emblem shape + readable token number.
    if (number == 0) {
      // Pin avatar: centered royal crown
      _drawRoyalCrown(canvas, center, coinR * 0.50, accentRing);
    } else if (isHome) {
      // Reached center home: gleaming 5-point golden victory star
      _star(canvas, center, coinR * 0.45, Paint()..color = accentRing);
      _star(canvas, center, coinR * 0.30,
          Paint()..color = Colors.white.withOpacity(0.90));
    } else {
      // Distinct per-color emblem at top, number stays large and readable
      // even at 48-60% stack sizes (floor keeps tiny tokens legible).
      _drawEmblem(canvas, Offset(cx, cy - coinR * 0.30), coinR * 0.30);
      _number(canvas, Offset(cx, cy + coinR * 0.24), '$number', w);
    }

    // 9. Glossy specular curved arc highlight (across upper left of coin)
    canvas.save();
    canvas.clipRRect(
        RRect.fromRectAndRadius(faceRect, Radius.circular(faceR)));
    final shinePath = Path()
      ..moveTo(cx - faceR * 0.85, cy - faceR * 0.30)
      ..quadraticBezierTo(cx - faceR * 0.20, cy - faceR * 0.90,
          cx + faceR * 0.60, cy - faceR * 0.65)
      ..quadraticBezierTo(cx + faceR * 0.10, cy - faceR * 0.35,
          cx - faceR * 0.45, cy + faceR * 0.25)
      ..close();
    canvas.drawPath(
      shinePath,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white.withOpacity(0.60),
            Colors.white.withOpacity(0.12),
            Colors.transparent,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(faceRect),
    );
    canvas.restore();
  }

  /// Distinct shape per color so hue is never the only cue.
  void _drawEmblem(Canvas canvas, Offset c, double size) {
    final Paint fill = Paint()..color = Colors.white.withOpacity(0.95);
    final Paint shadowP = Paint()..color = Colors.black.withOpacity(0.35);
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
              ..strokeWidth = 1.0);
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
            shadowP);
        canvas.drawRRect(
            RRect.fromRectAndRadius(r, Radius.circular(s * 0.12)), fill);
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

    // 3D Emboss shadow
    canvas.drawPath(
      path.shift(const Offset(0, 1.2)),
      Paint()..color = Colors.black.withOpacity(0.38),
    );
    // Gold crown body
    canvas.drawPath(
      path,
      Paint()..color = col,
    );
    // Crown top highlight line
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withOpacity(0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );

    // Crown jewel pearls on 3 peaks
    final pearlR = size * 0.09;
    canvas.drawCircle(Offset(c.dx, top), pearlR, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(left * 0.96 + right * 0.04, top + h * 0.22),
        pearlR * 0.85, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(right * 0.96 + left * 0.04, top + h * 0.22),
        pearlR * 0.85, Paint()..color = Colors.white);
  }

  void _number(Canvas canvas, Offset centre, String value, double w) {
    // Floor keeps stacked (48-60%) tokens legible.
    final double fs = math.max(9.0, w * 0.30);
    final face = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: Colors.white,
          fontSize: fs,
          fontWeight: FontWeight.w900,
          height: 1.0,
          shadows: const [
            Shadow(
                color: Colors.black87,
                blurRadius: 4,
                offset: Offset(0, 1.5)),
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
  bool shouldRepaint(covariant _PawnPainter old) =>
      old.color != color ||
      old.themePlayerColor != themePlayerColor ||
      old.themeMode != themeMode ||
      old.isHome != isHome ||
      old.number != number ||
      old.selectable != selectable ||
      old.isLastMoved != isLastMoved ||
      old.animLift != animLift;
}

/// Compact pawn avatar for player chips and cards.
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
        painter: _PawnPainter(
          color: color,
          themePlayerColor: themePlayerColor,
          isHome: false,
          number: 0,
          selectable: false,
          shadow: 0.35,
        ),
      ),
    );
  }
}
