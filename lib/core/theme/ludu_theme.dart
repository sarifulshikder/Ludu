import 'package:flutter/material.dart';
import '../../models/game_settings.dart';
import '../../models/ludo_color.dart';

/// Palette and visual styling details for a single player color within a theme.
class ThemePlayerColor {
  final Color primary;
  final Color darkShade;
  final Color lightGlow;
  final Color highlight;
  final Color accentRing;

  const ThemePlayerColor({
    required this.primary,
    required this.darkShade,
    required this.lightGlow,
    required this.highlight,
    required this.accentRing,
  });
}

/// Comprehensive configuration for a distinct visual theme.
class LuduThemeConfig {
  final AppThemeMode mode;
  final String title;
  final String subtitle;

  // Background
  final List<Color> backgroundGradient;
  final Color surfaceCard;
  final Color surfaceCardBorder;

  // Board
  final Color boardBezelStart;
  final Color boardBezelEnd;
  final Color boardInlayLine;
  final double boardInlayWidth;
  final Color boardPaper;
  final List<Color> centerGlowColors;

  // Track cells
  final Color cellBaseStart;
  final Color cellBaseEnd;
  final Color cellBorder;
  final double cellBorderWidth;
  final Color cellHighlightLine;

  // Safe squares
  final Color safeCellStart;
  final Color safeCellEnd;
  final Color safeStarColor;
  final Color safeStarDeep;

  // Yard styling
  final double yardBezelRadius;
  final Color yardPanelStart;
  final Color yardPanelEnd;
  final Color yardPanelBorder;
  final Color tokenWellColor;
  final Color tokenWellRim;

  // Center hub
  final Color hubCenterStart;
  final Color hubCenterEnd;
  final Color hubBorder;
  final Color hubIconColor;

  // Single Dice
  final Color diceBodyColor;
  final Color diceBorderColor;
  final Color dicePipColor;
  final Color diceNeutralEmblem;
  final Color diceGlowShadow;

  // Player colors
  final Map<LudoColor, ThemePlayerColor> playerColors;

  const LuduThemeConfig({
    required this.mode,
    required this.title,
    required this.subtitle,
    required this.backgroundGradient,
    required this.surfaceCard,
    required this.surfaceCardBorder,
    required this.boardBezelStart,
    required this.boardBezelEnd,
    required this.boardInlayLine,
    required this.boardInlayWidth,
    required this.boardPaper,
    required this.centerGlowColors,
    required this.cellBaseStart,
    required this.cellBaseEnd,
    required this.cellBorder,
    required this.cellBorderWidth,
    required this.cellHighlightLine,
    required this.safeCellStart,
    required this.safeCellEnd,
    required this.safeStarColor,
    required this.safeStarDeep,
    required this.yardBezelRadius,
    required this.yardPanelStart,
    required this.yardPanelEnd,
    required this.yardPanelBorder,
    required this.tokenWellColor,
    required this.tokenWellRim,
    required this.hubCenterStart,
    required this.hubCenterEnd,
    required this.hubBorder,
    required this.hubIconColor,
    required this.diceBodyColor,
    required this.diceBorderColor,
    required this.dicePipColor,
    required this.diceNeutralEmblem,
    required this.diceGlowShadow,
    required this.playerColors,
  });

  ThemePlayerColor colorOf(LudoColor color) =>
      playerColors[color] ??
      ThemePlayerColor(
        primary: color.primary,
        darkShade: color.darkShade,
        lightGlow: color.lightGlow,
        highlight: color.orbHighlight,
        accentRing: color.primary,
      );
}

class LuduTheme {
  // --- Theme A: Royal Gold ---
  // Deep midnight-black lacquer board with gold inlay lines,
  // jewel-toned colors (ruby, emerald, sapphire, amber), glossy gem-like tokens.
  static const LuduThemeConfig royalGold = LuduThemeConfig(
    mode: AppThemeMode.royalGold,
    title: 'Royal Gold',
    subtitle: 'Midnight lacquer & gold inlay',
    backgroundGradient: [
      Color(0xFF090D18),
      Color(0xFF04060C),
      Color(0xFF080C16),
    ],
    surfaceCard: Color(0xFF101626),
    surfaceCardBorder: Color(0xFF2E2412),
    boardBezelStart: Color(0xFF1E170E),
    boardBezelEnd: Color(0xFF0A0704),
    boardInlayLine: Color(0xFFE5B842),
    boardInlayWidth: 1.4,
    boardPaper: Color(0xFF0B0F1B),
    centerGlowColors: [
      Color(0x33F2C14E),
      Color(0x0FF2C14E),
      Colors.transparent,
    ],
    cellBaseStart: Color(0xFF151C2C),
    cellBaseEnd: Color(0xFF0E1320),
    cellBorder: Color(0xFF755B25),
    cellBorderWidth: 0.9,
    cellHighlightLine: Color(0x66FFDF78),
    safeCellStart: Color(0xFF332711),
    safeCellEnd: Color(0xFF1A1408),
    safeStarColor: Color(0xFFFFE07A),
    safeStarDeep: Color(0xFFB8860B),
    yardBezelRadius: 0.40,
    yardPanelStart: Color(0xFF111726),
    yardPanelEnd: Color(0xFF090D17),
    yardPanelBorder: Color(0xFFC59D3F),
    tokenWellColor: Color(0xFF0A0E18),
    tokenWellRim: Color(0xFFD4AF37),
    hubCenterStart: Color(0xFFFFF3C4),
    hubCenterEnd: Color(0xFFB8860B),
    hubBorder: Color(0xFF5C4300),
    hubIconColor: Color(0xFF382700),
    diceBodyColor: Color(0xFFF9F5EC),
    diceBorderColor: Color(0xFFD4AF37),
    dicePipColor: Color(0xFF1E1B15),
    diceNeutralEmblem: Color(0xFFC59D3F),
    diceGlowShadow: Color(0x66F2C14E),
    playerColors: {
      LudoColor.red: ThemePlayerColor(
        primary: Color(0xFFE63946),
        darkShade: Color(0xFF94121E),
        lightGlow: Color(0xFFFF7A85),
        highlight: Color(0xFFFFD3D7),
        accentRing: Color(0xFFFFD700),
      ),
      LudoColor.green: ThemePlayerColor(
        primary: Color(0xFF06D6A0),
        darkShade: Color(0xFF04664C),
        lightGlow: Color(0xFF6EEDCA),
        highlight: Color(0xFFD4FBF0),
        accentRing: Color(0xFFFFD700),
      ),
      LudoColor.yellow: ThemePlayerColor(
        primary: Color(0xFFF59E0B),
        darkShade: Color(0xFF92400E),
        lightGlow: Color(0xFFFCD34D),
        highlight: Color(0xFFFEF3C7),
        accentRing: Color(0xFFFFD700),
      ),
      LudoColor.blue: ThemePlayerColor(
        primary: Color(0xFF2563EB),
        darkShade: Color(0xFF10368C),
        lightGlow: Color(0xFF709DFB),
        highlight: Color(0xFFD8E5FF),
        accentRing: Color(0xFFFFD700),
      ),
    },
  );

  // --- Theme B: Neon Glass ---
  // Dark frosted-glass surfaces, soft neon glow on paths and tokens,
  // subtle light trails.
  static const LuduThemeConfig neonGlass = LuduThemeConfig(
    mode: AppThemeMode.neonGlass,
    title: 'Neon Glass',
    subtitle: 'Frosted glass & cyber neon',
    backgroundGradient: [
      Color(0xFF080D1D),
      Color(0xFF04060E),
      Color(0xFF0B1228),
    ],
    surfaceCard: Color(0xFF0E1830),
    surfaceCardBorder: Color(0xFF1E3A68),
    boardBezelStart: Color(0xFF152A50),
    boardBezelEnd: Color(0xFF091224),
    boardInlayLine: Color(0xFF00F0FF),
    boardInlayWidth: 1.2,
    boardPaper: Color(0xFF070E1E),
    centerGlowColors: [
      Color(0x3300F0FF),
      Color(0x0F00F0FF),
      Colors.transparent,
    ],
    cellBaseStart: Color(0xFF101D38),
    cellBaseEnd: Color(0xFF0A1326),
    cellBorder: Color(0xFF224478),
    cellBorderWidth: 0.9,
    cellHighlightLine: Color(0x6600F0FF),
    safeCellStart: Color(0xFF0B2B47),
    safeCellEnd: Color(0xFF071B2D),
    safeStarColor: Color(0xFF00F0FF),
    safeStarDeep: Color(0xFF0084B4),
    yardBezelRadius: 0.38,
    yardPanelStart: Color(0xFF0F1E3A),
    yardPanelEnd: Color(0xFF081224),
    yardPanelBorder: Color(0xFF00D2E6),
    tokenWellColor: Color(0xFF060D1A),
    tokenWellRim: Color(0xFF00F0FF),
    hubCenterStart: Color(0xFFE0FFFF),
    hubCenterEnd: Color(0xFF007A99),
    hubBorder: Color(0xFF003847),
    hubIconColor: Color(0xFF00212B),
    diceBodyColor: Color(0xFF0D1C38),
    diceBorderColor: Color(0xFF00F0FF),
    dicePipColor: Color(0xFF00F0FF),
    diceNeutralEmblem: Color(0xFF00F0FF),
    diceGlowShadow: Color(0x6600F0FF),
    playerColors: {
      LudoColor.red: ThemePlayerColor(
        primary: Color(0xFFFF2A6D),
        darkShade: Color(0xFF9E0A36),
        lightGlow: Color(0xFFFF759F),
        highlight: Color(0xFFFFD4E2),
        accentRing: Color(0xFFFF5388),
      ),
      LudoColor.green: ThemePlayerColor(
        primary: Color(0xFF05FFA1),
        darkShade: Color(0xFF008A54),
        lightGlow: Color(0xFF75FFC8),
        highlight: Color(0xFFD4FFEE),
        accentRing: Color(0xFF33FFB2),
      ),
      LudoColor.yellow: ThemePlayerColor(
        primary: Color(0xFFFFE600),
        darkShade: Color(0xFF9E8E00),
        lightGlow: Color(0xFFFFEE54),
        highlight: Color(0xFFFFF9C4),
        accentRing: Color(0xFFFFEC3D),
      ),
      LudoColor.blue: ThemePlayerColor(
        primary: Color(0xFF00F0FF),
        darkShade: Color(0xFF00759E),
        lightGlow: Color(0xFF6BFAFF),
        highlight: Color(0xFFD4FCFF),
        accentRing: Color(0xFF38F4FF),
      ),
    },
  );

  // --- Theme C: Wooden Luxe ---
  // Polished walnut board with brass inlays and soft studio lighting,
  // weighty carved pawn tokens.
  static const LuduThemeConfig woodenLuxe = LuduThemeConfig(
    mode: AppThemeMode.woodenLuxe,
    title: 'Wooden Luxe',
    subtitle: 'Polished walnut & brass inlays',
    backgroundGradient: [
      Color(0xFF1E130B),
      Color(0xFF120B06),
      Color(0xFF1B1009),
    ],
    surfaceCard: Color(0xFF271A10),
    surfaceCardBorder: Color(0xFF4A3423),
    boardBezelStart: Color(0xFF362315),
    boardBezelEnd: Color(0xFF180E07),
    boardInlayLine: Color(0xFFD8B266),
    boardInlayWidth: 1.3,
    boardPaper: Color(0xFF22160E),
    centerGlowColors: [
      Color(0x33D8B266),
      Color(0x0FD8B266),
      Colors.transparent,
    ],
    cellBaseStart: Color(0xFFEDE0CC),
    cellBaseEnd: Color(0xFFDDD0BA),
    cellBorder: Color(0xFF8C7145),
    cellBorderWidth: 0.9,
    cellHighlightLine: Color(0x66FFF5D6),
    safeCellStart: Color(0xFFD6BA85),
    safeCellEnd: Color(0xFFB89658),
    safeStarColor: Color(0xFF523B12),
    safeStarDeep: Color(0xFF332306),
    yardBezelRadius: 0.38,
    yardPanelStart: Color(0xFF2A1C12),
    yardPanelEnd: Color(0xFF1A1009),
    yardPanelBorder: Color(0xFFC59D4A),
    tokenWellColor: Color(0xFF160D07),
    tokenWellRim: Color(0xFFD8B266),
    hubCenterStart: Color(0xFFF7E4B2),
    hubCenterEnd: Color(0xFF9E772E),
    hubBorder: Color(0xFF47320D),
    hubIconColor: Color(0xFF2B1C05),
    diceBodyColor: Color(0xFFF5EEDB),
    diceBorderColor: Color(0xFF9E772E),
    dicePipColor: Color(0xFF2A1C12),
    diceNeutralEmblem: Color(0xFF9E772E),
    diceGlowShadow: Color(0x66C59D4A),
    playerColors: {
      LudoColor.red: ThemePlayerColor(
        primary: Color(0xFFB91C1C),
        darkShade: Color(0xFF6D0C0C),
        lightGlow: Color(0xFFE55757),
        highlight: Color(0xFFFFCECE),
        accentRing: Color(0xFFD8B266),
      ),
      LudoColor.green: ThemePlayerColor(
        primary: Color(0xFF15803D),
        darkShade: Color(0xFF0C4D24),
        lightGlow: Color(0xFF43B76D),
        highlight: Color(0xFFC6F5D5),
        accentRing: Color(0xFFD8B266),
      ),
      LudoColor.yellow: ThemePlayerColor(
        primary: Color(0xFFD97706),
        darkShade: Color(0xFF7A4002),
        lightGlow: Color(0xFFFBBF24),
        highlight: Color(0xFFFEF3C7),
        accentRing: Color(0xFFD8B266),
      ),
      LudoColor.blue: ThemePlayerColor(
        primary: Color(0xFF1D4ED8),
        darkShade: Color(0xFF102E84),
        lightGlow: Color(0xFF5E85ED),
        highlight: Color(0xFFD4E1FD),
        accentRing: Color(0xFFD8B266),
      ),
    },
  );

  static LuduThemeConfig forMode(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.royalGold:
        return royalGold;
      case AppThemeMode.neonGlass:
        return neonGlass;
      case AppThemeMode.woodenLuxe:
        return woodenLuxe;
    }
  }

  // Backward compatibility aliases
  static const Color darkBackground = Color(0xFF070B1A);
  static const Color darkSurface = Color(0xFF121B33);
  static const Color darkSurfaceElevated = Color(0xFF1C2745);
  static const Color goldAccent = Color(0xFFF2C14E);
  static const Color goldLight = Color(0xFFFFE3A0);
  static const Color goldDark = Color(0xFFB8860B);

  static ThemeData get darkTheme => getTheme(AppThemeMode.royalGold);
  static ThemeData get lightTheme => getTheme(AppThemeMode.royalGold);

  static ThemeData getTheme(AppThemeMode mode) {
    final cfg = forMode(mode);
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: cfg.backgroundGradient[0],
      colorScheme: ColorScheme.dark(
        primary: cfg.boardInlayLine,
        surface: cfg.surfaceCard,
        onSurface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: 3.0,
        ),
      ),
      cardTheme: CardThemeData(
        color: cfg.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cfg.surfaceCardBorder, width: 1),
        ),
      ),
      fontFamily: 'Roboto',
    );
  }
}
