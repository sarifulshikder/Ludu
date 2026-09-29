import 'player.dart';

enum GamePhase {
  setup,
  playing,
  finished,
}

class GameState {
  final List<Player> players;
  final int currentPlayerIndex;
  final int? currentDiceRoll;
  final int consecutiveSixes;
  final List<int> movableTokenIds;
  final String statusMessage;
  final List<Player> finishOrder; // 1st, 2nd, 3rd, 4th
  final GamePhase phase;
  final int totalTurns;
  final int totalSixes;
  final int totalCaptures;

  /// When true, 4-player 2v2 team rules apply (§E).
  final bool teamMode;

  /// Last rolled value per player (index-aligned). Null until that player
  /// has rolled for the first time — panels show a neutral face meanwhile.
  final List<int?> lastRolls;

  /// Last committed move, for the follow-the-action highlight (§F).
  /// Null color/token means no highlight.
  final int? lastMoveColor;
  final int? lastMoveToken;
  final int? lastMoveFrom;
  final int? lastMoveTo;

  GameState({
    required this.players,
    this.currentPlayerIndex = 0,
    this.currentDiceRoll,
    this.consecutiveSixes = 0,
    this.movableTokenIds = const [],
    this.statusMessage = 'Tap the dice to roll!',
    this.finishOrder = const [],
    this.phase = GamePhase.setup,
    this.totalTurns = 0,
    this.totalSixes = 0,
    this.totalCaptures = 0,
    this.teamMode = false,
    List<int?>? lastRolls,
    this.lastMoveColor,
    this.lastMoveToken,
    this.lastMoveFrom,
    this.lastMoveTo,
  }) : lastRolls = lastRolls ?? List<int?>.filled(players.length, null);

  Player get currentPlayer => players[currentPlayerIndex];

  bool get isGameOver => phase == GamePhase.finished;

  bool get canRollDice =>
      phase == GamePhase.playing && currentDiceRoll == null;

  bool get mustSelectToken =>
      phase == GamePhase.playing &&
      currentDiceRoll != null &&
      movableTokenIds.isNotEmpty;

  GameState copyWith({
    List<Player>? players,
    int? currentPlayerIndex,
    int? currentDiceRoll,
    bool clearDiceRoll = false,
    int? consecutiveSixes,
    List<int>? movableTokenIds,
    String? statusMessage,
    List<Player>? finishOrder,
    GamePhase? phase,
    int? totalTurns,
    int? totalSixes,
    int? totalCaptures,
    bool? teamMode,
    List<int?>? lastRolls,
    int? lastMoveColor,
    int? lastMoveToken,
    int? lastMoveFrom,
    int? lastMoveTo,
    bool clearLastMove = false,
  }) {
    return GameState(
      players: players ?? this.players,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      currentDiceRoll:
          clearDiceRoll ? null : (currentDiceRoll ?? this.currentDiceRoll),
      consecutiveSixes: consecutiveSixes ?? this.consecutiveSixes,
      movableTokenIds: movableTokenIds ?? this.movableTokenIds,
      statusMessage: statusMessage ?? this.statusMessage,
      finishOrder: finishOrder ?? this.finishOrder,
      phase: phase ?? this.phase,
      totalTurns: totalTurns ?? this.totalTurns,
      totalSixes: totalSixes ?? this.totalSixes,
      totalCaptures: totalCaptures ?? this.totalCaptures,
      teamMode: teamMode ?? this.teamMode,
      lastRolls: lastRolls ?? this.lastRolls,
      lastMoveColor:
          clearLastMove ? null : (lastMoveColor ?? this.lastMoveColor),
      lastMoveToken:
          clearLastMove ? null : (lastMoveToken ?? this.lastMoveToken),
      lastMoveFrom:
          clearLastMove ? null : (lastMoveFrom ?? this.lastMoveFrom),
      lastMoveTo: clearLastMove ? null : (lastMoveTo ?? this.lastMoveTo),
    );
  }

  Map<String, dynamic> toJson() => {
        'v': 2,
        'players': players.map((p) => p.toJson()).toList(),
        'currentPlayerIndex': currentPlayerIndex,
        'currentDiceRoll': currentDiceRoll,
        'consecutiveSixes': consecutiveSixes,
        'movableTokenIds': movableTokenIds,
        'statusMessage': statusMessage,
        'phase': phase.index,
        'totalTurns': totalTurns,
        'totalSixes': totalSixes,
        'totalCaptures': totalCaptures,
        'teamMode': teamMode,
        'lastRolls': lastRolls,
        'lastMoveColor': lastMoveColor,
        'lastMoveToken': lastMoveToken,
        'lastMoveFrom': lastMoveFrom,
        'lastMoveTo': lastMoveTo,
      };

  factory GameState.fromJson(Map<String, dynamic> json) {
    final rawPlayers = json['players'] as List?;
    if (rawPlayers == null || rawPlayers.isEmpty) {
      throw const FormatException('Missing players in save');
    }
    final players = rawPlayers
        .map((e) => Player.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    final phaseIndex = json['phase'] as int?;
    final movable = json['movableTokenIds'] as List?;
    final rawRolls = json['lastRolls'] as List?;
    // Rebuild finish order from ranks (1st, 2nd, ...).
    final ranked = players.where((p) => p.finishRank != null).toList()
      ..sort((a, b) => a.finishRank!.compareTo(b.finishRank!));
    return GameState(
      players: players,
      currentPlayerIndex:
          (json['currentPlayerIndex'] as int? ?? 0) % players.length,
      currentDiceRoll: json['currentDiceRoll'] as int?,
      consecutiveSixes: (json['consecutiveSixes'] as int? ?? 0).clamp(0, 2),
      movableTokenIds:
          movable == null ? const [] : movable.cast<int>().toList(),
      statusMessage:
          (json['statusMessage'] as String?) ?? 'Tap the dice to roll!',
      finishOrder: ranked,
      phase: (phaseIndex != null &&
              phaseIndex >= 0 &&
              phaseIndex < GamePhase.values.length)
          ? GamePhase.values[phaseIndex]
          : GamePhase.playing,
      totalTurns: (json['totalTurns'] as int?) ?? 0,
      totalSixes: (json['totalSixes'] as int?) ?? 0,
      totalCaptures: (json['totalCaptures'] as int?) ?? 0,
      teamMode: json['teamMode'] as bool? ?? false,
      lastRolls: rawRolls == null
          ? null
          : List<int?>.generate(
              players.length,
              (i) => i < rawRolls.length
                  ? (rawRolls[i] as int?)
                  : null,
            ),
      lastMoveColor: json['lastMoveColor'] as int?,
      lastMoveToken: json['lastMoveToken'] as int?,
      lastMoveFrom: json['lastMoveFrom'] as int?,
      lastMoveTo: json['lastMoveTo'] as int?,
    );
  }
}
