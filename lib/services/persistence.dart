import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/game_settings.dart';
import '../models/game_state.dart';

/// Local save/resume storage (§10): an interrupted game can be resumed,
/// settings survive restarts. Implemented against [SharedPreferences] in
/// production and swappable for tests.
abstract class GamePersistence {
  Future<void> saveGame(GameState state);
  Future<GameState?> loadGame();
  Future<void> clearGame();
  Future<void> saveSettings(GameSettings settings);
  Future<GameSettings?> loadSettings();
}

class SharedPrefsPersistence implements GamePersistence {
  static const String gameKey = 'ludu_save_v1';
  static const String settingsKey = 'ludu_settings_v1';

  const SharedPrefsPersistence();

  @override
  Future<void> saveGame(GameState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(gameKey, jsonEncode(state.toJson()));
  }

  @override
  Future<GameState?> loadGame() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(gameKey);
    if (raw == null) return null;
    try {
      return GameState.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // Corrupt or outdated save — drop it.
      await prefs.remove(gameKey);
      return null;
    }
  }

  @override
  Future<void> clearGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(gameKey);
  }

  @override
  Future<void> saveSettings(GameSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(settingsKey, jsonEncode(settings.toJson()));
  }

  @override
  Future<GameSettings?> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(settingsKey);
    if (raw == null) return null;
    try {
      return GameSettings.fromJson(
          jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await prefs.remove(settingsKey);
      return null;
    }
  }
}

/// In-memory implementation for unit/widget tests (no platform channels).
class MemoryPersistence implements GamePersistence {
  GameState? savedGame;
  GameSettings? savedSettings;

  @override
  Future<void> saveGame(GameState state) async {
    // Round-trip through JSON so tests also cover serialization.
    savedGame =
        GameState.fromJson(state.toJson());
  }

  @override
  Future<GameState?> loadGame() async => savedGame == null
      ? null
      : GameState.fromJson(savedGame!.toJson());

  @override
  Future<void> clearGame() async {
    savedGame = null;
  }

  @override
  Future<void> saveSettings(GameSettings settings) async {
    savedSettings = GameSettings.fromJson(settings.toJson());
  }

  @override
  Future<GameSettings?> loadSettings() async => savedSettings;
}
