"""Pass 15: the larder. Crops for every land, a cut of meat for every size of
beast, a fish for every water, and a cooking pot with its recipes. One table.

    python tools/items/foods.py                 # write the .tres files and game/Forest/life/FoodData.gd
    python tools/items/foods.py --art strips    # draw the crops' growth strips (PixelLab, 1 generation each)
    python tools/items/foods.py --art icons     # draw the item icons (PixelLab, 1 generation each)
    python tools/items/foods.py --split         # cut the strips into game/Forest/art/crops/<crop>.png
    python tools/items/foods.py --art icons ID [ID ...] [--force]

Hank (pass 15): "crops for each biome... certain dinosaurs prefer certain crops
and certain foods for better taming... foods that give bonuses, similar to Core
Keeper, and the ability to make those foods with a cooking pot and specific
recipes... bronto meat should be different than trike and stego meat, which
will be the same, and dodo meat would be less than that... the fish should be
specific to each biome too, and better designs."

The game reads what this writes:
  game/Items/Data/<id>.tres          each new item (icon once the PNG exists: run again after --art icons)
  game/Forest/life/FoodData.gd       crops, fish, meat, favourites, ingredient groups and recipes
  game/Forest/art/crops/<crop>.png   four growth stages side by side (Gardening draws them)
  game/Forest/art/items/<id>.png     new items' icons
  game/Forest/art/v6/item-<id>.png   redrawn icons of old items (ItemDB prefers v6)
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DATA = os.path.join(ROOT, "game", "Items", "Data")
ICON_DIR = os.path.join(ROOT, "game", "Forest", "art", "items")
V6 = os.path.join(ROOT, "game", "Forest", "art", "v6")
CROP_DIR = os.path.join(ROOT, "game", "Forest", "art", "crops")
STRIPS = os.path.join(ROOT, "art", "food", "strips")
PALETTE = os.path.join(ROOT, "art", "food", "palette.png")
FOOD_GD = os.path.join(ROOT, "game", "Forest", "life", "FoodData.gd")

# --- Crops ---------------------------------------------------------------------------------
# crop: seed item, yield item, how many a harvest, seconds to ripen, the land it
# grows best in (a quarter faster there), strip prompt.
# A harvest also gives the seed back (Gardening), so a crop whose seed is its own
# yield (a tuber, a grain) gives yield + 1.
CROPS = {
    "berry": ("berry_seed", "berry", 3, 90.0, "forest",
              "a tiny two-leaf seedling, a small leafy sprout, a bushy green plant with white flowers, a full bush heavy with round red berries"),
    "mushroom": ("mushroom_spore", "mushroom", 3, 120.0, "glassmere",
                 "tiny pale pinhead mushroom buttons, small buttons with lilac caps, a cluster of young lilac-capped mushrooms, a big cluster of ripe violet-capped mushrooms with cream stems"),
    "tuber": ("wild_tuber", "wild_tuber", 3, 110.0, "forest",
              "a tiny green sprout, a small leafy potato-like plant, a bushy leafy plant with small purple flowers, a leafy plant with plump red-brown tubers pushing out of the soil"),
    "redgrain": ("redgrain", "redgrain", 3, 120.0, "forest",
                 "a tiny green shoot, a small clump of grass blades, a tall clump of green stalks with young heads, tall stalks bowed under ripe crimson-red grain heads like wheat"),
    "lotus": ("mirelotus", "mirelotus", 3, 150.0, "glassmere",
              "a tiny curled green leaf, two round lily leaves, round lily leaves around a closed pink bud, round lily leaves around an open pink lotus flower with a pale root showing"),
    "melon": ("melon_seed", "sun_melon", 1, 180.0, "dunes",
              "a tiny sprout, a small vine with a few leaves, a spreading vine with yellow flowers, a vine with one big ripe golden-orange striped melon"),
    "cactus": ("cactus_fruit", "cactus_fruit", 3, 150.0, "dunes",
               "a tiny green cactus nub, a small round cactus, a paddle cactus with a pink bud, a paddle cactus crowned with ripe magenta fruit"),
    "pepper": ("ember_pepper", "ember_pepper", 3, 160.0, "pale_hills",
               "a tiny sprout, a small leafy plant, a bushy plant with white flowers and small green peppers, a bushy plant hung with glowing ember-red chili peppers"),
    "gourd": ("gourd_seed", "marrow_gourd", 1, 180.0, "bonelands",
              "a tiny sprout, a small vine with broad leaves, a vine with yellow flowers, a vine with one big pale bone-white ribbed gourd"),
}
STRIP_PROMPT = ("sprite sheet of four growth stages of one %s crop in a row, evenly spaced, left to right: %s; "
                "each stands on its own small patch of dark soil, garden crop for a farming game")
# Strips redrawn without the soil (the model's pale patches read as plates on a tilled bed).
BARE = {"melon"}
# Strips whose soil patch is a paler sand than its bottom rows: match its colours loosely.
LOOSE_SOIL = {"redgrain"}
BARE_PROMPT = ("sprite sheet of four growth stages of one %s crop in a row, evenly spaced, left to right: %s; "
               "each plant alone growing straight up out of the ground, no soil patch, no pot, no plate, garden crop for a farming game")
CROP_NAMES = {"berry": "berry bush", "mushroom": "mushroom patch", "tuber": "root vegetable", "redgrain": "red grain",
              "lotus": "marsh lotus", "melon": "melon", "cactus": "small cactus", "pepper": "hot pepper", "gourd": "gourd"}

# The wild plants a crop's first seeds come from: prop kind -> [crop (its ripe stage is the art), land, drops, extra drop].
WILD_CROPS = {
    "wild_grain": ["redgrain", "forest", ["redgrain", 2], []],
    "wild_lotus": ["lotus", "glassmere", ["mirelotus", 2], []],
    "wild_melon": ["melon", "dunes", ["sun_melon", 1], ["melon_seed", 2]],
    "wild_pepper": ["pepper", "pale_hills", ["ember_pepper", 2], []],
    "wild_gourd": ["gourd", "bonelands", ["marrow_gourd", 1], ["gourd_seed", 2]],
}

# --- Items -----------------------------------------------------------------------------------
# id: dict(name, stack, story, icon prompt[, food: [hunger, fullness s, vitality, over s]]
#          [, effects {...}, buff: seconds][, redraw: True (an old item's new icon)])
P = "game item icon"
ITEMS = {
    # Produce and seeds.
    "redgrain": dict(name="Redgrain", stack=40, story="A crimson grain from the red meadows. Sow it, or bake it.",
                     icon="a small bundle of crimson-red grain stalks tied with twine, " + P, crop="redgrain"),
    "mirelotus": dict(name="Mire Lotus", stack=30, story="A knobbly lotus root from the Mirefen. Plant a piece and it grows again.",
                      icon="a pale knobbly lotus root with a pink lotus petal on it, " + P, food=[15, 30, 4, 8], crop="lotus"),
    "sun_melon": dict(name="Sun Melon", stack=10, story="Heavy, golden and sweet. The dunes' trikes crack them open with their beaks.",
                      icon="a round golden-orange striped melon, " + P, food=[35, 60, 10, 15], crop="melon"),
    "melon_seed": dict(name="Melon Seeds", stack=30, story="Flat cream seeds. Sow them on tilled soil.",
                       icon="a small cloth pouch spilling flat cream melon seeds, " + P, crop="melon"),
    "ember_pepper": dict(name="Ember Pepper", stack=30, story="A chili that glows like a coal. Too hot to eat alone; plant it or cook with it.",
                         icon="a glowing ember-red chili pepper with a green stem, " + P, crop="pepper"),
    "marrow_gourd": dict(name="Marrow Gourd", stack=10, story="A pale, ribbed gourd that grows among the Bonelands' bones.",
                         icon="a pale bone-white ribbed gourd with a curled green stem, " + P, crop="gourd"),
    "gourd_seed": dict(name="Gourd Seeds", stack=30, story="Pale seeds from a marrow gourd. Sow them on tilled soil.",
                       icon="a small cloth pouch spilling pale gourd seeds, " + P, crop="gourd"),
    # Meat, by the size of the beast.
    "morsel": dict(name="Small Meat", stack=30, story="A little meat from a little beast. Roast it at a campfire.",
                   icon="a small scrap of raw red meat, " + P),
    "haunch": dict(name="Heavy Haunch", stack=20, story="A thick cut from a horned or plated herbivore. Roast it at a campfire.",
                   icon="a thick raw meat haunch on a bone, dark red with a white fat rim, " + P),
    "titan_rib": dict(name="Titan Rib", stack=10, story="One rib of a longneck, and a feast on it. Roast it at a campfire.",
                      icon="a huge raw rib of red meat on a long curved bone, " + P),
    "prime_meat": dict(name="Prime Cut", stack=20, story="Marbled meat from a great hunter. Predators prize it above all else.",
                       icon="a marbled raw prime steak, deep red with white marbling, " + P),
    "seared_morsel": dict(name="Seared Morsel", stack=30, story="A bite of meat, seared on a stick.",
                          icon="a small chunk of seared grilled meat on a wooden skewer, " + P, food=[30, 60, 8, 10]),
    "haunch_roast": dict(name="Haunch Roast", stack=20, story="Slow-roasted haunch. It sits heavy and keeps you steady.",
                         icon="a roasted meat haunch on a bone with golden-brown crackling, " + P, food=[100, 240, 40, 30],
                         effects={"defense": 3}, buff=180),
    "titan_roast": dict(name="Titan Rib Roast", stack=10, story="A longneck's rib, roasted whole. It carries you for hours.",
                        icon="a huge roasted rib of meat on a curved bone, glazed and browned, " + P, food=[100, 360, 60, 40],
                        effects={"vigor": 20}, buff=300),
    "prime_steak": dict(name="Prime Steak", stack=20, story="A hunter's cut, seared hot. Your blows land heavier.",
                        icon="a grilled prime steak with dark char lines and a sprig of herbs, " + P, food=[100, 300, 50, 30],
                        effects={"melee": 0.1}, buff=180),
    # The cooking pot's dishes (Core Keeper's meals: every one a buff).
    "redgrain_loaf": dict(name="Redgrain Loaf", stack=20, story="Dense red bread that keeps you full for a long walk.",
                          icon="a round rustic loaf of bread with a reddish crust scored on top, " + P, food=[45, 240, 10, 20],
                          effects={"hunger": 0.25}, buff=360),
    "tuber_mash": dict(name="Tuber Mash", stack=20, story="Mashed tubers and mushroom. Wounds close while you're fed.",
                       icon="a wooden bowl of creamy mashed tubers with a mushroom slice on top, " + P, food=[55, 180, 15, 20],
                       effects={"regen": 0.5}, buff=240),
    "mushroom_stew": dict(name="Mushroom Stew", stack=20, story="A thick violet stew. You feel sturdier for it.",
                          icon="a wooden bowl of hearty stew with violet mushroom pieces, " + P, food=[60, 200, 20, 20],
                          effects={"vigor": 15}, buff=300),
    "lotus_broth": dict(name="Lotus Broth", stack=20, story="Clear broth with lotus and fish. Water parts before you, and fish bite.",
                        icon="a clay bowl of clear broth with a pink lotus flower and pieces of fish, " + P, food=[60, 200, 20, 20],
                        effects={"wading": 0.4, "fishing": 0.25}, buff=300),
    "melon_cooler": dict(name="Melon Cooler", stack=20, story="A hollowed melon full of berries. Light feet.",
                         icon="a hollowed golden melon half filled with red berries and juice, " + P, food=[50, 150, 12, 15],
                         effects={"speed": 0.08}, buff=240),
    "ember_chili": dict(name="Ember Chili", stack=20, story="Meat stewed with ember peppers. It burns going down, and warms you through.",
                        icon="a clay bowl of red chili stew with meat chunks and ember-red peppers, " + P, food=[80, 240, 25, 25],
                        effects={"melee": 0.1, "cold": 1}, buff=300),
    "gourd_porridge": dict(name="Gourd Porridge", stack=20, story="Sweet gourd and red grain. It settles like armour.",
                           icon="a wooden bowl of pale orange gourd porridge sprinkled with red grains, " + P, food=[70, 300, 20, 25],
                           effects={"defense": 5}, buff=300),
    "hunters_stew": dict(name="Hunter's Stew", stack=20, story="A haunch stewed with roots and mushrooms. Food for a hunt.",
                         icon="a black iron pot of thick meat stew with tuber and mushroom chunks, " + P, food=[100, 300, 35, 30],
                         effects={"damage": 3, "crit": 0.05}, buff=300),
    "titan_pot_roast": dict(name="Titan Pot Roast", stack=10, story="A longneck rib with lotus and tubers. A feast that makes you hard to fell.",
                            icon="a big platter with a glazed rib roast, lotus root and tubers, " + P, food=[100, 420, 60, 40],
                            effects={"vigor": 40, "regen": 0.5}, buff=360),
    "pepper_steak": dict(name="Pepper Steak", stack=20, story="A prime cut under ember peppers. Every blow a hunter's.",
                         icon="a grilled steak topped with sliced red chili peppers on a wooden board, " + P, food=[100, 360, 50, 30],
                         effects={"melee": 0.15, "crit": 0.08}, buff=300),
    "fishers_chowder": dict(name="Fisher's Chowder", stack=20, story="Creamy fish and roots. Lucky water.",
                            icon="a wooden bowl of creamy fish chowder with tuber chunks, " + P, food=[75, 240, 25, 25],
                            effects={"fishing": 0.4, "luck": 0.1}, buff=300),
    "cactus_jelly": dict(name="Cactus Jelly", stack=20, story="Sticky, bright and quick. You slip out of harm's way.",
                         icon="a small glass jar of magenta cactus fruit jelly, " + P, food=[40, 150, 12, 15],
                         effects={"dodge": 0.3, "speed": 0.05}, buff=240),
    "foragers_salad": dict(name="Forager's Salad", stack=20, story="Berries, mushroom and lotus petals. You find more of everything.",
                           icon="a wooden bowl of fresh leafy salad with red berries, mushrooms and pink petals, " + P, food=[45, 180, 15, 20],
                           effects={"harvest": 0.25, "gather": 1}, buff=300),
    "miners_pie": dict(name="Miner's Pie", stack=20, story="Meat and red grain in a crust. Stone gives way.",
                       icon="a golden meat pie with a crimped crust, " + P, food=[70, 240, 20, 25],
                       effects={"gather": 1, "light": 0.5}, buff=300),
    # Treats for taming (a favourite of every beast of that diet).
    "beast_treat": dict(name="Beast Treat", stack=20, story="Melon, grain and berries in a leaf. Every plant-eater's favourite.",
                        icon="a loose bundle of broad fresh green leaves folded around chunks of orange melon, red berries and red grain, tied with a twine knot, animal feed, " + P),
    "bloody_bait": dict(name="Bloody Bait", stack=20, story="Meat scraps bound in twine. Every hunter's favourite.",
                        icon="a bloody bundle of raw red meat scraps bound with twine, " + P),
    # Fish of every water.
    "mire_eel": dict(name="Mire Eel", stack=20, story="A slick eel of the Mirefen's black water. The fishers' favourite.",
                     icon="a long slimy dark olive eel with a yellow belly curled in an S, side view, " + P, fish=True),
    "fen_pike": dict(name="Fen Pike", stack=20, story="A mottled pike with a mouthful of needles.",
                     icon="a mottled green swamp pike fish with a long toothy snout, side view, " + P, fish=True),
    "oasis_carp": dict(name="Oasis Carp", stack=20, story="A fat golden carp from a desert spring.",
                       icon="a plump golden carp fish with orange fins, side view, " + P, fish=True),
    "sunfin": dict(name="Sunfin", stack=20, story="A darting oasis fish with a sail like a sunset.",
                   icon="a slender fish with a tall sunset-orange sail fin on its back, side view, " + P, fish=True),
    "ash_char": dict(name="Ash Char", stack=20, story="A grey char spotted like embers, from the Pale Lands' cold pools.",
                     icon="a grey-silver char fish with ember-orange spots, side view, " + P, fish=True),
    "frostjaw": dict(name="Frostjaw", stack=20, story="An icy fish with a jaw like a trap.",
                     icon="an icy blue-white fish with a big underbite jaw and frosty scales, side view, " + P, fish=True),
    "rust_catfish": dict(name="Rust Catfish", stack=20, story="A whiskered catfish the colour of the Bonelands' rock.",
                         icon="a rust-red whiskered catfish, side view, " + P, fish=True),
    "bonegill": dict(name="Bonegill", stack=20, story="A pale fish striped like a ribcage, with blood-red gills.",
                     icon="a pale bony fish with rib-like dark stripes and red gills, side view, " + P, fish=True),
    # The old fish, drawn anew.
    "reed_perch": dict(redraw=True, icon="a green and gold striped river perch fish with a spiny dorsal fin, side view, " + P),
    "shardfin": dict(redraw=True, icon="a jade green fish with sharp translucent crystal shard fins, side view, " + P),
    "moonscale": dict(redraw=True, icon="a silvery pale blue fish with shimmering moon-white scales and a crescent tail, side view, " + P),
    "cooked_fish": dict(redraw=True, icon="a grilled whole fish with char lines on a wooden skewer, " + P),
    # The cooking pot.
    "cooking_pot": dict(name="Cooking Pot", stack=5, story="An iron pot on a ring of stones. Stand by it to cook the finer dishes.",
                        icon="a black iron cooking pot with stew, sitting on a ring of stones over a small fire, " + P, placeable=True),
}
# The cooking pot's own world sprite (ForestProp ART "cooking_pot").
POT_PROP = ("a black iron cauldron of bubbling stew on a ring of grey stones over a small campfire, top-down game prop", 32, 32)

# --- Recipes ------------------------------------------------------------------------------
# [item, {ingredients}, station, quantity]. "any:fish"/"any:meat" take the
# commonest of the group first (GROUPS order).
RECIPES = [
    ["cooking_pot", {"stone": 10, "plank": 3, "plant_fiber": 2}, "workbench", 1],
    # A campfire roasts a cut whole.
    ["seared_morsel", {"morsel": 1}, "campfire", 1],
    ["haunch_roast", {"haunch": 1}, "campfire", 1],
    ["titan_roast", {"titan_rib": 1}, "campfire", 1],
    ["prime_steak", {"prime_meat": 1}, "campfire", 1],
    # The cooking pot's dishes.
    ["redgrain_loaf", {"redgrain": 3}, "cooking_pot", 1],
    ["tuber_mash", {"wild_tuber": 2, "mushroom": 1}, "cooking_pot", 1],
    ["mushroom_stew", {"mushroom": 3, "wild_tuber": 1}, "cooking_pot", 1],
    ["lotus_broth", {"mirelotus": 2, "any:fish": 1}, "cooking_pot", 1],
    ["melon_cooler", {"sun_melon": 1, "berry": 2}, "cooking_pot", 1],
    ["ember_chili", {"ember_pepper": 2, "any:meat": 1}, "cooking_pot", 1],
    ["gourd_porridge", {"marrow_gourd": 1, "redgrain": 2}, "cooking_pot", 1],
    ["hunters_stew", {"haunch": 1, "wild_tuber": 1, "mushroom": 1}, "cooking_pot", 1],
    ["titan_pot_roast", {"titan_rib": 1, "mirelotus": 1, "wild_tuber": 1}, "cooking_pot", 1],
    ["pepper_steak", {"prime_meat": 1, "ember_pepper": 1}, "cooking_pot", 1],
    ["fishers_chowder", {"any:fish": 2, "wild_tuber": 1}, "cooking_pot", 1],
    ["cactus_jelly", {"cactus_fruit": 3, "berry": 1}, "cooking_pot", 1],
    ["foragers_salad", {"berry": 2, "mushroom": 1, "mirelotus": 1}, "cooking_pot", 1],
    ["miners_pie", {"redgrain": 2, "morsel": 2}, "cooking_pot", 1],
    ["beast_treat", {"sun_melon": 1, "redgrain": 2, "berry": 2}, "cooking_pot", 2],
    ["bloody_bait", {"prime_meat": 1, "morsel": 2}, "cooking_pot", 2],
]
# Ingredient groups, commonest first (a recipe takes from the front).
GROUPS = {
    "fish": ["reed_perch", "oasis_carp", "rust_catfish", "mire_eel", "ash_char", "fen_pike", "sunfin", "bonegill", "frostjaw", "shardfin", "moonscale"],
    "meat": ["morsel", "trex_meat", "haunch", "titan_rib", "prime_meat"],
}
GROUP_NAMES = {"fish": "Any fish", "meat": "Any raw meat"}

# --- Beasts ---------------------------------------------------------------------------------
# What each beast's carcass gives: species -> [meat, count] (babies: a morsel).
MEAT = {
    "dodo": ["morsel", 1], "lystro": ["morsel", 2], "compy": ["morsel", 1], "proto": ["morsel", 2],
    "raptor": ["trex_meat", 2], "deino": ["trex_meat", 2], "utah": ["trex_meat", 3], "dimetrodon": ["trex_meat", 3], "parasaur": ["trex_meat", 3],
    "trike": ["haunch", 3], "stego": ["haunch", 3], "anky": ["haunch", 4],
    "longneck": ["titan_rib", 3],
    "allo": ["prime_meat", 2], "carno": ["prime_meat", 3], "yuty": ["prime_meat", 3], "rex": ["prime_meat", 5],
    "sucho": ["prime_meat", 2], "spino": ["prime_meat", 4], "alpha": ["prime_meat", 4],
}
# A beast eats from its diet: "plants", "meat" or "fish" (ForestCreature's
# stats.food says which). Any food of its diet wins a little trust; a favourite
# wins twice as much.
DIETS = {
    "plants": ["berry", "mushroom", "wild_tuber", "redgrain", "mirelotus", "sun_melon", "cactus_fruit", "marrow_gourd", "beast_treat"],
    "meat": ["trex_meat", "morsel", "haunch", "titan_rib", "prime_meat", "bloody_bait"],
    "fish": GROUPS["fish"],
}
FAVOURITES = {
    "dodo": ["redgrain"], "lystro": ["wild_tuber"], "parasaur": ["mirelotus"], "longneck": ["mirelotus"],
    "stego": ["marrow_gourd"], "anky": ["marrow_gourd"], "trike": ["sun_melon"], "proto": ["cactus_fruit"],
    "compy": ["morsel"], "raptor": ["prime_meat"], "deino": ["prime_meat"], "utah": ["prime_meat"], "dimetrodon": ["prime_meat"],
    "allo": ["prime_meat"], "carno": ["prime_meat"], "yuty": ["prime_meat"], "rex": ["prime_meat"],
    "sucho": ["mire_eel"], "spino": ["mire_eel", "fen_pike"],
}
# Too small a bite for a big hunter.
SCORNS = {"morsel": ["allo", "carno", "yuty", "rex", "utah", "spino", "sucho", "dimetrodon"]}

# --- Fish -----------------------------------------------------------------------------------
# How each temper fights on the line (FishingPanel).
TEMPER = {
    "Gentle": {"speed": 0.85, "range": 0.22, "dart": 0.025, "cradle": 0.18, "gain": 0.19, "loss": 0.105},
    "Restless": {"speed": 1.25, "range": 0.27, "dart": 0.06, "cradle": 0.145, "gain": 0.17, "loss": 0.13},
    "Wild": {"speed": 1.7, "range": 0.31, "dart": 0.095, "cradle": 0.12, "gain": 0.16, "loss": 0.145},
    "Fierce": {"speed": 2.0, "range": 0.33, "dart": 0.11, "cradle": 0.11, "gain": 0.15, "loss": 0.155},
}
FISH = {
    "reed_perch": ("Reed Perch", "Gentle"), "shardfin": ("Jade Shardfin", "Restless"), "moonscale": ("Moonscale", "Wild"),
    "mire_eel": ("Mire Eel", "Restless"), "fen_pike": ("Fen Pike", "Wild"),
    "oasis_carp": ("Oasis Carp", "Gentle"), "sunfin": ("Sunfin", "Restless"),
    "ash_char": ("Ash Char", "Restless"), "frostjaw": ("Frostjaw", "Fierce"),
    "rust_catfish": ("Rust Catfish", "Gentle"), "bonegill": ("Bonegill", "Fierce"),
}
# Each land's waters (a hole's fish is one of these), and how many holes it gets.
WATERS = {
    "forest": [["reed_perch", "reed_perch", "shardfin", "moonscale"], 8],
    "glassmere": [["mire_eel", "reed_perch", "fen_pike", "mire_eel", "shardfin"], 8],
    "dunes": [["oasis_carp", "oasis_carp", "sunfin"], 5],
    "pale_hills": [["ash_char", "ash_char", "frostjaw"], 5],
    "bonelands": [["rust_catfish", "rust_catfish", "bonegill"], 5],
}


# --- Writing --------------------------------------------------------------------------------
def tres(iid):
    it = ITEMS[iid]
    icon = os.path.join(ICON_DIR, iid + ".png")
    has_icon = os.path.exists(icon)
    head = '[gd_resource type="Resource" script_class="Item" load_steps=%d format=3]\n' % (3 if has_icon else 2)
    head += '[ext_resource type="Script" path="res://Items/Item.gd" id="1"]\n'
    if has_icon:
        head += '[ext_resource type="Texture2D" path="res://Forest/art/items/%s.png" id="2"]\n' % iid
    body = '[resource]\nscript = ExtResource("1")\nid = "%s"\nname = "%s"\ndescription = "%s"\n' % (iid, it["name"], it["story"].replace('"', '\\"'))
    body += 'icon = ExtResource("2")\n' if has_icon else 'icon_generator = "forest"\n'
    body += 'max_stack = %d\n' % it["stack"]
    if it.get("placeable"):
        body += 'placeable = true\n'
    if "food" in it:
        hunger, full, vit, over = it["food"]
        body += 'consumable = true\nhunger_value = %d\nfood_satiation_seconds = %s\n' % (hunger, float(full))
        if vit:
            body += 'healing_total = %s\nhealing_duration = %s\n' % (float(vit), float(over))
    if it.get("effects"):
        body += "effects = {\n" + ",\n".join('"%s": %s' % (k, json.dumps(v)) for k, v in it["effects"].items()) + "\n}\n"
        body += 'buff_seconds = %s\n' % float(it["buff"])
    return head + body


def gd_value(v):
    return json.dumps(v)


def food_gd():
    crops = {}
    for crop, (seed, yld, count, secs, home, _) in CROPS.items():
        crops[seed] = {"crop": crop, "yield": yld, "count": count, "seconds": secs, "home": home}
    recipes = []
    for item, ing, station, qty in RECIPES:
        it = ITEMS[item]
        recipes.append({"name": it["name"], "item_id": item, "ingredients": ing, "station": station,
                        "category": "Building" if item == "cooking_pot" else "Food", "quantity": qty, "description": it["story"]})
    fish = {}
    for fid, (name, temper) in FISH.items():
        row = {"id": fid, "name": name, "difficulty": temper}
        row.update(TEMPER[temper])
        fish[fid] = row
    out = [
        "extends RefCounted",
        "## Written by tools/items/foods.py (edit the tables there, then run it).",
        "## Pass 15: the larder: crops for every land, meat for every size of beast, fish",
        "## for every water, the cooking pot's recipes and the beasts' favourite foods.",
        "",
        "## Seed item -> {crop (its art: Forest/art/crops/<crop>.png), yield, count, seconds, home land}.",
        "const CROPS := %s" % gd_value(crops),
        "## The wild plants a crop's first seeds come from: prop kind -> [crop, land, drop, extra drop].",
        "const WILD_CROPS := %s" % gd_value(WILD_CROPS),
        "## Recipes CraftingManager adds to its own (\"any:fish\": the commonest fish first).",
        "const RECIPES := %s" % gd_value(recipes),
        "## Ingredient groups, commonest first.",
        "const GROUPS := %s" % gd_value(GROUPS),
        "const GROUP_NAMES := %s" % gd_value(GROUP_NAMES),
        "## species -> [meat, count] (a baby gives a morsel).",
        "const MEAT := %s" % gd_value(MEAT),
        "## What each diet eats; a beast's favourites win twice the trust.",
        "const DIETS := %s" % gd_value(DIETS),
        "const FAVOURITES := %s" % gd_value(FAVOURITES),
        "const SCORNS := %s" % gd_value(SCORNS),
        "## Fish: id -> how it fights on the line (FishingPanel).",
        "const FISH := %s" % gd_value(fish),
        "## The same, as a list (a fishing hole keeps its fish's index; the first three are the forest's own).",
        "const FISH_LIST := %s" % gd_value(list(fish.values())),
        "## Each land's waters: [its fish (a hole's is one of these), holes].",
        "const WATERS := %s" % gd_value(WATERS),
        "",
    ]
    return "\n".join(out)


def write_data():
    count = 0
    for iid, it in ITEMS.items():
        if it.get("redraw"):
            continue
        open(os.path.join(DATA, iid + ".tres"), "w", encoding="utf-8", newline="\n").write(tres(iid))
        count += 1
    open(FOOD_GD, "w", encoding="utf-8", newline="\n").write(food_gd())
    print("wrote %d items and %s" % (count, os.path.relpath(FOOD_GD, ROOT)))


# --- Art ------------------------------------------------------------------------------------
def palette():
    """One palette for the larder: the forest's props, the old item art and fish."""
    if os.path.exists(PALETTE):
        return PALETTE
    from PIL import Image
    srcs = ["game/WorldObjects/Images/Objects.png", "game/Forest/art/v2/items.png",
            "game/Forest/art/fishing/reed_perch.png", "game/Forest/art/fishing/shardfin.png", "game/Forest/art/fishing/moonscale.png",
            "game/Forest/art/v2/item-trex_meat.png", "game/Forest/art/v2/item-cooked_meat.png", "game/Forest/art/v5/item-cooked_fish.png"]
    ims = [Image.open(os.path.join(ROOT, s)).convert("RGBA") for s in srcs]
    w = max(i.width for i in ims)
    sheet = Image.new("RGBA", (w, sum(i.height for i in ims)))
    y = 0
    for i in ims:
        sheet.paste(i, (0, y))
        y += i.height
    os.makedirs(os.path.dirname(PALETTE), exist_ok=True)
    sheet.save(PALETTE)
    return PALETTE


def _pixflux(call, out):
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    sys.path.insert(0, os.path.join(ROOT, "tools", "dino"))
    import pixellab_mcp as pl
    from new_species import job_id
    client = pl.Client()
    for attempt in range(120):
        text = pl.text_of(client.call("create_image_pixflux", pl.inline_files(call)))
        if "rate limit" not in text:
            break
        time.sleep(20)
    job = job_id(text)
    tmp = tempfile.mkdtemp(prefix="food_")
    pl.cmd_wait(job, tmp)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    shutil.move(os.path.join(tmp, "000.png"), out)
    shutil.rmtree(tmp, ignore_errors=True)
    print("drew", os.path.relpath(out, ROOT), flush=True)


def draw_strip(crop):
    call = {"description": (BARE_PROMPT if crop in BARE else STRIP_PROMPT) % (CROP_NAMES[crop], CROPS[crop][5]), "width": 96, "height": 24,
            "no_background": True, "view": "low top-down", "outline": "selective outline", "shading": "medium shading",
            "detail": "highly detailed", "color_image_base64": "@" + os.path.join(ROOT, "game/WorldObjects/Images/Objects.png")}
    _pixflux(call, os.path.join(STRIPS, crop + ".png"))


def icon_out(iid):
    return os.path.join(V6, "item-" + iid + ".png") if ITEMS[iid].get("redraw") else os.path.join(ICON_DIR, iid + ".png")


def draw_icon(iid):
    it = ITEMS[iid]
    colours = palette()
    if it.get("crop") and os.path.exists(os.path.join(STRIPS, it["crop"] + ".png")):
        colours = os.path.join(STRIPS, it["crop"] + ".png")
    call = {"description": it["icon"], "width": 32, "height": 32, "no_background": True, "view": "side",
            "outline": "single color black outline", "shading": "medium shading", "detail": "highly detailed",
            "color_image_base64": "@" + colours}
    _pixflux(call, icon_out(iid))


def draw_pot_prop():
    desc, w, h = POT_PROP
    call = {"description": desc, "width": w, "height": h, "no_background": True, "view": "low top-down",
            "outline": "selective outline", "shading": "medium shading", "detail": "highly detailed",
            "color_image_base64": "@" + palette()}
    _pixflux(call, os.path.join(ROOT, "game", "Forest", "art", "crops", "cooking_pot.png"))


def unsoil(frame, loose=False):
    """The model stands each plant on a little patch of soil of its own; on a
    tilled bed that reads as a plate. The patch's colours are the ones in its
    bottom two rows: rows from the bottom up that are mostly those colours go,
    keeping whatever else is in them (a stem, a tuber)."""
    px = frame.load()
    w, h = frame.size
    soil = set()
    for y in range(max(0, h - 2), h):
        for x in range(w):
            if px[x, y][3] > 24:
                soil.add(px[x, y][:3])
    import colorsys

    def hsv(c):
        return colorsys.rgb_to_hsv(c[0] / 255, c[1] / 255, c[2] / 255)
    tones = [hsv(c) for c in soil]

    def is_soil(c):
        if c[:3] in soil:
            return True
        if not loose:
            return False
        hh, ss, vv = hsv(c)
        return any(abs(hh - t[0]) < 0.05 and abs(ss - t[1]) < 0.3 and abs(vv - t[2]) < 0.35 for t in tones)
    cut = h
    for y in range(h - 1, -1, -1):
        solid = [px[x, y] for x in range(w) if px[x, y][3] > 24]
        if not solid:
            cut = y
            continue
        share = sum(1 for c in solid if is_soil(c)) / len(solid)
        if share < 0.6 or h - y > 7:
            break
        cut = y
    out = frame.copy()
    op = out.load()
    for y in range(cut, h):
        for x in range(w):
            if px[x, y][3] > 24 and is_soil(px[x, y]):
                op[x, y] = (0, 0, 0, 0)
    return out


def split():
    """Each strip into four frames, bottom-aligned in equal cells:
    game/Forest/art/crops/<crop>.png (4 x FW by FH)."""
    from PIL import Image
    os.makedirs(CROP_DIR, exist_ok=True)
    for crop in CROPS:
        src = os.path.join(STRIPS, crop + ".png")
        if not os.path.exists(src):
            print("no strip for", crop)
            continue
        im = Image.open(src).convert("RGBA")
        a = im.getchannel("A").point(lambda v: 255 if v > 24 else 0)
        cols = [any(a.getpixel((x, y)) for y in range(im.height)) for x in range(im.width)]
        runs, x = [], 0
        while x < im.width:
            if cols[x]:
                s = x
                while x < im.width and cols[x]:
                    x += 1
                runs.append([s, x])
            else:
                x += 1
        # A stray speck, or a fifth plant the model drew: keep the four
        # biggest, left to right. Plants that touch are cut in quarters.
        def mass(r):
            return sum(1 for x in range(r[0], r[1]) for y in range(im.height) if a.getpixel((x, y)))
        if len(runs) > 4:
            keep = sorted(sorted(runs, key=mass, reverse=True)[:4])
            runs = keep
        if len(runs) < 4:
            q = im.width // 4
            runs = [[i * q, (i + 1) * q] for i in range(4)]
        frames = []
        for x0, x1 in runs:
            box = im.crop((x0, 0, x1, im.height))
            bb = box.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
            box = unsoil(box.crop(bb) if bb else box, crop in LOOSE_SOIL)
            bb = box.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox()
            frames.append(box.crop(bb) if bb else box)
        fw = max(f.width for f in frames)
        fh = max(f.height for f in frames)
        sheet = Image.new("RGBA", (fw * 4, fh))
        for i, f in enumerate(frames):
            sheet.alpha_composite(f, (i * fw + (fw - f.width) // 2, fh - f.height))
        sheet.save(os.path.join(CROP_DIR, crop + ".png"))
        print("crop", crop, "frames", [f.size for f in frames], "cell", (fw, fh))


def run_many(kind, ids, force):
    """A few at a time (PixelLab runs 8 jobs at once per account)."""
    running = []
    for i in ids:
        running.append(subprocess.Popen([sys.executable, __file__, "--one", kind, i] + (["--force"] if force else [])))
        if len(running) >= 6:
            running.pop(0).wait()
    for p in running:
        p.wait()


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    force = "--force" in sys.argv
    if "--one" in sys.argv:
        kind, iid = args[0], args[1]
        if kind == "strips":
            draw_strip(iid)
        elif kind == "pot":
            draw_pot_prop()
        else:
            draw_icon(iid)
        return
    if "--split" in sys.argv:
        split()
        return
    if "--art" in sys.argv:
        kind = args[0]
        if kind == "strips":
            todo = [c for c in (args[1:] or list(CROPS)) if force or not os.path.exists(os.path.join(STRIPS, c + ".png"))]
        elif kind == "pot":
            todo = ["pot"] if force or not os.path.exists(os.path.join(CROP_DIR, "cooking_pot.png")) else []
        else:
            todo = [i for i in (args[1:] or list(ITEMS)) if force or not os.path.exists(icon_out(i))]
        print("drawing", len(todo), kind, todo, flush=True)
        run_many(kind, todo, force)
        return
    write_data()


if __name__ == "__main__":
    main()
