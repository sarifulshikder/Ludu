import 'package:flutter/widgets.dart';

/// True when running outside a real app: either inside `flutter test`
/// (widget binding present) or a pure Dart unit test (no binding at all).
///
/// Platform channels (audio, wakelock) have no implementation in either
/// case, so side effects that depend on them are skipped instead of
/// throwing. It also keeps endlessly repeating animations out of tests, so
/// `pumpAndSettle()` can always settle.
bool get isFlutterTest {
  try {
    final type = WidgetsBinding.instance.runtimeType.toString();
    return type.contains('Test');
  } catch (_) {
    // No widget binding: a pure Dart unit test.
    return true;
  }
}
