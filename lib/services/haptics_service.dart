import 'package:flutter/services.dart';

class HapticsService {
  static bool isEnabled = true;

  static void setEnabled(bool v) => isEnabled = v;

  /// Fire-and-forget haptic that can never crash the caller.
  /// On headless `flutter test` unit tests there is no platform binding, so
  /// every platform-channel error (sync or async) is swallowed here.
  static void _buzz(Future<void> Function() play) {
    if (!isEnabled) return;
    try {
      play().then((_) {}, onError: (_) {});
    } catch (_) {
      // No platform binding (e.g. headless unit tests) — ignore.
    }
  }

  static void light() => _buzz(HapticFeedback.lightImpact);

  static void medium() => _buzz(HapticFeedback.mediumImpact);

  static void heavy() => _buzz(HapticFeedback.heavyImpact);

  static void selection() => _buzz(HapticFeedback.selectionClick);

  static void capture() {
    _buzz(HapticFeedback.heavyImpact);
    Future.delayed(const Duration(milliseconds: 120), () {
      _buzz(HapticFeedback.heavyImpact);
    }).then((_) {}, onError: (_) {});
  }

  static void victory() {
    _buzz(HapticFeedback.mediumImpact);
    Future.delayed(const Duration(milliseconds: 150), () {
      _buzz(HapticFeedback.heavyImpact);
    }).then((_) {}, onError: (_) {});
    Future.delayed(const Duration(milliseconds: 300), () {
      _buzz(HapticFeedback.mediumImpact);
    }).then((_) {}, onError: (_) {});
  }
}
