import 'dart:math';

import 'package:flutter/material.dart';

/// A quiet geometric backdrop: large offset tiles with occasional circles and
/// star outlines. Derived from the sample games' themed board backgrounds, but
/// held at very low contrast so it never competes with the board.
class BoardBackdropPainter extends CustomPainter {
  final bool isDark;
  final Color accent;

  BoardBackdropPainter({required this.isDark, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / 3.2;
    final radius = cell * 0.16;

    // Deterministic per-cell variation: index maths, not Random, so the
    // pattern is stable across repaints.
    int cols = (size.width / cell).ceil() + 1;
    int rows = (size.height / cell).ceil() + 1;

    final tile = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * 0.014;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final seed = (r * 31 + c * 17) % 7;
        // Offset every other row for the woven look of the sample boards.
        final dx = (r.isOdd ? cell * 0.5 : 0.0);
        final centre = Offset(c * cell + dx + cell / 2, r * cell + cell / 2);
        if (centre.dy - cell / 2 > size.height) continue;

        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: centre, width: cell, height: cell),
          Radius.circular(radius),
        );

        tile.color = (isDark ? accent : accent)
            .withOpacity(isDark ? 0.055 : 0.075);
        canvas.drawRRect(rect, tile);

        stroke.color = (isDark ? Colors.white : accent).withOpacity(0.035);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: centre, width: cell * 0.62, height: cell * 0.62),
            Radius.circular(radius * 0.8),
          ),
          stroke,
        );

        switch (seed) {
          case 0:
            canvas.drawCircle(
              centre,
              cell * 0.20,
              Paint()..color = accent.withOpacity(0.05),
            );
            break;
          case 3:
            canvas.drawCircle(
              centre,
              cell * 0.20,
              stroke..color = accent.withOpacity(0.05),
            );
            break;
          case 5:
            _star(
              canvas,
              centre,
              cell * 0.20,
              stroke..color = accent.withOpacity(0.05),
            );
            break;
        }
      }
    }
  }

  void _star(Canvas canvas, Offset centre, double outer, Paint paint) {
    final inner = outer * 0.46;
    final path = Path();
    const points = 5;
    final step = pi / points;
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? outer : inner;
      final angle = i * step - pi / 2;
      final x = centre.dx + r * cos(angle);
      final y = centre.dy + r * sin(angle);
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
  bool shouldRepaint(covariant BoardBackdropPainter old) =>
      old.isDark != isDark || old.accent != accent;
}
