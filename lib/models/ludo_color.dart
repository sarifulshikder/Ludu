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

  Color get primary {
    switch (this) {
      case LudoColor.red:
        return const Color(0xFFE63946); // Ruby
      case LudoColor.green:
        return const Color(0xFF2A9D8F); // Emerald
      case LudoColor.yellow:
        return const Color(0xFFE9C46A); // Warm Amber Gold
      case LudoColor.blue:
        return const Color(0xFF277DA1); // Sapphire
    }
  }

  Color get darkShade {
    switch (this) {
      case LudoColor.red:
        return const Color(0xFF9E1B25);
      case LudoColor.green:
        return const Color(0xFF1B635A);
      case LudoColor.yellow:
        return const Color(0xFFB58A26);
      case LudoColor.blue:
        return const Color(0xFF154C63);
    }
  }

  Color get lightGlow {
    switch (this) {
      case LudoColor.red:
        return const Color(0xFFFF6B6B);
      case LudoColor.green:
        return const Color(0xFF48CAE4);
      case LudoColor.yellow:
        return const Color(0xFFFFD166);
      case LudoColor.blue:
        return const Color(0xFF4EA8DE);
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
