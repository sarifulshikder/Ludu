/// Player-facing game settings.
///
/// * [autoMove]: when exactly one legal move exists, the UI moves it
///   automatically after a short beat. Default ON.
/// * [blockRule]: when ON, a stack of 2+ same-color tokens on a non-safe
///   square is protected — opponents cannot land on it. Default OFF.
/// * [endAtFirstWinner]: when ON, the match ends at the first winner.
///   Default OFF (game continues for 2nd/3rd place).
/// * [sound], [vibration]: effect toggles. Default ON.
/// * [faceToFaceMode]: when ON, top player chips & dice rotate 180° for
///   opponents sitting across the phone. Default OFF.
/// * [appTheme]: theme selection (Royal Gold, Neon Glass, Wooden Luxe).
enum AppThemeMode {
  royalGold,
  neonGlass,
  woodenLuxe,
}

/// Premium sound packs (§C): Wood (default, warm), Glass (bright),
/// Minimal (soft and subtle).
enum SoundPack {
  wood,
  glass,
  minimal,
}

extension SoundPackExt on SoundPack {
  String get displayName {
    switch (this) {
      case SoundPack.wood:
        return 'Wood';
      case SoundPack.glass:
        return 'Glass';
      case SoundPack.minimal:
        return 'Minimal';
    }
  }

  String get subtitle {
    switch (this) {
      case SoundPack.wood:
        return 'Warm wooden tocks (default)';
      case SoundPack.glass:
        return 'Bright glassy shimmer';
      case SoundPack.minimal:
        return 'Soft and subtle';
    }
  }

  /// Asset prefix for this pack. Wood lives at the root for
  /// backward compatibility with older saves/clients.
  String get assetPrefix {
    switch (this) {
      case SoundPack.wood:
        return 'audio/';
      case SoundPack.glass:
        return 'audio/glass/';
      case SoundPack.minimal:
        return 'audio/minimal/';
    }
  }
}

extension AppThemeModeExt on AppThemeMode {
  String get displayName {
    switch (this) {
      case AppThemeMode.royalGold:
        return 'Royal Gold';
      case AppThemeMode.neonGlass:
        return 'Neon Glass';
      case AppThemeMode.woodenLuxe:
        return 'Wooden Luxe';
    }
  }

  String get subtitle {
    switch (this) {
      case AppThemeMode.royalGold:
        return 'Midnight lacquer & gold inlay';
      case AppThemeMode.neonGlass:
        return 'Frosted glass & cyber neon';
      case AppThemeMode.woodenLuxe:
        return 'Polished walnut & brass inlays';
    }
  }

  String get emoji {
    switch (this) {
      case AppThemeMode.royalGold:
        return '👑';
      case AppThemeMode.neonGlass:
        return '🔮';
      case AppThemeMode.woodenLuxe:
        return '🪵';
    }
  }
}

class GameSettings {
  final bool autoMove;
  final bool blockRule;
  final bool endAtFirstWinner;
  final bool sound;
  final bool vibration;

  /// Master sound volume 0.0–1.0.
  final double volume;

  /// Fast hop/dice animation. Normal = full pace, fast ≈ half time.
  final bool fastAnimation;

  /// Head-to-head rotation for opponents sitting across the device.
  final bool faceToFaceMode;

  /// Active premium theme.
  final AppThemeMode appTheme;

  /// Dark mode (true) or light mode (false). Default false (Light mode).
  final bool isDark;

  /// Active premium sound pack. Default Wood.
  final SoundPack soundPack;

  /// Background music toggle. Always OFF by default (no music asset ships;
  /// the toggle is reserved for a future ambient layer).
  final bool backgroundMusic;

  const GameSettings({
    this.autoMove = true,
    this.blockRule = false,
    this.endAtFirstWinner = false,
    this.sound = true,
    this.vibration = true,
    this.volume = 0.8,
    this.fastAnimation = false,
    this.faceToFaceMode = false,
    this.appTheme = AppThemeMode.royalGold,
    this.isDark = false,
    this.soundPack = SoundPack.wood,
    this.backgroundMusic = false,
  });

  /// Duration multiplier for hop/dice animations (1.0 normal, 0.55 fast).
  double get timeScale => fastAnimation ? 0.55 : 1.0;

  GameSettings copyWith({
    bool? autoMove,
    bool? blockRule,
    bool? endAtFirstWinner,
    bool? sound,
    bool? vibration,
    double? volume,
    bool? fastAnimation,
    bool? faceToFaceMode,
    AppThemeMode? appTheme,
    bool? isDark,
    SoundPack? soundPack,
    bool? backgroundMusic,
  }) {
    return GameSettings(
      autoMove: autoMove ?? this.autoMove,
      blockRule: blockRule ?? this.blockRule,
      endAtFirstWinner: endAtFirstWinner ?? this.endAtFirstWinner,
      sound: sound ?? this.sound,
      vibration: vibration ?? this.vibration,
      volume: volume ?? this.volume,
      fastAnimation: fastAnimation ?? this.fastAnimation,
      faceToFaceMode: faceToFaceMode ?? this.faceToFaceMode,
      appTheme: appTheme ?? this.appTheme,
      isDark: isDark ?? this.isDark,
      soundPack: soundPack ?? this.soundPack,
      backgroundMusic: backgroundMusic ?? this.backgroundMusic,
    );
  }

  Map<String, dynamic> toJson() => {
        'autoMove': autoMove,
        'blockRule': blockRule,
        'endAtFirstWinner': endAtFirstWinner,
        'sound': sound,
        'vibration': vibration,
        'volume': volume,
        'fastAnimation': fastAnimation,
        'faceToFaceMode': faceToFaceMode,
        'appTheme': appTheme.name,
        'isDark': isDark,
        'soundPack': soundPack.name,
        'backgroundMusic': backgroundMusic,
      };

  factory GameSettings.fromJson(Map<String, dynamic> json) {
    return GameSettings(
      autoMove: json['autoMove'] as bool? ?? true,
      blockRule: json['blockRule'] as bool? ?? false,
      endAtFirstWinner: json['endAtFirstWinner'] as bool? ?? false,
      sound: json['sound'] as bool? ?? true,
      vibration: json['vibration'] as bool? ?? true,
      volume: (json['volume'] as num?)?.toDouble() ?? 0.8,
      fastAnimation: json['fastAnimation'] as bool? ?? false,
      faceToFaceMode: json['faceToFaceMode'] as bool? ?? false,
      appTheme: AppThemeMode.values.firstWhere(
        (t) => t.name == (json['appTheme'] as String?),
        orElse: () => AppThemeMode.royalGold,
      ),
      isDark: json['isDark'] as bool? ?? false,
      soundPack: SoundPack.values.firstWhere(
        (t) => t.name == (json['soundPack'] as String?),
        orElse: () => SoundPack.wood,
      ),
      backgroundMusic: json['backgroundMusic'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GameSettings &&
          runtimeType == other.runtimeType &&
          autoMove == other.autoMove &&
          blockRule == other.blockRule &&
          endAtFirstWinner == other.endAtFirstWinner &&
          sound == other.sound &&
          vibration == other.vibration &&
          volume == other.volume &&
          fastAnimation == other.fastAnimation &&
          faceToFaceMode == other.faceToFaceMode &&
          appTheme == other.appTheme &&
          isDark == other.isDark &&
          soundPack == other.soundPack &&
          backgroundMusic == other.backgroundMusic;

  @override
  int get hashCode => Object.hash(
        autoMove,
        blockRule,
        endAtFirstWinner,
        sound,
        vibration,
        volume,
        fastAnimation,
        faceToFaceMode,
        appTheme,
        isDark,
        soundPack,
        backgroundMusic,
      );
}
