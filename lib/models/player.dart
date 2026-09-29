import 'package:flutter/material.dart';

import 'ludo_color.dart';
import 'token.dart';

class Player {
  final int id;
  final String name;
  final LudoColor color;
  final List<Token> tokens;
  final int? finishRank; // 1 for 1st, 2 for 2nd, etc. null if still active

  /// Team index for 2v2 mode (§E): Team A = Red + Yellow (0),
  /// Team B = Green + Blue (1). In Classic mode each player is their
  /// own team (teamId == id).
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

  /// Linking accent per team (§E): gold ring for A, ice-blue for B.
  static Color teamAccent(int teamId) => teamId == 0
      ? const Color(0xFFF2C14E)
      : const Color(0xFF4DD0E1);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color.index,
        'tokens': tokens.map((t) => t.toJson()).toList(),
        'finishRank': finishRank,
        'teamId': teamId,
      };

  factory Player.fromJson(Map<String, dynamic> json) {
    final colorIndex = json['color'] as int?;
    final color = (colorIndex != null &&
            colorIndex >= 0 &&
            colorIndex < LudoColor.values.length)
        ? LudoColor.values[colorIndex]
        : LudoColor.red;
    final rawTokens = json['tokens'] as List?;
    return Player(
      id: (json['id'] as int?) ?? 0,
      name: (json['name'] as String?) ?? 'Player',
      color: color,
      tokens: rawTokens
          ?.map((e) => Token.fromJson(
              (e as Map).cast<String, dynamic>(), color))
          .toList(),
      finishRank: json['finishRank'] as int?,
      teamId: (json['teamId'] as int?) ?? (json['id'] as int? ?? 0),
    );
  }

  @override
  String toString() => 'Player($name, color: ${color.shortName}, rank: $finishRank)';
}
