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

  // --- Light Theme Configurations ---

  static const LuduThemeConfig royalGoldLight = LuduThemeConfig(
    mode: AppThemeMode.royalGold,
    title: 'Royal Gold (Light)',
    subtitle: 'Porcelain ivory & polished gold',
    backgroundGradient: [
      Color(0xFFFBF8F2),
      Color(0xFFF3ECE0),
      Color(0xFFE9DFCE),
    ],
    surfaceCard: Color(0xFFFFFFFF),
    surfaceCardBorder: Color(0xFFDFCC9A),
    boardBezelStart: Color(0xFFE8D7AC),
    boardBezelEnd: Color(0xFFCAA95A),
    boardInlayLine: Color(0xFFC59D3F),
    boardInlayWidth: 1.4,
    boardPaper: Color(0xFFFBF8F1),
    centerGlowColors: [
      Color(0x33F2C14E),
      Color(0x10F2C14E),
      Colors.transparent,
    ],
    cellBaseStart: Color(0xFFFFFFFF),
    cellBaseEnd: Color(0xFFF7F2E7),
    cellBorder: Color(0xFFDCC89E),
    cellBorderWidth: 0.9,
    cellHighlightLine: Color(0x88FFE8A3),
    safeCellStart: Color(0xFFFFF6D8),
    safeCellEnd: Color(0xFFFAEEBA),
    safeStarColor: Color(0xFFD4AF37),
    safeStarDeep: Color(0xFF9E772E),
    yardBezelRadius: 0.40,
    yardPanelStart: Color(0xFFFFFFFF),
    yardPanelEnd: Color(0xFFF6F0E2),
    yardPanelBorder: Color(0xFFC59D3F),
    tokenWellColor: Color(0xFFEFE8D6),
    tokenWellRim: Color(0xFFD4AF37),
    hubCenterStart: Color(0xFFFFF7DC),
    hubCenterEnd: Color(0xFFE5B842),
    hubBorder: Color(0xFFB8860B),
    hubIconColor: Color(0xFF5C4300),
    diceBodyColor: Color(0xFFFFFFFF),
    diceBorderColor: Color(0xFFD4AF37),
    dicePipColor: Color(0xFF3D2E0B),
    diceNeutralEmblem: Color(0xFFD4AF37),
    diceGlowShadow: Color(0x55F2C14E),
    playerColors: {
      LudoColor.red: ThemePlayerColor(
        primary: Color(0xFFD91A3C),
        darkShade: Color(0xFF8A0A20),
        lightGlow: Color(0xFFFF5277),
        highlight: Color(0xFFFFD6DE),
        accentRing: Color(0xFFC59D3F),
      ),
      LudoColor.green: ThemePlayerColor(
        primary: Color(0xFF138A4B),
        darkShade: Color(0xFF094D28),
        lightGlow: Color(0xFF28C76F),
        highlight: Color(0xFFD0F8E2),
        accentRing: Color(0xFFC59D3F),
      ),
      LudoColor.yellow: ThemePlayerColor(
        primary: Color(0xFFD97706),
        darkShade: Color(0xFF7A4002),
        lightGlow: Color(0xFFF59E0B),
        highlight: Color(0xFFFEF3C7),
        accentRing: Color(0xFFC59D3F),
      ),
      LudoColor.blue: ThemePlayerColor(
        primary: Color(0xFF1A6ED8),
        darkShade: Color(0xFF0D3E80),
        lightGlow: Color(0xFF4DA6FF),
        highlight: Color(0xFFD8E5FF),
        accentRing: Color(0xFFC59D3F),
      ),
    },
  );

  static const LuduThemeConfig neonGlassLight = LuduThemeConfig(
    mode: AppThemeMode.neonGlass,
    title: 'Neon Glass (Light)',
    subtitle: 'Frosted ice & vibrant cyber glow',
    backgroundGradient: [
      Color(0xFFF2F7FC),
      Color(0xFFE5EEF8),
      Color(0xFFD8E5F4),
    ],
    surfaceCard: Color(0xFFFFFFFF),
    surfaceCardBorder: Color(0xFF90CAF9),
    boardBezelStart: Color(0xFFB3E5FC),
    boardBezelEnd: Color(0xFF81D4FA),
    boardInlayLine: Color(0xFF0288D1),
    boardInlayWidth: 1.4,
    boardPaper: Color(0xFFF4F9FD),
    centerGlowColors: [
      Color(0x3300E5FF),
      Color(0x1000E5FF),
      Colors.transparent,
    ],
    cellBaseStart: Color(0xFFFFFFFF),
    cellBaseEnd: Color(0xFFEBF3FA),
    cellBorder: Color(0xFFB0D2EC),
    cellBorderWidth: 0.9,
    cellHighlightLine: Color(0x88B3E5FC),
    safeCellStart: Color(0xFFE0F7FA),
    safeCellEnd: Color(0xFFB2EBF2),
    safeStarColor: Color(0xFF00ACC1),
    safeStarDeep: Color(0xFF006064),
    yardBezelRadius: 0.40,
    yardPanelStart: Color(0xFFFFFFFF),
    yardPanelEnd: Color(0xFFE8F2FA),
    yardPanelBorder: Color(0xFF0288D1),
    tokenWellColor: Color(0xFFE0EEF8),
    tokenWellRim: Color(0xFF4FC3F7),
    hubCenterStart: Color(0xFFE0F7FA),
    hubCenterEnd: Color(0xFF80DEEA),
    hubBorder: Color(0xFF00838F),
    hubIconColor: Color(0xFF004D40),
    diceBodyColor: Color(0xFFFFFFFF),
    diceBorderColor: Color(0xFF0288D1),
    dicePipColor: Color(0xFF01579B),
    diceNeutralEmblem: Color(0xFF0288D1),
    diceGlowShadow: Color(0x5500E5FF),
    playerColors: {
      LudoColor.red: ThemePlayerColor(
        primary: Color(0xFFE91E63),
        darkShade: Color(0xFF880E4F),
        lightGlow: Color(0xFFFF4081),
        highlight: Color(0xFFF8BBD0),
        accentRing: Color(0xFF0288D1),
      ),
      LudoColor.green: ThemePlayerColor(
        primary: Color(0xFF00C853),
        darkShade: Color(0xFF00695C),
        lightGlow: Color(0xFF69F0AE),
        highlight: Color(0xFFB9F6CA),
        accentRing: Color(0xFF0288D1),
      ),
      LudoColor.yellow: ThemePlayerColor(
        primary: Color(0xFFFFAB00),
        darkShade: Color(0xFFFF6D00),
        lightGlow: Color(0xFFFFD740),
        highlight: Color(0xFFFFF8E1),
        accentRing: Color(0xFF0288D1),
      ),
      LudoColor.blue: ThemePlayerColor(
        primary: Color(0xFF0091EA),
        darkShade: Color(0xFF01579B),
        lightGlow: Color(0xFF40C4FF),
        highlight: Color(0xFFE1F5FE),
        accentRing: Color(0xFF0288D1),
      ),
    },
  );

  static const LuduThemeConfig woodenLuxeLight = LuduThemeConfig(
    mode: AppThemeMode.woodenLuxe,
    title: 'Wooden Luxe (Light)',
    subtitle: 'Polished blonde birch & burnished brass',
    backgroundGradient: [
      Color(0xFFF8F4EC),
      Color(0xFFEFE8DB),
      Color(0xFFE4DAC7),
    ],
    surfaceCard: Color(0xFFFCF9F3),
    surfaceCardBorder: Color(0xFFCDB084),
    boardBezelStart: Color(0xFFDCC199),
    boardBezelEnd: Color(0xFFB89664),
    boardInlayLine: Color(0xFF9E772E),
    boardInlayWidth: 1.4,
    boardPaper: Color(0xFFF7F1E1),
    centerGlowColors: [
      Color(0x33D4AF37),
      Color(0x10D4AF37),
      Colors.transparent,
    ],
    cellBaseStart: Color(0xFFFFFDF8),
    cellBaseEnd: Color(0xFFF2E7D2),
    cellBorder: Color(0xFFCEB58C),
    cellBorderWidth: 0.9,
    cellHighlightLine: Color(0x88FFE4B5),
    safeCellStart: Color(0xFFF7E8CE),
    safeCellEnd: Color(0xFFEBD4AD),
    safeStarColor: Color(0xFFB8860B),
    safeStarDeep: Color(0xFF6B4E0F),
    yardBezelRadius: 0.40,
    yardPanelStart: Color(0xFFFAF4E6),
    yardPanelEnd: Color(0xFFEDE0C4),
    yardPanelBorder: Color(0xFF9E772E),
    tokenWellColor: Color(0xFFE2D3B6),
    tokenWellRim: Color(0xFFB89868),
    hubCenterStart: Color(0xFFF5E4C3),
    hubCenterEnd: Color(0xFFD4B27D),
    hubBorder: Color(0xFF8B6528),
    hubIconColor: Color(0xFF4A3412),
    diceBodyColor: Color(0xFFFFFDF8),
    diceBorderColor: Color(0xFF9E772E),
    dicePipColor: Color(0xFF42280E),
    diceNeutralEmblem: Color(0xFF9E772E),
    diceGlowShadow: Color(0x55D4AF37),
    playerColors: {
      LudoColor.red: ThemePlayerColor(
        primary: Color(0xFFC0392B),
        darkShade: Color(0xFF6E1810),
        lightGlow: Color(0xFFE74C3C),
        highlight: Color(0xFFFADBD8),
        accentRing: Color(0xFF9E772E),
      ),
      LudoColor.green: ThemePlayerColor(
        primary: Color(0xFF27AE60),
        darkShade: Color(0xFF145A32),
        lightGlow: Color(0xFF2ECC71),
        highlight: Color(0xFFD5F5E3),
        accentRing: Color(0xFF9E772E),
      ),
      LudoColor.yellow: ThemePlayerColor(
        primary: Color(0xFFD35400),
        darkShade: Color(0xFF78281F),
        lightGlow: Color(0xFFE67E22),
        highlight: Color(0xFFFCF3CF),
        accentRing: Color(0xFF9E772E),
      ),
      LudoColor.blue: ThemePlayerColor(
        primary: Color(0xFF2980B9),
        darkShade: Color(0xFF1B4F72),
        lightGlow: Color(0xFF3498DB),
        highlight: Color(0xFFD4E6F1),
        accentRing: Color(0xFF9E772E),
      ),
    },
  );

  static LuduThemeConfig forMode(AppThemeMode mode, {bool isDark = true}) {
    switch (mode) {
      case AppThemeMode.royalGold:
        return isDark ? royalGold : royalGoldLight;
      case AppThemeMode.neonGlass:
        return isDark ? neonGlass : neonGlassLight;
      case AppThemeMode.woodenLuxe:
        return isDark ? woodenLuxe : woodenLuxeLight;
    }
  }

  // Backward compatibility aliases
  static const Color darkBackground = Color(0xFF070B1A);
  static const Color darkSurface = Color(0xFF121B33);
  static const Color darkSurfaceElevated = Color(0xFF1C2745);
  static const Color goldAccent = Color(0xFFF2C14E);
  static const Color goldLight = Color(0xFFFFE3A0);
  static const Color goldDark = Color(0xFFB8860B);

  static ThemeData get darkTheme => getTheme(AppThemeMode.royalGold, isDark: true);
  static ThemeData get lightTheme => getTheme(AppThemeMode.royalGold, isDark: false);

  static ThemeData getTheme(AppThemeMode mode, {bool isDark = true}) {
    final cfg = forMode(mode, isDark: isDark);
    if (!isDark) {
      return ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: cfg.backgroundGradient[0],
        colorScheme: ColorScheme.light(
          primary: cfg.boardInlayLine,
          surface: cfg.surfaceCard,
          onSurface: const Color(0xFF1B1812),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Color(0xFF1B1812)),
          titleTextStyle: TextStyle(
            color: cfg.boardInlayLine,
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
