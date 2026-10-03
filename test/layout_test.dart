import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludu/main.dart';
import 'package:ludu/models/ludo_color.dart';
import 'package:ludu/ui/widgets/dice_widget.dart';
import 'package:ludu/ui/widgets/player_panel.dart';

/// Verifies the UI fixes and additions that are checkable without pixels:
/// panel anchoring, neutral dice, pill truthfulness and team panels.
void main() {
  setUp(() {
    // Nothing global to reset; each test builds its own tree.
  });

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const LuduApp());
    await tester.pumpAndSettle();
  }

  Future<void> startFourPlayerGame(WidgetTester tester) async {
    await tester.ensureVisible(find.text('START GAME'));
    await tester.tap(find.text('START GAME'));
    await tester.pumpAndSettle();
  }

  Finder panelFor(LudoColor color) => find.byWidgetPredicate(
        (w) => w is PlayerPanel && w.player.color == color,
      );

  testWidgets('§A1 every panel sits next to the base of its own colour',
      (tester) async {
    await pumpHome(tester);
    await startFourPlayerGame(tester);

    // All four panels exist.
    for (final c in LudoColor.values) {
      expect(panelFor(c), findsOneWidget, reason: 'missing panel for $c');
    }

    final red = tester.getTopLeft(panelFor(LudoColor.red));
    final green = tester.getTopLeft(panelFor(LudoColor.green));
    final yellow = tester.getTopLeft(panelFor(LudoColor.yellow));
    final blue = tester.getTopLeft(panelFor(LudoColor.blue));

    // Top row: Red left, Green right.
    expect(red.dx, lessThan(green.dx), reason: 'Red must be top-left');
    expect(red.dy, lessThan(blue.dy), reason: 'top row must be above');
    // Bottom row: Blue left (Player 4), Yellow right (Player 3).
    expect(blue.dx, lessThan(yellow.dx),
        reason: 'Blue (P4) must be bottom-left');
    expect(yellow.dy, greaterThan(red.dy),
        reason: 'Yellow (P3) must be bottom-right');
  });

  testWidgets('§A5 four embedded dice on screen, all neutral before first roll',
      (tester) async {
    await pumpHome(tester);
    await startFourPlayerGame(tester);

    final dice = tester
        .widgetList<DiceWidget>(find.byType(DiceWidget))
        .toList();
    // One dice embedded per player panel (4 players).
    expect(dice.length, equals(4), reason: 'must show 4 embedded dice (one per player dock)');
    // Before any player rolls, no dice should show a rolled value.
    expect(dice.every((d) => d.value == null), isTrue,
        reason: 'all dice must be neutral before first roll');
  });

  testWidgets('§A3 default names are never truncated', (tester) async {
    await pumpHome(tester);
    await startFourPlayerGame(tester);

    for (final c in LudoColor.values) {
      expect(find.text('Player ${c.index + 1}'), findsOneWidget,
          reason: 'full default name must render for $c');
    }
  });

  testWidgets('§A4 pills fill exactly for tokens that reached the center',
      (tester) async {
    await pumpHome(tester);
    await startFourPlayerGame(tester);

    final pills = tester
        .widgetList<ProgressPills>(find.byType(ProgressPills))
        .toList();
    expect(pills.length, equals(4));
    for (final p in pills) {
      // Nobody has moved yet, so nothing may be filled.
      expect(p.filledCount, equals(0));
      expect(p.homeFlags.length, equals(4));
    }
  });

  testWidgets('§B no "tap to roll" hint line remains under the board',
      (tester) async {
    await pumpHome(tester);
    await startFourPlayerGame(tester);
    expect(find.textContaining('TAP'), findsNothing);
    expect(find.textContaining('MOVING'), findsNothing);
  });

  testWidgets('§E team mode is selectable and starts a 4-player team game',
      (tester) async {
    await pumpHome(tester);

    expect(find.text('Team 2 vs 2'), findsOneWidget);
    expect(find.text('Classic'), findsOneWidget);

    await tester.ensureVisible(find.text('Team 2 vs 2'));
    await tester.tap(find.text('Team 2 vs 2'));
    await tester.pumpAndSettle();

    // Team preview explains the pairing.
    expect(find.textContaining('Team A'), findsWidgets);
    expect(find.textContaining('sit opposite'), findsWidgets);

    await tester.ensureVisible(find.text('START GAME'));
    await tester.tap(find.text('START GAME'));
    await tester.pumpAndSettle();

    // Every panel shows a team badge, and each has 8 pills (own + partner).
    final panels = tester
        .widgetList<PlayerPanel>(find.byType(PlayerPanel))
        .toList();
    expect(panels.length, equals(4));
    for (final p in panels) {
      expect(p.teamMode, isTrue);
      expect(p.partner, isNotNull);
    }
    final pills = tester
        .widgetList<ProgressPills>(find.byType(ProgressPills))
        .toList();
    expect(pills.length, equals(4));
    for (final p in pills) {
      expect(p.homeFlags.length, equals(8));
    }
    // Team A owns Red + Yellow.
    final teamOf = <LudoColor, int>{};
    for (final panel in panels) {
      teamOf[panel.player.color] = panel.player.teamId;
    }
    expect(teamOf[LudoColor.red], equals(teamOf[LudoColor.yellow]));
    expect(teamOf[LudoColor.green], equals(teamOf[LudoColor.blue]));
    expect(teamOf[LudoColor.red], isNot(teamOf[LudoColor.green]));
  });

  testWidgets('§F rules screen opens from the home screen', (tester) async {
    await pumpHome(tester);
    expect(find.text('Classic'), findsOneWidget);
    await tester.ensureVisible(find.text('Rules'));
    await tester.tap(find.text('Rules'));
    await tester.pumpAndSettle();

    expect(find.text('BASICS'), findsOneWidget);
    expect(find.text('True randomness'), findsOneWidget);

    // The Team section lives further down the scrollable rules.
    await tester.scrollUntilVisible(find.text('Helping your teammate'), 240,
        scrollable: find.byType(Scrollable).last);
    await tester.pumpAndSettle();
    expect(find.text('TEAM 2 VS 2'), findsOneWidget);
    expect(find.text('Helping your teammate'), findsOneWidget);
  });
}
