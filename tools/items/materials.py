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
    # Pass 18: the far ring's and the treetops' stuff.
    "vine": ("Jungle Vine", 99, False, "Tough, springy vine pulled down from the jungle's trees. Good as rope."),
    "glimmer_shard": ("Glimmer Shard", 99, False, "Sky-Fang crystal grown green and bright in the jungle. It glows in the dark."),
    "orchid": ("Canopy Orchid", 30, False, "A pale orchid from the treetops. Healers and dyers want it."),
    "amber": ("Amber", 40, False, "Golden resin from the giants' bark, hard as stone. Some pieces have things caught inside."),
    "charcoal": ("Charcoal", 99, False, "A burnt tree's heart. It burns hot, and blasting powder needs it."),
    "emberstone": ("Emberstone", 40, False, "The volcano's own ore: rock that never quite cools. The best blades are forged from it."),
    "sulfur": ("Sulfur", 60, False, "Yellow crust from the volcano's vents. It stinks, and it makes a bomb twice the bomb."),
    "obsidian": ("Obsidian", 60, False, "Black volcanic glass. Keener than any stone, and it laughs at the heat."),
    # Pass 18: the new beasts' spoils and the bosses' trophies (their armour,
    # weapons and trinkets are made of these), and the volcano's forge.
    "thyla_pelt": ("Treeshadow Pelt", 40, False, "A thylacoleo's striped pelt, soft and silent among the leaves."),
    "thyla_claw": ("Treeshadow Claw", 40, False, "The hooked thumb-claw a thylacoleo climbs and kills with."),
    "wing_leather": ("Wing Leather", 40, False, "Thin, tough skin from a pteranodon's wing. It holds the wind."),
    "ptera_crest": ("Pteranodon Crest", 20, False, "A long bony crest, light as a reed and hard as horn."),
    "dimorph_tooth": ("Dimorph Tooth", 60, False, "A dimorphodon's needle tooth. They have far too many."),
    "reaper_claw": ("Reaper's Claw", 10, False, "A scythe of a claw from the Pale Reaper. Frost clings to it, even in the sun."),
    "storm_feather": ("Storm Feather", 20, False, "A great grey feather from Stormcrest's wing. It crackles when you stroke it."),
    "molten_core": ("Molten Core", 5, False, "The Cinderhulk's burning heart: heavy as iron, and never cool."),
    "ember_forge": ("Ember Forge", 3, True, "A forge of black stone that burns emberstone. Stand by it to forge obsidian and the fire's own gear. Place on the world grid."),
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
