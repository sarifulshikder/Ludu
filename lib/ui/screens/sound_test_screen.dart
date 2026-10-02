import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/ludu_theme.dart';
import '../../models/game_settings.dart';
import '../../services/audio_service.dart';
import '../../services/haptics_service.dart';
import '../../state/settings_controller.dart';

/// Sound Test screen (§C): listen to every cue one by one, per pack.
class SoundTestScreen extends ConsumerStatefulWidget {
  const SoundTestScreen({super.key});

  @override
  ConsumerState<SoundTestScreen> createState() => _SoundTestScreenState();
}

class _SoundTestScreenState extends ConsumerState<SoundTestScreen> {
  String? _playing;

  Future<void> _play(String label, Future<void> Function() fn) async {
    HapticsService.selection();
    setState(() => _playing = label);
    await fn();
    if (mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (mounted && _playing == label) {
        setState(() => _playing = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final updater = ref.read(settingsControllerProvider.notifier);
    final cfg = LuduTheme.forMode(settings.appTheme, isDark: settings.isDark);

    final cues = <(String, String, Future<void> Function())>[
      ('Token step', 'soft wooden tock per hop', () => AudioService.playTokenStep(2, 6)),
      ('Dice rattle', 'rattle on wood + landing thud', () => AudioService.playDiceRoll()),
      ('Dice settle', 'soft thud on the final bounce', () => AudioService.playDiceResult()),
      ('Leave base', 'gentle pop + light shimmer', () => AudioService.playTokenOut()),
      ('Capture', 'soft thud + falling tone', () => AudioService.playCapture()),
      ('Reach center', 'warm bell / glass chime', () => AudioService.playSafe()),
      ('Bonus roll', 'short ascending chime (6)', () => AudioService.playSix()),
      ('No legal move', 'quiet muted tick', () => AudioService.playNoMove()),
      ('Victory', 'elegant ~2 s fanfare', () => AudioService.playVictory()),
      ('UI click', 'very light button click', () => AudioService.playUiClick()),
    ];

    return Scaffold(
      backgroundColor: cfg.backgroundGradient.first,
      appBar: AppBar(
        title: const Text('SOUND TEST'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            Text(
              'Pack: ${settings.soundPack.displayName}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
                color: cfg.boardInlayLine,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final pack in SoundPack.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(pack.displayName),
                        selected: settings.soundPack == pack,
                        onSelected: (_) {
                          HapticsService.selection();
                          updater.update(
                              settings.copyWith(soundPack: pack));
                        },
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Samples are CC0 studio recordings — soft, warm, tactile, calm. '
              'See assets/audio/LICENSE_NOTE.md.',
              style: TextStyle(
                fontSize: 12,
                color: settings.isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 12),
            for (final cue in cues)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  tileColor: cfg.surfaceCard,
                  leading: Icon(
                    _playing == cue.$1
                        ? Icons.graphic_eq_rounded
                        : Icons.play_arrow_rounded,
                    color: cfg.boardInlayLine,
                  ),
                  title: Text(cue.$1,
                      style:
                          const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text(cue.$2),
                  trailing: _playing == cue.$1
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                  onTap: () => _play(cue.$1, cue.$3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
