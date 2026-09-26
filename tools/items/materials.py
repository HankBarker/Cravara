"""Pass 15: each land's building stuff (the items; their art is
tools/world/make_material_art.py, their rules game/Forest/world/Materials.gd).

    python tools/items/materials.py      # write game/Items/Data/<id>.tres
"""
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DATA = os.path.join(ROOT, "game", "Items", "Data")
ICONS = os.path.join(ROOT, "game", "Forest", "art", "items")

# id: (name, stack, placeable, story)
ITEMS = {
    "bogwood": ("Mirewood", 99, False, "Black, wet and heavy: the Mirefen's trees. It doesn't rot."),
    "palewood": ("Palewood", 99, False, "Ash-grey wood from the Pale Lands, light and hard as bone."),
    "sandstone": ("Sandstone", 99, False, "Warm stone cut from the dunes' and the Bonelands' rock."),
    "bogwood_wall": ("Mirewood Wall", 99, True, "A palisade of black mirewood: sturdier than timber. Place on the world grid."),
    "bogwood_floor": ("Mirewood Floor", 99, True, "Dark mirewood boards. Place on the world grid; houses need a floor."),
    "palewood_wall": ("Palewood Wall", 99, True, "A pale palisade from the ash country. Place on the world grid."),
    "palewood_floor": ("Palewood Floor", 99, True, "Pale boards, bleached by ash. Place on the world grid; houses need a floor."),
    "sandstone_wall": ("Sandstone Wall", 99, True, "Blocks of warm dune stone, nearly as hard as granite. Place on the world grid."),
    "sandstone_floor": ("Sandstone Floor", 99, True, "Sandstone flags. Place on the world grid; houses need a floor."),
    "crystal_wall": ("Crystal-set Wall", 99, True, "Slate bound with Sky-Fang crystal: the strongest wall there is. Place on the world grid."),
    "crystal_floor": ("Crystal-set Floor", 99, True, "Slate flags with crystal in the seams. Place on the world grid; houses need a floor."),
}


def tres(iid):
    name, stack, placeable, story = ITEMS[iid]
    has_icon = os.path.exists(os.path.join(ICONS, iid + ".png"))
    out = '[gd_resource type="Resource" script_class="Item" load_steps=%d format=3]\n' % (3 if has_icon else 2)
    out += '[ext_resource type="Script" path="res://Items/Item.gd" id="1"]\n'
    if has_icon:
        out += '[ext_resource type="Texture2D" path="res://Forest/art/items/%s.png" id="2"]\n' % iid
    out += '[resource]\nscript = ExtResource("1")\nid = "%s"\nname = "%s"\ndescription = "%s"\n' % (iid, name, story)
    out += 'icon = ExtResource("2")\n' if has_icon else 'icon_generator = "forest"\n'
    out += 'max_stack = %d\nrarity = "common"\n' % stack
    if placeable:
        out += "placeable = true\n"
    return out


def main():
    for iid in ITEMS:
        open(os.path.join(DATA, iid + ".tres"), "w", encoding="utf-8", newline="\n").write(tres(iid))
    print("wrote %d items" % len(ITEMS))


if __name__ == "__main__":
    main()
