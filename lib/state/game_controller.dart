import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/board_coordinates.dart';
import '../models/game_state.dart';
import '../models/ludo_color.dart';
import '../models/player.dart';
import '../models/token.dart';
import '../services/audio_service.dart';
import '../services/dice_service.dart';
import '../services/haptics_service.dart';

final diceServiceProvider = Provider<DiceService>((ref) => DiceService());

final gameControllerProvider =
    StateNotifierProvider<GameController, GameState>((ref) {
  final diceService = ref.watch(diceServiceProvider);
  return GameController(diceService: diceService);
});

class GameController extends StateNotifier<GameState> {
  final DiceService _diceService;

  GameController({DiceService? diceService})
      : _diceService = diceService ?? DiceService(),
        super(GameState(players: _createDefaultPlayers(4)));

  static List<Player> _createDefaultPlayers(int count) {
    const defaultColors = [
      LudoColor.red,
      LudoColor.green,
      LudoColor.yellow,
      LudoColor.blue,
    ];
    return List.generate(
      count.clamp(2, 4),
      (i) => Player(
        id: i,
        name: 'Player ${i + 1}',
        color: defaultColors[i],
      ),
    );
  }

  /// Starts a new game with [playerCount] and optional custom names/colors.
  /// When [teamMode] is true (4 players), slots 0&2 form Team A and slots
  /// 1&3 form Team B — partners sit opposite each other.
  void startNewGame({
    required int playerCount,
    List<String>? playerNames,
    List<LudoColor>? playerColors,
    bool teamMode = false,
  }) {
    final count = playerCount.clamp(2, 4);
    final teams = teamMode && count == 4;
    final colors = playerColors ??
        (count == 2
            ? [LudoColor.red, LudoColor.yellow] // Diagonally opposite for balanced 2-player
            : [
                LudoColor.red,
                LudoColor.green,
                LudoColor.yellow,
                LudoColor.blue,
              ].sublist(0, count));

    final players = List.generate(
      count,
      (i) => Player(
        id: i,
        name: (playerNames != null && i < playerNames.length && playerNames[i].trim().isNotEmpty)
            ? playerNames[i].trim()
            : 'Player ${i + 1}',
        color: colors[i],
        teamId: teams ? ((i == 0 || i == 2) ? 0 : 1) : i,
      ),
    );

    state = GameState(
      players: players,
      currentPlayerIndex: 0,
      phase: GamePhase.playing,
      teamMode: teams,
      statusMessage: teams
          ? '${players[0].name} (${Player.teamName(0)}) starts! Tap the dice.'
          : '${players[0].name}\'s turn. Tap the dice to roll!',
    );
  }

  /// Rolls the dice using cryptographically secure RNG.
  /// Enforces standard Ludo rules, legal move calculations, and the 3-sixes cancellation rule.
  int rollDice() {
    if (!state.canRollDice) return state.currentDiceRoll ?? 1;

    AudioService.playDiceRoll();
    final roll = _diceService.roll();
    if (roll == 6) {
      AudioService.playSix();
    }
    final player = state.currentPlayer;
    int newConsecutiveSixes = (roll == 6) ? state.consecutiveSixes + 1 : 0;
    int totalSixes = state.totalSixes + (roll == 6 ? 1 : 0);
    int totalTurns = state.totalTurns + 1;

    // Rule: If a player rolls three 6s in a row within the same turn,
    // cancel/forfeit the move and pass turn to next player immediately.
    if (newConsecutiveSixes >= 3) {
      state = state.copyWith(
        currentDiceRoll: roll,
        consecutiveSixes: 3,
        totalSixes: totalSixes,
        totalTurns: totalTurns,
        statusMessage: 'Three 6s in a row! Turn forfeited for ${player.name}!',
        movableTokenIds: const [],
      );

      // Advance turn immediately after 3rd six
      advanceToNextPlayer();
      return roll;
    }

    final movableTokens = getMovableTokenIds(player, roll);

    String message;
    if (movableTokens.isEmpty) {
      message = '${player.name} rolled a $roll. No legal moves.';
    } else if (roll == 6) {
      message = '${player.name} rolled a 6! Select a token to move.';
    } else {
      message = '${player.name} rolled a $roll. Select a token to move.';
    }

    state = state.copyWith(
      currentDiceRoll: roll,
      consecutiveSixes: newConsecutiveSixes,
      movableTokenIds: movableTokens,
      statusMessage: message,
      totalSixes: totalSixes,
      totalTurns: totalTurns,
    );

    // If no moves are possible, turn automatically passes
    if (movableTokens.isEmpty) {
      // If player rolled 6 but has no moves, does extra turn apply?
      // In standard Ludo, if a player cannot move with a 6, the turn passes
      // (or if they roll a 6 with no moves, some rules allow another roll,
      // but standard rule is: no legal move -> pass turn).
      advanceToNextPlayer();
    }

    return roll;
  }

  /// Determines which tokens of [player] can legally move with [roll].
  List<int> getMovableTokenIds(Player player, int roll) {
    final List<int> movable = [];
    for (final token in player.tokens) {
      if (token.isHome) continue;

      if (token.isInBase) {
        if (roll == 6) {
          movable.add(token.id);
        }
      } else {
        // Token is on outer track or home stretch
        final targetStep = token.step + roll;
        // Exact roll required to reach home (step 56)
        if (targetStep <= 56) {
          movable.add(token.id);
        }
      }
    }
    return movable;
  }

  /// Moves the token with [tokenId] for the current player.
  void moveToken(int tokenId) {
    if (!state.mustSelectToken || !state.movableTokenIds.contains(tokenId)) {
      return;
    }

    final player = state.currentPlayer;
    final token = player.tokens.firstWhere((t) => t.id == tokenId);
    final roll = state.currentDiceRoll!;

    // Save snapshot for potential undo
    final tokenSnapshot = token;
    final int playerIndexSnapshot = state.currentPlayerIndex;
    final List<Token> capturedSnapshots = [];

    final int newStep;
    if (token.isInBase) {
      newStep = 0; // Enter outer track
    } else {
      newStep = token.step + roll;
    }

    final updatedToken = token.copyWith(step: newStep);
    final updatedTokens = List<Token>.from(player.tokens);
    updatedTokens[token.id] = updatedToken;

    var updatedPlayer = player.copyWith(tokens: updatedTokens);
    final updatedPlayers = List<Player>.from(state.players);
    updatedPlayers[state.currentPlayerIndex] = updatedPlayer;

    int totalCaptures = state.totalCaptures;
    String status = '${player.name} moved token ${token.id + 1}.';
    bool didCapture = false;

    // Check for captures if landing on outer track (0..50)
    if (newStep >= 0 && newStep <= 50) {
      final landingGlobalIndex = (player.color.startSquare + newStep) % 52;

      // Safe squares cannot be captured
      if (!BoardCoordinates.isSafeSquare(landingGlobalIndex)) {
        for (int p = 0; p < updatedPlayers.length; p++) {
          if (p == state.currentPlayerIndex) continue;
          // Teammates are immune — partners stack safely (Team 2v2).
          if (state.teamMode &&
              updatedPlayers[p].teamId == player.teamId) {
            continue;
          }
          final opponent = updatedPlayers[p];
          final opponentTokens = List<Token>.from(opponent.tokens);
          bool opponentCaptured = false;

          for (int t = 0; t < opponentTokens.length; t++) {
            final opToken = opponentTokens[t];
            if (opToken.isOnOuterTrack && opToken.globalTrackIndex == landingGlobalIndex) {
              capturedSnapshots.add(opToken);
              opponentTokens[t] = opToken.copyWith(step: -1); // Send back to base
              opponentCaptured = true;
              totalCaptures++;
            }
          }

          if (opponentCaptured) {
            AudioService.playCapture();
            HapticsService.capture();
            updatedPlayers[p] = opponent.copyWith(tokens: opponentTokens);
            status = '⚔️ ${player.name} captured ${opponent.name}\'s token!';
            didCapture = true;
          }
        }
      }
    }

    // Check if token reached Home (center, step 56) — exact roll already enforced.
    final bool didReachHome = newStep == 56;
    if (didReachHome) {
      AudioService.playSafe();
      HapticsService.victory();
      status = '🎉 ${player.name}\'s token reached Home!';
    }

    // Winning: solo = first player with all 4 home; team = first team
    // with all 8 home.
    final List<Player> newFinishOrder = List.from(state.finishOrder);
    bool justFinished = false;
    if (state.teamMode) {
      final mates = updatedPlayers
          .where((p) => p.teamId == player.teamId)
          .toList();
      if (mates.every((m) => m.tokens.every((t) => t.isHome))) {
        for (final m in mates) {
          final idx = updatedPlayers.indexWhere((p) => p.id == m.id);
          final ranked = m.copyWith(finishRank: 1);
          updatedPlayers[idx] = ranked;
          newFinishOrder.add(ranked);
        }
        updatedPlayer = updatedPlayers[state.currentPlayerIndex];
        justFinished = true;
        status =
            '🏆 ${Player.teamName(player.teamId)} wins the game!';
      } else if (didReachHome) {
        // Teammate progress note (extra turn already granted below).
      }
    } else if (updatedPlayer.tokens.every((t) => t.isHome) &&
        updatedPlayer.finishRank == null) {
      const rank = 1;
      updatedPlayer = updatedPlayer.copyWith(finishRank: rank);
      updatedPlayers[state.currentPlayerIndex] = updatedPlayer;
      newFinishOrder.add(updatedPlayer);
      justFinished = true;
      status = '🏆 ${player.name} wins the game!';
    }

    final bool isOver = justFinished;
    if (isOver) {
      AudioService.playVictory();
      HapticsService.victory();
    }

    state = state.copyWith(
      players: updatedPlayers,
      finishOrder: newFinishOrder,
      phase: isOver ? GamePhase.finished : GamePhase.playing,
      totalCaptures: totalCaptures,
      statusMessage: isOver
          ? (state.teamMode
              ? '🏆 ${Player.teamName(player.teamId)} wins! All 8 tokens home.'
              : '🏆 ${player.name} wins! All 4 tokens home.')
          : status,
      clearDiceRoll: true,
      movableTokenIds: const [],
      lastMovedTokenSnapshot: tokenSnapshot,
      lastMovedPlayerIndex: playerIndexSnapshot,
      lastCapturedTokensSnapshot: capturedSnapshots,
    );

    if (isOver) return;

    // Turn continuation rules (§4): extra roll when —
    //  • roll is 6, OR
    //  • an opponent token was captured, OR
    //  • a token reached home (center).
    // consecutiveSixes chain is preserved across the extra turn; it is only
    // reset when the turn passes (see advanceToNextPlayer) or a non-6 is rolled
    // (see rollDice which recomputes the counter).
    final bool earnedExtraTurn =
        (roll == 6 || didCapture || didReachHome);
    if (earnedExtraTurn) {
      final reason = roll == 6
          ? 'Rolled a 6! Roll again.'
          : didCapture
              ? 'Capture bonus! Roll again.'
              : 'Home bonus! Roll again.';
      state = state.copyWith(
        statusMessage: '$status $reason',
      );
    } else {
      // Advance to next active player
      advanceToNextPlayer();
    }
  }

  /// Cancels and reverts whatever move was made on the 3rd six, then passes the turn.
  void undoThirdSixMove() {
    if (state.lastMovedTokenSnapshot == null || state.lastMovedPlayerIndex == null) {
      return;
    }

    final pIdx = state.lastMovedPlayerIndex!;
    final token = state.lastMovedTokenSnapshot!;
    final updatedPlayers = List<Player>.from(state.players);

    // Revert moved token
    final player = updatedPlayers[pIdx];
    final updatedTokens = List<Token>.from(player.tokens);
    updatedTokens[token.id] = token;
    updatedPlayers[pIdx] = player.copyWith(tokens: updatedTokens);

    // Restore captured tokens if any
    if (state.lastCapturedTokensSnapshot != null) {
      for (final capToken in state.lastCapturedTokensSnapshot!) {
        final ownerIdx = updatedPlayers.indexWhere((p) => p.color == capToken.color);
        if (ownerIdx != -1) {
          final op = updatedPlayers[ownerIdx];
          final opTokens = List<Token>.from(op.tokens);
          opTokens[capToken.id] = capToken;
          updatedPlayers[ownerIdx] = op.copyWith(tokens: opTokens);
        }
      }
    }

    state = state.copyWith(
      players: updatedPlayers,
      consecutiveSixes: 0,
      clearDiceRoll: true,
      movableTokenIds: const [],
      clearSnapshot: true,
      statusMessage: 'Third consecutive 6 cancelled! Move reverted and turn passed.',
    );

    advanceToNextPlayer();
  }

  /// Advances turn to the next player who has not finished yet.
  void advanceToNextPlayer() {
    if (state.phase == GamePhase.finished) return;

    final activePlayers = state.players.where((p) => p.finishRank == null).toList();
    if (activePlayers.isEmpty) {
      state = state.copyWith(phase: GamePhase.finished);
      return;
    }

    int nextIndex = (state.currentPlayerIndex + 1) % state.players.length;
    while (state.players[nextIndex].finishRank != null) {
      nextIndex = (nextIndex + 1) % state.players.length;
    }

    final nextPlayer = state.players[nextIndex];
    state = state.copyWith(
      currentPlayerIndex: nextIndex,
      consecutiveSixes: 0,
      clearDiceRoll: true,
      movableTokenIds: const [],
      statusMessage: '${nextPlayer.name}\'s turn. Tap the dice to roll!',
    );
  }
}
