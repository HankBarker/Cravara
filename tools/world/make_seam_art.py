"""Pass 15: ore seams in the far lands' stone.

    python tools/world/make_seam_art.py [--preview OUT.png]

Each far land's ore used to lie only in loose veins on open ground. Hank:
"it makes more sense to just have them be a part of that stone thing". A seam
is a block of the land's own outcrop stone (the 16x28 ore blocks Sky-Fang
crystal already runs through: sandstone for the Bonelands and the dunes, chalk
for the Pale Lands) with the crystal recoloured into the land's ore:

  seam_rustiron  Bonelands sandstone, rust-red iron nodules
  seam_sunstone  dune sandstone, amber sunstone glinting through
  seam_ashglass  Pale Lands chalk, black glass shards with an ember in them

The crystal's shades (dark, mid, light, highlight) map by brightness onto the
ore's ramp, so the seam keeps the block's lighting. Writes
game/Forest/art/pass11/seam_*.png (ForestProp.wild_art loads from there).
"""
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "game", "Forest", "art", "bonelands")
OUT = os.path.join(ROOT, "game", "Forest", "art", "pass11")

# The crystal's own colours in the ore blocks, darkest first.
CRYSTAL = ["1d4a61", "2f6e8c", "4fa3b8", "8fd4d6", "c8f0f0"]
SEAMS = {
    "seam_rustiron": ("sand_ore.png", ["3a1210", "7a2418", "b0402a", "e0703a", "ffa060"]),
    "seam_sunstone": ("sand_ore.png", ["6a3a12", "a8661e", "e0a33a", "f6cf6a", "fff0b8"]),
    "seam_ashglass": ("chalk_ore.png", ["0c0a0d", "1c1521", "3a3440", "ea6a2a", "ffb070"]),
}


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def near(c, h, tol=18):
    r, g, b = hexc(h)
    return abs(c[0] - r) + abs(c[1] - g) + abs(c[2] - b) <= tol


def crystal_rank(c):
    """Which crystal shade a pixel is (None: not crystal). Unknown cyan-ish
    shades go by brightness."""
    for i, h in enumerate(CRYSTAL):
        if near(c, h):
            return i
    r, g, b = c[:3]
    if b > r + 25 and g > r + 10:
        v = max(r, g, b)
        return min(4, int(v / 256 * 5))
    return None


def make(name):
    src_name, ramp = SEAMS[name]
    im = Image.open(os.path.join(SRC, src_name)).convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            c = px[x, y]
            if not c[3]:
                continue
            rank = crystal_rank(c)
            if rank is not None:
                px[x, y] = hexc(ramp[rank]) + (c[3],)
    return im


def main():
    ims = []
    for name in SEAMS:
        im = make(name)
        ims.append(im)
        if "--preview" not in sys.argv:
            im.save(os.path.join(OUT, name + ".png"))
            print("wrote", name)
    if "--preview" in sys.argv:
        dest = sys.argv[sys.argv.index("--preview") + 1]
        sheet = Image.new("RGBA", (sum(i.width + 6 for i in ims), max(i.height for i in ims)), (90, 140, 70, 255))
        x = 0
        for i in ims:
            sheet.alpha_composite(i, (x, 0))
            x += i.width + 6
        sheet.resize((sheet.width * 8, sheet.height * 8), Image.NEAREST).save(dest)
        print("preview", dest)


if __name__ == "__main__":
    main()
