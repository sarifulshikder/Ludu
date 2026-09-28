import 'ludo_color.dart';
import 'token.dart';

class Player {
  final int id;
  final String name;
  final LudoColor color;
  final List<Token> tokens;
  final int? finishRank; // 1 for 1st, 2 for 2nd, etc. null if still active

  Player({
    required this.id,
    required this.name,
    required this.color,
    List<Token>? tokens,
    this.finishRank,
  }) : tokens = tokens ??
            List.generate(
              4,
              (index) => Token(id: index, color: color, step: -1),
              growable: false,
            );

  bool get hasFinished => tokens.every((token) => token.isHome);
  int get tokensHomeCount => tokens.where((token) => token.isHome).length;
  int get tokensInBaseCount => tokens.where((token) => token.isInBase).length;
  int get tokensInPlayCount => tokens.where((token) => !token.isInBase && !token.isHome).length;

  Player copyWith({
    int? id,
    String? name,
    LudoColor? color,
    List<Token>? tokens,
    int? finishRank,
    bool clearRank = false,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      tokens: tokens ?? this.tokens,
      finishRank: clearRank ? null : (finishRank ?? this.finishRank),
    );
  }

  @override
  String toString() => 'Player($name, color: ${color.shortName}, rank: $finishRank)';
}
