import 'player.dart';
import 'token.dart';

enum GamePhase {
  setup,
  playing,
  finished,
}

class GameState {
  final List<Player> players;
  final int currentPlayerIndex;
  final int? currentDiceRoll;
  final bool isRolling;
  final bool isMovingToken;
  final int consecutiveSixes;
  final List<int> movableTokenIds;
  final String statusMessage;
  final List<Player> finishOrder; // 1st, 2nd, 3rd, 4th
  final GamePhase phase;
  final int totalTurns;
  final int totalSixes;
  final int totalCaptures;
  /// When true, 4-player Team 2v2 rules apply: teammates can't capture each
  /// other and the first team with all 8 tokens home wins.
  final bool teamMode;

  // Snapshot to allow undoing third 6 if needed
  final Token? lastMovedTokenSnapshot;
  final int? lastMovedPlayerIndex;
  final List<Token>? lastCapturedTokensSnapshot;

  const GameState({
    required this.players,
    this.currentPlayerIndex = 0,
    this.currentDiceRoll,
    this.isRolling = false,
    this.isMovingToken = false,
    this.consecutiveSixes = 0,
    this.movableTokenIds = const [],
    this.statusMessage = 'Tap the dice to roll!',
    this.finishOrder = const [],
    this.phase = GamePhase.setup,
    this.totalTurns = 0,
    this.totalSixes = 0,
    this.totalCaptures = 0,
    this.teamMode = false,
    this.lastMovedTokenSnapshot,
    this.lastMovedPlayerIndex,
    this.lastCapturedTokensSnapshot,
  });

  Player get currentPlayer => players[currentPlayerIndex];

  bool get isGameOver => phase == GamePhase.finished;

  bool get canRollDice =>
      phase == GamePhase.playing &&
      !isRolling &&
      !isMovingToken &&
      currentDiceRoll == null;

  bool get mustSelectToken =>
      phase == GamePhase.playing &&
      !isRolling &&
      !isMovingToken &&
      currentDiceRoll != null &&
      movableTokenIds.isNotEmpty;

  GameState copyWith({
    List<Player>? players,
    int? currentPlayerIndex,
    int? currentDiceRoll,
    bool clearDiceRoll = false,
    bool? isRolling,
    bool? isMovingToken,
    int? consecutiveSixes,
    List<int>? movableTokenIds,
    String? statusMessage,
    List<Player>? finishOrder,
    GamePhase? phase,
    int? totalTurns,
    int? totalSixes,
    int? totalCaptures,
    bool? teamMode,
    Token? lastMovedTokenSnapshot,
    bool clearSnapshot = false,
    int? lastMovedPlayerIndex,
    List<Token>? lastCapturedTokensSnapshot,
  }) {
    return GameState(
      players: players ?? this.players,
      currentPlayerIndex: currentPlayerIndex ?? this.currentPlayerIndex,
      currentDiceRoll: clearDiceRoll ? null : (currentDiceRoll ?? this.currentDiceRoll),
      isRolling: isRolling ?? this.isRolling,
      isMovingToken: isMovingToken ?? this.isMovingToken,
      consecutiveSixes: consecutiveSixes ?? this.consecutiveSixes,
      movableTokenIds: movableTokenIds ?? this.movableTokenIds,
      statusMessage: statusMessage ?? this.statusMessage,
      finishOrder: finishOrder ?? this.finishOrder,
      phase: phase ?? this.phase,
      totalTurns: totalTurns ?? this.totalTurns,
      totalSixes: totalSixes ?? this.totalSixes,
      totalCaptures: totalCaptures ?? this.totalCaptures,
      teamMode: teamMode ?? this.teamMode,
      lastMovedTokenSnapshot: clearSnapshot ? null : (lastMovedTokenSnapshot ?? this.lastMovedTokenSnapshot),
      lastMovedPlayerIndex: clearSnapshot ? null : (lastMovedPlayerIndex ?? this.lastMovedPlayerIndex),
      lastCapturedTokensSnapshot: clearSnapshot ? null : (lastCapturedTokensSnapshot ?? this.lastCapturedTokensSnapshot),
    );
  }
}
