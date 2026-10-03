import 'dart:math';

/// Weighted probability of rolling a 6 in Lucky Sixes mode.
/// Single config constant — change here to tune globally.
// ignore: constant_identifier_names
const double SIX_PROBABILITY = 0.22;

/// Dart-style alias for [SIX_PROBABILITY].
const double sixProbability = SIX_PROBABILITY;

/// Service responsible for dice generation.
///
/// **Lucky Sixes mode** ([luckySixes] == true, default ON):
///   - P(6) ≈ 22 %, faces 1–5 share the remaining 78 % equally (~15.6 % each).
///   - When [streak] ≥ 2 (two consecutive sixes already rolled this turn),
///     the result is forced to be in [1, 5] — a 6 is impossible.
///   - Effective P(6) across all rolls ≈ 21 % because forced-1..5 pulls it
///     slightly below 22 %.
///
/// **Uniform mode** ([luckySixes] == false):
///   - Plain 1/6 for each face, no weighting.
///   - The engine's old "void the third 6" safety rule applies (enforced by
///     GameController, not here).
///
/// Backed by [Random.secure()] by default; inject a seeded [Random] for
/// deterministic tests.
class DiceService {
  final Random _rng;

  /// When true, Lucky Sixes weighting is applied (default).
  final bool luckySixes;

  DiceService({Random? random, this.luckySixes = true})
      : _rng = random ?? Random.secure();

  /// Rolls the dice.
  ///
  /// [streak] — current consecutive-six streak for the active player.
  ///   When [luckySixes] is true and [streak] ≥ 2, the result is guaranteed
  ///   to be in [1, 5] (uniform).
  ///
  /// [luckySixesOverride] — if non-null, overrides the instance [luckySixes]
  ///   field. Used by [GameController] so the live settings value always wins.
  int roll({int streak = 0, bool? luckySixesOverride}) {
    final bool lucky = luckySixesOverride ?? luckySixes;
    if (lucky) {
      // After two consecutive sixes: force a 1–5 draw.
      if (streak >= 2) {
        return _rng.nextInt(5) + 1; // 1..5 uniform
      }
      // Weighted draw: SIX_PROBABILITY chance of 6.
      final double r = _rng.nextDouble();
      if (r < SIX_PROBABILITY) return 6;
      // Map remaining range [SIX_PROBABILITY, 1.0) uniformly onto 1..5.
      return ((r - SIX_PROBABILITY) / (1.0 - SIX_PROBABILITY) * 5).floor() + 1;
    } else {
      return _rng.nextInt(6) + 1;
    }
  }
}
