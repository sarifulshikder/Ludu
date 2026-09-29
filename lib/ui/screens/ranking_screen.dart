import 'package:flutter/material.dart';

import '../../models/game_state.dart';
import '../../models/ludo_color.dart';
import '../../services/haptics_service.dart';
import '../board/token_widget.dart';
import '../widgets/confetti_overlay.dart';

/// Final ranking screen (§7): full standings with medals, match stats,
/// and Rematch / New Game buttons.
class RankingScreen extends StatefulWidget {
  final GameState gameState;
  final VoidCallback onRematch;
  final VoidCallback onNewGame;

  const RankingScreen({
    super.key,
    required this.gameState,
    required this.onRematch,
    required this.onNewGame,
  });

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  @override
  void initState() {
    super.initState();
    HapticsService.victory();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Ranked players first (1st, 2nd, ...), then the rest by progress.
    final ordered = List.of(widget.gameState.players)
      ..sort((a, b) {
        final ra = a.finishRank ?? 99;
        final rb = b.finishRank ?? 99;
        if (ra != rb) return ra.compareTo(rb);
        return b.tokensHomeCount.compareTo(a.tokensHomeCount);
      });
    final winner = widget.gameState.finishOrder.isNotEmpty
        ? widget.gameState.finishOrder.first
        : ordered.first;

    return ConfettiOverlay(
      isPlaying: true,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              children: [
                const SizedBox(height: 12),
                const Text(
                  '🏆 RESULTS 🏆',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4.0,
                    color: Color(0xFFF2C14E),
                  ),
                ),
                const SizedBox(height: 8),
                PinAvatar(
                    color: winner.color, size: 92, isDark: isDark),
                const SizedBox(height: 10),
                Text(
                  '${winner.name} wins!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '${winner.color.displayName} ${winner.color.emblemGlyph} • 4/4 home',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: winner.color.primary,
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: ListView.separated(
                    itemCount: ordered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final player = ordered[index];
                      final rank = player.finishRank ?? (index + 1);
                      final color = player.color;
                      final isWinner = rank == 1;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color.darkShade
                                  .withOpacity(isDark ? 0.7 : 0.2),
                              color.primary
                                  .withOpacity(isDark ? 0.4 : 0.15),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isWinner
                                ? const Color(0xFFF2C14E)
                                : color.primary.withOpacity(0.5),
                            width: isWinner ? 2.5 : 1.2,
                          ),
                          boxShadow: [
                            if (isWinner)
                              BoxShadow(
                                color: const Color(0xFFF2C14E)
                                    .withOpacity(0.3),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                        child: Row(
                          children: [
                            _RankBadge(rank: rank),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${color.emblemGlyph} ${player.name}',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    color.displayName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? color.lightGlow
                                          : color.darkShade,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black26,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${player.tokensHomeCount} / 4 Home',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF141D2E)
                        : const Color(0xFFEDE8DD),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF283650)
                          : const Color(0xFFD6CEBD),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(
                          'Total Turns', '${widget.gameState.totalTurns}'),
                      _StatItem(
                          'Sixes Rolled', '${widget.gameState.totalSixes}'),
                      _StatItem(
                          'Captures', '${widget.gameState.totalCaptures}'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          HapticsService.light();
                          widget.onNewGame();
                        },
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          side: const BorderSide(
                              color: Color(0xFFF2C14E), width: 1.5),
                        ),
                        child: const Text(
                          'New Game',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFF2C14E),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          HapticsService.medium();
                          widget.onRematch();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF2C14E),
                          foregroundColor: const Color(0xFF1B1F2A),
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                        ),
                        child: const Text(
                          'Rematch',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;

  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) {
    Color medalColor;
    String label;
    if (rank == 1) {
      medalColor = const Color(0xFFFFD700);
      label = '1st';
    } else if (rank == 2) {
      medalColor = const Color(0xFFC0C0C0);
      label = '2nd';
    } else if (rank == 3) {
      medalColor = const Color(0xFFCD7F32);
      label = '3rd';
    } else {
      medalColor = const Color(0xFF78909C);
      label = '4th';
    }

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: medalColor.withOpacity(0.2),
        border: Border.all(color: medalColor, width: 2.2),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: medalColor,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFFE9C46A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }
}
