import 'package:flutter/material.dart';

/// The 4 player colors in Ludu.
///
/// Rich jewel tones for a distinct, high-end visual aesthetic:
/// - Red: Ruby
/// - Green: Emerald
/// - Yellow: Radiant Amber
/// - Blue: Royal Sapphire
enum LudoColor {
  red,
  green,
  yellow,
  blue,
}

extension LudoColorExt on LudoColor {
  String get displayName {
    switch (this) {
      case LudoColor.red:
        return 'Ruby Red';
      case LudoColor.green:
        return 'Emerald Green';
      case LudoColor.yellow:
        return 'Amber Gold';
      case LudoColor.blue:
        return 'Sapphire Blue';
    }
  }

  String get shortName {
    switch (this) {
      case LudoColor.red:
        return 'Red';
      case LudoColor.green:
        return 'Green';
      case LudoColor.yellow:
        return 'Yellow';
      case LudoColor.blue:
        return 'Blue';
    }
  }

  /// Global tile index where this player enters the 52-square outer track.
  int get startSquare {
    switch (this) {
      case LudoColor.red:
        return 0;
      case LudoColor.green:
        return 13;
      case LudoColor.yellow:
        return 26;
      case LudoColor.blue:
        return 39;
    }
  }

  /// Saturated flat fill used across the board, tokens and player chrome.
  Color get primary {
    switch (this) {
      case LudoColor.red:
        return const Color(0xFFE03131); // Red
      case LudoColor.green:
        return const Color(0xFF2F9E44); // Green
      case LudoColor.yellow:
        return const Color(0xFFFAB005); // Yellow
      case LudoColor.blue:
        return const Color(0xFF1971C2); // Blue
    }
  }

  Color get darkShade {
    switch (this) {
      case LudoColor.red:
        return const Color(0xFFC92A2A);
      case LudoColor.green:
        return const Color(0xFF2B8A3E);
      case LudoColor.yellow:
        return const Color(0xFFE8B90A);
      case LudoColor.blue:
        return const Color(0xFF1864AB);
    }
  }

  Color get lightGlow {
    switch (this) {
      case LudoColor.red:
        return const Color(0xFFFF8787);
      case LudoColor.green:
        return const Color(0xFF69DB7C);
      case LudoColor.yellow:
        return const Color(0xFFFFE066);
      case LudoColor.blue:
        return const Color(0xFF4DABF7);
    }
  }

  LinearGradient get jewelGradient {
    return LinearGradient(
      colors: [lightGlow, primary, darkShade],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}
