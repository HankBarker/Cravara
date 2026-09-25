"""Front- and back-view bites built from the creature's own resting drawing,
for keys whose generated ones fell apart (Ossuar: from the front the whole
skeleton turned into a column with a giant red mouth; from behind it
stretched thin and then turned side-on).

    python tools/dino/lunge_front.py KEY CLIP [--view down|up] [--preview PATH]

CLIP is bite (9 frames), chomp (13, a bigger wind-up) or eat (13, a
graze from the front). The legs stay planted
(the bottom rows either side of a central gap, as walk_front.py finds them);
everything above the hips rears up and then snaps at the target:

  - facing the viewer (down): the body stretches up (the wind-up), then
    drops and widens toward the viewer: the head comes down at you;
  - facing away (up): it crouches, then stretches up and narrows away.

Each frame is an inverse mapping of the resting drawing (nearest pixel), so
nothing tears or leaves holes. Frame 0 is the untouched drawing. Writes
art/dino-v2/clips/KEY/CLIP_VIEW/ and records the method in the ledger; the
contact frame (the deepest snap) goes in hits.json.
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen  # noqa: E402
import walk_front  # noqa: E402

OUT = gen.OUT
# Per clip and facing: (vertical scale of the body above the hips, horizontal
# scale about its centre) per frame. The contact is the deepest snap.
SHAPES = {
    ("bite", "down"): ([1.0, 1.03, 1.06, 1.06, 0.95, 0.9, 0.93, 0.97, 1.0],
                       [1.0, 1.0, 1.0, 1.0, 1.03, 1.05, 1.03, 1.01, 1.0]),
    ("bite", "up"): ([1.0, 0.97, 0.94, 0.94, 1.05, 1.08, 1.05, 1.02, 1.0],
                     [1.0, 1.0, 1.0, 1.0, 0.98, 0.97, 0.98, 0.99, 1.0]),
    ("chomp", "down"): ([1.0, 1.02, 1.05, 1.08, 1.1, 1.1, 0.93, 0.86, 0.86, 0.9, 0.94, 0.97, 1.0],
                        [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.04, 1.07, 1.07, 1.05, 1.03, 1.01, 1.0]),
    ("chomp", "up"): ([1.0, 0.98, 0.95, 0.92, 0.9, 0.9, 1.06, 1.11, 1.11, 1.08, 1.05, 1.02, 1.0],
                      [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.98, 0.96, 0.96, 0.97, 0.98, 0.99, 1.0]),
    # Grazing from the front (the parasaur's generated one shrank the animal
    # to a dome): the head dips toward the ground and chews.
    ("eat", "down"): ([1.0, 0.97, 0.93, 0.9, 0.88, 0.87, 0.88, 0.87, 0.88, 0.9, 0.93, 0.97, 1.0],
                      [1.0, 1.0, 1.01, 1.02, 1.02, 1.02, 1.02, 1.02, 1.02, 1.02, 1.01, 1.0, 1.0]),
    # Ossuar's roar from the front and behind (the generated ones failed QA on
    # its glowing crystal every try): it rears up tall, holds, and settles.
    ("roar", "down"): ([1.0, 1.03, 1.06, 1.09, 1.11, 1.12, 1.12, 1.12, 1.12, 1.1, 1.06, 1.03, 1.0],
                       [1.0, 1.0, 1.01, 1.02, 1.03, 1.04, 1.04, 1.04, 1.04, 1.03, 1.02, 1.01, 1.0]),
    ("roar", "up"): ([1.0, 1.03, 1.06, 1.09, 1.11, 1.12, 1.12, 1.12, 1.12, 1.1, 1.06, 1.03, 1.0],
                     [1.0, 1.0, 1.01, 1.02, 1.03, 1.04, 1.04, 1.04, 1.04, 1.03, 1.02, 1.01, 1.0]),
    # The parasaur's front clips, rebuilt on its pass-12 front drawing (the
    # generated ones were drawn on the old one): breathing, a rear-and-slam
    # stomp, a flinch, and a collapse toward the viewer.
    ("idle", "down"): ([1.0, 1.02, 1.04, 1.045, 1.04, 1.02, 1.0, 0.99],
                       [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]),
    ("stomp", "down"): ([1.0, 1.03, 1.06, 1.09, 1.11, 1.12, 1.1, 0.92, 0.88, 0.9, 0.94, 0.97, 1.0],
                        [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.05, 1.07, 1.05, 1.03, 1.01, 1.0]),
    ("hurt", "down"): ([1.0, 0.94, 0.92, 0.96, 1.0], [1.0, 1.02, 1.02, 1.01, 1.0]),
    ("death", "down"): ([1.0, 0.98, 0.95, 0.9, 0.84, 0.76, 0.68, 0.6, 0.54, 0.5, 0.48, 0.47, 0.47],
                        [1.0, 1.0, 1.01, 1.02, 1.04, 1.06, 1.08, 1.1, 1.12, 1.13, 1.14, 1.14, 1.14]),
    # A flinch side-on: the body drops into its hips and comes back.
    ("hurt", "side"): ([1.0, 0.94, 0.92, 0.96, 1.0], [1.0, 1.0, 1.0, 1.0, 1.0]),
}
CONTACT = {"bite": 5, "chomp": 7, "eat": 0, "roar": 0, "hurt": 0, "idle": 0, "stomp": 8, "death": 0}


def build(key, clip, view):
    drawing = Image.open(os.path.join(OUT, "first", "%s_%s.png" % (key, view))).convert("RGBA")
    src = drawing.load()
    w, h = drawing.size
    rig = walk_front.rig_for(key)
    legs, body, bottom, centre = walk_front.masks(drawing, rig)
    leg_px = set().union(*legs)
    hip = bottom - rig["legs"] + 1
    sys_, sxs = SHAPES[(clip, view)]
    frames = []
    for sy, sx in zip(sys_, sxs):
        out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        dst = out.load()
        for y in range(h):
            for x in range(w):
                if y >= hip:
                    # The hips and legs don't move (the body's own pixels
                    # down there are copied as they are).
                    if src[x, y][3] and (x, y) not in leg_px:
                        dst[x, y] = src[x, y]
                    continue
                fy = hip - (hip - y) / sy
                fx = centre + (x - centre) / sx
                ix, iy = int(round(fx)), int(round(fy))
                if 0 <= ix < w and 0 <= iy < hip and src[ix, iy][3] and (ix, iy) not in leg_px:
                    dst[x, y] = src[ix, iy]
        for x, y in leg_px:
            dst[x, y] = src[x, y]
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
    entry.update({"status": "done", "method": "lunge_front.py (%s from the %s drawing)" % (clip, view), "frames": len(frames)})
    led[name] = entry
    gen.save_ledger(key, led)
    # The contact frame for this facing (attacks only), as export.py reads it.
    if CONTACT.get(clip, 0) > 0 and clip in ("bite", "chomp", "stomp"):
        import json
        hits_path = os.path.join(HERE, "hits.json")
        hits = json.load(open(hits_path, encoding="utf-8")) if os.path.exists(hits_path) else {}
        entry = hits.setdefault(key, {}).get(clip)
        if not isinstance(entry, dict):
            entry = {v: int(entry) for v in ("side", "down", "up")} if entry is not None else {}
        entry[view] = CONTACT[clip]
        hits[key][clip] = entry
        with open(hits_path, "w", encoding="utf-8") as f:
            json.dump(hits, f, indent=1)
            f.write("\n")
    print("built", dst_dir, len(frames), "frames; contact", CONTACT[clip])


def main():
    key, clip = sys.argv[1], sys.argv[2]
    view = sys.argv[sys.argv.index("--view") + 1] if "--view" in sys.argv else "down"
    frames = build(key, clip, view)
    if "--preview" in sys.argv:
        walk_front.preview(frames, sys.argv[sys.argv.index("--preview") + 1])
    else:
        write(key, clip, view, frames)


if __name__ == "__main__":
    main()
