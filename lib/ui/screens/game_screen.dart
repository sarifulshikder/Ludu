import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/env.dart';
import '../../core/theme/ludu_theme.dart';
import '../../models/game_settings.dart';
import '../../models/game_state.dart';
import '../../models/ludo_color.dart';
import '../../models/player.dart';
import '../../services/audio_service.dart';
import '../../services/haptics_service.dart';
import '../../state/game_controller.dart';
import '../../state/settings_controller.dart';
import '../board/ludo_board.dart';
import '../widgets/dice_widget.dart';
import '../widgets/player_panel.dart';
import 'ranking_screen.dart';
import 'rules_screen.dart';
import 'settings_sheet.dart';

/// Game Screen with Square 15×15 Board, large chips, single gliding dice.
///
/// Polish pass:
/// * Perfectly square 15x15 board with a 10 dp safe inset (edge tokens,
///   glow and lift effects are never clipped) plus a soft board
///   shadow/glow pedestal.
/// * Large player chips (70 dp) kept close to the board (12 dp gaps).
/// * ONE large dice (110 dp) sitting directly beside the active player's
///   chip with a 12 dp gap, on the side facing the board's center. The
///   chip rows reserve a middle dice slot so the dice never overlaps any
///   text or border; it glides smoothly (450 ms) when the turn passes.
/// * Balanced spacing above/below so the board looks centered, over a
///   tasteful themed background (vignette, subtle pattern, glow).
/// * Face-to-face rotation mode for opponents across the phone (stays as
///   a user setting).
class GameScreen extends ConsumerStatefulWidget {
  final VoidCallback onNewGame;
  final VoidCallback onToggleTheme;
  final bool isDark;

  const GameScreen({
    super.key,
    required this.onNewGame,
    required this.onToggleTheme,
    required this.isDark,
  });

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _isMuted = AudioService.isMuted;
  bool _boardAnimating = false;

  /// Short input freeze after an automatic pass.
  bool _passFreeze = false;
  Timer? _freezeTimer;
  Timer? _autoMoveTimer;

  static const double _topBarHeight = 38.0;
  static const double _chipBoardGap = 12.0;
  static const double _diceGap = 12.0;
  static const double _diceSize = 110.0;
  static const double _diceSlotWidth = 126.0;
  static const double _rowHeight = 118.0;
  static const double _boardSideInset = 10.0;

  /// Dice slot placeholders (empty space reserved so the gliding dice
  /// never overlaps text or borders). The single overlay dice flies
  /// between the measured slot centers.
  final GlobalKey _topSlotKey = GlobalKey();
  final GlobalKey _bottomSlotKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();
  Offset? _diceCenter;
  LudoColor? _diceCenterFor;

  /// Panels are placed by base colour:
  /// Top-left Red, Top-right Green, Bottom-left Blue, Bottom-right Yellow.
  static const LudoColor topLeft = LudoColor.red;
  static const LudoColor topRight = LudoColor.green;
  static const LudoColor bottomLeft = LudoColor.blue;
  static const LudoColor bottomRight = LudoColor.yellow;

  @override
  void initState() {
    super.initState();
    if (!isFlutterTest) WakelockPlus.enable().catchError((_) {});
  }

  @override
  void dispose() {
    if (!isFlutterTest) WakelockPlus.disable().catchError((_) {});
    _freezeTimer?.cancel();
    _autoMoveTimer?.cancel();
    super.dispose();
  }

  void _toggleMute() {
    HapticsService.light();
    AudioService.playUiClick();
    setState(() {
      AudioService.toggleMute();
      _isMuted = AudioService.isMuted;
    });
  }

  void _openSettings() {
    HapticsService.light();
    AudioService.playUiClick();
    final settings = ref.read(settingsControllerProvider);
    final cfg = LuduTheme.forMode(settings.appTheme);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cfg.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SettingsSheet(
        isDark: widget.isDark,
        onToggleTheme: widget.onToggleTheme,
        onRestartMatch: _confirmRestart,
      ),
    );
  }

  void _openPauseMenu() {
    HapticsService.light();
    AudioService.playUiClick();
    final settings = ref.read(settingsControllerProvider);
    final cfg = LuduTheme.forMode(settings.appTheme);
    showModalBottomSheet(
      context: context,
      backgroundColor: cfg.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'PAUSED',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.0,
                  color: Color(0xFFE9C46A),
                ),
              ),
              const SizedBox(height: 12),
              _PauseAction(
                icon: Icons.play_arrow_rounded,
                label: 'Resume',
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
              _PauseAction(
                icon: Icons.settings_rounded,
                label: 'Settings',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openSettings();
                },
              ),
              _PauseAction(
                icon: Icons.menu_book_rounded,
                label: 'Rules',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => RulesScreen(isDark: widget.isDark),
                  ));
                },
              ),
              _PauseAction(
                icon: Icons.refresh_rounded,
                label: 'Restart match',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmRestart();
                },
              ),
              _PauseAction(
                icon: Icons.logout_rounded,
                label: 'Quit to home',
                danger: true,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmExit();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmRestart() {
    HapticsService.light();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141D2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Restart Game?',
            style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        content: const Text(
          'Are you sure you want to restart the current match?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _rematchWith(ref.read(gameControllerProvider));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63946)),
            child: const Text('Restart', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _rematchWith(GameState st) {
    ref.read(gameControllerProvider.notifier).startNewGame(
          playerCount: st.players.length,
          playerNames: st.players.map((p) => p.name).toList(),
          playerColors: st.players.map((p) => p.color).toList(),
          teamMode: st.teamMode,
        );
  }

  void _confirmExit() {
    HapticsService.light();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF141D2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Quit this game?',
            style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        content: const Text(
          'Your progress is saved, so you can resume from the home screen.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep playing'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onNewGame();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE63946)),
            child: const Text('Quit', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _primaryAction(GameState gameState, GameController controller) {
    if (_boardAnimating || _passFreeze) return;
    _autoMoveTimer?.cancel();
    if (gameState.canRollDice) {
      controller.rollDice();
      _afterRoll(ref.read(gameControllerProvider));
    } else if (gameState.mustSelectToken &&
        gameState.movableTokenIds.length == 1) {
      controller.moveToken(gameState.movableTokenIds.first);
    }
  }

  void _afterRoll(GameState state) {
    if (state.phase != GamePhase.playing) return;
    if (state.currentDiceRoll == null) {
      setState(() => _passFreeze = true);
      _freezeTimer?.cancel();
      _freezeTimer = Timer(const Duration(milliseconds: 900), () {
        if (mounted) setState(() => _passFreeze = false);
      });
      return;
    }
    final autoMove = ref.read(settingsControllerProvider).autoMove;
    if (autoMove && state.mustSelectToken) {
      final idx = state.currentPlayerIndex;
      final roll = state.currentDiceRoll!;
      if (state.movableTokenIds.length != 1) return;
      _autoMoveTimer?.cancel();
      _autoMoveTimer = Timer(const Duration(milliseconds: 650), () {
        if (!mounted) return;
        final fresh = ref.read(gameControllerProvider);
        final controller = ref.read(gameControllerProvider.notifier);
        if (fresh.phase == GamePhase.playing &&
            fresh.currentPlayerIndex == idx &&
            fresh.currentDiceRoll == roll &&
            fresh.mustSelectToken &&
            fresh.movableTokenIds.length == 1 &&
            !_boardAnimating &&
            !_passFreeze) {
          controller.moveToken(fresh.movableTokenIds.first);
        }
      });
    }
  }

  /// Measures the reserved dice slots and glides the single overlay dice
  /// to the active slot. Slots reserve empty space so the 110 dp dice —
  /// parked 12 dp beside the active chip on the board-facing side — never
  /// overlaps text or borders.
  void _syncDicePosition(LudoColor active, bool isTopActive) {
    final slotKey = isTopActive ? _topSlotKey : _bottomSlotKey;
    final stackBox =
        _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final slotBox =
        slotKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || slotBox == null) return;
    final Offset slotTopLeft = slotBox.localToGlobal(Offset.zero);
    final Offset stackTopLeft = stackBox.globalToLocal(slotTopLeft);
    final Size slotSize = slotBox.size;
    // Dice sits centered vertically in the slot, nudged ~8 dp toward the
    // active side so Red→Green (and Blue→Yellow) still glides visibly
    // while keeping >=12 dp gaps to both chips.
    final bool leftActive = active == LudoColor.red || active == LudoColor.blue;
    final double dx = leftActive ? -8.0 : 8.0;
    final Offset center = Offset(
      stackTopLeft.dx + slotSize.width / 2 + dx,
      stackTopLeft.dy + slotSize.height / 2,
    );
    if (_diceCenter != center || _diceCenterFor != active) {
      setState(() {
        _diceCenter = center;
        _diceCenterFor = active;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameControllerProvider);
    final controller = ref.read(gameControllerProvider.notifier);
    final settings = ref.watch(settingsControllerProvider);
    final isDark = settings.isDark;
    final cfg = LuduTheme.forMode(settings.appTheme, isDark: isDark);

    SystemChrome.setSystemUIOverlayStyle(
      (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: cfg.backgroundGradient.last,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
    );

    if (gameState.phase == GamePhase.finished) {
      return RankingScreen(
        gameState: gameState,
        onRematch: () => _rematchWith(gameState),
        onNewGame: widget.onNewGame,
      );
    }

    final activePlayer = gameState.currentPlayer;
    final isActivePlayerRolling = activePlayer.finishRank == null;
    final singleMovable = gameState.mustSelectToken &&
        gameState.movableTokenIds.length == 1;
    final canRoll = isActivePlayerRolling &&
        (gameState.canRollDice || singleMovable) &&
        !_boardAnimating &&
        !_passFreeze;

    // Is active dice in top half of screen (Red or Green)?
    final isTopActive = activePlayer.color == LudoColor.red ||
        activePlayer.color == LudoColor.green;
    final isDiceRotated = settings.faceToFaceMode && isTopActive;

    // Measure slots after layout so the overlay dice parks exactly in the
    // reserved gap (never overlapping text/borders).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncDicePosition(activePlayer.color, isTopActive);
    });

    return Scaffold(
      backgroundColor: cfg.backgroundGradient[0],
      body: Stack(
        children: [
          // Tasteful themed background (vignette + pattern + glow).
          Positioned.fill(
            child: CustomPaint(
              painter: _BackgroundPainter(
                bgColor: cfg.backgroundGradient[0],
                accentColor: cfg.boardInlayLine,
                isDark: isDark,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: cfg.backgroundGradient.map((c) => c.withOpacity(0.93)).toList(),
              ),
            ),
            child: SafeArea(
              child: Stack(
                key: _stackKey,
                children: [
                  // Main layout column — balanced spacers center the board.
                  Column(
                    children: [
                      // Slim top bar (38dp)
                      SizedBox(
                        height: _topBarHeight,
                        child: _buildTopBar(gameState, cfg, isDark),
                      ),

                      // Top balancing spacer (mirrors the bottom one).
                      const Expanded(flex: 1, child: SizedBox.shrink()),

                      // Top player row with reserved middle dice slot.
                      _buildPanelRow(
                        gameState,
                        controller,
                        settings,
                        cfg,
                        const [topLeft, topRight],
                        isTopRow: true,
                        slotKey: _topSlotKey,
                      ),

                      // Chips sit close to the board (12 dp).
                      const SizedBox(height: _chipBoardGap),

                      // Center square board: 10 dp safe inset + shadow so
                      // edge tokens (glow/lift included) are never clipped.
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: _boardSideInset),
                        child: AspectRatio(
                          aspectRatio: 1.0,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(
                                      isDark ? 0.55 : 0.30),
                                  blurRadius: 28,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: cfg.boardInlayLine.withOpacity(
                                      isDark ? 0.16 : 0.10),
                                  blurRadius: 42,
                                  spreadRadius: 1,
                                  offset: Offset.zero,
                                ),
                              ],
                            ),
                            child: LudoBoard(
                              gameState: gameState,
                              timeScale: settings.timeScale,
                              themeMode: settings.appTheme,
                              themeConfig: cfg,
                              isDark: isDark,
                              onTokenSelected: (tokenId) {
                                if (_boardAnimating || _passFreeze) return;
                                _autoMoveTimer?.cancel();
                                controller.moveToken(tokenId);
                              },
                              onAnimatingChanged: (v) {
                                if (mounted) {
                                  setState(() => _boardAnimating = v);
                                }
                              },
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: _chipBoardGap),

                      // Bottom player row with reserved middle dice slot.
                      _buildPanelRow(
                        gameState,
                        controller,
                        settings,
                        cfg,
                        const [bottomLeft, bottomRight],
                        isTopRow: false,
                        slotKey: _bottomSlotKey,
                      ),

                      // Bottom balancing spacer — equals the top one.
                      const Expanded(flex: 1, child: SizedBox.shrink()),
                    ],
                  ),

                  // Single gliding large dice (110 dp). Parks in the
                  // reserved slot beside the active chip; glides over
                  // 450 ms when the turn passes.
                  if (_diceCenter != null)
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeInOutCubic,
                      left: _diceCenter!.dx - _diceSize / 2,
                      top: _diceCenter!.dy - _diceSize / 2,
                      width: _diceSize,
                      height: _diceSize,
                      child: DiceWidget(
                        value: gameState.currentDiceRoll,
                        isRolling: false,
                        canRoll: canRoll,
                        activeColor: activePlayer.color,
                        size: _diceSize,
                        timeScale: settings.timeScale,
                        isRotated: isDiceRotated,
                        themeMode: settings.appTheme,
                        themeConfig: cfg,
                        onRoll: () => _primaryAction(gameState, controller),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Row of two large player chips with a reserved middle dice slot.
  /// The slot stays empty (same size) when this row is inactive, so chips
  /// never shift and the overlay dice never overlaps text or borders.
  Widget _buildPanelRow(
    GameState gameState,
    GameController controller,
    GameSettings settings,
    LuduThemeConfig cfg,
    List<LudoColor> slotColors, {
    required bool isTopRow,
    GlobalKey? slotKey,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: SizedBox(
        height: _rowHeight,
        child: Row(
          crossAxisAlignment: isTopRow
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _slot(
                gameState,
                controller,
                settings,
                cfg,
                slotColors[0],
                isTopRow: isTopRow,
              ),
            ),
            const SizedBox(width: _diceGap),
            // Reserved dice gap: 126 dp wide so the 110 dp dice keeps a
            // true 12 dp gap to the active chip with room to nudge toward
            // the active side for a visible within-row glide. Stays the
            // same size when this row is inactive so chips never shift.
            Container(
              key: slotKey,
              width: _diceSlotWidth,
              height: _rowHeight,
              color: Colors.transparent,
            ),
            const SizedBox(width: _diceGap),
            Expanded(
              child: _slot(
                gameState,
                controller,
                settings,
                cfg,
                slotColors[1],
                isTopRow: isTopRow,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slot(
    GameState gameState,
    GameController controller,
    GameSettings settings,
    LuduThemeConfig cfg,
    LudoColor color, {
    required bool isTopRow,
  }) {
    final index = gameState.players.indexWhere((p) => p.color == color);
    if (index == -1) return const SizedBox.shrink();

    final player = gameState.players[index];
    final isActive =
        index == gameState.currentPlayerIndex && player.finishRank == null;
    final singleMovable = gameState.mustSelectToken &&
        gameState.movableTokenIds.length == 1;
    final canRoll = isActive &&
        (gameState.canRollDice || singleMovable) &&
        !_boardAnimating &&
        !_passFreeze;

    Player? partner;
    if (gameState.teamMode) {
      for (final p in gameState.players) {
        if (p.teamId == player.teamId && p.id != player.id) {
          partner = p;
        }
      }
    }

    final isRotated = isTopRow && settings.faceToFaceMode;

    return PlayerPanel(
      player: player,
      playerIndex: index,
      isActive: isActive,
      diceValue: isActive ? gameState.currentDiceRoll : null,
      canRoll: canRoll,
      onRoll: () => _primaryAction(gameState, controller),
      isDark: widget.isDark,
      teamMode: gameState.teamMode,
      partner: partner,
      timeScale: settings.timeScale,
      isRotated: isRotated,
      themeConfig: cfg,
    );
  }

  /// Slim top bar: back, title, sound, pause menu.
  Widget _buildTopBar(GameState gameState, LuduThemeConfig cfg, bool isDark) {
    // Rebuild with real icons (kept as a closure for brevity).
    Widget btn(IconData icon, String tooltip, VoidCallback onTap) {
      return Tooltip(
        message: tooltip,
        child: Material(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : Colors.black.withOpacity(0.06),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 34,
              height: 34,
              child: Icon(
                icon,
                size: 18,
                color: isDark ? Colors.white : const Color(0xFF1B1812),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Row(
        children: [
          btn(
            Icons.arrow_back_rounded,
            'Quit game',
            _confirmExit,
          ),
          const SizedBox(width: 8),
          Text(
            'LUDU',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 3.0,
              color: cfg.boardInlayLine,
            ),
          ),
          const Spacer(),
          btn(
            _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            _isMuted ? 'Unmute' : 'Mute',
            _toggleMute,
          ),
          const SizedBox(width: 8),
          btn(
            Icons.pause_rounded,
            'Menu',
            _openPauseMenu,
          ),
        ],
      ),
    );
  }
}

class _PauseAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _PauseAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFE63946) : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        tileColor: Colors.white.withOpacity(danger ? 0.05 : 0.03),
        leading: Icon(icon, color: color),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        onTap: () {
          HapticsService.light();
          AudioService.playUiClick();
          onTap();
        },
      ),
    );
  }
}

/// Tasteful themed background: vignette + subtle pattern + board glow.
class _BackgroundPainter extends CustomPainter {
  const _BackgroundPainter({
    required this.bgColor,
    required this.accentColor,
    required this.isDark,
  });

  final Color bgColor;
  final Color accentColor;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    // Vignette edges.
    final vigPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(isDark ? 0.55 : 0.18),
        ],
        stops: const [0.55, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vigPaint);

    // Subtle diamond pattern woven across the whole backdrop.
    final linePaint = Paint()
      ..color = accentColor.withOpacity(isDark ? 0.05 : 0.035)
      ..strokeWidth = 1.0;
    const step = 46.0;
    for (double x = -size.height; x < size.width + size.height; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height), linePaint);
      canvas.drawLine(Offset(x + size.height, 0), Offset(x, size.height), linePaint);
    }

    // Faint gold-dust dots scattered in top and bottom thirds.
    final dotPaint = Paint()
      ..color = accentColor.withOpacity(isDark ? 0.07 : 0.04)
      ..style = PaintingStyle.fill;

    final rng = math.Random(42); // fixed seed → stable layout
    final zones = [
      Rect.fromLTWH(0, 0, size.width, size.height * 0.28),
      Rect.fromLTWH(0, size.height * 0.72, size.width, size.height * 0.28),
    ];
    for (final zone in zones) {
      for (int i = 0; i < 30; i++) {
        final x = zone.left + rng.nextDouble() * zone.width;
        final y = zone.top + rng.nextDouble() * zone.height;
        final r = 1.5 + rng.nextDouble() * 3.0;
        canvas.drawCircle(Offset(x, y), r, dotPaint);
      }
    }

    // Soft board pedestal glow — gold circle behind board center.
    final cx = size.width / 2;
    final cy = size.height / 2;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.5,
        colors: [
          accentColor.withOpacity(isDark ? 0.12 : 0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: size.width * 0.55));
    canvas.drawCircle(Offset(cx, cy), size.width * 0.55, glowPaint);
  }

  @override
  bool shouldRepaint(_BackgroundPainter old) =>
      old.bgColor != bgColor || old.accentColor != accentColor || old.isDark != isDark;
}
