import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

import '../core/env.dart';
import '../models/game_settings.dart';

/// Central sound-effect manager for the game.
///
/// Premium pass (§C):
/// * Real recorded-style samples (CC0, see assets/audio/LICENSE_NOTE.md):
///   soft wooden/ceramic tocks, dice rattle on wood, pops, chimes, fanfare.
///   No beeps or 8-bit tones.
/// * 3 sound packs: Wood (default), Glass, Minimal. Pack switches resolve
///   to `assets/audio/`, `assets/audio/glass/`, `assets/audio/minimal/`.
/// * Low-latency playback: every cue owns a dedicated [AudioPlayer] in
///   [PlayerMode.lowLatency] (Android SoundPool), warmed up in [init].
/// * Loudness: samples peak at -12 dBFS with fade tails; per-cue gains
///   below only attenuate. Volumes never exceed 1.0 (no clipping).
/// * Pile-up guard: the same cue re-triggered within [_minGap] is ignored,
///   and at most [_maxSimultaneous] cues overlap — extras are dropped.
/// * Token steps stay in sync with hop animations: [playTokenStep] accepts
///   the step index/count and applies a gentle pitch rise across the move
///   plus slight random variation via [AudioPlayer.setPlaybackRate].
class AudioService {
  AudioService._();

  static bool isMuted = false;

  /// Master volume 0.0–1.0, applied as a multiplier on every cue (§C).
  static double masterVolume = 0.8;

  /// Active sound pack. Defaults to Wood.
  static SoundPack soundPack = SoundPack.wood;

  static bool _initialized = false;
  static bool _available = false;

  /// Last error surfaced by a play call. Useful for diagnosing silent audio.
  static String? lastError;

  static final Map<String, AudioPlayer> _players = <String, AudioPlayer>{};
  static final Map<String, DateTime> _lastPlay = <String, DateTime>{};
  static int _inFlight = 0;

  static const Duration _minGap = Duration(milliseconds: 55);
  static const int _maxSimultaneous = 4;

  static final Random _random = Random();

  /// Base file name -> per-cue gain (attenuation only, never above 1.0).
  static const Map<String, double> _cues = <String, double>{
    'dice_roll.wav': 0.9,
    'dice_result.wav': 0.65,
    'token_step.wav': 0.6,
    'token_out.wav': 0.85,
    'capture.wav': 0.95,
    'six.wav': 0.85,
    'safe.wav': 0.85,
    'no_move.wav': 0.5,
    'victory.wav': 0.95,
    'ui_click.wav': 0.4,
  };

  /// Whether the platform audio backend came up successfully.
  static bool get isAvailable => _available;

  static String _assetFor(String file) =>
      '${soundPack.assetPrefix}$file';

  /// All concrete asset paths across packs (for warm-up).
  static Iterable<String> _allAssets() sync* {
    for (final pack in SoundPack.values) {
      for (final file in _cues.keys) {
        yield '${pack.assetPrefix}$file';
      }
    }
  }

  /// Warms up the audio backend. Safe to call more than once and safe to call
  /// from pure Dart unit tests (it degrades to a no-op without Flutter bindings).
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // No platform audio backend in tests: constructing players would raise
    // MissingPluginException on the event channel.
    if (isFlutterTest) return;

    // Guard against headless unit tests that have no Flutter binding:
    // touching WidgetsBinding.instance throws when it was never initialised.
    try {
      WidgetsBinding.instance;
    } catch (_) {
      return;
    }

    for (final asset in _allAssets()) {
      try {
        final player = AudioPlayer(playerId: 'ludu_$asset');
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setVolume(0.0);
        _players[asset] = player;
        _available = true;
      } catch (e) {
        lastError = 'init $asset: $e';
        debugPrint('AudioService: failed to prepare $asset -> $e');
      }
    }
    await _applyVolumes();
  }

  /// Switches the active sound pack (§C). Warms up lazily if needed.
  static Future<void> setSoundPack(SoundPack pack) async {
    soundPack = pack;
    if (!_initialized) {
      unawaited(init());
      return;
    }
    await _applyVolumes();
  }

  static Future<void> toggleMute() async {
    isMuted = !isMuted;
    await _applyVolumes();
  }

  static Future<void> setMuted(bool muted) async {
    if (isMuted == muted) return;
    isMuted = muted;
    await _applyVolumes();
  }

  /// Sets the master volume (§C). Clamped to 0.0–1.0.
  static Future<void> setMasterVolume(double v) async {
    masterVolume = v.clamp(0.0, 1.0);
    await _applyVolumes();
  }

  static Future<void> _applyVolumes() async {
    for (final entry in _players.entries) {
      try {
        final file = entry.key.split('/').last;
        final base = _cues[file] ?? 0.8;
        await entry.value.setVolume(isMuted ? 0.0 : base * masterVolume);
      } catch (e) {
        debugPrint(
            'AudioService: volume update failed for ${entry.key} -> $e');
      }
    }
  }

  // --- Public cues (signatures kept backward-compatible) ---

  static Future<void> playDiceRoll() => _play('dice_roll.wav');

  static Future<void> playDiceResult() => _play('dice_result.wav');

  /// Soft wooden/ceramic tock, exactly in sync with the hop animation.
  /// [stepIndex]/[stepCount] add a gentle pitch rise across one move plus
  /// slight random variation so repeated steps never sound mechanical.
  static Future<void> playTokenStep([int stepIndex = 0, int stepCount = 1]) {
    final int n = stepCount <= 0 ? 1 : stepCount;
    final double progress = n <= 1 ? 0.0 : (stepIndex / (n - 1)).clamp(0.0, 1.0);
    // Gentle rise (~+6%) across the move + ±1.5% human variation.
    final double rate =
        (0.98 + progress * 0.06 + (_random.nextDouble() - 0.5) * 0.03)
            .clamp(0.85, 1.2);
    return _play('token_step.wav', playbackRate: rate);
  }

  static Future<void> playTokenOut() => _play('token_out.wav');
  static Future<void> playCapture() => _play('capture.wav');
  static Future<void> playSix() => _play('six.wav');

  /// Warm bell / glass chime when a token reaches the center.
  static Future<void> playSafe() => _play('safe.wav');
  static Future<void> playNoMove() => _play('no_move.wav');
  static Future<void> playVictory() => _play('victory.wav');

  /// Very light UI click for buttons, chip taps and settings toggles.
  static Future<void> playUiClick() => _play('ui_click.wav');

  /// Plays every cue once with a small gap — used by the Sound Test screen.
  static Future<void> playAllPreview(void Function(String file)? onEach) async {
    for (final file in _cues.keys) {
      onEach?.call(file);
      await _play(file, ignoreGap: true);
      await Future<void>.delayed(const Duration(milliseconds: 650));
    }
  }

  static Future<void> _play(
    String file, {
    double? playbackRate,
    bool ignoreGap = false,
  }) async {
    if (isMuted || isFlutterTest) return;
    final now = DateTime.now();
    final last = _lastPlay[file];
    if (!ignoreGap &&
        last != null &&
        now.difference(last) < _minGap) {
      return; // pile-up guard: drop too-rapid repeats
    }
    if (_inFlight >= _maxSimultaneous && !ignoreGap) return;
    _lastPlay[file] = now;

    final asset = _assetFor(file);
    var player = _players[asset];
    if (player == null) {
      // Not warmed up yet (or audio unavailable) - try to warm up in background.
      if (!_initialized) unawaited(init());
      return;
    }
    _inFlight++;
    try {
      await player.stop();
      if (playbackRate != null) {
        try {
          await player.setPlaybackRate(playbackRate);
        } catch (_) {
          // Rate unsupported on this platform — play at natural pitch.
        }
      }
      final base = (_cues[file] ?? 0.8) * masterVolume;
      await player.play(
        AssetSource(asset),
        volume: base.clamp(0.0, 1.0),
      );
    } catch (e) {
      lastError = 'play $asset: $e';
      debugPrint('AudioService: play failed for $asset -> $e');
    } finally {
      _inFlight = (_inFlight - 1).clamp(0, _maxSimultaneous);
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
    _lastPlay.clear();
    _inFlight = 0;
    _available = false;
    _initialized = false;
  }
}
