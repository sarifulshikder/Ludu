import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/game_settings.dart';
import '../../services/haptics_service.dart';
import '../../state/settings_controller.dart';
import 'rules_screen.dart';

/// In-game settings (§9, §C, §F): sound + volume, vibration, auto-move,
/// block rule, end-at-first-winner, animation speed, theme, rules and match
/// restart.
class SettingsSheet extends ConsumerWidget {
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onRestartMatch;

  const SettingsSheet({
    super.key,
    required this.isDark,
    required this.onToggleTheme,
    required this.onRestartMatch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final updater = ref.read(settingsControllerProvider.notifier);

    void update(GameSettings next) {
      HapticsService.selection();
      updater.update(next);
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'SETTINGS',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                color: Color(0xFFE9C46A),
              ),
            ),
            _tile(
              title: 'Sound effects',
              subtitle: 'Dice, hops, captures, center, bonuses',
              icon: settings.sound
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              value: settings.sound,
              onChanged: (v) => update(settings.copyWith(sound: v)),
            ),
            // Separate volume slider (§C).
            Opacity(
              opacity: settings.sound ? 1.0 : 0.45,
              child: Padding(
                padding: const EdgeInsets.only(left: 12, right: 4, bottom: 6),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 26,
                      child: Icon(Icons.volume_down_rounded, size: 20),
                    ),
                    Expanded(
                      child: Slider(
                        value: settings.volume,
                        min: 0,
                        max: 1,
                        divisions: 10,
                        label: '${(settings.volume * 100).round()}%',
                        onChanged: settings.sound
                            ? (v) => update(settings.copyWith(volume: v))
                            : null,
                      ),
                    ),
                    SizedBox(
                      width: 42,
                      child: Text(
                        '${(settings.volume * 100).round()}%',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _tile(
              title: 'Vibration',
              subtitle: 'Light on moves, strong on captures',
              icon: settings.vibration
                  ? Icons.vibration_rounded
                  : Icons.mobile_off_rounded,
              value: settings.vibration,
              onChanged: (v) => update(settings.copyWith(vibration: v)),
            ),
            _tile(
              title: 'Animation speed',
              subtitle: settings.fastAnimation
                  ? 'Fast — snappier hops and dice'
                  : 'Normal — full-length hops and dice',
              icon: settings.fastAnimation
                  ? Icons.fast_forward_rounded
                  : Icons.play_circle_outline_rounded,
              value: settings.fastAnimation,
              onChanged: (v) => update(settings.copyWith(fastAnimation: v)),
            ),
            _tile(
              title: 'Auto-move single option',
              subtitle: 'When only one move is legal, play it automatically',
              icon: Icons.bolt_rounded,
              value: settings.autoMove,
              onChanged: (v) => update(settings.copyWith(autoMove: v)),
            ),
            _tile(
              title: 'Block rule',
              subtitle: 'Stacks of 2+ on a plain square cannot be landed on',
              icon: Icons.block_rounded,
              value: settings.blockRule,
              onChanged: (v) => update(settings.copyWith(blockRule: v)),
            ),
            _tile(
              title: 'End game at first winner',
              subtitle: 'Stop the match as soon as someone finishes',
              icon: Icons.emoji_events_rounded,
              value: settings.endAtFirstWinner,
              onChanged: (v) => update(settings.copyWith(endAtFirstWinner: v)),
            ),
            _tile(
              title: 'Dark theme',
              subtitle: 'Midnight arena instead of daylight',
              icon: isDark
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
              value: isDark,
              onChanged: (_) => onToggleTheme(),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => RulesScreen(isDark: isDark),
                  ));
                },
                icon: const Icon(Icons.menu_book_rounded, size: 20),
                label: const Text(
                  'Read the rules',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  side: const BorderSide(
                      color: Color(0xFFE9C46A), width: 1.5),
                  foregroundColor: const Color(0xFFE9C46A),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onRestartMatch();
                },
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text(
                  'Restart match',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  side: const BorderSide(
                      color: Color(0xFFE63946), width: 1.5),
                  foregroundColor: const Color(0xFFE63946),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _tile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(subtitle),
      secondary: Icon(icon),
      value: value,
      onChanged: onChanged,
    );
  }
}
