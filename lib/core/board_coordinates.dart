import 'dart:ui';
import '../models/ludo_color.dart';

class BoardPoint {
  final double row;
  final double col;

  const BoardPoint(this.row, this.col);

  Offset toOffset(double tileSize) {
    return Offset(col * tileSize + tileSize / 2, row * tileSize + tileSize / 2);
  }
}

class BoardCoordinates {
  /// The 8 standard safe/starred squares on the 52-tile outer track.
  /// 0: Red Start, 13: Green Start, 26: Yellow Start, 39: Blue Start
  /// 8, 21, 34, 47: Additional 4 safe star tiles.
  static const Set<int> safeSquares = {0, 8, 13, 21, 26, 34, 39, 47};

  static bool isSafeSquare(int globalTrackIndex) {
    return safeSquares.contains(globalTrackIndex);
  }

  /// 52 Outer track coordinates on a 15x15 board (0 to 14 index).
  static const List<BoardPoint> outerTrack = [
    // Red Start & lane East (0-4)
    BoardPoint(6, 1), // 0: Red start [Safe]
    BoardPoint(6, 2), // 1
    BoardPoint(6, 3), // 2
    BoardPoint(6, 4), // 3
    BoardPoint(6, 5), // 4

    // Top arm North (5-10)
    BoardPoint(5, 6), // 5
    BoardPoint(4, 6), // 6
    BoardPoint(3, 6), // 7
    BoardPoint(2, 6), // 8: Safe Star
    BoardPoint(1, 6), // 9
    BoardPoint(0, 6), // 10

    // Top cap (11-12)
    BoardPoint(0, 7), // 11
    BoardPoint(0, 8), // 12

    // Green Start & lane South (13-17)
    BoardPoint(1, 8), // 13: Green start [Safe]
    BoardPoint(2, 8), // 14
    BoardPoint(3, 8), // 15
    BoardPoint(4, 8), // 16
    BoardPoint(5, 8), // 17

    // Right arm East (18-23)
    BoardPoint(6, 9),  // 18
    BoardPoint(6, 10), // 19
    BoardPoint(6, 11), // 20
    BoardPoint(6, 12), // 21: Safe Star
    BoardPoint(6, 13), // 22
    BoardPoint(6, 14), // 23

    // Right cap (24-25)
    BoardPoint(7, 14), // 24
    BoardPoint(8, 14), // 25

    // Yellow Start & lane West (26-30)
    BoardPoint(8, 13), // 26: Yellow start [Safe]
    BoardPoint(8, 12), // 27
    BoardPoint(8, 11), // 28
    BoardPoint(8, 10), // 29
    BoardPoint(8, 9),  // 30

    // Bottom arm South (31-36)
    BoardPoint(9, 8),  // 31
    BoardPoint(10, 8), // 32
    BoardPoint(11, 8), // 33
    BoardPoint(12, 8), // 34: Safe Star
    BoardPoint(13, 8), // 35
    BoardPoint(14, 8), // 36

    // Bottom cap (37-38)
    BoardPoint(14, 7), // 37
    BoardPoint(14, 6), // 38

    // Blue Start & lane North (39-43)
    BoardPoint(13, 6), // 39: Blue start [Safe]
    BoardPoint(12, 6), // 40
    BoardPoint(11, 6), // 41
    BoardPoint(10, 6), // 42
    BoardPoint(9, 6),  // 43

    // Left arm West (44-49)
    BoardPoint(8, 5), // 44
    BoardPoint(8, 4), // 45
    BoardPoint(8, 3), // 46
    BoardPoint(8, 2), // 47: Safe Star
    BoardPoint(8, 1), // 48
    BoardPoint(8, 0), // 49

    // Left cap (50-51)
    BoardPoint(7, 0), // 50
    BoardPoint(6, 0), // 51
  ];

  /// Home stretch tiles for each player (steps 51 to 55).
  static const Map<LudoColor, List<BoardPoint>> homeStretches = {
    LudoColor.red: [
      BoardPoint(7, 1),
      BoardPoint(7, 2),
      BoardPoint(7, 3),
      BoardPoint(7, 4),
      BoardPoint(7, 5),
    ],
    LudoColor.green: [
      BoardPoint(1, 7),
      BoardPoint(2, 7),
      BoardPoint(3, 7),
      BoardPoint(4, 7),
      BoardPoint(5, 7),
    ],
    LudoColor.yellow: [
      BoardPoint(7, 13),
      BoardPoint(7, 12),
      BoardPoint(7, 11),
      BoardPoint(7, 10),
      BoardPoint(7, 9),
    ],
    LudoColor.blue: [
      BoardPoint(13, 7),
      BoardPoint(12, 7),
      BoardPoint(11, 7),
      BoardPoint(10, 7),
      BoardPoint(9, 7),
    ],
  };

  /// Center Home finish destination (step 56).
  static const Map<LudoColor, BoardPoint> homeDestinations = {
    LudoColor.red: BoardPoint(7.0, 6.2),
    LudoColor.green: BoardPoint(6.2, 7.0),
    LudoColor.yellow: BoardPoint(7.0, 7.8),
    LudoColor.blue: BoardPoint(7.8, 7.0),
  };

  /// Base slot coordinates for 4 tokens per player.
  static const Map<LudoColor, List<BoardPoint>> baseSlots = {
    LudoColor.red: [
      BoardPoint(1.8, 1.8),
      BoardPoint(1.8, 3.8),
      BoardPoint(3.8, 1.8),
      BoardPoint(3.8, 3.8),
    ],
    LudoColor.green: [
      BoardPoint(1.8, 10.8),
      BoardPoint(1.8, 12.8),
      BoardPoint(3.8, 10.8),
      BoardPoint(3.8, 12.8),
    ],
    LudoColor.yellow: [
      BoardPoint(10.8, 10.8),
      BoardPoint(10.8, 12.8),
      BoardPoint(12.8, 10.8),
      BoardPoint(12.8, 12.8),
    ],
    LudoColor.blue: [
      BoardPoint(10.8, 1.8),
      BoardPoint(10.8, 3.8),
      BoardPoint(12.8, 1.8),
      BoardPoint(12.8, 3.8),
    ],
  };

  /// Resolves the (row, col) BoardPoint for a token at [step].
  /// [step]: -1 (in base), 0..50 (outer track), 51..55 (home stretch), 56 (finished).
  static BoardPoint getTokenPosition({
    required LudoColor color,
    required int tokenId,
    required int step,
  }) {
    if (step == -1) {
      return baseSlots[color]![tokenId.clamp(0, 3)];
    }
    if (step >= 0 && step <= 50) {
      final globalIndex = (color.startSquare + step) % 52;
      return outerTrack[globalIndex];
    }
    if (step >= 51 && step <= 55) {
      final stretchIndex = step - 51;
      return homeStretches[color]![stretchIndex];
    }
    // step >= 56
    return homeDestinations[color]!;
  }
}
