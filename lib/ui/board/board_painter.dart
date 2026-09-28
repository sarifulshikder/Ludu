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
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF101726) : const Color(0xFFFAF7F2)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isDark ? const Color(0xFF22304A) : const Color(0xFFD6CEBD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(20),
    );

    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(rrect, borderPaint);
  }

  void _drawBases(Canvas canvas, double tileSize) {
    void drawBaseBox(double col, double row, LudoColor color) {
      final rect = Rect.fromLTWH(col * tileSize, row * tileSize, tileSize * 6, tileSize * 6);
      final rrect = RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(16));

      // Outer gradient base
      final baseGradient = RadialGradient(
        colors: [
          color.primary.withOpacity(isDark ? 0.35 : 0.20),
          color.darkShade.withOpacity(isDark ? 0.70 : 0.35),
        ],
        center: Alignment.center,
        radius: 0.9,
      );

      final paint = Paint()
        ..shader = baseGradient.createShader(rect)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(rrect, paint);

      // Border with jewel glow
      final borderPaint = Paint()
        ..color = color.primary.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawRRect(rrect, borderPaint);

      // Inner white/dark sunken platform
      final innerRect = Rect.fromLTWH(
        (col + 1.0) * tileSize,
        (row + 1.0) * tileSize,
        tileSize * 4.0,
        tileSize * 4.0,
      );
      final innerRRect = RRect.fromRectAndRadius(innerRect, const Radius.circular(14));

      final innerPaint = Paint()
        ..color = isDark ? const Color(0xFF141D2E) : Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawRRect(innerRRect, innerPaint);

      // Draw the 4 circular token holders inside base
      final slotPaint = Paint()
        ..color = color.primary.withOpacity(isDark ? 0.25 : 0.15)
        ..style = PaintingStyle.fill;

      final slotBorder = Paint()
        ..color = color.primary.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      for (final slot in BoardCoordinates.baseSlots[color]!) {
        final center = slot.toOffset(tileSize);
        canvas.drawCircle(center, tileSize * 0.65, slotPaint);
        canvas.drawCircle(center, tileSize * 0.65, slotBorder);
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
      ..color = isDark ? const Color(0xFF182236) : const Color(0xFFEBE5D8)
      ..style = PaintingStyle.fill;

    final tileBorder = Paint()
      ..color = isDark ? const Color(0xFF283754) : const Color(0xFFD3CABE)
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
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));

      // Check if start square
      LudoColor? startColor;
      if (i == LudoColor.red.startSquare) startColor = LudoColor.red;
      if (i == LudoColor.green.startSquare) startColor = LudoColor.green;
      if (i == LudoColor.yellow.startSquare) startColor = LudoColor.yellow;
      if (i == LudoColor.blue.startSquare) startColor = LudoColor.blue;

      if (startColor != null) {
        final startPaint = Paint()
          ..color = startColor.primary.withOpacity(isDark ? 0.45 : 0.35)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(rrect, startPaint);

        final startBorder = Paint()
          ..color = startColor.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8;
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
        ..color = color.primary.withOpacity(isDark ? 0.75 : 0.65)
        ..style = PaintingStyle.fill;

      final borderPaint = Paint()
        ..color = color.lightGlow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      for (final pt in tiles) {
        final rect = Rect.fromLTWH(
          pt.col * tileSize + 1,
          pt.row * tileSize + 1,
          tileSize - 2,
          tileSize - 2,
        );
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(6));
        canvas.drawRRect(rrect, fillPaint);
        canvas.drawRRect(rrect, borderPaint);
      }
    }
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
        ..color = color.primary.withOpacity(isDark ? 0.85 : 0.75)
        ..style = PaintingStyle.fill;

      final borderPaint = Paint()
        ..color = color.lightGlow
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawPath(path, paint);
      canvas.drawPath(path, borderPaint);
    }

    // Red (Left)
    drawQuadrant(
      LudoColor.red,
      Offset(6 * tileSize, 6 * tileSize),
      Offset(6 * tileSize, 9 * tileSize),
    );
    // Green (Top)
    drawQuadrant(
      LudoColor.green,
      Offset(6 * tileSize, 6 * tileSize),
      Offset(9 * tileSize, 6 * tileSize),
    );
    // Yellow (Right)
    drawQuadrant(
      LudoColor.yellow,
      Offset(9 * tileSize, 6 * tileSize),
      Offset(9 * tileSize, 9 * tileSize),
    );
    // Blue (Bottom)
    drawQuadrant(
      LudoColor.blue,
      Offset(6 * tileSize, 9 * tileSize),
      Offset(9 * tileSize, 9 * tileSize),
    );

    // Radiant Gold Center Star/Diamond
    final starPaint = Paint()
      ..color = const Color(0xFFE9C46A)
      ..style = PaintingStyle.fill;

    final starBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final starPath = Path()
      ..moveTo(center.dx, center.dy - tileSize * 0.45)
      ..lineTo(center.dx + tileSize * 0.45, center.dy)
      ..lineTo(center.dx, center.dy + tileSize * 0.45)
      ..lineTo(center.dx - tileSize * 0.45, center.dy)
      ..close();

    canvas.drawPath(starPath, starPaint);
    canvas.drawPath(starPath, starBorder);
  }

  void _drawSafeStars(Canvas canvas, double tileSize) {
    for (final safeIdx in BoardCoordinates.safeSquares) {
      final pt = BoardCoordinates.outerTrack[safeIdx];
      final center = pt.toOffset(tileSize);
      _draw8PointStar(canvas, center, tileSize * 0.32);
    }
  }

  void _draw8PointStar(Canvas canvas, Offset center, double outerRadius) {
    final innerRadius = outerRadius * 0.45;
    final path = Path();
    const int points = 8;
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

    final starFill = Paint()
      ..color = const Color(0xFFE9C46A)
      ..style = PaintingStyle.fill;

    final starStroke = Paint()
      ..color = isDark ? const Color(0xFF5A4418) : const Color(0xFF8A6B29)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawPath(path, starFill);
    canvas.drawPath(path, starStroke);
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
