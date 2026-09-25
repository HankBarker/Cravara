"""Back-view (walking away) locomotion built from the creature's own drawing.

    python tools/dino/walk_back.py KEY [--run]

The animation models could not walk a heavy quadruped away from the viewer:
the stego's and trike's hind legs splayed out sideways like a frog kick, and
the trike's saddled walk stretched the body taller. From behind the hind legs
are two columns at the bottom sides with the tail hanging between them, so the
gait is built from the resting back drawing instead:

  - the hind legs lift in turn (2 px walking, 3 running) and never leave their
    own columns, so nothing kicks out
  - the body dips on each footfall and rises 1 px between them; the planted
    leg stretches by that pixel so it never tears away from the rump
  - the tail sways against the step, more toward its tip

RIG gives, per key, the two leg boxes and the tail box on the resting drawing
(art/dino-v2/first/KEY_up.png) and the row the tail swings from. Writes
art/dino-v2/clips/KEY/walk_up/ (or run_up/), 8 looping frames with frame 0 the
untouched drawing, and records the method in the ledger.
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
# Boxes are (x0, y0, x1, y1), end-exclusive, on the resting back drawing.
RIG = {
    "stego": {"legs": [(46, 60, 54, 68), (61, 60, 68, 68)], "tail": (51, 58, 64, 74), "hip": 60},
    "stego_saddle": {"legs": [(46, 60, 54, 69), (60, 60, 67, 69)], "tail": (51, 58, 64, 74), "hip": 60},
    "trike": {"legs": [(37, 56, 46, 62), (52, 56, 61, 62)], "tail": (45, 57, 54, 66), "hip": 57},
    "trike_saddle": {"legs": [(38, 57, 46, 62), (52, 57, 61, 62)], "tail": (46, 58, 53, 66), "hip": 58},
    # The Ashmane (pass 12, a biped): its model run away from the viewer
    # turned the whole animal round. Its tail curls up over its back, so it
    # rides with the body (an empty tail box).
    "yuty": {"legs": [(46, 90, 60, 108), (66, 90, 82, 108)], "tail": (0, 0, 0, 0), "hip": 90},
}
GAIT = {
    "walk": {"lift": 2.0, "bob": 1.0, "tail": 2.0},
    "run": {"lift": 3.0, "bob": 1.0, "tail": 2.5},
}


def masks(drawing, rig):
    """Pixel sets: each leg, the tail (outside the legs) and the rest (body)."""
    px = drawing.load()
    w, h = drawing.size
    opaque = {(x, y) for y in range(h) for x in range(w) if px[x, y][3]}

    def inside(box):
        return {(x, y) for (x, y) in opaque if box[0] <= x < box[2] and box[1] <= y < box[3]}

    legs = [inside(b) for b in rig["legs"]]
    taken = set().union(*legs)
    tail = inside(rig["tail"]) - taken
    body = opaque - taken - tail
    return legs, tail, body


def build(key, clip):
    rig = RIG[key]
    gait = GAIT[clip]
    drawing = Image.open(os.path.join(OUT, "first", "%s_up.png" % key)).convert("RGBA")
    src = drawing.load()
    w, h = drawing.size
    legs, tail, body = masks(drawing, rig)
    tail_tip = max(y for _, y in tail) if tail else rig["hip"] + 1
    centre = sum(x for x, _ in body) / max(1, len(body))
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

        for x, y in body:
            put(x, y - bob, src[x, y])
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
                # Planted: the foot stays on the ground while the rump rises, so
                # the leg stretches by the bob.
                bottom = {}
                for x, y in leg:
                    bottom[x] = max(bottom.get(x, y), y)
                for x, y in leg:
                    put(x, y - bob, src[x, y])
                for x, low in bottom.items():
                    for k in range(bob):
                        put(x, low - k, src[x, low - k] if src[x, low - k][3] else src[x, low])
        span = max(1, tail_tip - rig["hip"])
        for x, y in tail:
            reach = max(0.0, (y - rig["hip"]) / span) ** 1.5
            put(x + int(round(-gait["tail"] * s * reach)), y - bob, src[x, y])
        frames.append(out)
    frames[0] = drawing.copy()
    name = "%s_up" % clip
    dst_dir = os.path.join(OUT, "clips", key, name)
    os.makedirs(dst_dir, exist_ok=True)
    for old in os.listdir(dst_dir):
        if old.endswith(".png"):
            os.remove(os.path.join(dst_dir, old))
    for i, f in enumerate(frames):
        f.save(os.path.join(dst_dir, "%03d.png" % i))
    led = gen.load_ledger(key)
    entry = led.get(name, {})
    entry.update({"status": "done", "method": "walk_back.py (%s gait from the back drawing)" % clip, "frames": FRAMES})
    led[name] = entry
    gen.save_ledger(key, led)
    print("built", dst_dir, FRAMES, "frames")


def main():
    key = sys.argv[1]
    build(key, "run" if "--run" in sys.argv else "walk")


if __name__ == "__main__":
    main()
