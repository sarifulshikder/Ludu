import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

/// Central sound-effect manager for the game.
///
/// Design notes:
/// * Every sound owns a dedicated [AudioPlayer]. Sharing one player and calling
///   `stop()` before each `play()` cancels the previous sample almost instantly,
///   which is why rapid effects (the per-step token hop fires every ~100ms)
///   were inaudible.
/// * Players run in [PlayerMode.lowLatency], which maps to Android's SoundPool.
///   SoundPool is built for short samples: it decodes ahead of time and plays
///   without the async prepare cycle that made MediaPlayer drop the first
///   milliseconds of every effect.
/// * Players are created and warmed up eagerly in [init] so the very first dice
///   roll does not race player construction.
class AudioService {
  AudioService._();

  static bool isMuted = false;
  static bool _initialized = false;
  static bool _available = false;

  /// Last error surfaced by a play call. Useful for diagnosing silent audio.
  static String? lastError;

  static final Map<String, AudioPlayer> _players = <String, AudioPlayer>{};

  static const Map<String, double> _assets = <String, double>{
    'audio/dice_roll.wav': 0.85,
    'audio/token_step.wav': 0.55,
    'audio/token_out.wav': 0.85,
    'audio/capture.wav': 1.0,
    'audio/six.wav': 0.9,
    'audio/safe.wav': 0.8,
    'audio/victory.wav': 1.0,
  };

  /// Whether the platform audio backend came up successfully.
  static bool get isAvailable => _available;

  /// Warms up the audio backend. Safe to call more than once and safe to call
  /// from pure Dart unit tests (it degrades to a no-op without Flutter bindings).
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Guard against headless unit tests that have no Flutter binding:
    // touching WidgetsBinding.instance throws when it was never initialised.
    try {
      WidgetsBinding.instance;
    } catch (_) {
      return;
    }

    for (final asset in _assets.keys) {
      try {
        final player = AudioPlayer(playerId: 'ludu_$asset');
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setVolume(isMuted ? 0.0 : _assets[asset]!);
        _players[asset] = player;
        _available = true;
      } catch (e) {
        lastError = 'init $asset: $e';
        debugPrint('AudioService: failed to prepare $asset -> $e');
      }
    }
  }

  static Future<void> toggleMute() async {
    isMuted = !isMuted;
    await _applyMute();
  }

  static Future<void> setMuted(bool muted) async {
    if (isMuted == muted) return;
    isMuted = muted;
    await _applyMute();
  }

  static Future<void> _applyMute() async {
    for (final entry in _players.entries) {
      try {
        await entry.value.setVolume(isMuted ? 0.0 : _assets[entry.key]!);
      } catch (e) {
        debugPrint('AudioService: mute update failed for ${entry.key} -> $e');
      }
    }
  }

  static Future<void> playDiceRoll() => _play('audio/dice_roll.wav');
  static Future<void> playTokenStep() => _play('audio/token_step.wav');
  static Future<void> playTokenOut() => _play('audio/token_out.wav');
  static Future<void> playCapture() => _play('audio/capture.wav');
  static Future<void> playSix() => _play('audio/six.wav');
  static Future<void> playSafe() => _play('audio/safe.wav');
  static Future<void> playVictory() => _play('audio/victory.wav');

  static Future<void> _play(String asset) async {
    if (isMuted) return;
    final player = _players[asset];
    if (player == null) {
      // Not warmed up yet (or audio unavailable) - try to warm up in background.
      if (!_initialized) unawaited(init());
      return;
    }
    try {
      await player.stop();
      await player.play(
        AssetSource(asset),
        volume: _assets[asset]!,
      );
    } catch (e) {
      lastError = 'play $asset: $e';
      debugPrint('AudioService: play failed for $asset -> $e');
    }
  }

  /// Releases every underlying player. Called on app teardown / hot restart.
  static Future<void> dispose() async {
    for (final player in _players.values) {
      try {
        await player.dispose();
      } catch (_) {
        // Ignore disposal errors.
      }
    }
    _players.clear();
    _available = false;
    _initialized = false;
  }
}
