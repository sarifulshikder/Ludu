import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/game_state.dart';
import '../../models/ludo_color.dart';
import '../../services/haptics_service.dart';
import '../../state/game_controller.dart';
import '../../state/settings_controller.dart';

/// Home screen (§10): Start Game, player count (2/3/4), player names and
/// colors, resume-a-saved-game, rules and full settings.
class SetupScreen extends ConsumerStatefulWidget {
  final Function({
    required int playerCount,
    required List<String> playerNames,
    required List<LudoColor> playerColors,
  }) onStartGame;
  final VoidCallback onResumeGame;
  final VoidCallback onToggleTheme;
  final bool isDark;

  const SetupScreen({
    super.key,
    required this.onStartGame,
    required this.onResumeGame,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  int _playerCount = 4;
  late List<TextEditingController> _nameControllers;

  /// Clockwise seat order (§1): Red, Green, Yellow, Blue.
  final List<LudoColor> _selectedColors = [
    LudoColor.red,
    LudoColor.green,
    LudoColor.yellow,
    LudoColor.blue,
  ];

  final List<LudoColor> _allColors = [
    LudoColor.red,
    LudoColor.green,
    LudoColor.yellow,
    LudoColor.blue,
  ];

  List<LudoColor> get _activeColors =>
      _selectedColors.sublist(0, _playerCount);

  @override
  void initState() {
    super.initState();
    _nameControllers = List.generate(
      4,
      (i) => TextEditingController(text: 'Player ${i + 1}'),
    );
  }

  @override
  void dispose() {
    for (final c in _nameControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _pickColor(int playerIndex, LudoColor color) {
    HapticsService.selection();
    setState(() {
      final existing = _selectedColors.indexOf(color);
      if (existing != -1 && existing < _playerCount) {
        // Swap so colors stay unique.
        final tmp = _selectedColors[playerIndex];
        _selectedColors[playerIndex] = color;
        _selectedColors[existing] = tmp;
      } else {
        _selectedColors[playerIndex] = color;
      }
    });
  }

  void _setPlayerCount(int count) {
    HapticsService.selection();
    setState(() {
      _playerCount = count;
      // Ensure active colors stay unique.
      final seen = <LudoColor>{};
      for (int i = 0; i < _playerCount; i++) {
        if (seen.contains(_selectedColors[i])) {
          _selectedColors[i] =
              _allColors.firstWhere((c) => !seen.contains(c));
        }
        seen.add(_selectedColors[i]);
      }
      if (count == 2) {
        // Opposite seats for a balanced duel (§1).
        _selectedColors[0] = LudoColor.red;
        _selectedColors[1] = LudoColor.yellow;
      }
      if (count == 3) {
        _selectedColors[0] = LudoColor.red;
        _selectedColors[1] = LudoColor.green;
        _selectedColors[2] = LudoColor.yellow;
      }
    });
  }

  void _showRulesDialog() {
    HapticsService.light();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor:
              widget.isDark ? const Color(0xFF141D2E) : Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Text('🎲 ', style: TextStyle(fontSize: 22)),
              Text('Ludu Rules',
                  style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _RuleItem(
                  title: 'Pure Luck Guarantee',
                  desc: 'Every roll uses cryptographically secure Random.secure(). Zero weighting, zero hidden help.',
                ),
                _RuleItem(
                  title: 'First Player',
                  desc: 'The starting player is chosen randomly. Turns run clockwise: Red, Green, Yellow, Blue.',
                ),
                _RuleItem(
                  title: 'Exit Base',
                  desc: 'Roll a 6 to bring a token onto your start square.',
                ),
                _RuleItem(
                  title: 'Extra Turn',
                  desc: 'Roll again after a 6 you actually move with, after a capture, or after reaching the center. Bonuses chain.',
                ),
                _RuleItem(
                  title: 'Captures & Safe Squares',
                  desc: 'Landing exactly on an opponent sends them home. Passing over is safe. Start squares and stars are safe and can be shared.',
                ),
                _RuleItem(
                  title: 'Three 6s Rule',
                  desc: 'A third consecutive 6 is voided — no move — and the turn passes. Earlier moves stay.',
                ),
                _RuleItem(
                  title: 'Exact Roll to Finish',
                  desc: 'The center needs the exact number. Smaller rolls still move closer inside the home column.',
                ),
                _RuleItem(
                  title: 'Winning',
                  desc: 'All 4 home takes the next rank. The game continues for 2nd and 3rd place.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Got It',
                style: TextStyle(
                  color: Color(0xFFE9C46A),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<LudoColor> activeColors = _activeColors;
    final settings = ref.watch(settingsControllerProvider);
    final settingsUpdater =
        ref.read(settingsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('LUDU'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Rules',
            onPressed: _showRulesDialog,
          ),
          IconButton(
            icon: Icon(widget.isDark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded),
            tooltip: 'Toggle Theme',
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFE63946),
                            Color(0xFF2A9D8F),
                            Color(0xFFE9C46A),
                            Color(0xFF277DA1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE9C46A).withOpacity(0.35),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text('🎲',
                            style: TextStyle(fontSize: 42)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Ludu',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pure Luck • Local Pass & Play',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _ResumeCard(
                isDark: widget.isDark,
                onResume: widget.onResumeGame,
              ),
              const Text(
                'NUMBER OF PLAYERS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: Color(0xFFE9C46A),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [2, 3, 4].map((count) {
                  final isSelected = _playerCount == count;
                  return Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 4.0),
                      child: InkWell(
                        onTap: () => _setPlayerCount(count),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFE9C46A)
                                : (widget.isDark
                                    ? const Color(0xFF141D2E)
                                    : Colors.white),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFE9C46A)
                                  : (widget.isDark
                                      ? const Color(0xFF283650)
                                      : const Color(0xFFD6CEBD)),
                              width: isSelected ? 2.0 : 1.0,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$count Players',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isSelected
                                    ? const Color(0xFF1A202C)
                                    : (widget.isDark
                                        ? Colors.white
                                        : const Color(0xFF1A202C)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              const Text(
                'PLAYERS & SEATS',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: Color(0xFFE9C46A),
                ),
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _playerCount,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final color = activeColors[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: widget.isDark
                          ? const Color(0xFF141D2E)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: color.primary.withOpacity(0.6),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: color.jewelGradient,
                                border: Border.all(
                                    color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.primary.withOpacity(0.45),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  color.emblemGlyph,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _nameControllers[index],
                                maxLength: 16,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                                decoration: InputDecoration(
                                  counterText: '',
                                  border: InputBorder.none,
                                  isDense: true,
                                  labelText:
                                      '${color.displayName} ${color.emblemGlyph} Player',
                                  labelStyle: TextStyle(
                                    color: color.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: _allColors.map((c) {
                            final selected = c == color;
                            final taken = activeColors.contains(c);
                            return Padding(
                              padding:
                                  const EdgeInsets.only(right: 10),
                              child: GestureDetector(
                                onTap: () => _pickColor(index, c),
                                child: Opacity(
                                  opacity:
                                      (!selected && taken) ? 0.45 : 1.0,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: c.jewelGradient,
                                      border: Border.all(
                                        color: selected
                                            ? Colors.white
                                            : Colors.white30,
                                        width: selected ? 3.0 : 1.5,
                                      ),
                                      boxShadow: [
                                        if (selected)
                                          BoxShadow(
                                            color: c.primary
                                                .withOpacity(0.6),
                                            blurRadius: 10,
                                          ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        c.emblemGlyph,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: selected ? 17 : 14,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              Material(
                color: widget.isDark
                    ? const Color(0xFF141D2E)
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: widget.isDark
                        ? const Color(0xFF283650)
                        : const Color(0xFFD6CEBD),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 8, bottom: 2),
                        child: Text(
                          'SETTINGS',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: Color(0xFFE9C46A),
                          ),
                        ),
                      ),
                      _SettingsSwitch(
                        title: 'Sound effects',
                        subtitle: 'Dice, moves, captures, victory',
                        icon: settings.sound
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        value: settings.sound,
                        onChanged: (v) {
                          HapticsService.selection();
                          settingsUpdater.update(
                              settings.copyWith(sound: v));
                        },
                      ),
                      _SettingsSwitch(
                        title: 'Vibration',
                        subtitle:
                            'Light haptics for roll, move, capture',
                        icon: settings.vibration
                            ? Icons.vibration_rounded
                            : Icons.mobile_off_rounded,
                        value: settings.vibration,
                        onChanged: (v) {
                          settingsUpdater.update(
                              settings.copyWith(vibration: v));
                          HapticsService.selection();
                        },
                      ),
                      _SettingsSwitch(
                        title: 'Auto-move single option',
                        subtitle:
                            'Play it automatically when only one move is legal',
                        icon: Icons.bolt_rounded,
                        value: settings.autoMove,
                        onChanged: (v) {
                          HapticsService.selection();
                          settingsUpdater.update(
                              settings.copyWith(autoMove: v));
                        },
                      ),
                      _SettingsSwitch(
                        title: 'Block rule',
                        subtitle:
                            'Stacks of 2+ on a plain square cannot be landed on',
                        icon: Icons.block_rounded,
                        value: settings.blockRule,
                        onChanged: (v) {
                          HapticsService.selection();
                          settingsUpdater.update(
                              settings.copyWith(blockRule: v));
                        },
                      ),
                      _SettingsSwitch(
                        title: 'End game at first winner',
                        subtitle:
                            'Stop the match as soon as someone finishes',
                        icon: Icons.emoji_events_rounded,
                        value: settings.endAtFirstWinner,
                        onChanged: (v) {
                          HapticsService.selection();
                          settingsUpdater.update(settings.copyWith(
                              endAtFirstWinner: v));
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  HapticsService.medium();
                  final names = List.generate(
                    _playerCount,
                    (i) => _nameControllers[i].text.trim().isEmpty
                        ? 'Player ${i + 1}'
                        : _nameControllers[i].text.trim(),
                  );
                  widget.onStartGame(
                    playerCount: _playerCount,
                    playerNames: names,
                    playerColors: activeColors,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE9C46A),
                  foregroundColor: const Color(0xFF131824),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                  shadowColor:
                      const Color(0xFFE9C46A).withOpacity(0.4),
                ),
                child: const Text(
                  'START GAME',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2.0,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resume card (§10): appears only when an interrupted game is saved.
class _ResumeCard extends ConsumerWidget {
  final bool isDark;
  final VoidCallback onResume;

  const _ResumeCard({required this.isDark, required this.onResume});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<GameState?>(
      future: ref.read(persistenceProvider).loadGame(),
      builder: (context, snapshot) {
        final saved = snapshot.data;
        if (saved == null || saved.phase != GamePhase.playing) {
          return const SizedBox.shrink();
        }
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2A9D8F), Color(0xFF21867A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2A9D8F).withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.history_rounded,
                  color: Colors.white, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Interrupted game found',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${saved.players.length} players • '
                      '${saved.players.map((p) => p.name).join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  HapticsService.medium();
                  ref
                      .read(gameControllerProvider.notifier)
                      .restore(saved);
                  onResume();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF21867A),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Resume',
                    style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitch({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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

class _RuleItem extends StatelessWidget {
  final String title;
  final String desc;

  const _RuleItem({required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Color(0xFFE9C46A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            desc,
            style: const TextStyle(fontSize: 13, height: 1.3),
          ),
        ],
      ),
    );
  }
}
