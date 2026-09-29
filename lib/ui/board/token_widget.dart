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

    final primary = themePlayerColor?.primary ?? color.primary;
    final dark = themePlayerColor?.darkShade ?? color.darkShade;
    final glow = themePlayerColor?.lightGlow ?? color.lightGlow;
    final highlight = themePlayerColor?.highlight ?? color.orbHighlight;
    final accentRing = themePlayerColor?.accentRing ?? const Color(0xFFF2C14E);

    // Ground drop shadow (increases when lifted)
    final shadowScale = selectable ? 1.25 : 1.0;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, w * (selectable ? 0.94 : 0.90)),
        width: w * 0.66 * shadowScale,
        height: w * 0.15 * shadowScale,
      ),
      Paint()
        ..color = Colors.black.withOpacity(selectable ? 0.48 : shadow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * (selectable ? 0.09 : 0.06)),
    );

    // Last-move follow ring
    if (isLastMoved && !selectable) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, w * 0.50),
          width: w * 1.04,
          height: w * 1.08,
        ),
        Paint()
          ..color = accentRing.withOpacity(0.95)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.2, w * 0.06),
      );
    }

    // Selectable pulsing halo
    if (selectable) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, w * 0.50),
          width: w * 1.18,
          height: w * 1.22,
        ),
        Paint()
          ..color = accentRing.withOpacity(0.55)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.08),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, w * 0.50),
          width: w * 1.02,
          height: w * 1.06,
        ),
        Paint()
          ..color = Colors.white.withOpacity(0.90)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2.0, w * 0.05),
      );
    }

    // Tapered pawn torso
    final body = Path()
      ..moveTo(cx - w * 0.30, w * 0.86)
      ..lineTo(cx - w * 0.155, w * 0.46)
      ..quadraticBezierTo(cx - w * 0.14, w * 0.40, cx - w * 0.10, w * 0.385)
      ..lineTo(cx + w * 0.10, w * 0.385)
      ..quadraticBezierTo(cx + w * 0.14, w * 0.40, cx + w * 0.155, w * 0.46)
      ..lineTo(cx + w * 0.30, w * 0.86)
      ..quadraticBezierTo(cx, w * 0.92, cx - w * 0.30, w * 0.86)
      ..close();

    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          colors: [glow, primary, dark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(body.getBounds()),
    );

    // Torso specular & shading
    canvas.save();
    canvas.clipPath(body);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + w * 0.10, w * 0.86),
        width: w * 0.62,
        height: w * 0.50,
      ),
      Paint()..color = Colors.black.withOpacity(0.22),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - w * 0.10, w * 0.60),
        width: w * 0.12,
        height: w * 0.40,
      ),
      Paint()..color = highlight.withOpacity(0.60),
    );
    canvas.restore();

    // Collar ring around neck
    final collar = Rect.fromCenter(
      center: Offset(cx, w * 0.385),
      width: w * 0.28,
      height: w * 0.07,
    );
    canvas.drawOval(
      collar,
      Paint()..color = accentRing,
    );
    canvas.drawOval(
      collar,
      Paint()
        ..color = Colors.white.withOpacity(0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, w * 0.025),
    );

    // Head orb
    final headC = Offset(cx, w * 0.24);
    final headR = w * 0.21;
    canvas.drawCircle(
      headC,
      headR,
      Paint()
        ..shader = RadialGradient(
          colors: [highlight, primary, dark],
          stops: const [0.0, 0.45, 1.0],
          center: const Alignment(-0.35, -0.4),
          radius: 1.1,
        ).createShader(Rect.fromCircle(center: headC, radius: headR)),
    );
    canvas.drawCircle(
      headC,
      headR,
      Paint()
        ..color = accentRing.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.4, w * 0.038),
    );
    // Specular shine on head
    canvas.drawOval(
      Rect.fromCenter(
        center: headC + Offset(-headR * 0.32, -headR * 0.38),
        width: headR * 0.85,
        height: headR * 0.55,
      ),
      Paint()..color = Colors.white.withOpacity(0.82),
    );

    // Stepped base
    final base = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - w * 0.30, w * 0.82, w * 0.60, w * 0.10),
      Radius.circular(w * 0.05),
    );
    canvas.drawRRect(
      base,
      Paint()
        ..shader = LinearGradient(
          colors: [primary, dark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(base.outerRect),
    );
    canvas.drawRRect(
      base,
      Paint()
        ..color = accentRing
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.2, w * 0.03),
    );

    // Shape-coded emblem on the belly
    _emblemText(
      canvas,
      Offset(cx, w * 0.60),
      color.emblemGlyph,
      w * 0.20,
      Colors.white.withOpacity(0.95),
    );

    if (number == 0) {
      // Avatar mode
      _emblemText(canvas, Offset(cx, w * 0.62), color.emblemGlyph,
          w * 0.30, Colors.white);
    } else if (isHome) {
      _star(canvas, Offset(cx, w * 0.74), w * 0.10,
          Paint()..color = accentRing);
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
          shadows: const [Shadow(color: Colors.black87, blurRadius: 4)],
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
            shadows: const [Shadow(color: Colors.black54, blurRadius: 3)]),
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
