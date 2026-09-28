#!/usr/bin/env python3
"""Synthesise the Ludu sound-effect set.

Everything is generated from scratch with additive synthesis plus
frequency-domain filtered noise, so each cue is designed rather than sampled.
Outputs 16-bit mono 44.1 kHz WAV files into assets/audio/.
"""

import math
import os
import struct
import wave

import numpy as np

SR = 44100
# tool/ -> project root
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")

rng = np.random.default_rng(20240617)


# ---------------------------------------------------------------- primitives


def silence(dur):
    return np.zeros(int(SR * dur), dtype=np.float64)


def exp_env(n, tau, attack=0.002, curve=1.0):
    """Percussive envelope: short linear attack, exponential decay."""
    t = np.arange(n) / SR
    a = int(max(1, attack * SR))
    env = np.exp(-t / max(tau, 1e-6))
    env[:a] *= np.linspace(0.0, 1.0, a)
    return env ** curve if curve != 1.0 else env


def tone(freq, dur, tau=None, attack=0.004, phase=0.0, detune=0.0):
    n = int(SR * dur)
    t = np.arange(n) / SR
    if tau is None:
        tau = dur / 3.0
    w = 2 * math.pi * freq * t
    x = np.sin(w + phase)
    if detune:
        w2 = 2 * math.pi * (freq * (1 + detune)) * t
        x = 0.6 * x + 0.4 * np.sin(w2 + phase)
    return x * exp_env(n, tau, attack)


def partials(freq, ratios, amps, dur, tau, attack=0.003):
    """Additive tone with several partials, each decaying faster."""
    n = int(SR * dur)
    out = np.zeros(n)
    for r, a in zip(ratios, amps):
        if a <= 0:
            continue
        t = np.arange(n) / SR
        # Higher partials die away faster, as on a real struck object.
        out += a * np.sin(2 * math.pi * freq * r * t) * exp_env(n, tau / (0.5 + 0.5 * r), attack)
    return out


def band_noise(dur, centre, q, tau, attack=0.0015, gain=1.0):
    """Band-passed noise burst via FFT shaping (crisp, no filter ringing)."""
    n = int(SR * dur)
    x = rng.normal(0.0, 1.0, n) * exp_env(n, tau, attack)
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(n, 1.0 / SR)
    # One-pole resonance approximation on the magnitude response.
    ratio = np.clip(freqs / max(centre, 1.0), 1e-4, 1e4)
    mag = 1.0 / np.sqrt(1.0 + (q * (ratio - 1.0 / ratio)) ** 2)
    y = np.fft.irfft(spec * mag, n)
    peak = np.max(np.abs(y)) or 1.0
    return (y / peak) * gain


def sweep_noise(dur, f_start, f_end, tau, attack=0.01):
    """Noise through a sweeping band-pass: a whoosh."""
    n = int(SR * dur)
    x = rng.normal(0.0, 1.0, n)
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(n, 1.0 / SR)
    mag = np.zeros_like(freqs)
    steps = 96
    for i in range(steps):
        t0 = i / steps
        t1 = (i + 1) / steps
        fc = f_start * (f_end / f_start) ** t0
        lo, hi = f_start * (f_end / f_start) ** t0, f_start * (f_end / f_start) ** t1
        mask = (freqs >= min(lo, hi)) & (freqs < max(lo, hi))
        mag[mask] += math.sin(math.pi * (t0 + t1) / 2)
    mag /= mag.max() or 1.0
    y = np.fft.irfft(spec * mag, n)
    return y * exp_env(n, tau, attack)


def mix_into(dest, src, at):
    i = int(at * SR)
    if i >= len(dest):
        dest = np.pad(dest, (0, i + len(src) - len(dest)))
    end = min(len(dest), i + len(src))
    dest[i:end] += src[: end - i]
    return dest


def fit(x, n):
    """Pad or trim a signal so layered components share one length."""
    x = np.asarray(x, dtype=np.float64)
    if len(x) == n:
        return x
    if len(x) > n:
        return x[:n]
    return np.pad(x, (0, n - len(x)))


def reverb(x, mix=0.22, decay=0.30, pre=0.012):
    """Small Schroeder-ish tail: a few taps plus a decaying diffuse tail."""
    n = len(x)
    d1, d2, d3 = int(0.011 * SR), int(0.019 * SR), int(0.031 * SR)
    out = x.copy()
    for d, g in ((d1, 0.55), (d2, 0.42), (d3, 0.30)):
        if d < n:
            out[d:] += x[: n - d] * g * (1.0 - mix)
    tail_len = int(decay * SR)
    ir = rng.normal(0, 1, tail_len) * np.exp(-np.arange(tail_len) / (decay * SR * 0.35))
    ir[int(pre * SR):] *= 0.6
    ir /= np.max(np.abs(ir)) or 1.0
    wet = np.convolve(x, ir)[:n]
    wet /= (np.max(np.abs(wet)) or 1.0)
    return (1 - mix) * out + mix * wet * np.max(np.abs(x))


def finish(x, peak=0.89, fade_out=0.0):
    """Soft-knee limiter, de-click tail, normalise."""
    x = np.asarray(x, dtype=np.float64)
    if fade_out > 0:
        k = int(fade_out * SR)
        if k > 1 and len(x) > k:
            x[-k:] *= np.linspace(1.0, 0.0, k)
    m = np.max(np.abs(x))
    if m > 0:
        x = x / m
    # Gentle saturation keeps transients round instead of brittle.
    x = np.tanh(x * 1.18) / math.tanh(1.18)
    x = x * peak
    return x


def write(name, x, peak=0.89):
    pcm = np.clip(x, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype("<i2")
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    dur = len(pcm) / SR
    rms = float(np.sqrt(np.mean((pcm / 32768.0) ** 2)))
    print(f"  {name:20s} {dur:5.2f}s  peak={np.max(np.abs(pcm))/32768:.2f}  rms={rms:.3f}")


def clack(body_hz=430, bright=1750, dur=0.055, gain=1.0, seed_shift=0.0):
    """One die-on-board clack: bright transient plus a wooden body."""
    n = int(SR * dur)
    y = fit(band_noise(dur, bright * (1 + seed_shift), 2.6, dur * 0.30, gain=0.85), n)
    y += fit(tone(body_hz * (1 + seed_shift * 0.5), dur, tau=dur * 0.55, attack=0.0012), n) * 0.75
    y += fit(tone(body_hz * 1.9 * (1 + seed_shift), dur, tau=dur * 0.30, attack=0.001), n) * 0.25
    return y * gain


# ------------------------------------------------------------------ the cues


def make_dice_roll():
    """A die tumbling in a cup: clacks accelerate, then one solid landing."""
    x = silence(0.78)
    gaps = [0.085, 0.072, 0.062, 0.054, 0.047, 0.041, 0.036, 0.031, 0.027, 0.024]
    t = 0.0
    for i, g in enumerate(gaps):
        jitter = float(rng.uniform(-0.09, 0.09))
        gain = 0.30 + 0.42 * (i / len(gaps))
        x = mix_into(x, clack(430 * (1 + jitter), 1750 * (1 + jitter), 0.05, gain, jitter), t)
        t += g
    # Final settle, louder and lower.
    x = mix_into(x, clack(390, 1450, 0.085, 1.0), t + 0.012)
    x = mix_into(x, band_noise(0.16, 3200, 1.4, 0.030, gain=0.16), t + 0.012)
    return finish(reverb(x, mix=0.12, decay=0.14), 0.86, fade_out=0.04)


def make_token_step():
    """Soft board tick, repeated up to 56x per move so it must stay gentle."""
    n = int(SR * 0.075)
    x = fit(band_noise(0.075, 2450, 3.0, 0.020, gain=0.55), n)
    x += fit(tone(610, 0.075, tau=0.032, attack=0.0012), n) * 0.55
    x += fit(tone(915, 0.055, tau=0.022, attack=0.001), n) * 0.18
    return finish(x, 0.42, fade_out=0.02)


def make_token_out():
    """Leaving the yard: a lift-off whoosh that lands on the board."""
    x = silence(0.40)
    x = mix_into(x, sweep_noise(0.22, 320, 2600, 0.075, attack=0.012) * 0.55, 0.0)
    x = mix_into(x, clack(370, 1500, 0.075, 0.95), 0.185)
    x = mix_into(x, band_noise(0.12, 2900, 1.5, 0.028, gain=0.20), 0.185)
    return finish(reverb(x, mix=0.14, decay=0.16), 0.84, fade_out=0.05)


def make_capture():
    """The payoff hit: a low thump, an inharmonic metal clash and a dark fall."""
    x = silence(0.70)
    # Impact transient
    x = mix_into(x, band_noise(0.10, 1500, 0.9, 0.026, gain=0.95), 0.0)
    # Descending body thump
    n = int(SR * 0.34)
    t = np.arange(n) / SR
    sweep = 105.0 * np.exp(-t * 6.5) + 48.0
    x[:n] += np.sin(2 * math.pi * np.cumsum(sweep) / SR) * exp_env(n, 0.11, 0.001)
    # Inharmonic metal clash
    metal = partials(
        523.0,
        [1.0, 1.51, 2.13, 2.86, 3.41],
        [0.50, 0.30, 0.22, 0.14, 0.09],
        0.55,
        tau=0.20,
        attack=0.0015,
    )
    x = mix_into(x, metal, 0.006)
    return finish(reverb(x, mix=0.20, decay=0.30), 0.95, fade_out=0.06)


def make_six():
    """Reward cue: a bright ascending bell arpeggio."""
    x = silence(0.62)
    notes = [(523.25, 0.00), (659.25, 0.065), (783.99, 0.13), (1046.50, 0.195)]
    for f, at in notes:
        b = partials(
            f,
            [1.0, 2.00, 3.01, 4.18, 5.43],
            [0.46, 0.20, 0.11, 0.06, 0.03],
            0.55,
            tau=0.17,
            attack=0.002,
        )
        x = mix_into(x, b, at)
        x = mix_into(x, band_noise(0.05, f * 4, 3.0, 0.010, gain=0.10), at)
    return finish(reverb(x, mix=0.24, decay=0.34), 0.80, fade_out=0.07)


def make_safe():
    """A warm, reassuring two-note chime for reaching home."""
    x = silence(0.52)
    for f, at, a in ((392.00, 0.00, 0.52), (587.33, 0.085, 0.44), (783.99, 0.17, 0.30)):
        b = partials(
            f,
            [1.0, 2.0, 3.0, 4.0],
            [a, a * 0.34, a * 0.15, a * 0.07],
            0.50,
            tau=0.19,
            attack=0.003,
        )
        x = mix_into(x, b, at)
    return finish(reverb(x, mix=0.26, decay=0.32), 0.78, fade_out=0.07)


def make_victory():
    """Triumphant fanfare: rising run, then a sustained major chord."""
    x = silence(1.85)
    run = [(523.25, 0.00), (659.25, 0.085), (783.99, 0.17), (1046.50, 0.255), (1318.51, 0.34)]
    for f, at in run:
        b = partials(
            f,
            [1.0, 2.0, 3.0, 4.0, 5.0],
            [0.42, 0.18, 0.10, 0.05, 0.03],
            0.70,
            tau=0.15,
            attack=0.002,
        )
        x = mix_into(x, b, at)
    # Sustained C major chord with a slow swell.
    chord = np.zeros(int(SR * 1.35))
    for f, a in ((523.25, 0.50), (659.25, 0.38), (783.99, 0.34), (1046.50, 0.26)):
        n = len(chord)
        t = np.arange(n) / SR
        vib = 1.0 + 0.0035 * np.sin(2 * math.pi * 5.2 * t)
        chord += a * np.sin(2 * math.pi * f * vib * t) * exp_env(n, 0.62, 0.06)
        chord += a * 0.22 * np.sin(2 * math.pi * f * 2 * t) * exp_env(n, 0.40, 0.06)
    x = mix_into(x, chord, 0.44)
    # Cymbal-ish sparkle on the downbeat.
    x = mix_into(x, band_noise(0.5, 6200, 0.8, 0.16, gain=0.14), 0.44)
    return finish(reverb(x, mix=0.30, decay=0.45), 0.86, fade_out=0.10)


def main():
    os.makedirs(OUT, exist_ok=True)
    print("Rendering sound set:")
    write("dice_roll.wav", make_dice_roll())
    write("token_step.wav", make_token_step())
    write("token_out.wav", make_token_out())
    write("capture.wav", make_capture())
    write("six.wav", make_six())
    write("safe.wav", make_safe())
    write("victory.wav", make_victory())


if __name__ == "__main__":
    main()
