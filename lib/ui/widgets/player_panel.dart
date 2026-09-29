import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/theme/ludu_theme.dart';

import '../../models/player.dart';
import '../board/token_widget.dart';

/// Compact Player Chip (slim panel, 48–54 dp tall).
///
/// * Pawn icon + Name + 4 progress pills (one per token, filled when that
///   token reaches the center home).
/// * In Team mode, shows a compact team badge.
/// * Active player's chip glows clearly with an outer luminous aura.
/// * Face-to-face mode: when [isRotated] is true, the chip rotates 180° so
///   opponents sitting across the phone can read it right-side-up.
class PlayerPanel extends StatelessWidget {
  final Player player;
  final int playerIndex;
  final bool isActive;
  final bool canRoll;
  final VoidCallback? onRoll;
  final bool isDark;
  final bool teamMode;
  final Player? partner;
  final double timeScale;
  final bool isRotated;
  final LuduThemeConfig? themeConfig;

  /// Optional dice value retained for backward compatibility with tests.
  final int? diceValue;

  const PlayerPanel({
    super.key,
    required this.player,
    required this.playerIndex,
    required this.isActive,
    this.diceValue,
    this.canRoll = false,
    this.onRoll,
    this.isDark = true,
    this.teamMode = false,
    this.partner,
    this.timeScale = 1.0,
    this.isRotated = false,
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
    final cfg = themeConfig ?? LuduTheme.royalGold;
    final color = player.color;
    final themeColor = cfg.colorOf(color);
    final finished = player.finishRank != null;
    final teamAccent =
        teamMode ? Player.teamAccent(player.teamId) : themeColor.primary;

    Widget chipContent = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cfg.surfaceCard,
        gradient: LinearGradient(
          colors: isActive
              ? [
                  Color.alphaBlend(
                    themeColor.primary.withOpacity(0.38),
                    cfg.surfaceCard,
                  ),
                  Color.alphaBlend(
                    themeColor.primary.withOpacity(0.18),
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
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? themeColor.primary
              : cfg.surfaceCardBorder.withOpacity(0.9),
          width: isActive ? 2.2 : 1.0,
        ),
        boxShadow: [
          if (isActive)
            BoxShadow(
              color: themeColor.primary.withOpacity(0.48),
              blurRadius: 14,
              spreadRadius: 1.0,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Opacity(
        opacity: finished ? 0.72 : 1.0,
        child: Row(
          children: [
            // Pawn avatar icon
            PinAvatar(
              color: color,
              size: 28,
              isDark: isDark,
              themePlayerColor: themeColor,
            ),
            const SizedBox(width: 8),
            // Name + team badge + progress pills
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          player.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                            color: isActive
                                ? Colors.white
                                : Colors.white.withOpacity(0.88),
                          ),
                        ),
                      ),
                      if (teamMode) ...[
                        const SizedBox(width: 4),
                        _TeamBadge(teamId: player.teamId),
                      ],
                      if (finished) ...[
                        const SizedBox(width: 4),
                        Text(
                          ordinal(player.finishRank!),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFF2C14E),
                          ),
                        ),
                      ] else if (isActive) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
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
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: themeColor.lightGlow,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Progress pills: 4 pills in classic, 8 pills (own + partner) in team mode
                  ProgressPills(
                    homeFlags: [
                      ...player.tokens.map((t) => t.isHome),
                      if (teamMode && partner != null)
                        ...partner!.tokens.map((t) => t.isHome),
                    ],
                    fill: teamMode ? teamAccent : themeColor.primary,
                    idle: Colors.white.withOpacity(0.12),
                    accent: isActive ? themeColor.primary.withOpacity(0.4) : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (isRotated) {
      chipContent = Transform.rotate(
        angle: math.pi,
        child: chipContent,
      );
    }

    return chipContent;
  }
}

/// Compact team badge pill in 2v2 mode.
class _TeamBadge extends StatelessWidget {
  final int teamId;

  const _TeamBadge({required this.teamId});

  @override
  Widget build(BuildContext context) {
    final color = Player.teamAccent(teamId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.20),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.85), width: 0.9),
      ),
      child: Text(
        Player.teamName(teamId).toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
          color: color,
        ),
      ),
    );
  }
}

/// 4 Progress pills (one per token) inside the player chip.
/// Fills when that token reaches the center home.
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < homeFlags.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          _Pill(
            filled: homeFlags[i],
            fill: fill,
            idle: idle,
          ),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final bool filled;
  final Color fill;
  final Color idle;

  const _Pill({
    required this.filled,
    required this.fill,
    required this.idle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 14,
      height: 5.5,
      decoration: BoxDecoration(
        color: filled ? fill : idle,
        borderRadius: BorderRadius.circular(3),
        boxShadow: filled
            ? [
                BoxShadow(
                  color: fill.withOpacity(0.65),
                  blurRadius: 4,
                  offset: const Offset(0, 0.5),
                ),
              ]
            : null,
      ),
    );
  }
}
