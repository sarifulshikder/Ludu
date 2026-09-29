import 'package:flutter/material.dart';

import '../../models/ludo_color.dart';
import '../../models/player.dart';
import '../board/token_widget.dart';
import 'dice_widget.dart';

/// Player panel (§8): avatar, name, home progress and the player's own big
/// dice. Only the active player's dice is highlighted and tappable; their
/// panel glows and shows a clear "Your turn" label.
class PlayerPanel extends StatelessWidget {
  final Player player;
  final int playerIndex;
  final bool isActive;
  final int? diceValue;
  final bool canRoll;
  final VoidCallback onRoll;
  final bool isDark;

  const PlayerPanel({
    super.key,
    required this.player,
    required this.playerIndex,
    required this.isActive,
    required this.diceValue,
    required this.canRoll,
    required this.onRoll,
    required this.isDark,
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
    final idleFace = (playerIndex + 1).clamp(1, 6);
    final fg = isDark ? Colors.white : const Color(0xFF0F172A);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                    isDark
                        ? const Color(0xFF111A2E)
                        : const Color(0xFFFDFDFB),
                  ),
                ]
              : [
                  isDark ? const Color(0xFF141D2E) : Colors.white,
                  isDark ? const Color(0xFF141D2E) : Colors.white,
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? color.primary.withOpacity(canRoll ? 0.95 : 0.6)
              : (isDark
                  ? const Color(0xFF283650)
                  : const Color(0xFFD6CEBD)),
          width: isActive ? 2.0 : 1.0,
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
            PinAvatar(color: color, size: 34, isDark: isDark),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${color.emblemGlyph} ${player.name}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (finished)
                    Text(
                      'Finished • ${ordinal(player.finishRank!)}',
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
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: Color(0xFF2A9D8F),
                      ),
                    )
                  else
                    Text(
                      '${player.tokensHomeCount}/4 home',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? Colors.white60
                            : const Color(0xFF64748B),
                      ),
                    ),
                  const SizedBox(height: 4),
                  _ProgressDots(player: player, isDark: isDark),
                ],
              ),
            ),
            const SizedBox(width: 8),
            DiceWidget(
              value: isActive ? (diceValue ?? idleFace) : idleFace,
              isRolling: false,
              canRoll: canRoll && !finished,
              activeColor: color,
              size: 62,
              onRoll: onRoll,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  final Player player;
  final bool isDark;

  const _ProgressDots({required this.player, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: player.tokens.map((t) {
        Color fill;
        if (t.isHome) {
          fill = const Color(0xFFF2C14E);
        } else if (t.isInBase) {
          fill = isDark
              ? const Color(0xFF39465E)
              : const Color(0xFFC8CFD9);
        } else {
          fill = player.color.primary;
        }
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 4),
            height: 7,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }).toList(),
    );
  }
}
