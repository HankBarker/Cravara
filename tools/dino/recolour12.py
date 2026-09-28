"""Pass 12: recolour an existing species' front/back drawing into a new beast's
colours, as the init image for its front/back restyle (redraw_view.py), so a
beast keeps the same hues when it turns.

Each drawing is split into a body and an accent (the stego's plates -> the
dimetrodon's sail; the allo's head crest -> the carnotaurus' horns) by hue;
each part's shades are mapped by brightness rank onto the matching ramp taken
from the beast's finished side view.

    python tools/dino/recolour12.py KEY VIEW SOURCE_IMAGE OUT [--scale S]

Ramps come from art/dino-v2/new/KEY/east.png (the chosen side view).
"""
import colorsys
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
NEW = os.path.join(ROOT, "art", "dino-v2", "new")

# Per beast: which hues count as accent in the source drawing and in the
# beast's own side view (degrees, min saturation).
ACCENT = {
    "dimetrodon": {"src": (15, 65, 0.45), "dst": (0, 40, 0.45)},  # stego plates -> red/orange sail
    "carno": {"src": (400, 401, 1.1), "dst": (400, 401, 1.1)},  # no accent (horns drawn on by hand)
    "yuty": {"src": (400, 401, 1.1), "dst": (400, 401, 1.1)},  # all white: the rex's spikes become fur
    "proto": {"src": (15, 40, 0.5), "dst": (15, 35, 0.5)},  # the frill keeps its orange
    "anky": {"src": (400, 401, 1.1), "dst": (400, 401, 1.1)},  # none
}


def lum(c):
    return c[0] * 0.3 + c[1] * 0.59 + c[2] * 0.11


def hue_sat(c):
    h, s, v = colorsys.rgb_to_hsv(c[0] / 255.0, c[1] / 255.0, c[2] / 255.0)
    return h * 360.0, s, v


def in_band(c, band):
    lo, hi, smin = band
    h, s, v = hue_sat(c)
    if s < smin or v < 0.2:
        return False
    return lo <= h <= hi or lo <= h + 360 <= hi


def ramps(img, band, counts=False):
    """The body's and the accent's colours, darkest first (with pixel counts
    when `counts`)."""
    body, accent = {}, {}
    for y in range(img.height):
        for x in range(img.width):
            p = img.getpixel((x, y))
            if p[3] == 0:
                continue
            c = p[:3]
            if lum(c) < 28:
                continue  # outline
            part = accent if in_band(c, band) else body
            part[c] = part.get(c, 0) + 1
    if counts:
        return sorted(body.items(), key=lambda kv: lum(kv[0])), sorted(accent.items(), key=lambda kv: lum(kv[0]))
    return sorted(body, key=lum), sorted(accent, key=lum)


def recolour(key, src, scale=1.0):
    side = Image.open(os.path.join(NEW, key, "east.png")).convert("RGBA")
    bands = ACCENT[key]
    body_d, accent_d = ramps(side, bands["dst"], counts=True)
    if not accent_d:
        accent_d = body_d
    img = src.convert("RGBA")
    img = img.crop(img.getbbox())
    if scale != 1.0:
        img = img.resize((round(img.width * scale), round(img.height * scale)), Image.NEAREST)
    body_s, accent_s = ramps(img, bands["src"], counts=True)
    outline = min((side.getpixel((x, y))[:3] for y in range(side.height) for x in range(side.width)
                   if side.getpixel((x, y))[3] > 0), key=lum)

    def rank_map(sources, targets):
        """Histogram matching: a source shade at brightness percentile t (by
        pixel count) takes the target shade at the same percentile, so the
        front view is as light or dark overall as the side view."""
        table = {}
        total_s = float(sum(n for _, n in sources)) or 1.0
        total_t = float(sum(n for _, n in targets)) or 1.0
        cum_t, marks = 0.0, []
        for c, n in targets:
            marks.append((cum_t + n / 2.0) / total_t)
            cum_t += n
        cum = 0.0
        for c, n in sources:
            t = (cum + n / 2.0) / total_s
            cum += n
            best = min(range(len(targets)), key=lambda i: abs(marks[i] - t))
            table[c] = targets[best][0]
        return table

    table = rank_map(body_s, body_d)
    table.update(rank_map(accent_s, accent_d))
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    po, pi = out.load(), img.load()
    for y in range(img.height):
        for x in range(img.width):
            p = pi[x, y]
            if p[3] == 0:
                continue
            c = p[:3]
            po[x, y] = (table[c] if c in table else outline) + (255,)
    return out


def main():
    key, view, src, out = sys.argv[1:5]
    scale = float(sys.argv[sys.argv.index("--scale") + 1]) if "--scale" in sys.argv else 1.0
    recolour(key, Image.open(src), scale).save(out)
    print("recoloured", src, "->", out)


if __name__ == "__main__":
    main()
