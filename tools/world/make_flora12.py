"""Pass 12 flora: more undergrowth for the ground layer (ForestFlora), drawn
here in the tufts' own greens and appended to game/Forest/ground/art/flora.png
(32 x 32 cells, the plant bottom-centred on its root):

  shrubs  small leafy bushes for the meadows (4)
  ferns   arching fronds for the forest floor (3)
  scrub   dry, twiggy desert brush for the sand (3)

    python tools/world/make_flora12.py

Idempotent: cells from index 33 on are redrawn each run; flora.json gets the
kinds and the sprite sizes.
"""
import json
import math
import os
import random

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ATLAS = os.path.join(ROOT, "game", "Forest", "ground", "art", "flora.png")
META = os.path.join(ROOT, "game", "Forest", "ground", "art", "flora.json")
FIRST = 33
CELL = 32
COLS = 16

OUT = (40, 74, 42, 255)
DARK = (58, 104, 50, 255)
MID = (84, 140, 62, 255)
LEAF = (116, 172, 76, 255)
LIGHT = (160, 206, 104, 255)
BERRY = (198, 67, 84, 255)
SCRUB_OUT = (86, 78, 58, 255)
SCRUB = (150, 142, 98, 255)
SCRUB_LIGHT = (196, 186, 132, 255)
SCRUB_DARK = (118, 108, 74, 255)


def outline(img, body):
    px = img.load()
    for (x, y) in list(body):
        for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if n not in body and 0 <= n[0] < CELL and 0 <= n[1] < CELL and px[n][3] == 0:
                px[n] = OUT


def shrub(seed, w, h):
    """A rounded leafy bush: overlapping leaf clusters, lit from the top left,
    a darker underside, a few pale leaf tips (and sometimes berries)."""
    rnd = random.Random(seed)
    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    px = img.load()
    cx, base = CELL / 2.0, CELL - 1
    # Many small leaf clusters (a bumpy, leafy edge rather than a smooth
    # blob), smaller ones along the top.
    blobs = []
    for i in range(14):
        bx = cx + rnd.uniform(-w * 0.4, w * 0.4)
        up = rnd.random()
        by = base - 2 - up * h * 0.75
        r = rnd.uniform(2.0, 3.4) if up > 0.55 else rnd.uniform(3.0, 4.6)
        blobs.append((bx, by, r))
    body = set()
    for y in range(CELL):
        for x in range(CELL):
            for (bx, by, r) in blobs:
                if (x + 0.5 - bx) ** 2 + ((y + 0.5 - by) * 1.15) ** 2 <= r * r and y <= base:
                    body.add((x, y))
                    break
    top = min(y for _, y in body) if body else base
    for (x, y) in body:
        depth = (y - top) / max(1.0, base - top)
        lit = (x - cx) / max(1.0, w / 2.0)
        if depth > 0.72:
            px[x, y] = DARK
        elif depth < 0.3 and lit < 0.2:
            px[x, y] = LIGHT
        elif depth < 0.55:
            px[x, y] = LEAF
        else:
            px[x, y] = MID
    # Leaf texture: the shadowed side of every little cluster (below and
    # right of each clump's centre), pale tips along the top of each.
    for (bx, by, r) in blobs:
        for (x, y) in body:
            dx, dy = x + 0.5 - bx, y + 0.5 - by
            d2 = dx * dx + dy * dy
            if r * r * 0.45 < d2 <= r * r and dx + dy > 0.8 and px[x, y] in (LEAF, LIGHT):
                px[x, y] = MID
            elif d2 <= r * r * 0.3 and dx + dy < -0.8 and px[x, y] in (LEAF, MID) and y < base - 3:
                px[x, y] = LIGHT
    for (x, y) in body:
        if (x, y - 1) not in body and rnd.random() < 0.5:
            px[x, y] = LIGHT
    if rnd.random() < 0.5:
        for i in range(3):
            x, y = rnd.choice(sorted(body))
            if y < base - 2:
                px[x, y] = BERRY
    outline(img, body)
    return img


def fern(seed):
    """Arching fronds from one root: a curved rib with little leaflets."""
    rnd = random.Random(seed)
    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    px = img.load()
    root = (CELL / 2.0, CELL - 1.5)
    body = set()
    for f in range(rnd.randint(5, 7)):
        angle = math.radians(rnd.uniform(-160, -20))
        length = rnd.uniform(9, 14)
        bend = rnd.uniform(0.04, 0.09) * (1 if math.cos(angle) > 0 else -1)
        x, y = root
        a = angle
        for step in range(int(length)):
            x += math.cos(a)
            y += math.sin(a)
            a += bend
            p = (int(round(x)), int(round(y)))
            if 0 <= p[0] < CELL and 0 <= p[1] < CELL:
                body.add(p)
                # Leaflets either side, shorter toward the tip.
                if step % 2 == 0 and step < length - 2:
                    for side in (-1, 1):
                        q = (int(round(x + math.cos(a + side * 1.4) * 1.6)), int(round(y + math.sin(a + side * 1.4) * 1.6)))
                        if 0 <= q[0] < CELL and 0 <= q[1] < CELL:
                            body.add(q)
    for (x, y) in body:
        px[x, y] = LEAF if y < CELL - 8 else MID
    for (x, y) in body:
        if (x, y - 1) not in body and rnd.random() < 0.4:
            px[x, y] = LIGHT
    outline(img, body)
    return img


def scrub(seed):
    """Dry desert brush: a low tangle of grey-olive twigs with pale tips."""
    rnd = random.Random(seed)
    img = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    px = img.load()
    root = (CELL / 2.0, CELL - 1.5)
    body = set()
    for t in range(rnd.randint(9, 13)):
        angle = math.radians(rnd.uniform(-170, -10))
        length = rnd.uniform(5, 10)
        x, y = root
        a = angle
        for step in range(int(length)):
            x += math.cos(a) * 1.1
            y += math.sin(a) * 0.8
            a += rnd.uniform(-0.35, 0.35)
            p = (int(round(x)), int(round(y)))
            if 0 <= p[0] < CELL and 0 <= p[1] < CELL:
                body.add(p)
    for (x, y) in body:
        px[x, y] = SCRUB if y < CELL - 4 else SCRUB_DARK
    for (x, y) in body:
        if (x, y - 1) not in body and rnd.random() < 0.5:
            px[x, y] = SCRUB_LIGHT
    for (x, y) in list(body):
        for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if n not in body and 0 <= n[0] < CELL and 0 <= n[1] < CELL and px[n][3] == 0 and rnd.random() < 0.55:
                px[n] = SCRUB_OUT
    return img


def main():
    atlas = Image.open(ATLAS).convert("RGBA")
    meta = json.load(open(META))
    sprites = [shrub(101, 18, 13), shrub(202, 22, 15), shrub(303, 15, 11), shrub(404, 20, 14),
               fern(11), fern(22), fern(33),
               scrub(7), scrub(8), scrub(9)]
    total = FIRST + len(sprites)
    rows = (total + COLS - 1) // COLS
    if atlas.height < rows * CELL:
        grown = Image.new("RGBA", (COLS * CELL, rows * CELL), (0, 0, 0, 0))
        grown.alpha_composite(atlas, (0, 0))
        atlas = grown
    sizes = meta["sizes"][:FIRST]
    for i, spr in enumerate(sprites):
        index = FIRST + i
        x0, y0 = (index % COLS) * CELL, (index // COLS) * CELL
        atlas.paste((0, 0, 0, 0), (x0, y0, x0 + CELL, y0 + CELL))
        atlas.alpha_composite(spr, (x0, y0))
        box = spr.getbbox()
        sizes.append([box[2] - box[0], box[3] - box[1]])
    meta["sizes"] = sizes
    meta["kinds"]["shrubs"] = {"first": FIRST, "count": 4}
    meta["kinds"]["ferns"] = {"first": FIRST + 4, "count": 3}
    meta["kinds"]["scrub"] = {"first": FIRST + 7, "count": 3}
    atlas.save(ATLAS)
    json.dump(meta, open(META, "w"), indent=1)
    print("flora: shrubs, ferns, scrub ->", total, "sprites")


if __name__ == "__main__":
    main()
