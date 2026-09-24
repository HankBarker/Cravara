"""Cravera's interface art: carved fossil-slate, bronze lashings and Sky-Fang crystal.

    python tools/ui/make_ui_art.py

Writes game/UI/art/*.png, native-pixel nine-patch pieces that UI/SkyfangUI.gd
turns into StyleBoxTextures (margins in NINE below), plus the HUD icons:

- plaques (buttons): normal, hover, pressed, on (a toggle held down), disabled
- sockets (inventory and hotbar slots): slot, slot_hover, slot_selected
- field (text input), chip (a key cap for hints), tip (tooltips), card and
  card_dim (recipe and companion rows), shade (a soft backing for toasts)
- icons: heart (vitality), meat (hunger), drop (bleeding), shield (defence)
  and crystal, cut from the Raven Fantasy icon sheet in assets_raw (the same
  sheet the forest's items use); arrow (drop-down) and pip are drawn here.

Everything is drawn in the palette of UI/CrystalFrame.gd so the panels, the
world's ruins and these pieces read as one set. Corners are cut (never round)
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


VOID = hexc("091a1b")
SLATE_D = hexc("0e2021")
SLATE = hexc("152c2b")
SLATE_M = hexc("1d3935")
SLATE_L = hexc("27463f")
SLATE_H = hexc("33584d")
MOSS = hexc("3d694c")
RIM = hexc("547f76")
BRONZE_H = hexc("e0c68c")
BRONZE_L = hexc("bc9e67")
BRONZE = hexc("8f7650")
BRONZE_D = hexc("5c4a33")
CRYSTAL_H = hexc("d6f7e6")
CRYSTAL_L = hexc("a2e3ca")
CRYSTAL = hexc("459a93")
CRYSTAL_D = hexc("1f5552")
DIM_FACE = hexc("1a2a29")
DIM_EDGE = hexc("2c3d3a")
DIM_TICK = hexc("4f4a3c")

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


def ticks(img, color, light=None):
    """Bronze lashings in each corner, the mark of the crystal frames."""
    w, h = img.size
    for sx, sy in [(0, 0), (1, 0), (0, 1), (1, 1)]:
        x = 2 if sx == 0 else w - 3
        y = 2 if sy == 0 else h - 3
        dx = 1 if sx == 0 else -1
        dy = 1 if sy == 0 else -1
        put(img, x, y, light or color)
        put(img, x + dx, y, color)
        put(img, x, y + dy, color)


def plaque(face, top, bottom, lash, lash_light=None, glint=None, pressed=False, edge=VOID):
    """A carved slate plaque (16x14): bevel lit from the top-left, lashed corners."""
    w, h = 16, 14
    img = canvas(w, h)
    outline(img, edge)
    fill(img, 1, 1, w - 2, h - 2, face)
    hi, lo = (bottom, top) if pressed else (top, bottom)
    hline(img, 2, w - 3, 1, hi)
    vline(img, 1, 2, h - 3, hi)
    hline(img, 2, w - 3, h - 2, lo)
    vline(img, w - 2, 2, h - 3, lo)
    # A second, deeper shadow under the plaque: it stands off the panel.
    if not pressed:
        hline(img, 2, w - 3, h - 3, lerp(face, lo, 0.5))
    ticks(img, lash, lash_light)
    if glint:
        put(img, 3, 1, glint)
        put(img, 4, 1, glint)
        put(img, 1, 3, glint)
    return img


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(4))


def socket(rim_top, rim_bottom, floor, ring=VOID, glow=None, lash=None):
    """A recessed stone socket (16x16): shadow along the top-left, a worn lip below."""
    w, h = 16, 16
    img = canvas(w, h)
    outline(img, ring)
    fill(img, 1, 1, w - 2, h - 2, floor)
    hline(img, 1, w - 2, 1, rim_top)
    vline(img, 1, 1, h - 2, rim_top)
    hline(img, 2, w - 3, 2, lerp(rim_top, floor, 0.5))
    vline(img, 2, 2, h - 3, lerp(rim_top, floor, 0.5))
    hline(img, 2, w - 2, h - 2, rim_bottom)
    vline(img, w - 2, 2, h - 2, rim_bottom)
    if glow:
        # The selected socket: a crystal ring inside the stone.
        hline(img, 3, w - 4, 3, glow[0])
        vline(img, 3, 3, h - 4, glow[1])
        hline(img, 3, w - 4, h - 4, glow[1])
        vline(img, w - 4, 3, h - 4, glow[1])
        put(img, 3, 3, glow[2])
    if lash:
        ticks(img, lash)
    return img


def field():
    """Recessed text field (12x12) with a bronze lip along the bottom."""
    img = canvas(12, 12)
    outline(img, VOID)
    fill(img, 1, 1, 10, 10, SLATE_D)
    hline(img, 1, 10, 1, hexc("071516"))
    vline(img, 1, 1, 10, hexc("071516"))
    hline(img, 2, 10, 10, BRONZE_D)
    vline(img, 10, 2, 10, hexc("1a2d2b"))
    return img


def chip():
    """A key cap (10x12): face, lit top, and a deep front edge below."""
    img = canvas(10, 12)
    outline(img, VOID)
    fill(img, 1, 1, 8, 10, hexc("3a3325"))
    fill(img, 1, 1, 8, 7, hexc("5f5236"))
    hline(img, 2, 7, 1, BRONZE_L)
    vline(img, 1, 2, 6, hexc("7d6a45"))
    hline(img, 2, 7, 8, hexc("2b2519"))
    return img


def tip():
    """Tooltip plate (12x12): slate inside a bronze band."""
    img = canvas(12, 12)
    outline(img, VOID)
    fill(img, 1, 1, 10, 10, BRONZE)
    hline(img, 1, 10, 1, BRONZE_L)
    fill(img, 2, 2, 9, 9, hexc("0f2223"))
    hline(img, 2, 9, 2, SLATE_M)
    ticks(img, BRONZE_H)
    return img


def card(border, face, lash):
    """A row card (16x16): a thin carved border, lashed corners."""
    img = canvas(16, 16)
    outline(img, VOID)
    fill(img, 1, 1, 14, 14, border)
    fill(img, 2, 2, 13, 13, face)
    hline(img, 2, 13, 2, lerp(face, border, 0.35))
    ticks(img, lash)
    return img


def shade():
    """A soft dark backing (8x8) for toasts and hints over bright ground."""
    img = canvas(8, 8)
    for y in range(8):
        for x in range(8):
            edge = min(x, y, 7 - x, 7 - y)
            img.putpixel((x, y), (6, 18, 19, [70, 130, 165, 175][min(edge, 3)]))
    return img


def arrow():
    """Drop-down arrow (7x5): a small bronze-rimmed crystal wedge."""
    img = canvas(7, 5)
    rows = ["BBBBBBB", ".BCCCB.", "..BCB..", "...B...", "......."]
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "B":
                put(img, x, y, BRONZE_L)
            elif ch == "C":
                put(img, x, y, CRYSTAL_L)
    return img


def pip(lit):
    """A 7x7 crystal pip (hotbar pouch marker): lit for the pouch in hand."""
    img = canvas(7, 7)
    shape = ["...B...", "..BLB..", ".BLHLB.", "BLHWHCB", ".BCHCB.", "..BCB..", "...B..."]
    colors = {"B": BRONZE_L if lit else BRONZE_D, "L": CRYSTAL_L if lit else hexc("2a4744"),
              "H": CRYSTAL_H if lit else hexc("33524e"), "W": (255, 255, 255, 255) if lit else hexc("3b5a55"),
              "C": CRYSTAL if lit else hexc("20383a")}
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
    pieces = {
        "button_normal": (plaque(SLATE_M, SLATE_H, hexc("0f2423"), BRONZE, BRONZE_L), (4, 4, 4, 4)),
        "button_hover": (plaque(SLATE_L, hexc("4a7867"), hexc("132b29"), BRONZE_L, BRONZE_H, glint=CRYSTAL_H), (4, 4, 4, 4)),
        "button_pressed": (plaque(hexc("132a28"), SLATE_H, hexc("0a1c1c"), BRONZE, BRONZE_L, pressed=True), (4, 4, 4, 4)),
        "button_on": (plaque(hexc("1b3d3a"), CRYSTAL, hexc("0c2222"), BRONZE_L, BRONZE_H, pressed=True, edge=CRYSTAL_D), (4, 4, 4, 4)),
        "button_disabled": (plaque(DIM_FACE, DIM_EDGE, hexc("121e1d"), DIM_TICK, edge=hexc("0c1717")), (4, 4, 4, 4)),
        "slot": (socket(hexc("071617"), hexc("2c4a43"), hexc("112423")), (5, 5, 5, 5)),
        "slot_hover": (socket(hexc("071617"), RIM, hexc("17302e"), ring=hexc("0d2021")), (5, 5, 5, 5)),
        "slot_selected": (socket(hexc("0a1d1d"), CRYSTAL, hexc("183c38"), ring=CRYSTAL_D, glow=(CRYSTAL_L, CRYSTAL, CRYSTAL_H), lash=BRONZE_H), (5, 5, 5, 5)),
        "field": (field(), (4, 4, 4, 4)),
        "chip": (chip(), (3, 3, 3, 4)),
        "tip": (tip(), (4, 4, 4, 4)),
        "card": (card(hexc("35574b"), hexc("12292a"), BRONZE_L), (5, 5, 5, 5)),
        "card_dim": (card(hexc("243632"), hexc("0f2020"), DIM_TICK), (5, 5, 5, 5)),
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
