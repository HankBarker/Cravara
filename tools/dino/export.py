"""Export cleaned dinosaur clips into the game.

    python tools/dino/export.py [KEY ...]

Reads art/dino-v2/clips/KEY/CLIP_VIEW/*.png (from gen.py) and writes
game/Forest/creatures/art/v2/KEY/CLIP_VIEW.png - one horizontal strip per clip
and facing - plus game/Forest/creatures/art/v2/KEY.json, the clip catalogue
the game reads (DinoArt.gd):

  {"key", "species", "canvas": [w, h], "ground": row the feet stand on,
   "clips": {CLIP: {"frames", "fps", "loop", "hit": frame the blow lands,
                    "placeholder": true when no generated art exists yet}}}

A clip without generated art is exported as a placeholder (the resting drawing
repeated), so the game always has every clip. Hit frames come from
tools/dino/hits.json (reviewed by eye) or, failing that, the most extended pose.
"""
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
SRC = os.path.join(ROOT, "art", "dino-v2")
DST = os.path.join(ROOT, "game", "Forest", "creatures", "art", "v2")
SPEC = json.load(open(os.path.join(HERE, "clips.json"), encoding="utf-8"))
VIEWS = ("side", "down", "up")
GROUND = 6
ATTACKS = {"bite", "chomp", "slash", "pounce", "tail_swing", "tail_swing_far", "stomp", "gore", "peck"}


def frames_of(key, clip, view):
    d = os.path.join(SRC, "clips", key, "%s_%s" % (clip, view))
    if not os.path.isdir(d):
        return []
    return [Image.open(os.path.join(d, n)).convert("RGBA") for n in sorted(os.listdir(d)) if n.endswith(".png")]


def extended_frame(frames):
    """Index of the pose furthest from the resting drawing (a fair first guess
    for the contact frame of an attack)."""
    base = frames[0]
    best, best_i = -1, len(frames) // 2
    for i, f in enumerate(frames[1:], 1):
        a, b = base.getbbox(), f.getbbox()
        if not a or not b:
            continue
        spread = abs(a[0] - b[0]) + abs(a[2] - b[2]) + abs(a[1] - b[1])
        diff = sum(1 for p, q in zip(base.getdata(), f.getdata()) if (p[3] > 0) != (q[3] > 0))
        score = spread * 40 + diff
        if score > best:
            best, best_i = score, i
    return best_i


def saddle_template(key, view):
    """Pixels of the saddle (saddled drawing minus the bare one) on the canvas."""
    sp = key.split("_")[0]
    saddled = Image.open(os.path.join(SRC, "first", "%s_%s.png" % (key, view))).convert("RGBA")
    bare = Image.open(os.path.join(SRC, "first", "%s_%s.png" % (sp, view))).convert("RGBA")
    pts = []
    for y in range(saddled.height):
        for x in range(saddled.width):
            a = saddled.getpixel((x, y))
            b = bare.getpixel((x, y))
            if a[3] and a[:3] != b[:3]:
                pts.append((x, y, a[:3]))
    return pts


def track(frame, template, radius=6):
    """Offset (dx, dy) that best lays the saddle template onto `frame`."""
    if not template:
        return (0, 0)
    template = template[::3]
    px = frame.load()
    w, h = frame.size
    best, best_off = -1, (0, 0)
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            score = 0
            for x, y, c in template:
                q = (x + dx, y + dy)
                if 0 <= q[0] < w and 0 <= q[1] < h:
                    p = px[q]
                    if p[3] and abs(p[0] - c[0]) + abs(p[1] - c[1]) + abs(p[2] - c[2]) < 60:
                        score += 1
            # Prefer the smallest shift among equals: a still saddle stays put.
            score = score * 100 - abs(dx) - abs(dy)
            if score > best:
                best, best_off = score, (dx, dy)
    return best_off


def frame_origin(key, view):
    """Top-left of the original drawing on the canvas (prepare.py placement)."""
    sys.path.insert(0, HERE)
    import prepare
    sp = key.split("_")[0]
    img = prepare.source(key, view)
    snapped = Image.open(os.path.join(SRC, "base", "%s_%s.png" % (key, view))).convert("RGBA")
    cw, ch = prepare.CANVAS[sp]
    box = snapped.getbbox()
    return [(cw - img.width) // 2, ch - prepare.GROUND - box[3]]


def main():
    keys = sys.argv[1:] or list(SPEC["keys"])
    hits = {}
    hp = os.path.join(HERE, "hits.json")
    if os.path.exists(hp):
        hits = json.load(open(hp, encoding="utf-8"))
    for key in keys:
        info = SPEC["keys"][key]
        first = Image.open(os.path.join(SRC, "first", "%s_side.png" % key)).convert("RGBA")
        w, h = first.size
        out_dir = os.path.join(DST, key)
        os.makedirs(out_dir, exist_ok=True)
        meta = {"key": key, "species": info["species"], "canvas": [w, h], "ground": h - GROUND - 1,
                "origin": {v: frame_origin(key, v) for v in VIEWS}, "clips": {}}
        saddled = key.endswith("_saddle")
        templates = {v: saddle_template(key, v) for v in VIEWS} if saddled else {}
        for clip in info["clips"]:
            c = SPEC["clips"][clip]
            views = tuple(c.get("views", VIEWS))  # a few clips exist side-on only
            entry = {"fps": c["fps"], "loop": bool(c.get("loop"))}
            if views != VIEWS:
                entry["views"] = list(views)
            counts = []
            placeholder = False
            per_view = {}
            for view in views:
                fr = frames_of(key, clip, view)
                if not fr:
                    placeholder = True
                    base = Image.open(os.path.join(SRC, "first", "%s_%s.png" % (key, view))).convert("RGBA")
                    n = int(c["frames"]) if c.get("loop") else int(c["frames"]) + 1
                    fr = [base] * n
                per_view[view] = fr
                counts.append(len(fr))
            n = min(counts)
            for view, fr in per_view.items():
                strip = Image.new("RGBA", (w * n, h), (0, 0, 0, 0))
                for i, f in enumerate(fr[:n]):
                    strip.alpha_composite(f, (i * w, 0))
                strip.save(os.path.join(out_dir, "%s_%s.png" % (clip, view)))
            entry["frames"] = n
            if placeholder:
                entry["placeholder"] = True
            if saddled:
                # Where the saddle (and so the rider's seat) moved in each frame.
                entry["seat"] = {v: [list(track(f, templates[v])) for f in per_view[v][:n]] for v in views}
            hit_by_view = {}
            if clip in ATTACKS:
                # Contact (and take-off) frames per facing: each facing's clip was
                # generated on its own, so the blow can land on different frames.
                override = hits.get(key, {}).get(clip)
                takeoff_by_view = {}
                for v in views:
                    # A number or {"hit", "takeoff"} covers every facing; a dict
                    # keyed by facing covers the facings it names (others: auto).
                    o = override
                    if isinstance(override, dict) and "hit" not in override:
                        o = override.get(v)
                    if isinstance(o, dict):
                        hit_by_view[v] = int(o["hit"])
                        if "takeoff" in o:
                            takeoff_by_view[v] = int(o["takeoff"])
                    elif o is not None:
                        hit_by_view[v] = int(o)
                    else:
                        hit_by_view[v] = extended_frame(per_view[v][:n]) if not placeholder else max(1, n * 5 // 9)
                entry["hit"] = hit_by_view.get("side", hit_by_view[views[0]])
                entry["hit_view"] = hit_by_view
                if takeoff_by_view:
                    entry["takeoff"] = takeoff_by_view.get("side", min(takeoff_by_view.values()))
                    entry["takeoff_view"] = takeoff_by_view
            if clip == "tail_swing" and not placeholder:
                # Which way the tail is out in the front/back clips at contact, so
                # the game can mirror them toward the target's side. (A back view
                # may sweep one way and then the other: the contact frame decides.)
                entry["swing"] = {}
                for v in ("down", "up"):
                    fr = per_view[v][:n]
                    b0 = fr[0].getbbox()
                    grow_l = grow_r = 0
                    hb = fr[min(hit_by_view.get(v, 0), n - 1)].getbbox()
                    if hb and b0:
                        grow_l, grow_r = b0[0] - hb[0], hb[2] - b0[2]
                    if grow_l == grow_r:
                        for f in fr[1:]:
                            b = f.getbbox()
                            if b and b0:
                                grow_l = max(grow_l, b0[0] - b[0])
                                grow_r = max(grow_r, b[2] - b0[2])
                    entry["swing"][v] = "left" if grow_l > grow_r else "right"
            meta["clips"][clip] = entry
        json.dump(meta, open(os.path.join(DST, key + ".json"), "w", encoding="utf-8"), indent=1)
        real = sum(1 for e in meta["clips"].values() if not e.get("placeholder"))
        print("%-13s canvas %dx%d  clips %d (%d generated)" % (key, w, h, len(meta["clips"]), real))


if __name__ == "__main__":
    main()
