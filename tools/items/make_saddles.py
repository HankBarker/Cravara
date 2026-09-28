"""Pass 18: a saddle for every beast a keeper can ride (creatures/Rides.gd),
their items, recipes' rows and three icons (PixelLab pixflux, 1 each: a
plant-eater's saddle, a hunter's war saddle, the pteranodon's flying saddle).

    python tools/items/make_saddles.py [--icons]
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
DATA = os.path.join(ROOT, "game", "Items", "Data")
ICONS = os.path.join(ROOT, "game", "Forest", "art", "items")
P = "game item icon"
ICON_ART = {
    "saddle_beast": "a sturdy brown leather riding saddle on a red woven blanket with brass buckles, " + P,
    "saddle_hunter": "a heavy dark leather war saddle studded with bone spikes on a dark red blanket, " + P,
    "saddle_sky": "a light tan leather flying saddle with long crossed straps and a small crest-shaped harness, " + P,
}
# species: (name, icon, story)
SADDLES = {
    "longneck": ("Longneck Saddle", "saddle_beast", "A broad saddle for a longneck's back. You'll see the whole world from up there."),
    "parasaur": ("Parasaur Saddle", "saddle_beast", "A light saddle for a parasaur: the quickest plant-eater there is."),
    "anky": ("Ankylosaur Saddle", "saddle_beast", "Strapped over the plates of an ankylosaur. Slow, and nothing gets through."),
    "dimetrodon": ("Dimetrodon Saddle", "saddle_hunter", "A saddle for a dimetrodon, set in front of its sail."),
    "raptor": ("Raptor Saddle", "saddle_hunter", "A small war saddle for a raptor. Hold on."),
    "deino": ("Deinonychus Saddle", "saddle_hunter", "A reed-runner's war saddle."),
    "utah": ("Utahraptor Saddle", "saddle_hunter", "A war saddle for the Sandblade. The fastest thing on two legs."),
    "thyla": ("Thylacoleo Saddle", "saddle_hunter", "A close-fitting saddle for a thylacoleo, with a grip for when it springs."),
    "allo": ("Allosaurus Saddle", "saddle_hunter", "A hunter's war saddle for an allosaur."),
    "carno": ("Carnotaurus Saddle", "saddle_hunter", "A war saddle for a charging carnotaur."),
    "yuty": ("Yutyrannus Saddle", "saddle_hunter", "A war saddle sewn to take the Ashmane's fur."),
    "rex": ("Tyrant Saddle", "saddle_hunter", "A war saddle for a tyrant. Everything runs."),
    "sucho": ("Suchomimus Saddle", "saddle_hunter", "A saddle for the reed-hunter of the Mirefen; it doesn't mind the water."),
    "spino": ("Spinosaur Saddle", "saddle_hunter", "A war saddle for the bog's king, set on its shoulders before the sail."),
    "ptera": ("Skyfisher Saddle", "saddle_sky", "A flying saddle for a pteranodon. Space to take off; over the jungle, E to rise into the treetops."),
}
HUNTER_BIG = ["allo", "carno", "yuty", "rex", "sucho", "spino"]


def recipe(sp):
    name, icon, story = SADDLES[sp]
    if sp == "ptera":
        ing = {"vine": 8, "plank": 4, "glimmer_shard": 2, "plant_fiber": 6}
        gate = ""
    elif icon == "saddle_beast":
        ing = {"plank": 8, "plant_fiber": 12, "crystal_shard": 3, "longneck_hide": 1}
        gate = ""
    elif sp in HUNTER_BIG:
        ing = {"grimjaw_hide": 2, "trex_scale": 2, "plank": 8, "plant_fiber": 12}
        gate = "grimjaw"
    else:
        ing = {"grimjaw_hide": 1, "raptor_hide": 3, "plank": 6, "plant_fiber": 10}
        gate = "grimjaw"
    row = '{"name":"%s", "item_id":"%s_saddle", "ingredients":%s, "station":"workbench", "category":"Armor", "description":"%s"%s},' % (
        name, sp, str(ing).replace("'", '"').replace(": ", ":"), "Fit to a bonded %s through its companion menu, then ride." % name.replace(" Saddle", "").lower(),
        (', "hidden_until":"%s"' % gate) if gate else "")
    return row


def tres(sp):
    name, icon, story = SADDLES[sp]
    has_icon = os.path.exists(os.path.join(ICONS, icon + ".png"))
    out = '[gd_resource type="Resource" script_class="Item" load_steps=%d format=3]\n' % (3 if has_icon else 2)
    out += '[ext_resource type="Script" path="res://Items/Item.gd" id="1"]\n'
    if has_icon:
        out += '[ext_resource type="Texture2D" path="res://Forest/art/items/%s.png" id="2"]\n' % icon
    out += '[resource]\nscript = ExtResource("1")\nid = "%s_saddle"\nname = "%s"\ndescription = "%s"\n' % (sp, name, story)
    out += 'icon = ExtResource("2")\n' if has_icon else 'icon_generator = "forest"\n'
    out += 'max_stack = 1\nrarity = "uncommon"\nequipment_slot = "saddle"\n'
    return out


def main():
    if "--icons" in sys.argv:
        import foods
        for icon, desc in ICON_ART.items():
            if os.path.exists(os.path.join(ICONS, icon + ".png")):
                continue
            foods._pixflux({"description": desc, "width": 32, "height": 32, "no_background": True, "view": "side",
                            "outline": "single color black outline", "shading": "medium shading", "detail": "highly detailed"},
                           os.path.join(ICONS, icon + ".png"))
    for sp in SADDLES:
        open(os.path.join(DATA, sp + "_saddle.tres"), "w", encoding="utf-8", newline="\n").write(tres(sp))
    # Grimjaw's hide (the bog's boss drops it; the hunters' saddles need it).
    path = os.path.join(DATA, "grimjaw_hide.tres")
    has_icon = os.path.exists(os.path.join(ICONS, "grimjaw_hide.png"))
    out = '[gd_resource type="Resource" script_class="Item" load_steps=%d format=3]\n' % (3 if has_icon else 2)
    out += '[ext_resource type="Script" path="res://Items/Item.gd" id="1"]\n'
    if has_icon:
        out += '[ext_resource type="Texture2D" path="res://Forest/art/items/grimjaw_hide.png" id="2"]\n'
    out += '[resource]\nscript = ExtResource("1")\nid = "grimjaw_hide"\nname = "Grimjaw\'s Hide"\ndescription = "A slab of the old croc\'s armoured hide. Tough enough to take a hunter\'s saddle."\n'
    out += 'icon = ExtResource("2")\n' if has_icon else 'icon_generator = "forest"\n'
    out += 'max_stack = 20\nrarity = "rare"\n'
    open(path, "w", encoding="utf-8", newline="\n").write(out)
    for sp in SADDLES:
        print("\t" + recipe(sp))


if __name__ == "__main__":
    main()
