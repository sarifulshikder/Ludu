import 'package:flutter/material.dart';

/// The 4 player colors in Ludu — "Aurora Arena" palette.
///
/// Color-blind-safe set inspired by Okabe–Ito (safe for deuteranopia,
/// protanopia and tritanopia). Each color is double-coded with a unique
/// emblem shape so players never rely on hue alone:
/// - Red/Vermilion ▲ triangle
/// - Teal/Green ● circle
/// - Amber/Gold ★ star
/// - Ultramarine Blue ■ square
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
        return 'Ember Red';
      case LudoColor.green:
        return 'Lagoon Teal';
      case LudoColor.yellow:
        return 'Solar Amber';
      case LudoColor.blue:
        return 'Abyss Blue';
    }
  }

  String get shortName {
    switch (this) {
      case LudoColor.red:
        return 'Red';
      case LudoColor.green:
        return 'Teal';
      case LudoColor.yellow:
        return 'Amber';
      case LudoColor.blue:
        return 'Blue';
    }
  }

  /// Shape-coding for color-blind players. Drawn as the token emblem and
  /// reused on the player's home-column arrow.
  String get emblemGlyph {
    switch (this) {
      case LudoColor.red:
        return '▲';
      case LudoColor.green:
        return '●';
      case LudoColor.yellow:
        return '★';
      case LudoColor.blue:
        return '■';
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

  /// Vibrant but comfortable flat fill. Luminance is staggered
  /// (amber brightest, blue darkest) so value alone distinguishes them.
  Color get primary {
    switch (this) {
      case LudoColor.red:
        return const Color(0xFFE2483A); // Vermilion ember
      case LudoColor.green:
        return const Color(0xFF00A57F); // Bluish-green lagoon
      case LudoColor.yellow:
        return const Color(0xFFE5A900); // Pure rich gold
      case LudoColor.blue:
        return const Color(0xFF1976D2); // Ultramarine abyss
    }
  }

  Color get darkShade {
    switch (this) {
      case LudoColor.red:
        return const Color(0xFFB23227);
      case LudoColor.green:
        return const Color(0xFF007A5E);
      case LudoColor.yellow:
        return const Color(0xFFA67C00); // Deep golden bronze
      case LudoColor.blue:
        return const Color(0xFF0D47A1);
    }
  }

  Color get lightGlow {
    switch (this) {
      case LudoColor.red:
        return const Color(0xFFFF9B8A);
      case LudoColor.green:
        return const Color(0xFF5EEAD4);
      case LudoColor.yellow:
        return const Color(0xFFFFDF6D); // Bright gold glow
      case LudoColor.blue:
        return const Color(0xFF7FB8FF);
    }
  }

  /// Bright orb highlight used for the 3D token specular.
  Color get orbHighlight {
    switch (this) {
      case LudoColor.red:
        return const Color(0xFFFFD9D2);
      case LudoColor.green:
        return const Color(0xFFCCFBF1);
      case LudoColor.yellow:
        return const Color(0xFFFFF9DB); // Pale gold specular highlight
      case LudoColor.blue:
        return const Color(0xFFD6E9FF);
    }
  }

  LinearGradient get jewelGradient {
    return LinearGradient(
      colors: [lightGlow, primary, darkShade],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }

  /// Radial 3D orb gradient (highlight top-left → primary → dark edge).
  RadialGradient get orbGradient {
    return RadialGradient(
      colors: [orbHighlight, primary, darkShade],
      stops: const [0.0, 0.45, 1.0],
      center: const Alignment(-0.35, -0.4),
      radius: 1.1,
    );
  }
}
