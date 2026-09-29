import 'package:flutter_test/flutter_test.dart';
import 'package:ludu/core/board_coordinates.dart';
import 'package:ludu/models/game_state.dart';
import 'package:ludu/models/token.dart';
import 'package:ludu/services/dice_service.dart';
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

void main() {
  group('Ludo Game Rules Unit Tests', () {
    test('Rolling a 6 allows bringing a token out of base to step 0', () {
      final controller = GameController(diceService: ScriptedDiceService([6]));
      controller.startNewGame(playerCount: 2);

      expect(controller.state.currentPlayer.tokens.every((t) => t.isInBase), isTrue);

      controller.rollDice();
      expect(controller.state.currentDiceRoll, equals(6));
      expect(controller.state.movableTokenIds, equals([0, 1, 2, 3]));

      controller.moveToken(0);
      expect(controller.state.players[0].tokens[0].step, equals(0));
      // Rolling a 6 grants an extra turn, so player 0 is still current player
      expect(controller.state.currentPlayerIndex, equals(0));
    });

    test('Rolling non-6 cannot bring a token out of base and auto-passes turn', () {
      final controller = GameController(diceService: ScriptedDiceService([4]));
      controller.startNewGame(playerCount: 2);

      // Player 0 rolls 4 with all tokens in base
      controller.rollDice();

      // No tokens can move, so turn auto-advances to Player 1
      expect(controller.state.currentPlayerIndex, equals(1));
    });

    test('Exact roll required to reach Home (no overshoot)', () {
      final controller = GameController(diceService: ScriptedDiceService([4, 2]));
      controller.startNewGame(playerCount: 2);

      // Place token at step 54 (needs exactly 2 to reach step 56)
      final player0 = controller.state.players[0];
      final updatedTokens = List<Token>.from(player0.tokens);
      updatedTokens[0] = updatedTokens[0].copyWith(step: 54);
      controller.state = controller.state.copyWith(
        players: [player0.copyWith(tokens: updatedTokens), controller.state.players[1]],
      );

      // Roll 4 -> overshoot (54 + 4 = 58 > 56)
      controller.rollDice();
      // Token 0 cannot move with a 4
      expect(controller.state.movableTokenIds.contains(0), isFalse);

      // Roll 2 -> exact (54 + 2 = 56)
      // Switch back to player 0 for test
      controller.state = controller.state.copyWith(currentPlayerIndex: 0, clearDiceRoll: true);
      controller.rollDice();
      expect(controller.state.movableTokenIds.contains(0), isTrue);

      controller.moveToken(0);
      expect(controller.state.players[0].tokens[0].isHome, isTrue);
      expect(controller.state.players[0].tokens[0].step, equals(56));
    });

    test('Capture on normal square sends opponent token back to base', () {
      final controller = GameController(diceService: ScriptedDiceService([3]));
      controller.startNewGame(playerCount: 2);

      // Setup:
      // Player 0 has token at step 1 (outer track global square 1, which is not safe)
      // Player 1 has token at step 0 (outer track global square 26 for Yellow)
      // Let's place Player 1 token at global square 4 (step 4 for Player 0)
      // Player 0 start is square 0. Step 1 + 3 = 4. Square 4 is NOT a safe square.
      // Player 1 (Yellow) start is square 26. Global square 4 corresponds to Yellow step 30 ((26 + 30) % 52 = 4).
      final p0 = controller.state.players[0];
      final p1 = controller.state.players[1];

      final p0Tokens = List<Token>.from(p0.tokens);
      p0Tokens[0] = p0Tokens[0].copyWith(step: 1); // will move to step 4 (global square 4)

      final p1Tokens = List<Token>.from(p1.tokens);
      p1Tokens[0] = p1Tokens[0].copyWith(step: 30); // is at global square (26 + 30) % 52 = 4

      controller.state = controller.state.copyWith(
        players: [p0.copyWith(tokens: p0Tokens), p1.copyWith(tokens: p1Tokens)],
        currentPlayerIndex: 0,
      );

      expect(BoardCoordinates.isSafeSquare(4), isFalse);

      controller.rollDice(); // rolls 3
      controller.moveToken(0);

      // Player 0 token moved to step 4
      expect(controller.state.players[0].tokens[0].step, equals(4));
      // Player 1 opponent token was captured and sent to base (-1)
      expect(controller.state.players[1].tokens[0].step, equals(-1));
      expect(controller.state.totalCaptures, equals(1));
    });

    test('Opponent token on safe star square CANNOT be captured', () {
      final controller = GameController(diceService: ScriptedDiceService([2]));
      controller.startNewGame(playerCount: 2);

      // Safe square 8 (Red zone safe star)
      // Player 0 is at step 6 (global square 6). Rolls 2 -> lands on step 8 (global square 8).
      // Player 1 has token at global square 8.
      // Yellow start is 26. (26 + 34) % 52 = 8.
      final p0 = controller.state.players[0];
      final p1 = controller.state.players[1];

      final p0Tokens = List<Token>.from(p0.tokens);
      p0Tokens[0] = p0Tokens[0].copyWith(step: 6);

      final p1Tokens = List<Token>.from(p1.tokens);
      p1Tokens[0] = p1Tokens[0].copyWith(step: 34); // global 8

      controller.state = controller.state.copyWith(
        players: [p0.copyWith(tokens: p0Tokens), p1.copyWith(tokens: p1Tokens)],
        currentPlayerIndex: 0,
      );

      expect(BoardCoordinates.isSafeSquare(8), isTrue);

      controller.rollDice(); // rolls 2
      controller.moveToken(0);

      // Player 0 lands on square 8
      expect(controller.state.players[0].tokens[0].step, equals(8));
      // Player 1 is NOT captured because square 8 is safe!
      expect(controller.state.players[1].tokens[0].step, equals(34));
      expect(controller.state.totalCaptures, equals(0));
    });

    test('Three consecutive 6s cancels third move and passes turn to next player', () {
      final controller = GameController(diceService: ScriptedDiceService([6, 6, 6]));
      controller.startNewGame(playerCount: 2);

      expect(controller.state.currentPlayerIndex, equals(0));

      // 1st six
      controller.rollDice();
      expect(controller.state.consecutiveSixes, equals(1));
      controller.moveToken(0); // exits to step 0
      expect(controller.state.currentPlayerIndex, equals(0)); // extra turn

      // 2nd six
      controller.rollDice();
      expect(controller.state.consecutiveSixes, equals(2));
      controller.moveToken(0); // moves to step 6
      expect(controller.state.currentPlayerIndex, equals(0)); // extra turn

      // 3rd six
      controller.rollDice();
      // On 3rd six, rule cancels move and advances turn to Player 1 immediately
      expect(controller.state.consecutiveSixes, equals(0));
      expect(controller.state.currentPlayerIndex, equals(1));
    });

    test('Explicit undo of third 6 reverts token position and restores captures', () {
      final controller = GameController();
      controller.startNewGame(playerCount: 2);

      final p0 = controller.state.players[0];
      final p1 = controller.state.players[1];

      // Simulate a state where Player 0 token moved from step 0 to step 6 on 3rd six,
      // capturing Player 1 token at global square 6
      final tokenSnapshot = p0.tokens[0].copyWith(step: 0);
      final capturedSnapshot = p1.tokens[0].copyWith(step: 32); // global 6

      controller.state = controller.state.copyWith(
        players: [
          p0.copyWith(tokens: [p0.tokens[0].copyWith(step: 6), p0.tokens[1], p0.tokens[2], p0.tokens[3]]),
          p1.copyWith(tokens: [p1.tokens[0].copyWith(step: -1), p1.tokens[1], p1.tokens[2], p1.tokens[3]]),
        ],
        currentPlayerIndex: 0,
        lastMovedTokenSnapshot: tokenSnapshot,
        lastMovedPlayerIndex: 0,
        lastCapturedTokensSnapshot: [capturedSnapshot],
        consecutiveSixes: 3,
      );

      controller.undoThirdSixMove();

      // P0 token reverted to step 0
      expect(controller.state.players[0].tokens[0].step, equals(0));
      // P1 token restored to step 32
      expect(controller.state.players[1].tokens[0].step, equals(32));
      // Turn passed to player 1
      expect(controller.state.currentPlayerIndex, equals(1));
    });

    test('First player to bring all 4 home wins immediately (§6)', () {
      final controller = GameController(
          diceService: ScriptedDiceService([2]));
      controller.startNewGame(playerCount: 3);

      // Player 0 has 3 home + 1 at step 54 (needs exact 2).
      final p0 = controller.state.players[0];
      final p0Tokens = List<Token>.from(p0.tokens);
      for (int i = 0; i < 3; i++) {
        p0Tokens[i] = p0Tokens[i].copyWith(step: 56);
      }
      p0Tokens[3] = p0Tokens[3].copyWith(step: 54);
      controller.state = controller.state.copyWith(
        players: [
          p0.copyWith(tokens: p0Tokens),
          controller.state.players[1],
          controller.state.players[2]
        ],
        currentPlayerIndex: 0,
      );

      controller.rollDice(); // rolls 2
      expect(controller.state.movableTokenIds.contains(3), isTrue);
      controller.moveToken(3);

      expect(controller.state.players[0].tokens.every((t) => t.isHome),
          isTrue);
      expect(controller.state.phase, equals(GamePhase.finished));
      expect(controller.state.finishOrder.length, equals(1));
      expect(controller.state.finishOrder.first.name,
          equals(controller.state.players[0].name));
    });

    test('Capture grants an extra turn even without a 6 (§4)', () {
      final controller = GameController(diceService: ScriptedDiceService([3]));
      controller.startNewGame(playerCount: 2);

      final p0 = controller.state.players[0];
      final p1 = controller.state.players[1];
      final p0Tokens = List<Token>.from(p0.tokens);
      p0Tokens[0] = p0Tokens[0].copyWith(step: 1);
      final p1Tokens = List<Token>.from(p1.tokens);
      p1Tokens[0] = p1Tokens[0].copyWith(step: 30); // global 4

      controller.state = controller.state.copyWith(
        players: [p0.copyWith(tokens: p0Tokens), p1.copyWith(tokens: p1Tokens)],
        currentPlayerIndex: 0,
      );

      controller.rollDice(); // 3
      controller.moveToken(0);

      expect(controller.state.players[1].tokens[0].step, equals(-1));
      // Extra turn: still player 0.
      expect(controller.state.currentPlayerIndex, equals(0));
      expect(controller.state.currentDiceRoll, isNull);
    });

    test('Reaching home grants an extra turn even without a 6 (§4)', () {
      final controller = GameController(diceService: ScriptedDiceService([2]));
      controller.startNewGame(playerCount: 2);

      final p0 = controller.state.players[0];
      final p0Tokens = List<Token>.from(p0.tokens);
      p0Tokens[0] = p0Tokens[0].copyWith(step: 54);
      p0Tokens[1] = p0Tokens[1].copyWith(step: 10);
      controller.state = controller.state.copyWith(
        players: [p0.copyWith(tokens: p0Tokens), controller.state.players[1]],
        currentPlayerIndex: 0,
      );

      controller.rollDice(); // 2
      controller.moveToken(0);

      expect(controller.state.players[0].tokens[0].step, equals(56));
      expect(controller.state.phase, equals(GamePhase.playing));
      expect(controller.state.currentPlayerIndex, equals(0));
    });

    test('Team 2v2 assigns left/right columns as partner teams', () {
      final controller = GameController();
      controller.startNewGame(playerCount: 4, teamMode: true);

      expect(controller.state.teamMode, isTrue);
      final teams =
          controller.state.players.map((p) => p.teamId).toList();
      expect(teams, equals([0, 1, 0, 1]));
    });

    test('Teammates cannot capture each other (stack safely)', () {
      final controller = GameController(diceService: ScriptedDiceService([3]));
      controller.startNewGame(playerCount: 4, teamMode: true);

      // Player 0 (red, team A) token at step 1 -> moves to step 4 (global 4).
      // Player 2 (yellow, team A) token parked on global 4 ((26+30)%52).
      final p0 = controller.state.players[0];
      final p2 = controller.state.players[2];
      final p0Tokens = List<Token>.from(p0.tokens);
      p0Tokens[0] = p0Tokens[0].copyWith(step: 1);
      final p2Tokens = List<Token>.from(p2.tokens);
      p2Tokens[0] = p2Tokens[0].copyWith(step: 30);

      controller.state = controller.state.copyWith(
        players: [
          p0.copyWith(tokens: p0Tokens),
          controller.state.players[1],
          p2.copyWith(tokens: p2Tokens),
          controller.state.players[3],
        ],
        currentPlayerIndex: 0,
      );

      controller.rollDice(); // 3
      controller.moveToken(0);

      expect(controller.state.players[0].tokens[0].step, equals(4));
      // Partner untouched.
      expect(controller.state.players[2].tokens[0].step, equals(30));
      expect(controller.state.totalCaptures, equals(0));
    });

    test('Team wins when all 8 partner tokens are home', () {
      final controller = GameController(diceService: ScriptedDiceService([2]));
      controller.startNewGame(playerCount: 4, teamMode: true);

      // Team A: player 0 fully home, player 2 has 3 home + 1 at step 54.
      final p0 = controller.state.players[0];
      final p2 = controller.state.players[2];
      final p0Tokens =
          List.generate(4, (i) => Token(id: i, color: p0.color, step: 56));
      final p2Tokens =
          List.generate(4, (i) => Token(id: i, color: p2.color, step: 56));
      p2Tokens[3] = p2Tokens[3].copyWith(step: 54);

      controller.state = controller.state.copyWith(
        players: [
          p0.copyWith(tokens: p0Tokens),
          controller.state.players[1],
          p2.copyWith(tokens: p2Tokens),
          controller.state.players[3],
        ],
        currentPlayerIndex: 2,
      );

      controller.rollDice(); // 2, exact finish for token 3
      controller.moveToken(3);

      expect(controller.state.phase, equals(GamePhase.finished));
      expect(controller.state.finishOrder.length, equals(2));
      expect(
        controller.state.finishOrder.map((p) => p.teamId).toSet(),
        equals({0}),
      );
    });
  });
}
