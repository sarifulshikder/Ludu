import 'package:flutter/material.dart';

import '../../models/ludo_color.dart';
import '../../models/player.dart';
import '../board/token_widget.dart';
import 'dice_widget.dart';

/// Player panel (§8): avatar, name, home progress and the player's own big
/// dice. Only the active player's dice is highlighted and tappable; their
/// panel glows and shows a clear "Your turn" label.
///
/// * Until a player rolls for the first time their dice shows the neutral
///   blank face (§A5) — never a fake number.
/// * One pill per token; a pill fills only when that token reaches the
///   center, so pills always match the real state (§A4). In Team 2v2 the
///   eight pills are own + partner, matching the "X/8 home" text (§E).
/// * Names scale down to fit and only ellipsize when a custom name is
///   genuinely too long (§A3).
class PlayerPanel extends StatelessWidget {
  final Player player;
  final int playerIndex;
  final bool isActive;

  /// Face to show: null = neutral blank (never rolled yet).
  final int? diceValue;
  final bool canRoll;
  final VoidCallback onRoll;
  final bool isDark;
  final bool teamMode;
  final Player? partner;
  final double timeScale;

  const PlayerPanel({
    super.key,
    required this.player,
    required this.playerIndex,
    required this.isActive,
    required this.diceValue,
    required this.canRoll,
    required this.onRoll,
    required this.isDark,
    this.teamMode = false,
    this.partner,
    this.timeScale = 1.0,
  });

  static String ordinal(int n) {
    if (n == 1) return '1st';
    if (n == 2) return '2nd';
    if (n == 3) return '3rd';
    return '${n}th';
  }

  @override
  Widget build(BuildContext context) {
    final color = player.color;
    final finished = player.finishRank != null;
    final fg = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? Colors.white60 : const Color(0xFF64748B);
    final teamAccent =
        teamMode ? Player.teamAccent(player.teamId) : color.primary;

    // Team 2v2: 8 home tokens across the two teammates.
    final ownHome = player.tokensHomeCount;
    final partnerHome = partner?.tokensHomeCount ?? 0;
    final totalHome = ownHome + partnerHome;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
              ? [
                  Color.alphaBlend(
                    color.primary.withOpacity(isDark ? 0.38 : 0.22),
                    isDark ? const Color(0xFF16203A) : Colors.white,
                  ),
                  Color.alphaBlend(
                    color.primary.withOpacity(isDark ? 0.18 : 0.10),
                    isDark ? const Color(0xFF111A2E) : const Color(0xFFFDFDFB),
                  ),
                ]
              : [
                  isDark ? const Color(0xFF141D2E) : Colors.white,
                  isDark ? const Color(0xFF141D2E) : Colors.white,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? (canRoll ? color.primary.withOpacity(0.95) : teamAccent)
              : (isDark
                  ? const Color(0xFF283650)
                  : const Color(0xFFD6CEBD)),
          // A thicker colored ring links the two teammates (§E).
          width: isActive ? (canRoll ? 2.4 : 1.8) : 1.0,
        ),
        boxShadow: [
          if (isActive)
            BoxShadow(
              color: color.primary.withOpacity(isDark ? 0.35 : 0.25),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Opacity(
        opacity: finished ? 0.75 : 1.0,
        child: Row(
          children: [
            PinAvatar(color: color, size: 30, isDark: isDark),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _FitName(
                          text: player.name,
                          color: fg,
                          isDark: isDark,
                        ),
                      ),
                      if (teamMode) ...[
                        const SizedBox(width: 4),
                        _TeamBadge(teamId: player.teamId, isDark: isDark),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  if (finished)
                    Text(
                      'Finished • ${ordinal(player.finishRank!)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? const Color(0xFFF2C14E)
                            : const Color(0xFF9A7600),
                      ),
                    )
                  else if (isActive)
                    const Text(
                      'Your turn',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: Color(0xFF2A9D8F),
                      ),
                    )
                  else
                    Text(
                      teamMode
                          ? '${Player.teamName(player.teamId)} $totalHome/8'
                          : '$ownHome/4 home',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: muted,
                      ),
                    ),
                  const SizedBox(height: 3),
                  // Pills: one per token, filled only at the center.
                  ProgressPills(
                    homeFlags: [
                      ...player.tokens.map((t) => t.isHome),
                      ...?partner?.tokens.map((t) => t.isHome),
                    ],
                    fill: teamMode ? teamAccent : color.primary,
                    idle: isDark
                        ? const Color(0xFF39465E)
                        : const Color(0xFFC8CFD9),
                    accent: isActive ? color.primary.withOpacity(0.35) : null,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            DiceWidget(
              value: diceValue,
              isRolling: false,
              canRoll: canRoll && !finished,
              activeColor: color,
              size: 56,
              timeScale: timeScale,
              onRoll: onRoll,
            ),
          ],
        ),
      ),
    );
  }
}

/// Team badge (§E): "A"/"B" in the team accent so teammates read as linked.
class _TeamBadge extends StatelessWidget {
  final int teamId;
  final bool isDark;

  const _TeamBadge({required this.teamId, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final accent = Player.teamAccent(teamId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: accent.withOpacity(isDark ? 0.25 : 0.20),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withOpacity(0.9), width: 1),
      ),
      child: Text(
        teamId == 0 ? 'A' : 'B',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          height: 1.1,
          color: isDark ? accent : const Color(0xFF1B1F2A),
        ),
      ),
    );
  }
}

/// Home-progress pills (§A4): one per token; a pill fills only when that
/// token has reached the center. Rows of 4, so 8 pills in Team mode.
class ProgressPills extends StatelessWidget {
  final List<bool> homeFlags;
  final Color fill;
  final Color idle;
  final Color? accent;

  /// How many pills are currently filled — always equals the number of
  /// tokens that have reached the center, so text and pills can never
  /// disagree (§A4).
  int get filledCount => homeFlags.where((h) => h).length;

  const ProgressPills({
    super.key,
    required this.homeFlags,
    required this.fill,
    required this.idle,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var r = 0; r < homeFlags.length / 4; r++) {
      final row = <Widget>[];
      for (var c = 0; c < 4; c++) {
        final i = r * 4 + c;
        if (i >= homeFlags.length) break;
        row.add(Expanded(
          child: Container(
            margin: EdgeInsets.only(right: c == 3 ? 0 : 3, bottom: 2),
            height: 6,
            decoration: BoxDecoration(
              color: homeFlags[i] ? fill : idle,
              borderRadius: BorderRadius.circular(3),
              border: homeFlags[i]
                  ? null
                  : Border.all(
                      color: accent ?? Colors.transparent,
                      width: 1),
            ),
          ),
        ));
      }
      rows.add(Row(children: row));
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }
}

/// Name that scales down to fit and ellipsizes only when very long (§A3).
class _FitName extends StatelessWidget {
  final String text;
  final Color color;
  final bool isDark;

  const _FitName({
    required this.text,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double base = 14;
        const double min = 10.5;
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              fontSize: base,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : double.infinity;
        if (tp.width <= available) {
          return Text(
            text,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: color,
              fontSize: base,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          );
        }
        // Scale down, but never past `min` — below that, ellipsize.
        final scale = tp.width <= 0 ? 1.0 : available / tp.width;
        final fontSize = scale >= min / base ? base * scale : min;
        return Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        );
      },
    );
  }
}
