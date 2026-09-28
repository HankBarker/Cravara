"""Slice the PixelLab Keeper v2 base rotations into rig parts.

Input : art/keeper-v2/source/base_{south,east,north}.png  (32x32, PixelLab pro-flash + V3 rotations)
Output: game/Forest/keeper/art/base/{head,torso,boot}_{down,up,side}.png (+ .mat.png material masks)
        game/Forest/keeper/art/base/rig.json   (anchors in 64x64 cel coordinates)
        art/keeper-v2/review/base-labels.png   (label overlay for review)

The runtime rig (game/Forest/keeper/KeeperRig.gd) draws limbs procedurally
from joint positions, so arms and legs are *not* exported as sprites; only
their colour ramps are sampled here.
"""
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from keeper_palette import MATERIALS, hls, lum, nearest, hexc  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "art", "keeper-v2", "source")
OUT = os.path.join(ROOT, "game", "Forest", "keeper", "art", "base")
REVIEW = os.path.join(ROOT, "art", "keeper-v2", "review")

# Source (32x32) -> cel (64x64). Soles (source row 30) land on cel row 43,
# the hero's centre line (source x=16.0) lands on cel x=32.0 so that a
# whole-cel flip_x mirrors right-facing art into left-facing art exactly.
CEL_OFFSET = (16, 13)
DIRS = {"down": "south", "up": "north", "side": "east"}


def load(name):
    return Image.open(os.path.join(SRC, name)).convert("RGBA")


def unify_palette(images):
    """Snap the pro-model south view onto the V3 rotations' palette."""
    pal = set()
    for key in ("east", "north"):
        for p in images[key].getdata():
            if p[3] > 0:
                pal.add(p[:3])
    pal = sorted(pal)
    out = {}
    for key, im in images.items():
        q = Image.new("RGBA", im.size)
        for y in range(im.height):
            for x in range(im.width):
                p = im.getpixel((x, y))
                if p[3] > 127:
                    q.putpixel((x, y), nearest(p, pal) + (255,))
        out[key] = q
    return out, pal


# ---------------------------------------------------------------- labels
# Region rules per view, derived from the class grids of the base art.
def label_of(view, x, y):
    if view == "south":
        if y <= 15:
            return "head"
        if y >= 26:
            return "legs"
        if 16 <= y <= 23 and (x <= 10 or x >= 20):
            return "arm_l" if x <= 10 else "arm_r"
        return "torso"
    if view == "north":
        if y <= 14:
            return "head"
        if y >= 26:
            return "legs"
        if 15 <= y <= 23 and (x <= 11 or x >= 21):
            return "arm_l" if x <= 11 else "arm_r"
        return "torso"
    if view == "east":
        if y <= 15:
            return "head"
        if y >= 26:
            return "legs"
        if 17 <= y <= 23 and 11 <= x <= 15:
            return "arm_near"
        return "torso"
    raise ValueError(view)


def classify(label, c, y):
    """Material for one opaque pixel of a base part."""
    h, l, s = hls(c)
    if l < 0.14:
        return "outline"
    if label == "head":
        if 70 <= h <= 170:
            return "eye"
        if l > 0.86 and s > 0.5 and h > 48:
            return "eye"  # eye whites / catchlights
        return "hair" if h >= 39.5 else "skin"
    if label == "torso":
        if 70 <= h <= 170:
            return "cloth"
        if l > 0.62 and h >= 39.5:
            return "trim"
        if l > 0.55 and h < 39.5:
            return "skin"
        if h >= 355 or h < 20:
            return "leather"
        return "leather" if l < 0.32 else "skin"
    if label.startswith("arm"):
        return "skin" if l > 0.25 else "outline"
    if label == "legs":
        return "trousers"
    return "trim"


def material_mask(img, label, top=0):
    mask = Image.new("RGBA", img.size, (0, 0, 0, 0))
    mats = {}
    for y in range(img.height):
        for x in range(img.width):
            p = img.getpixel((x, y))
            if p[3] == 0:
                continue
            m = classify(label, p, y + top)
            mats.setdefault(m, set()).add(p[:3])
            mask.putpixel((x, y), (MATERIALS[m], 0, 0, 255))
    # Shade index = rank of the colour inside its material ramp (0 = darkest).
    ranks = {m: sorted(cols, key=lum) for m, cols in mats.items()}
    for y in range(img.height):
        for x in range(img.width):
            mp = mask.getpixel((x, y))
            if mp[3] == 0:
                continue
            m = [k for k, v in MATERIALS.items() if v == mp[0]][0]
            shade = ranks[m].index(img.getpixel((x, y))[:3])
            mask.putpixel((x, y), (mp[0], shade, len(ranks[m]), 255))
    return mask, ranks


def crop(img, pixels):
    """New image holding only `pixels` (set of (x,y)); returns (img, origin)."""
    xs = [p[0] for p in pixels]
    ys = [p[1] for p in pixels]
    x0, y0, x1, y1 = min(xs), min(ys), max(xs), max(ys)
    out = Image.new("RGBA", (x1 - x0 + 1, y1 - y0 + 1))
    for (x, y) in pixels:
        out.putpixel((x - x0, y - y0), img.getpixel((x, y)))
    return out, (x0, y0)


def fill_side_torso(img, origin, back_x=12, rows=(17, 23)):
    """The near arm hid the back half of the side torso; rebuild it.

    Each hidden row is extended backwards from its first visible fabric pixel
    to the torso's back edge (source x=`back_x`), which gets an outline pixel.
    """
    out = img.copy()
    ox, oy = origin
    outline = None
    for p in img.getdata():
        if p[3] and lum(p) < 36:
            outline = p
            break
    for sy in range(rows[0], rows[1] + 1):
        y = sy - oy
        if y < 0 or y >= img.height:
            continue
        first = None
        for x in range(img.width):
            p = img.getpixel((x, y))
            if p[3] and lum(p) >= 36:
                first = (x, p)
                break
        if first is None:
            continue
        x0, colour = first
        for x in range(back_x - ox + 1, x0):
            out.putpixel((x, y), colour)
        out.putpixel((back_x - ox, y), outline)
    return out


def main():
    raw = {v: load(f"base_{v}.png") for v in ("south", "east", "north")}
    imgs, pal = unify_palette(raw)
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(REVIEW, exist_ok=True)
    rig = {"cel_offset": list(CEL_OFFSET), "views": {}}
    ramps_all = {}
    review = Image.new("RGBA", (32 * 3 * 2 + 16, 32 + 8), (40, 52, 40, 255))
    colors = {"head": (220, 90, 90), "torso": (90, 200, 90), "arm_l": (90, 90, 230),
              "arm_r": (230, 200, 60), "arm_near": (90, 90, 230), "legs": (200, 90, 220)}
    for i, (dname, view) in enumerate(DIRS.items()):
        im = imgs[view]
        regions = {}
        for y in range(32):
            for x in range(32):
                if im.getpixel((x, y))[3] > 0:
                    regions.setdefault(label_of(view, x, y), set()).add((x, y))
        # review overlay: source | labels
        ox = i * 72 + 4
        review.alpha_composite(im, (ox, 4))
        lab = Image.new("RGBA", (32, 32))
        for name, pts in regions.items():
            for (x, y) in pts:
                c = im.getpixel((x, y))
                k = colors[name]
                lab.putpixel((x, y), tuple(int(c[j] * 0.35 + k[j] * 0.65) for j in range(3)) + (255,))
        review.alpha_composite(lab, (ox + 34, 4))

        vinfo = {}
        for part in ("head", "torso"):
            pts = regions[part]
            img, origin = crop(im, pts)
            if view == "east" and part == "torso":
                img = fill_side_torso(img, origin)
            mask, ramps = material_mask(img, part, origin[1])
            img.save(os.path.join(OUT, f"{part}_{dname}.png"))
            mask.save(os.path.join(OUT, f"{part}_{dname}.mat.png"))
            vinfo[part] = {"origin": [origin[0] + CEL_OFFSET[0], origin[1] + CEL_OFFSET[1]],
                           "size": [img.width, img.height]}
            for m, cols in ramps.items():
                ramps_all.setdefault(m, set()).update(cols)
        # arm + leg colours feed the procedural limb ramps
        for part in [k for k in regions if k.startswith("arm") or k == "legs"]:
            for (x, y) in regions[part]:
                c = im.getpixel((x, y))
                m = classify(part, c, y)
                ramps_all.setdefault(("limb_" + part if m != "outline" else "outline"), set()).add(c[:3])
        rig["views"][dname] = vinfo
        print(dname, {k: len(v) for k, v in regions.items()})
    rig["ramps_sampled"] = {k: [hexc(c) for c in sorted(v, key=lum)] for k, v in ramps_all.items()}
    with open(os.path.join(OUT, "extract_base.json"), "w") as f:
        json.dump(rig, f, indent=1)
    review.resize((review.width * 6, review.height * 6), Image.NEAREST).save(os.path.join(REVIEW, "base-labels.png"))
    print(json.dumps(rig["ramps_sampled"], indent=0)[:3000])


if __name__ == "__main__":
    main()
