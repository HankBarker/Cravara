"""Procedural foley for the Keeper's movement feel (no samples, no downloads).

Writes 16-bit mono 44.1 kHz WAVs next to this script:
  step_grass_N  soft grass shuffle (heel swish + toe roll + blade crackle)
  step_moss_N   darker, damper grass (dark meadow)
  step_dirt_N   dirt tap (low thump + grit)
  step_wood_N   wooden floor knock (damped board modes, heel + toe)
  step_water_N  wading splish (swept noise + bubbles)
  splash_N      entering / leaving water
  whoosh_N      tool swing (swept band-pass air, peaks ~40% in)
  rustle_N      soft cloth / armour rustle (roll, gear)
  hit_N         tool striking a creature (crack + body thump + slap)
  hurt_N        the Keeper taking a hit (dull thud + soft falling tone)
  pop_N         picking something up: a small round bloop, very soft
  amb_wind_0    ambience bed (seamless 16 s loop): soft wind, slow gusts, leaves
  amb_day_0     ambience bed (loop): a far, gentle haze of buzzing insects
  amb_night_0   ambience bed (loop): a chorus of crickets
  chirp_N       a single bug nearby (a cricket's trill, a beetle's click-buzz)

Every file is levelled to a per-family short-term K-weighted loudness (steps
-17, splash/whoosh -14, hit/hurt -10; peaks soft-limited at -1 dBFS), so
AudioManager.play_foley()'s quiet playback dB compare across families.
Deterministic: re-running rewrites identical files.  Usage:  python make_feel_sfx.py
Then import: bash tools/keeper/godot.sh --headless --import
"""
import os
import wave

import numpy as np
from scipy import signal

SR = 44100
OUT = os.path.dirname(os.path.abspath(__file__))


# ------------------------------------------------------------------ helpers
def n_of(seconds):
    return int(round(SR * seconds))


def env(n, attack, tau, hold=0.0):
    """Linear attack, optional hold, exponential decay (seconds)."""
    t = np.arange(n) / SR
    a = np.clip(t / attack, 0.0, 1.0) if attack > 0 else np.ones(n)
    d = np.exp(-np.maximum(t - attack - hold, 0.0) / tau)
    return a * d


def bump(n, centre, width):
    t = np.arange(n) / SR
    return np.exp(-0.5 * ((t - centre) / width) ** 2)


def band(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], btype="band", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def low(x, f, order=2):
    sos = signal.butter(order, f, btype="low", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def high(x, f, order=2):
    sos = signal.butter(order, f, btype="high", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def svf_band(x, freqs, q):
    """Time-varying state-variable band-pass (Chamberlin), freqs per sample."""
    out = np.zeros_like(x)
    low_s = 0.0
    band_s = 0.0
    damp = 1.0 / q
    for i in range(len(x)):
        f = 2.0 * np.sin(np.pi * min(freqs[i], SR / 6.0) / SR)
        high_s = x[i] - low_s - damp * band_s
        band_s += f * high_s
        low_s += f * band_s
        out[i] = band_s
    return out


def sweep_sine(n, f_start, f_end, curve="exp"):
    t = np.arange(n) / SR
    dur = n / SR
    if curve == "exp":
        k = np.log(f_end / f_start) / dur
        phase = 2 * np.pi * f_start * (np.exp(k * t) - 1.0) / k
    else:
        phase = 2 * np.pi * (f_start * t + 0.5 * (f_end - f_start) / dur * t * t)
    return np.sin(phase)


def delayed(x, seconds, n):
    out = np.zeros(n)
    d = n_of(seconds)
    if d < n:
        m = min(len(x), n - d)
        out[d:d + m] = x[:m]
    return out


def crackle(rng, n, count, window, lo, hi):
    x = np.zeros(n)
    for _ in range(count):
        p = int(rng.uniform(0.0, window) * SR)
        if p < n:
            x[p] += rng.uniform(-1.0, 1.0)
    return band(x, lo, hi)


def bubble(rng, n, at):
    """A small rising bubble chirp starting at `at` seconds."""
    length = n_of(rng.uniform(0.018, 0.032))
    f0 = rng.uniform(380, 700)
    chirp = sweep_sine(length, f0, f0 * rng.uniform(1.8, 2.6)) * env(length, 0.001, rng.uniform(0.006, 0.012))
    return delayed(chirp, at, n)


def _biquad(kind, gain_db, q, fc):
    a_ = 10 ** (gain_db / 40)
    w0 = 2 * np.pi * fc / SR
    alpha = np.sin(w0) / (2 * q)
    c = np.cos(w0)
    if kind == "shelf":
        b = [a_ * ((a_ + 1) + (a_ - 1) * c + 2 * np.sqrt(a_) * alpha), -2 * a_ * ((a_ - 1) + (a_ + 1) * c), a_ * ((a_ + 1) + (a_ - 1) * c - 2 * np.sqrt(a_) * alpha)]
        a = [(a_ + 1) - (a_ - 1) * c + 2 * np.sqrt(a_) * alpha, 2 * ((a_ - 1) - (a_ + 1) * c), (a_ + 1) - (a_ - 1) * c - 2 * np.sqrt(a_) * alpha]
    else:
        b = [(1 + c) / 2, -(1 + c), (1 + c) / 2]
        a = [1 + alpha, -2 * c, 1 - alpha]
    return np.array(b) / a[0], np.array(a) / a[0]


def loudness(x, window=0.1):
    """Short-term K-weighted loudness (BS.1770 pre-filter), max over 100 ms."""
    b, a = _biquad("shelf", 4.0, 1 / np.sqrt(2), 1500.0)
    y = signal.lfilter(b, a, x)
    b, a = _biquad("highpass", 0.0, 0.5, 38.0)
    y = signal.lfilter(b, a, y)
    w = n_of(window)
    energy = np.convolve(y ** 2, np.ones(w) / w, "valid") if len(y) > w else np.array([np.mean(y ** 2)])
    return -0.691 + 10 * np.log10(energy.max() + 1e-12)


def finish(x, fade_ms=12.0, target=-17.0):
    """DC/fades, then level to `target` short-term loudness (LU below full
    scale) so AudioManager's playback dB are comparable across families;
    peaks above -1 dBFS are soft-limited."""
    x = x - np.mean(x)
    fi = min(len(x), n_of(0.0015))
    x[:fi] *= np.linspace(0.0, 1.0, fi)
    fo = min(len(x), n_of(fade_ms / 1000.0))
    x[-fo:] *= np.cos(np.linspace(0.0, np.pi / 2, fo)) ** 2
    for _ in range(3):
        x = x * 10 ** ((target - loudness(x)) / 20)
        ceiling = 0.891  # -1 dBFS
        if np.max(np.abs(x)) > ceiling:
            x = ceiling * np.tanh(x / ceiling)
    return x


def soft_clip(x, drive):
    return np.tanh(x * drive) / np.tanh(drive)


def write(name, x):
    data = np.clip(np.round(x * 32767.0), -32768, 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


# ------------------------------------------------------------------ sounds
def step_grass(rng, damp=False):
    n = n_of(0.17)
    t = np.arange(n) / SR
    heel = sweep_sine(n, rng.uniform(85, 110), 60, "lin") * env(n, 0.002, 0.018) * 0.30
    lo_cut = 1400 if damp else 1900
    hi_cut = 5200 if damp else 7200
    swish = band(rng.standard_normal(n), lo_cut, hi_cut) * env(n, 0.006, 0.034)
    toe = delayed(band(rng.standard_normal(n), lo_cut + 500, hi_cut) * env(n, 0.004, 0.026), rng.uniform(0.030, 0.048), n)
    blades = crackle(rng, n, rng.integers(7, 13), 0.075, 2600, 8500) * env(n, 0.001, 0.05)
    x = heel + swish * 0.55 + toe * 0.35 + blades * (0.30 if damp else 0.55)
    return finish(low(x, 6500 if damp else 9000), 20, -17.0)


def step_dirt(rng):
    n = n_of(0.15)
    thump = sweep_sine(n, rng.uniform(150, 175), rng.uniform(85, 100)) * env(n, 0.0015, 0.022)
    body = band(rng.standard_normal(n), 300, 1500) * env(n, 0.002, 0.020) * 0.95
    grit = band(rng.standard_normal(n), 2000, 6000) * env(n, 0.001, 0.012) * 0.30
    gravel = crackle(rng, n, rng.integers(3, 7), 0.045, 1800, 5500) * 0.45
    toe = delayed(band(rng.standard_normal(n), 450, 2400) * env(n, 0.002, 0.014), rng.uniform(0.028, 0.040), n) * 0.45
    x = soft_clip(thump * 0.8 + body + grit + gravel + toe, 1.6)
    return finish(low(x, 7000), 18, -17.0)


def board_knock(rng, n, f1, amp):
    t = np.arange(n) / SR
    x = np.zeros(n)
    for ratio, tau, a in ((1.0, 0.065, 1.0), (2.32, 0.042, 0.55), (3.87, 0.026, 0.33), (5.41, 0.016, 0.18)):
        f = f1 * ratio * rng.uniform(0.985, 1.015)
        x += np.sin(2 * np.pi * f * t + rng.uniform(0, 6.28)) * np.exp(-t / tau) * a
    click = band(rng.standard_normal(n), 1500, 5500) * env(n, 0.0005, 0.0022) * 0.8
    return (x * env(n, 0.0012, 10.0) + click) * amp


def step_wood(rng):
    n = n_of(0.22)
    heel = board_knock(rng, n, rng.uniform(175, 230), 1.0)
    toe = delayed(board_knock(rng, n, rng.uniform(200, 260), 0.45), rng.uniform(0.034, 0.052), n)
    x = heel + toe
    return finish(low(x, 6000), 30, -17.0)


def step_water(rng):
    n = n_of(0.24)
    t = np.arange(n) / SR
    centre = 700 + 1500 * np.clip(t / 0.08, 0, 1) - 500 * np.clip((t - 0.08) / 0.16, 0, 1)
    body = svf_band(rng.standard_normal(n), centre, 1.6) * env(n, 0.008, 0.050)
    x = body * 0.9
    for _ in range(rng.integers(2, 5)):
        x += bubble(rng, n, rng.uniform(0.015, 0.14)) * rng.uniform(0.18, 0.34)
    x += sweep_sine(n, 190, 110) * env(n, 0.002, 0.020) * 0.25
    return finish(low(x, 7000), 30, -17.0)


def splash(rng, big=True):
    n = n_of(0.52 if big else 0.36)
    t = np.arange(n) / SR
    plop = sweep_sine(n, rng.uniform(150, 175), 75) * env(n, 0.002, 0.040) * 0.55
    centre = 800 + 1900 * np.clip(t / 0.06, 0, 1) - 1300 * np.clip((t - 0.06) / 0.3, 0, 1)
    main = svf_band(rng.standard_normal(n), centre, 1.3) * env(n, 0.010, 0.11 if big else 0.07)
    slosh = delayed(band(rng.standard_normal(n), 380, 1800) * env(n, 0.012, 0.075), rng.uniform(0.10, 0.15), n) * (0.55 if big else 0.35)
    x = plop + main + slosh
    for _ in range(rng.integers(5, 9) if big else rng.integers(3, 5)):
        x += bubble(rng, n, rng.uniform(0.03, 0.30 if big else 0.2)) * rng.uniform(0.15, 0.3)
    return finish(low(x, 8000), 60, -14.0)


def whoosh(rng):
    dur = rng.uniform(0.21, 0.27)
    n = n_of(dur)
    u = np.arange(n) / n
    peak = rng.uniform(1300, 1800)
    rise = 320 + (peak - 320) * np.clip(u / 0.4, 0, 1) ** 1.3
    fall = peak - (peak - 430) * np.clip((u - 0.4) / 0.6, 0, 1) ** 0.8
    centre = np.where(u < 0.4, rise, fall)
    a, b = 1.6, 2.4  # beta-shaped swell peaking ~40% in
    shape = (u ** a) * ((1 - u) ** b)
    shape /= shape.max()
    noise = rng.standard_normal(n)
    core = svf_band(noise, centre, 1.25)
    air = svf_band(rng.standard_normal(n), centre * 2.1, 2.0) * 0.28
    x = (core + air) * shape
    return finish(low(high(x, 180), 6000), 25, -14.0)


def rustle(rng, creak=False):
    n = n_of(0.24)
    shape = np.zeros(n)
    for _ in range(rng.integers(4, 7)):
        shape += bump(n, rng.uniform(0.015, 0.19), rng.uniform(0.008, 0.022)) * rng.uniform(0.4, 1.0)
    cloth = band(rng.standard_normal(n), 1100, 5200) * shape
    x = cloth
    if creak:
        m = n_of(0.07)
        tt = np.arange(m) / SR
        f = rng.uniform(55, 85)
        pulses = signal.sawtooth(2 * np.pi * f * tt) * env(m, 0.01, 0.03)
        x = x + delayed(band(pulses, 500, 1600), rng.uniform(0.04, 0.12), n) * 0.35
    return finish(low(x, 7500), 30, -17.0)


def hit(rng):
    n = n_of(0.22)
    crack = band(rng.standard_normal(n), 1800, 7000) * env(n, 0.0004, 0.005) * 0.7
    thwack = band(rng.standard_normal(n), 550, 2600) * env(n, 0.0008, 0.030) * 1.1
    body = sweep_sine(n, rng.uniform(170, 195), rng.uniform(70, 85)) * env(n, 0.001, 0.050) * 0.9
    ring = np.sin(2 * np.pi * rng.uniform(420, 520) * np.arange(n) / SR) * env(n, 0.001, 0.022) * 0.25
    x = soft_clip(crack + thwack + body + ring, 2.0)
    return finish(low(x, 8500), 40, -10.0)


def hurt(rng):
    n = n_of(0.32)
    thud = sweep_sine(n, rng.uniform(135, 150), 68) * env(n, 0.0015, 0.070) * 0.8
    impact = band(rng.standard_normal(n), 380, 1800) * env(n, 0.001, 0.038) * 0.85
    crunch = band(rng.standard_normal(n), 1400, 4200) * env(n, 0.0008, 0.016) * 0.35
    tri = signal.sawtooth(2 * np.pi * np.cumsum(np.linspace(340, 185, n)) / SR, 0.5)
    tone = low(tri, 1800) * env(n, 0.006, 0.090) * 0.30
    x = soft_clip(thud + impact + crunch + tone, 1.8)
    return finish(low(x, 7000), 50, -10.0)


def thud(rng):
    """A heavy footfall or stomp: a deep falling boom, a dirt crunch and a
    short rumble tail (dinosaurs: stomps, heavy steps, charge impacts)."""
    n = n_of(0.46)
    boom = sweep_sine(n, rng.uniform(88, 102), rng.uniform(36, 42)) * env(n, 0.002, 0.16) * 1.0
    knock = sweep_sine(n, rng.uniform(170, 200), 80) * env(n, 0.001, 0.035) * 0.45
    crunch = band(rng.standard_normal(n), 220, 1400) * env(n, 0.0015, 0.045) * 0.55
    grit = band(rng.standard_normal(n), 1400, 3600) * env(n, 0.001, 0.02) * 0.18
    rumble = low(rng.standard_normal(n), 90) * env(n, 0.01, 0.2) * 0.9
    x = soft_clip(boom + knock + crunch + grit + rumble, 1.6)
    return finish(low(x, 5000), 60, -12.0)


def pop(rng, i):
    """Picking something up: a small, round bloop, like a bubble. A soft sine
    that glides up nearly an octave, a quieter lower partner, a breath of air
    and no click. Levelled low: it should sit under everything else."""
    n = n_of(0.09)
    f0 = 540 * (1 + 0.05 * (i - 1.5))
    tone = sweep_sine(n, f0, f0 * 1.85, "exp") * env(n, 0.003, 0.03)
    body = sweep_sine(n, f0 * 0.5, f0 * 0.9, "exp") * env(n, 0.003, 0.022) * 0.3
    air = band(rng.standard_normal(n), 2500, 7000) * env(n, 0.001, 0.008) * 0.04
    return finish(low(tone + body + air, 6000), 30, -19.0)


def seamless(x, overlap_s=2.0):
    """A loop that joins without a click: the last `overlap_s` crossfades
    (equal power) into the start, then is cut off."""
    k = n_of(overlap_s)
    head = x[:k].copy()
    tail = x[-k:]
    t = np.linspace(0.0, np.pi / 2, k)
    x = x[:-k].copy()
    x[:k] = head * np.sin(t) + tail * np.cos(t)
    return x


def loudness_long(x, window=0.4):
    """loudness() for long beds: the same K-weighting, the moving average by a
    running sum (the direct convolution is far too slow on 18 s of audio)."""
    b, a = _biquad("shelf", 4.0, 1 / np.sqrt(2), 1500.0)
    y = signal.lfilter(b, a, x)
    b, a = _biquad("highpass", 0.0, 0.5, 38.0)
    y = signal.lfilter(b, a, y)
    w = n_of(window)
    c = np.concatenate(([0.0], np.cumsum(y ** 2)))
    energy = (c[w:] - c[:-w]) / w
    return -0.691 + 10 * np.log10(energy.max() + 1e-12)


def level(x, target):
    """Loudness only (no fades: loops must stay seamless)."""
    x = x - np.mean(x)
    for _ in range(3):
        x = x * 10 ** ((target - loudness_long(x)) / 20)
    return np.clip(x, -0.89, 0.89)


def amb_wind(rng):
    n = n_of(18.0)
    t = np.arange(n) / SR
    base = low(band(rng.standard_normal(n), 60, 900), 700)
    gust = 0.55 + 0.45 * np.sin(2 * np.pi * t / 7.3 + 0.8) * np.sin(2 * np.pi * t / 4.1)
    whistle = band(rng.standard_normal(n), 900, 1600) * (0.08 + 0.06 * np.sin(2 * np.pi * t / 5.3))
    leaves = band(rng.standard_normal(n), 2500, 7000) * (np.clip(np.sin(2 * np.pi * t / 6.1 + 1.3), 0, 1) ** 3) * 0.12
    return level(seamless(base * gust + whistle * gust + leaves), -30.0)


def amb_day(rng):
    n = n_of(18.0)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for i in range(5):
        f = rng.uniform(3800, 6200)
        buzz = band(rng.standard_normal(n), f - 150, f + 150)
        trem = 0.5 + 0.5 * np.sin(2 * np.pi * rng.uniform(28, 55) * t)
        swell = np.clip(np.sin(2 * np.pi * t / rng.uniform(5.0, 9.0) + rng.uniform(0, 6.28)), 0, 1) ** 2
        x += buzz * trem * swell * rng.uniform(0.5, 1.0)
    hum = low(rng.standard_normal(n), 300) * 0.15
    return level(seamless(x + hum), -34.0)


def cricket(rng, n, f, rate, every, gain):
    x = np.zeros(n)
    t = 0.0
    while t < n / SR:
        for p in range(int(rng.integers(3, 5))):
            at = int((t + p / rate) * SR)
            k = n_of(0.014)
            if at + k >= n:
                break
            tone = np.sin(2 * np.pi * f * np.arange(k) / SR) * np.sin(np.linspace(0, np.pi, k))
            x[at:at + k] += tone * gain
        t += every * rng.uniform(0.85, 1.15)
    return x


def amb_night(rng):
    n = n_of(18.0)
    x = np.zeros(n)
    for i in range(6):
        x += cricket(rng, n, rng.uniform(3900, 4900), rng.uniform(22, 30), rng.uniform(0.55, 1.1), rng.uniform(0.3, 1.0))
    bed = low(rng.standard_normal(n), 400) * 0.05
    return level(seamless(x + bed), -32.0)


def chirp(rng, i):
    if i % 2 == 0:
        n = n_of(0.5)
        return finish(cricket(rng, n, rng.uniform(4200, 5200), 26, 0.6, 1.0), 20, -26.0)
    # A beetle's click, then a short buzz.
    n = n_of(0.35)
    click = band(rng.standard_normal(n), 2000, 6000) * env(n, 0.0005, 0.004)
    buzz = band(rng.standard_normal(n), 900, 1800) * np.sin(2 * np.pi * 70 * np.arange(n) / SR) * bump(n, 0.18, 0.06)
    return finish(click + buzz * 0.6, 30, -26.0)


def main():
    plan = [
        ("step_grass", 5, lambda r, i: step_grass(r)),
        ("step_moss", 4, lambda r, i: step_grass(r, damp=True)),
        ("step_dirt", 5, lambda r, i: step_dirt(r)),
        ("step_wood", 5, lambda r, i: step_wood(r)),
        ("step_water", 5, lambda r, i: step_water(r)),
        ("splash", 3, lambda r, i: splash(r, big=i < 2)),
        ("whoosh", 4, lambda r, i: whoosh(r)),
        ("rustle", 4, lambda r, i: rustle(r, creak=i % 2 == 1)),
        ("hit", 4, lambda r, i: hit(r)),
        ("hurt", 3, lambda r, i: hurt(r)),
        ("thud", 4, lambda r, i: thud(r)),
        ("pop", 4, lambda r, i: pop(r, i)),
        ("amb_wind", 1, lambda r, i: amb_wind(r)),
        ("amb_day", 1, lambda r, i: amb_day(r)),
        ("amb_night", 1, lambda r, i: amb_night(r)),
        ("chirp", 4, lambda r, i: chirp(r, i)),
    ]
    for family_index, (family, count, make) in enumerate(plan):
        for i in range(count):
            rng = np.random.default_rng(7919 * (family_index + 1) + 104729 * i)
            x = make(rng, i)
            write("%s_%d" % (family, i), x)
            rms = 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)
            print("%-14s %5.0f ms  rms %6.1f dBFS  loud %6.1f  peak %5.1f dBFS" % ("%s_%d" % (family, i), len(x) * 1000 / SR, rms, loudness(x), 20 * np.log10(np.max(np.abs(x)))))


if __name__ == "__main__":
    main()
