import 'dart:math';

/// Service responsible for dice generation.
///
/// NON-NEGOTIABLE REQUIREMENT: Pure Luck.
/// Strictly uses [Random.secure()] (cryptographically secure pseudo-random number generator)
/// with zero weights, zero dynamic difficulty adjustment (DDA), and zero pity mechanics.
class DiceService {
  final Random _secureRandom;

  DiceService([Random? random]) : _secureRandom = random ?? Random.secure();

  /// Returns a genuinely random integer from 1 to 6 inclusive.
  int roll() {
    return _secureRandom.nextInt(6) + 1;
  }
}
