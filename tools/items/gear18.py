"""Pass 18: the far ring's gear: the new weapons and three armour sets (the
thylacoleo's Treeshadow, the pteranodon's Skywing, the volcano's Obsidian),
authored in one table like the trinkets.

    python tools/items/gear18.py            # write game/Items/Data/<id>.tres
    python tools/items/gear18.py --recipes  # print the CraftingManager rows

Icons: tools/keeper/make_icons.py (armour to the wardrobe icons, weapons to
Forest/art/items); a .tres points at its icon once the PNG exists (run again
after the icons).
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DATA = os.path.join(ROOT, "game", "Items", "Data")
ITEM_ICONS = os.path.join(ROOT, "game", "Forest", "art", "items")
WARDROBE = os.path.join(ROOT, "game", "Forest", "equipment", "art", "wardrobe", "icons")

# id: (name, rarity, damage, class, story, ingredients, station, hidden_until)
WEAPONS = {
    "glimmer_spear": ("Glimmer Spear", "epic", 44, "thrust", "A glimmer shard lashed to a vine-bound shaft. It glows in the jungle's dark.",
                      {"glimmer_shard": 5, "vine": 4, "thyla_claw": 1, "plank": 2}, "workbench", ""),
    "obsidian_blade": ("Obsidian Blade", "epic", 48, "sweep", "Black volcanic glass, keener than any steel, on an emberstone grip.",
                       {"obsidian": 6, "emberstone": 3, "plank": 2}, "ember_forge", ""),
    "reaper_scythe": ("Reaper's Scythe", "legendary", 52, "sweep", "The Pale Reaper's claw on a palewood haft. It sweeps wide and cold.",
                      {"reaper_claw": 1, "palewood": 4, "pale_crystal": 4}, "workbench", "reaper"),
    "storm_glaive": ("Stormwing Glaive", "legendary", 58, "sweep", "Storm feathers bound down a glimmer blade. It hums before a blow.",
                     {"storm_feather": 2, "wing_leather": 2, "glimmer_shard": 4, "plank": 2}, "workbench", "stormcrest"),
    "cinderbrand": ("Cinderbrand", "legendary", 64, "smash", "The Cinderhulk's molten core set in an obsidian head. It never cools.",
                    {"molten_core": 1, "obsidian": 6, "emberstone": 6}, "ember_forge", "cinderhulk"),
}

# set id: (set name, [(slot, name, defence, ingredients)], station, hidden_until, set text)
ARMOUR = {
    "thyla": ("Treeshadow", [
        ("helmet", "Treeshadow Hood", 10, {"thyla_pelt": 2, "vine": 2, "plant_fiber": 3}),
        ("chestplate", "Treeshadow Jerkin", 16, {"thyla_pelt": 4, "thyla_claw": 1, "vine": 3}),
        ("leggings", "Treeshadow Leggings", 12, {"thyla_pelt": 3, "vine": 2, "plant_fiber": 3}),
    ], "workbench", "", "beasts notice you from half as far, and you move 6% faster"),
    "sky": ("Skywing", [
        ("helmet", "Skywing Crest", 11, {"wing_leather": 2, "ptera_crest": 1, "plant_fiber": 2}),
        ("chestplate", "Skywing Mantle", 18, {"wing_leather": 4, "dimorph_tooth": 3, "vine": 2}),
        ("leggings", "Skywing Leggings", 13, {"wing_leather": 3, "vine": 2, "plant_fiber": 2}),
    ], "workbench", "", "you move 10% faster and roll further"),
    "obsidian": ("Obsidian", [
        ("helmet", "Obsidian Helm", 13, {"obsidian": 4, "emberstone": 2, "ashmane_fur": 1}),
        ("chestplate", "Obsidian Cuirass", 21, {"obsidian": 7, "emberstone": 3, "ashmane_fur": 2}),
        ("leggings", "Obsidian Greaves", 15, {"obsidian": 5, "emberstone": 2, "ashmane_fur": 1}),
    ], "ember_forge", "", "keeps off 60% of the volcano's heat; fire and lava harm you less"),
}
SLOT = {"helmet": "head", "chestplate": "chest", "leggings": "legs"}


def _tres(iid, name, story, icon_dir, icon_res, rarity, extra):
    icon = os.path.join(icon_dir, iid + ".png")
    has = os.path.exists(icon)
    out = '[gd_resource type="Resource" script_class="Item" load_steps=%d format=3]\n' % (3 if has else 2)
    out += '[ext_resource type="Script" path="res://Items/Item.gd" id="1"]\n'
    if has:
        out += '[ext_resource type="Texture2D" path="%s%s.png" id="2"]\n' % (icon_res, iid)
    out += '[resource]\nscript = ExtResource("1")\nid = "%s"\nname = "%s"\ndescription = "%s"\n' % (iid, name, story.replace('"', '\\"'))
    out += 'icon = ExtResource("2")\n' if has else 'icon_generator = "forest"\n'
    out += 'max_stack = 1\nrarity = "%s"\n' % rarity
    return out + extra


def write():
    n = 0
    for iid, (name, rarity, dmg, cls, story, _, _, _) in WEAPONS.items():
        text = _tres(iid, name, "%s %d damage%s." % (story, dmg, ", smashing" if cls == "smash" else ""), ITEM_ICONS,
                     "res://Forest/art/items/", rarity, 'tool_type = "sword"\ndamage = %d\nweapon_class = "%s"\n' % (dmg, cls))
        open(os.path.join(DATA, iid + ".tres"), "w", encoding="utf-8", newline="\n").write(text)
        n += 1
    for sid, (set_name, pieces, _, _, set_text) in ARMOUR.items():
        for slot, name, defence, _ in pieces:
            iid = "%s_%s" % (sid, slot)
            story = "%s. %s set: %s." % (_story(sid, slot), set_name, set_text)
            text = _tres(iid, name, story, WARDROBE, "res://Forest/equipment/art/wardrobe/icons/", "epic" if sid != "obsidian" else "legendary",
                         'armor_slot = "%s"\ndefense = %d\n' % (SLOT[slot], defence))
            open(os.path.join(DATA, iid + ".tres"), "w", encoding="utf-8", newline="\n").write(text)
            n += 1
    print("wrote %d items" % n)


def _story(sid, slot):
    return {
        ("thyla", "helmet"): "A hood of striped thylacoleo pelt, its ears still on",
        ("thyla", "chestplate"): "Striped pelt with a thick fur collar and claws at the cuffs",
        ("thyla", "leggings"): "Pelt wrapped close with jungle vine: not a sound in the leaves",
        ("sky", "helmet"): "A light helm swept back into a pteranodon's crest",
        ("sky", "chestplate"): "Grey wing leather over the shoulders, stitched with dimorph teeth",
        ("sky", "leggings"): "Wing leather, light as nothing",
        ("obsidian", "helmet"): "Black volcanic glass, ember in its seams",
        ("obsidian", "chestplate"): "Plates of obsidian over emberstone, warm to the touch",
        ("obsidian", "leggings"): "Obsidian greaves lined with Ashmane fur",
    }[(sid, slot)]


def recipes():
    rows = []
    for iid, (name, _, dmg, cls, story, ing, station, hidden) in WEAPONS.items():
        row = {"name": name, "item_id": iid, "ingredients": ing, "station": station, "category": "Tools",
               "description": "%d damage%s. %s" % (dmg, ", smashing" if cls == "smash" else "", story)}
        if hidden:
            row["hidden_until"] = hidden
        rows.append(row)
    for sid, (set_name, pieces, station, hidden, set_text) in ARMOUR.items():
        for slot, name, defence, ing in pieces:
            row = {"name": name, "item_id": "%s_%s" % (sid, slot), "ingredients": ing, "station": station, "category": "Armor",
                   "description": "Defence %d. %s set: %s." % (defence, set_name, set_text)}
            if hidden:
                row["hidden_until"] = hidden
            rows.append(row)
    return "\n".join("\t" + json.dumps(r, separators=(", ", ":")) + "," for r in rows)


if __name__ == "__main__":
    if "--recipes" in sys.argv:
        print(recipes())
    else:
        write()
