"""Prepare the dinosaur base drawings for animation.

    python tools/dino/prepare.py

For every species (and the saddled stego/trike) and facing (side/down/up):
  * builds one ~64-colour palette per species from all its drawings
    (art/dino-v2/palettes/<species>.hex) - the originals carry thousands of
    near-identical shades, so every clip snaps to this shared palette instead;
  * writes the palette-snapped drawing to art/dino-v2/base/<key>_<view>.png;
  * writes the animation start frame to art/dino-v2/first/<key>_<view>.png:
    the drawing centred on the species canvas (CANVAS) with its feet on the
    ground row (canvas height - GROUND).

Keys: dodo, longneck, raptor, rex, stego, trike, stego_saddle, trike_saddle.
"""
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ART = os.path.join(ROOT, "game", "Forest", "creatures", "art")
MOUNT = os.path.join(ROOT, "game", "Forest", "creatures", "mount_art")
OUT = os.path.join(ROOT, "art", "dino-v2")

# Original frame size per species (first cel of each 17-frame strip).
FRAME = {"dodo": (20, 24), "longneck": (70, 60), "raptor": (42, 32), "rex": (76, 56),
         "stego": (60, 40), "trike": (54, 42), "alpha": (84, 60),
         "allo": (64, 46), "lystro": (24, 20), "parasaur": (76, 52), "ossuar": (84, 64),
         # Pass 12 (drawn by PixelLab create_character v3, tools/dino/pick12.py).
         "dimetrodon": (60, 56), "carno": (68, 66), "yuty": (68, 68), "anky": (56, 52), "proto": (32, 30), "compy": (24, 20),
         # Pass 13 (PixelLab v3, tools/dino/pick13.py; the carno redrawn so).
         "utah": (52, 54), "deino": (42, 44), "sucho": (72, 64), "spino": (108, 90)}
# Animation canvas: room for tail sweeps, rearing, lunges and leaps.
CANVAS = {"dodo": (48, 48), "longneck": (128, 112), "raptor": (96, 72), "rex": (128, 96),
          "stego": (112, 80), "trike": (96, 72), "alpha": (128, 96),
          "allo": (112, 84), "lystro": (48, 48), "parasaur": (112, 88), "ossuar": (136, 104),
          "dimetrodon": (112, 96), "carno": (128, 112), "yuty": (128, 112), "anky": (112, 88), "proto": (64, 56), "compy": (48, 40),
          "utah": (112, 96), "deino": (96, 80), "sucho": (136, 112), "spino": (184, 144)}
GROUND = 6  # feet sit this many rows above the canvas bottom
VIEWS = ("side", "down", "up")
# Babies (pass 11, tools/dino/babies.py): their own frame and canvas, their
# parent's palette, and only the facings drawn (most are side-on only).
BABY_FRAME = {"dodo_baby": (18, 18), "lystro_baby": (22, 16), "stego_baby": (36, 26), "trike_baby": (32, 26),
              "longneck_baby": (38, 34), "raptor_baby": (28, 26), "allo_baby": (36, 28), "parasaur_baby": (40, 30)}
BABY_CANVAS = {"dodo_baby": (40, 36), "lystro_baby": (40, 36), "stego_baby": (64, 52), "trike_baby": (56, 48),
               "longneck_baby": (64, 60), "raptor_baby": (56, 44), "allo_baby": (64, 52), "parasaur_baby": (64, 52)}
FRAME.update(BABY_FRAME)
CANVAS.update(BABY_CANVAS)


def frame_key(key):
    """The FRAME/CANVAS entry for a key: a baby's own, else its species'."""
    return key if key in FRAME else species_of(key)


def species_of(key):
    return key.split("_")[0]


def source(key, view):
    sp = species_of(key)
    w, h = FRAME[frame_key(key)]
    if key in BABY_FRAME:
        path = os.path.join(ART, key + ("" if view == "side" else "_" + view) + ".png")
        return Image.open(path).convert("RGBA").crop((0, 0, w, h))
    if key.endswith("_saddle"):
        path = os.path.join(MOUNT, "%s_%s.png" % (sp, view))
    else:
        path = os.path.join(ART, sp + ("" if view == "side" else "_" + view) + ".png")
    return Image.open(path).convert("RGBA").crop((0, 0, w, h))


def has_view(key, view):
    if key in BABY_FRAME or key.endswith("_saddle"):
        return True
    return os.path.exists(os.path.join(ART, species_of(key) + ("" if view == "side" else "_" + view) + ".png"))


def weighted(c, p):
    r = (c[0] + p[0]) / 2
    dr, dg, db = c[0] - p[0], c[1] - p[1], c[2] - p[2]
    return (2 + r / 256) * dr * dr + 4 * dg * dg + (2 + (255 - r) / 256) * db * db


def snap(img, pal):
    cache = {}
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    for y in range(img.height):
        for x in range(img.width):
            c = img.getpixel((x, y))
            if c[3] < 128:
                continue
            k = c[:3]
            if k not in cache:
                cache[k] = min(pal, key=lambda p: weighted(k, p))
            out.putpixel((x, y), cache[k] + (255,))
    return out


def build_palette(images, colours=64):
    px = []
    for im in images:
        px += [c[:3] for c in im.getdata() if c[3] >= 128]
    strip = Image.new("RGB", (len(px), 1))
    strip.putdata(px)
    q = strip.quantize(colors=colours, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    return sorted(set(q.convert("RGB").getdata()))


def keys():
    return ["dodo", "longneck", "raptor", "rex", "stego", "trike", "stego_saddle", "trike_saddle", "alpha", "allo", "lystro", "parasaur", "ossuar",
            "dimetrodon", "carno", "yuty", "anky", "proto", "compy", "utah", "deino", "sucho", "spino"]


def baby_views(key):
    return [v for v in VIEWS if os.path.exists(os.path.join(ART, key + ("" if v == "side" else "_" + v) + ".png"))]


def prepare_baby(key):
    """A baby's drawings, snapped to its parent's palette (never rebuilt)."""
    sp = species_of(key)
    pal = [tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) for h in open(os.path.join(OUT, "palettes", sp + ".hex")).read().split()]
    cw, ch = CANVAS[key]
    views = baby_views(key)
    for v in views:
        img = source(key, v)
        snapped = snap(img, pal)
        snapped.save(os.path.join(OUT, "base", "%s_%s.png" % (key, v)))
        box = snapped.getbbox()
        canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        canvas.alpha_composite(snapped, ((cw - img.width) // 2, ch - GROUND - box[3]))
        canvas.save(os.path.join(OUT, "first", "%s_%s.png" % (key, v)))
    print(key, "on the", sp, "palette;", len(views), "drawings:", ", ".join(views))


def main():
    for d in ("palettes", "base", "first"):
        os.makedirs(os.path.join(OUT, d), exist_ok=True)
    # `python prepare.py alpha` redoes one species (the rest are left alone);
    # `python prepare.py stego_baby` one baby.
    only = set(sys.argv[1:])
    for key in BABY_FRAME:
        if key in only:
            prepare_baby(key)
    for sp in FRAME:
        if sp in BABY_FRAME:
            continue
        if only and sp not in only:
            continue
        # A species drawn in fewer facings (pass 12: the side-on compy) skips the rest.
        drawings = {(k, v): source(k, v) for k in keys() if species_of(k) == sp for v in VIEWS if has_view(k, v)}
        pal = build_palette(list(drawings.values()), 72 if sp in ("stego", "trike") else 64)
        with open(os.path.join(OUT, "palettes", sp + ".hex"), "w") as f:
            f.write("\n".join("%02x%02x%02x" % c for c in pal))
        cw, ch = CANVAS[sp]
        for (k, v), img in drawings.items():
            snapped = snap(img, pal)
            snapped.save(os.path.join(OUT, "base", "%s_%s.png" % (k, v)))
            box = snapped.getbbox()
            canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
            x = (cw - img.width) // 2
            y = ch - GROUND - box[3]  # lowest opaque row onto the ground row
            canvas.alpha_composite(snapped, (x, y))
            canvas.save(os.path.join(OUT, "first", "%s_%s.png" % (k, v)))
        print(sp, "palette", len(pal), "colours;", len(drawings), "drawings")


if __name__ == "__main__":
    sys.exit(main())
