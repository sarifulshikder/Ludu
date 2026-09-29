import 'package:flutter/material.dart';

/// "Aurora Arena" — midnight-glass premium theme.
/// Deep indigo backdrop, frosted panels, champagne-gold accents.
class LuduTheme {
  static const Color darkBackground = Color(0xFF070B1A);
  static const Color darkSurface = Color(0xFF121B33);
  static const Color darkSurfaceElevated = Color(0xFF1C2745);
  static const Color darkBoardBezel = Color(0xFF1A2340);
  static const Color darkTileBase = Color(0xFFF4F1EA);
  static const Color darkTileBorder = Color(0xFF8E99B0);

  static const Color lightBackground = Color(0xFFF3EFE6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFE9E2D3);
  static const Color lightBoardBezel = Color(0xFF22314F);
  static const Color lightTileBase = Color(0xFFFFFFFF);
  static const Color lightTileBorder = Color(0xFFB9B0A0);

  static const Color goldAccent = Color(0xFFF2C14E);
  static const Color goldLight = Color(0xFFFFE3A0);
  static const Color goldDark = Color(0xFFB8860B);

  /// Aurora gradient stops for the game backdrop.
  static const List<Color> darkAurora = [
    Color(0xFF0C1633),
    Color(0xFF070B1A),
    Color(0xFF101F3D),
  ];
  static const List<Color> lightAurora = [
    Color(0xFFEAF1F8),
    Color(0xFFF6F1E6),
    Color(0xFFDDE7F1),
  ];

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: goldAccent,
        surface: darkSurface,
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.0,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2A3854), width: 1),
        ),
      ),
      fontFamily: 'Roboto',
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: lightBackground,
      colorScheme: const ColorScheme.light(
        primary: goldDark,
        surface: lightSurface,
        onSurface: Color(0xFF1E293B),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Color(0xFF1E293B),
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.0,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFDCD5C5), width: 1),
        ),
      ),
      fontFamily: 'Roboto',
    );
  }
}
