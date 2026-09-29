import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ludu/main.dart';

void main() {
  testWidgets('LuduApp launches to SetupScreen and starts game', (WidgetTester tester) async {
    // Set a realistic phone screen size so scrollable content fits
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const LuduApp());
    await tester.pumpAndSettle();

    // Verify title and setup options exist
    expect(find.text('LUDU'), findsWidgets);
    expect(find.text('4 Players'), findsOneWidget);

    // Scroll to button if needed and tap
    await tester.ensureVisible(find.text('START GAME'));
    await tester.tap(find.text('START GAME'));
    await tester.pumpAndSettle();

    // Verify GameScreen is now displayed with turn dock and dice controls
    expect(find.textContaining('TAP TO ROLL'), findsOneWidget);
  });
}
