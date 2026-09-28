"""Pass 18: saddles for every beast a keeper can ride (Hank: "Allosaurus,
T-Rex, Bronto... you should be able to ride basically every major dino...
adding the saddles for them and animations for them as well").

    python tools/dino/saddle_paint.py KEY [KEY ...] [--preview PATH]

The stego's and the trike's saddled clips were drawn by PixelLab, a whole set
each. For the rest a saddle is painted onto the beast's own exported clips
(game/Forest/creatures/art/v2/KEY/), in code, frame by frame:

  - its seat on the resting drawing, per facing: side-on over the middle of
    its legs, on the top of its back (SEAT has the odd one by hand: the
    spinosaur's sits in front of its sail); from the front just behind the
    head; from behind over the back;
  - each frame's seat found by laying the resting drawing's back (a patch
    round the seat) onto the frame (the best of every shift within reach),
    so the saddle rides every stride, bite and sweep;
  - a leather saddle drawn there in the facing's view (side: cantle, seat and
    pommel on a coloured blanket, a girth strap; front and back: the arch of
    it, the straps down both flanks), sized to the beast.

Writes game/Forest/creatures/art/v2/KEY_saddle/<clip>_<facing>.png and
KEY_saddle.json (its clips, each with the per-frame `seat` shifts the rider
follows, and `seat_at`: the seat on the canvas per facing).
"""
import json
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
V2 = os.path.join(ROOT, "game", "Forest", "creatures", "art", "v2")
VIEWS = ("side", "down", "up")
# The clips a ridden beast plays (a walk and a run, the rider's strike, a flinch).
RIDDEN = {
    "allo": ["idle", "walk", "run", "bite", "chomp", "roar", "hurt"],
    "rex": ["idle", "walk", "run", "bite", "chomp", "roar", "hurt"],
    "carno": ["idle", "walk", "run", "bite", "roar", "hurt"],
    "yuty": ["idle", "walk", "run", "bite", "chomp", "roar", "hurt"],
    "longneck": ["idle", "walk", "stomp", "tail_swing", "tail_swing_far", "hurt"],
    "parasaur": ["idle", "walk", "run", "stomp", "roar", "hurt"],
    "anky": ["idle", "walk", "tail_swing", "tail_swing_far", "hurt"],
    "spino": ["idle", "walk", "run", "bite", "slash", "roar", "hurt"],
    "sucho": ["idle", "walk", "run", "bite", "chomp", "hurt"],
    "utah": ["idle", "walk", "run", "slash", "pounce", "hurt"],
    "deino": ["idle", "walk", "run", "slash", "pounce", "hurt"],
    "raptor": ["idle", "walk", "run", "slash", "pounce", "hurt"],
    "dimetrodon": ["idle", "walk", "run", "bite", "chomp", "hurt"],
    "thyla": ["idle", "walk", "run", "maul", "pounce", "hurt"],
    "ptera": ["idle", "walk", "bite", "takeoff", "hurt"],
    "pterafly": ["fly", "glide", "swoop", "screech", "hurt"],
}
# Seats set by hand (canvas px) where the rule misses.
SEAT = {
    # On its shoulders, just in front of the sail.
    "spino": {"side": (123, 91), "down": (91, 83), "up": (91, 84)},
    # In front of its sail too.
    "dimetrodon": {"side": (73, 57), "up": (56, 64)},
    # On the wing: on its back at the wings' roots.
    "pterafly": {"side": (49, 53)},
}
# The saddle's width by the beast's size.
WIDTH = {"raptor": 10, "deino": 10, "thyla": 11, "ptera": 10, "pterafly": 11, "utah": 12, "dimetrodon": 13,
         "allo": 14, "carno": 14, "parasaur": 14, "sucho": 15, "yuty": 16, "rex": 17, "anky": 17, "longneck": 18, "spino": 18}
OUT_C = (26, 23, 38)
DARK = (74, 46, 28)
MID = (122, 78, 44)
LIGHT = (170, 118, 64)
RED = (150, 52, 42)
TRIM = (206, 160, 72)
STRAP = (52, 34, 24)


def load_meta(key):
    return json.load(open(os.path.join(V2, key + ".json"), encoding="utf-8"))


def frames_of(key, clip, view, meta):
    path = os.path.join(V2, key, "%s_%s.png" % (clip, view))
    if not os.path.exists(path):
        return []
    strip = Image.open(path).convert("RGBA")
    cw, ch = meta["canvas"]
    n = strip.width // cw
    return [strip.crop((i * cw, 0, (i + 1) * cw, ch)) for i in range(n)]


def seat_of(key, view, ref):
    if key in SEAT and view in SEAT[key]:
        return SEAT[key][view]
    px = ref.load()
    b = ref.getbbox()
    w, h = ref.size
    if view == "side":
        cols = [x for x in range(w) if any(px[x, y][3] for y in range(b[3] - 5, b[3]))]
        sx = int(sum(cols) / len(cols)) if cols else (b[0] + b[2]) // 2
        # The back's top there, skipping a thin spine or crest (a run of
        # opaque pixels at least 5 wide round the column).
        sy = b[1]
        for y in range(b[1], b[3]):
            run = sum(1 for x in range(sx - 3, sx + 4) if 0 <= x < w and px[x, y][3])
            if run >= 6:
                sy = y
                break
        return (sx, sy + 1)
    cols = [x for x in range(w) for y in range(b[1], b[3]) if px[x, y][3]]
    sx = int(round(sum(cols) / len(cols)))
    # The first row wide enough to be head or body (past a thin crest or sail).
    top = b[1]
    for y in range(b[1], b[3]):
        if sum(1 for x in range(sx - 5, sx + 6) if 0 <= x < w and px[x, y][3]) >= 9:
            top = y
            break
    if view == "down":
        # From the front the saddle's behind the head: the rider sits there,
        # drawn behind the beast (its head hides the rider's legs).
        return (sx, top + 2)
    return (sx, top + int((b[3] - top) * 0.3))


def track(ref, frame, seat, reach=(6, 5)):
    """The shift that best lays the resting drawing's back (round the seat) onto `frame`."""
    sx, sy = seat
    rp = ref.load()
    fp = frame.load()
    w, h = ref.size
    patch = []
    for y in range(sy - 2, sy + 9):
        for x in range(sx - 8, sx + 9):
            if 0 <= x < w and 0 <= y < h and rp[x, y][3]:
                patch.append((x, y, rp[x, y][:3]))
    if not patch:
        return (0, 0)
    best, best_off = -1, (0, 0)
    for dy in range(-reach[1], reach[1] + 1):
        for dx in range(-reach[0], reach[0] + 1):
            score = 0
            for x, y, c in patch:
                q = (x + dx, y + dy)
                if 0 <= q[0] < w and 0 <= q[1] < h:
                    p = fp[q]
                    if p[3] and abs(p[0] - c[0]) + abs(p[1] - c[1]) + abs(p[2] - c[2]) < 70:
                        score += 1
            score = score * 100 - abs(dx) - abs(dy)
            if score > best:
                best, best_off = score, (dx, dy)
    return best_off


def _put(px, w, h, x, y, c):
    if 0 <= x < w and 0 <= y < h:
        px[x, y] = c + (255,)


def paint(img, view, at, width, flip=False):
    """A saddle on `img` with its seat at `at` (the rider's hip rests there)."""
    px = img.load()
    w, h = img.size
    x0, y0 = at
    half = width // 2
    if view == "side":
        # Blanket (red, trimmed) under the saddle, a little longer at both ends.
        for x in range(x0 - half - 2, x0 + half + 3):
            _put(px, w, h, x, y0 + 1, RED)
            _put(px, w, h, x, y0 + 2, TRIM if (x - x0) % 3 == 0 else RED)
            _put(px, w, h, x, y0 + 3, OUT_C)
        # The seat: a dip between the cantle (back, left) and the pommel (front).
        for x in range(x0 - half, x0 + half + 1):
            t = (x - (x0 - half)) / max(1, width)
            rise = 2 if t < 0.18 else (1 if t > 0.82 else 0)
            for y in range(y0 - rise, y0 + 1):
                _put(px, w, h, x, y, LIGHT if y == y0 - rise else MID)
            _put(px, w, h, x, y0 - rise - 1, OUT_C)
        _put(px, w, h, x0 - half - 1, y0 - 2, OUT_C)
        _put(px, w, h, x0 + half + 1, y0 - 1, OUT_C)
        # The girth strap and its buckle.
        for y in range(y0 + 4, y0 + 9):
            _put(px, w, h, x0 + 1, y, STRAP)
        _put(px, w, h, x0 + 1, y0 + 6, TRIM)
        return
    if view == "down":
        return  # hidden behind the head (the rider is drawn behind the beast)
    # From behind: the saddle's arch over the back, the blanket's
    # edge showing under it, a strap down each flank.
    for x in range(x0 - half, x0 + half + 1):
        edge = abs(x - x0) >= half - 1
        top = y0 - (1 if not edge else 0) - (1 if view == "up" and abs(x - x0) < half - 2 else 0)
        for y in range(top, y0 + 2):
            _put(px, w, h, x, y, DARK if edge else (LIGHT if y == top else MID))
        _put(px, w, h, x, top - 1, OUT_C)
        _put(px, w, h, x, y0 + 2, RED)
        _put(px, w, h, x, y0 + 3, OUT_C if abs(x - x0) > half - 2 else TRIM)
    for sx in (x0 - half, x0 + half):
        for y in range(y0 + 3, y0 + 9):
            _put(px, w, h, sx, y, STRAP)


def build(key):
    meta = load_meta(key)
    species = meta.get("species", key)
    clips = [c for c in RIDDEN.get(key, ["idle", "walk"]) if c in meta["clips"]]
    width = WIDTH.get(key, 14)
    out_dir = os.path.join(V2, key + "_saddle")
    os.makedirs(out_dir, exist_ok=True)
    out = {k: v for k, v in meta.items() if k != "clips"}
    out["key"] = key + "_saddle"
    out["species"] = species
    out["clips"] = {}
    out["seat_at"] = {}
    # The rider is drawn behind the beast from the front (MountedAppearance).
    out["rider_behind"] = ["down"]
    rest_clip = "idle" if "idle" in meta["clips"] else clips[0]
    for view in VIEWS:
        ref_frames = frames_of(key, rest_clip, view, meta)
        if not ref_frames:
            continue
        ref = ref_frames[0]
        seat = seat_of(key, view, ref)
        out["seat_at"][view] = [seat[0], seat[1]]
        for clip in clips:
            frames = frames_of(key, clip, view, meta)
            if not frames:
                continue
            shifts = []
            painted = []
            for f in frames:
                d = track(ref, f, seat)
                shifts.append([d[0], d[1]])
                g = f.copy()
                paint(g, view, (seat[0] + d[0], seat[1] + d[1]), width)
                painted.append(g)
            cw, ch = meta["canvas"]
            strip = Image.new("RGBA", (cw * len(painted), ch), (0, 0, 0, 0))
            for i, g in enumerate(painted):
                strip.paste(g, (i * cw, 0))
            strip.save(os.path.join(out_dir, "%s_%s.png" % (clip, view)))
            entry = out["clips"].setdefault(clip, {k: v for k, v in meta["clips"][clip].items() if k != "seat"})
            entry.setdefault("seat", {})[view] = shifts
    json.dump(out, open(os.path.join(V2, key + "_saddle.json"), "w", encoding="utf-8"))
    print("saddled", key, "clips", len(out["clips"]), "seats", out["seat_at"])
    return out


def preview(keys, path):
    rows = []
    for key in keys:
        meta = json.load(open(os.path.join(V2, key + "_saddle.json"), encoding="utf-8"))
        row = []
        for view in VIEWS:
            p = os.path.join(V2, key + "_saddle", "walk_%s.png" % view)
            if not os.path.exists(p):
                p = os.path.join(V2, key + "_saddle", "fly_%s.png" % view)
            if not os.path.exists(p):
                continue
            strip = Image.open(p).convert("RGBA")
            cw, ch = meta["canvas"]
            row.append(strip.crop((0, 0, min(strip.width, cw * 4), ch)))
        rows.append(row)
    z = 2
    wid = max(sum(im.width * z + 8 for im in r) for r in rows) + 8
    hei = sum(max(im.height for im in r) * z + 8 for r in rows) + 8
    sheet = Image.new("RGBA", (wid, hei), (86, 118, 70, 255))
    y = 8
    for r in rows:
        x = 8
        for im in r:
            sheet.alpha_composite(im.resize((im.width * z, im.height * z), Image.NEAREST), (x, y))
            x += im.width * z + 8
        y += max(im.height for im in r) * z + 8
    sheet.save(path)
    print("preview", path, sheet.size)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if "--preview" in sys.argv:
        path = sys.argv[sys.argv.index("--preview") + 1]
        keys = [a for a in args if a != path]
        for k in keys:
            build(k)
        preview(keys, path)
        return
    for k in args:
        build(k)


if __name__ == "__main__":
    main()
