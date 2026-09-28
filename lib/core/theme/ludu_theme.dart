import 'package:flutter/material.dart';

class LuduTheme {
  static const Color darkBackground = Color(0xFF0A0F1D);
  static const Color darkSurface = Color(0xFF141C2E);
  static const Color darkSurfaceElevated = Color(0xFF1E2942);
  static const Color darkBoardBezel = Color(0xFF182236);
  static const Color darkTileBase = Color(0xFF1F2B45);
  static const Color darkTileBorder = Color(0xFF2E3E61);

  static const Color lightBackground = Color(0xFFF5F3ED);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFEBE6DC);
  static const Color lightBoardBezel = Color(0xFF2B3A4A);
  static const Color lightTileBase = Color(0xFFF0EBE1);
  static const Color lightTileBorder = Color(0xFFD8D0C0);

  static const Color goldAccent = Color(0xFFE9C46A);
  static const Color goldLight = Color(0xFFFFE3A0);
  static const Color goldDark = Color(0xFFC59B27);

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
