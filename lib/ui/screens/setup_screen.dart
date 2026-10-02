import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../models/game_settings.dart';
import '../../models/game_state.dart';
import '../../models/ludo_color.dart';
import '../../models/player.dart';
import '../../services/audio_service.dart';
import '../../services/haptics_service.dart';
import '../../state/game_controller.dart';
import '../../state/settings_controller.dart';
import 'rules_screen.dart';
import 'sound_test_screen.dart';

/// Home screen (§10): Start Game, player count (2/3/4), player names and
/// colors, resume-a-saved-game, rules and full settings.
class SetupScreen extends ConsumerStatefulWidget {
  final Function({
    required int playerCount,
    required List<String> playerNames,
    required List<LudoColor> playerColors,
    required bool teamMode,
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

  /// Team 2v2 (§E): teammates opposite, Team A = Red + Yellow.
  bool _teamMode = false;
  late List<TextEditingController> _nameControllers;

  /// Clockwise seat order: Red, Green, Yellow, Blue.
  /// P1 Red top-left, P2 Green top-right, P3 Yellow bottom-right,
  /// P4 Blue bottom-left.
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
      // Team 2v2 always needs exactly four players (§E).
      if (_teamMode) _playerCount = 4;
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

  void _setMode(bool team) {
    HapticsService.selection();
    setState(() {
      _teamMode = team;
      // Team mode is 4 players only; Classic keeps the chosen count.
      if (team) _playerCount = 4;
      if (team) {
        _selectedColors[0] = LudoColor.red;
        _selectedColors[1] = LudoColor.green;
        _selectedColors[2] = LudoColor.yellow;
        _selectedColors[3] = LudoColor.blue;
      }
    });
  }

  /// Classic / Team mode cards (§E).
  Widget _modeCard(String title, String subtitle, IconData icon, bool team) {
    final selected = _teamMode == team;
    final bg = selected
        ? const Color(0xFFE9C46A)
        : (widget.isDark ? const Color(0xFF141D2E) : Colors.white);
    final fg = selected
        ? const Color(0xFF1A202C)
        : (widget.isDark ? Colors.white : const Color(0xFF1A202C));
    final sub = selected
        ? const Color(0xFF3D3520)
        : (widget.isDark ? Colors.white70 : const Color(0xFF64748B));
    return Expanded(
      child: InkWell(
        onTap: () => _setMode(team),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFFE9C46A)
                  : (widget.isDark
                      ? const Color(0xFF283650)
                      : const Color(0xFFD6CEBD)),
              width: selected ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 22, color: fg),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: fg,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: sub),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Team A / Team B preview: who plays with whom (§E).
  Widget _teamPreview(List<LudoColor> activeColors) {
    Widget row(String label, LudoColor a, LudoColor b) {
      final accent = Player.teamAccent(label == 'Team A' ? 0 : 1);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 58,
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withOpacity(widget.isDark ? 0.25 : 0.20),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: accent, width: 1),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: widget.isDark ? accent : const Color(0xFF1A202C),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _miniOrb(a),
            _miniOrb(b),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'sit opposite • share squares • never capture each other',
                style: TextStyle(
                  fontSize: 11,
                  color: widget.isDark
                      ? Colors.white60
                      : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF141D2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isDark
              ? const Color(0xFF283650)
              : const Color(0xFFD6CEBD),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row('Team A', activeColors[0], activeColors[2]),
          row('Team B', activeColors[1], activeColors[3]),
          Text(
            'A team wins when all 8 tokens are home. Once you finish your own 4, '
            'your rolls move your teammate\u2019s tokens.',
            style: TextStyle(
              fontSize: 11,
              color:
                  widget.isDark ? Colors.white60 : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniOrb(LudoColor c) {
    return Container(
      width: 26,
      height: 26,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: c.jewelGradient,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Center(
        child: Text(
          c.emblemGlyph,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  /// Full rules screen (§F), including the Team 2v2 rules.
  void _openRules() {
    HapticsService.light();
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => RulesScreen(isDark: widget.isDark),
    ));
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
            icon: const Icon(Icons.menu_book_rounded),
            tooltip: 'Rules',
            onPressed: _openRules,
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
                'GAME MODE',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: Color(0xFFE9C46A),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _modeCard(
                    'Classic',
                    '2–4 players, everyone for themselves',
                    Icons.person_rounded,
                    false,
                  ),
                  const SizedBox(width: 10),
                  _modeCard(
                    'Team 2 vs 2',
                    'Red+Yellow vs Green+Blue, 8 home wins',
                    Icons.groups_rounded,
                    true,
                  ),
                ],
              ),
              if (_teamMode) ...[
                const SizedBox(height: 12),
                _teamPreview(activeColors),
              ],
              const SizedBox(height: 20),
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
              if (_teamMode)
                Center(
                  child: Text(
                    'Team 2 vs 2 always uses 4 players',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: widget.isDark
                          ? Colors.white60
                          : const Color(0xFF64748B),
                    ),
                  ),
                )
              else
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
                        padding: EdgeInsets.only(top: 8, bottom: 6),
                        child: Text(
                          'BOARD & PIECE THEME',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: Color(0xFFE9C46A),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          children: [
                            for (final mode in AppThemeMode.values) ...[
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 3.0),
                                  child: InkWell(
                                    onTap: () {
                                      HapticsService.selection();
                                      settingsUpdater.update(settings.copyWith(appTheme: mode));
                                    },
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                      decoration: BoxDecoration(
                                        color: settings.appTheme == mode
                                            ? const Color(0xFFE9C46A)
                                            : (widget.isDark ? const Color(0xFF1B253B) : const Color(0xFFF0EAE1)),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: settings.appTheme == mode
                                              ? const Color(0xFFE9C46A)
                                              : (widget.isDark ? const Color(0xFF2C3E60) : const Color(0xFFD6CEBD)),
                                          width: settings.appTheme == mode ? 2.0 : 1.0,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(mode.emoji, style: const TextStyle(fontSize: 18)),
                                          const SizedBox(height: 2),
                                          Text(
                                            mode.displayName,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: settings.appTheme == mode
                                                  ? const Color(0xFF141D2E)
                                                  : (widget.isDark ? Colors.white : const Color(0xFF141D2E)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      _SettingsSwitch(
                        title: 'Face-to-face mode',
                        subtitle: 'Rotate top chips & dice 180° for opponents across the phone',
                        icon: Icons.screen_rotation_rounded,
                        value: settings.faceToFaceMode,
                        onChanged: (v) {
                          HapticsService.selection();
                          settingsUpdater.update(settings.copyWith(faceToFaceMode: v));
                        },
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
                      // Sound pack (§C): Wood / Glass / Minimal.
                      Padding(
                        padding: const EdgeInsets.only(
                            left: 0, right: 0, top: 4, bottom: 6),
                        child: Row(
                          children: [
                            for (final pack in SoundPack.values)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 3.0),
                                  child: ChoiceChip(
                                    label: Text(pack.displayName),
                                    selected:
                                        settings.soundPack == pack,
                                    onSelected: (_) {
                                      HapticsService.selection();
                                      settingsUpdater.update(settings
                                          .copyWith(soundPack: pack));
                                      AudioService.playUiClick();
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      _SettingsSwitch(
                        title: 'Background music',
                        subtitle: 'Ambient layer (off by default)',
                        icon: settings.backgroundMusic
                            ? Icons.music_note_rounded
                            : Icons.music_off_rounded,
                        value: settings.backgroundMusic,
                        onChanged: (v) {
                          HapticsService.selection();
                          settingsUpdater.update(settings.copyWith(
                              backgroundMusic: v));
                        },
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 2, bottom: 4),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              HapticsService.selection();
                              AudioService.playUiClick();
                              Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                builder: (_) =>
                                    const SoundTestScreen(),
                              ));
                            },
                            icon: const Icon(
                                Icons.graphic_eq_rounded,
                                size: 20),
                            label: const Text(
                              'Sound test — listen to each cue',
                              style:
                                  TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
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
                      // Volume slider (§C).
                      Opacity(
                        opacity: settings.sound ? 1.0 : 0.45,
                        child: Padding(
                          padding: const EdgeInsets.only(
                              left: 14, right: 14, bottom: 4),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 28,
                                child:
                                    Icon(Icons.volume_down_rounded, size: 20),
                              ),
                              Expanded(
                                child: Slider(
                                  value: settings.volume,
                                  min: 0,
                                  max: 1,
                                  divisions: 10,
                                  label: '${(settings.volume * 100).round()}%',
                                  onChanged: settings.sound
                                      ? (v) => settingsUpdater.update(
                                          settings.copyWith(volume: v))
                                      : null,
                                ),
                              ),
                              SizedBox(
                                width: 42,
                                child: Text(
                                  '${(settings.volume * 100).round()}%',
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _SettingsSwitch(
                        title: 'Animation speed',
                        subtitle: settings.fastAnimation
                            ? 'Fast — snappier hops and dice'
                            : 'Normal — full-length hops and dice',
                        icon: settings.fastAnimation
                            ? Icons.fast_forward_rounded
                            : Icons.play_circle_outline_rounded,
                        value: settings.fastAnimation,
                        onChanged: (v) {
                          HapticsService.selection();
                          settingsUpdater.update(
                              settings.copyWith(fastAnimation: v));
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
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openRules,
                  icon: const Icon(Icons.menu_book_rounded, size: 20),
                  label: const Text(
                    'Rules',
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
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  HapticsService.medium();
                  AudioService.playUiClick();
                  final names = List.generate(
                    _teamMode ? 4 : _playerCount,
                    (i) => _nameControllers[i].text.trim().isEmpty
                        ? 'Player ${i + 1}'
                        : _nameControllers[i].text.trim(),
                  );
                  widget.onStartGame(
                    playerCount: _teamMode ? 4 : _playerCount,
                    playerNames: names,
                    playerColors: activeColors,
                    teamMode: _teamMode,
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
