import 'ludo_color.dart';

class Token {
  final int id;
  final LudoColor color;
  final int step; // -1: base, 0..50: outer track, 51..55: home stretch, 56: home

  const Token({
    required this.id,
    required this.color,
    this.step = -1,
  });

  bool get isInBase => step == -1;
  bool get isOnOuterTrack => step >= 0 && step <= 50;
  bool get isOnHomeStretch => step >= 51 && step <= 55;
  bool get isHome => step >= 56;

  int? get globalTrackIndex {
    if (!isOnOuterTrack) return null;
    return (color.startSquare + step) % 52;
  }

  Token copyWith({
    int? id,
    LudoColor? color,
    int? step,
  }) {
    return Token(
      id: id ?? this.id,
      color: color ?? this.color,
      step: step ?? this.step,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'color': color.index,
        'step': step,
      };

  factory Token.fromJson(Map<String, dynamic> json, LudoColor fallback) {
    final colorIndex = json['color'] as int?;
    final color = (colorIndex != null &&
            colorIndex >= 0 &&
            colorIndex < LudoColor.values.length)
        ? LudoColor.values[colorIndex]
        : fallback;
    return Token(
      id: (json['id'] as int?) ?? 0,
      color: color,
      step: (json['step'] as int?) ?? -1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Token &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          color == other.color &&
          step == other.step;

  @override
  int get hashCode => Object.hash(id, color, step);

  @override
  String toString() => 'Token(id: $id, color: ${color.shortName}, step: $step)';
}
