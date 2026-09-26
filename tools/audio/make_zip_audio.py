"""The field pack's zipper (pass 14): synthesized, no samples.

    python tools/audio/make_zip_audio.py

Writes game/Forest/audio/leather/pack-unzip.wav and pack-zip.wav (22.05 kHz
mono, 16-bit). A zipper is a run of tiny teeth clicks over a cloth rasp; the
pack opening ends in a soft leather flap, the closing in the clasp's click.
Deterministic (a fixed seed), so the files only change with this script.
"""
import os
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "game", "Forest", "audio", "leather")
RATE = 22050


def lowpass(x, cut):
    """One-pole low-pass (cut in Hz)."""
    a = np.exp(-2.0 * np.pi * cut / RATE)
    y = np.zeros_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1.0 - a) * x[i] + a * acc
        y[i] = acc
    return y


def highpass(x, cut):
    return x - lowpass(x, cut)


def teeth(rng, seconds, start_rate, end_rate, curve=1.0, loud=1.0):
    """The zipper's teeth: clicks whose rate glides from start to end."""
    n = int(seconds * RATE)
    out = np.zeros(n)
    t = 0.0
    while t < seconds:
        f = (t / seconds) ** curve
        rate = start_rate + (end_rate - start_rate) * f
        i = int(t * RATE)
        length = int(0.0022 * RATE)
        click = rng.normal(0.0, 1.0, length) * np.exp(-np.linspace(0.0, 7.0, length))
        # A tooth rings a little (a tiny metal-and-fabric resonance).
        ring = np.sin(2 * np.pi * rng.uniform(2600, 3400) * np.arange(length) / RATE) * np.exp(-np.linspace(0.0, 9.0, length))
        seg = (click * 0.7 + ring * 0.5) * loud * rng.uniform(0.7, 1.0)
        end = min(n, i + length)
        out[i:end] += seg[:end - i]
        t += 1.0 / rate * rng.uniform(0.85, 1.15)
    return out


def rasp(rng, seconds, loud=0.12):
    """The cloth dragging under the slider."""
    n = int(seconds * RATE)
    noise = highpass(rng.normal(0.0, 1.0, n), 900.0)
    env = np.sin(np.linspace(0.0, np.pi, n)) ** 0.6
    return noise * env * loud


def thump(seconds, freq, loud):
    """A soft low flap (the pack falling open) or a clasp's knock."""
    n = int(seconds * RATE)
    t = np.arange(n) / RATE
    return np.sin(2 * np.pi * freq * t * (1.0 - 0.35 * t / seconds)) * np.exp(-t * 18.0) * loud


def write(name, x):
    x = x / max(1e-6, np.max(np.abs(x))) * 0.82
    fade = int(0.004 * RATE)
    x[:fade] *= np.linspace(0.0, 1.0, fade)
    x[-fade:] *= np.linspace(1.0, 0.0, fade)
    data = (x * 32767).astype("<i2").tobytes()
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    print("wrote", os.path.relpath(path, ROOT), "%.2f s" % (len(x) / RATE))


def main():
    rng = np.random.default_rng(1414)
    # Unzip: a quick pull that speeds up, then the flap falls open.
    pull = 0.30
    open_ = np.zeros(int(0.46 * RATE))
    z = teeth(rng, pull, 45.0, 150.0, curve=0.7) + rasp(rng, pull)
    open_[:len(z)] += z
    flap = thump(0.16, 95.0, 0.55) + lowpass(rng.normal(0.0, 1.0, int(0.16 * RATE)), 700.0) * np.exp(-np.arange(int(0.16 * RATE)) / RATE * 22.0) * 0.5
    at = int(0.27 * RATE)
    open_[at:at + len(flap)] += flap
    write("pack-unzip.wav", open_)
    # Zip: a steady pull, a little slower at the end, then the clasp clicks shut.
    pull = 0.24
    close = np.zeros(int(0.34 * RATE))
    z = teeth(rng, pull, 130.0, 70.0, curve=1.3, loud=0.9) + rasp(rng, pull, 0.09)
    close[:len(z)] += z
    knock = thump(0.08, 180.0, 0.3)
    knock[:int(0.05 * RATE)] += thump(0.05, 1400.0, 0.5)
    clasp = knock
    at = int(0.25 * RATE)
    close[at:at + len(clasp)] += clasp[:len(close) - at]
    write("pack-zip.wav", close)


if __name__ == "__main__":
    main()
