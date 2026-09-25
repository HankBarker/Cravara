"""Build a back-view display (a roar, a threat) from the resting back idle.

    python tools/dino/lift_back.py KEY CLIP --hip ROW [--lift PX] [--no-ledger]

A negative --lift dips instead (eating from behind: the body lowers over the
tops of the legs as the head goes down to the ground).

From behind, a roar is mostly the body rearing: the models kept turning the
animal round to show its open jaws (the deinonychus's and the Suchomimus's
threat and roar) or grew the tail into a tall pale spike. This plays the
back idle loop and lifts everything above the hips (`--hip`, the row where
the legs part) up by a rise-hold-settle curve, stretching the tops of the
legs so they stay planted. Every pixel is the drawing's own.

Writes art/dino-v2/clips/KEY/CLIP_up/ with the clip's frame count from
clips.json, and records `method` in the ledger so `gen.py clean` leaves it.
"""
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
CLIPS = os.path.join(ROOT, "art", "dino-v2", "clips")
SPEC = json.load(open(os.path.join(HERE, "clips.json"), encoding="utf-8"))


def opt(flag, default=None):
    return sys.argv[sys.argv.index(flag) + 1] if flag in sys.argv else default


def curve(n, lift):
    """Rise (or dip) over the first third, hold, settle over the last third (frame 0 rests)."""
    out = []
    for i in range(n):
        t = i / max(1, n - 1)
        if t < 0.33:
            f = t / 0.33
        elif t < 0.7:
            f = 1.0
        else:
            f = max(0.0, 1.0 - (t - 0.7) / 0.3)
        out.append(int(round(lift * f)))
    out[0] = 0
    return out


def lift_frame(src, hip, d):
    w, h = src.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    if d == 0:
        return src.copy()
    if d < 0:
        # A dip: the legs stay, the body settles down over their tops.
        out.paste(src.crop((0, hip, w, h)), (0, hip))
        upper = src.crop((0, 0, w, hip))
        out.alpha_composite(upper, (0, -d))
        return out
    out.paste(src.crop((0, 0, w, hip)), (0, -d))
    for k in range(d):
        out.paste(src.crop((0, hip, w, hip + 1)), (0, hip - d + k))
    out.paste(src.crop((0, hip, w, h)), (0, hip))
    return out


def main():
    key, clip = sys.argv[1], sys.argv[2]
    hip = int(opt("--hip"))
    lift = int(opt("--lift", "4"))
    idle_dir = os.path.join(CLIPS, key, "idle_up")
    idle = [Image.open(os.path.join(idle_dir, n)).convert("RGBA") for n in sorted(os.listdir(idle_dir)) if n.endswith(".png")]
    n = int(SPEC["clips"][clip]["frames"]) + 1
    out_dir = os.path.join(CLIPS, key, clip + "_up")
    os.makedirs(out_dir, exist_ok=True)
    for old in os.listdir(out_dir):
        if old.endswith(".png"):
            os.remove(os.path.join(out_dir, old))
    lifts = curve(n, lift)
    for i, d in enumerate(lifts):
        lift_frame(idle[i % len(idle)], hip, d).save(os.path.join(out_dir, "%03d.png" % i))
    print("%s/%s_up: %d frames, lift %s" % (key, clip, n, lifts))
    if "--no-ledger" not in sys.argv:
        p = os.path.join(ROOT, "art", "dino-v2", "ledger", key + ".json")
        led = json.load(open(p, encoding="utf-8"))
        entry = led.get(clip + "_up", {})
        entry["method"] = "lift_back.py --hip %d --lift %d" % (hip, lift)
        entry["status"] = entry.get("status", "done") if entry.get("status") != "submitted" else "done"
        led[clip + "_up"] = entry
        tmp = p + ".tmp"
        json.dump(led, open(tmp, "w", encoding="utf-8"), indent=1)
        os.replace(tmp, p)


if __name__ == "__main__":
    main()
