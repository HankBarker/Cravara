"""The parasaur's crest, drawn by hand (pixel by pixel) onto its PixelLab
drawings: the models gave it a fine hadrosaur body but never the long tube
crest that sweeps back from the skull. A 3-px tube along a curve, in the
head's own colours, outlined, shaded underneath and lit on top; seen from the
front or behind it's a short nub on top of the head.

    python tools/dino/parasaur_crest.py

Reads art/dino-v2/new/parasaur/try1/{east,north}.png and writes
art/dino-v2/new/parasaur/{east,north}.png (the front view, south.png, is the
pass-12 redraw).
"""
import math
import os

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "art", "dino-v2", "new", "parasaur", "try1")
DST = os.path.join(ROOT, "art", "dino-v2", "new", "parasaur")
OUTLINE = (20, 26, 16, 255)


def seg_dist(p, a, b):
    ax, ay = a
    bx, by = b
    px, py = p
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / float(dx * dx + dy * dy)))
    qx, qy = ax + t * dx, ay + t * dy
    return math.hypot(px - qx, py - qy)


def crest(img, path, radius, fill, shade, light):
    px = img.load()
    w, h = img.size
    tube = set()
    for y in range(h):
        for x in range(w):
            d = min(seg_dist((x, y), path[i], path[i + 1]) for i in range(len(path) - 1))
            if d <= radius:
                tube.add((x, y))
    for (x, y) in tube:
        below = (x, y + 1) not in tube
        above = (x, y - 1) not in tube
        px[x, y] = shade if below else (light if above else fill)
    for (x, y) in tube:
        for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if n in tube or not (0 <= n[0] < w and 0 <= n[1] < h):
                continue
            if px[n][3] == 0:
                px[n] = OUTLINE


def main():
    side = Image.open(os.path.join(SRC, "east.png")).convert("RGBA")
    fill = side.getpixel((70, 53))[:3] + (255,)
    shade = tuple(max(0, int(c * 0.72)) for c in fill[:3]) + (255,)
    light = tuple(min(255, int(c * 1.25) + 10) for c in fill[:3]) + (255,)
    # From the top of the skull, back and a little up, as long as the head.
    crest(side, [(71, 51), (68, 48.5), (64, 46.5), (60, 45.5), (56, 45.5)], 1.3, fill, shade, light)
    side.save(os.path.join(DST, "east.png"))
    # The front view is no longer this nub: pass 12 redrew it whole
    # (tools/dino/redraw_view.py, with the crest painted as a thick tube
    # sweeping back from the skull) -> art/dino-v2/new/parasaur/south.png.
    for view in ("north",):
        img = Image.open(os.path.join(SRC, view + ".png")).convert("RGBA")
        box = img.getbbox()
        cx = (box[0] + box[2]) // 2
        top = box[1]
        # The row where the head is widest near the top: the nub sits on it.
        f = img.getpixel((cx, top + 2))[:3] + (255,)
        s = tuple(max(0, int(c * 0.72)) for c in f[:3]) + (255,)
        l = tuple(min(255, int(c * 1.25) + 10) for c in f[:3]) + (255,)
        crest(img, [(cx, top + 1), (cx, top - 4)], 1.2, f, s, l)
        img.save(os.path.join(DST, view + ".png"))
    print("crest drawn on side, front and back")


if __name__ == "__main__":
    main()
