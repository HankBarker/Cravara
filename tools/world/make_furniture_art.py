"""Pass 18: the furniture drawn the way the chest is (Hank: "fix the chairs,
tables, and beds so that they are more so kind of like what the chests look
like when you place them down, almost like a top-down view").

    python tools/world/make_furniture_art.py [--preview PATH]

The pass-17 furniture (PixelLab pixflux, art/v8) came out in a side-on
perspective, so a chair or table stood in the world like a cut-out. These are
drawn by hand, in code, at the chest's angle: steep 3/4 from above, the top
faces large and lit, the front faces short and darker, the chest's own
browns and near-black outline (art/v5/chest_0.png). Written to
game/Forest/art/v9/: chair, table, table_food, bed (the hide bed) and barrel.
"""
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "Forest", "art", "v9")

# The chest's palette (art/v5/chest_*.png) plus cloth, food and iron.
P = {
    "K": (26, 23, 38),      # outline
    "O": (46, 36, 31),      # soft outline / deepest wood
    "d": (58, 42, 30),      # wood, dark
    "m": (110, 90, 62),     # wood, mid
    "l": (168, 136, 98),    # wood, light
    "h": (199, 168, 92),    # wood, lit edge
    "H": (217, 195, 154),   # wood, brightest glint
    "r": (107, 74, 74),     # red-brown wood (the chest's)
    "R": (168, 106, 82),    # red-brown, light
    "g": (63, 81, 40),      # moss
    "i": (62, 60, 70),      # iron
    "I": (128, 126, 134),   # iron, lit
    "w": (236, 224, 196),   # linen, light
    "W": (200, 184, 150),   # linen, shade
    "v": (156, 138, 108),   # linen, deep fold
    "b": (150, 52, 42),     # blanket
    "B": (190, 86, 58),     # blanket, light
    "x": (98, 34, 32),      # blanket, dark
    "y": (214, 170, 84),    # blanket stripe (ochre)
    "f": (122, 86, 52),     # fur trim
    "F": (170, 128, 80),    # fur trim, light
    "p": (206, 202, 192),   # plate
    "P": (150, 146, 140),   # plate rim shade
    "c": (160, 84, 40),     # roast
    "C": (212, 132, 64),    # roast, lit
    "e": (206, 158, 84),    # bread
    "E": (236, 196, 120),   # bread, lit
    "a": (184, 40, 40),     # apple
    "A": (236, 96, 80),     # apple, lit
    "q": (94, 122, 51),     # leaf / greens
    "s": (240, 234, 222),   # foam
    ".": None,
}


def from_rows(rows):
    h = len(rows)
    w = max(len(r) for r in rows)
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            col = P[ch]
            if col is not None:
                px[x, y] = col + (255,)
    return img


# A chair facing the viewer: the back (a vertical panel, its top edge lit),
# the seat below it (a top face, lighter), the seat's front, two front legs.
CHAIR = [
    "................",
    "................",
    "................",
    "....KKKKKKKK....",
    "....KHhhhhlK....",
    "....KmmmmmdK....",
    "....KmddddmK....",
    "....KmdrrdmK....",
    "....KmddddmK....",
    "....KmmmmmdK....",
    "...KlhhhhhhlK...",
    "...KllllllllK...",
    "...KlllllllmK...",
    "...KmmmmmmmmK...",
    "...KddddddddK...",
    "...KKKKKKKKKK...",
    "...KmK....KmK...",
    "...KdK....KdK...",
    "...KKK....KKK...",
    "................",
]


def table(food=False):
    """A two-cell table: its top (planks, lit along the back), the apron's
    front, four legs (the back two a shade darker, set in)."""
    w, h = 32, 24
    rows = [["."] * w for _ in range(h)]
    x0, x1 = 2, 29          # outline columns
    top0, top1 = 5, 15      # the top's rows (outline at top0)
    for x in range(x0, x1 + 1):
        rows[top0][x] = "K"
    for y in range(top0 + 1, top1 + 1):
        rows[y][x0] = "K"
        rows[y][x1] = "K"
        for x in range(x0 + 1, x1):
            if y == top0 + 1:
                c = "h" if x not in (x0 + 1, x1 - 1) else "l"
            elif (y - top0) % 4 == 0:
                c = "m"                      # a seam between planks
            else:
                c = "l"
            # a knot or two, a darker end grain at the right
            if (x, y) in ((9, 8), (21, 12), (15, 10)):
                c = "m"
            if x == x1 - 1 and y > top0 + 1:
                c = "m"
            rows[y][x] = c
    for y in (top1 + 1, top1 + 2):          # the apron's front
        rows[y][x0] = "K"
        rows[y][x1] = "K"
        for x in range(x0 + 1, x1):
            rows[y][x] = "d" if y == top1 + 2 else "m"
    for x in range(x0, x1 + 1):
        rows[top1 + 3][x] = "K"
    # Legs: the front two at the corners, the back two set in and darker.
    for lx, shade in ((x0, "m"), (x1 - 2, "m"), (x0 + 4, "O"), (x1 - 6, "O")):
        for y in range(top1 + 4, top1 + 7):
            rows[y][lx] = "K"
            rows[y][lx + 1] = shade if y < top1 + 6 else "K"
            rows[y][lx + 2] = "K"
    if food:
        _lay(rows, [
            ".KKKKK.",
            "KPpppPK",
            "KpCCcpK",
            "KpcCccK",
            "KPpppPK",
            ".KKKKK.",
        ], 5, 7)          # a plate with a roast
        _lay(rows, [
            ".KKKK.",
            "KEEEeK",
            "KeEeeK",
            ".KKKK.",
        ], 14, 7)         # a loaf
        _lay(rows, [
            "KKK",
            "KAK",
            "KaK",
            "KKK",
        ], 14, 11)        # an apple
        _lay(rows, [
            "KKKKK",
            "KsssK",
            "KmmdKK",
            "KmmdK.",
            "KKKKK.",
        ], 21, 6)         # a mug of ale
        _lay(rows, [
            ".KKKK.",
            "KPppPK",
            "KqqaqK",
            "KPppPK",
            ".KKKK.",
        ], 20, 11)        # a plate of greens
    return from_rows(["".join(r) for r in rows])


def _lay(rows, art, ox, oy):
    for y, line in enumerate(art):
        for x, ch in enumerate(line):
            if ch != ".":
                rows[oy + y][ox + x] = ch


def bed():
    """The hide bed from above: the headboard's face at the head, a pillow,
    the linen turned down over a woven blanket with an ochre band, a fur
    throw across the foot, the foot board's face and two short legs."""
    w, h = 30, 40
    rows = [["."] * w for _ in range(h)]
    x0, x1 = 3, 26
    # Headboard: top edge and face (rows 2-7).
    for x in range(x0, x1 + 1):
        rows[2][x] = "K"
    for y in range(3, 8):
        rows[y][x0] = "K"
        rows[y][x1] = "K"
        for x in range(x0 + 1, x1):
            if y == 3:
                c = "H" if x < x0 + 6 else "h"
            elif y == 7:
                c = "d"
            else:
                c = "r" if (x - x0) % 5 else "O"   # planks of the chest's red-brown wood
                if y == 4 and c == "r":
                    c = "R"
            rows[y][x] = c
    # The frame's sides and the bed's top face (rows 8-33).
    for y in range(8, 34):
        rows[y][x0] = "K"
        rows[y][x1] = "K"
        rows[y][x0 + 1] = "m"
        rows[y][x1 - 1] = "d"
        for x in range(x0 + 2, x1 - 1):
            rows[y][x] = "W"
    # Pillow.
    _lay(rows, [
        "..KKKKKKKKKKKKKK..",
        ".KwwwwwwwwwwwwwWK.",
        "KwwwwwwwwwwwwwwwWK",
        "KWwwwwwwvwwwwwwwWK",
        "KWWwwwwwwwwwwwwWWK",
        ".KWWWWWWWWWWWWWWK.",
        "..KKKKKKKKKKKKKK..",
    ], x0 + 3, 8)
    # The linen turned down (rows 16-17), then the blanket.
    for y in range(16, 34):
        for x in range(x0 + 2, x1 - 1):
            if y == 16:
                c = "w"
            elif y == 17:
                c = "v"
            elif y in (24, 25):
                c = "y" if y == 24 else "e"
            elif y >= 29:
                c = "F" if (x + y) % 3 else "f"          # the fur throw
            else:
                c = "B" if (x * 3 + y * 5) % 11 == 0 else ("x" if x in (x0 + 2, x1 - 2) else "b")
            rows[y][x] = c
    # Foot board face and legs.
    for y in (34, 35):
        rows[y][x0] = "K"
        rows[y][x1] = "K"
        for x in range(x0 + 1, x1):
            rows[y][x] = "r" if y == 34 else "O"
    for x in range(x0, x1 + 1):
        rows[36][x] = "K"
    for lx in (x0, x1 - 2):
        for y in (37, 38):
            rows[y][lx] = "K"
            rows[y][lx + 1] = "d" if y == 37 else "K"
            rows[y][lx + 2] = "K"
    return from_rows(["".join(r) for r in rows])


# A barrel from above: the lid (an ellipse of planks, a lit rim), the staves'
# short curved front with two iron hoops.
BARREL = [
    "................",
    ".....KKKKKK.....",
    "...KKhHhhhhKK...",
    "..KhlmllmllmhK..",
    "..KllmllmllmlK..",
    "..KllmllmllmlK..",
    "..KmlmllmllmmK..",
    "...KmmddddmmK...",
    "..KiiiiiiiiiiK..",
    "..KIiiiiiiiiiK..",
    "..KmllmllmlmdK..",
    "..KmllmllmlmdK..",
    "..KmllmllmlmdK..",
    "..KiiiiiiiiiiK..",
    "..KIiiiiiiiiiK..",
    "..KdmmdmmdmmdK..",
    "...KKKKKKKKKK...",
    "................",
]


def main():
    os.makedirs(OUT, exist_ok=True)
    art = {
        "chair": from_rows(CHAIR),
        "table": table(False),
        "table_food": table(True),
        "bed": bed(),
        "barrel": from_rows(BARREL),
    }
    if "--preview" in sys.argv:
        path = sys.argv[sys.argv.index("--preview") + 1]
        chest = Image.open(os.path.join(ROOT, "game", "Forest", "art", "v5", "chest_0.png")).convert("RGBA")
        items = [chest] + list(art.values())
        z = 6
        wid = sum(i.width * z + 24 for i in items) + 24
        hei = max(i.height for i in items) * z + 24
        sheet = Image.new("RGBA", (wid, hei), (86, 124, 64, 255))
        x = 24
        for i in items:
            sheet.alpha_composite(i.resize((i.width * z, i.height * z), Image.NEAREST), (x, hei - 12 - i.height * z))
            x += i.width * z + 24
        sheet.save(path)
        print("preview", path)
        return
    for name, img in art.items():
        if name != "bed":
            # Stand the art on the canvas's last row (props draw it with its
            # bottom 7 px below the cell's centre); the bed keeps the hide
            # bed's 30x40 frame and its rects.
            img = img.crop((0, 0, img.width, img.getbbox()[3]))
        img.save(os.path.join(OUT, name + ".png"))
        print("wrote", name, img.size)
    # The bed's item icon: the same bed with eight rows of blanket taken out,
    # so it fits a 32x32 slot at 1:1.
    b = art["bed"]
    keep = [y for y in range(b.height) if y not in (18, 19, 20, 21, 26, 27, 30, 39)]
    icon = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    top = 32 - len(keep)
    for i, y in enumerate(keep[2:]):
        icon.paste(b.crop((0, y, b.width, y + 1)), (1, top + i))
    icon.save(os.path.join(OUT, "bed_item.png"))
    print("wrote bed_item", icon.size)


if __name__ == "__main__":
    main()
