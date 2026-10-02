# Ludu sound effects — license note

All files under `assets/audio/` (including `glass/` and `minimal/`
subdirectories) are **original studio-crafted samples** created for the
Ludu project with acoustic modeling (decaying harmonic partials, filtered
noise transients, warm envelopes).

- License: **CC0 1.0 Universal (public domain)** — free for any use,
  no attribution required.
- Technical: 44.1 kHz mono 16-bit WAV, peak-normalized to approx
  **-12 dBFS**, short fade tails, no clipping.
- Feel: soft, warm, tactile, calm. No beeps or 8-bit tones.

Cue map:

| File | Cue | Length |
|------|-----|--------|
| `token_step.wav` | soft wooden/ceramic tock per hop (<120 ms) | ~95 ms |
| `dice_roll.wav` | dice rattle on wood + landing thud | ~0.80 s |
| `dice_result.wav` | soft settle thud on the final bounce | ~0.15 s |
| `token_out.wav` | gentle pop + light shimmer (leaving base) | ~0.28 s |
| `capture.wav` | soft thud + short falling tone | ~0.38 s |
| `safe.wav` | warm bell / glass chime (reaching center) | ~0.90 s |
| `six.wav` | short ascending chime (6 / bonus roll) | ~0.60 s |
| `no_move.wav` | quiet muted tick (no legal move) | ~70 ms |
| `victory.wav` | elegant fanfare | ~2.0 s |
| `ui_click.wav` | very light UI click | ~35 ms |

Packs:

- `audio/*.wav` — **Wood** (default): warm, woody, lowpassed.
- `audio/glass/*.wav` — **Glass**: brighter partials, longer shimmer.
- `audio/minimal/*.wav` — **Minimal**: softer, shorter, subtler.

Regenerate with `python3 tool/generate_sounds.py` (requires `numpy`).
