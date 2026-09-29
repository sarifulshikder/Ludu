import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/board_coordinates.dart';
import '../../models/ludo_color.dart';

/// Paints the board in a flat, high-contrast board-game style: solid saturated
/// yards and lanes, light track cells separated by thin dark rules, outlined
/// star safe-squares, arrowed start squares and a bare four-triangle centre.
class BoardPainter extends CustomPainter {
  final bool isDark;

  BoardPainter({required this.isDark});

  // --- Surfaces -----------------------------------------------------------

  // The board reads as a physical object, so the cells stay light in both
  // themes for maximum contrast against the pieces.
  Color get _trackFill => isDark ? const Color(0xFFE9EDF4) : const Color(0xFFFFFFFF);
  Color get _trackRule => isDark ? const Color(0xFF9AA3B2) : const Color(0xFFB9B3A6);
  Color get _frameInk => isDark ? const Color(0xFF64789E) : const Color(0xFF8C8577);
  Color get _ink => isDark ? const Color(0xFF0A1120) : const Color(0xFF1F2937);
  Color get _paper => isDark ? const Color(0xFFEDF1F7) : const Color(0xFFFCFCFA);

  @override
  void paint(Canvas canvas, Size size) {
    final double tileSize = size.width / 15.0;

    _drawBoard(canvas, size);
    _drawYards(canvas, tileSize);
    _drawTrackCells(canvas, tileSize);
    _drawHomeStretches(canvas, tileSize);
    _drawCentre(canvas, tileSize);
    _drawSafeStars(canvas, tileSize);
    _drawStartArrows(canvas, tileSize);
  }

  // --- Board shell --------------------------------------------------------

  void _drawBoard(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(14));

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = isDark ? const Color(0xFF0C1424) : const Color(0xFFF2EEE6)
        ..style = PaintingStyle.fill,
    );

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = _frameInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
    );
  }

  // --- Corner yards -------------------------------------------------------

  void _drawYards(Canvas canvas, double tileSize) {
    void yard(double col, double row, LudoColor color) {
      final outer = Rect.fromLTWH(
        col * tileSize,
        row * tileSize,
        tileSize * 6,
        tileSize * 6,
      );
      final outerRRect = RRect.fromRectAndRadius(outer, const Radius.circular(8));

      // Solid saturated yard.
      canvas.drawRRect(outerRRect, Paint()..color = color.primary);
      canvas.drawRRect(
        outerRRect,
        Paint()
          ..color = _ink.withOpacity(0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );

      // White holding panel the pieces rest in.
      final panel = Rect.fromLTWH(
        (col + 0.95) * tileSize,
        (row + 0.95) * tileSize,
        tileSize * 4.1,
        tileSize * 4.1,
      );
      final panelRRect = RRect.fromRectAndRadius(panel, const Radius.circular(6));
      canvas.drawRRect(panelRRect, Paint()..color = _paper);
      canvas.drawRRect(
        panelRRect,
        Paint()
          ..color = _ink.withOpacity(0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );

      // Seats stay behind when a piece leaves: a coloured disc just larger than
      // the pin head, so a thin rim shows around it as in the reference.
      for (final slot in BoardCoordinates.baseSlots[color]!) {
        final c = slot.toOffset(tileSize);
        canvas.drawCircle(c, tileSize * 0.46, Paint()..color = color.primary);
        canvas.drawCircle(
          c,
          tileSize * 0.46,
          Paint()
            ..color = color.darkShade
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
    }

    yard(0, 0, LudoColor.red); // top-left
    yard(9, 0, LudoColor.green); // top-right
    yard(9, 9, LudoColor.yellow); // bottom-right
    yard(0, 9, LudoColor.blue); // bottom-left
  }

  // --- Track --------------------------------------------------------------

  void _drawTrackCells(Canvas canvas, double tileSize) {
    final fill = Paint()..color = _trackFill;
    final rule = Paint()
      ..color = _trackRule
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final pt in BoardCoordinates.outerTrack) {
      final rect = Rect.fromLTWH(
        pt.col * tileSize + 0.8,
        pt.row * tileSize + 0.8,
        tileSize - 1.6,
        tileSize - 1.6,
      );
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
      canvas.drawRRect(rrect, fill);
      canvas.drawRRect(rrect, rule);
    }
  }

  void _drawHomeStretches(Canvas canvas, double tileSize) {
    for (final entry in BoardCoordinates.homeStretches.entries) {
      for (final pt in entry.value) {
        final rect = Rect.fromLTWH(
          pt.col * tileSize + 0.8,
          pt.row * tileSize + 0.8,
          tileSize - 1.6,
          tileSize - 1.6,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          Paint()..color = entry.key.primary,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          Paint()
            ..color = _ink.withOpacity(0.45)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
      }
    }
  }

  // --- Centre -------------------------------------------------------------

  void _drawCentre(Canvas canvas, double tileSize) {
    final centre = Offset(7.5 * tileSize, 7.5 * tileSize);
    // The centre block is 3x3 cells, so the half-width is 1.5 tiles.
    const r = 1.5;

    void quadrant(LudoColor color, Offset a, Offset b) {
      final path = Path()
        ..moveTo(centre.dx, centre.dy)
        ..lineTo(a.dx, a.dy)
        ..lineTo(b.dx, b.dy)
        ..close();

      canvas.drawPath(path, Paint()..color = color.primary);
      canvas.drawPath(
        path,
        Paint()
          ..color = _ink.withOpacity(0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }

    // Each colour owns the side its home lane runs along.
    quadrant(
      LudoColor.red,
      Offset((7.5 - r) * tileSize, (7.5 - r) * tileSize),
      Offset((7.5 - r) * tileSize, (7.5 + r) * tileSize),
    );
    quadrant(
      LudoColor.green,
      Offset((7.5 - r) * tileSize, (7.5 - r) * tileSize),
      Offset((7.5 + r) * tileSize, (7.5 - r) * tileSize),
    );
    quadrant(
      LudoColor.yellow,
      Offset((7.5 + r) * tileSize, (7.5 - r) * tileSize),
      Offset((7.5 + r) * tileSize, (7.5 + r) * tileSize),
    );
    quadrant(
      LudoColor.blue,
      Offset((7.5 - r) * tileSize, (7.5 + r) * tileSize),
      Offset((7.5 + r) * tileSize, (7.5 + r) * tileSize),
    );
  }

  // --- Safe stars ---------------------------------------------------------

  void _drawSafeStars(Canvas canvas, double tileSize) {
    for (final index in BoardCoordinates.safeSquares) {
      // Start squares carry an arrow instead, so they stay uncluttered.
      if (_startColorFor(index) != null) continue;
      final pt = BoardCoordinates.outerTrack[index];
      _star(
        canvas,
        pt.toOffset(tileSize),
        tileSize * 0.34,
        Paint()
          ..color = _ink.withOpacity(0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
        fill: false,
      );
    }
  }

  // --- Start arrows -------------------------------------------------------

  LudoColor? _startColorFor(int index) {
    if (index == LudoColor.red.startSquare) return LudoColor.red;
    if (index == LudoColor.green.startSquare) return LudoColor.green;
    if (index == LudoColor.yellow.startSquare) return LudoColor.yellow;
    if (index == LudoColor.blue.startSquare) return LudoColor.blue;
    return null;
  }

  void _drawStartArrows(Canvas canvas, double tileSize) {
    for (int i = 0; i < BoardCoordinates.outerTrack.length; i++) {
      final color = _startColorFor(i);
      if (color == null) continue;
      final pt = BoardCoordinates.outerTrack[i];
      _arrow(canvas, pt.toOffset(tileSize), tileSize * 0.40, color.primary, i);
    }
  }

  /// Filled arrow: triangular head on a narrower shaft, pointing along travel.
  void _arrow(Canvas canvas, Offset centre, double size, Color color, int index) {
    final next = BoardCoordinates.outerTrack[(index + 1) % BoardCoordinates.outerTrack.length];
    final cur = BoardCoordinates.outerTrack[index];
    final d = Offset((next.col - cur.col).sign.toDouble(), (next.row - cur.row).sign.toDouble());
    final w = Offset(-d.dy, d.dx);

    Offset p(double along, double across) =>
        centre + d * (size * along) + w * (size * across);

    final path = Path()
      ..moveTo(p(1.0, 0.0).dx, p(1.0, 0.0).dy) // tip
      ..lineTo(p(0.25, 0.75).dx, p(0.25, 0.75).dy) // head barb
      ..lineTo(p(-0.15, 0.30).dx, p(-0.15, 0.30).dy) // shaft
      ..lineTo(p(-0.85, 0.30).dx, p(-0.85, 0.30).dy) // tail
      ..lineTo(p(-0.85, -0.30).dx, p(-0.85, -0.30).dy)
      ..lineTo(p(-0.15, -0.30).dx, p(-0.15, -0.30).dy)
      ..lineTo(p(0.25, -0.75).dx, p(0.25, -0.75).dy)
      ..close();

    canvas.drawPath(path, Paint()..color = color);
  }

  void _star(Canvas canvas, Offset centre, double outer, Paint paint, {bool fill = true}) {
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
    if (fill) {
      canvas.drawPath(path, paint);
    } else {
      paint.style = PaintingStyle.stroke;
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) => oldDelegate.isDark != isDark;
}
