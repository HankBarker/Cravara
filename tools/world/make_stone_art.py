"""Stone building pieces for the camp, drawn in the master palette.

    python tools/world/make_stone_art.py

Writes game/Forest/art/v6/:
  stone_wall.png       16x28  courses of cut stone in running bond, a capstone
                              row on top and moss at the foot (bottom at +8,
                              like the timber wall)
  stone_door.png       16x28  an iron-banded plank door in a stone frame
  stone_door_open.png  16x28  the frame with the door swung in
  stone_floor.png      16x16  flagstones, the same stone as the ruins' paving
  slate_roof.png       16x16  overlapping purple-grey slates with a ridge
and 16x16 satchel icons game/Forest/art/items/<id>.png for the four items.
Stone matches the first builders' ruins; the timber set (art/v2, v3) keeps
its own look. Every piece is drawn pixel by pixel from a fixed seed.
"""
import os
import random

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
ART = os.path.join(ROOT, "game", "Forest", "art", "v6")
ICONS = os.path.join(ROOT, "game", "Forest", "art", "items")


def c(hexv):
    return (int(hexv[0:2], 16), int(hexv[2:4], 16), int(hexv[4:6], 16), 255)


INK = c("1A1726")
MORTAR = c("2E241F")
MORTAR_L = c("3A2A1E")
S0, S1, S2, S3, S4 = c("2E3640"), c("4A5560"), c("74808C"), c("A7B1BA"), c("DCE2E6")
M0, M1, M2, M3 = c("2A3320"), c("3F5128"), c("5E7A33"), c("86A84A")
W0, W1, W2, W3 = c("3A2A1E"), c("6B4A4A"), c("6E5A3E"), c("A86A52")
IRON0, IRON1 = c("2C2840"), c("6E5C8C")
SL0, SL1, SL2 = c("2C2840"), c("473F66"), c("6E5C8C")
CLEAR = (0, 0, 0, 0)


def canvas(w, h):
    return Image.new("RGBA", (w, h), CLEAR)


def put(img, x, y, col):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), col)


def block(img, x0, y0, x1, y1, rng, face=S1):
    """One cut stone: lit top-left edge, shadowed bottom-right, a few pits."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            col = face
            if y == y0 or x == x0:
                col = S2
            if y == y1 or x == x1:
                col = S0
            if (x, y) == (x0, y0):
                col = S3
            put(img, x, y, col)
    for _ in range(max(2, (x1 - x0 + 1) * (y1 - y0 + 1) // 4)):
        px, py = rng.randint(x0 + 1, max(x0 + 1, x1 - 1)), rng.randint(y0 + 1, max(y0 + 1, y1 - 1))
        roll = rng.random()
        put(img, px, py, S0 if roll < 0.55 else (M1 if roll < 0.68 else S2))


def courses(img, x0, x1, y0, y1, rng, start=0):
    """Running-bond courses of stone between y0 and y1 (4px stones, 1px mortar)."""
    y = y0
    row = start
    while y + 3 <= y1:
        offset = 0 if row % 2 == 0 else 4
        x = x0 - offset
        while x <= x1:
            width = 7 if (row + x) % 3 else 6
            bx0, bx1 = max(x0, x), min(x1, x + width - 1)
            if bx1 - bx0 >= 1:
                block(img, bx0, y, bx1, y + 3, rng)
            for my in range(y, y + 4):
                put(img, x + width, my, MORTAR)
            x += width + 1
        for mx in range(x0, x1 + 1):
            put(img, mx, y + 4, MORTAR_L)
        y += 5
        row += 1


def moss(img, x0, x1, y_base, rng, amount=0.55):
    for x in range(x0, x1 + 1):
        if rng.random() < amount:
            put(img, x, y_base, M1)
            if rng.random() < 0.5:
                put(img, x, y_base - 1, M2)
            if rng.random() < 0.2:
                put(img, x, y_base - 2, M3)


def stone_wall():
    rng = random.Random(61)
    img = canvas(16, 28)
    # Capstones seen from above (rows 0-5), then the face.
    for x in range(16):
        put(img, x, 0, INK)
    for y in range(1, 6):
        for x in range(16):
            put(img, x, y, S2 if y < 3 else S1)
    for x in (5, 11):
        for y in range(1, 6):
            put(img, x, y, MORTAR)
    for x in range(16):
        put(img, x, 1, S3 if x not in (5, 11) else MORTAR)
        put(img, x, 6, S0)
    courses(img, 0, 15, 7, 26, rng)
    moss(img, 0, 15, 26, rng)
    for x in range(16):
        put(img, x, 27, INK)
    for y in range(0, 28):
        put(img, 0, y, INK if img.getpixel((0, y))[3] else CLEAR)
        put(img, 15, y, S0 if y > 0 else INK)
    put(img, 2, 3, M2)
    put(img, 13, 2, M1)
    return img


def frame(img, rng):
    """Stone jambs and a lintel round a doorway (door space x 3-12, y 9-26)."""
    for y in range(0, 28):
        for x in list(range(0, 3)) + list(range(13, 16)):
            put(img, x, y, S1)
    for y in range(0, 9):
        for x in range(16):
            put(img, x, y, S1)
    # Lintel stone and keystone.
    block(img, 0, 1, 15, 7, rng, S1)
    block(img, 6, 0, 9, 7, rng, S2)
    for x in range(16):
        put(img, x, 0, INK)
        put(img, x, 8, MORTAR)
    for y in range(9, 27, 5):
        block(img, 0, y, 2, min(26, y + 3), rng)
        block(img, 13, y, 15, min(26, y + 3), rng)
        put(img, 0, y + 4, MORTAR_L)
        put(img, 15, y + 4, MORTAR_L)
    for y in range(28):
        put(img, 0, y, INK)
        put(img, 15, y, S0)
    for x in range(16):
        put(img, x, 27, INK)
    moss(img, 0, 2, 26, rng, 0.9)
    moss(img, 13, 15, 26, rng, 0.9)


def stone_door(opened):
    rng = random.Random(62)
    img = canvas(16, 28)
    frame(img, rng)
    if opened:
        for y in range(9, 27):
            for x in range(3, 13):
                put(img, x, y, MORTAR if y < 11 else c("2E241F"))
        for y in range(10, 27):
            put(img, 3, y, W1)
            put(img, 4, y, W0)
        for x in range(5, 13):
            put(img, x, 26, W0)
        return img
    for y in range(9, 27):
        for x in range(3, 13):
            col = W1 if x % 3 else W0
            if x in (3, 12):
                col = W0
            put(img, x, y, col)
    for band in (12, 22):
        for x in range(3, 13):
            put(img, x, band, IRON0)
            put(img, x, band - 1, IRON1 if x % 3 == 1 else IRON0)
    for (x, y) in [(10, 17), (10, 18), (9, 17)]:
        put(img, x, y, S3)
    put(img, 10, 16, IRON0)
    return img


def stone_floor():
    rng = random.Random(63)
    img = canvas(16, 16)
    for y in range(16):
        for x in range(16):
            put(img, x, y, MORTAR)
    slabs = [(0, 0, 8, 6), (10, 0, 15, 5), (0, 8, 5, 15), (7, 8, 15, 15), (10, 7, 15, 7)]
    for (x0, y0, x1, y1) in slabs[:4]:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                col = S1 if rng.random() < 0.25 else S2
                if y == y0 or x == x0:
                    col = S2 if rng.random() < 0.5 else S3
                if y == y1 or x == x1:
                    col = S0
                put(img, x, y, col)
        for _ in range(5):
            put(img, rng.randint(x0 + 1, x1 - 1), rng.randint(y0 + 1, y1 - 1), S0 if rng.random() < 0.7 else M1)
    # The gap row between the top-right slab and the bottom slabs.
    for x in range(10, 16):
        put(img, x, 6, MORTAR_L)
        put(img, x, 7, MORTAR)
    for (x, y) in [(9, 3), (6, 7), (6, 14), (15, 6)]:
        put(img, x, y, M1)
    put(img, 9, 4, M2)
    return img


def slate_roof():
    rng = random.Random(64)
    img = canvas(16, 16)
    for y in range(16):
        for x in range(16):
            put(img, x, y, SL1)
    # Overlapping courses of slates, each lit at its lower edge.
    for row, y in enumerate(range(1, 16, 4)):
        offset = 0 if row % 2 == 0 else 2
        for x in range(-offset, 16, 4):
            tone = SL1 if rng.random() < 0.7 else SL0
            for yy in range(y, y + 3):
                for xx in range(x, x + 3):
                    put(img, xx, yy, tone if yy < y + 2 else SL2)
            for yy in range(y, y + 4):
                put(img, x + 3, yy, SL0)
            if rng.random() < 0.3:
                put(img, x + 1, y + 1, SL2)
        for x in range(16):
            put(img, x, y + 3, SL0)
    # Ridge along the top.
    for x in range(16):
        put(img, x, 0, S3 if x % 4 else S2)
    for x in range(16):
        put(img, x, 15, INK)
    return img


def icon_of(art, box):
    """A 16x16 satchel icon from a region of the art (whole pixels, no scaling)."""
    img = canvas(16, 16)
    region = art.crop(box)
    img.alpha_composite(region, ((16 - region.width) // 2, (16 - region.height) // 2))
    return img


def main():
    os.makedirs(ART, exist_ok=True)
    wall = stone_wall()
    door = stone_door(False)
    door_open = stone_door(True)
    floor = stone_floor()
    roof = slate_roof()
    wall.save(os.path.join(ART, "stone_wall.png"))
    door.save(os.path.join(ART, "stone_door.png"))
    door_open.save(os.path.join(ART, "stone_door_open.png"))
    floor.save(os.path.join(ART, "stone_floor.png"))
    roof.save(os.path.join(ART, "slate_roof.png"))
    icon_of(wall, (0, 6, 16, 22)).save(os.path.join(ICONS, "stone_wall.png"))
    icon_of(door, (0, 6, 16, 22)).save(os.path.join(ICONS, "stone_door.png"))
    icon_of(floor, (0, 0, 16, 16)).save(os.path.join(ICONS, "stone_floor.png"))
    icon_of(roof, (0, 0, 16, 16)).save(os.path.join(ICONS, "slate_roof.png"))
    print("stone pieces written")


if __name__ == "__main__":
    main()
