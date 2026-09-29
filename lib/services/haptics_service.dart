import 'package:flutter/services.dart';

class HapticsService {
  static bool isEnabled = true;

  static void setEnabled(bool v) => isEnabled = v;

  static void light() {
    if (!isEnabled) return;
    HapticFeedback.lightImpact();
  }

  static void medium() {
    if (!isEnabled) return;
    HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (!isEnabled) return;
    HapticFeedback.heavyImpact();
  }

  static void selection() {
    if (!isEnabled) return;
    HapticFeedback.selectionClick();
  }

  static void capture() {
    if (!isEnabled) return;
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (isEnabled) HapticFeedback.heavyImpact();
    });
  }

  static void victory() {
    if (!isEnabled) return;
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 150), () {
      if (isEnabled) HapticFeedback.heavyImpact();
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (isEnabled) HapticFeedback.mediumImpact();
    });
  }
}
