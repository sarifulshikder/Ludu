import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/board_coordinates.dart';
import '../../models/ludo_color.dart';

/// Tall premium board (§8–§9): the classic 15×15 cross layout drawn on a
/// tall rectangle whose cells are ~1:1.33 (width:height), so it fills a
/// portrait phone edge to edge. All path connections are identical to the
/// standard grid — only the vertical pitch is stretched.
///
/// * Clean light playing surfaces, soft gradients and shadows.
/// * Tinted corner yards with token wells + active-turn glow.
/// * Gold-foil safe stars, glowing start cells, gradient home columns.
/// * Center trophy medallion (4 petals + gold crown hub).
class BoardPainter extends CustomPainter {
  /// Tall-cell proportions (width:height) for portrait phones.
  /// Width is capped by 15 columns, so height carries the size gains.
  static const double cellAspect = 1.45;

  final bool isDark;
  final LudoColor? activeColor;

  BoardPainter({required this.isDark, this.activeColor});

  Color get _trackRule =>
      isDark ? const Color(0xFF8E99B0) : const Color(0xFFA39A87);
  Color get _ink => const Color(0xFF101A30);
  Color get _paper => const Color(0xFFFDFBF6);

  static const Color _goldFoil = Color(0xFFF2C14E);
  static const Color _goldDeep = Color(0xFFB8860B);

  @override
  void paint(Canvas canvas, Size size) {
    final double tw = size.width / 15.0;
    final double th = size.height / 15.0;
    final double tu = min(tw, th);
    _drawShell(canvas, size, tw, th, tu);
    _drawYards(canvas, tw, th, tu);
    _drawTrackCells(canvas, tw, th, tu);
    _drawHomeStretches(canvas, tw, th, tu);
    _drawCentre(canvas, tw, th, tu);
    _drawSafeStars(canvas, tw, th, tu);
    _drawStartCells(canvas, tw, th, tu);
  }

  // --- Shell: bezel + soft vignette ------------------------------------
  void _drawShell(Canvas canvas, Size size, double tw, double th, double tu) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(tu * 0.55));

    final bezel = isDark
        ? const LinearGradient(
            colors: [Color(0xFF232F55), Color(0xFF0D1430), Color(0xFF1B2547)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : const LinearGradient(
            colors: [Color(0xFF3E5C8A), Color(0xFF2A3D5C), Color(0xFF46587A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );
    canvas.drawRRect(
      rrect,
      Paint()..shader = bezel.createShader(rect),
    );

    // Clean light paper with a faint radial light from the center.
    // Minimal margins so every pixel goes to the path cells.
    final inner = Rect.fromLTWH(tw * 0.10, th * 0.10,
        size.width - tw * 0.20, size.height - th * 0.20);
    final innerR =
        RRect.fromRectAndRadius(inner, Radius.circular(tu * 0.42));
    final glow = RadialGradient(
      colors: [
        Colors.white.withOpacity(isDark ? 0.10 : 0.45),
        _paper.withOpacity(isDark ? 0.04 : 0.10),
        Colors.transparent,
      ],
      stops: const [0.0, 0.55, 1.0],
      center: Alignment.center,
      radius: 0.85,
    );
    canvas.drawRRect(innerR, Paint()..color = _paper);
    canvas.drawRRect(innerR, Paint()..shader = glow.createShader(inner));

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = _goldFoil.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(2.0, tu * 0.09),
    );
  }

  // --- Corner yards: tinted glass + wells + active glow ------------------
  void _drawYards(Canvas canvas, double tw, double th, double tu) {
    void yard(double col, double row, LudoColor color) {
      final isActive = activeColor == color;
      final outer =
          Rect.fromLTWH(col * tw, row * th, tw * 6, th * 6);

      final glass = LinearGradient(
        colors: [
          Color.alphaBlend(
              color.primary.withOpacity(0.80), const Color(0xFFFFFFFF)),
          Color.alphaBlend(
              color.primary.withOpacity(0.55), const Color(0xFFF3EEDF)),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
      final outerR =
          RRect.fromRectAndRadius(outer, Radius.circular(tu * 0.4));
      canvas.drawRRect(outerR, Paint()..shader = glass.createShader(outer));

      // Radial aura from yard center.
      final auraCenter = Offset((col + 3) * tw, (row + 3) * th);
      final auraR = tu * 3.1;
      canvas.drawCircle(
        auraCenter,
        auraR,
        Paint()
          ..shader = RadialGradient(
            colors: [color.lightGlow.withOpacity(0.40), Colors.transparent],
          ).createShader(Rect.fromCircle(center: auraCenter, radius: auraR)),
      );

      // Active-turn neon rim.
      if (isActive) {
        canvas.drawRRect(
          outerR,
          Paint()
            ..color = color.primary.withOpacity(0.95)
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(2.5, tu * 0.14)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, tu * 0.06),
        );
      }
      canvas.drawRRect(
        outerR,
        Paint()
          ..color = Colors.white.withOpacity(0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      // Ivory holding panel.
      final panel = Rect.fromLTWH((col + 0.7) * tw, (row + 0.7) * th,
          tw * 4.6, th * 4.6);
      final panelR =
          RRect.fromRectAndRadius(panel, Radius.circular(tu * 0.3));
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
      canvas.drawRRect(
        panelR,
        Paint()
          ..color = Colors.black.withOpacity(0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = tu * 0.12
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, tu * 0.08),
      );

      // Deep token wells.
      for (final slot in BoardCoordinates.baseSlots[color]!) {
        final c = slot.toOffsetXY(tw, th);
        canvas.drawCircle(
            c, tu * 0.52, Paint()..color = const Color(0xFFD9D2C2));
        canvas.drawCircle(
          c + Offset(0, tu * 0.06),
          tu * 0.44,
          Paint()..color = Colors.white.withOpacity(0.85),
        );
        canvas.drawCircle(
          c,
          tu * 0.52,
          Paint()
            ..color = color.primary
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(2.0, tu * 0.10),
        );
        if (isActive) {
          canvas.drawCircle(
            c,
            tu * 0.58,
            Paint()
              ..color = color.primary.withOpacity(0.7)
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

  // --- Track: pearl cells with crisp borders -----------------------------
  void _drawTrackCells(Canvas canvas, double tw, double th, double tu) {
    for (final pt in BoardCoordinates.outerTrack) {
      final rect = Rect.fromLTWH(
          pt.col * tw + 0.8, pt.row * th + 0.8, tw - 1.6, th - 1.6);
      final rrect =
          RRect.fromRectAndRadius(rect, Radius.circular(tu * 0.14));
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
        Offset(rect.left + tw * 0.18, rect.top + 1.5),
        Offset(rect.right - tw * 0.18, rect.top + 1.5),
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

  void _drawHomeStretches(
      Canvas canvas, double tw, double th, double tu) {
    for (final entry in BoardCoordinates.homeStretches.entries) {
      final color = entry.key;
      for (int i = 0; i < entry.value.length; i++) {
        final pt = entry.value[i];
        final rect = Rect.fromLTWH(
            pt.col * tw + 1.0, pt.row * th + 1.0, tw - 2.0, th - 2.0);
        final rrect =
            RRect.fromRectAndRadius(rect, Radius.circular(tu * 0.16));
        canvas.drawRRect(
          rrect,
          Paint()
            ..shader = LinearGradient(
              colors: [
                color.lightGlow.withOpacity(0.85),
                color.primary,
                color.darkShade
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(rect),
        );
        _chevron(canvas, rect.center, tu * 0.24,
            Colors.white.withOpacity(0.85), color);
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

  void _chevron(
      Canvas canvas, Offset c, double s, Color color, LudoColor owner) {
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
  void _drawCentre(Canvas canvas, double tw, double th, double tu) {
    final centre = Offset(7.5 * tw, 7.5 * th);
    final corners = [
      Offset((7.5 - 1.5) * tw, (7.5 - 1.5) * th),
      Offset((7.5 + 1.5) * tw, (7.5 - 1.5) * th),
      Offset((7.5 + 1.5) * tw, (7.5 + 1.5) * th),
      Offset((7.5 - 1.5) * tw, (7.5 + 1.5) * th),
    ];
    final colors = [
      LudoColor.red,
      LudoColor.green,
      LudoColor.yellow,
      LudoColor.blue
    ];

    for (int i = 0; i < 4; i++) {
      final a = corners[i];
      final b = corners[(i + 1) % 4];
      final path = Path()
        ..moveTo(centre.dx, centre.dy)
        ..lineTo(a.dx, a.dy)
        ..quadraticBezierTo(
          (a.dx + b.dx) / 2 + (centre.dx - (a.dx + b.dx) / 2) * 0.12,
          (a.dy + b.dy) / 2 + (centre.dy - (a.dy + b.dy) / 2) * 0.12,
          b.dx,
          b.dy)
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
      centre,
      tu * 0.72,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFF3C4), Color(0xFFF2C14E), Color(0xFF9A7600)],
          stops: [0.0, 0.6, 1.0],
        ).createShader(Rect.fromCircle(center: centre, radius: tu * 0.72)),
    );
    canvas.drawCircle(
      centre,
      tu * 0.72,
      Paint()
        ..color = const Color(0xFF5C4300)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    _star(canvas, centre, tu * 0.42,
        Paint()..color = const Color(0xFF5C4300), fill: true);
    _star(canvas, centre + Offset(0, -tu * 0.03), tu * 0.36,
        Paint()..color = Colors.white.withOpacity(0.95), fill: true);
  }

  // --- Safe stars: gold foil, impossible to miss ----------------------------
  void _drawSafeStars(Canvas canvas, double tw, double th, double tu) {
    for (final index in BoardCoordinates.safeSquares) {
      if (_startColorFor(index) != null) continue;
      final pt = BoardCoordinates.outerTrack[index];
      final c = pt.toOffsetXY(tw, th);
      final rect =
          Rect.fromCenter(center: c, width: tw - 2.0, height: th - 2.0);
      final rrect =
          RRect.fromRectAndRadius(rect, Radius.circular(tu * 0.16));
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
      _star(canvas, c + const Offset(0, 1.0), tu * 0.40,
          Paint()..color = _goldDeep.withOpacity(0.9), fill: true);
      _star(canvas, c, tu * 0.38, Paint()..color = Colors.white,
          fill: true);
    }
  }

  // --- Start cells: glowing ring + directional arrow -------------------------
  LudoColor? _startColorFor(int index) {
    if (index == LudoColor.red.startSquare) return LudoColor.red;
    if (index == LudoColor.green.startSquare) return LudoColor.green;
    if (index == LudoColor.yellow.startSquare) return LudoColor.yellow;
    if (index == LudoColor.blue.startSquare) return LudoColor.blue;
    return null;
  }

  void _drawStartCells(Canvas canvas, double tw, double th, double tu) {
    for (int i = 0; i < BoardCoordinates.outerTrack.length; i++) {
      final color = _startColorFor(i);
      if (color == null) continue;
      final pt = BoardCoordinates.outerTrack[i];
      final c = pt.toOffsetXY(tw, th);
      final rect =
          Rect.fromCenter(center: c, width: tw - 2.0, height: th - 2.0);
      final rrect =
          RRect.fromRectAndRadius(rect, Radius.circular(tu * 0.16));
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = LinearGradient(
            colors: [color.primary, color.darkShade],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(rect),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: tu * 0.78, height: tu * 0.78),
          Radius.circular(tu * 0.2),
        ),
        Paint()
          ..color = Colors.white.withOpacity(0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
      _arrow(canvas, c, tu * 0.34, Colors.white, i);
    }
  }

  void _arrow(
      Canvas canvas, Offset centre, double size, Color color, int index) {
    final next = BoardCoordinates
        .outerTrack[(index + 1) % BoardCoordinates.outerTrack.length];
    final cur = BoardCoordinates.outerTrack[index];
    final d = Offset((next.col - cur.col).sign.toDouble(),
        (next.row - cur.row).sign.toDouble());
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
      oldDelegate.isDark != isDark ||
      oldDelegate.activeColor != activeColor;
}
