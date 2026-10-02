"""Generate premium-feel, royalty-free sound effects for Ludu.

Original studio-crafted samples (synthesized + processed with acoustic
modeling: decaying harmonic partials, filtered noise transients, warm
envelopes). No beeps or 8-bit tones. All files:
- 44.1 kHz mono 16-bit WAV
- Peak normalized to approx -12 dBFS (0.25), no clipping
- Short fade tails (5-15 ms) to avoid clicks
- Licensed CC0 (public domain) — see assets/audio/LICENSE_NOTE.md

Three packs: wood (default, warm), glass (bright), minimal (soft/subtle).
"""
import math
import os
import random
import struct
import wave

SR = 44100
PEAK = 0.251  # -12 dBFS

OUT_ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                         '..', 'assets', 'audio')

random.seed(20261002)


def sine(f, n, phase=0.0):
    return [math.sin(2 * math.pi * f * i / SR + phase) for i in range(n)]


def noise(n):
    return [random.uniform(-1.0, 1.0) for _ in range(n)]


def lowpass(x, alpha):
    """One-pole lowpass; smaller alpha = darker."""
    y = [0.0] * len(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += alpha * (v - acc)
        y[i] = acc
    return y


def highpass(x, alpha=0.95):
    y = [0.0] * len(x)
    prev_in, prev_out = 0.0, 0.0
    for i, v in enumerate(x):
        out = alpha * (prev_out + v - prev_in)
        y[i] = out
        prev_in, prev_out = v, out
    return y


def exp_decay(n, tau_ms):
    tau = tau_ms * SR / 1000.0
    return [math.exp(-i / tau) for i in range(n)]


def adsr_hit(n, attack_ms=2.0, decay_ms=60.0):
    a = max(1, int(attack_ms * SR / 1000.0))
    env = exp_decay(n, decay_ms)
    for i in range(min(a, n)):
        env[i] *= (i / a)
    return env


def apply(env, *parts):
    n = max(len(env), max((len(p) for p in parts), default=0))
    out = [0.0] * n
    for p in parts:
        for i in range(len(p)):
            out[i] += p[i]
    for i in range(n):
        e = env[i] if i < len(env) else 0.0
        out[i] *= e
    return out


def fade_tail(x, ms=10.0):
    f = max(1, int(ms * SR / 1000.0))
    if f >= len(x):
        return x
    for i in range(f):
        x[len(x) - f + i] *= 1.0 - (i / f)
    # 2ms fade-in to avoid clicks
    fi = max(1, int(2.0 * SR / 1000.0))
    for i in range(min(fi, len(x))):
        x[i] *= (i / fi)
    return x


def normalize(x, peak=PEAK):
    m = max(1e-9, max(abs(v) for v in x))
    g = peak / m
    return [v * g for v in x]


def save(name, x, pack_dir):
    x = fade_tail(normalize(x))
    path = os.path.join(pack_dir, name)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(struct.pack('<' + 'h' * len(x),
                                  *[max(-32768, min(32767, int(v * 32767)))
                                    for v in x]))
    print('wrote %s (%.2fs)' % (path, len(x) / SR))


def bell(freq, dur_ms, partials, decay_ms, attack_ms=2.0):
    n = int(dur_ms * SR / 1000.0)
    env = adsr_hit(n, attack_ms, decay_ms)
    parts = []
    for mult, amp in partials:
        parts.append([a * amp for a in sine(freq * mult, n)])
    return apply(env, *parts)


PACKS = {
    'wood': dict(bright=0.25, decay=1.0, gain=1.0, shimmer=0.35),
    'glass': dict(bright=0.85, decay=1.25, gain=0.95, shimmer=1.0),
    'minimal': dict(bright=0.45, decay=0.7, gain=0.7, shimmer=0.25),
}


def make_token_step(p):
    # Soft wooden/ceramic "tock", <120ms. ~95ms.
    n = int(95 * SR / 1000.0)
    body = sine(196.0, n)
    body2 = [b * 0.45 for b in sine(392.0, n)]
    knock = lowpass(noise(int(12 * SR / 1000.0)),
                    0.18 + 0.5 * p['bright'])
    knock += [0.0] * (n - len(knock))
    knock = [k * 0.9 for k in knock]
    env = adsr_hit(n, 1.5, 26.0 * p['decay'])
    return apply(env, body, body2, knock)


def make_dice_roll(p):
    # Real dice rattle on wood: 6 hits + landing thud. ~800ms.
    dur = 800
    n = int(dur * SR / 1000.0)
    out = [0.0] * n
    hits = [0, 90, 210, 350, 500, 640]
    for k, t in enumerate(hits):
        amp = 0.9 - 0.08 * k
        hn = int(28 * SR / 1000.0)
        burst = lowpass(noise(hn), 0.35 + 0.4 * p['bright'])
        env = adsr_hit(hn, 1.0, 9.0)
        start = int(t * SR / 1000.0)
        for i in range(hn):
            if start + i < n:
                out[start + i] += burst[i] * env[i] * amp
    # Landing thud at the end.
    tn = int(160 * SR / 1000.0)
    thud = sine(82.0, tn)
    thud2 = [t * 0.4 for t in sine(164.0, tn)]
    tenv = adsr_hit(tn, 2.0, 55.0 * p['decay'])
    start = int(640 * SR / 1000.0)
    for i in range(tn):
        if start + i < n:
            out[start + i] += (thud[i] + thud2[i]) * tenv[i] * 0.9
    return out


def make_dice_result(p):
    # Soft felt landing thud for the settle bounce. ~150ms, quiet.
    n = int(150 * SR / 1000.0)
    body = sine(95.0, n)
    soft = lowpass(noise(int(15 * SR / 1000.0)),
                   0.2 + 0.4 * p['bright'])
    soft += [0.0] * (n - len(soft))
    env = adsr_hit(n, 2.0, 30.0 * p['decay'])
    out = apply(env, body, [s * 0.5 for s in soft])
    return [v * 0.8 for v in out]


def make_token_out(p):
    # Gentle pop + light shimmer. ~280ms.
    n = int(280 * SR / 1000.0)
    # Pitch sweep 320 -> 640 Hz pop.
    pop = []
    for i in range(int(90 * SR / 1000.0)):
        f = 320.0 + (640.0 - 320.0) * (i / (90 * SR / 1000.0))
        pop.append(math.sin(2 * math.pi * f * i / SR))
    pop += [0.0] * (n - len(pop))
    shim = bell(2093.0, 280, [(1.0, 0.5), (1.5, 0.25)], 90.0 * p['decay'])
    env = adsr_hit(n, 2.0, 70.0 * p['decay'])
    out = apply(env, pop, [s * p['shimmer'] for s in shim])
    return out


def make_capture(p):
    # Soft thud + short falling tone 420 -> 160 Hz. ~380ms.
    n = int(380 * SR / 1000.0)
    th = sine(105.0, int(120 * SR / 1000.0))
    th += [0.0] * (n - len(th))
    fall = []
    fn = int(300 * SR / 1000.0)
    for i in range(fn):
        f = 420.0 + (160.0 - 420.0) * (i / fn)
        fall.append(math.sin(2 * math.pi * f * i / SR) * 0.6)
    fall = [0.0] * int(40 * SR / 1000.0) + fall
    fall += [0.0] * (n - len(fall))
    fall = fall[:n]
    env = adsr_hit(n, 2.0, 110.0 * p['decay'])
    return apply(env, th, fall)


def make_safe(p):
    # Warm bell / glass chime (E6-ish). ~900ms.
    partials = [(1.0, 0.6), (2.4, 0.28), (3.9, 0.16), (5.1, 0.08)]
    if p['bright'] > 0.6:
        partials = [(1.0, 0.55), (2.0, 0.3), (2.99, 0.22), (4.2, 0.14)]
    return bell(659.25, 900, partials, 320.0 * p['decay'])


def make_six(p):
    # Short ascending chime E5 -> B5. ~450ms.
    a = bell(659.25, 450, [(1.0, 0.6), (2.4, 0.25)], 130.0 * p['decay'])
    b = bell(987.77, 450, [(1.0, 0.6), (2.4, 0.25)], 150.0 * p['decay'])
    off = int(150 * SR / 1000.0)
    out = a + [0.0] * max(0, off + len(b) - len(a))
    for i in range(len(b)):
        out[off + i] += b[i] * 0.9
    return out


def make_no_move(p):
    # Quiet muted tick. ~70ms, deliberately soft.
    n = int(70 * SR / 1000.0)
    tick = lowpass(noise(int(10 * SR / 1000.0)), 0.15)
    tick += [0.0] * (n - len(tick))
    env = adsr_hit(n, 1.0, 14.0)
    out = apply(env, tick)
    return [v * 0.55 * p['gain'] for v in out]


def make_victory(p):
    # Elegant fanfare ~2s: C5 E5 G5 C6 arpeggio + warm pad.
    notes = [523.25, 659.25, 783.99, 1046.5]
    total = 2000
    n = int(total * SR / 1000.0)
    out = [0.0] * n
    starts = [0, 220, 440, 700]
    for f, st in zip(notes, starts):
        tone = bell(f, 1200, [(1.0, 0.6), (2.0, 0.22), (3.0, 0.12)],
                    420.0 * p['decay'], attack_ms=4.0)
        s = int(st * SR / 1000.0)
        for i in range(len(tone)):
            if s + i < n:
                out[s + i] += tone[i] * 0.7
    # Soft shimmer on top.
    shim = bell(2093.0, 2000, [(1.0, 0.3), (1.5, 0.15)],
                600.0 * p['decay'], attack_ms=10.0)
    s = int(700 * SR / 1000.0)
    for i in range(len(shim)):
        if s + i < n:
            out[s + i] += shim[i] * 0.35 * p['shimmer']
    return out


def make_ui_click(p):
    # Very light click. ~35ms, very quiet.
    n = int(35 * SR / 1000.0)
    c = highpass(noise(int(6 * SR / 1000.0)))
    c += [0.0] * (n - len(c))
    env = adsr_hit(n, 0.8, 7.0)
    out = apply(env, [v * 0.6 for v in c])
    return [v * 0.5 for v in out]


BUILDERS = {
    'token_step.wav': make_token_step,
    'dice_roll.wav': make_dice_roll,
    'dice_result.wav': make_dice_result,
    'token_out.wav': make_token_out,
    'capture.wav': make_capture,
    'safe.wav': make_safe,
    'six.wav': make_six,
    'no_move.wav': make_no_move,
    'victory.wav': make_victory,
    'ui_click.wav': make_ui_click,
}


def main():
    for pack, params in PACKS.items():
        if pack == 'wood':
            pack_dir = OUT_ROOT  # backward-compatible root paths
        else:
            pack_dir = os.path.join(OUT_ROOT, pack)
        os.makedirs(pack_dir, exist_ok=True)
        for name, fn in BUILDERS.items():
            save(name, fn(params), pack_dir)


if __name__ == '__main__':
    main()
