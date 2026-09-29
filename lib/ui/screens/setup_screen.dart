import 'package:flutter/material.dart';
import '../../models/ludo_color.dart';
import '../../services/audio_service.dart';
import '../../services/haptics_service.dart';

class SetupScreen extends StatefulWidget {
  final Function({
    required int playerCount,
    required List<String> playerNames,
    required List<LudoColor> playerColors,
  }) onStartGame;
  final VoidCallback onToggleTheme;
  final bool isDark;

  const SetupScreen({
    super.key,
    required this.onStartGame,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _playerCount = 4;
  late List<TextEditingController> _nameControllers;
  final List<LudoColor> _selectedColors = [
    LudoColor.red,
    LudoColor.green,
    LudoColor.yellow,
    LudoColor.blue,
  ];
  bool _soundOn = !AudioService.isMuted;
  bool _vibrationOn = HapticsService.isEnabled;

  final List<LudoColor> _allColors = [
    LudoColor.red,
    LudoColor.green,
    LudoColor.yellow,
    LudoColor.blue,
  ];

  List<LudoColor> get _activeColors =>
      _selectedColors.sublist(0, _playerCount);

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
        // Default to opposite seats for balance if user hasn't customized.
        _selectedColors[0] = LudoColor.red;
        _selectedColors[1] = LudoColor.yellow;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
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

  void _showRulesDialog() {
    HapticsService.light();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: widget.isDark ? const Color(0xFF141D2E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Text('🎲 ', style: TextStyle(fontSize: 22)),
              Text(
                'Ludu Rules',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          content: const SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _RuleItem(
                  title: 'Pure Luck Guarantee',
                  desc: 'Every roll uses cryptographically secure Random.secure(). Zero DDA, zero weighting, zero pity mechanics.',
                ),
                _RuleItem(
                  title: 'Exit Base',
                  desc: 'Roll a 6 to bring a token out of base.',
                ),
                _RuleItem(
                  title: 'Extra Turn',
                  desc: 'Roll again when you roll a 6, capture an opponent, or bring a token home.',
                ),
                _RuleItem(
                  title: 'Captures & Safe Stars',
                  desc: 'Landing on an opponent sends them back to base. Star squares and each color start square are safe.',
                ),
                _RuleItem(
                  title: 'Three 6s Rule',
                  desc: 'Three consecutive 6s cancels the third roll and passes the turn.',
                ),
                _RuleItem(
                  title: 'Exact Roll to Finish',
                  desc: 'Tokens need the exact number to enter the center. Overshoots cannot move.',
                ),
                _RuleItem(
                  title: 'Winning',
                  desc: 'First player to bring all 4 tokens home wins.',
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
            icon: Icon(widget.isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            tooltip: 'Toggle Theme',
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Logo / Slogan
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
                        child: Text(
                          '🎲',
                          style: TextStyle(fontSize: 42),
                        ),
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
                        color: widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Player Count Selection
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
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: InkWell(
                        onTap: () => _setPlayerCount(count),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFE9C46A)
                                : (widget.isDark ? const Color(0xFF141D2E) : Colors.white),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFE9C46A)
                                  : (widget.isDark ? const Color(0xFF283650) : const Color(0xFFD6CEBD)),
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
                                    : (widget.isDark ? Colors.white : const Color(0xFF1A202C)),
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

              // Player Name Inputs & Colors
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
                separatorBuilder: (context, index) => const SizedBox(height: 10),
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
                                    color:
                                        color.primary.withOpacity(0.45),
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
                        // Color picker: tap to claim, tap taken to swap.
                        Row(
                          children: _allColors.map((c) {
                            final selected = c == color;
                            final taken = activeColors.contains(c);
                            return Padding(
                              padding:
                                  const EdgeInsets.only(right: 10),
                              child: GestureDetector(
                                onTap: () =>
                                    _pickColor(index, c),
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

              // Settings: sound + vibration toggles.
              // Material (not Container) background so the SwitchListTiles
              // paint their ink on a Material ancestor — otherwise the
              // framework throws in debug builds.
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
                      padding:
                          EdgeInsets.only(top: 8, bottom: 2),
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
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Sound effects',
                          style:
                              TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text(
                          'Dice, moves, captures, victory'),
                      secondary: Icon(
                        _soundOn
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                      ),
                      value: _soundOn,
                      onChanged: (v) {
                        setState(() => _soundOn = v);
                        AudioService.setMuted(!v);
                        HapticsService.selection();
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Vibration',
                          style:
                              TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text(
                          'Light haptics for roll, move, capture'),
                      secondary: Icon(
                        _vibrationOn
                            ? Icons.vibration_rounded
                            : Icons.mobile_off_rounded,
                      ),
                      value: _vibrationOn,
                      onChanged: (v) {
                        setState(() => _vibrationOn = v);
                        HapticsService.setEnabled(v);
                        HapticsService.selection();
                      },
                    ),
                  ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Start Game Button
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 6,
                  shadowColor: const Color(0xFFE9C46A).withOpacity(0.4),
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
