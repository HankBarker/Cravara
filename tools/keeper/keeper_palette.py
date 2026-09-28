"""Shared colour helpers for the Keeper v2 part pipeline.

Parts are stored as ordinary RGBA PNGs plus a companion *material mask*
(`<name>.mat.png`): R = material id, G = shade index (0 = darkest).
The runtime recolours appearance materials (skin, hair, cloth, trousers)
by swapping ramps, so the default look is the untouched source art.
"""
import colorsys

# Material ids shared with game/Forest/keeper/KeeperParts.gd (keep in sync).
MATERIALS = {
    "none": 0,
    "outline": 1,
    "skin": 2,
    "hair": 3,
    "eye": 4,
    "cloth": 5,      # dyeable tunic fabric
    "trim": 6,       # ivory stitching / light accents (never dyed)
    "leather": 7,    # belts, straps, boots (never dyed)
    "trousers": 8,   # dyeable trousers
    "armor": 9,      # armour pieces: fixed colours
    "glow": 10,      # emissive armour accents
}
MATERIAL_NAMES = {v: k for k, v in MATERIALS.items()}
DYEABLE = ("skin", "hair", "cloth", "trousers")


def hls(c):
    r, g, b = c[:3]
    h, l, s = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
    return h * 360.0, l, s


def lum(c):
    r, g, b = c[:3]
    return 0.299 * r + 0.587 * g + 0.114 * b


def dist2(a, b):
    # Weighted RGB distance; good enough to snap AI noise onto a palette.
    dr, dg, db = a[0] - b[0], a[1] - b[1], a[2] - b[2]
    rm = (a[0] + b[0]) / 2.0
    return (2 + rm / 256) * dr * dr + 4 * dg * dg + (2 + (255 - rm) / 256) * db * db


def nearest(c, palette):
    best, bd = None, 1e18
    for q in palette:
        d = dist2(c, q)
        if d < bd:
            bd, best = d, q
    return best


def hexc(c):
    return "%02x%02x%02x" % tuple(c[:3])


def parse_hex(h):
    h = h.strip().lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))
