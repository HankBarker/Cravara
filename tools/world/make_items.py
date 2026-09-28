"""Items found at the forest's points of interest: icons and item resources.

    python tools/world/make_items.py

Icons are 16x16 cells cut from the Raven Fantasy icon sheet in assets_raw
(Free - Raven Fantasy Icons, Clockwork Raven Studios); the baked tuber is the
wild tuber roasted here. Writes game/Forest/art/items/<id>.png and
game/Items/Data/<id>.tres (ItemDB picks the .tres up by itself). The baked
tuber's campfire recipe lives in Scripts/CraftingManager.gd.
"""
import os
import zipfile
from io import BytesIO

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
ZIP = os.path.join(ROOT, "assets_raw", "Free - Raven Fantasy Icons.zip")
SHEET = "Full Spritesheet/16x16.png"
ICONS = os.path.join(ROOT, "game", "Forest", "art", "items")
DATA = os.path.join(ROOT, "game", "Items", "Data")

# id: (sheet row, column) of the 16x16 icon.
CELLS = {"ancient_coin": (8, 2), "sky_idol": (8, 7), "fossil_bone": (14, 6), "wild_tuber": (27, 9)}

ITEMS = [
    {"id": "ancient_coin", "name": "Ancient Coin", "stack": 99, "rarity": "uncommon",
     "text": "A tarnished gold coin stamped with a falling star. The first builders minted them; traders still prize them."},
    {"id": "sky_idol", "name": "Sky-Fang Idol", "stack": 10, "rarity": "rare",
     "text": "A gilded figure of the old tribe's star-god, cold to the touch. A collector would pay well for it."},
    {"id": "fossil_bone", "name": "Fossil Bone", "stack": 30, "rarity": "uncommon",
     "text": "Stone that was once bone, from a beast older than the forest. Anyone who studies dinosaurs would want it."},
    {"id": "wild_tuber", "name": "Wild Tuber", "stack": 30, "rarity": "common", "food": [10, 4.0, 8.0, 10.0],
     "text": "A knobbly root dug from the meadow. Edible raw, better baked. 10 hunger; 4 vitality over 8 seconds."},
    {"id": "baked_tuber", "name": "Baked Tuber", "stack": 30, "rarity": "common", "food": [45, 14.0, 16.0, 60.0],
     "text": "Soft and sweet from the campfire. 45 hunger, full for a minute; 14 vitality over 16 seconds."},
]


def roast(img):
    """Browner and darker, with a toasted rim: the baked tuber."""
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (int(r * 0.78 + 10), int(g * 0.6 + 6), int(b * 0.42), a)
    # A wisp of steam over the top.
    for x, y in [(7, 1), (8, 0), (10, 2), (11, 1)]:
        px[x, y] = (236, 236, 228, 200)
    return out


def tres(item):
    lines = [
        '[gd_resource type="Resource" script_class="Item" load_steps=3 format=3]',
        '[ext_resource type="Script" path="res://Items/Item.gd" id="1"]',
        '[ext_resource type="Texture2D" path="res://Forest/art/items/%s.png" id="2"]' % item["id"],
        "[resource]",
        'script = ExtResource("1")',
        'id = "%s"' % item["id"],
        'name = "%s"' % item["name"],
        'description = "%s"' % item["text"],
        'icon = ExtResource("2")',
        "max_stack = %d" % item["stack"],
        'rarity = "%s"' % item["rarity"],
    ]
    if "food" in item:
        hunger, heal, secs, full = item["food"]
        lines += ["consumable = true", "hunger_value = %d" % hunger, "healing_total = %.1f" % heal,
                  "healing_duration = %.1f" % secs, "food_satiation_seconds = %.1f" % full]
    return "\n".join(lines) + "\n"


def main():
    os.makedirs(ICONS, exist_ok=True)
    with zipfile.ZipFile(ZIP) as z:
        member = next(n for n in z.namelist() if n.replace("\\", "/").endswith(SHEET))
        sheet = Image.open(BytesIO(z.read(member))).convert("RGBA")
    icons = {}
    for item_id, (row, col) in CELLS.items():
        icons[item_id] = sheet.crop((col * 16, row * 16, col * 16 + 16, row * 16 + 16))
    icons["baked_tuber"] = roast(icons["wild_tuber"])
    for item_id, img in icons.items():
        img.save(os.path.join(ICONS, item_id + ".png"))
    for item in ITEMS:
        with open(os.path.join(DATA, item["id"] + ".tres"), "w", encoding="utf-8", newline="\n") as f:
            f.write(tres(item))
    print("icons:", sorted(icons), "items:", [i["id"] for i in ITEMS])


if __name__ == "__main__":
    main()
