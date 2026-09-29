import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludu/main.dart';
import 'package:ludu/ui/widgets/dice_widget.dart';

void main() {
  testWidgets(
      'LuduApp launches to SetupScreen, starts a game, rolls dice',
      (WidgetTester tester) async {
    // Realistic portrait phone so the layout fits.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const LuduApp());
    await tester.pumpAndSettle();

    // Setup screen: title, player counts, start button.
    expect(find.text('LUDU'), findsWidgets);
    expect(find.text('4 Players'), findsOneWidget);

    await tester.ensureVisible(find.text('START GAME'));
    await tester.tap(find.text('START GAME'));
    await tester.pumpAndSettle();

    // Game screen: exactly one active player chip showing 'TURN' badge.
    expect(find.text('TURN'), findsOneWidget);

    // Tap the active player's dice: the roll must resolve without errors.
    final activeDice = find.byWidgetPredicate(
      (w) => w is DiceWidget && w.canRoll,
    );
    expect(activeDice, findsOneWidget);
    await tester.tap(activeDice);
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('TURN'), findsOneWidget);
  });
}
