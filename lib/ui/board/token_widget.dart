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
/// * Almost fills a cell (~90–95% of cell width).
/// * Small lift on movable tokens + golden/neon pulsing aura.
/// * Jewel gloss for Royal Gold, glowing frosted acrylic for Neon Glass,
///   lathe-turned wood with brass collar for Wooden Luxe.
/// * Color-blind double-coding: unique emblem glyph (▲ ● ★ ■).
class TokenWidget extends StatefulWidget {
  final Token token;
  final double size;
  final bool isMovable;
  final bool isLastMoved;
  final VoidCallback? onTap;
  final AppThemeMode themeMode;
  final ThemePlayerColor? themePlayerColor;

  const TokenWidget({
    super.key,
    required this.token,
    required this.size,
    this.isMovable = false,
    this.isLastMoved = false,
    this.onTap,
    this.themeMode = AppThemeMode.royalGold,
    this.themePlayerColor,
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
    _pulseScale = Tween<double>(begin: 1.0, end: 1.10).animate(
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
            return Transform.scale(
              scale: bounce,
              // Small lift on movable tokens
              child: Transform.translate(
                offset: widget.isMovable
                    ? const Offset(0, -3.5)
                    : Offset.zero,
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

  _PawnPainter({
    required this.color,
    this.themePlayerColor,
    this.themeMode = AppThemeMode.royalGold,
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
    final cy = w / 2;
    final center = Offset(cx, cy);

    final primary = themePlayerColor?.primary ?? color.primary;
    final dark = themePlayerColor?.darkShade ?? color.darkShade;
    final glow = themePlayerColor?.lightGlow ?? color.lightGlow;
    final highlight = themePlayerColor?.highlight ?? color.orbHighlight;
    final accentRing = themePlayerColor?.accentRing ?? const Color(0xFFF2C14E);

    final double coinR = w * 0.47;

    // 1. Ground Drop Shadow (larger & softer when lifted)
    final shadowScale = selectable ? 1.25 : 1.0;
    final shadowY = selectable ? cy + w * 0.08 : cy + w * 0.035;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, shadowY),
        width: coinR * 2.0 * shadowScale,
        height: coinR * 0.55 * shadowScale,
      ),
      Paint()
        ..color = Colors.black.withOpacity(selectable ? 0.45 : shadow)
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

    // 3. Selectable pulsing aura
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

    // 4. Outer Minted Coin Bevel Rim (Metallic Gold / Cyber Neon / Polished Brass)
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
    canvas.drawCircle(center, coinR, outerRimPaint);

    // Coin serrated / grooved milled rim ring
    canvas.drawCircle(
      center,
      coinR * 0.93,
      Paint()
        ..color = Colors.white.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, w * 0.022),
    );

    // 5. Stepped Recessed Coin Face (Inner Bevel)
    final innerR = coinR * 0.85;
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

    // 6. Domed Jewel Core / Enamel Face
    final faceR = coinR * 0.82;
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

    // 7. Embossed Center Emblem (Crown + Number / Star)
    if (number == 0) {
      // Pin avatar: centered royal crown
      _drawRoyalCrown(canvas, center, coinR * 0.50, accentRing);
    } else if (isHome) {
      // Reached center home: gleaming 5-point golden victory star
      _star(canvas, center, coinR * 0.45, Paint()..color = accentRing);
      _star(canvas, center, coinR * 0.30,
          Paint()..color = Colors.white.withOpacity(0.90));
    } else {
      // In-play coin: Embossed Royal Crown at top + Token Number at center
      _drawRoyalCrown(
          canvas, Offset(cx, cy - coinR * 0.22), coinR * 0.30, accentRing);
      _number(canvas, Offset(cx, cy + coinR * 0.20), '$number', w);
    }

    // 8. Glossy Specular Curved Arc Highlight (across upper left of coin)
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
    final face = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: Colors.white,
          fontSize: w * 0.28,
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
      old.isLastMoved != isLastMoved;
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
