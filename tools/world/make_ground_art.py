"""Build the ground detail atlases from the craftpix detail sheets.

    python tools/world/make_ground_art.py

Sources (assets_raw, the same craftpix artist family as the forest's trees and
props, used under the craftpix.net file licence):
  grassland  craftpix-net-918283 .../PNG/Details.png
  rocky      craftpix-net-235765 .../PNG/details.png

Writes game/Forest/ground/art/:
  stamps.png + stamps.json   small static marks baked into the ground by
                             ground.gdshader: one 16x16 cell per stamp, grouped
                             by kind. "tint" kinds are recoloured by the shader
                             from their brightness onto whatever ground tone
                             they land on; the others keep their own colours.
  flora.png + flora.json     swaying plants for ForestFlora (MultiMesh): one
                             32x32 cell per plant, bottom-centred. The pack's
                             frosty tufts are recoloured into lush greens.
"""
import json
import os
import sys
import zipfile
from io import BytesIO

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
RAW = os.path.join(ROOT, "assets_raw")
OUT = os.path.join(ROOT, "game", "Forest", "ground", "art")

SHEETS = {
    "grassland": ("craftpix-net-918283-grassland-top-down-tileset-pixel-art.zip", "PNG/Details.png"),
    "rocky": ("craftpix-net-235765-rocky-top-down-tileset-pixel-art-for-rpg.zip", "PNG/details.png"),
}

# Boxes (x0, y0, x1, y1) on the sheets, found with tools/world/sheet_pieces.py.
STAMPS = {
    # Tinted onto the grass tone underneath.
    "blades": {"tint": True, "boxes": [("grassland", b) for b in [
        (2, 212, 14, 220), (20, 212, 29, 219), (36, 214, 44, 218), (50, 210, 63, 221),
        (68, 212, 75, 218), (82, 213, 93, 220), (179, 197, 189, 205)]]},
    "clover": {"tint": True, "boxes": [("rocky", b) for b in [
        (105, 394, 117, 405), (136, 392, 151, 406), (98, 426, 110, 437), (113, 419, 125, 430),
        (172, 396, 179, 403), (181, 428, 188, 435), (204, 420, 211, 427)]]},
    # Keep their own colours.
    "flowers": {"tint": False, "boxes": [("grassland", b) for b in [
        (2, 161, 14, 174), (117, 164, 124, 172), (130, 162, 141, 174), (147, 163, 157, 172),
        (162, 166, 173, 174), (176, 163, 192, 174), (162, 131, 175, 142), (178, 147, 190, 158)]]
        + [("rocky", b) for b in [(44, 315, 51, 324), (76, 316, 85, 324), (107, 314, 116, 323),
                                  (171, 314, 180, 323), (203, 316, 212, 324), (36, 364, 45, 372)]]},
    "specks": {"tint": True, "boxes": [("grassland", b) for b in [
        (96, 177, 106, 185), (115, 179, 127, 188), (129, 177, 144, 191), (163, 176, 176, 192),
        (178, 179, 191, 189), (44, 192, 52, 198), (164, 196, 173, 204), (13, 190, 23, 197)]]},
    "pebbles": {"tint": False, "boxes": [("rocky", b) for b in [
        (91, 491, 115, 503), (136, 490, 155, 504), (197, 491, 218, 501), (39, 523, 57, 532),
        (71, 516, 89, 525), (168, 523, 183, 532), (200, 512, 215, 521), (34, 504, 38, 508),
        (117, 497, 121, 501)]] + [("grassland", b) for b in [(118, 67, 131, 76), (125, 82, 138, 92)]]},
    "twigs": {"tint": False, "boxes": [("rocky", b) for b in [
        (42, 392, 54, 403), (75, 394, 85, 404), (2, 426, 14, 437), (26, 418, 38, 429),
        (52, 427, 62, 437), (75, 419, 85, 429), (35, 435, 45, 445)]]},
}
FLORA = {
    # The rocky pack's frosty tufts, recoloured into grass.
    "tufts": {"green": True, "boxes": [("rocky", b) for b in [
        (4, 115, 27, 136), (32, 115, 55, 136), (134, 117, 157, 138), (0, 149, 22, 168),
        (64, 144, 86, 163), (166, 151, 185, 166), (230, 145, 249, 160), (80, 165, 91, 176),
        (232, 168, 248, 181), (265, 168, 280, 183), (43, 185, 54, 196), (74, 179, 85, 190),
        (99, 178, 110, 189), (176, 177, 192, 190), (179, 192, 190, 203)]]},
    "blossoms": {"green": False, "boxes": [("rocky", b) for b in [
        (201, 197, 229, 222), (255, 198, 275, 218), (163, 212, 191, 237), (200, 230, 220, 250),
        (224, 224, 244, 244), (268, 236, 288, 256)]]},
    "sprigs": {"green": False, "boxes": [("rocky", b) for b in [
        (168, 243, 185, 256), (160, 259, 177, 272), (203, 258, 212, 269), (170, 281, 179, 292),
        (192, 272, 201, 283), (199, 293, 208, 304)]]},
    "clumps": {"green": False, "boxes": [("rocky", b) for b in [
        (230, 266, 250, 281), (256, 264, 276, 279), (8, 313, 22, 326), (257, 306, 271, 319),
        (9, 337, 23, 350), (137, 353, 151, 366)]]},
}
STAMP_CELL = 16
FLORA_CELL = 32
# Grass ramp (dark -> light) for the recoloured tufts.
GREEN = [(40, 74, 42), (58, 104, 50), (84, 140, 62), (116, 172, 76), (160, 206, 104)]


def load_sheets():
    sheets = {}
    for name, (zname, member) in SHEETS.items():
        with zipfile.ZipFile(os.path.join(RAW, zname)) as z:
            sheets[name] = Image.open(BytesIO(z.read(member))).convert("RGBA")
    return sheets


def cut(sheet, box):
    img = sheet.crop(box)
    tight = img.getbbox()
    return img.crop(tight) if tight else img


def lum(p):
    return 0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2]


def to_green(img):
    """Map a frosty tuft's shades onto the grass ramp by brightness rank."""
    px = img.load()
    levels = sorted({round(lum(px[x, y])) for y in range(img.height) for x in range(img.width) if px[x, y][3]})
    out = img.copy()
    o = out.load()
    for y in range(img.height):
        for x in range(img.width):
            p = px[x, y]
            if not p[3]:
                continue
            rank = levels.index(round(lum(p))) / max(1, len(levels) - 1)
            o[x, y] = GREEN[min(len(GREEN) - 1, int(rank * len(GREEN)))] + (255,)
    return out


def pack(groups, cell, anchor_bottom):
    """One cell per sprite, in group order; returns (atlas, meta)."""
    entries = []
    meta = {"cell": cell, "kinds": {}}
    for kind, spec in groups.items():
        first = len(entries)
        for img in spec["images"]:
            entries.append(img)
        meta["kinds"][kind] = {"first": first, "count": len(entries) - first}
        for key in ("tint",):
            if key in spec:
                meta["kinds"][kind][key] = spec[key]
    cols = 16
    rows = (len(entries) + cols - 1) // cols
    atlas = Image.new("RGBA", (cols * cell, rows * cell), (0, 0, 0, 0))
    sizes = []
    for i, img in enumerate(entries):
        if img.width > cell or img.height > cell:
            img = img.crop((0, 0, min(cell, img.width), min(cell, img.height)))
        cx, cy = (i % cols) * cell, (i // cols) * cell
        ox = (cell - img.width) // 2
        oy = cell - img.height if anchor_bottom else (cell - img.height) // 2
        atlas.alpha_composite(img, (cx + ox, cy + oy))
        sizes.append([img.width, img.height])
    meta["columns"] = cols
    meta["sizes"] = sizes
    return atlas, meta


def main():
    sheets = load_sheets()
    os.makedirs(OUT, exist_ok=True)
    stamp_groups = {}
    for kind, spec in STAMPS.items():
        stamp_groups[kind] = {"tint": spec["tint"], "images": [cut(sheets[s], b) for s, b in spec["boxes"]]}
    atlas, meta = pack(stamp_groups, STAMP_CELL, False)
    atlas.save(os.path.join(OUT, "stamps.png"))
    json.dump(meta, open(os.path.join(OUT, "stamps.json"), "w"), indent=1)
    flora_groups = {}
    for kind, spec in FLORA.items():
        imgs = [cut(sheets[s], b) for s, b in spec["boxes"]]
        if spec["green"]:
            imgs = [to_green(i) for i in imgs]
        flora_groups[kind] = {"images": imgs}
    atlas, meta = pack(flora_groups, FLORA_CELL, True)
    atlas.save(os.path.join(OUT, "flora.png"))
    json.dump(meta, open(os.path.join(OUT, "flora.json"), "w"), indent=1)
    print("stamps:", {k: len(v["images"]) for k, v in stamp_groups.items()})
    print("flora:", {k: len(v["images"]) for k, v in flora_groups.items()})


if __name__ == "__main__":
    sys.exit(main())
