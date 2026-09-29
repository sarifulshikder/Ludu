import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/board_coordinates.dart';
import '../models/game_settings.dart';
import '../models/game_state.dart';
import '../models/ludo_color.dart';
import '../models/player.dart';
import '../models/token.dart';
import '../services/audio_service.dart';
import '../services/dice_service.dart';
import '../services/haptics_service.dart';
import '../services/persistence.dart';
import 'settings_controller.dart';

final diceServiceProvider = Provider<DiceService>((ref) => DiceService());

final gameControllerProvider =
    StateNotifierProvider<GameController, GameState>((ref) {
  final diceService = ref.watch(diceServiceProvider);
  final persistence = ref.watch(persistenceProvider);
  // Live settings: the engine always enforces the current UI settings
  // (block rule, end-at-first-winner) at action time.
  return GameController(
    diceService: diceService,
    persistence: persistence,
    settingsReader: () => ref.read(settingsControllerProvider),
  );
});

/// Standard Ludo engine (§1–§7), fully UI-independent and unit-tested.
///
/// Step model: -1 = base, 0..50 = outer track (50 moves after entering),
/// 51..55 = own home column (capture-free), 56 = center. Entering the
/// board costs a 6 and lands on the color's own (safe) start square.
class GameController extends StateNotifier<GameState> {
  final DiceService _diceService;
  final GamePersistence _persistence;
  final GameSettings Function()? _settingsReader;
  GameSettings _localSettings = const GameSettings();

  GameController({
    DiceService? diceService,
    GamePersistence? persistence,
    GameSettings? settings,
    this._settingsReader,
  })  : _diceService = diceService ?? DiceService(),
        _persistence = persistence ?? const SharedPrefsPersistence(),
        super(GameState(players: _createDefaultPlayers(4))) {
    if (settings != null) _localSettings = settings;
  }

  /// Settings currently enforced by the engine.
  GameSettings get settings => _settingsReader?.call() ?? _localSettings;

  /// Direct settings override (used in tests; the app reads live settings).
  /// Recomputes pending movables so a mid-turn rule change stays legal.
  set settings(GameSettings value) => setSettings(value);

  void setSettings(GameSettings value) {
    _localSettings = value;
    if (state.phase == GamePhase.playing && state.currentDiceRoll != null) {
      final movables =
          getMovableTokenIds(state.currentPlayer, state.currentDiceRoll!);
      state = state.copyWith(movableTokenIds: movables);
    }
  }

  static List<Player> _createDefaultPlayers(int count) {
    // Seats double as turn order — clockwise: Red, Green, Yellow, Blue.
    // P1 Red top-left, P2 Green top-right, P3 Yellow bottom-right,
    // P4 Blue bottom-left.
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

  /// Default seat colors: 2 players sit opposite (Red vs Yellow),
  /// 3 players take Red/Green/Yellow, 4 play clockwise Red/Green/Yellow/Blue.
  /// P3 is Yellow (bottom-right), P4 is Blue (bottom-left).
  static List<LudoColor> defaultColorsFor(int count) {
    if (count == 2) return [LudoColor.red, LudoColor.yellow];
    if (count == 3) {
      return [LudoColor.red, LudoColor.green, LudoColor.yellow];
    }
    return const [
      LudoColor.red,
      LudoColor.green,
      LudoColor.yellow,
      LudoColor.blue,
    ];
  }

  /// Starts a new game. The first player is chosen randomly (§1) unless
  /// [firstPlayerIndex] is given (deterministic tests / rematch fairness).
  /// When [teamMode] is true (exactly 4 players), Red + Yellow form Team A
  /// and Green + Blue form Team B — opposite seats, alternating turns (§E).
  void startNewGame({
    required int playerCount,
    List<String>? playerNames,
    List<LudoColor>? playerColors,
    int? firstPlayerIndex,
    bool teamMode = false,
  }) {
    final count = playerCount.clamp(2, 4);
    final teams = teamMode && count == 4;
    final colors = playerColors ?? defaultColorsFor(count);

    final players = List.generate(
      count,
      (i) => Player(
        id: i,
        name: (playerNames != null &&
                i < playerNames.length &&
                playerNames[i].trim().isNotEmpty)
            ? playerNames[i].trim()
            : 'Player ${i + 1}',
        color: colors[i],
        teamId: teams ? ((i == 0 || i == 2) ? 0 : 1) : i,
      ),
    );

    final first = firstPlayerIndex != null
        ? firstPlayerIndex % count
        : Random.secure().nextInt(count);
    state = GameState(
      players: players,
      currentPlayerIndex: first,
      phase: GamePhase.playing,
      teamMode: teams,
      statusMessage: teams
          ? '${players[first].name} (${Player.teamName(players[first].teamId)}) starts! Tap the dice.'
          : '${players[first].name} starts! Tap the dice.',
    );
    _persist();
  }

  /// Restores a previously saved game (§10).
  void restore(GameState saved) {
    state = saved;
  }

  /// Rolls the dice using cryptographically secure RNG (§2).
  /// Extra taps while a roll is pending are ignored: [canRollDice] is false
  /// until the move (or auto-pass) resolves.
  int rollDice() {
    if (!state.canRollDice) return state.currentDiceRoll ?? 1;

    AudioService.playDiceRoll();
    final roll = _diceService.roll();
    if (roll == 6) {
      AudioService.playSix();
    }
    final player = state.currentPlayer;
    final int newConsecutiveSixes =
        (roll == 6) ? state.consecutiveSixes + 1 : 0;
    final int totalSixes = state.totalSixes + (roll == 6 ? 1 : 0);
    final int totalTurns = state.totalTurns + 1;

    final lastRolls = List<int?>.from(state.lastRolls);
    if (state.currentPlayerIndex < lastRolls.length) {
      lastRolls[state.currentPlayerIndex] = roll;
    }

    // §5: three consecutive 6s in one turn — the third 6 is voided, no move
    // is made (moves from the first two 6s stay), turn passes immediately.
    if (newConsecutiveSixes >= 3) {
      state = state.copyWith(
        currentDiceRoll: roll,
        consecutiveSixes: 3,
        totalSixes: totalSixes,
        totalTurns: totalTurns,
        statusMessage:
            'Three 6s in a row! Roll voided for ${player.name}.',
        movableTokenIds: const [],
        lastRolls: lastRolls,
        clearLastMove: true,
      );
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
      lastRolls: lastRolls,
      clearLastMove: true,
    );

    // §4: no legal move — the turn passes automatically (the UI adds a
    // short beat before enabling the next dice). A 6 with no legal move
    // earns no bonus: no move was actually made (§5).
    if (movableTokens.isEmpty) {
      AudioService.playNoMove();
      advanceToNextPlayer();
    } else {
      _persist();
    }

    return roll;
  }

  /// Resolves whose tokens the current roller actually moves. In Team 2v2,
  /// a player who already brought all 4 home keeps rolling and moves
  /// their teammate's tokens with those rolls (§E, "helping teammate").
  Player _actingOwner(Player roller) {
    final current = state.players.firstWhere(
      (p) => p.id == roller.id,
      orElse: () => roller,
    );
    if (state.teamMode && current.hasFinished) {
      return state.players.firstWhere(
        (p) => p.teamId == current.teamId && p.id != current.id,
      );
    }
    return current;
  }

  /// Determines which tokens of [player] can legally move with [roll].
  ///
  /// * Base exit needs a 6 (lands on the own, always-safe start square).
  /// * Reaching the center needs the exact number — no overshoot.
  /// * Landing on an opponent stack (2+ same-color tokens on a non-safe
  ///   square) is illegal with the Block rule ON — and always in Team 2v2
  ///   (§E). Teammate tokens never block each other.
  List<int> getMovableTokenIds(Player player, int roll) {
    final owner = _actingOwner(player);
    final ownerIdx = state.players.indexWhere((p) => p.id == owner.id);
    final blocks = (settings.blockRule || state.teamMode)
        ? _opponentBlockSquares(ownerIdx)
        : const <int>{};

    final List<int> movable = [];
    for (final token in owner.tokens) {
      if (token.isHome) continue;

      if (token.isInBase) {
        if (roll == 6) movable.add(token.id);
      } else {
        final targetStep = token.step + roll;
        if (targetStep > 56) continue; // exact roll required
        if (targetStep <= 50 && blocks.isNotEmpty) {
          final landing =
              (owner.color.startSquare + targetStep) % 52;
          if (!BoardCoordinates.isSafeSquare(landing) &&
              blocks.contains(landing)) {
            continue; // blocked square — cannot land (§6, §E)
          }
        }
        movable.add(token.id);
      }
    }
    return movable;
  }

  /// Global track squares holding 2+ tokens of one opponent color on a
  /// non-safe square. Teammates are never opponents (§E).
  Set<int> _opponentBlockSquares(int ownerIdx) {
    final ownerTeam = state.players[ownerIdx].teamId;
    final Map<int, Map<int, int>> counts = {};
    for (int p = 0; p < state.players.length; p++) {
      if (p == ownerIdx) continue;
      if (state.teamMode &&
          state.players[p].teamId == ownerTeam) {
        continue; // teammates share freely, never block
      }
      for (final token in state.players[p].tokens) {
        if (!token.isOnOuterTrack) continue;
        final g = token.globalTrackIndex!;
        if (BoardCoordinates.isSafeSquare(g)) continue;
        counts.putIfAbsent(p, () => {})[g] =
            (counts[p]![g] ?? 0) + 1;
      }
    }
    final blocks = <int>{};
    for (final perPlayer in counts.values) {
      perPlayer.forEach((square, count) {
        if (count >= 2) blocks.add(square);
      });
    }
    return blocks;
  }

  /// Moves [tokenId] for the current player. There is no undo (§4) and no
  /// voluntary passing: with at least one legal move the player must move.
  /// In Team 2v2 a finished player moves their teammate's tokens (§E).
  void moveToken(int tokenId) {
    if (!state.mustSelectToken ||
        !state.movableTokenIds.contains(tokenId)) {
      return;
    }

    final player = state.currentPlayer;
    final owner = _actingOwner(player);
    final ownerIdx = state.players.indexWhere((p) => p.id == owner.id);
    final helping = ownerIdx != state.currentPlayerIndex;
    final token = owner.tokens.firstWhere((t) => t.id == tokenId);
    final roll = state.currentDiceRoll!;
    final fromStep = token.step;

    final int newStep = token.isInBase ? 0 : token.step + roll;

    final updatedToken = token.copyWith(step: newStep);
    final updatedTokens = List<Token>.from(owner.tokens);
    updatedTokens[token.id] = updatedToken;

    var updatedOwner = owner.copyWith(tokens: updatedTokens);
    final updatedPlayers = List<Player>.from(state.players);
    updatedPlayers[ownerIdx] = updatedOwner;

    int totalCaptures = state.totalCaptures;
    String status = helping
        ? '${player.name} moved ${owner.name}\u2019s token ${token.id + 1}.'
        : '${player.name} moved token ${token.id + 1}.';
    bool didCapture = false;

    // §6/§E: only the exact landing square captures; passing over is safe.
    // Base, home column and safe squares can never be captured, and
    // teammates never capture each other.
    if (newStep >= 0 && newStep <= 50) {
      final landingGlobalIndex =
          (owner.color.startSquare + newStep) % 52;

      if (!BoardCoordinates.isSafeSquare(landingGlobalIndex)) {
        for (int p = 0; p < updatedPlayers.length; p++) {
          if (p == ownerIdx) continue;
          if (state.teamMode &&
              updatedPlayers[p].teamId == owner.teamId) {
            continue;
          }
          final opponent = updatedPlayers[p];
          final opponentTokens = List<Token>.from(opponent.tokens);
          bool opponentCaptured = false;

          for (int t = 0; t < opponentTokens.length; t++) {
            final opToken = opponentTokens[t];
            if (opToken.isOnOuterTrack &&
                opToken.globalTrackIndex == landingGlobalIndex) {
              opponentTokens[t] =
                  opToken.copyWith(step: -1); // back to base
              opponentCaptured = true;
              totalCaptures++;
            }
          }

          if (opponentCaptured) {
            AudioService.playCapture();
            HapticsService.capture();
            updatedPlayers[p] =
                opponent.copyWith(tokens: opponentTokens);
            status =
                '⚔️ ${player.name} captured ${opponent.name}\u2019s token!';
            didCapture = true;
          }
        }
      }
    }

    final bool didReachHome = newStep == 56;
    if (didReachHome) {
      AudioService.playSafe();
      HapticsService.victory();
      status = '🎉 ${owner.name}\u2019s token reached the center!';
    }

    // §7/§E: Classic — the moment all 4 tokens reach the center the player
    // takes the next rank (the game continues unless end-at-first-winner).
    // Team 2v2 — the team wins when all 8 tokens are home.
    final List<Player> newFinishOrder = List.from(state.finishOrder);
    bool isOver = false;
    bool justFinished = false;
    if (state.teamMode) {
      final mates = updatedPlayers
          .where((p) => p.teamId == player.teamId)
          .toList();
      if (mates.every((m) => m.tokens.every((t) => t.isHome))) {
        final rank = newFinishOrder.length + 1;
        for (final m in mates) {
          final idx = updatedPlayers.indexWhere((p) => p.id == m.id);
          final ranked = m.copyWith(finishRank: rank);
          updatedPlayers[idx] = ranked;
          newFinishOrder.add(ranked);
        }
        updatedOwner = updatedPlayers[ownerIdx];
        justFinished = true;
        isOver = true;
        status =
            '🏆 ${Player.teamName(player.teamId)} wins the game!';
      }
    } else if (updatedOwner.hasFinished &&
        updatedOwner.finishRank == null) {
      final rank = newFinishOrder.length + 1;
      updatedOwner = updatedOwner.copyWith(finishRank: rank);
      updatedPlayers[ownerIdx] = updatedOwner;
      newFinishOrder.add(updatedOwner);
      justFinished = true;
      status = '🏆 ${player.name} finished ${_ordinal(rank)}!';
      if (settings.endAtFirstWinner) {
        isOver = true;
      } else {
        final activeLeft =
            updatedPlayers.where((p) => p.finishRank == null).toList();
        if (activeLeft.length <= 1) {
          if (activeLeft.length == 1) {
            final last = activeLeft.first;
            final lastRanked =
                last.copyWith(finishRank: rank + 1);
            updatedPlayers[updatedPlayers
                .indexWhere((p) => p.id == last.id)] = lastRanked;
            newFinishOrder.add(lastRanked);
          }
          isOver = true;
        }
      }
    }

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
              : status)
          : status,
      clearDiceRoll: true,
      movableTokenIds: const [],
      lastMoveColor: owner.color.index,
      lastMoveToken: tokenId,
      lastMoveFrom: fromStep,
      lastMoveTo: newStep,
    );

    if (isOver) {
      _persist(); // finished games clear the resume save
      return;
    }

    // §5: an extra roll is earned only by a move actually made with a 6,
    // by capturing, or by bringing a token into the center. Bonuses chain.
    // A player who just finished takes no bonus — the turn moves on.
    // consecutiveSixes survives across the extra turn and resets when the
    // turn passes or a non-6 is rolled.
    final bool earnedExtraTurn = !justFinished &&
        (roll == 6 || didCapture || didReachHome);
    if (earnedExtraTurn) {
      final reason = roll == 6
          ? 'Rolled a 6! Roll again.'
          : didCapture
              ? 'Capture bonus! Roll again.'
              : 'Center bonus! Roll again.';
      state = state.copyWith(
        statusMessage: '$status $reason',
      );
      _persist();
    } else {
      advanceToNextPlayer();
    }
  }

  /// Advances to the next player who has not finished yet (§7).
  void advanceToNextPlayer() {
    if (state.phase == GamePhase.finished) return;

    final hasActive =
        state.players.any((p) => p.finishRank == null);
    if (!hasActive) {
      state = state.copyWith(phase: GamePhase.finished);
      _persist();
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
      statusMessage: '${nextPlayer.name}\u2019s turn. Tap the dice to roll!',
    );
    _persist();
  }

  void _persist() {
    try {
      if (state.phase == GamePhase.finished) {
        _persistence.clearGame().then((_) {}, onError: (_) {});
      } else {
        _persistence.saveGame(state).then((_) {}, onError: (_) {});
      }
    } catch (_) {
      // Storage must never break gameplay.
    }
  }

  static String _ordinal(int n) {
    if (n == 1) return '1st';
    if (n == 2) return '2nd';
    if (n == 3) return '3rd';
    return '${n}th';
  }
}
