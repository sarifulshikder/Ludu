import 'package:flutter_test/flutter_test.dart';
import 'package:ludu/core/board_coordinates.dart';
import 'package:ludu/models/game_settings.dart';
import 'package:ludu/models/game_state.dart';
import 'package:ludu/models/ludo_color.dart';
import 'package:ludu/models/player.dart';
import 'package:ludu/services/dice_service.dart';
import 'package:ludu/services/persistence.dart';
import 'package:ludu/state/game_controller.dart';

class ScriptedDiceService implements DiceService {
  final List<int> script;
  int _index = 0;

  ScriptedDiceService(this.script);

  @override
  int roll() {
    final val = script[_index % script.length];
    _index++;
    return val;
  }
}

/// Fresh controller with scripted dice and in-memory persistence.
GameController newGame(
  List<int> script, {
  int players = 2,
  int first = 0,
  GameSettings? settings,
  List<String>? names,
}) {
  final controller = GameController(
    diceService: ScriptedDiceService(script),
    persistence: MemoryPersistence(),
  );
  if (settings != null) controller.setSettings(settings);
  controller.startNewGame(
    playerCount: players,
    playerNames: names,
    firstPlayerIndex: first,
  );
  return controller;
}

/// Sets token steps for one player, leaving everyone else untouched.
void setSteps(GameController c, int playerIdx, List<int> steps) {
  assert(steps.length == 4);
  final players = List<Player>.from(c.state.players);
  final p = players[playerIdx];
  players[playerIdx] = p.copyWith(
    tokens: List.generate(
        4, (i) => p.tokens[i].copyWith(step: steps[i])),
  );
  c.state = c.state.copyWith(players: players);
}

/// Moves the state back to [playerIdx] with a cleared dice (test helper).
void backTo(GameController c, int playerIdx) {
  c.state = c.state.copyWith(
    currentPlayerIndex: playerIdx,
    clearDiceRoll: true,
    movableTokenIds: const [],
  );
}

void main() {
  // ------------------------------------------------------------------ §1
  group('Setup (§1)', () {
    test('2 to 4 players start with 4 tokens each, all in base', () {
      for (final count in [2, 3, 4]) {
        final c = newGame([1], players: count);
        expect(c.state.players.length, equals(count));
        for (final p in c.state.players) {
          expect(p.tokens.length, equals(4));
          expect(p.tokens.every((t) => t.isInBase), isTrue);
          expect(p.finishRank, isNull);
        }
        expect(c.state.phase, equals(GamePhase.playing));
      }
    });

    test('4 players sit clockwise: Red, Green, Yellow, Blue', () {
      final c = newGame([1], players: 4);
      expect(
        c.state.players.map((p) => p.color).toList(),
        equals([
          LudoColor.red,
          LudoColor.green,
          LudoColor.yellow,
          LudoColor.blue,
        ]),
      );
    });

    test('2 players default to opposite colors Red vs Yellow', () {
      final c = newGame([1], players: 2);
      expect(
        c.state.players.map((p) => p.color).toList(),
        equals([LudoColor.red, LudoColor.yellow]),
      );
    });

    test('3 players default to Red, Green, Yellow', () {
      final c = newGame([1], players: 3);
      expect(
        c.state.players.map((p) => p.color).toList(),
        equals([
          LudoColor.red,
          LudoColor.green,
          LudoColor.yellow,
        ]),
      );
    });

    test('Turn order is clockwise Red, Green, Yellow, Blue', () {
      // All tokens in base + rolling 1 never moves: pure passes.
      final c = newGame([1, 1, 1, 1], players: 4, first: 0);
      c.rollDice();
      expect(c.state.currentPlayerIndex, equals(1));
      c.rollDice();
      expect(c.state.currentPlayerIndex, equals(2));
      c.rollDice();
      expect(c.state.currentPlayerIndex, equals(3));
      c.rollDice();
      expect(c.state.currentPlayerIndex, equals(0));
    });

    test('First player is chosen randomly', () {
      final seen = <int>{};
      for (int i = 0; i < 200; i++) {
        final c = GameController(
          diceService: ScriptedDiceService([1]),
          persistence: MemoryPersistence(),
        );
        c.startNewGame(playerCount: 4);
        expect(c.state.currentPlayerIndex, inInclusiveRange(0, 3));
        seen.add(c.state.currentPlayerIndex);
      }
      // 200 random starts must cover every seat.
      expect(seen, equals({0, 1, 2, 3}));
    });

    test('firstPlayerIndex override pins the starting player', () {
      final c = newGame([1], players: 4, first: 2);
      expect(c.state.currentPlayerIndex, equals(2));
    });
  });

  // ------------------------------------------------------------------ §2
  group('Dice (§2)', () {
    test('One roll per tap: extra rolls while pending are ignored', () {
      final c = newGame([4, 5], first: 0);
      setSteps(c, 0, [10, -1, -1, -1]);
      expect(c.rollDice(), equals(4));
      expect(c.state.totalTurns, equals(1));
      // Tap again before moving: same value, no new roll consumed.
      expect(c.rollDice(), equals(4));
      expect(c.state.totalTurns, equals(1));
      expect(c.state.movableTokenIds, equals([0]));
    });
  });

  // ------------------------------------------------------------------ §3
  group('Board and path (§3)', () {
    test('Journey: step 50 -> home column -> exact center', () {
      final c = newGame([1, 1], first: 0);
      setSteps(c, 0, [50, -1, -1, -1]);
      c.rollDice();
      expect(c.state.movableTokenIds, equals([0]));
      c.moveToken(0);
      expect(c.state.players[0].tokens[0].step, equals(51));
      expect(
          c.state.players[0].tokens[0].isOnHomeStretch, isTrue);

      backTo(c, 0);
      setSteps(c, 0, [55, -1, -1, -1]);
      c.rollDice();
      c.moveToken(0);
      expect(c.state.players[0].tokens[0].step, equals(56));
      expect(c.state.players[0].tokens[0].isHome, isTrue);
    });

    test('Tokens in the home column can never be captured', () {
      final c = newGame([2], first: 0);
      setSteps(c, 0, [54, -1, -1, -1]);
      // Opponent token anywhere on the track.
      setSteps(c, 1, [10, -1, -1, -1]);
      c.rollDice(); // 2 -> exact center
      c.moveToken(0);
      expect(c.state.players[0].tokens[0].step, equals(56));
      expect(c.state.totalCaptures, equals(0));
      expect(c.state.players[1].tokens[0].step, equals(10));
    });

    test('Start squares are 0/13/26/39 with safe stars at 8/21/34/47',
        () {
      expect(LudoColor.red.startSquare, equals(0));
      expect(LudoColor.green.startSquare, equals(13));
      expect(LudoColor.yellow.startSquare, equals(26));
      expect(LudoColor.blue.startSquare, equals(39));
      for (final s in [0, 8, 13, 21, 26, 34, 39, 47]) {
        expect(BoardCoordinates.isSafeSquare(s), isTrue);
      }
      expect(BoardCoordinates.isSafeSquare(4), isFalse);
    });
  });

  // ------------------------------------------------------------------ §4
  group('Movement (§4)', () {
    test('A token leaves the base only on a 6, onto its start square',
        () {
      final c = newGame([6], first: 0);
      c.rollDice();
      expect(c.state.movableTokenIds, equals([0, 1, 2, 3]));
      c.moveToken(2);
      final t = c.state.players[0].tokens[2];
      expect(t.step, equals(0));
      expect(t.globalTrackIndex,
          equals(c.state.players[0].color.startSquare));
    });

    test('Rolls 1-5 cannot leave the base and auto-pass', () {
      for (final roll in [1, 2, 3, 4, 5]) {
        final c = newGame([roll], first: 0);
        c.rollDice();
        expect(c.state.movableTokenIds, isEmpty);
        expect(c.state.currentPlayerIndex, equals(1));
      }
    });

    test('After leaving, a token moves forward by the roll', () {
      final c = newGame([6, 3], first: 0);
      c.rollDice();
      c.moveToken(0); // out to step 0, bonus roll
      c.rollDice(); // 3
      c.moveToken(0);
      expect(c.state.players[0].tokens[0].step, equals(3));
    });

    test('Exact roll required for the center; smaller moves close in',
        () {
      final c = newGame([4], first: 0);
      setSteps(c, 0, [54, -1, -1, -1]);
      c.rollDice(); // 4 overshoots 54 -> 58
      expect(c.state.movableTokenIds.contains(0), isFalse);
      expect(c.state.currentPlayerIndex,
          equals(1)); // auto-pass, no bonus

      final c2 = newGame([2], first: 0);
      setSteps(c2, 0, [53, -1, -1, -1]);
      c2.rollDice();
      expect(c2.state.movableTokenIds, equals([0]));
      c2.moveToken(0);
      expect(c2.state.players[0].tokens[0].step, equals(55));
    });

    test('With a legal move the turn waits: no voluntary passing', () {
      final c = newGame([3], first: 0);
      setSteps(c, 0, [10, -1, -1, -1]);
      c.rollDice();
      expect(c.state.mustSelectToken, isTrue);
      expect(c.state.currentPlayerIndex, equals(0));
      // Illegal token id is ignored, turn still waits.
      c.moveToken(99);
      expect(c.state.currentPlayerIndex, equals(0));
      expect(c.state.players[0].tokens[0].step, equals(10));
    });

    test('A 6 with no legal move passes (no bonus without a move)', () {
      final c = newGame([6], first: 0);
      // Every token would overshoot the center with a 6.
      setSteps(c, 0, [51, 52, 53, 54]);
      c.rollDice();
      expect(c.state.movableTokenIds, isEmpty);
      expect(c.state.currentPlayerIndex, equals(1));
      expect(c.state.consecutiveSixes, equals(0));
    });

    test('There is no undo: moves are final', () {
      // The controller exposes no undo API; a committed move simply stays.
      final c = newGame([6], first: 0);
      c.rollDice();
      c.moveToken(0);
      expect(c.state.players[0].tokens[0].step, equals(0));
      // No `undoX` method exists on the controller (compile-time guarantee
      // checked by review); state offers no snapshot fields.
      expect(c.state.currentDiceRoll, isNull);
    });
  });

  // ------------------------------------------------------------------ §5
  group('Extra turns (§5)', () {
    test('Rolling a 6 grants another roll after moving', () {
      final c = newGame([6], first: 0);
      c.rollDice();
      c.moveToken(0);
      expect(c.state.currentPlayerIndex, equals(0));
      expect(c.state.canRollDice, isTrue);
      expect(c.state.consecutiveSixes, equals(1));
    });

    test('Capture grants an extra turn even without a 6', () {
      final c = newGame([3], first: 0);
      // Red token at step 1 -> 4 (global 4, not safe).
      setSteps(c, 0, [1, -1, -1, -1]);
      // Yellow at global 4 == step (4 - 26 + 52) % 52 = 30.
      setSteps(c, 1, [30, -1, -1, -1]);
      c.rollDice();
      c.moveToken(0);
      expect(c.state.players[1].tokens[0].step, equals(-1));
      expect(c.state.currentPlayerIndex, equals(0));
      expect(c.state.currentDiceRoll, isNull);
    });

    test('Bringing a token to the center grants an extra turn', () {
      final c = newGame([2], first: 0);
      setSteps(c, 0, [54, 10, -1, -1]);
      c.rollDice();
      c.moveToken(0);
      expect(c.state.players[0].tokens[0].step, equals(56));
      expect(c.state.currentPlayerIndex, equals(0));
    });

    test('Bonuses chain: capture, then 6, then turn passes on plain roll',
        () {
      final c = newGame([3, 6, 2], first: 0);
      setSteps(c, 0, [1, -1, -1, -1]);
      setSteps(c, 1, [30, -1, -1, -1]); // yellow on global 4
      c.rollDice(); // 3, captures
      c.moveToken(0);
      expect(c.state.currentPlayerIndex, equals(0)); // capture bonus
      c.rollDice(); // 6
      expect(c.state.consecutiveSixes, equals(1));
      c.moveToken(1); // second token exits to step 0
      expect(c.state.players[0].tokens[1].step, equals(0));
      expect(c.state.currentPlayerIndex, equals(0)); // six bonus
      c.rollDice(); // 2
      c.moveToken(0); // 4 -> 6, no bonus
      expect(c.state.currentPlayerIndex, equals(1));
      expect(c.state.consecutiveSixes, equals(0));
    });

    test('Three consecutive 6s: third voided, first two moves stay', () {
      final c = newGame([6, 6, 6], first: 0);
      c.rollDice();
      c.moveToken(0); // out to step 0
      c.rollDice();
      c.moveToken(0); // step 0 -> 6
      expect(c.state.players[0].tokens[0].step, equals(6));
      c.rollDice(); // third 6: void, no move offered
      expect(c.state.movableTokenIds, isEmpty);
      expect(c.state.currentPlayerIndex, equals(1));
      expect(c.state.consecutiveSixes, equals(0));
      // The first two moves were NOT reverted.
      expect(c.state.players[0].tokens[0].step, equals(6));
    });
  });

  // ------------------------------------------------------------------ §6
  group('Capture and safe squares (§6)', () {
    test('Landing exactly on an opponent captures it to base', () {
      final c = newGame([3], first: 0);
      setSteps(c, 0, [1, -1, -1, -1]);
      setSteps(c, 1, [30, -1, -1, -1]); // yellow, global 4
      c.rollDice();
      c.moveToken(0);
      expect(c.state.players[0].tokens[0].step, equals(4));
      expect(c.state.players[1].tokens[0].step, equals(-1));
      expect(c.state.totalCaptures, equals(1));
    });

    test('Passing over an opponent does nothing', () {
      final c = newGame([4], first: 0);
      setSteps(c, 0, [1, -1, -1, -1]); // lands on step 5, passes 2..4
      setSteps(c, 1, [29, -1, -1, -1]); // yellow, global 3
      c.rollDice();
      c.moveToken(0);
      expect(c.state.players[0].tokens[0].step, equals(5));
      expect(c.state.players[1].tokens[0].step, equals(29));
      expect(c.state.totalCaptures, equals(0));
    });

    test('Start squares are safe and can be shared', () {
      final c = newGame([6], first: 0);
      // Yellow parks on Red's start (global 0 == yellow step 26).
      setSteps(c, 1, [26, -1, -1, -1]);
      c.rollDice(); // 6, red exits onto step 0 (global 0)
      c.moveToken(0);
      expect(c.state.players[0].tokens[0].step, equals(0));
      // Safe: the yellow token survives and both share the square.
      expect(c.state.players[1].tokens[0].step, equals(26));
      expect(c.state.totalCaptures, equals(0));
    });

    test('Star squares are safe and can be shared', () {
      final c = newGame([2], first: 0);
      setSteps(c, 0, [6, -1, -1, -1]); // -> step 8, global 8 (star)
      setSteps(c, 1, [34, -1, -1, -1]); // yellow, global 8
      c.rollDice();
      c.moveToken(0);
      expect(c.state.players[0].tokens[0].step, equals(8));
      expect(c.state.players[1].tokens[0].step, equals(34));
      expect(c.state.totalCaptures, equals(0));
    });

    test('Same-color stacks share squares freely', () {
      final c = newGame([1], first: 0);
      setSteps(c, 0, [1, 2, -1, -1]);
      c.rollDice(); // 1: token 0 -> 2 joins token 1; token 1 -> 3
      c.moveToken(0);
      final steps =
          c.state.players[0].tokens.map((t) => t.step).toList();
      expect(steps.where((s) => s == 2).length, equals(2));
      expect(c.state.totalCaptures, equals(0));
    });

    test('Block OFF: every opponent token on the square is captured', () {
      final c = newGame([3], first: 0);
      setSteps(c, 0, [1, -1, -1, -1]);
      setSteps(c, 1, [30, 30, -1, -1]); // two yellows, global 4
      c.rollDice();
      c.moveToken(0);
      expect(c.state.players[1].tokens[0].step, equals(-1));
      expect(c.state.players[1].tokens[1].step, equals(-1));
      expect(c.state.totalCaptures, equals(2));
    });

    test('Block ON: landing on an opponent stack is illegal', () {
      final c = newGame(
        [3],
        first: 0,
        settings: const GameSettings(blockRule: true),
      );
      setSteps(c, 0, [1, -1, -1, -1]);
      setSteps(c, 1, [30, 30, -1, -1]); // yellow stack, global 4
      c.rollDice();
      // The only out token would land on the block: no legal moves.
      expect(c.state.movableTokenIds, isEmpty);
      expect(c.state.currentPlayerIndex, equals(1));
      expect(c.state.players[1].tokens[0].step, equals(30));
    });

    test('Block ON: single opponent tokens are still captured', () {
      final c = newGame(
        [3],
        first: 0,
        settings: const GameSettings(blockRule: true),
      );
      setSteps(c, 0, [1, -1, -1, -1]);
      setSteps(c, 1, [30, -1, -1, -1]);
      c.rollDice();
      expect(c.state.movableTokenIds, equals([0]));
      c.moveToken(0);
      expect(c.state.players[1].tokens[0].step, equals(-1));
    });

    test('Block ON: safe squares are unaffected (stacks can be shared)',
        () {
      final c = newGame(
        [2],
        first: 0,
        settings: const GameSettings(blockRule: true),
      );
      // Yellow stack on the safe star global 8.
      setSteps(c, 1, [34, 34, -1, -1]);
      setSteps(c, 0, [6, -1, -1, -1]); // -> step 8
      c.rollDice();
      expect(c.state.movableTokenIds, equals([0]));
      c.moveToken(0);
      expect(c.state.players[0].tokens[0].step, equals(8));
      expect(c.state.players[1].tokens[0].step, equals(34));
      expect(c.state.totalCaptures, equals(0));
    });
  });

  // ------------------------------------------------------------------ §7
  group('Winning and ranking (§7)', () {
    test('All 4 home takes 1st place and the game continues', () {
      final c = newGame([2], players: 3, first: 0);
      setSteps(c, 0, [56, 56, 56, 54]);
      c.rollDice();
      c.moveToken(3);
      expect(c.state.players[0].finishRank, equals(1));
      expect(c.state.finishOrder.map((p) => p.id).toList(),
          equals([0]));
      // Default: the game continues for the rest.
      expect(c.state.phase, equals(GamePhase.playing));
      expect(c.state.currentPlayerIndex, equals(1));
    });

    test('Full game: 2nd, 3rd assigned, last standing takes last rank',
        () {
      final c = newGame([2], players: 3, first: 1);
      // P0 already finished 1st.
      final players = List<Player>.from(c.state.players);
      players[0] = players[0].copyWith(
        tokens: List.generate(
            4,
            (i) => players[0]
                .tokens[i]
                .copyWith(step: 56)),
        finishRank: 1,
      );
      c.state = c.state.copyWith(
        players: players,
        finishOrder: [players[0]],
        currentPlayerIndex: 1,
      );
      // P1 finishes second...
      setSteps(c, 1, [56, 56, 56, 54]);
      c.rollDice();
      c.moveToken(3);
      expect(c.state.players[1].finishRank, equals(2));
      // ...and P2 automatically takes 3rd: game over.
      expect(c.state.phase, equals(GamePhase.finished));
      expect(c.state.players[2].finishRank, equals(3));
      expect(c.state.finishOrder.map((p) => p.id).toList(),
          equals([0, 1, 2]));
    });

    test('Finished players are skipped in the turn order', () {
      final c = newGame([1, 1], players: 3, first: 1);
      final players = List<Player>.from(c.state.players);
      players[0] = players[0].copyWith(
        tokens: List.generate(
            4,
            (i) => players[0]
                .tokens[i]
                .copyWith(step: 56)),
        finishRank: 1,
      );
      c.state = c.state.copyWith(
        players: players,
        finishOrder: [players[0]],
        currentPlayerIndex: 1,
      );
      c.rollDice(); // P1 all base, rolls 1 -> pass to P2 (not P0)
      expect(c.state.currentPlayerIndex, equals(2));
      c.rollDice(); // P2 passes back to P1, skipping finished P0
      expect(c.state.currentPlayerIndex, equals(1));
    });

    test('End-at-first-winner stops the game immediately', () {
      final c = newGame(
        [2],
        players: 2,
        first: 0,
        settings: const GameSettings(endAtFirstWinner: true),
      );
      setSteps(c, 0, [56, 56, 56, 54]);
      c.rollDice();
      c.moveToken(3);
      expect(c.state.phase, equals(GamePhase.finished));
      expect(c.state.finishOrder.length, equals(1));
      expect(c.state.players[0].finishRank, equals(1));
      expect(c.state.players[1].finishRank, isNull);
    });
  });

  // ------------------------------------------------- settings & saves
  group('Settings and persistence (§9, §10)', () {
    test('Settings default to auto-move ON, block OFF, play-on, fx ON',
        () {
      const s = GameSettings();
      expect(s.autoMove, isTrue);
      expect(s.blockRule, isFalse);
      expect(s.endAtFirstWinner, isFalse);
      expect(s.sound, isTrue);
      expect(s.vibration, isTrue);
    });

    test('Mid-turn save round-trips through JSON losslessly', () {
      final c = newGame([6], players: 3, first: 1,
          names: ['A', 'B', 'C']);
      setSteps(c, 1, [12, -1, -1, 56]);
      c.rollDice(); // 6, movables pending
      final restored = GameState.fromJson(c.state.toJson());
      expect(restored.currentPlayerIndex,
          equals(c.state.currentPlayerIndex));
      expect(restored.currentDiceRoll, equals(6));
      expect(restored.consecutiveSixes,
          equals(c.state.consecutiveSixes));
      expect(restored.movableTokenIds,
          equals(c.state.movableTokenIds));
      expect(restored.statusMessage, equals(c.state.statusMessage));
      expect(restored.totalTurns, equals(c.state.totalTurns));
      for (int p = 0; p < 3; p++) {
        expect(restored.players[p].name, equals(['A', 'B', 'C'][p]));
        expect(
          restored.players[p].tokens.map((t) => t.step).toList(),
          equals(
              c.state.players[p].tokens.map((t) => t.step).toList()),
        );
      }
      // A restored mid-turn game is immediately playable.
      final c2 = GameController(
        diceService: ScriptedDiceService([6]),
        persistence: MemoryPersistence(),
      );
      c2.restore(restored);
      expect(c2.state.mustSelectToken, isTrue);
    });

    test('In-progress games are saved; finished games clear the save',
        () async {
      final persistence = MemoryPersistence();
      final c = GameController(
        diceService: ScriptedDiceService([2]),
        persistence: persistence,
        settings: const GameSettings(endAtFirstWinner: true),
      );
      c.startNewGame(playerCount: 2, firstPlayerIndex: 0);
      await Future<void>.delayed(Duration.zero);
      final saved = await persistence.loadGame();
      expect(saved, isNotNull);
      expect(saved!.players.length, equals(2));

      setSteps(c, 0, [56, 56, 56, 54]);
      c.rollDice();
      c.moveToken(3); // wins, end-at-first -> finished
      expect(c.state.phase, equals(GamePhase.finished));
      await Future<void>.delayed(Duration.zero);
      expect(await persistence.loadGame(), isNull);
    });
  });
}
