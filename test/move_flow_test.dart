import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludu/services/dice_service.dart';
import 'package:ludu/state/game_controller.dart';
import 'package:ludu/ui/board/ludo_board.dart';
import 'package:ludu/ui/board/token_widget.dart';

class ScriptedDice implements DiceService {
  final List<int> script;
  int _index = 0;

  ScriptedDice(this.script);

  @override
  int roll() {
    final val = script[_index % script.length];
    _index++;
    return val;
  }
}

GameController? _ctrl;

/// Minimal harness: the real LudoBoard wired to a scripted-dice
/// controller, so taps travel the exact production path
/// (tap orb -> hop animation -> timed commit -> moveToken).
class _Harness extends ConsumerWidget {
  const _Harness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final st = ref.watch(gameControllerProvider);
    _ctrl = ref.read(gameControllerProvider.notifier);
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            height: 600,
            child: LudoBoard(
              gameState: st,
              onTokenSelected: (id) => _ctrl!.moveToken(id),
              onRollDice: () => _ctrl!.rollDice(),
            ),
          ),
        ),
      ),
    );
  }
}

Finder get _movableOrbs => find.byWidgetPredicate(
      (w) => w is TokenWidget && w.isMovable,
    );

/// Pumps past hop timers + settle delays without relying on
/// pumpAndSettle (movable orbs pulse while selectable).
Future<void> _pumpThrough(WidgetTester tester, int steps) async {
  for (int i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  group('Board tap-to-move flow', () {
    testWidgets('tapping dice then an orb moves that orb by the roll',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameControllerProvider.overrideWith(
              (ref) => GameController(
                diceService: ScriptedDice([6, 3]),
              ),
            ),
          ],
          child: const _Harness(),
        ),
      );
      _ctrl!.startNewGame(playerCount: 2);
      await tester.pumpAndSettle();

      // --- Roll 6, bring orb 1 out of base by tapping it. ---
      _ctrl!.rollDice();
      await tester.pump();
      expect(_ctrl!.state.currentDiceRoll, equals(6));
      expect(_movableOrbs, findsNWidgets(4));

      await tester.tap(_movableOrbs.first);
      await _pumpThrough(tester, 6);
      expect(_ctrl!.state.players[0].tokens[0].step, equals(0));
      // Rolled a 6: same player rolls again.
      expect(_ctrl!.state.currentPlayerIndex, equals(0));

      // --- Roll 3, tap the same orb: it must hop exactly 3 squares. ---
      _ctrl!.rollDice();
      await tester.pump();
      expect(_ctrl!.state.currentDiceRoll, equals(3));
      expect(_movableOrbs, findsOneWidget);

      await tester.tap(_movableOrbs);
      await _pumpThrough(tester, 8);
      expect(_ctrl!.state.players[0].tokens[0].step, equals(3));
      // Non-6 without capture/home: turn passes to player 2.
      expect(_ctrl!.state.currentPlayerIndex, equals(1));
    });

    testWidgets('tapping a different orb moves that orb instead',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameControllerProvider.overrideWith(
              (ref) => GameController(
                diceService: ScriptedDice([6]),
              ),
            ),
          ],
          child: const _Harness(),
        ),
      );
      _ctrl!.startNewGame(playerCount: 2);
      await tester.pumpAndSettle();

      _ctrl!.rollDice();
      await tester.pump();
      expect(_movableOrbs, findsNWidgets(4));

      // Tap the LAST movable orb (token id 3), not the first.
      await tester.tap(_movableOrbs.last);
      await _pumpThrough(tester, 6);

      expect(_ctrl!.state.players[0].tokens[3].step, equals(0));
      expect(_ctrl!.state.players[0].tokens[0].step, equals(-1));
      expect(_ctrl!.state.players[0].tokens[1].step, equals(-1));
      expect(_ctrl!.state.players[0].tokens[2].step, equals(-1));
    });
  });
}
