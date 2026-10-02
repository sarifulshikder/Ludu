import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/ludu_theme.dart';
import '../../models/game_settings.dart';
import '../../services/audio_service.dart';
import '../../services/haptics_service.dart';
import '../../state/settings_controller.dart';
import 'rules_screen.dart';
import 'sound_test_screen.dart';

/// In-game settings: theme selector, face-to-face mode, sound + volume,
/// vibration, animation speed, auto-move, block rule, rules & match restart.
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
    final isDark = settings.isDark;
    final cfg = LuduTheme.forMode(settings.appTheme, isDark: isDark);

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
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'SETTINGS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                    color: Color(0xFFE9C46A),
                  ),
                ),
                Text(
                  settings.appTheme.displayName.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: cfg.boardInlayLine,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // --- Theme Selection Section ---
            Text(
              'BOARD & PIECE THEME',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final mode in AppThemeMode.values) ...[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3.0),
                      child: _ThemeCard(
                        mode: mode,
                        isSelected: settings.appTheme == mode,
                        isDark: isDark,
                        onTap: () => update(settings.copyWith(appTheme: mode)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),

            // --- Dark Mode Toggle ---
            _tile(
              title: 'Dark mode',
              subtitle: isDark
                  ? 'Midnight arena & deep contrast'
                  : 'Luminous light porcelain & gold',
              icon: isDark
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
              value: isDark,
              onChanged: (v) {
                update(settings.copyWith(isDark: v));
                onToggleTheme();
              },
            ),

            // --- Face-to-Face Mode ---
            _tile(
              title: 'Face-to-face mode',
              subtitle: 'Rotate top chips & dice 180° for opponents across the phone',
              icon: Icons.screen_rotation_rounded,
              value: settings.faceToFaceMode,
              onChanged: (v) => update(settings.copyWith(faceToFaceMode: v)),
            ),

            // --- Sound & Volume ---
            _tile(
              title: 'Sound effects',
              subtitle: 'Dice, hops, captures, center, bonuses',
              icon: settings.sound
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
              value: settings.sound,
              onChanged: (v) => update(settings.copyWith(sound: v)),
            ),
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

            // --- Sound Pack (Wood / Glass / Minimal) ---
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 4),
              child: Text(
                'SOUND PACK',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
            Row(
              children: [
                for (final pack in SoundPack.values)
                  Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 3.0),
                      child: InkWell(
                        onTap: settings.sound
                            ? () {
                                update(
                                    settings.copyWith(soundPack: pack));
                                AudioService.playUiClick();
                              }
                            : null,
                        borderRadius: BorderRadius.circular(12),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              vertical: 10, horizontal: 6),
                          decoration: BoxDecoration(
                            color: cfg.surfaceCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: settings.soundPack == pack
                                  ? cfg.boardInlayLine
                                  : cfg.surfaceCardBorder,
                              width:
                                  settings.soundPack == pack ? 2.2 : 1.0,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                pack.displayName,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight:
                                      settings.soundPack == pack
                                          ? FontWeight.w900
                                          : FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                pack == SoundPack.wood
                                    ? '🪵'
                                    : pack == SoundPack.glass
                                        ? '🔮'
                                        : '🍃',
                                style: const TextStyle(fontSize: 18),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Text(
                settings.soundPack.subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
              ),
            ),

            // --- Background Music (OFF by default) ---
            _tile(
              title: 'Background music',
              subtitle: 'Ambient layer (off by default)',
              icon: settings.backgroundMusic
                  ? Icons.music_note_rounded
                  : Icons.music_off_rounded,
              value: settings.backgroundMusic,
              onChanged: (v) =>
                  update(settings.copyWith(backgroundMusic: v)),
            ),

            // --- Sound Test ---
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 6),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticsService.selection();
                    AudioService.playUiClick();
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => const SoundTestScreen(),
                    ));
                  },
                  icon: const Icon(Icons.graphic_eq_rounded, size: 20),
                  label: const Text(
                    'Sound test — listen to each cue',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(
                        color: cfg.boardInlayLine, width: 1.5),
                    foregroundColor: cfg.boardInlayLine,
                  ),
                ),
              ),
            ),

            // --- Vibration ---
            _tile(
              title: 'Vibration',
              subtitle: 'Light on moves, strong on captures',
              icon: settings.vibration
                  ? Icons.vibration_rounded
                  : Icons.mobile_off_rounded,
              value: settings.vibration,
              onChanged: (v) => update(settings.copyWith(vibration: v)),
            ),

            // --- Animation Speed ---
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

            // --- Auto-move single option ---
            _tile(
              title: 'Auto-move single option',
              subtitle: 'When only one move is legal, play it automatically',
              icon: Icons.bolt_rounded,
              value: settings.autoMove,
              onChanged: (v) => update(settings.copyWith(autoMove: v)),
            ),

            // --- Block Rule ---
            _tile(
              title: 'Block rule',
              subtitle: 'Stacks of 2+ on a plain square cannot be landed on',
              icon: Icons.block_rounded,
              value: settings.blockRule,
              onChanged: (v) => update(settings.copyWith(blockRule: v)),
            ),

            // --- End at first winner ---
            _tile(
              title: 'End game at first winner',
              subtitle: 'Stop the match as soon as someone finishes',
              icon: Icons.emoji_events_rounded,
              value: settings.endAtFirstWinner,
              onChanged: (v) => update(settings.copyWith(endAtFirstWinner: v)),
            ),

            const SizedBox(height: 10),
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

class _ThemeCard extends StatelessWidget {
  final AppThemeMode mode;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.mode,
    required this.isSelected,
    this.isDark = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = LuduTheme.forMode(mode, isDark: isDark);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: cfg.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? cfg.boardInlayLine : cfg.surfaceCardBorder,
            width: isSelected ? 2.2 : 1.0,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: cfg.boardInlayLine.withOpacity(0.35),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              mode.emoji,
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(height: 4),
            Text(
              mode.displayName,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF1B1812))
                    : (isDark ? Colors.white70 : const Color(0xFF555555)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
