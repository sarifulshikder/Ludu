import 'package:flutter/material.dart';
import '../../models/game_state.dart';
import '../../models/ludo_color.dart';
import '../../services/haptics_service.dart';
import '../widgets/confetti_overlay.dart';

class VictoryScreen extends StatefulWidget {
  final GameState gameState;
  final VoidCallback onPlayAgain;
  final VoidCallback onNewGame;

  const VictoryScreen({
    super.key,
    required this.gameState,
    required this.onPlayAgain,
    required this.onNewGame,
  });

  @override
  State<VictoryScreen> createState() => _VictoryScreenState();
}

class _VictoryScreenState extends State<VictoryScreen> {
  @override
  void initState() {
    super.initState();
    HapticsService.victory();
  }

  @override
  Widget build(BuildContext context) {
    final finishOrder = widget.gameState.finishOrder;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ConfettiOverlay(
      isPlaying: true,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Title
                const Text(
                  'GAME OVER',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4.0,
                    color: Color(0xFFE9C46A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Final Standings',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 24),

                // Podium / Ranking List
                Expanded(
                  child: ListView.separated(
                    itemCount: finishOrder.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final player = finishOrder[index];
                      final rank = player.finishRank ?? (index + 1);
                      final color = player.color;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              color.darkShade.withOpacity(isDark ? 0.7 : 0.2),
                              color.primary.withOpacity(isDark ? 0.4 : 0.15),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: rank == 1 ? const Color(0xFFE9C46A) : color.primary.withOpacity(0.5),
                            width: rank == 1 ? 2.5 : 1.2,
                          ),
                          boxShadow: [
                            if (rank == 1)
                              BoxShadow(
                                color: const Color(0xFFE9C46A).withOpacity(0.3),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                        child: Row(
                          children: [
                            // Rank Medal
                            _buildRankBadge(rank),
                            const SizedBox(width: 16),

                            // Player Name & Color
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    player.name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    color.displayName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: color.lightGlow,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Tokens Home
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

                // Match Statistics Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141D2E) : const Color(0xFFEDE8DD),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? const Color(0xFF283650) : const Color(0xFFD6CEBD),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('Total Turns', '${widget.gameState.totalTurns}'),
                      _buildStatItem('Sixes Rolled', '${widget.gameState.totalSixes}'),
                      _buildStatItem('Captures', '${widget.gameState.totalCaptures}'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          HapticsService.light();
                          widget.onNewGame();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: const BorderSide(color: Color(0xFFE9C46A), width: 1.5),
                        ),
                        child: const Text(
                          'New Setup',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE9C46A),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          HapticsService.medium();
                          widget.onPlayAgain();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE9C46A),
                          foregroundColor: const Color(0xFF1B1F2A),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 4,
                        ),
                        child: const Text(
                          'Play Again',
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

  Widget _buildRankBadge(int rank) {
    Color medalColor;
    String label;
    if (rank == 1) {
      medalColor = const Color(0xFFFFD700); // Gold
      label = '1st';
    } else if (rank == 2) {
      medalColor = const Color(0xFFC0C0C0); // Silver
      label = '2nd';
    } else if (rank == 3) {
      medalColor = const Color(0xFFCD7F32); // Bronze
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

  Widget _buildStatItem(String label, String value) {
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
