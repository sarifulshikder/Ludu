# 🎲 Ludu — Pure Luck Ludo (Android)

[![CI & Android Build](https://github.com/sarifulshikder/Ludu/actions/workflows/ci.yml/badge.svg)](https://github.com/sarifulshikder/Ludu/actions/workflows/ci.yml)

A local **pass-and-play** Ludo game for 2–4 players on one Android device.

**Core guarantee:** Every dice roll uses Dart's `Random.secure()` (cryptographically secure RNG) with **zero** dynamic difficulty adjustment, zero weighting, and zero pity mechanics. A 120,000-roll chi-square test verifies uniform 1–6 distribution.

---

## Features

- 2–4 players, pass-and-play on one device
- Standard Ludo rules (6 to exit, safe stars, exact roll to finish, 3×6 cancellation)
- 3D tumbling dice animation + haptic feedback
- Step-by-step token movement along the path
- Capture micro-interaction with double-rumble haptics
- Confetti celebration on finishing
- Full dark / light theme toggle
- Responsive layout (phones & tablets)
- Jewel-toned visual identity (Ruby, Emerald, Amber Gold, Sapphire)
- Complete finish ranking: 1st through last

## Quick Start (Docker — no local Flutter/SDK needed)

### Prerequisites
- Docker installed on your machine

### 1. Pull the Flutter image
```bash
docker pull ghcr.io/cirruslabs/flutter:stable
```

### 2. Get dependencies
```bash
docker run --rm \
  -v $(pwd):/app \
  -w /app \
  ghcr.io/cirruslabs/flutter:stable \
  flutter pub get
```

### 3. Run tests
```bash
docker run --rm \
  -v $(pwd):/app \
  -w /app \
  ghcr.io/cirruslabs/flutter:stable \
  flutter test
```

Expected output: **10/10 tests passed** including the 120,000-roll fairness test.

### 4. Build release APK
```bash
docker run --rm \
  -v $(pwd):/app \
  -w /app \
  ghcr.io/cirruslabs/flutter:stable \
  flutter build apk --release
```

> **Low-spec server tip:** If builds hang on a machine with ≤7 GB RAM, Gradle is already configured with `-Xmx2048m` and `daemon=false` in [`android/gradle.properties`](android/gradle.properties).

The APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

### 5. Install on device (USB debugging enabled)
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## Project Structure

```
lib/
├── core/
│   ├── board_coordinates.dart   # 15×15 grid, 52-tile path, 8 safe squares
│   └── theme/
│       └── ludu_theme.dart      # Dark + Light jewel theme
├── models/
│   ├── ludo_color.dart          # 4 player colors with jewel gradients
│   ├── token.dart               # Token state (step index)
│   ├── player.dart              # Player identity & rankings
│   └── game_state.dart          # Full immutable game state
├── services/
│   ├── dice_service.dart        # Random.secure() — pure luck RNG
│   └── haptics_service.dart     # Haptic micro-interactions
├── state/
│   └── game_controller.dart     # Riverpod StateNotifier — all game rules
└── ui/
    ├── board/
    │   ├── board_painter.dart   # Custom canvas board rendering
    │   ├── ludo_board.dart      # Board + step-by-step token animation
    │   └── token_widget.dart    # 3D jewel token with pulse glow
    ├── screens/
    │   ├── setup_screen.dart    # Player count + name setup
    │   ├── game_screen.dart     # Main gameplay screen
    │   └── victory_screen.dart  # Final standings + confetti
    └── widgets/
        ├── dice_widget.dart         # 3D tumbling dice
        ├── turn_indicator_banner.dart  # Active player banner
        └── confetti_overlay.dart    # Victory celebration particles

test/
├── dice_fairness_test.dart   # 120,000-roll chi-square uniformity proof
├── game_rules_test.dart      # All Ludo rules unit tested
└── widget_test.dart          # Setup → Game screen smoke test
```

## State Management

Uses **Riverpod** (`StateNotifierProvider`). Game state is fully immutable — every action returns a new `GameState` copy.

## Gameplay Rules

| Rule | Implementation |
|------|---------------|
| 6 to exit base | `getMovableTokenIds`: `roll == 6` for base tokens |
| Extra turn on 6 | Turn not advanced when roll is 6 (unless just finished) |
| Three 6s forfeit | 3rd consecutive 6 → immediate turn pass, no move |
| Safe squares | 8 fixed squares: `{0, 8, 13, 21, 26, 34, 39, 47}` |
| Capture | Lands on occupied non-safe square → opponent returns to base |
| Exact roll home | `targetStep > 56` → token not movable |
| Complete ranking | Game continues until all players finish (1st–last) |

## Building for iOS

The iOS scaffolding is already in the `ios/` directory. To build:
```bash
open ios/Runner.xcworkspace  # macOS + Xcode required
```

---

**applicationId:** `com.idcnetwork.ludu`  
**Min SDK:** Android 5.0 (API 21)  
**Flutter:** 3.44.0 stable  
**State management:** flutter_riverpod 2.6.1
