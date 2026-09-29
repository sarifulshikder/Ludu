import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_settings.dart';
import '../services/audio_service.dart';
import '../services/haptics_service.dart';
import '../services/persistence.dart';

final persistenceProvider =
    Provider<GamePersistence>((ref) => const SharedPrefsPersistence());

/// App-wide settings (§9–§10), persisted locally and applied to the
/// sound/vibration backends. The game engine reads them live.
final settingsControllerProvider =
    StateNotifierProvider<SettingsController, GameSettings>((ref) {
  final persistence = ref.watch(persistenceProvider);
  return SettingsController(persistence);
});

class SettingsController extends StateNotifier<GameSettings> {
  final GamePersistence _persistence;

  SettingsController(this._persistence)
      : super(const GameSettings()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final saved = await _persistence.loadSettings();
      if (saved != null) {
        state = saved;
        _applyToBackends(saved);
      }
    } catch (_) {
      // Defaults stand.
    }
  }

  Future<void> update(GameSettings next) async {
    state = next;
    _applyToBackends(next);
    try {
      await _persistence.saveSettings(next);
    } catch (_) {
      // Settings must never break gameplay.
    }
  }

  void _applyToBackends(GameSettings s) {
    AudioService.setMuted(!s.sound);
    HapticsService.setEnabled(s.vibration);
  }
}
