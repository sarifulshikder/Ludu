/// Player-facing game settings (§4, §6, §7, §9).
///
/// * [autoMove]: when exactly one legal move exists, the UI moves it
///   automatically after a short beat. Default ON.
/// * [blockRule]: when ON, a stack of 2+ same-color tokens on a non-safe
///   square is protected — opponents cannot land on it. Default OFF.
/// * [endAtFirstWinner]: when ON, the match ends at the first winner.
///   Default OFF (game continues for 2nd/3rd place).
/// * [sound], [vibration]: effect toggles. Default ON.
class GameSettings {
  final bool autoMove;
  final bool blockRule;
  final bool endAtFirstWinner;
  final bool sound;
  final bool vibration;

  const GameSettings({
    this.autoMove = true,
    this.blockRule = false,
    this.endAtFirstWinner = false,
    this.sound = true,
    this.vibration = true,
  });

  GameSettings copyWith({
    bool? autoMove,
    bool? blockRule,
    bool? endAtFirstWinner,
    bool? sound,
    bool? vibration,
  }) {
    return GameSettings(
      autoMove: autoMove ?? this.autoMove,
      blockRule: blockRule ?? this.blockRule,
      endAtFirstWinner: endAtFirstWinner ?? this.endAtFirstWinner,
      sound: sound ?? this.sound,
      vibration: vibration ?? this.vibration,
    );
  }

  Map<String, dynamic> toJson() => {
        'autoMove': autoMove,
        'blockRule': blockRule,
        'endAtFirstWinner': endAtFirstWinner,
        'sound': sound,
        'vibration': vibration,
      };

  factory GameSettings.fromJson(Map<String, dynamic> json) {
    return GameSettings(
      autoMove: json['autoMove'] as bool? ?? true,
      blockRule: json['blockRule'] as bool? ?? false,
      endAtFirstWinner: json['endAtFirstWinner'] as bool? ?? false,
      sound: json['sound'] as bool? ?? true,
      vibration: json['vibration'] as bool? ?? true,
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
          vibration == other.vibration;

  @override
  int get hashCode => Object.hash(
      autoMove, blockRule, endAtFirstWinner, sound, vibration);
}
