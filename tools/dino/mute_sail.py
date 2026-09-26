"""Pass 14: mute a beast's bright sail to a dull ridge, in every drawing it has.

    python tools/dino/mute_sail.py KEY [--preview OUT.png]

The Suchomimus came out with the Spinosaurus' bright orange, banded sail, and
the two read alike from afar. The real animal carried a low ridge, so its warm
sail colours (orange, peach, the red-brown bands: hue under 42 degrees, well
saturated) are pulled down to a dull khaki-olive, keeping each pixel's shading
so the ridge still reads, just no longer as a banner.

Rewrites art/dino-v2/clips/KEY/*/*.png and art/dino-v2/first/KEY_{side,down,up}.png
in place (the first run backs them up to art/dino-v2/fix/KEY-sail/). Muted
colours no longer match, so running it twice changes nothing more. Then
`python tools/dino/export.py KEY`.
"""
import colorsys
import glob
import os
import shutil
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ART = os.path.join(ROOT, "art", "dino-v2")

HUE_MAX = 42.0
SAT_MIN = 0.38


def mute(c):
    r, g, b, a = c
    if a == 0:
        return c
    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    hd = h * 360.0
    if not ((hd <= HUE_MAX or hd >= 345.0) and s >= SAT_MIN):
        return c
    # Khaki-olive, much less saturated, a little darker; highlights keep some light.
    nh = 52.0 / 360.0
    ns = s * 0.55
    nv = v * (0.6 if v < 0.8 else 0.68)
    nr, ng, nb = colorsys.hsv_to_rgb(nh, ns, nv)
    return (int(round(nr * 255)), int(round(ng * 255)), int(round(nb * 255)), a)


def files(key):
    out = sorted(glob.glob(os.path.join(ART, "clips", key, "*", "*.png")))
    for view in ("side", "down", "up"):
        p = os.path.join(ART, "first", "%s_%s.png" % (key, view))
        if os.path.exists(p):
            out.append(p)
    return out


def apply(path):
    img = Image.open(path).convert("RGBA")
    px = img.load()
    changed = 0
    cache = {}
    for y in range(img.height):
        for x in range(img.width):
            c = px[x, y]
            if c not in cache:
                cache[c] = mute(c)
            n = cache[c]
            if n != c:
                px[x, y] = n
                changed += 1
    return img, changed


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return
    key = sys.argv[1]
    targets = files(key)
    if "--preview" in sys.argv:
        out = sys.argv[sys.argv.index("--preview") + 1]
        views = [p for p in targets if os.path.dirname(p).endswith("first")]
        pairs = [(Image.open(p).convert("RGBA"), apply(p)[0]) for p in views]
        w = sum(a.width for a, _ in pairs) + 10 * len(pairs)
        h = max(a.height for a, _ in pairs) * 2 + 10
        sheet = Image.new("RGBA", (w, h), (90, 110, 80, 255))
        x = 0
        for a, b in pairs:
            sheet.alpha_composite(a, (x, 0))
            sheet.alpha_composite(b, (x, a.height + 10))
            x += a.width + 10
        sheet.resize((sheet.width * 3, sheet.height * 3), Image.NEAREST).save(out)
        print("preview", out)
        return
    backup = os.path.join(ART, "fix", key + "-sail")
    first_run = not os.path.exists(backup)
    total = 0
    for p in targets:
        if first_run:
            rel = os.path.relpath(p, ART)
            dst = os.path.join(backup, rel)
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            shutil.copy2(p, dst)
        img, changed = apply(p)
        if changed:
            img.save(p)
            total += changed
    print("%s: %d files, %d pixels muted%s" % (key, len(targets), total, " (backed up)" if first_run else ""))


if __name__ == "__main__":
    main()
