"""Cravera Dinosaur Factory, step 2: Blender renders -> the game's pixel sprites.

    python tools/blender/pixelize.py carno [--colours 30] [--no-export]

Reads art/blender/<key>/raw/<clip>_<facing>/NNN.png (dino_factory.py, rendered
at SCALE x) and:
  1. brings each frame down to game pixels: every SCALE x SCALE block becomes
     one pixel (opaque when enough of it is covered; its colour the block's
     commonest opaque colour, so edges stay crisp instead of blended);
  2. snaps every frame of every clip to one palette (median cut over them all,
     so the animal keeps its colours from frame to frame and facing to facing);
  3. drops stray pixels and draws Cravera's dark 1 px outline round the body;
  4. writes the frames (art/blender/<key>/frames/) and, unless --no-export,
     the game's strips and catalogue: game/Forest/creatures/art/v2/<key>/
     <clip>_<facing>.png and <key>.json (the DinoArt format export.py writes),
     plus the resting drawings game/Forest/creatures/art/<key>[_down|_up].png.
"""
import json
import os
import sys
from collections import Counter

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SCALE = 4
COVER = 6  # of SCALE*SCALE sub-pixels for a pixel to be solid
# Clip timing (matches dino_factory.CLIPS) and the frame each blow lands on.
CLIPS = {"idle": (6, True), "walk": (9, True), "run": (13, True), "bite": (14, False), "roar": (10, False),
         "hurt": (12, False), "death": (10, False)}
HITS = {"bite": 5}
FACINGS = ("side", "down", "up")


def downsample(img):
    w, h = img.width // SCALE, img.height // SCALE
    src = img.load()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    dst = out.load()
    for y in range(h):
        for x in range(w):
            cols = Counter()
            covered = 0
            for sy in range(SCALE):
                for sx in range(SCALE):
                    p = src[x * SCALE + sx, y * SCALE + sy]
                    if p[3] >= 128:
                        covered += 1
                        cols[(p[0] >> 2 << 2, p[1] >> 2 << 2, p[2] >> 2 << 2)] += 1
            if covered >= COVER:
                dst[x, y] = cols.most_common(1)[0][0] + (255,)
    return out


def palette_of(frames, n):
    px = []
    for im in frames:
        px += [p[:3] for p in im.getdata() if p[3] > 0]
    strip = Image.new("RGB", (len(px), 1))
    strip.putdata(px)
    q = strip.quantize(colors=n, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    return sorted(set(q.convert("RGB").getdata()), key=lambda c: c[0] * 0.3 + c[1] * 0.59 + c[2] * 0.11)


def weighted(c, p):
    r = (c[0] + p[0]) / 2
    dr, dg, db = c[0] - p[0], c[1] - p[1], c[2] - p[2]
    return (2 + r / 256) * dr * dr + 4 * dg * dg + (2 + (255 - r) / 256) * db * db


def snap(img, pal, cache):
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            p = px[x, y]
            if p[3] == 0:
                continue
            k = p[:3]
            if k not in cache:
                cache[k] = min(pal, key=lambda q: weighted(k, q))
            px[x, y] = cache[k] + (255,)


def tidy(img, outline):
    """Drop lone pixels (fewer than two solid neighbours), then outline."""
    px = img.load()
    W, H = img.size
    solid = lambda x, y: 0 <= x < W and 0 <= y < H and px[x, y][3] > 0
    lone = [(x, y) for y in range(H) for x in range(W)
            if px[x, y][3] > 0 and sum(solid(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))) < 2]
    for (x, y) in lone:
        px[x, y] = (0, 0, 0, 0)
    edge = [(x, y) for y in range(H) for x in range(W)
            if px[x, y][3] == 0 and any(solid(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
    for (x, y) in edge:
        px[x, y] = outline + (255,)


def main():
    key = sys.argv[1]
    n_colours = int(sys.argv[sys.argv.index("--colours") + 1]) if "--colours" in sys.argv else 30
    raw = os.path.join(ROOT, "art", "blender", key, "raw")
    out = os.path.join(ROOT, "art", "blender", key, "frames")
    # 1. down to game pixels
    frames = {}
    for name in sorted(os.listdir(raw)):
        files = sorted(f for f in os.listdir(os.path.join(raw, name)) if f.endswith(".png"))
        frames[name] = [downsample(Image.open(os.path.join(raw, name, f)).convert("RGBA")) for f in files]
    # 2. one palette for every frame
    pal = palette_of([im for seq in frames.values() for im in seq], n_colours)
    darkest = pal[0]
    outline = tuple(max(0, int(c * 0.35)) for c in darkest)
    cache = {}
    for seq in frames.values():
        for im in seq:
            snap(im, pal, cache)
            tidy(im, outline)
    for name, seq in frames.items():
        d = os.path.join(out, name)
        os.makedirs(d, exist_ok=True)
        for i, im in enumerate(seq):
            im.save(os.path.join(d, "%03d.png" % i))
    print("pixelized", sum(len(s) for s in frames.values()), "frames,", len(pal) + 1, "colours")
    if "--no-export" in sys.argv:
        return
    # 3. the game's strips and catalogue (DinoArt)
    first = frames[next(iter(frames))][0]
    w, h = first.size
    game = os.path.join(ROOT, "game", "Forest", "creatures", "art")
    v2 = os.path.join(game, "v2", key)
    os.makedirs(v2, exist_ok=True)
    meta = {"key": key, "species": key, "canvas": [w, h], "ground": h - 7, "origin": {}, "clips": {},
            "source": "blender"}
    for clip, (fps, loop) in CLIPS.items():
        views = [f for f in FACINGS if ("%s_%s" % (clip, f)) in frames]
        if not views:
            continue
        count = len(frames["%s_%s" % (clip, views[0])])
        info = {"fps": fps, "loop": loop, "frames": count}
        if clip in HITS:
            info["hit"] = HITS[clip]
            info["hit_view"] = {v: HITS[clip] for v in views}
        meta["clips"][clip] = info
        for v in views:
            seq = frames["%s_%s" % (clip, v)]
            strip = Image.new("RGBA", (w * len(seq), h), (0, 0, 0, 0))
            for i, im in enumerate(seq):
                strip.alpha_composite(im, (i * w, 0))
            strip.save(os.path.join(v2, "%s_%s.png" % (clip, v)))
    for v in FACINGS:
        rest = frames.get("idle_" + v, [None])[0]
        if rest is None:
            continue
        box = rest.getbbox()
        meta["origin"][v] = [box[0], box[1]]
        rest.crop(box).save(os.path.join(game, key + ("" if v == "side" else "_" + v) + ".png"))
    json.dump(meta, open(os.path.join(game, "v2", key + ".json"), "w", encoding="utf-8"), indent=1)
    print("exported", key, "canvas %dx%d" % (w, h), "clips", list(meta["clips"]))


if __name__ == "__main__":
    main()
