"""Side-view tail sweeps built from the creature's own art.

    python tools/dino/tail_side.py KEY [--near] [--far]      (default: both)

The animation models could not swing a tail out to the side in a side view:
they curled it into a glowing crescent, smeared it into flame or turned the
whole animal round, which is exactly what the design forbids. This builds the
sweep instead: the body (the resting side drawing, facing right) stays still
while the tail, cut from the same drawing at the hips, bends out to one side:

  near  tail_swing_side      toward the viewer: down the screen, drawn in front
                             of the body
  far   tail_swing_far_side  away from the viewer: up the screen, behind the
                             body; the game plays it when the target stands on
                             the far side (DinoMoves picks it by the aim)

The bend grows from nothing at the hips to the full angle at the tip, so the
root stays attached and the spiked end leads. The tail keeps (and at the whip
slightly exceeds) its length: rigid rotation tore the root plates loose, and
true foreshortening made the swing read as the tail pulling in. Each clip is a
short counter-cock, a fast whip, a held contact pose and an eased return. The
tail is drawn from a Scale2x-upscaled copy (RotSprite-style), so edges stay
clean and every colour is one of the drawing's own.

Writes art/dino-v2/clips/KEY/<clip>/ (13 frames, contact on frame 6), records
the method in the ledger and the contact frame in hits.json.
"""
import json
import math
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen  # noqa: E402

OUT = gen.OUT
# Column where the tail meets the hips on each side drawing (facing right).
CUT = {"stego": 48, "stego_saddle": 48, "longneck": 52, "anky": 39}
CONTACT = 6
# Per frame: (share of the full swing, stretch along the tail). Cock back,
# whip, hold on contact, ease back. The tail keeps (and at the whip slightly
# exceeds) its full length: true foreshortening made it read as retracting.
PLAN = [(0.0, 1.0), (-0.14, 0.97), (-0.24, 0.95), (0.3, 1.02), (0.66, 1.07), (0.9, 1.1), (1.0, 1.1),
        (1.03, 1.08), (0.95, 1.05), (0.76, 1.03), (0.5, 1.01), (0.24, 1.0), (0.08, 1.0)]
# Screen angle of the full swing (+ = tip down the screen, toward the viewer).
SWING = {"near": 70.0, "far": -56.0}
# A long, already curled tail hooks over itself at the full angle.
SWING_KEY = {"longneck": {"far": -34.0}}
CLIP = {"near": "tail_swing_side", "far": "tail_swing_far_side"}
# Toward the viewer the tail passes in front of the body once it is clear of it.
FRONT_FROM = 9.0


def scale2x(img):
    """EPX / Scale2x: doubles pixel art, rounding diagonals instead of blurring."""
    w, h = img.size
    src = img.load()
    out = Image.new("RGBA", (w * 2, h * 2), (0, 0, 0, 0))
    dst = out.load()

    def px(x, y):
        if 0 <= x < w and 0 <= y < h:
            p = src[x, y]
            return p if p[3] else (0, 0, 0, 0)
        return (0, 0, 0, 0)

    for y in range(h):
        for x in range(w):
            p = px(x, y)
            a, b, c, d = px(x, y - 1), px(x + 1, y), px(x - 1, y), px(x, y + 1)
            e0 = a if (c == a and c != d and a != b) else p
            e1 = b if (a == b and a != c and b != d) else p
            e2 = c if (d == c and d != b and c != a) else p
            e3 = d if (b == d and b != a and d != c) else p
            dst[2 * x, 2 * y] = e0
            dst[2 * x + 1, 2 * y] = e1
            dst[2 * x, 2 * y + 1] = e2
            dst[2 * x + 1, 2 * y + 1] = e3
    return out


def split(drawing, cut):
    """(body, tail, pivot): the drawing without the tail, the tail alone, and
    the root point the tail turns about (on the cut line, mid tail)."""
    w, h = drawing.size
    tail = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    tail.paste(drawing.crop((0, 0, cut, h)), (0, 0))
    body = drawing.copy()
    body.paste((0, 0, 0, 0), (0, 0, cut, h))
    px = drawing.load()
    rows = [y for y in range(h) for x in range(cut - 3, cut) if px[x, y][3]]
    root = (min(rows) + max(rows)) / 2.0 + 0.5
    return body, tail, (float(cut), root)


def bent(tail4, size, pivot, angle_deg, stretch):
    """The tail bent `angle_deg` on screen (+ = tip down, the side toward the
    viewer) and stretched along itself. The bend grows from nothing at the
    hips to the full angle at the tip, so the root stays attached and the
    spiked end leads. Each Scale2x sample is carried to its bent spot and every
    screen pixel takes the colour most of its samples bring."""
    w, h = size
    alpha = math.radians(angle_deg)
    src = tail4.load()
    sw, sh = tail4.size
    xs = [x for y in range(sh) for x in range(sw) if src[x, y][3]]
    length = pivot[0] - min(xs) / 4.0 if xs else 1.0
    # The bent centre line: angle(s) = alpha * (1 - (1 - s/L)^2).
    step = 0.125
    line = [(pivot[0], pivot[1], 0.0)]
    px, py = pivot
    s = 0.0
    while s < length + 2.0:
        u = min(1.0, s / length)
        th = alpha * (1.0 - (1.0 - u) ** 2)
        px -= math.cos(th) * step * stretch
        py += math.sin(th) * step * stretch
        s += step
        line.append((px, py, th))
    votes = {}
    for y in range(sh):
        for x in range(sw):
            p = src[x, y]
            if not p[3]:
                continue
            fx, fy = (x + 0.5) / 4.0, (y + 0.5) / 4.0
            along = max(0.0, pivot[0] - fx)
            v = fy - pivot[1]
            cx, cy, th = line[min(len(line) - 1, int(along / step))]
            # Offsets across the tail turn with it: (0, 1) -> (sin, cos).
            qx, qy = cx + math.sin(th) * v, cy + math.cos(th) * v
            key = (int(math.floor(qx)), int(math.floor(qy)))
            if 0 <= key[0] < w and 0 <= key[1] < h:
                votes.setdefault(key, {})
                votes[key][p] = votes[key].get(p, 0) + 1
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dst = out.load()
    for key, colours in votes.items():
        if sum(colours.values()) >= 6:
            dst[key] = max(colours.items(), key=lambda kv: kv[1])[0]
    return out


def build(key, side):
    drawing = Image.open(os.path.join(OUT, "first", "%s_side.png" % key)).convert("RGBA")
    body, tail, pivot = split(drawing, CUT[key])
    tail4 = scale2x(scale2x(tail))
    frames = []
    for i, (share, stretch) in enumerate(PLAN):
        angle = SWING_KEY.get(key, {}).get(side, SWING[side]) * share
        if i == 0 or (abs(angle) < 0.5 and stretch == 1.0):
            frames.append(drawing.copy())
            continue
        t = bent(tail4, drawing.size, pivot, angle, stretch)
        canvas = Image.new("RGBA", drawing.size, (0, 0, 0, 0))
        if angle >= FRONT_FROM:
            canvas.alpha_composite(body)
            canvas.alpha_composite(t)
        else:
            canvas.alpha_composite(t)
            canvas.alpha_composite(body)
        frames.append(canvas)
    dst = os.path.join(OUT, "clips", key, CLIP[side])
    os.makedirs(dst, exist_ok=True)
    for old in os.listdir(dst):
        if old.endswith(".png"):
            os.remove(os.path.join(dst, old))
    for i, f in enumerate(frames):
        f.save(os.path.join(dst, "%03d.png" % i))
    led = gen.load_ledger(key)
    entry = led.get(CLIP[side], {})
    entry.update({"status": "done", "method": "tail_side.py (still body + bent tail, %s)" % side, "frames": len(frames)})
    led[CLIP[side]] = entry
    gen.save_ledger(key, led)
    hits_path = os.path.join(HERE, "hits.json")
    hits = json.load(open(hits_path, encoding="utf-8")) if os.path.exists(hits_path) else {}
    clip = "tail_swing" if side == "near" else "tail_swing_far"
    entry = hits.setdefault(key, {}).setdefault(clip, {})
    if isinstance(entry, dict):
        entry["side"] = CONTACT
    json.dump(hits, open(hits_path, "w", encoding="utf-8"), indent=1)
    print("built", dst, len(frames), "frames, contact", CONTACT)


def main():
    key = sys.argv[1]
    sides = [s for s in ("near", "far") if "--" + s in sys.argv] or ["near", "far"]
    for side in sides:
        build(key, side)


if __name__ == "__main__":
    main()
