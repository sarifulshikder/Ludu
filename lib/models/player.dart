import 'ludo_color.dart';
import 'token.dart';

class Player {
  final int id;
  final String name;
  final LudoColor color;
  final List<Token> tokens;
  final int? finishRank; // 1 for 1st, 2 for 2nd, etc. null if still active
  /// Team index for Team 2v2 mode. In solo mode each player is their own
  /// team (teamId == id). In team mode slots 0&2 are Team A (0) and
  /// slots 1&3 are Team B (1) — partners sit opposite each other.
  final int teamId;

  Player({
    required this.id,
    required this.name,
    required this.color,
    List<Token>? tokens,
    this.finishRank,
    int? teamId,
  })  : teamId = teamId ?? id,
        tokens = tokens ??
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
    int? teamId,
  }) {
    return Player(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      tokens: tokens ?? this.tokens,
      finishRank: clearRank ? null : (finishRank ?? this.finishRank),
      teamId: teamId ?? this.teamId,
    );
  }

  /// Display name for a team index.
  static String teamName(int teamId) => teamId == 0 ? 'Team A' : 'Team B';

  @override
  String toString() => 'Player($name, color: ${color.shortName}, rank: $finishRank)';
}
