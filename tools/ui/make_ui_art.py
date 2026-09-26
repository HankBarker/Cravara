"""Cravera's interface art: a keeper's field pack (pass 14).

    python tools/ui/make_ui_art.py

Writes game/UI/art/*.png, native-pixel nine-patch pieces that UI/SkyfangUI.gd
turns into StyleBoxTextures (margins in NINE below), plus the HUD icons:

- tabs (buttons): normal, hover, pressed, on (a toggle held down), disabled:
  stitched leather tabs
- pockets (inventory and hotbar slots): slot, slot_hover, slot_selected:
  stitched leather pockets whose floor lets the world show through, a brass
  ring round the one in hand
- field (text input), chip (a key cap for hints), tip (tooltips), card and
  card_dim (recipe and companion rows), shade (a soft backing for toasts)
- icons: heart (vitality), meat (hunger), drop (bleeding), shield (defence)
  and crystal, cut from the Raven Fantasy icon sheet in assets_raw (the same
  sheet the forest's items use); arrow (drop-down) and pip are drawn here.

Pass 13's carved fossil slate and mint crystal read green and heavy (Hank:
"not a big fan of the green"); pass 14 is leather, brass and stitching with
the Sky-Fang's pale blue for whatever is lit. Corners are cut (never round)
and every edge is a whole pixel, so the pieces stay crisp at the 4x scale.
"""
import json
import os
import zipfile
from io import BytesIO

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "game", "UI", "art")
RAVEN = os.path.join(ROOT, "assets_raw", "Free - Raven Fantasy Icons.zip")


def hexc(value, alpha=255):
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


VOID = hexc("140c07")
LEATHER_D = hexc("2a1b12")
LEATHER = hexc("4a3021")
LEATHER_M = hexc("5e3d29")
LEATHER_L = hexc("7a5236")
LEATHER_H = hexc("98693f")
STITCH = hexc("dcb77a")
STITCH_D = hexc("9c7a48")
BRASS_D = hexc("6b4a1f")
BRASS = hexc("a9803c")
BRASS_L = hexc("d8ad5f")
BRASS_H = hexc("f1d38c")
CRYSTAL_H = hexc("eaf8ff")
CRYSTAL_L = hexc("bfe8f8")
CRYSTAL = hexc("7fc8e8")
CRYSTAL_D = hexc("2f6f8f")
DIM_FACE = hexc("3a2e25")
DIM_EDGE = hexc("4a3d32")
DIM_TICK = hexc("6a5a48")

# name: nine-patch margins (left, top, right, bottom) the theme stretches by.
NINE = {}


def canvas(w, h):
    return Image.new("RGBA", (w, h), (0, 0, 0, 0))


def put(img, x, y, color):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), color)


def hline(img, x0, x1, y, color):
    for x in range(x0, x1 + 1):
        put(img, x, y, color)


def vline(img, x, y0, y1, color):
    for y in range(y0, y1 + 1):
        put(img, x, y, color)


def outline(img, color):
    """A 1px ring with the four corner pixels cut away."""
    w, h = img.size
    hline(img, 1, w - 2, 0, color)
    hline(img, 1, w - 2, h - 1, color)
    vline(img, 0, 1, h - 2, color)
    vline(img, w - 1, 1, h - 2, color)


def fill(img, x0, y0, x1, y1, color):
    for y in range(y0, y1 + 1):
        hline(img, x0, x1, y, color)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(4))


def stitches(img, color, inset, horizontal=True, vertical=False):
    """A running stitch `inset` px inside the edge: every other pixel, the
    corners left bare so the nine-patch stretches it evenly."""
    w, h = img.size
    if horizontal:
        for x in range(inset + 1, w - inset - 1, 2):
            put(img, x, inset, color)
            put(img, x, h - 1 - inset, color)
    if vertical:
        for y in range(inset + 1, h - inset - 1, 2):
            put(img, inset, y, color)
            put(img, w - 1 - inset, y, color)


def rivets(img, color, light):
    """Brass rivets in the corners, where the frames had lashings."""
    w, h = img.size
    for x, y in [(2, 2), (w - 3, 2), (2, h - 3), (w - 3, h - 3)]:
        put(img, x, y, color)
    put(img, 2, 2, light)


def tab(face, top, bottom, stitch, pressed=False, edge=VOID, rivet=None):
    """A stitched leather tab (16x14): lit along the top, a stitch inside the
    top and bottom edges, standing off the pack (a darker lip below)."""
    w, h = 16, 14
    img = canvas(w, h)
    outline(img, edge)
    fill(img, 1, 1, w - 2, h - 2, face)
    hi, lo = (bottom, top) if pressed else (top, bottom)
    hline(img, 2, w - 3, 1, hi)
    vline(img, 1, 2, h - 3, lerp(face, hi, 0.5))
    hline(img, 2, w - 3, h - 2, lo)
    vline(img, w - 2, 2, h - 3, lerp(face, lo, 0.5))
    if not pressed:
        hline(img, 2, w - 3, h - 3, lerp(face, lo, 0.45))
    stitches(img, stitch, 3 if not pressed else 3)
    if rivet:
        rivets(img, rivet[0], rivet[1])
    return img


def pocket(floor, rim_top, rim_bottom, stitch, ring=VOID, glow=None):
    """A leather pocket (16x16): a dark mouth along the top, a worn lip below,
    a stitch round the inside, and a floor the world shows through."""
    w, h = 16, 16
    img = canvas(w, h)
    outline(img, ring)
    fill(img, 1, 1, w - 2, h - 2, floor)
    hline(img, 1, w - 2, 1, rim_top)
    vline(img, 1, 1, h - 2, lerp(rim_top, floor, 0.4))
    hline(img, 2, w - 2, h - 2, rim_bottom)
    vline(img, w - 2, 2, h - 2, lerp(rim_bottom, floor, 0.4))
    stitches(img, stitch, 2, horizontal=True, vertical=True)
    if glow:
        # The pocket in hand: a brass ring inside the leather.
        hline(img, 2, w - 3, 2, glow[0])
        vline(img, 2, 2, h - 3, glow[0])
        hline(img, 2, w - 3, h - 3, glow[1])
        vline(img, w - 3, 2, h - 3, glow[1])
        put(img, 2, 2, glow[2])
    return img


def field():
    """A text field (12x12): dark leather with a brass lip along the bottom."""
    img = canvas(12, 12)
    outline(img, VOID)
    fill(img, 1, 1, 10, 10, hexc("1f140d", 235))
    hline(img, 1, 10, 1, hexc("120b06"))
    vline(img, 1, 1, 10, hexc("120b06"))
    hline(img, 2, 10, 10, BRASS_D)
    vline(img, 10, 2, 10, LEATHER)
    return img


def chip():
    """A key cap (10x12): a brass-rimmed leather button."""
    img = canvas(10, 12)
    outline(img, VOID)
    fill(img, 1, 1, 8, 10, LEATHER)
    fill(img, 1, 1, 8, 7, LEATHER_L)
    hline(img, 2, 7, 1, BRASS_L)
    vline(img, 1, 2, 6, LEATHER_H)
    hline(img, 2, 7, 8, LEATHER_D)
    return img


def tip():
    """A tooltip (12x12): dark leather inside a brass band, a stitch within."""
    img = canvas(12, 12)
    outline(img, VOID)
    fill(img, 1, 1, 10, 10, BRASS)
    hline(img, 1, 10, 1, BRASS_L)
    fill(img, 2, 2, 9, 9, hexc("1d130c", 244))
    hline(img, 3, 8, 3, STITCH_D)
    return img


def card(border, face, stitch):
    """A row card (16x16): a leather strip with a stitched border."""
    img = canvas(16, 16)
    outline(img, VOID)
    fill(img, 1, 1, 14, 14, border)
    fill(img, 2, 2, 13, 13, face)
    hline(img, 2, 13, 2, lerp(face, border, 0.35))
    stitches(img, stitch, 3, horizontal=True, vertical=True)
    return img


def shade():
    """A soft dark backing (8x8) for toasts and hints over bright ground."""
    img = canvas(8, 8)
    for y in range(8):
        for x in range(8):
            edge = min(x, y, 7 - x, 7 - y)
            img.putpixel((x, y), (20, 12, 7, [70, 130, 165, 175][min(edge, 3)]))
    return img


def arrow():
    """Drop-down arrow (7x5): a brass wedge."""
    img = canvas(7, 5)
    rows = ["BBBBBBB", ".BCCCB.", "..BCB..", "...B...", "......."]
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "B":
                put(img, x, y, BRASS_L)
            elif ch == "C":
                put(img, x, y, BRASS_H)
    return img


def pip(lit):
    """A 7x7 crystal pip (hotbar pouch marker): lit for the pouch in hand."""
    img = canvas(7, 7)
    shape = ["...B...", "..BLB..", ".BLHLB.", "BLHWHCB", ".BCHCB.", "..BCB..", "...B..."]
    colors = {"B": BRASS_L if lit else BRASS_D, "L": CRYSTAL_L if lit else hexc("4a3b2e"),
              "H": CRYSTAL_H if lit else hexc("57463a"), "W": (255, 255, 255, 255) if lit else hexc("5e4d40"),
              "C": CRYSTAL if lit else hexc("3a2d23")}
    for y, row in enumerate(shape):
        for x, ch in enumerate(row):
            if ch in colors:
                put(img, x, y, colors[ch])
    return img


def raven_icons():
    with zipfile.ZipFile(RAVEN) as z:
        member = next(n for n in z.namelist() if n.replace("\\", "/").endswith("Full Spritesheet/16x16.png"))
        sheet = Image.open(BytesIO(z.read(member))).convert("RGBA")
    cells = {"heart": (41, 2), "meat": (30, 5), "drop": (46, 5), "shield": (41, 7), "crystal": (63, 5)}
    return {name: sheet.crop((c * 16, r * 16, c * 16 + 16, r * 16 + 16)) for name, (r, c) in cells.items()}


def main():
    os.makedirs(OUT, exist_ok=True)
    floor = hexc("1c120b", 178)
    pieces = {
        "button_normal": (tab(LEATHER_M, LEATHER_L, LEATHER_D, STITCH_D), (4, 4, 4, 4)),
        "button_hover": (tab(LEATHER_L, LEATHER_H, LEATHER, STITCH), (4, 4, 4, 4)),
        "button_pressed": (tab(LEATHER, LEATHER_L, LEATHER_D, STITCH_D, pressed=True), (4, 4, 4, 4)),
        "button_on": (tab(LEATHER_D, BRASS_L, hexc("1c120b"), BRASS_H, pressed=True, edge=BRASS), (4, 4, 4, 4)),
        "button_disabled": (tab(DIM_FACE, DIM_EDGE, hexc("241c16"), DIM_TICK, edge=hexc("1a120c")), (4, 4, 4, 4)),
        "slot": (pocket(floor, hexc("0e0804"), LEATHER_M, hexc("6e5234")), (5, 5, 5, 5)),
        "slot_hover": (pocket(hexc("33211a", 200), hexc("0e0804"), LEATHER_L, STITCH_D, ring=hexc("22160e")), (5, 5, 5, 5)),
        "slot_selected": (pocket(hexc("3a2718", 210), hexc("0e0804"), BRASS_L, STITCH, ring=BRASS_D, glow=(BRASS_L, BRASS, BRASS_H)), (5, 5, 5, 5)),
        "field": (field(), (4, 4, 4, 4)),
        "chip": (chip(), (3, 3, 3, 4)),
        "tip": (tip(), (4, 4, 4, 4)),
        "card": (card(LEATHER_L, hexc("33211a", 236), STITCH_D), (5, 5, 5, 5)),
        "card_dim": (card(hexc("4a3a2e"), hexc("241911", 226), DIM_TICK), (5, 5, 5, 5)),
        "shade": (shade(), (3, 3, 3, 3)),
    }
    for name, (img, margins) in pieces.items():
        img.save(os.path.join(OUT, name + ".png"))
        NINE[name] = list(margins)
    arrow().save(os.path.join(OUT, "arrow.png"))
    pip(True).save(os.path.join(OUT, "pip_lit.png"))
    pip(False).save(os.path.join(OUT, "pip.png"))
    for name, img in raven_icons().items():
        img.save(os.path.join(OUT, "icon_" + name + ".png"))
    with open(os.path.join(OUT, "nine.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(NINE, f, indent=1, sort_keys=True)
    print("wrote", len(pieces), "pieces and icons to", OUT)


if __name__ == "__main__":
    main()
