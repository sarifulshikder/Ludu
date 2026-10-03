import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludu/models/game_settings.dart';
import 'package:ludu/services/dice_service.dart';
import 'package:ludu/services/persistence.dart';
import 'package:ludu/state/game_controller.dart';
import 'package:ludu/state/settings_controller.dart';
import 'package:ludu/ui/board/ludo_board.dart';
import 'package:ludu/ui/board/token_widget.dart';
import 'package:ludu/ui/screens/game_screen.dart';
import 'package:ludu/ui/widgets/dice_widget.dart';

class ScriptedDice implements DiceService {
  final List<int> script;
  int _index = 0;

  ScriptedDice(this.script);

  @override
  bool get luckySixes => false;

  @override
  int roll({int streak = 0, bool? luckySixesOverride}) {
    final val = script[_index % script.length];
    _index++;
    return val;
  }
}

GameController? _ctrl;

/// Same harness shape as move_flow_test: real LudoBoard wired to a
/// scripted-dice controller.
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
            height: 532,
            child: LudoBoard(
              gameState: st,
              onTokenSelected: (id) => _ctrl!.moveToken(id),
            ),
          ),
        ),
      ),
    );
  }
}

Finder get _movablePawns => find.byWidgetPredicate(
      (w) => w is TokenWidget && w.isMovable,
    );

/// Tokens rendered inside the "Choose a token" fan-out (56 dp each).
Finder get _pickerPawns => find.byWidgetPredicate(
      (w) => w is TokenWidget && w.isMovable && w.size == 56.0,
    );

Future<void> _pumpThrough(WidgetTester tester, int steps) async {
  for (int i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Green is player index 1 in a 4-player game. Parks tokens 0 and 2 on the
/// same square (step 5) with everything else in base.
void _parkGreenStack() {
  final players = List.of(_ctrl!.state.players);
  final g = players[1];
  players[1] = g.copyWith(
    tokens: List.generate(4, (i) {
      final step = (i == 0 || i == 2) ? 5 : -1;
      return g.tokens[i].copyWith(step: step);
    }),
  );
  _ctrl!.state = _ctrl!.state.copyWith(players: players);
}

Future<void> _startGreenStackGame(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        gameControllerProvider.overrideWith(
          (ref) => GameController(
            diceService: ScriptedDice([2]),
            persistence: MemoryPersistence(),
          ),
        ),
      ],
      child: const _Harness(),
    ),
  );
  _ctrl!.startNewGame(playerCount: 4, firstPlayerIndex: 1);
  await tester.pumpAndSettle();
  _parkGreenStack();
  await tester.pump();
  _ctrl!.rollDice();
  await tester.pump();
  expect(_ctrl!.state.currentDiceRoll, equals(2));
  expect(_ctrl!.state.movableTokenIds, equals([0, 2]));
}

void main() {
  group('Stack fan-out picker (regression)', () {
    testWidgets('opens the picker and selects the first token', (tester) async {
      await _startGreenStackGame(tester);
      expect(_movablePawns, findsNWidgets(2));

      await tester.tap(_movablePawns.first);
      await tester.pump();
      expect(find.text('Choose a token'), findsOneWidget);
      expect(_pickerPawns, findsNWidgets(2));

      await tester.tap(_pickerPawns.first);
      await _pumpThrough(tester, 10);

      expect(find.text('Choose a token'), findsNothing);
      final steps =
          _ctrl!.state.players[1].tokens.map((t) => t.step).toList();
      expect(steps[0], equals(7));
      expect(steps[2], equals(5));
    });

    testWidgets('opens the picker and selects the second token',
        (tester) async {
      await _startGreenStackGame(tester);

      await tester.tap(_movablePawns.first);
      await tester.pump();
      expect(find.text('Choose a token'), findsOneWidget);

      await tester.tap(_pickerPawns.last);
      await _pumpThrough(tester, 10);

      expect(find.text('Choose a token'), findsNothing);
      final steps =
          _ctrl!.state.players[1].tokens.map((t) => t.step).toList();
      expect(steps[2], equals(7));
      expect(steps[0], equals(5));
    });

    testWidgets('tapping outside closes the picker without moving',
        (tester) async {
      await _startGreenStackGame(tester);

      await tester.tap(_movablePawns.first);
      await tester.pump();
      expect(find.text('Choose a token'), findsOneWidget);

      // Tap a board corner far from the popup card.
      await tester.tapAt(const Offset(390, 520));
      await tester.pump();
      expect(find.text('Choose a token'), findsNothing);
      final steps =
          _ctrl!.state.players[1].tokens.map((t) => t.step).toList();
      expect(steps, equals([5, -1, 5, -1]));

      // The stack can be tapped again to reopen the picker.
      await tester.tap(_movablePawns.first);
      await tester.pump();
      expect(find.text('Choose a token'), findsOneWidget);
    });

    testWidgets('selects from a stack in Team 2 vs 2 mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameControllerProvider.overrideWith(
              (ref) => GameController(
                diceService: ScriptedDice([2]),
                persistence: MemoryPersistence(),
              ),
            ),
          ],
          child: const _Harness(),
        ),
      );
      // Red (index 0, Team A) to move in a team game.
      _ctrl!.startNewGame(playerCount: 4, firstPlayerIndex: 0, teamMode: true);
      await tester.pumpAndSettle();
      // Park Red tokens 1 and 3 on one square; teammate Yellow stays home.
      final players = List.of(_ctrl!.state.players);
      final red = players[0];
      players[0] = red.copyWith(
        tokens: List.generate(4, (i) {
          final step = (i == 1 || i == 3) ? 5 : -1;
          return red.tokens[i].copyWith(step: step);
        }),
      );
      _ctrl!.state = _ctrl!.state.copyWith(players: players);
      await tester.pump();
      _ctrl!.rollDice();
      await tester.pump();
      expect(_ctrl!.state.movableTokenIds, equals([1, 3]));

      await tester.tap(_movablePawns.first);
      await tester.pump();
      expect(find.text('Choose a token'), findsOneWidget);
      expect(_pickerPawns, findsNWidgets(2));

      await tester.tap(_pickerPawns.last);
      await _pumpThrough(tester, 10);

      expect(find.text('Choose a token'), findsNothing);
      final steps =
          _ctrl!.state.players[0].tokens.map((t) => t.step).toList();
      expect(steps[3], equals(7));
      expect(steps[1], equals(5));
    });

    testWidgets('stack picker works with Face-to-face mode ON',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final settingsCtrl = SettingsController(MemoryPersistence());
      GameController? gameCtrl;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            gameControllerProvider.overrideWith((ref) {
              gameCtrl = GameController(
                diceService: ScriptedDice([2]),
                persistence: MemoryPersistence(),
              );
              return gameCtrl!;
            }),
            settingsControllerProvider.overrideWith((ref) => settingsCtrl),
          ],
          child: MaterialApp(
            home: GameScreen(
              onNewGame: () {},
              onToggleTheme: () {},
              isDark: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Face-to-face ON: top chips and dice rotate 180°. The board and
      // its stack picker are never rotated, so picks must still work.
      settingsCtrl.update(const GameSettings(faceToFaceMode: true));
      await tester.pumpAndSettle();

      gameCtrl!.startNewGame(playerCount: 4, firstPlayerIndex: 1);
      await tester.pumpAndSettle();
      _ctrl = gameCtrl;
      _parkGreenStack();
      await tester.pumpAndSettle();

      // Roll through the real dice widget, then pick from the stack.
      final dice = find.byWidgetPredicate(
        (w) => w is DiceWidget && w.canRoll,
      );
      expect(dice, findsOneWidget);
      await tester.tap(dice);
      await _pumpThrough(tester, 8);
      expect(gameCtrl!.state.movableTokenIds, equals([0, 2]));

      await tester.tap(_movablePawns.first);
      await tester.pump();
      expect(find.text('Choose a token'), findsOneWidget);

      await tester.tap(_pickerPawns.first);
      await _pumpThrough(tester, 12);

      expect(find.text('Choose a token'), findsNothing);
      final steps =
          gameCtrl!.state.players[1].tokens.map((t) => t.step).toList();
      expect(steps[0], equals(7));
      expect(steps[2], equals(5));
    });
  });
}
