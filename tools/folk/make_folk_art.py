"""Props where the folk are found in the wilds.

    python tools/folk/make_folk_art.py

Writes game/Forest/folk/art/:
  folk_hut.png         a thatched round hut on stilts (craftpix rocky tileset,
                       House.png, cropped): someone's own little house
  folk_camp.png        a cold camp: a ring of fire stones round a charred log,
                       a rolled bedroll and a split crate (drawn here)
  folk_cage.png        an old tribe's beast-trap: lashed posts, bone spikes and
                       a hide canopy (drawn here), and folk_cage_open.png with
                       its front posts broken away
All in the master palette; drawn pixel by pixel.
"""
import os
import zipfile
from io import BytesIO

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "game", "Forest", "folk", "art")
ROCKY = os.path.join(ROOT, "assets_raw", "craftpix-net-235765-rocky-top-down-tileset-pixel-art-for-rpg.zip")


def c(hexv, a=255):
    return (int(hexv[0:2], 16), int(hexv[2:4], 16), int(hexv[4:6], 16), a)


INK = c("1A1726")
W0, W1, W2, W3, W4 = c("2E241F"), c("3A2A1E"), c("6E5A3E"), c("9C8348"), c("C7A85C")
H0, H1, H2 = c("6B4A4A"), c("A86A52"), c("D49464")
B0, B1 = c("D9C39A"), c("F7EFC8")
S0, S1, S2 = c("2E3640"), c("4A5560"), c("74808C")
ASH, EMBER = c("3B2B33"), c("8C2222")
CLOTH0, CLOTH1 = c("2A4A66"), c("2F6E8C")


def canvas(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def put(img, x, y, col):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), col)


def rect(img, x0, y0, x1, y1, col):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(img, x, y, col)


def hut():
    with zipfile.ZipFile(ROCKY) as z:
        img = Image.open(BytesIO(z.read("PNG/Objects_separately/House.png"))).convert("RGBA")
    return img.crop(img.getbbox())


def camp():
    """The stranded traveller's camp: a hide lean-to over a bedroll, a ring of
    stones and a dropped pack, drawn front-on by PixelLab (map object
    6bceaf32-8a4f-490b-85b1-9099a4cb691f, kept in art/folk/source/sites/)."""
    img = Image.open(os.path.join(ROOT, "art", "folk", "source", "sites", "camp2.png")).convert("RGBA")
    return img.crop(img.getbbox())


def cage(opened):
    img = canvas(28, 34)
    # Hide canopy on top.
    for y in range(0, 7):
        inset = max(0, 3 - y)
        rect(img, inset, y, 27 - inset, y, H1 if y % 2 else H0)
    rect(img, 1, 6, 26, 7, H0)
    for x in range(0, 28, 4):
        put(img, x, 7, B0)
    # Back rail and floor frame.
    rect(img, 1, 30, 26, 32, W1)
    rect(img, 1, 30, 26, 30, W2)
    rect(img, 1, 33, 26, 33, INK)
    posts = [1, 7, 13, 19, 25]
    front_broken = {7, 13, 19} if opened else set()
    for x in posts:
        if x in front_broken:
            # A snapped stub and the broken piece lying at the foot.
            rect(img, x, 24, x + 1, 30, W2)
            put(img, x, 24, B0)
            continue
        rect(img, x, 7, x + 1, 30, W2)
        rect(img, x, 7, x, 30, W3)
        put(img, x, 8, B1)
        # Bone spike on top of every post.
        put(img, x, 5, B1)
        put(img, x + 1, 4, B0)
    for y in (12, 22):
        for x in range(1, 27):
            if opened and 8 < x < 19 and y == 22:
                continue
            put(img, x, y, W1)
            if x % 3 == 0:
                put(img, x, y - 1, H2)
    if opened:
        # Broken posts on the ground in front.
        for (x0, y0, x1) in [(6, 31, 13), (15, 32, 22)]:
            for x in range(x0, x1 + 1):
                put(img, x, y0, W2)
                put(img, x, y0 + 1, W1)
    for y in range(7, 31):
        put(img, 0, y, INK)
        put(img, 27, y, INK)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    hut().save(os.path.join(OUT, "folk_hut.png"))
    camp().save(os.path.join(OUT, "folk_camp.png"))
    cage(False).save(os.path.join(OUT, "folk_cage.png"))
    cage(True).save(os.path.join(OUT, "folk_cage_open.png"))
    for n in sorted(os.listdir(OUT)):
        if n.endswith(".png"):
            print(n, Image.open(os.path.join(OUT, n)).size)


if __name__ == "__main__":
    main()
