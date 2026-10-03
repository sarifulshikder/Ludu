import 'package:flutter/material.dart';

/// Rules screen (§F): Classic and Team 2v2 rules, reachable from the home
/// screen and from Settings.
class RulesScreen extends StatelessWidget {
  final bool isDark;

  const RulesScreen({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ludu Rules'),
        backgroundColor: isDark ? const Color(0xFF0B1220) : null,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: _sections(isDark),
        ),
      ),
    );
  }

  static List<Widget> _sections(bool isDark) {
    _Rule r(String t, String b) => _Rule(t, b, isDark);
    return [
      _SectionHeader(
        title: 'Basics',
        color: const Color(0xFF2A9D8F),
        children: [
          r(
            'True randomness',
            'One die, values 1–6, from a cryptographically secure source. '
                'With Lucky sixes ON (default): 6 comes up about 22 % of the '
                'time; 1–5 share the rest equally; three 6s in a row can never '
                'happen. With Lucky sixes OFF: plain 1/6 per face. '
                'No hidden help, no catch-up, same rule for every player.',
          ),
          r(
            'Seats & turn order',
            'Red top-left, Green top-right, Yellow bottom-right, Blue '
                'bottom-left. Turns run clockwise: Red → Green → Yellow → Blue. '
                'The first player is chosen randomly.',
          ),
          r(
            'Journey',
            'A token needs exactly 56 steps: a 6 to leave the base onto your '
                'own start square, 50 squares around the outer track, 5 up your '
                'home column, then 1 into the center.',
          ),
          r(
            'Exact roll to finish',
            'The center needs the exact number. Inside your home column smaller '
                'rolls still move you closer. A move that would overshoot is illegal.',
          ),
          r(
            'Captures & safe squares',
            'Landing exactly on an opponent sends that token back to its base; '
                'passing over one does nothing. Start squares and the four stars are '
                'safe and may be shared by any colors. Tokens in a base or in a home '
                'column can never be captured.',
          ),
          r(
            'Extra turns',
            'You roll again after a 6 you actually moved with, after a capture, '
                'and after bringing a token into the center. Bonuses chain. Three '
                'consecutive 6s voids the third roll — no move — and passes the turn; '
                'moves made with the first two stay.',
          ),
          r(
            'No legal move',
            'If nothing can move, the turn passes automatically. If something can '
                'move, you must move it — there is no passing and no undo.',
          ),
        ],
      ),
      _SectionHeader(
        title: 'Winning',
        color: const Color(0xFFF2C14E),
        children: [
          r(
            'Ranks',
            'A player takes a rank the moment all 4 of their tokens reach the center. '
                'Finished players are skipped in the turn order and play continues for '
                '2nd and 3rd place. Turn on "End game at first winner" to stop at the '
                'first winner instead.',
          ),
        ],
      ),
      _SectionHeader(
        title: 'Team 2 vs 2',
        color: const Color(0xFF277DA1),
        children: [
          r(
            'The teams',
            'Exactly four players. Team A = Red + Yellow, Team B = Green + Blue, so '
                'teammates sit opposite each other. Turn order stays clockwise, which '
                'means the teams alternate.',
          ),
          r(
            'Teammates',
            'Teammates never capture each other. A token may land on a square holding '
                'a teammate — they share it safely.',
          ),
          r(
            'Teammate stacks',
            'In Team mode, teammates sharing a non-safe square form a protected stack: '
                'opponents cannot land on it. This is always on in Team mode, '
                'independent of the Block rule setting.',
          ),
          r(
            'Helping your teammate',
            "Once you have brought all 4 of your own tokens home, you keep rolling on "
                "your turns and your rolls move your teammate's tokens.",
          ),
          r(
            'Winning a team game',
            'A team wins when all 8 tokens — 4 from each teammate — have reached the center.',
          ),
          r(
            'Everything else',
            'Extra turns, captures, safe squares, the three-6s rule and the no-legal-move '
                'pass all behave exactly as in Classic mode.',
          ),
        ],
      ),
      _SectionHeader(
        title: 'Settings',
        color: const Color(0xFFE9C46A),
        children: [
          r(
            'Lucky sixes',
            'Sixes come up a little more often (about 22 % vs 17 %), and three '
                'in a row can never happen. The same weighted draw applies to '
                'every player equally — no hidden help. On by default.',
          ),
          r(
            'Block rule (Classic)',
            'When on, a stack of 2+ same-color tokens on a non-safe square is protected '
                'and opponents cannot land on it. Off by default.',
          ),
          r(
            'Auto-move',
            'When only one move is legal, it is played automatically. On by default.',
          ),
          r(
            'Animation speed, sound & vibration',
            'Play at normal or fast pace, set a sound volume, and keep light haptics on '
                'moves with a stronger buzz on captures.',
          ),
        ],
      ),
    ];
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  final List<Widget> children;

  const _SectionHeader({
    required this.title,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.6,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  final String title;
  final String body;
  final bool isDark;

  const _Rule(this.title, this.body, this.isDark);

  @override
  Widget build(BuildContext context) {
    final bodyColor = isDark
        ? Colors.white.withOpacity(0.78)
        : const Color(0xFF475569);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.circle, size: 7, color: Color(0xFFE9C46A)),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 14, top: 2),
            child: Text(
              body,
              style: TextStyle(fontSize: 13, height: 1.35, color: bodyColor),
            ),
          ),
        ],
      ),
    );
  }
}
