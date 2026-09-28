"""Pass 12: the Pale Lands' sounds, synthesised (no downloads): the toll that
greets a keeper the first time in (a deep, slowly dying boom under a hiss of
falling ash) and the mountain's distant rumbles.

    python tools/audio/make_pale_audio.py

Writes game/Forest/audio/generated/pale_sting.wav, pale_rumble_0.wav,
pale_rumble_1.wav (mono, 22050 Hz, 16-bit).
"""
import os
import wave

import numpy as np

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "Forest", "audio", "generated")
RATE = 22050


def brown(n, rng):
    x = np.cumsum(rng.standard_normal(n))
    x -= np.linspace(x[0], x[-1], n)
    return x / (np.max(np.abs(x)) + 1e-9)


def lowpass(x, cutoff):
    a = np.exp(-2.0 * np.pi * cutoff / RATE)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def write(name, x):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.9
    data = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print("wrote", name, "%.1fs" % (len(x) / RATE))


def sting(rng):
    t = np.arange(int(RATE * 6.0)) / RATE
    # A deep toll: a falling sine with a slow beat, and its octave, dying away.
    f = 58.0 - 18.0 * (1 - np.exp(-t * 0.8))
    phase = 2 * np.pi * np.cumsum(f) / RATE
    boom = np.sin(phase) * np.exp(-t * 0.55) * (1 + 0.25 * np.sin(2 * np.pi * 0.9 * t))
    boom += 0.35 * np.sin(2 * phase) * np.exp(-t * 0.9)
    attack = np.minimum(1.0, t / 0.03)
    # Under it, a hiss of ash (low-passed noise), swelling then fading.
    hiss = lowpass(rng.standard_normal(len(t)), 900.0) * 0.12 * np.sin(np.pi * np.clip(t / 6.0, 0, 1)) ** 2
    return boom * attack + hiss


def rumble(rng, seconds):
    n = int(RATE * seconds)
    t = np.arange(n) / RATE
    r = lowpass(brown(n, rng), 120.0)
    env = np.sin(np.pi * np.clip(t / seconds, 0, 1)) ** 1.5
    return r * env


def main():
    os.makedirs(OUT, exist_ok=True)
    rng = np.random.default_rng(1212)
    write("pale_sting.wav", sting(rng))
    write("pale_rumble_0.wav", rumble(rng, 3.5))
    write("pale_rumble_1.wav", rumble(rng, 4.5))


if __name__ == "__main__":
    main()
