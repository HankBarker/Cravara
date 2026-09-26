"""Front-view (walking toward the viewer) locomotion built from the creature's
own drawing, like walk_back.py does from behind.

    python tools/dino/walk_front.py KEY [--run] [--view down|up] [--preview PATH]

The models' front walks changed the animal from frame to frame: the stego's
plates and the longneck's body grew and shrank, the allosaurus kicked a leg
out sideways, the alpha's crest pumped up and down and the raptor slid along
barely moving its feet. From the front the legs are two columns at the bottom
sides, so the gait is built from the resting front drawing instead:

  - the legs lift in turn (2 px walking, 3 running) and never leave their own
    columns, so nothing kicks out
  - the body dips on each footfall and rises 1 px between them; the planted
    leg stretches by that pixel so it never tears away from the body
  - the head end sways a pixel against the step (bipeds a little more)

The legs are found on the drawing itself: the bottom LEG rows (per key, a
share of the drawing's height by default) either side of a central gap, so a
belly or tail hanging between the legs stays with the body. Writes
art/dino-v2/clips/KEY/walk_down/ (or run_down/, or *_up with --view up), 8
looping frames with frame 0 the untouched drawing, and records the method in
the ledger. --preview writes a review strip instead of touching the clips.
"""
import math
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen  # noqa: E402

OUT = gen.OUT
FRAMES = 8
# Per key: legs = rows of the drawing (from its lowest pixel up) that count as
# legs, gap = half-width (px) of the central strip that stays with the body,
# sway = px the upper body leans against each step.
RIG = {
    "stego": {"legs": 9, "gap": 3, "sway": 1},
    "stego_saddle": {"legs": 9, "gap": 3, "sway": 1},
    "trike": {"legs": 7, "gap": 3, "sway": 1},
    "trike_saddle": {"legs": 7, "gap": 3, "sway": 1},
    "longneck": {"legs": 11, "gap": 4, "sway": 1},
    "rex": {"legs": 9, "gap": 3, "sway": 1},
    "allo": {"legs": 8, "gap": 3, "sway": 1},
    "alpha": {"legs": 8, "gap": 3, "sway": 1},
    "raptor": {"legs": 6, "gap": 2, "sway": 1},
    "dodo": {"legs": 4, "gap": 1, "sway": 1},
    "lystro": {"legs": 4, "gap": 2, "sway": 0},
    "parasaur": {"legs": 8, "gap": 3, "sway": 1},
    "ossuar": {"legs": 9, "gap": 3, "sway": 1},
    # Pass 14: the Sailking (its crystal run lost the sail from the front).
    "spino": {"legs": 11, "gap": 4, "sway": 1},
}
GAIT = {
    "walk": {"lift": 2.0, "bob": 1.0},
    "run": {"lift": 3.0, "bob": 1.0},
}


def rig_for(key):
    if key in RIG:
        return RIG[key]
    base = key.split("_")[0]
    r = dict(RIG.get(base, {"legs": 5, "gap": 2, "sway": 1}))
    if key.endswith("_baby"):
        # Babies are about half size: shorter legs, a narrower gap.
        r["legs"] = max(3, r["legs"] // 2)
        r["gap"] = max(1, r["gap"] // 2)
    return r


def masks(drawing, rig):
    """Pixel sets: the left leg, the right leg and the rest (body)."""
    px = drawing.load()
    w, h = drawing.size
    opaque = [(x, y) for y in range(h) for x in range(w) if px[x, y][3]]
    bottom = max(y for _, y in opaque)
    top_leg = bottom - rig["legs"] + 1
    lower = [(x, y) for (x, y) in opaque if y >= top_leg]
    centre = (min(x for x, _ in lower) + max(x for x, _ in lower)) / 2.0
    left = {(x, y) for (x, y) in lower if x < centre - rig["gap"]}
    right = {(x, y) for (x, y) in lower if x > centre + rig["gap"]}
    body = set(opaque) - left - right
    return [left, right], body, bottom, centre


def build(key, clip, view="down"):
    rig = rig_for(key)
    gait = GAIT[clip]
    drawing = Image.open(os.path.join(OUT, "first", "%s_%s.png" % (key, view))).convert("RGBA")
    src = drawing.load()
    w, h = drawing.size
    legs, body, bottom, centre = masks(drawing, rig)
    top = min(y for _, y in body)
    frames = []
    for i in range(FRAMES):
        s = math.sin(2.0 * math.pi * i / FRAMES)
        lifts = [int(round(gait["lift"] * max(0.0, s))), int(round(gait["lift"] * max(0.0, -s)))]
        bob = int(round(gait["bob"] * abs(s)))
        out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        dst = out.load()

        def put(x, y, colour):
            if 0 <= x < w and 0 <= y < h:
                dst[x, y] = colour

        # The upper body leans a pixel away from the lifted leg: the head end
        # sways most, the hips not at all.
        lean = 0
        if rig["sway"] and (lifts[0] or lifts[1]):
            lean = rig["sway"] if lifts[0] else -rig["sway"]
        span = max(1, bottom - top)
        for x, y in body:
            reach = max(0.0, 1.0 - (y - top) / span)
            put(x + int(round(lean * reach)), y - bob, src[x, y])
        for leg, lift in zip(legs, lifts):
            if not leg:
                continue
            if lift:
                # Off the ground, a touch in toward the body at the top of the step.
                side = 1 if sum(x for x, _ in leg) / len(leg) < centre else -1
                inward = side if lift >= 2 else 0
                for x, y in leg:
                    put(x + inward, y - bob - lift, src[x, y])
            else:
                # Planted: the foot stays on the ground while the body rises, so
                # the leg stretches by the bob.
                low = {}
                for x, y in leg:
                    low[x] = max(low.get(x, y), y)
                for x, y in leg:
                    put(x, y - bob, src[x, y])
                for x, lowest in low.items():
                    for k in range(bob):
                        put(x, lowest - k, src[x, lowest - k] if src[x, lowest - k][3] else src[x, lowest])
        frames.append(out)
    frames[0] = drawing.copy()
    return frames


def write(key, clip, view, frames):
    name = "%s_%s" % (clip, view)
    dst_dir = os.path.join(OUT, "clips", key, name)
    os.makedirs(dst_dir, exist_ok=True)
    for old in os.listdir(dst_dir):
        if old.endswith(".png"):
            os.remove(os.path.join(dst_dir, old))
    for i, f in enumerate(frames):
        f.save(os.path.join(dst_dir, "%03d.png" % i))
    led = gen.load_ledger(key)
    entry = led.get(name, {})
    entry.update({"status": "done", "method": "walk_front.py (%s gait from the %s drawing)" % (clip, view), "frames": FRAMES})
    led[name] = entry
    gen.save_ledger(key, led)
    print("built", dst_dir, FRAMES, "frames")


def preview(frames, path, scale=4):
    bb = None
    for f in frames:
        b = f.getbbox()
        if b:
            bb = b if bb is None else (min(bb[0], b[0]), min(bb[1], b[1]), max(bb[2], b[2]), max(bb[3], b[3]))
    crops = [f.crop(bb) for f in frames]
    fw, fh = crops[0].size
    sheet = Image.new("RGBA", ((fw + 4) * len(crops) * scale, fh * scale), (70, 96, 60, 255))
    for i, c in enumerate(crops):
        sheet.alpha_composite(c.resize((fw * scale, fh * scale), Image.NEAREST), (i * (fw + 4) * scale, 0))
    sheet.save(path)


def main():
    key = sys.argv[1]
    clip = "run" if "--run" in sys.argv else "walk"
    view = sys.argv[sys.argv.index("--view") + 1] if "--view" in sys.argv else "down"
    frames = build(key, clip, view)
    if "--preview" in sys.argv:
        preview(frames, sys.argv[sys.argv.index("--preview") + 1])
    else:
        write(key, clip, view, frames)


if __name__ == "__main__":
    main()
