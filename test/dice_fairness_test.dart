import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludu/services/dice_service.dart';

// ── helpers ──────────────────────────────────────────────────────────────────

/// Chi-square statistic for a frequency map against a uniform expected value.
double _chiSquare(Map<int, int> counts, double expectedPerBucket) {
  double x2 = 0;
  for (final c in counts.values) {
    final d = c - expectedPerBucket;
    x2 += d * d / expectedPerBucket;
  }
  return x2;
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  // ── 1. Distribution test (Lucky Sixes ON) ──────────────────────────────────
  group('Lucky Sixes ON — distribution (1 M rolls)', () {
    test('P(6) ≈ 21 % ± 1 pp; faces 1–5 uniform among non-6 rolls', () {
      final rng = Random(42);
      final dice = DiceService(random: rng, luckySixes: true);
      const int N = 1000000;
      final counts = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};
      int streak = 0;

      for (int i = 0; i < N; i++) {
        final r = dice.roll(streak: streak);
        counts[r] = counts[r]! + 1;
        streak = (r == 6) ? streak + 1 : 0;
        // The dice service prevents streak ≥ 3, but keep simulation safe.
        if (streak >= 3) streak = 0;
      }

      final sixCount = counts[6]!;
      final sixPct = sixCount / N * 100;

      // Effective P(6) ≈ 21 % (slightly below 22 % because the streak-2 guard
      // forces 1–5 on occasional rolls). Allow ± 1 pp.
      expect(
        sixPct,
        inInclusiveRange(20.0, 22.5),
        reason: 'P(6) was ${sixPct.toStringAsFixed(2)} %, expected ~21 %',
      );

      // Faces 1–5 must be statistically uniform among non-6 rolls.
      final nonSixTotal = N - sixCount;
      final expectedNonSix = nonSixTotal / 5.0;
      final nonSix = {
        1: counts[1]!,
        2: counts[2]!,
        3: counts[3]!,
        4: counts[4]!,
        5: counts[5]!,
      };
      final x2 = _chiSquare(nonSix, expectedNonSix);
      // df = 4 (five buckets), critical value at p = 0.001 = 18.467
      expect(
        x2,
        lessThan(18.467),
        reason: 'Chi-square $x2 too large; faces 1–5 not uniform among non-6',
      );
    });
  });

  // ── 2. Streak test (Lucky Sixes ON) ───────────────────────────────────────
  group('Lucky Sixes ON — streak test (10 M rolls)', () {
    test('Three consecutive 6s NEVER occur; post-two-six roll is 1–5 uniform',
        () {
      final rng = Random(12345);
      final dice = DiceService(random: rng, luckySixes: true);
      const int N = 10000000;
      int streak = 0;
      int threeInARowCount = 0;
      final postTwo = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

      for (int i = 0; i < N; i++) {
        final wasAtTwo = (streak == 2);

        // Hard assertion BEFORE the roll: if streak == 2, we must get 1–5.
        final r = dice.roll(streak: streak);

        if (wasAtTwo) {
          expect(
            r,
            inInclusiveRange(1, 5),
            reason: 'Dice returned $r when streak was 2 (roll $i)',
          );
          postTwo[r] = postTwo[r]! + 1;
        }

        // Count how many times the dice would have produced a third 6.
        if (r == 6 && streak >= 2) threeInARowCount++;

        streak = (r == 6) ? streak + 1 : 0;
        if (streak >= 3) streak = 0; // safety — engine would void this
      }

      expect(
        threeInARowCount,
        0,
        reason: 'Three-in-a-row occurred $threeInARowCount times',
      );

      // Post-two-six rolls must be uniform over 1–5.
      final postTotal = postTwo.values.fold(0, (a, b) => a + b);
      if (postTotal >= 100) {
        // enough samples to chi-square test
        final expectedPost = postTotal / 5.0;
        final x2 = _chiSquare(postTwo, expectedPost);
        expect(
          x2,
          lessThan(18.467), // df=4 p=0.001
          reason:
              'Post-two-six rolls not uniform: $postTwo — chi2=$x2',
        );
      }
    });
  });

  // ── 3. Uniform mode (Lucky Sixes OFF) ─────────────────────────────────────
  group('Uniform mode (Lucky Sixes OFF)', () {
    test('1 M rolls: each face within 0.5 pp of 1/6', () {
      final rng = Random(99);
      final dice = DiceService(random: rng, luckySixes: false);
      const int N = 1000000;
      final counts = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};

      for (int i = 0; i < N; i++) {
        final r = dice.roll();
        counts[r] = counts[r]! + 1;
      }

      const double expected = N / 6.0;
      for (int face = 1; face <= 6; face++) {
        final deviation = (counts[face]! - expected).abs() / N * 100;
        expect(
          deviation,
          lessThan(0.5),
          reason:
              'Face $face: ${counts[face]} deviates ${deviation.toStringAsFixed(2)} pp',
        );
      }
      // Also chi-square. df=5 p=0.001 critical = 20.515
      final x2 = _chiSquare(counts, expected);
      expect(x2, lessThan(20.515),
          reason: 'Chi-square $x2 too large for uniform distribution');
    });
  });

  // ── 4. luckySixesOverride parameter ───────────────────────────────────────
  group('luckySixesOverride parameter', () {
    test('override=false makes a luckySixes=true instance roll uniformly', () {
      final rng = Random(7);
      final dice = DiceService(random: rng, luckySixes: true);
      const int N = 600000;
      final counts = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0};
      for (int i = 0; i < N; i++) {
        final r = dice.roll(luckySixesOverride: false);
        counts[r] = counts[r]! + 1;
      }
      const double expected = N / 6.0;
      final x2 = _chiSquare(counts, expected);
      expect(x2, lessThan(20.515),
          reason: 'override=false should produce uniform dist; chi2=$x2');
    });

    test('override=true makes a luckySixes=false instance use Lucky Sixes', () {
      final rng = Random(8);
      final dice = DiceService(random: rng, luckySixes: false);
      const int N = 600000;
      int sixCount = 0;
      int streak = 0;
      for (int i = 0; i < N; i++) {
        final r = dice.roll(streak: streak, luckySixesOverride: true);
        if (r == 6) sixCount++;
        streak = (r == 6) ? streak + 1 : 0;
        if (streak >= 3) streak = 0;
      }
      final sixPct = sixCount / N * 100;
      expect(
        sixPct,
        inInclusiveRange(20.0, 23.0),
        reason:
            'override=true should give ~21 % sixes; got ${sixPct.toStringAsFixed(2)} %',
      );
    });
  });
}
