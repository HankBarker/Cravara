"""Pass 15: each land's building stuff, drawn from the timber and stone the
keeper already builds with.

    python tools/world/make_material_art.py [--preview OUT.png]

Hank: "different woods from different biomes, bog wood, pale wood, and then
building materials like sandstone and crystal bases". Each material recolours
the timber palisade and plank floor (the woods) or the cut-stone wall and
flagstones (the stones) by brightness onto a ramp of its own, and the moss on
them into its own accent:

  bogwood    Mirewood, black-brown and wet, the moss kept
  palewood   Palewood from the Pale Lands, ash-grey, lichen for moss
  sandstone  warm dune sandstone, dry ochre where the moss was
  crystal    dark slate laid with Sky-Fang crystal in its seams

Writes game/Forest/art/v7/<material>_{wall,floor}.png (ForestProp.ART), the
pieces' icons game/Forest/art/items/<material>_{wall,floor}.png and the
materials' own icons (bogwood, palewood, sandstone) in game/Forest/art/items/.
"""
import colorsys
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ART = os.path.join(ROOT, "game", "Forest", "art")
OUT = os.path.join(ART, "v7")
ITEMS = os.path.join(ART, "items")

# ramp (dark -> light) for the body, ramp for the moss, and the seams' crystal (or None).
MATERIALS = {
    "bogwood": (["17150e", "262216", "38321f", "4c442a", "625838", "7a7048", "948a5c"], None, None),
    "palewood": (["2e2a26", "47423b", "625c52", "7e776b", "9a9384", "b6ae9e", "d0c9b8"], ["5f6858", "7c8672", "9aa38e"], None),
    "sandstone": (["3e2a1c", "5e412a", "815a38", "a47648", "c3955e", "dcb57a", "f0d49a"], ["8c6c34", "a8864a", "c4a466"], None),
    "crystal": (["121822", "1d2633", "2a3646", "3b4a5d", "4f6177", "677b92", "8497ad"], ["2f6e8c", "4fa3b8", "8fd4d6"], ["1d4a61", "2f6e8c", "4fa3b8", "8fd4d6", "c8f0f0"]),
}
WOODS = ("bogwood", "palewood")
# material: (wall source, floor source, wall icon, floor icon)
SOURCES = {
    "wood": ("v2/wood_wall.png", "v2/wood_floor.png", "v2/item-wood_wall.png", "v2/item-wood_floor.png"),
    "stone": ("v6/stone_wall.png", "v6/stone_floor.png", "items/stone_wall.png", "items/stone_floor.png"),
}
RAW = {"bogwood": "v2/item-log.png", "palewood": "v2/item-log.png", "sandstone": "v2/item-stone.png"}


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def lum(c):
    return 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]


def is_moss(c):
    h, s, v = colorsys.rgb_to_hsv(c[0] / 255, c[1] / 255, c[2] / 255)
    return 0.16 <= h <= 0.48 and s > 0.22 and v > 0.18


def recolour(im, material, seams=False):
    body, moss, crystal = MATERIALS[material]
    px = im.load()
    colours = {px[x, y][:3] for y in range(im.height) for x in range(im.width) if px[x, y][3]}
    base = sorted((c for c in colours if not is_moss(c)), key=lum)
    greens = sorted((c for c in colours if is_moss(c)), key=lum)
    lo, hi = (lum(base[0]), lum(base[-1])) if base else (0, 255)
    table = {}
    for c in base:
        t = (lum(c) - lo) / max(1.0, hi - lo)
        table[c] = hexc(body[min(len(body) - 1, int(round(t * (len(body) - 1))))])
    for i, c in enumerate(greens):
        if moss is None:
            table[c] = c
        else:
            t = i / max(1, len(greens) - 1)
            table[c] = hexc(moss[min(len(moss) - 1, int(round(t * (len(moss) - 1))))])
    # Crystal: the darkest seams (mortar between the stones) are crystal veins.
    if crystal and seams and len(base) > 2:
        table[base[0]] = hexc(crystal[1])
        table[base[1]] = hexc(crystal[0])
    out = im.copy()
    op = out.load()
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            if c[3]:
                op[x, y] = table[c[:3]] + (c[3],)
    # A few glints in a crystal floor and wall.
    if crystal and seams:
        glint = hexc(crystal[4])
        for y in range(im.height):
            for x in range(im.width):
                if op[x, y][3] and op[x, y][:3] == hexc(crystal[1]) and (x * 7 + y * 13) % 11 == 0:
                    op[x, y] = glint + (op[x, y][3],)
    return out


def make(material):
    kind = "wood" if material in WOODS else "stone"
    wall, floor, wall_icon, floor_icon = SOURCES[kind]
    out = {}
    for part, src, seams in (("wall", wall, True), ("floor", floor, True)):
        out["%s_%s" % (material, part)] = recolour(Image.open(os.path.join(ART, src)).convert("RGBA"), material, seams)
    icons = {}
    for part, src in (("wall", wall_icon), ("floor", floor_icon)):
        icons["%s_%s" % (material, part)] = recolour(Image.open(os.path.join(ART, src)).convert("RGBA"), material, True)
    if material in RAW:
        icons[material] = recolour(Image.open(os.path.join(ART, RAW[material])).convert("RGBA"), material, False)
    return out, icons


def main():
    os.makedirs(OUT, exist_ok=True)
    tiles, all_icons = [], []
    for material in MATERIALS:
        art, icons = make(material)
        for name, im in art.items():
            tiles.append(im)
            if "--preview" not in sys.argv:
                im.save(os.path.join(OUT, name + ".png"))
        for name, im in icons.items():
            all_icons.append(im)
            if "--preview" not in sys.argv:
                im.save(os.path.join(ITEMS, name + ".png"))
        print("made", material, list(art), list(icons))
    if "--preview" in sys.argv:
        dest = sys.argv[sys.argv.index("--preview") + 1]
        row = tiles + all_icons
        sheet = Image.new("RGBA", (sum(i.width + 4 for i in row), max(i.height for i in row)), (70, 100, 60, 255))
        x = 0
        for i in row:
            sheet.alpha_composite(i, (x, 0))
            x += i.width + 4
        sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(dest)
        print("preview", dest)


if __name__ == "__main__":
    main()
