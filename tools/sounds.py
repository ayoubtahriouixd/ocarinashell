#!/usr/bin/env python3
"""Original UI sounds with an ocarina timbre -> assets/sounds/*.wav (48 kHz, 16-bit, stereo).

Synthesis (numpy only): near-sine tone with weak odd harmonics, breath noise through a resonator tuned to the
note (the 'chiff' of the attack), delayed vibrato, and a low-passed synthetic hall reverb. All melodies use the
A-minor pentatonic (A C D E G), so any two sounds played together stay consonant.
  startup   7-note phrase (greeter / session start)     notify    E5 → A5
  critical  E5 E5 A5, a little louder                    lock      E5 → C5 → A4 (closing)
  unlock    A4 → C5 → E5 → A5 (opening)                  tick      G5, 60 ms, almost dry (volume release)
  farewell  E5 → A4, soft and long (before power off)
Played with `pw-play`; never in Shinobi, Do Not Disturb or while locked (except unlock).

usage: python3 tools/sounds.py [outdir=assets/sounds]
"""
import math
import pathlib
import sys
import wave

import numpy as np

K = pathlib.Path(__file__).resolve().parent.parent
SR = 48000
NOTE = {"A4": 440.0, "C5": 523.25, "D5": 587.33, "E5": 659.26, "G5": 783.99, "A5": 880.0, "C6": 1046.5}


def biquad_bandpass(x, f0, q):
    w0 = 2 * math.pi * f0 / SR
    alpha = math.sin(w0) / (2 * q)
    b0, b1, b2 = alpha, 0.0, -alpha
    a0, a1, a2 = 1 + alpha, -2 * math.cos(w0), 1 - alpha
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, xi in enumerate(x):
        yi = b0 * xi + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, xi, y1, yi
        y[i] = yi
    return y


def onepole_lowpass(x, fc):
    a = math.exp(-2 * math.pi * fc / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, xi in enumerate(x):
        acc = (1 - a) * xi + a * acc
        y[i] = acc
    return y


def ocarina(freq, dur, vel=1.0, rng=None):
    rng = rng or np.random.default_rng(0)
    n = int(SR * (dur + 0.12))
    t = np.arange(n) / SR
    att, rel = 0.028, 0.11
    env = np.clip(t / att, 0, 1) ** 1.6
    env *= np.where(t < dur, 1.0, np.exp(-(t - dur) / (rel / 3)))
    env *= 1 - 0.18 * np.clip((t - att) / max(dur, 0.05), 0, 1)          # gentle decay while held
    vib = 1 + 0.0042 * np.sin(2 * math.pi * 5.3 * t) * np.clip((t - 0.16) / 0.25, 0, 1)
    phase = 2 * math.pi * np.cumsum(freq * vib) / SR
    tone = np.sin(phase) + 0.10 * np.sin(2 * phase + 0.3) + 0.075 * np.sin(3 * phase + 1.1) + 0.012 * np.sin(5 * phase)
    noise = rng.normal(0, 1, n)
    breath = biquad_bandpass(noise, freq, 9.0) * 0.35 + onepole_lowpass(noise, 2400) * 0.04
    chiff = np.exp(-t / 0.035) * 1.6 + 0.35
    sig = (tone * 0.9 + breath * chiff) * env * vel
    return sig


def reverb_ir(seconds=1.35, rt60=1.1, seed=5):
    rng = np.random.default_rng(seed)
    n = int(SR * seconds)
    t = np.arange(n) / SR
    decay = np.exp(-6.91 * t / rt60)
    irs = []
    for ch in range(2):
        noise = rng.normal(0, 1, n) * decay
        noise = onepole_lowpass(noise, 3800)          # dark hall: no fizzy highs
        noise[:int(SR * 0.012)] *= np.linspace(0, 1, int(SR * 0.012))
        irs.append(noise / np.sqrt(np.sum(noise ** 2)))
    return irs


def convolve(x, ir):
    n = len(x) + len(ir) - 1
    nfft = 1 << (n - 1).bit_length()
    return np.fft.irfft(np.fft.rfft(x, nfft) * np.fft.rfft(ir, nfft), nfft)[:n]


def render(events, wet=0.28, tail=1.1, peak_db=-6.0, seed=1):
    """events: list of (start_s, note, dur_s, velocity, pan -1..1)."""
    rng = np.random.default_rng(seed)
    end = max(s + d for s, _, d, _, _ in events) + 0.15
    n = int(SR * end)
    dry = np.zeros((2, n))
    for s, note, d, v, pan in events:
        sig = ocarina(NOTE[note], d, v, rng)
        i = int(SR * s)
        sig = sig[: n - i]
        gl, gr = math.cos((pan + 1) * math.pi / 4), math.sin((pan + 1) * math.pi / 4)
        dry[0, i:i + len(sig)] += sig * gl
        dry[1, i:i + len(sig)] += sig * gr
    irl, irr = reverb_ir()
    tail_n = int(SR * tail) if wet > 0 else int(SR * 0.05)
    out = np.zeros((2, n + tail_n))
    out[:, :n] += dry * (1 - wet * 0.5)
    if wet > 0:
        for ch, ir in ((0, irl), (1, irr)):
            rv = convolve(dry[ch], ir)[: n + tail_n]
            out[ch, : len(rv)] += rv * wet
    fade = int(SR * 0.25)
    out[:, -fade:] *= np.linspace(1, 0, fade) ** 2
    out *= 10 ** (peak_db / 20) / (np.max(np.abs(out)) + 1e-9)
    return out


def write_wav(path, stereo):
    pcm = (np.clip(stereo.T, -1, 1) * 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())


SOUNDS = {
    "startup": dict(events=[(0.00, "A4", 0.22, .80, -.25), (0.24, "C5", 0.22, .82, -.15), (0.48, "D5", 0.22, .84, -.05),
                            (0.72, "E5", 0.40, .90, .05), (1.16, "G5", 0.22, .82, .15), (1.40, "E5", 0.22, .80, .05),
                            (1.66, "A5", 0.95, .92, 0.0)], wet=0.34, tail=1.4, peak_db=-7.0),
    "notify": dict(events=[(0.0, "E5", 0.13, .80, -.1), (0.15, "A5", 0.42, .90, .1)], wet=0.26, peak_db=-7.0),
    "critical": dict(events=[(0.0, "E5", 0.12, .95, -.1), (0.16, "E5", 0.12, .95, .1), (0.32, "A5", 0.55, 1.0, 0.0)],
                     wet=0.22, peak_db=-4.0),
    "lock": dict(events=[(0.0, "E5", 0.14, .85, .15), (0.16, "C5", 0.14, .82, 0.0), (0.32, "A4", 0.50, .80, -.15)],
                 wet=0.30, peak_db=-7.0),
    "unlock": dict(events=[(0.0, "A4", 0.09, .80, -.2), (0.10, "C5", 0.09, .82, -.07), (0.20, "E5", 0.09, .86, .07),
                           (0.30, "A5", 0.48, .92, .2)], wet=0.28, peak_db=-6.5),
    "tick": dict(events=[(0.0, "G5", 0.06, .6, 0.0)], wet=0.0, tail=0.05, peak_db=-15.0),
    # the farewell (Dengen → power off / reboot / log out): one soft falling breath, quieter than everything else
    "farewell": dict(events=[(0.0, "E5", 0.30, .62, .1), (0.34, "A4", 1.10, .58, -.05)], wet=0.40, tail=1.5,
                     peak_db=-11.0),
}


def main(out):
    out = pathlib.Path(out)
    out.mkdir(parents=True, exist_ok=True)
    for name, spec in SOUNDS.items():
        audio = render(**spec)
        write_wav(out / f"{name}.wav", audio)
        print(f"{name + '.wav':14s} {audio.shape[1] / SR:4.2f} s  peak {20 * np.log10(np.max(np.abs(audio))):5.1f} dBFS")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else K / "assets" / "sounds")
