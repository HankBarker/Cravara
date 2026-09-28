"""Build a trike's gore clip from its own clean wind-up frames.

    python tools/dino/gore_from_windup.py KEY   (trike | trike_saddle)

The animation models could not draw a triceratops head swing: every attempt
reared it up, turned it bipedal or grew its horns into glowing blades. The
wind-up clip (head lowered, horns forward) came out clean in every facing, so
the gore is built from it: the head drops, cocks back a pixel, the horns
drive forward (contact), toss up a touch and settle back. The engine's lunge
moves the body forward on top of this, so the blow covers real ground.

Writes art/dino-v2/clips/KEY/gore_{side,down,up}/ (9 frames, contact on 5).
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen  # noqa: E402

OUT = gen.OUT
# (wind-up frame, forward px, up px) per gore frame; contact = frame 5.
PLAN = [(0, 0, 0), (1, 0, 0), (2, 0, 0), (3, -1, 0), (4, 2, 0), (4, 4, 1), (5, 3, 1), (6, 1, 0), (1, 0, 0)]
FORWARD = {"side": (1, 0), "down": (0, 1), "up": (0, -1)}


def main():
    key = sys.argv[1]
    for view in ("side", "down", "up"):
        src = os.path.join(OUT, "clips", key, "windup_%s" % view)
        wind = [Image.open(os.path.join(src, n)).convert("RGBA") for n in sorted(os.listdir(src)) if n.endswith(".png")]
        fx, fy = FORWARD[view]
        dst = os.path.join(OUT, "clips", key, "gore_%s" % view)
        os.makedirs(dst, exist_ok=True)
        for old in os.listdir(dst):
            if old.endswith(".png"):
                os.remove(os.path.join(dst, old))
        for i, (w, fwd, up) in enumerate(PLAN):
            frame = wind[min(w, len(wind) - 1)]
            out = Image.new("RGBA", frame.size, (0, 0, 0, 0))
            # Forward along the facing; "up" lifts the whole body a pixel (the toss).
            out.alpha_composite(frame, (fx * fwd, fy * fwd - up if view == "side" else fy * fwd))
            out.save(os.path.join(dst, "%03d.png" % i))
        led = gen.load_ledger(key)
        e = led.get("gore_%s" % view, {})
        e.update({"status": "done", "method": "gore_from_windup.py (wind-up frames + thrust)", "frames": len(PLAN)})
        led["gore_%s" % view] = e
        gen.save_ledger(key, led)
    print("built gore for", key, "(contact frame 5)")


if __name__ == "__main__":
    main()
