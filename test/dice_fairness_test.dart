import 'package:flutter_test/flutter_test.dart';
import 'package:ludu/services/dice_service.dart';

void main() {
  group('DiceService Pure Luck & Cryptographic Uniformity Test', () {
    test('120,000 rolls produce a statistically uniform 1-6 distribution', () {
      final diceService = DiceService();
      const int totalRolls = 120000;
      const double expectedPerBucket = totalRolls / 6.0; // 20,000

      final Map<int, int> counts = {
        1: 0,
        2: 0,
        3: 0,
        4: 0,
        5: 0,
        6: 0,
      };

      for (int i = 0; i < totalRolls; i++) {
        final roll = diceService.roll();
        expect(roll, inInclusiveRange(1, 6), reason: 'Roll must be between 1 and 6');
        counts[roll] = counts[roll]! + 1;
      }

      // Calculate Pearson's Chi-Square statistic: sum((Observed - Expected)^2 / Expected)
      double chiSquare = 0.0;
      for (int face = 1; face <= 6; face++) {
        final observed = counts[face]!;
        final diff = observed - expectedPerBucket;
        chiSquare += (diff * diff) / expectedPerBucket;

        // Verify each bucket is within reasonable tolerance (< 2.5% deviation)
        final percentageDeviation = ((observed - expectedPerBucket).abs() / expectedPerBucket) * 100;
        expect(
          percentageDeviation,
          lessThan(2.5),
          reason: 'Face $face frequency ($observed) deviates too much from expected ($expectedPerBucket)',
        );
      }

      // With 5 degrees of freedom (6 buckets - 1):
      // Critical value for chi-square at p = 0.001 is 20.515
      // If chiSquare < 20.515, the null hypothesis of uniform distribution holds.
      expect(
        chiSquare,
        lessThan(20.515),
        reason: 'Chi-Square statistic $chiSquare exceeds critical value for uniform distribution',
      );
    });
  });
}
