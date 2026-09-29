import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludu/main.dart';
import 'package:ludu/ui/widgets/dice_widget.dart';

void main() {
  testWidgets(
      'LuduApp launches to SetupScreen, starts a tall-board game, rolls',
      (WidgetTester tester) async {
    // Realistic portrait phone so the tall layout fits.
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

    // Tall-board game screen: exactly one active "Your turn" panel.
    expect(find.text('Your turn'), findsOneWidget);

    // Tap the active player's big panel dice: the roll must resolve
    // without errors (turn either stays with movables or passes on).
    final activeDice = find.byWidgetPredicate(
      (w) => w is DiceWidget && w.canRoll,
    );
    expect(activeDice, findsOneWidget);
    await tester.tap(activeDice);
    for (int i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Your turn'), findsOneWidget);
  });
}
