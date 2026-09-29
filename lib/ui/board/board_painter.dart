import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/board_coordinates.dart';
import '../../models/ludo_color.dart';

/// "Aurora Arena" board — premium midnight-glass look.
///
/// * Edge-to-edge 15×15 grid, pearl track cells with crisp 1.2dp rules.
/// * Frosted-glass corner yards with radial color glow + deep token wells.
/// * Gold-foil safe stars, glowing chevron start cells, gradient home columns.
/// * Center is a rounded trophy medallion (4 petals + gold crown hub),
///   not the generic flat triangles of stock Ludo boards.
class BoardPainter extends CustomPainter {
  final bool isDark;
  final LudoColor? activeColor;

  BoardPainter({required this.isDark, this.activeColor});

  Color get _trackRule => isDark ? const Color(0xFF8E99B0) : const Color(0xFFA39A87);
  Color get _ink => const Color(0xFF101A30);
  Color get _paper => const Color(0xFFFDFBF6);

  static const Color _goldFoil = Color(0xFFF2C14E);
  static const Color _goldDeep = Color(0xFFB8860B);

  @override
  void paint(Canvas canvas, Size size) {
    final double tileSize = size.width / 15.0;
    _drawShell(canvas, size, tileSize);
    _drawYards(canvas, tileSize);
    _drawTrackCells(canvas, tileSize);
    _drawHomeStretches(canvas, tileSize);
    _drawCentre(canvas, tileSize);
    _drawSafeStars(canvas, tileSize);
    _drawStartCells(canvas, tileSize);
  }

  // --- Shell: rounded bezel + soft vignette + linen texture ---------------
  void _drawShell(Canvas canvas, Size size, double tile) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(tile * 0.55));

    // Deep bezel gradient.
    final bezel = isDark
        ? const LinearGradient(
            colors: [Color(0xFF232F55), Color(0xFF0D1430), Color(0xFF1B2547)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF33415F), Color(0xFF1D2942), Color(0xFF2C3A58)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    canvas.drawRRect(
      rrect,
      Paint()..shader = bezel.createShader(rect),
    );

    // Inner board paper with faint radial light from the center.
    final inner = Rect.fromLTWH(
      tile * 0.18, tile * 0.18, size.width - tile * 0.36, size.height - tile * 0.36);
    final innerR = RRect.fromRectAndRadius(inner, Radius.circular(tile * 0.42));
    final glow = RadialGradient(
      colors: [
        Colors.white.withOpacity(isDark ? 0.10 : 0.55),
        _paper.withOpacity(isDark ? 0.04 : 0.12),
        Colors.transparent,
      ],
      stops: const [0.0, 0.55, 1.0],
      center: Alignment.center,
      radius: 0.85,
    );
    canvas.drawRRect(innerR, Paint()..color = _paper);
    canvas.drawRRect(innerR, Paint()..shader = glow.createShader(inner));

    // Linen texture: deterministic micro-dots at very low alpha.
    final dotPaint = Paint()
      ..color = (isDark ? Colors.white : const Color(0xFF5A6272))
          .withOpacity(0.05);
    for (int r = 0; r < 15; r++) {
      for (int c = 0; c < 15; c++) {
        final seed = (r * 13 + c * 7) % 5;
        if (seed != 0) continue;
        canvas.drawCircle(
          Offset((c + 0.72) * tile, (r + 0.28) * tile),
          tile * 0.03,
          dotPaint,
        );
      }
    }

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = _goldFoil.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(2.0, tile * 0.09),
    );
  }

  // --- Corner yards: frosted glass + radial glow + deep wells -------------
  void _drawYards(Canvas canvas, double tile) {
    void yard(double col, double row, LudoColor color) {
      final isActive = activeColor == color;
      final outer = Rect.fromLTWH(col * tile, row * tile, tile * 6, tile * 6);

      // Tinted glass base.
      final glass = LinearGradient(
        colors: [
          Color.alphaBlend(color.primary.withOpacity(0.85), const Color(0xFF1B2547)),
          Color.alphaBlend(color.darkShade.withOpacity(0.95), const Color(0xFF0D1430)),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      final outerR = RRect.fromRectAndRadius(outer, Radius.circular(tile * 0.4));
      canvas.drawRRect(outerR, Paint()..shader = glass.createShader(outer));

      // Radial aura from yard center.
      final auraCenter = Offset((col + 3) * tile, (row + 3) * tile);
      canvas.drawCircle(
        auraCenter,
        tile * 3.1,
        Paint()
          ..shader = RadialGradient(
            colors: [color.lightGlow.withOpacity(0.35), Colors.transparent],
          ).createShader(Rect.fromCircle(center: auraCenter, radius: tile * 3.1)),
      );

      // Active-turn neon rim.
      if (isActive) {
        canvas.drawRRect(
          outerR,
          Paint()
            ..color = color.lightGlow.withOpacity(0.95)
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(2.5, tile * 0.12)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, tile * 0.06),
        );
      }
      canvas.drawRRect(
        outerR,
        Paint()
          ..color = Colors.white.withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      // Ivory holding panel — widened slightly so the spread-out token
      // wells plus the middle dice all sit inside it.
      final panel = Rect.fromLTWH(
        (col + 0.7) * tile, (row + 0.7) * tile, tile * 4.6, tile * 4.6);
      final panelR = RRect.fromRectAndRadius(panel, Radius.circular(tile * 0.3));
      canvas.drawRRect(
        panelR,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFF1EAD9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(panel),
      );
      canvas.drawRRect(
        panelR,
        Paint()
          ..color = _ink.withOpacity(0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      // Soft drop shadow inside panel.
      canvas.drawRRect(
        panelR,
        Paint()
          ..color = Colors.black.withOpacity(0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = tile * 0.12
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, tile * 0.08),
      );

      // Deep token wells.
      for (final slot in BoardCoordinates.baseSlots[color]!) {
        final c = slot.toOffset(tile);
        // Well pit.
        canvas.drawCircle(c, tile * 0.52, Paint()..color = const Color(0xFFD9D2C2));
        canvas.drawCircle(
          c + Offset(0, tile * 0.06),
          tile * 0.44,
          Paint()..color = Colors.white.withOpacity(0.85),
        );
        // Colored rim ring.
        canvas.drawCircle(
          c,
          tile * 0.52,
          Paint()
            ..color = color.primary
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(2.0, tile * 0.10),
        );
        if (isActive) {
          canvas.drawCircle(
            c,
            tile * 0.58,
            Paint()
              ..color = color.lightGlow.withOpacity(0.7)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3),
          );
        }
      }
    }

    yard(0, 0, LudoColor.red);
    yard(9, 0, LudoColor.green);
    yard(9, 9, LudoColor.yellow);
    yard(0, 9, LudoColor.blue);
  }

  // --- Track: big pearl cells with crisp borders ---------------------------
  void _drawTrackCells(Canvas canvas, double tile) {
    for (final pt in BoardCoordinates.outerTrack) {
      final rect = Rect.fromLTWH(
        pt.col * tile + 0.8, pt.row * tile + 0.8, tile - 1.6, tile - 1.6);
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(tile * 0.14));
      // Pearl gradient + top highlight line for a tactile feel.
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFEFE8D8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(rect),
      );
      canvas.drawLine(
        Offset(rect.left + tile * 0.18, rect.top + 1.5),
        Offset(rect.right - tile * 0.18, rect.top + 1.5),
        Paint()
          ..color = Colors.white.withOpacity(0.9)
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = _trackRule
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }
  }

  void _drawHomeStretches(Canvas canvas, double tile) {
    for (final entry in BoardCoordinates.homeStretches.entries) {
      final color = entry.key;
      for (int i = 0; i < entry.value.length; i++) {
        final pt = entry.value[i];
        final rect = Rect.fromLTWH(
          pt.col * tile + 1.0, pt.row * tile + 1.0, tile - 2.0, tile - 2.0);
        final rrect = RRect.fromRectAndRadius(rect, Radius.circular(tile * 0.16));
        canvas.drawRRect(
          rrect,
          Paint()
            ..shader = LinearGradient(
              colors: [color.lightGlow.withOpacity(0.85), color.primary, color.darkShade],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(rect),
        );
        // Chevron pointing toward center.
        _chevron(canvas, rect.center, tile * 0.20, Colors.white.withOpacity(0.85), color);
        canvas.drawRRect(
          rrect,
          Paint()
            ..color = _ink.withOpacity(0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }
  }

  void _chevron(Canvas canvas, Offset c, double s, Color color, LudoColor owner) {
    // Direction toward board center from the home lane.
    Offset dir;
    switch (owner) {
      case LudoColor.red:
        dir = const Offset(1, 0);
        break;
      case LudoColor.green:
        dir = const Offset(0, 1);
        break;
      case LudoColor.yellow:
        dir = const Offset(-1, 0);
        break;
      case LudoColor.blue:
        dir = const Offset(0, -1);
        break;
    }
    final perp = Offset(-dir.dy, dir.dx);
    final path = Path()
      ..moveTo((c - dir * s + perp * s).dx, (c - dir * s + perp * s).dy)
      ..lineTo((c + dir * s * 0.6).dx, (c + dir * s * 0.6).dy)
      ..lineTo((c - dir * s - perp * s).dx, (c - dir * s - perp * s).dy)
      ..lineTo((c - dir * s * 0.2).dx, (c - dir * s * 0.2).dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  // --- Centre: trophy medallion -------------------------------------------
  void _drawCentre(Canvas canvas, double tile) {
    final centre = Offset(7.5 * tile, 7.5 * tile);
    const r = 1.5;
    final corners = [
      Offset((7.5 - r) * tile, (7.5 - r) * tile),
      Offset((7.5 + r) * tile, (7.5 - r) * tile),
      Offset((7.5 + r) * tile, (7.5 + r) * tile),
      Offset((7.5 - r) * tile, (7.5 + r) * tile),
    ];
    final colors = [LudoColor.red, LudoColor.green, LudoColor.yellow, LudoColor.blue];

    // Petals with rounded joins.
    for (int i = 0; i < 4; i++) {
      final a = corners[i];
      final b = corners[(i + 1) % 4];
      final path = Path()
        ..moveTo(centre.dx, centre.dy)
        ..lineTo(a.dx, a.dy)
        ..quadraticBezierTo(
          (a.dx + b.dx) / 2 + (centre.dx - (a.dx + b.dx) / 2) * 0.12,
          (a.dy + b.dy) / 2 + (centre.dy - (a.dy + b.dy) / 2) * 0.12,
          b.dx, b.dy)
        ..close();
      final color = colors[i];
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: [color.lightGlow, color.primary, color.darkShade],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(path.getBounds()),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
    }

    // Gold crown hub.
    canvas.drawCircle(
      centre, tile * 0.72,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFF3C4), Color(0xFFF2C14E), Color(0xFF9A7600)],
          stops: [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: centre, radius: tile * 0.72)),
    );
    canvas.drawCircle(
      centre, tile * 0.72,
      Paint()
        ..color = const Color(0xFF5C4300)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    _star(canvas, centre, tile * 0.42, Paint()..color = const Color(0xFF5C4300), fill: true);
    _star(canvas, centre + Offset(0, -tile * 0.03), tile * 0.36,
        Paint()..color = Colors.white.withOpacity(0.95), fill: true);
  }

  // --- Safe stars: gold foil, impossible to miss ----------------------------
  void _drawSafeStars(Canvas canvas, double tile) {
    for (final index in BoardCoordinates.safeSquares) {
      if (_startColorFor(index) != null) continue;
      final pt = BoardCoordinates.outerTrack[index];
      final c = pt.toOffset(tile);
      final rect = Rect.fromCenter(center: c, width: tile - 2.0, height: tile - 2.0);
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(tile * 0.16));
      // Gold foil wash behind the star.
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFFF3C4), Color(0xFFF2C14E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(rect),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = _goldDeep
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
      // Embossed star: dark base + bright face.
      _star(canvas, c + const Offset(0, 1.0), tile * 0.34,
          Paint()..color = _goldDeep.withOpacity(0.9), fill: true);
      _star(canvas, c, tile * 0.32, Paint()..color = Colors.white, fill: true);
    }
  }

  // --- Start cells: glowing ring + directional arrow + emblem ---------------
  LudoColor? _startColorFor(int index) {
    if (index == LudoColor.red.startSquare) return LudoColor.red;
    if (index == LudoColor.green.startSquare) return LudoColor.green;
    if (index == LudoColor.yellow.startSquare) return LudoColor.yellow;
    if (index == LudoColor.blue.startSquare) return LudoColor.blue;
    return null;
  }

  void _drawStartCells(Canvas canvas, double tile) {
    for (int i = 0; i < BoardCoordinates.outerTrack.length; i++) {
      final color = _startColorFor(i);
      if (color == null) continue;
      final pt = BoardCoordinates.outerTrack[i];
      final c = pt.toOffset(tile);
      final rect = Rect.fromCenter(center: c, width: tile - 2.0, height: tile - 2.0);
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(tile * 0.16));
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = LinearGradient(
            colors: [color.primary, color.darkShade],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(rect),
      );
      // White inner ring.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: tile * 0.78, height: tile * 0.78),
          Radius.circular(tile * 0.2),
        ),
        Paint()
          ..color = Colors.white.withOpacity(0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
      _arrow(canvas, c, tile * 0.30, Colors.white, i);
    }
  }

  void _arrow(Canvas canvas, Offset centre, double size, Color color, int index) {
    final next = BoardCoordinates.outerTrack[(index + 1) % BoardCoordinates.outerTrack.length];
    final cur = BoardCoordinates.outerTrack[index];
    final d = Offset(
        (next.col - cur.col).sign.toDouble(), (next.row - cur.row).sign.toDouble());
    final w = Offset(-d.dy, d.dx);
    Offset p(double along, double across) =>
        centre + d * (size * along) + w * (size * across);
    final path = Path()
      ..moveTo(p(1.0, 0.0).dx, p(1.0, 0.0).dy)
      ..lineTo(p(0.25, 0.75).dx, p(0.25, 0.75).dy)
      ..lineTo(p(-0.15, 0.30).dx, p(-0.15, 0.30).dy)
      ..lineTo(p(-0.85, 0.30).dx, p(-0.85, 0.30).dy)
      ..lineTo(p(-0.85, -0.30).dx, p(-0.85, -0.30).dy)
      ..lineTo(p(-0.15, -0.30).dx, p(-0.15, -0.30).dy)
      ..lineTo(p(0.25, -0.75).dx, p(0.25, -0.75).dy)
      ..close();
    // Shadow then face.
    canvas.drawPath(path.shift(const Offset(0, 1.2)),
        Paint()..color = Colors.black.withOpacity(0.35));
    canvas.drawPath(path, Paint()..color = color);
  }

  void _star(Canvas canvas, Offset centre, double outer, Paint paint,
      {bool fill = true}) {
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
    if (!fill) paint.style = PaintingStyle.stroke;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) =>
      oldDelegate.isDark != isDark || oldDelegate.activeColor != activeColor;
}
