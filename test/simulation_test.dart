import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ludu/core/board_coordinates.dart';
import 'package:ludu/models/game_settings.dart';
import 'package:ludu/models/game_state.dart';
import 'package:ludu/services/dice_service.dart';
import 'package:ludu/services/persistence.dart';
import 'package:ludu/state/game_controller.dart';

/// Full-game simulation (§0): plays thousands of random games across 2/3/4
/// players (and both rule settings) and checks that every game terminates
/// with no illegal state.
void main() {
  group('Full-game simulation', () {
    test('2000 random games terminate with legal states', () async {
      final rng = Random(12345);
      const games = 2000;
      const actionCap = 20000;
      int totalActions = 0;

      for (int g = 0; g < games; g++) {
        // Every 7th game is a 4-player Team 2v2 match.
        final teamGame = g % 7 == 0;
        final count = teamGame ? 4 : 2 + rng.nextInt(3);
        final settings = GameSettings(
          // Exercise both rule variants across the run.
          blockRule: g.isEven,
          endAtFirstWinner: g % 5 == 0,
        );
        final controller = GameController(
          diceService: DiceService(random: Random(rng.nextInt(1 << 32))),
          persistence: MemoryPersistence(),
          settings: settings,
        );
        controller.startNewGame(
          playerCount: count,
          firstPlayerIndex: rng.nextInt(count),
          teamMode: teamGame,
        );

        int actions = 0;
        while (controller.state.phase != GamePhase.finished) {
          actions++;
          if (actions > actionCap) {
            fail('Game $g ($count players) did not terminate '
                'after $actionCap actions');
          }
          final s = controller.state;
          _assertLegalMidGame(s, 'game $g action $actions');
          if (s.canRollDice) {
            final roll = controller.rollDice();
            assert(roll >= 1 && roll <= 6);
          } else if (s.mustSelectToken) {
            final ids = s.movableTokenIds;
            controller.moveToken(ids[rng.nextInt(ids.length)]);
          } else {
            fail('Game $g stuck: dice ${s.currentDiceRoll}, '
                'movables ${s.movableTokenIds}, player '
                '${s.currentPlayerIndex}');
          }
        }
        totalActions += actions;
        _assertLegalFinal(controller.state, settings, 'game $g');
      }

      // Sanity: games actually ran a realistic number of actions.
      expect(totalActions, greaterThan(games * 50));
    }, timeout: const Timeout(Duration(minutes: 5)));
  });
}

/// Invariants that must hold after every single action.
void _assertLegalMidGame(GameState s, String where) {
  // Token steps always inside the model.
  for (final p in s.players) {
    for (final t in p.tokens) {
      assert(t.step >= -1 && t.step <= 56, '$where: $t out of range');
      if (t.isOnOuterTrack) {
        final g = t.globalTrackIndex!;
        assert(g >= 0 && g < 52, '$where: bad global index $g');
        // Track position matches the color's path.
        final at = BoardCoordinates.outerTrack[g];
        final want = BoardCoordinates.getTokenPosition(
            color: t.color, tokenId: t.id, step: t.step);
        assert(at.row == want.row && at.col == want.col,
            '$where: $t off its path');
      }
    }
    // A finished player holds all 4 home.
    if (p.finishRank != null) {
      assert(p.hasFinished, '$where: ranked ${p.name} not all home');
    }
  }
  // The turn always belongs to an unfinished player.
  assert(s.currentPlayer.finishRank == null,
      '$where: turn belongs to finished ${s.currentPlayer.name}');
  // Ranks are unique and sequential.
  final ranks =
      s.players.where((p) => p.finishRank != null).map((p) => p.finishRank!);
  assert(ranks.toSet().length == ranks.length, '$where: duplicate ranks');
  for (final r in ranks) {
    assert(r >= 1 && r <= s.players.length, '$where: rank $r out of range');
  }
  assert(s.finishOrder.length == ranks.length,
      '$where: finishOrder/ranks mismatch');
  // Sixes counter never escapes its 0..2 window mid-turn.
  assert(s.consecutiveSixes >= 0 && s.consecutiveSixes <= 2,
      '$where: sixes ${s.consecutiveSixes}');
  assert(s.totalCaptures >= 0 && s.totalTurns >= 0 && s.totalSixes >= 0,
      '$where: negative counters');
}

/// End-of-game invariants.
void _assertLegalFinal(GameState s, GameSettings settings, String where) {
  expect(s.phase, equals(GamePhase.finished), reason: where);
  if (s.teamMode) {
    // One team owns all 8 home tokens; both mates share rank 1.
    expect(s.finishOrder.length, equals(2), reason: where);
    final teams = s.finishOrder.map((p) => p.teamId).toSet();
    expect(teams.length, equals(1), reason: where);
    for (final p in s.finishOrder) {
      expect(p.hasFinished, isTrue, reason: '$where ${p.name}');
    }
    return;
  }
  if (settings.endAtFirstWinner) {
    expect(s.finishOrder.length, equals(1), reason: where);
    expect(s.finishOrder.first.hasFinished, isTrue, reason: where);
  } else {
    // Full ranking: every player ranked exactly once. Everyone except
    // the last player standing finished all 4 home; the game ends as
    // soon as one player is left, whatever their progress (§7).
    expect(s.finishOrder.length, equals(s.players.length), reason: where);
    final ranks = s.finishOrder.map((p) => p.finishRank!).toList()
      ..sort();
    expect(
        ranks,
        equals(List.generate(s.players.length, (i) => i + 1)),
        reason: where);
    for (final p in s.finishOrder.sublist(0, s.finishOrder.length - 1)) {
      expect(p.hasFinished, isTrue, reason: '$where ${p.name}');
    }
  }
}
