
import 'package:flutter/material.dart';

import '../../core/env.dart';
import '../../core/theme/ludu_theme.dart';
import '../../models/game_settings.dart';
import '../../models/player.dart';
import '../board/token_widget.dart';
import 'dice_widget.dart';

/// Player Seat Dock (§11: Play Store Ludo style).
///
/// Features:
/// - 4 docks visible at all times (Red top-left, Green top-right,
///   Yellow bottom-right, Blue bottom-left).
/// - Dock width ~half screen, containing:
///   * Pawn icon
///   * Name stacked above progress pills (shrunk before truncating)
///   * 4 progress pills (one per token, filled only when token reaches center)
///   * Embedded dice (72–80 dp) on the side facing the board's center
///     (mirrored: Red/Blue info left, dice right; Green/Yellow dice left, info right)
/// - Active player: dock glows in player color, dice is ~1.15x larger with a gentle pulse,
///   animated gold arrow points at the dice, small "TURN" tag. Only this dice is tappable.
/// - Inactive players: dimmed (~55% opacity), not tappable, showing last rolled value.
///   Before first roll, shows neutral face.
/// - Arrow hidden while rolling or while tokens move.
/// - Face-to-face mode: when [isRotated] is true, top docks rotate 180° via [RotatedBox]
///   so touch hit testing and rendering are both upside-down for the opposing player.
/// - Team mode (§8): shows team badge ("Team A" / "Team B") and combined progress ("X/8 home").
class PlayerPanel extends StatelessWidget {
  final Player player;
  final int playerIndex;
  final bool isActive;
  final bool canRoll;
  final bool isRolling;
  final bool boardAnimating;
  final int? diceValue;
  final VoidCallback? onRoll;
  final bool isDark;
  final bool teamMode;
  final Player? partner;
  final double timeScale;
  final bool isRotated;
  final bool diceOnLeft;
  final AppThemeMode themeMode;
  final LuduThemeConfig? themeConfig;

  const PlayerPanel({
    super.key,
    required this.player,
    required this.playerIndex,
    required this.isActive,
    this.diceValue,
    this.canRoll = false,
    this.isRolling = false,
    this.boardAnimating = false,
    this.onRoll,
    this.isDark = true,
    this.teamMode = false,
    this.partner,
    this.timeScale = 1.0,
    this.isRotated = false,
    this.diceOnLeft = false,
    this.themeMode = AppThemeMode.royalGold,
    this.themeConfig,
  });

  static String ordinal(int n) {
    if (n == 1) return '1st';
    if (n == 2) return '2nd';
    if (n == 3) return '3rd';
    return '${n}th';
  }

  @override
  Widget build(BuildContext context) {
    final cfg = themeConfig ??
        (isDark ? LuduTheme.royalGold : LuduTheme.royalGoldLight);
    final color = player.color;
    final themeColor = cfg.colorOf(color);
    final finished = player.finishRank != null;
    final teamAccent =
        teamMode ? Player.teamAccent(player.teamId) : themeColor.primary;

    const double diceSize = 74.0;
    final bool showArrow = isActive &&
        canRoll &&
        !isRolling &&
        !boardAnimating &&
        !finished;

    // Team progress calculation
    final int ownHome = player.tokensHomeCount;
    final int partnerHome = partner?.tokensHomeCount ?? 0;
    final int teamHome = ownHome + partnerHome;

    // 1. Info Area (Avatar, Name, Badges, Pills)
    Widget buildInfoArea() {
      final nameColor = isDark
          ? (isActive ? Colors.white : Colors.white.withOpacity(0.85))
          : (isActive ? themeColor.darkShade : const Color(0xFF1B1812));

      return Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PinAvatar(
                  color: color,
                  size: 26,
                  isDark: isDark,
                  themePlayerColor: themeColor,
                ),
                const SizedBox(width: 5),
                // Name + all badges share the FittedBox so they scale
                // down together if the dock is narrow (e.g. team mode
                // with both TeamBadge + TURN visible simultaneously).
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          player.name,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                            color: nameColor,
                          ),
                        ),
                        if (teamMode) ...[ 
                          const SizedBox(width: 3),
                          _TeamBadge(teamId: player.teamId),
                        ],
                        if (finished) ...[
                          const SizedBox(width: 3),
                          Text(
                            ordinal(player.finishRank!),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFF2C14E),
                            ),
                          ),
                        ] else if (isActive) ...[
                          const SizedBox(width: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: themeColor.primary.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: themeColor.primary,
                                width: 0.9,
                              ),
                            ),
                            child: Text(
                              'TURN',
                              style: TextStyle(
                                fontSize: 8.0,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                                color: isDark
                                    ? themeColor.lightGlow
                                    : themeColor.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            // Progress pills (§11 & §8: 4 pills per player; 8 in team mode)
            ProgressPills(
              homeFlags: [
                ...player.tokens.map((t) => t.isHome),
                if (teamMode && partner != null)
                  ...partner!.tokens.map((t) => t.isHome),
              ],
              fill: teamMode ? teamAccent : themeColor.primary,
              idle: isDark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.black.withOpacity(0.10),
              accent: isActive ? themeColor.primary.withOpacity(0.4) : null,
            ),
            if (teamMode) ...[
              const SizedBox(height: 2),
              Text(
                '$teamHome/8 home',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ],
          ],
        ),
      );
    }


    // 2. Embedded Dice with optional animated arrow
    Widget buildDiceArea() {
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Transform.scale(
            scale: isActive ? 1.14 : 1.0,
            child: DiceWidget(
              value: diceValue,
              isRolling: isRolling && isActive,
              canRoll: isActive && canRoll,
              activeColor: color,
              size: diceSize,
              timeScale: timeScale,
              isRotated: false, // Rotation handled by RotatedBox on the dock
              themeMode: themeMode,
              themeConfig: cfg,
              onRoll: () => onRoll?.call(),
            ),
          ),
          if (showArrow)
            Positioned(
              top: -14,
              child: const _AnimatedGoldArrow(),
            ),
        ],
      );
    }

    // 3. Dock Container
    Widget dockContent = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: cfg.surfaceCard,
        gradient: LinearGradient(
          colors: isActive
              ? [
                  Color.alphaBlend(
                    themeColor.primary.withOpacity(0.32),
                    cfg.surfaceCard,
                  ),
                  Color.alphaBlend(
                    themeColor.primary.withOpacity(0.14),
                    cfg.surfaceCard,
                  ),
                ]
              : [
                  cfg.surfaceCard,
                  cfg.surfaceCard,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? themeColor.primary
              : cfg.surfaceCardBorder.withOpacity(0.85),
          width: isActive ? 2.2 : 1.0,
        ),
        boxShadow: [
          if (isActive)
            BoxShadow(
              color: themeColor.primary.withOpacity(0.48),
              blurRadius: 16,
              spreadRadius: 1.0,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Opacity(
        // Inactive players dimmed to ~55% opacity (§11)
        opacity: isActive ? 1.0 : (finished ? 0.45 : 0.55),
        child: Row(
          children: diceOnLeft
              ? [
                  buildDiceArea(),
                  const SizedBox(width: 8),
                  buildInfoArea(),
                ]
              : [
                  buildInfoArea(),
                  const SizedBox(width: 8),
                  buildDiceArea(),
                ],
        ),
      ),
    );

    // Face-to-face mode (§11): RotatedBox rotates both drawing and tap targets 180°
    if (isRotated) {
      dockContent = RotatedBox(
        quarterTurns: 2,
        child: dockContent,
      );
    }

    return dockContent;
  }
}

/// Animated gold arrow pointing down at the active dice (§11).
class _AnimatedGoldArrow extends StatefulWidget {
  const _AnimatedGoldArrow();

  @override
  State<_AnimatedGoldArrow> createState() => _AnimatedGoldArrowState();
}

class _AnimatedGoldArrowState extends State<_AnimatedGoldArrow>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bounce = Tween<double>(begin: 0.0, end: 5.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (!isFlutterTest) {
      _controller.repeat(reverse: true);
    } else {
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bounce,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _bounce.value),
          child: CustomPaint(
            size: const Size(18, 12),
            painter: _GoldArrowPainter(),
          ),
        );
      },
    );
  }
}

class _GoldArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w / 2, h)
      ..lineTo(0, 0)
      ..lineTo(w * 0.35, h * 0.25)
      ..lineTo(w * 0.35, 0)
      ..lineTo(w * 0.65, 0)
      ..lineTo(w * 0.65, h * 0.25)
      ..lineTo(w, 0)
      ..close();

    final rect = Offset.zero & size;
    // Metallic gold gradient
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFF7D6), Color(0xFFF2C14E), Color(0xFFB8860B)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect);

    // Drop shadow
    canvas.drawPath(
      path.shift(const Offset(0, 1.5)),
      Paint()
        ..color = Colors.black.withOpacity(0.40)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );

    canvas.drawPath(path, fillPaint);

    // White rim highlight
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  @override
  bool shouldRepaint(covariant _GoldArrowPainter old) => false;
}

/// Compact team badge in 2v2 mode (§8).
class _TeamBadge extends StatelessWidget {
  final int teamId;

  const _TeamBadge({required this.teamId});

  @override
  Widget build(BuildContext context) {
    final color = Player.teamAccent(teamId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withOpacity(0.20),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.85), width: 0.9),
      ),
      child: Text(
        teamId == 0 ? 'Team A' : 'Team B',
        style: TextStyle(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

/// Home-progress pills (§A4): one per token, filled only when that token
/// reaches center home.
class ProgressPills extends StatelessWidget {
  final List<bool> homeFlags;
  final Color fill;
  final Color idle;
  final Color? accent;

  const ProgressPills({
    super.key,
    required this.homeFlags,
    required this.fill,
    required this.idle,
    this.accent,
  });

  int get filledCount => homeFlags.where((h) => h).length;

  @override
  Widget build(BuildContext context) {
    final count = homeFlags.length;
    const perRow = 4;
    final rowCount = (count / perRow).ceil();
    final rows = <Widget>[];

    for (int r = 0; r < rowCount; r++) {
      final rowChildren = <Widget>[];
      for (int c = 0; c < perRow; c++) {
        final idx = r * perRow + c;
        if (idx >= count) break;
        if (c > 0) rowChildren.add(const SizedBox(width: 3));
        rowChildren.add(
          Expanded(
            child: _Pill(
              filled: homeFlags[idx],
              fill: fill,
              idle: idle,
              height: count > 4 ? 4.0 : 5.5,
            ),
          ),
        );
      }
      if (r > 0) rows.add(const SizedBox(height: 2));
      rows.add(Row(children: rowChildren));
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

class _Pill extends StatelessWidget {
  final bool filled;
  final Color fill;
  final Color idle;
  final double height;

  const _Pill({
    required this.filled,
    required this.fill,
    required this.idle,
    this.height = 5.5,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: height,
      decoration: BoxDecoration(
        color: filled ? fill : idle,
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: filled
            ? [
                BoxShadow(
                  color: fill.withOpacity(0.65),
                  blurRadius: 3,
                  offset: const Offset(0, 0.5),
                ),
              ]
            : null,
      ),
    );
  }
}
