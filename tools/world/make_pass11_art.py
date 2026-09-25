"""Pass 11 art for the game: world objects cut from the PixelLab drawings in
art/pass11/objects/ (tools/world/make_objects.py) and item icons drawn here.

    python tools/world/make_pass11_art.py

Objects -> game/Forest/art/pass11/<name>.png (cropped to the drawing).
Icons   -> game/Forest/art/items/<id>.png (16 x 16, dark outline, one
           highlight, like the other forest icons).
"""
import os

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RAW = os.path.join(ROOT, "art", "pass11", "objects")
GAME_ART = os.path.join(ROOT, "game", "Forest", "art", "pass11")
ICONS = os.path.join(ROOT, "game", "Forest", "art", "items")

OUTLINE = (34, 26, 22, 255)

# Egg colours per species: shell, shade, speckle (they match the parents).
EGGS = {
    "lystro_egg": ((196, 204, 150), (150, 160, 104), (98, 110, 62)),
    "stego_egg": ((222, 214, 170), (178, 168, 120), (212, 128, 44)),
    "trike_egg": ((226, 196, 170), (184, 146, 120), (72, 160, 140)),
    "longneck_egg": ((196, 220, 226), (140, 176, 190), (64, 124, 170)),
    "raptor_egg": ((200, 214, 222), (146, 166, 182), (48, 150, 180)),
    "allo_egg": ((218, 190, 160), (170, 136, 104), (120, 64, 40)),
    "parasaur_egg": ((212, 222, 176), (160, 176, 124), (190, 112, 60)),
}


def crop_objects():
    os.makedirs(GAME_ART, exist_ok=True)
    for name in sorted(os.listdir(RAW)):
        if not name.endswith(".png"):
            continue
        img = Image.open(os.path.join(RAW, name)).convert("RGBA")
        box = img.getbbox()
        if box:
            img = img.crop(box)
        img.save(os.path.join(GAME_ART, name))
        print("object", name, img.size)


def egg(shell, shade, speck):
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = img.load()
    # An upright oval 8 wide, 11 tall, centred low.
    cx, cy, rx, ry = 7.5, 8.5, 4.2, 5.6
    inside = set()
    for y in range(16):
        for x in range(16):
            dx, dy = (x - cx) / rx, (y - cy) / ry
            # A little narrower at the top.
            if dy < 0:
                dx *= 1.0 + 0.18 * -dy
            if dx * dx + dy * dy <= 1.0:
                inside.add((x, y))
    for (x, y) in inside:
        right = x > cx + 1.2
        low = y > cy + 2.5
        px[x, y] = shade if (right or low) else shell
    for (x, y) in inside:
        for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if n not in inside and 0 <= n[0] < 16 and 0 <= n[1] < 16:
                px[n[0], n[1]] = OUTLINE
    # Speckles and a highlight.
    for (x, y) in [(6, 6), (9, 8), (7, 10), (10, 11), (5, 12), (8, 5)]:
        if (x, y) in inside:
            px[x, y] = speck + (255,)
    for (x, y) in [(5, 5), (5, 6)]:
        if (x, y) in inside:
            px[x, y] = (255, 250, 236, 255)
    return img


def pattern(rows, colours):
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    top = (16 - len(rows)) // 2
    for y, row in enumerate(rows):
        for x, ch in enumerate(row.ljust(16, ".")[:16]):
            if ch in colours:
                img.putpixel((x, top + y), colours[ch])
    return img


def icons():
    os.makedirs(ICONS, exist_ok=True)
    for item_id, (shell, shade, speck) in EGGS.items():
        egg(shell + (255,), shade + (255,), speck).save(os.path.join(ICONS, item_id + ".png"))
        print("icon", item_id)
    bone = {"o": OUTLINE, "w": (236, 226, 204, 255), "s": (190, 176, 150, 255)}
    pattern([
        ".ooo............",
        "owwwo.oo........",
        "owwwwowwo.......",
        ".owwwwwwo.......",
        "..owwwwso.......",
        "...owwwsso......",
        "....owwwsso.....",
        ".....owwwsso....",
        "......owwwsso...",
        ".......owwwwwo..",
        ".......owwwwwwo.",
        "........owoowwwo",
        ".........o..owwo",
        ".............oo.",
    ], bone).save(os.path.join(ICONS, "old_bone.png"))
    print("icon old_bone")
    more = {
        "glass_pearl": ({"o": OUTLINE, "w": (236, 246, 250, 255), "b": (176, 214, 232, 255), "s": (120, 170, 200, 255), "h": (255, 255, 255, 255)}, [
            "................",
            "................",
            "................",
            ".....oooooo.....",
            "....owwhwwbo....",
            "...owwhhwwbbo...",
            "...owwwwwbbbo...",
            "...owwwwbbbso...",
            "...owwwbbbsso...",
            "...obbbbbssso...",
            "....obbbsssso...",
            ".....oooooo.....",
        ]),
        "cactus_fruit": ({"o": OUTLINE, "r": (214, 58, 58, 255), "d": (150, 34, 40, 255), "g": (86, 150, 70, 255), "y": (250, 214, 120, 255), "h": (255, 170, 160, 255)}, [
            "......ogo.......",
            ".....oggo.......",
            "....oogoo.......",
            "...orrrrroo.....",
            "..orrhrrrrdo....",
            "..orhyrrryrdo...",
            "..orrrrrrrrdo...",
            "..oryrrrrydo....",
            "..orrrrrrrddo...",
            "...odrrrrddo....",
            "....oodddoo.....",
            "......ooo.......",
        ]),
        "pale_crystal": ({"o": (60, 58, 72, 255), "w": (240, 240, 250, 255), "l": (206, 198, 232, 255), "d": (158, 150, 196, 255)}, [
            "........o.......",
            ".......owo......",
            "..o....owlo.....",
            ".owo..owwlo.....",
            ".owlo.owwldo....",
            ".owwlowwwldo.o..",
            "..owlowwlldoowo.",
            "..owlowwlddoowlo",
            "..owlowwldoowldo",
            "...owowwldowlddo",
            "...oooooooooooo.",
        ]),
        "maw_tooth": ({"o": OUTLINE, "w": (246, 238, 216, 255), "s": (206, 192, 160, 255), "r": (150, 110, 90, 255)}, [
            "..oooooooooooo..",
            "..orrrrrrrrrro..",
            "..owwwwwwwwwso..",
            "...owwwwwwwso...",
            "...owwwwwwsso...",
            "....owwwwsso....",
            "....owwwwsso....",
            ".....owwsso.....",
            ".....owwsso.....",
            "......owso......",
            "......owso......",
            ".......oo.......",
        ]),
        "grave_horn": ({"o": OUTLINE, "w": (232, 222, 196, 255), "s": (190, 176, 148, 255), "b": (88, 160, 210, 255), "c": (170, 230, 246, 255)}, [
            "............oo..",
            "...........owso.",
            "..........owwso.",
            ".........owwso..",
            "........owwso...",
            ".......owwsso...",
            "..oo..owwsso....",
            ".obco.owssso....",
            ".obccowwsso.....",
            "..obcowwso......",
            "...oowwso.......",
            "....oooo........",
        ]),
        "bone_crown": ({"o": OUTLINE, "w": (236, 226, 204, 255), "s": (190, 176, 150, 255), "b": (88, 160, 210, 255), "c": (170, 230, 246, 255)}, [
            "................",
            "..o....oo....o..",
            ".owo..owwo..owo.",
            ".owo..owwo..owo.",
            ".owwo.owso.owso.",
            ".owwwowwsoowwso.",
            ".owwwwwbbwwwwso.",
            ".owwwwbccbwwwso.",
            ".owwwwwbbwwwsso.",
            ".osssssssssssso.",
            "..oooooooooooo..",
        ]),
        "maw_charm": ({"o": OUTLINE, "w": (246, 238, 216, 255), "s": (206, 192, 160, 255), "c": (150, 110, 90, 255), "p": (200, 230, 240, 255)}, [
            ".o............o.",
            ".c............c.",
            "..c..........c..",
            "...c........c...",
            "....cc.pp.cc....",
            "......oooo......",
            ".....owwwso.....",
            ".....owwwso.....",
            "......owso......",
            "......owso......",
            ".......oo.......",
        ]),
        # The boat's icon moved to make_pass12_art.py (the pass-12 rowboat).
    }
    for item_id, (colours, rows) in more.items():
        pattern(rows, colours).save(os.path.join(ICONS, item_id + ".png"))
        print("icon", item_id)
    # The incubator: the drawing itself, shrunk by whole pixels onto 16 x 16.
    src = os.path.join(GAME_ART, "incubator.png")
    if os.path.exists(src):
        inc = Image.open(src).convert("RGBA")
        small = inc.resize((max(1, inc.width // 2), max(1, inc.height // 2)), Image.NEAREST)
        out = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        out.alpha_composite(small, ((16 - small.width) // 2, 16 - small.height - 1))
        out.save(os.path.join(ICONS, "incubator.png"))
        print("icon incubator", small.size)


if __name__ == "__main__":
    crop_objects()
    icons()
