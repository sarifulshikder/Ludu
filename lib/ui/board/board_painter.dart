import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/board_coordinates.dart';
import '../../models/ludo_color.dart';

class BoardPainter extends CustomPainter {
  final bool isDark;

  BoardPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final double tileSize = size.width / 15.0;

    _drawBoardBackground(canvas, size);
    _drawBases(canvas, tileSize);
    _drawTrackTiles(canvas, tileSize);
    _drawHomeStretches(canvas, tileSize);
    _drawCenterTriangle(canvas, tileSize);
    _drawSafeStars(canvas, tileSize);
  }

  void _drawBoardBackground(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(24),
    );

    // Deep base colour
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = isDark ? const Color(0xFF0F172A) : const Color(0xFFFAF7F2)
        ..style = PaintingStyle.fill,
    );

    // Soft top-lit vignette so the board reads as a physical, bevelled object
    // rather than a flat swatch.
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = RadialGradient(
          colors: isDark
              ? [const Color(0xFF1B2942).withOpacity(0.85), Colors.transparent]
              : [Colors.white.withOpacity(0.95), Colors.transparent],
          center: const Alignment(-0.3, -0.5),
          radius: 1.15,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Metallic gold frame: a wide gradient stroke reads as polished metal.
    final goldFrame = Paint()
      ..shader = LinearGradient(
        colors: const [
          Color(0xFFF7E7A1),
          Color(0xFFD4AF37),
          Color(0xFF8C6D1F),
          Color(0xFFE8CE72),
          Color(0xFF9C7A24),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;
    canvas.drawRRect(rrect, goldFrame);

    // Crisp inner bevel line
    canvas.drawRRect(
      rrect.deflate(6.5),
      Paint()
        ..color = isDark ? Colors.white.withOpacity(0.16) : Colors.black.withOpacity(0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  void _drawBases(Canvas canvas, double tileSize) {
    void drawBaseBox(double col, double row, LudoColor color) {
      final rect = Rect.fromLTWH(col * tileSize, row * tileSize, tileSize * 6, tileSize * 6);
      final rrect = RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(18));

      // Outer rich satin gradient
      final baseGradient = RadialGradient(
        colors: [
          color.primary.withOpacity(isDark ? 0.45 : 0.28),
          color.darkShade.withOpacity(isDark ? 0.85 : 0.48),
        ],
        center: Alignment.center,
        radius: 0.95,
      );

      final paint = Paint()
        ..shader = baseGradient.createShader(rect)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(rrect, paint);

      // Gold/metallic border
      final borderPaint = Paint()
        ..color = color.primary.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4;

      canvas.drawRRect(rrect, borderPaint);

      // Diagonal glass sheen across the yard for depth
      canvas.save();
      canvas.clipRRect(rrect);
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(isDark ? 0.14 : 0.45),
              Colors.transparent,
              Colors.black.withOpacity(isDark ? 0.18 : 0.05),
            ],
            stops: const [0.0, 0.45, 1.0],
          ).createShader(rect)
          ..style = PaintingStyle.fill,
      );
      canvas.restore();

      // Inner platform
      final innerRect = Rect.fromLTWH(
        (col + 0.9) * tileSize,
        (row + 0.9) * tileSize,
        tileSize * 4.2,
        tileSize * 4.2,
      );
      final innerRRect = RRect.fromRectAndRadius(innerRect, const Radius.circular(16));

      final innerPaint = Paint()
        ..color = isDark ? const Color(0xFF131D2E) : Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawRRect(innerRRect, innerPaint);

      final innerBorder = Paint()
        ..color = color.primary.withOpacity(isDark ? 0.35 : 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawRRect(innerRRect, innerBorder);

      // 4 Large circular pedestals for tokens
      final podRadius = tileSize * 0.82;
      for (final slot in BoardCoordinates.baseSlots[color]!) {
        final center = slot.toOffset(tileSize);

        // Outer glow rim
        final podGlow = Paint()
          ..color = color.primary.withOpacity(isDark ? 0.22 : 0.15)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, podRadius, podGlow);

        // Inner recessed ring
        final podInner = Paint()
          ..color = isDark ? const Color(0xFF0D1424) : const Color(0xFFF1F5F9)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, podRadius * 0.82, podInner);

        // Metallic bezel
        final podBorder = Paint()
          ..shader = LinearGradient(
            colors: [color.lightGlow, color.darkShade],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(Rect.fromCircle(center: center, radius: podRadius))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4;
        canvas.drawCircle(center, podRadius, podBorder);
      }
    }

    // Top-Left: Red
    drawBaseBox(0, 0, LudoColor.red);
    // Top-Right: Green
    drawBaseBox(9, 0, LudoColor.green);
    // Bottom-Right: Yellow
    drawBaseBox(9, 9, LudoColor.yellow);
    // Bottom-Left: Blue
    drawBaseBox(0, 9, LudoColor.blue);
  }

  void _drawTrackTiles(Canvas canvas, double tileSize) {
    final tileBg = Paint()
      ..color = isDark ? const Color(0xFF162032) : const Color(0xFFF8FAFC)
      ..style = PaintingStyle.fill;

    final tileBorder = Paint()
      ..color = isDark ? const Color(0xFF2B3A55) : const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 0; i < BoardCoordinates.outerTrack.length; i++) {
      final pt = BoardCoordinates.outerTrack[i];
      final rect = Rect.fromLTWH(
        pt.col * tileSize + 1,
        pt.row * tileSize + 1,
        tileSize - 2,
        tileSize - 2,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5));

      // Check if start square
      LudoColor? startColor;
      if (i == LudoColor.red.startSquare) startColor = LudoColor.red;
      if (i == LudoColor.green.startSquare) startColor = LudoColor.green;
      if (i == LudoColor.yellow.startSquare) startColor = LudoColor.yellow;
      if (i == LudoColor.blue.startSquare) startColor = LudoColor.blue;

      if (startColor != null) {
        final startPaint = Paint()
          ..color = startColor.primary.withOpacity(isDark ? 0.65 : 0.50)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(rrect, startPaint);

        final startBorder = Paint()
          ..color = startColor.lightGlow
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawRRect(rrect, startBorder);
      } else {
        canvas.drawRRect(rrect, tileBg);
        canvas.drawRRect(rrect, tileBorder);
      }
    }
  }

  void _drawHomeStretches(Canvas canvas, double tileSize) {
    for (final entry in BoardCoordinates.homeStretches.entries) {
      final color = entry.key;
      final tiles = entry.value;

      final fillPaint = Paint()
        ..color = color.primary.withOpacity(isDark ? 0.85 : 0.75)
        ..style = PaintingStyle.fill;

      final borderPaint = Paint()
        ..color = color.lightGlow.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;

      for (int idx = 0; idx < tiles.length; idx++) {
        final pt = tiles[idx];
        final rect = Rect.fromLTWH(
          pt.col * tileSize + 1,
          pt.row * tileSize + 1,
          tileSize - 2,
          tileSize - 2,
        );
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5));
        canvas.drawRRect(rrect, fillPaint);
        canvas.drawRRect(rrect, borderPaint);

        // Direction chevron pointing toward center
        _drawHomeChevron(canvas, pt.toOffset(tileSize), color, tileSize * 0.22);
      }
    }
  }

  void _drawHomeChevron(Canvas canvas, Offset center, LudoColor color, double size) {
    final chevronPaint = Paint()
      ..color = Colors.white.withOpacity(0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final path = Path();
    switch (color) {
      case LudoColor.red:
        // Points East
        path.moveTo(center.dx - size * 0.5, center.dy - size);
        path.lineTo(center.dx + size * 0.5, center.dy);
        path.lineTo(center.dx - size * 0.5, center.dy + size);
        break;
      case LudoColor.green:
        // Points South
        path.moveTo(center.dx - size, center.dy - size * 0.5);
        path.lineTo(center.dx, center.dy + size * 0.5);
        path.lineTo(center.dx + size, center.dy - size * 0.5);
        break;
      case LudoColor.yellow:
        // Points West
        path.moveTo(center.dx + size * 0.5, center.dy - size);
        path.lineTo(center.dx - size * 0.5, center.dy);
        path.lineTo(center.dx + size * 0.5, center.dy + size);
        break;
      case LudoColor.blue:
        // Points North
        path.moveTo(center.dx - size, center.dy + size * 0.5);
        path.lineTo(center.dx, center.dy - size * 0.5);
        path.lineTo(center.dx + size, center.dy + size * 0.5);
        break;
    }
    canvas.drawPath(path, chevronPaint);
  }

  void _drawCenterTriangle(Canvas canvas, double tileSize) {
    final center = Offset(7.5 * tileSize, 7.5 * tileSize);

    void drawQuadrant(LudoColor color, Offset p1, Offset p2) {
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();

      final paint = Paint()
        ..color = color.primary.withOpacity(isDark ? 0.90 : 0.82)
        ..style = PaintingStyle.fill;

      final borderPaint = Paint()
        ..color = color.lightGlow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8;

      canvas.drawPath(path, paint);
      canvas.drawPath(path, borderPaint);
    }

    // Red (Left)
    drawQuadrant(LudoColor.red, Offset(6.0 * tileSize, 6.0 * tileSize), Offset(6.0 * tileSize, 9.0 * tileSize));
    // Green (Top)
    drawQuadrant(LudoColor.green, Offset(6.0 * tileSize, 6.0 * tileSize), Offset(9.0 * tileSize, 6.0 * tileSize));
    // Yellow (Right)
    drawQuadrant(LudoColor.yellow, Offset(9.0 * tileSize, 6.0 * tileSize), Offset(9.0 * tileSize, 9.0 * tileSize));
    // Blue (Bottom)
    drawQuadrant(LudoColor.blue, Offset(6.0 * tileSize, 9.0 * tileSize), Offset(9.0 * tileSize, 9.0 * tileSize));

    // Center Golden Trophy Crest
    final crestBg = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;
    final crestBorder = Paint()
      ..color = const Color(0xFFFFD700)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    canvas.drawCircle(center, tileSize * 0.72, crestBg);
    canvas.drawCircle(center, tileSize * 0.72, crestBorder);

    // Golden star in center crest
    _drawStar(canvas, center, tileSize * 0.42, const Color(0xFFFFD700));
  }

  void _drawSafeStars(Canvas canvas, double tileSize) {
    for (final safeIdx in BoardCoordinates.safeSquares) {
      final pt = BoardCoordinates.outerTrack[safeIdx];
      final center = pt.toOffset(tileSize);
      _drawStar(canvas, center, tileSize * 0.36, const Color(0xFFFFC107));
    }
  }

  void _drawStar(Canvas canvas, Offset center, double outerRadius, Color color) {
    final innerRadius = outerRadius * 0.45;
    final path = Path();
    const int points = 5;
    const double step = pi / points;

    for (int i = 0; i < points * 2; i++) {
      final r = (i % 2 == 0) ? outerRadius : innerRadius;
      final angle = i * step - pi / 2;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.4)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawPath(path.shift(const Offset(0, 1.2)), shadowPaint);

    final starFill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final starStroke = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawPath(path, starFill);
    canvas.drawPath(path, starStroke);
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
