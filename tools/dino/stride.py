"""Measure how fast a walk or run clip's feet travel, to set ForestCreature.BODY.

    python tools/dino/stride.py KEY [CLIP ...]        # default: walk run

The PixelLab clips walk in place, so a planted foot slides backward under the
body. For each pair of frames this finds the feet on the ground (opaque pixels
in the lowest rows of the side view), pairs each with the nearest foot in the
next frame, measured from the body's centre (the models let the whole body
drift a little), and takes the backward drift of the ones that stayed planted.
Median drift per frame x the clip's fps = the world speed (px/s) at which the
feet don't slide: BODY[KEY].walk / .run.

Checked against tuned species (2026-09-25): walks within a few px/s (stego,
trike, the Blender carno's exact 30), the allo's and rex's runs within 4.
Runs of hunters are set higher on purpose: the run clip plays at most 2.4x
(ForestCreature), so BODY.run >= chase / 2.4 keeps a full chase from sliding
the feet far. The suggestion printed allows for that.
"""
import json
import os
import statistics
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
V2 = os.path.join(ROOT, "game", "Forest", "creatures", "art", "v2")
BAND = 3  # rows above the lowest opaque row that count as "on the ground"


def frames(key, clip):
    meta = json.load(open(os.path.join(V2, key + ".json"), encoding="utf-8"))
    info = meta["clips"][clip]
    w, h = meta["canvas"]
    strip = Image.open(os.path.join(V2, key, "%s_side.png" % clip)).convert("RGBA")
    return [strip.crop((i * w, 0, (i + 1) * w, h)) for i in range(info["frames"])], float(info["fps"])


def feet(img):
    """Runs of opaque pixels along the ground band: (centre x, width)."""
    px = img.load()
    w, h = img.size
    bottom = max((y for y in range(h) for x in range(w) if px[x, y][3] > 0), default=-1)
    if bottom < 0:
        return []
    cols = [any(px[x, y][3] > 0 for y in range(bottom - BAND + 1, bottom + 1)) for x in range(w)]
    out, start = [], None
    for x, on in enumerate(cols + [False]):
        if on and start is None:
            start = x
        elif not on and start is not None:
            out.append(((start + x - 1) / 2.0, x - start))
            start = None
    return out


def body_x(img):
    """Mean x of the opaque pixels above the legs."""
    px = img.load()
    w, h = img.size
    bottom = max((y for y in range(h) for x in range(w) if px[x, y][3] > 0), default=-1)
    xs = [x for y in range(0, bottom - 6) for x in range(w) if px[x, y][3] > 0]
    return sum(xs) / len(xs) if xs else w / 2.0


def drift(key, clip):
    imgs, fps = frames(key, clip)
    steps = []
    for a, b in zip(imgs, imgs[1:] + imgs[:1]):
        fa, fb = feet(a), feet(b)
        ca, cb = body_x(a), body_x(b)
        for xa, wa in fa:
            if not fb:
                continue
            xb, wb = min(fb, key=lambda f: abs((f[0] - cb) - (xa - ca)))
            d = (xa - ca) - (xb - cb)  # facing right: a planted foot drifts left
            if 0.0 < d <= 6.0 and abs(wa - wb) <= 3:
                steps.append(d)
    if not steps:
        return None, fps, 0
    return statistics.median(steps) * fps, fps, len(steps)


def chase_of(key):
    """BODY[key].chase from ForestCreature.gd (0 when it has none)."""
    import re
    src = open(os.path.join(ROOT, "game", "Forest", "creatures", "ForestCreature.gd"), encoding="utf-8").read()
    m = re.search(r'"%s": \{"accel"[^}]*"chase": ([0-9.]+)' % re.escape(key), src)
    return float(m.group(1)) if m else 0.0


def main():
    key = sys.argv[1]
    clips = sys.argv[2:] or ["walk", "run"]
    for clip in clips:
        speed, fps, n = drift(key, clip)
        if speed is None:
            print("%s %s: no planted feet found" % (key, clip))
        else:
            note = ""
            chase = chase_of(key)
            if clip == "run" and chase / 2.4 > speed:
                note = "; with its chase of %.0f, suggest %.0f" % (chase, chase / 2.4)
            print("%s %s: %.0f px/s (%d samples at %g fps)%s" % (key, clip, speed, n, fps, note))


if __name__ == "__main__":
    main()
