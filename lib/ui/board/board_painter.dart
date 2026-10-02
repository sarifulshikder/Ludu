import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/board_coordinates.dart';
import '../../core/theme/ludu_theme.dart';
import '../../models/game_settings.dart';
import '../../models/ludo_color.dart';

/// Perfectly Square 15×15 Board Painter.
///
/// * 1:1 square aspect ratio, edge-to-edge across screen width.
/// * Ultra-thin cell borders (0.8 dp) to maximize cell area.
/// * Theme-specific rendering for Royal Gold, Neon Glass, and Wooden Luxe.
/// * High-contrast path, safe squares with stars, directional arrows, and
///   center trophy medallion.
class BoardPainter extends CustomPainter {
  /// Perfect square cell proportions (1.0).
  static const double cellAspect = 1.0;

  final bool isDark;
  final LudoColor? activeColor;
  final AppThemeMode themeMode;
  final LuduThemeConfig? themeConfig;

  BoardPainter({
    required this.isDark,
    this.activeColor,
    this.themeMode = AppThemeMode.royalGold,
    this.themeConfig,
  });

  LuduThemeConfig get _cfg =>
      themeConfig ?? LuduTheme.forMode(themeMode, isDark: isDark);

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

  // --- Shell: edge-to-edge board with metallic/neon inlay -----------------
  void _drawShell(Canvas canvas, Size size, double tw, double th, double tu) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(tu * 0.45));

    final bezel = LinearGradient(
      colors: [_cfg.boardBezelStart, _cfg.boardBezelEnd],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    canvas.drawRRect(rrect, Paint()..shader = bezel.createShader(rect));

    // Clean paper base fill (no outer margin)
    final innerR = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.8, 0.8, size.width - 1.6, size.height - 1.6),
      Radius.circular(tu * 0.40),
    );
    canvas.drawRRect(innerR, Paint()..color = _cfg.boardPaper);

    // Subtle center glow
    final glow = RadialGradient(
      colors: _cfg.centerGlowColors,
      stops: const [0.0, 0.55, 1.0],
      center: Alignment.center,
      radius: 0.85,
    );
    canvas.drawRRect(innerR, Paint()..shader = glow.createShader(rect));

    // Outer inlay line
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = _cfg.boardInlayLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = _cfg.boardInlayWidth,
    );
  }

  // --- Corner yards: 6x6 cells in each corner ----------------------------
  void _drawYards(Canvas canvas, double tw, double th, double tu) {
    final totalW = tw * 15.0;
    final totalH = th * 15.0;
    void yard(double col, double row, LudoColor color) {
      final isActive = activeColor == color;
      final themeColor = _cfg.colorOf(color);
      // Use BoardLayout so the yard rect matches the non-uniform grid
      final left = BoardLayout.colLeft(col, totalW);
      final top = BoardLayout.rowTop(row, totalH);
      final right = BoardLayout.colLeft(col + 6, totalW);
      final bottom = BoardLayout.rowTop(row + 6, totalH);
      final outer = Rect.fromLTRB(left, top, right, bottom);

      // Hard vivid fill — just the pure player color, no dark blending
      final outerR =
          RRect.fromRectAndRadius(outer, Radius.circular(tu * _cfg.yardBezelRadius));
      canvas.drawRRect(
        outerR,
        Paint()
          ..shader = LinearGradient(
            colors: [
              themeColor.primary,
              themeColor.darkShade,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(outer),
      );

      // Active-turn neon/gold rim
      if (isActive) {
        canvas.drawRRect(
          outerR,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(3.0, tu * 0.14)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, tu * 0.07),
        );
      }
      canvas.drawRRect(
        outerR,
        Paint()
          ..color = Colors.white.withOpacity(0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );

      // Inner holding panel — dark neutral so coins pop
      final panelLeft = left + (right - left) * 0.10;
      final panelTop = top + (bottom - top) * 0.10;
      final panelW = (right - left) * 0.80;
      final panelH = (bottom - top) * 0.80;
      final panel = Rect.fromLTWH(panelLeft, panelTop, panelW, panelH);
      final panelR =
          RRect.fromRectAndRadius(panel, Radius.circular(tu * 0.28));
      canvas.drawRRect(
        panelR,
        Paint()
          ..shader = LinearGradient(
            colors: [_cfg.yardPanelStart, _cfg.yardPanelEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(panel),
      );
      canvas.drawRRect(
        panelR,
        Paint()
          ..color = Colors.white.withOpacity(0.50)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      // Deep token wells (2x2 base slots) spaced evenly in base panel
      final wellR = tu * 0.54;
      for (final slot in BoardCoordinates.baseSlots[color]!) {
        final c = slot.toOffsetXY(tw, th);
        // Well recessed cavity
        canvas.drawCircle(
          c,
          wellR,
          Paint()..color = _cfg.tokenWellColor,
        );
        // Well rim
        canvas.drawCircle(
          c,
          wellR,
          Paint()
            ..color = _cfg.tokenWellRim.withOpacity(0.90)
            ..style = PaintingStyle.stroke
            ..strokeWidth = max(1.8, tu * 0.08),
        );
        if (isActive) {
          canvas.drawCircle(
            c,
            wellR + 2.5,
            Paint()
              ..color = Colors.white.withOpacity(0.60)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }
      }
    }

    yard(0, 0, LudoColor.red);
    yard(9, 0, LudoColor.green);
    yard(9, 9, LudoColor.yellow);
    yard(0, 9, LudoColor.blue);
  }

  // --- Track: pearl cells with razor-thin borders (0.8 dp) ----------------
  void _drawTrackCells(Canvas canvas, double tw, double th, double tu) {
    final totalW = tw * 15.0;
    final totalH = th * 15.0;
    for (final pt in BoardCoordinates.outerTrack) {
      final cellR = BoardLayout.cellRect(pt.col, pt.row, totalW, totalH);
      final rect = Rect.fromLTWH(
        cellR.left + 0.4,
        cellR.top + 0.4,
        cellR.width - 0.8,
        cellR.height - 0.8,
      );
      final rrect =
          RRect.fromRectAndRadius(rect, Radius.circular(tu * 0.12));

      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = LinearGradient(
            colors: [_cfg.cellBaseStart, _cfg.cellBaseEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(rect),
      );

      // Subtle top highlight sheen
      canvas.drawLine(
        Offset(rect.left + cellR.width * 0.15, rect.top + 1.0),
        Offset(rect.right - cellR.width * 0.15, rect.top + 1.0),
        Paint()
          ..color = _cfg.cellHighlightLine
          ..strokeWidth = 1.0
          ..strokeCap = StrokeCap.round,
      );

      // Razor thin border
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = _cfg.cellBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = _cfg.cellBorderWidth,
      );
    }
  }


  // --- Home stretches: 5-cell lanes to center -----------------------------
  void _drawHomeStretches(Canvas canvas, double tw, double th, double tu) {
    final totalW = tw * 15.0;
    final totalH = th * 15.0;
    for (final entry in BoardCoordinates.homeStretches.entries) {
      final color = entry.key;
      final themeColor = _cfg.colorOf(color);
      for (int i = 0; i < entry.value.length; i++) {
        final pt = entry.value[i];
        final cellR = BoardLayout.cellRect(pt.col, pt.row, totalW, totalH);
        final rect = Rect.fromLTWH(
          cellR.left + 0.5,
          cellR.top + 0.5,
          cellR.width - 1.0,
          cellR.height - 1.0,
        );
        final rrect =
            RRect.fromRectAndRadius(rect, Radius.circular(tu * 0.14));

        canvas.drawRRect(
          rrect,
          Paint()
            ..shader = LinearGradient(
              colors: [
                themeColor.lightGlow.withOpacity(0.90),
                themeColor.primary,
                themeColor.darkShade,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(rect),
        );

        _chevron(
          canvas,
          rect.center,
          tu * 0.22,
          Colors.white.withOpacity(0.90),
          color,
        );

        canvas.drawRRect(
          rrect,
          Paint()
            ..color = _cfg.boardInlayLine.withOpacity(0.55)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.9,
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

  // --- Centre: 3x3 finish trophy medallion -------------------------------
  void _drawCentre(Canvas canvas, double tw, double th, double tu) {
    final centre = Offset(7.5 * tw, 7.5 * th);
    final nw = Offset(6.0 * tw, 6.0 * th);
    final ne = Offset(9.0 * tw, 6.0 * th);
    final se = Offset(9.0 * tw, 9.0 * th);
    final sw = Offset(6.0 * tw, 9.0 * th);

    // 4 triangles of the pinwheel tiling the 3x3 block exactly:
    // Red West, Green North, Yellow East, Blue South
    final triangles = [
      (color: LudoColor.red, p1: sw, p2: nw),
      (color: LudoColor.green, p1: nw, p2: ne),
      (color: LudoColor.yellow, p1: ne, p2: se),
      (color: LudoColor.blue, p1: se, p2: sw),
    ];

    for (final tri in triangles) {
      final path = Path()
        ..moveTo(centre.dx, centre.dy)
        ..lineTo(tri.p1.dx, tri.p1.dy)
        ..lineTo(tri.p2.dx, tri.p2.dy)
        ..close();

      final themeColor = _cfg.colorOf(tri.color);
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: [
              themeColor.lightGlow,
              themeColor.primary,
              themeColor.darkShade,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(path.getBounds()),
      );

      // Gold inlay divider line
      canvas.drawPath(
        path,
        Paint()
          ..color = _cfg.boardInlayLine.withOpacity(0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    // Outer 3x3 border
    canvas.drawRect(
      Rect.fromLTWH(6.0 * tw, 6.0 * th, 3.0 * tw, 3.0 * th),
      Paint()
        ..color = _cfg.boardInlayLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // Center gold star medallion hub
    final hubR = tu * 0.48;
    canvas.drawCircle(
      centre,
      hubR,
      Paint()
        ..shader = RadialGradient(
          colors: [_cfg.hubCenterStart, _cfg.hubCenterEnd],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: centre, radius: hubR)),
    );
    canvas.drawCircle(
      centre,
      hubR,
      Paint()
        ..color = _cfg.hubBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8,
    );
    _star(canvas, centre, hubR * 0.58,
        Paint()..color = _cfg.hubIconColor, fill: true);
    _star(canvas, centre + const Offset(0, -0.8), hubR * 0.50,
        Paint()..color = Colors.white.withOpacity(0.95), fill: true);
  }

  // --- Safe stars: prominent foil / neon / brass stars ---------------------
  void _drawSafeStars(Canvas canvas, double tw, double th, double tu) {
    final totalW = tw * 15.0;
    final totalH = th * 15.0;
    for (final index in BoardCoordinates.safeSquares) {
      if (_startColorFor(index) != null) continue;
      final pt = BoardCoordinates.outerTrack[index];
      final c = pt.toOffsetXY(tw, th);
      final cellR = BoardLayout.cellRect(pt.col, pt.row, totalW, totalH);
      final rect = Rect.fromCenter(
        center: c,
        width: cellR.width - 1.0,
        height: cellR.height - 1.0,
      );
      final rrect =
          RRect.fromRectAndRadius(rect, Radius.circular(tu * 0.14));

      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = LinearGradient(
            colors: [_cfg.safeCellStart, _cfg.safeCellEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(rect),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = _cfg.safeStarDeep
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      _star(
        canvas,
        c + const Offset(0, 1.0),
        tu * 0.38,
        Paint()..color = _cfg.safeStarDeep.withOpacity(0.8),
        fill: true,
      );
      _star(
        canvas,
        c,
        tu * 0.36,
        Paint()..color = _cfg.safeStarColor,
        fill: true,
      );
    }
  }


  // --- Start cells: glowing launch square with directional arrow ---------
  LudoColor? _startColorFor(int index) {
    if (index == LudoColor.red.startSquare) return LudoColor.red;
    if (index == LudoColor.green.startSquare) return LudoColor.green;
    if (index == LudoColor.yellow.startSquare) return LudoColor.yellow;
    if (index == LudoColor.blue.startSquare) return LudoColor.blue;
    return null;
  }

  void _drawStartCells(Canvas canvas, double tw, double th, double tu) {
    final totalW = tw * 15.0;
    final totalH = th * 15.0;
    for (int i = 0; i < BoardCoordinates.outerTrack.length; i++) {
      final color = _startColorFor(i);
      if (color == null) continue;
      final themeColor = _cfg.colorOf(color);
      final pt = BoardCoordinates.outerTrack[i];
      final c = pt.toOffsetXY(tw, th);
      final cellR = BoardLayout.cellRect(pt.col, pt.row, totalW, totalH);
      final rect = Rect.fromCenter(
        center: c,
        width: cellR.width - 1.0,
        height: cellR.height - 1.0,
      );
      final rrect =
          RRect.fromRectAndRadius(rect, Radius.circular(tu * 0.14));

      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = LinearGradient(
            colors: [themeColor.primary, themeColor.darkShade],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(rect),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: tu * 0.76, height: tu * 0.76),
          Radius.circular(tu * 0.18),
        ),
        Paint()
          ..color = Colors.white.withOpacity(0.92)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      _arrow(canvas, c, tu * 0.32, Colors.white, i);
    }
  }


  void _arrow(
      Canvas canvas, Offset centre, double size, Color color, int index) {
    final next = BoardCoordinates
        .outerTrack[(index + 1) % BoardCoordinates.outerTrack.length];
    final cur = BoardCoordinates.outerTrack[index];
    final d = Offset(
      (next.col - cur.col).sign.toDouble(),
      (next.row - cur.row).sign.toDouble(),
    );
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

    canvas.drawPath(
      path.shift(const Offset(0, 1.2)),
      Paint()..color = Colors.black.withOpacity(0.35),
    );
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
      oldDelegate.activeColor != activeColor ||
      oldDelegate.themeMode != themeMode;
}
