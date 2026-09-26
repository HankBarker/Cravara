"""Pass 14: the trinkets (Terraria's accessories), authored in one table.

    python tools/items/trinkets.py            # write game/Items/Data/<id>.tres
    python tools/items/trinkets.py --recipes  # print the CraftingManager recipe rows

Each trinket: name, rarity, effects (Forest/items/Trinkets.gd reads them), a
line of its story, where it comes from (a beast's rare drop, a chest's find,
the workbench, or two trinkets tinkered into one), and its icon prompt with a
colour source for tools/keeper/make_icons.py (which reads ICONS from here).
A .tres points at its icon once the PNG exists (run again after the icons).
"""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
DATA = os.path.join(ROOT, "game", "Items", "Data")
ICON_DIR = os.path.join(ROOT, "game", "Forest", "art", "items")
C = "game/Forest/creatures/art/"

# id: (name, rarity, effects, story, source, icon prompt, colour source)
# source: ("beast", species, chance) | ("chest", kinds) | ("craft", {ingredients}) | ("tinker", [a, b], {extra})
TRINKETS = {
    # --- a beast's rare drop -------------------------------------------------------------
    "sickle_toe": ("Sickle Toe", "rare", {"crit": 0.05}, "A raptor's killing claw on a thong.",
                   ("beast", "raptor", 0.03), "a single sharp curved sickle-shaped claw hanging on a leather thong, no creature, game item icon", C + "raptor.png"),
    "frill_guard": ("Frill Guard", "rare", {"defense": 2, "steady": 0.25}, "A shard of triceratops frill shaped to strap on the forearm.",
                    ("beast", "trike", 0.05), "a curved orange and green shard of triceratops frill with leather arm straps, like a small bracer, no creature, game item icon", C + "trike.png"),
    "tail_spike": ("Thagomizer Spike", "rare", {"thorns": 4, "knock": 0.2, "defense": 1}, "The tip of a stegosaur's tail spike, bound to a band.",
                   ("beast", "stego", 0.05), "a single long pale bone spike with an amber base bound to a leather band, no creature, game item icon", C + "stego.png"),
    "club_knuckle": ("Club Knuckle", "rare", {"knock": 0.4, "defense": 1}, "A knob of ankylosaur tail-club bound over the fist.",
                     ("beast", "anky", 0.05), "a knobbly round bony club knuckle-guard with leather wraps, no creature, game item icon", C + "anky.png"),
    "longneck_bell": ("Longneck Bell", "rare", {"pack_guard": 0.15}, "A hollow longneck vertebra that booms when struck.",
                      ("beast", "longneck", 0.04), "a hollow bone bell carved from a vertebra hanging from a blue cord, no creature, game item icon", C + "longneck.png"),
    "crest_whistle": ("Crest Whistle", "rare", {"pack_damage": 0.1, "speed": 0.03}, "Carved from a parasaur's crest; it calls the pack to the fight.",
                      ("beast", "parasaur", 0.05), "a curved hollow brown bone whistle carved from a dinosaur crest on a cord, no creature, game item icon", C + "parasaur.png"),
    "rust_signet": ("Rustback Signet", "epic", {"melee": 0.08, "defense": 1}, "A ring of rust-red allosaur scale.",
                    ("beast", "allo", 0.04), "a chunky ring made of rust-red scales with a small tooth set in it, game item icon", C + "allo.png"),
    "rust_buckler": ("Rustfang Buckler", "epic", {"defense": 4, "steady": 0.2}, "A small round shield of allosaur scale and bone.",
                     ("beast", "allo", 0.02), "a small round shield of rust-red scales rimmed with teeth and bone, game item icon", C + "allo.png"),
    "tyrant_eye": ("Tyrant's Eye", "legendary", {"crit": 0.08, "knock": 0.25}, "The rex's amber eye, turned to stone. It sees the weak spot.",
                   ("beast", "rex", 0.06), "a glowing amber eye-shaped gemstone with a slit pupil set in dark green scale, game item icon", C + "rex.png"),
    "sunsail_brooch": ("Sunsail Brooch", "rare", {"regen": 0.25, "fire": 0.3}, "A clasp of dimetrodon sail-skin that holds the sun's warmth.",
                       ("beast", "dimetrodon", 0.05), "a fan-shaped brooch of red and orange sail-skin ribs with a gold pin, no creature, game item icon", C + "dimetrodon.png"),
    "frill_buckle": ("Frill Buckle", "rare", {"steady": 0.3}, "A protoceratops frill made into a belt buckle.",
                     ("beast", "proto", 0.05), "a small scalloped sandy frill made into a belt buckle, no creature, game item icon", C + "proto.png"),
    "compy_trove": ("Compy's Trove", "epic", {"luck": 0.15}, "A little pouch of shiny things a compy had hoarded.",
                    ("beast", "compy", 0.02), "a small leather pouch spilling shiny pebbles, a coin and a crystal chip, game item icon", C + "compy.png"),
    "dodo_plume": ("Dodo Plume", "rare", {"hunger": 0.12}, "A soft dodo tail-feather. Somehow you feel less hungry.",
                   ("beast", "dodo", 0.03), "a single soft curly grey and white tail feather tied with a red string, game item icon", C + "dodo.png"),
    "tusk_charm": ("Tusk Charm", "rare", {"harvest": 0.2}, "A lystrosaur tusk on a cord. Crops grow thick for its wearer.",
                   ("beast", "lystro", 0.04), "a small curved ivory tusk hanging on a green cord with a seed bead, game item icon", C + "lystro.png"),
    "scarhorn_tip": ("Scarhorn Tip", "epic", {"knock": 0.3, "melee": 0.05}, "The broken tip of a Scarhorn's horn.",
                     ("beast", "carno", 0.05), "the broken tip of a thick crimson and bone-white horn on a leather strap, no creature, game item icon", C + "carno.png"),
    "ash_tuft": ("Ashen Mane Tuft", "epic", {"cold": 1, "ash_guard": 0.5}, "A tuft of the Ashmane's mane. Snow and ash can't reach you.",
                 ("beast", "yuty", 0.08), "a fluffy tuft of long white and ash-grey feathers bound with a red cord, game item icon", C + "yuty.png"),
    "reed_claw": ("Reedstalker Claw", "rare", {"bleed": 2.0}, "A deinonychus claw. Its cuts keep bleeding.",
                  ("beast", "deino", 0.05), "a dark olive hooked claw with a yellow base on a thong, no creature, game item icon", C + "deino.png"),
    "sandblade_plume": ("Sandblade Plume", "epic", {"speed": 0.08, "dodge": 0.25}, "A long Utahraptor feather. You move lighter.",
                        ("beast", "utah", 0.06), "a long striped tan and white feather with a bead at the quill, game item icon", "art/dino-v2/first/utah_side.png"),
    "mirefang_tooth": ("Mirefang Tooth", "rare", {"fishing": 0.25, "wading": 0.2}, "A Suchomimus tooth. Fish bite sooner; the shallows pull less.",
                       ("beast", "sucho", 0.05), "a long thin conical crocodile tooth on an olive cord, game item icon", "art/dino-v2/first/sucho_side.png"),
    "sailking_fin": ("Sailking's Fin", "legendary", {"regen": 0.4, "defense": 3}, "A shard of the Sailking's great sail.",
                     ("beast", "spino", 0.12), "a fan-shaped shard of red and orange sail with teal scales at its base, game item icon", "art/dino-v2/first/spino_side.png"),
    "skyfang_shard": ("Sky-Fang Shard", "rare", {"crystal_bane": 0.25, "light": 0.3}, "Crystal from a sick beast. It hums near other crystal.",
                      ("beast", "crystal", 0.10), "a glowing pale blue crystal shard wrapped in wire on a cord, game item icon", "art/dino-v2/first/raptor_crystal_side.png"),
    "crystal_heart": ("Crystal Heart", "legendary", {"regen": 0.3, "defense": 2, "crystal_bane": 0.1}, "The crystal that grew at a beast's heart.",
                      ("beast", "crystal", 0.03), "a heart-shaped cluster of glowing pale blue crystals on a silver chain, game item icon", "art/dino-v2/first/raptor_crystal_side.png"),
    # --- a chest's find ------------------------------------------------------------------
    "wayfarer_anklet": ("Wayfarer's Anklet", "rare", {"speed": 0.06}, "Worn thin by some keeper who walked the whole world.",
                        ("chest", ["cache"]), "a worn leather anklet with brass beads and a small bell, game item icon", "art/keeper-v2/source/sunward/south.png"),
    "lucky_coin": ("Lucky Coin", "rare", {"luck": 0.1}, "An old coin with a hole through it, on a string.",
                   ("chest", ["cache", "relic", "bones"]), "an old gold coin with a hole in the middle on a string, game item icon", "art/keeper-v2/source/sunward/south.png"),
    "moonstone_ring": ("Moonstone Ring", "rare", {"light": 0.5, "regen": 0.1}, "It glows faintly in the dark.",
                       ("chest", ["cache", "relic"]), "a silver ring with a glowing pale moonstone, game item icon", "art/keeper-v2/source/sunward/south.png"),
    "old_compass": ("Old Compass", "rare", {"wisdom": 0.1}, "Its needle points somewhere that isn't north.",
                    ("chest", ["cache", "relic"]), "an old brass pocket compass with a cracked glass face, game item icon", "art/keeper-v2/source/sunward/south.png"),
    "quiver_strap": ("Hunter's Quiver Strap", "rare", {"arrows": 0.12, "draw": 0.1}, "A strap worn smooth by a thousand draws.",
                     ("chest", ["cache"]), "a leather quiver strap with three fletched arrows and a bone buckle, game item icon", "art/keeper-v2/source/sunward/south.png"),
    "keepers_locket": ("Keeper's Locket", "epic", {"feast": 3, "regen": 0.1}, "The last keeper's locket. There's a pressed flower inside.",
                       ("chest", ["relic"]), "an oval silver locket, slightly open, with a pressed flower inside, game item icon", "art/keeper-v2/source/sunward/south.png"),
    # --- the workbench (a beast's parts go into weapons, or into these) --------------------
    "fang_necklace": ("Fang Necklace", "common", {"crit": 0.04}, "Raptor fangs strung on fibre.",
                      ("craft", {"raptor_fang": 3, "plant_fiber": 2}), "a necklace of several sharp white fangs strung on a green fibre cord, game item icon", C + "raptor.png"),
    "plate_pendant": ("Plate Pendant", "common", {"bleed": 1.5}, "A stego plate, filed to an edge.",
                      ("craft", {"stego_plate": 2, "plant_fiber": 2}), "a small amber stegosaurus plate with a sharp filed edge hanging on a cord, game item icon", C + "stego.png"),
    "horn_guard": ("Horn Guard", "common", {"defense": 2, "steady": 0.15}, "Trike horn and hide, a bracer that turns blows.",
                   ("craft", {"trike_horn": 2, "trike_hide": 1}), "a leather bracer with a short curved horn along the forearm, game item icon", C + "trike.png"),
    "scale_bracer": ("Scale Bracer", "rare", {"defense": 3}, "Crystal scale laced over raptor hide.",
                     ("craft", {"trex_scale": 3, "raptor_hide": 1}), "a bracer of overlapping green crystal-edged scales laced on hide, game item icon", C + "rex.png"),
    "tooth_ring": ("Allo Tooth Ring", "rare", {"melee": 0.06}, "An allosaur tooth set in rustiron.",
                   ("craft", {"allo_tooth": 2, "rustiron": 1}), "a rust-coloured iron ring with a curved white tooth set in it, game item icon", C + "allo.png"),
    "sunstone_amulet": ("Sunstone Amulet", "rare", {"fire": 0.4, "regen": 0.15}, "Warm to the touch, even at night.",
                        ("craft", {"sunstone": 2, "sail_scale": 1}), "a glowing orange sunstone amulet in a frame of red sail scales, game item icon", C + "dimetrodon.png"),
    "bogiron_band": ("Bog-iron Band", "rare", {"fishing": 0.15, "wading": 0.2}, "Black bog iron and a Suchomimus claw.",
                     ("craft", {"bog_iron": 2, "sucho_claw": 1}), "a dark black-iron armband with a hooked claw charm, game item icon", "art/dino-v2/first/sucho_side.png"),
    "ashglass_eye": ("Ashglass Eye", "rare", {"crit": 0.05, "light": 0.2}, "A lens of ashglass. Through it, foes show their weak spots.",
                     ("craft", {"ashglass": 2, "ashmane_fur": 1}), "a round smoky black glass lens with a glowing ember core, on a grey fur cord, game item icon", C + "yuty.png"),
    "fur_wrap": ("Fur-lined Wrap", "rare", {"cold": 1}, "Ashmane fur against the snow.",
                 ("craft", {"ashmane_fur": 2, "raptor_hide": 1}), "a thick wrap of grey fur with a leather tie, game item icon", C + "yuty.png"),
    "claw_bracelet": ("Claw Bracelet", "rare", {"bleed": 1.0, "crit": 0.03}, "Deinonychus and Utahraptor claws in a ring.",
                      ("craft", {"deino_claw": 2, "sickle_claw": 1}), "a bracelet ringed with small dark hooked claws, game item icon", C + "deino.png"),
    "spine_torc": ("Spine Torc", "epic", {"thorns": 3, "defense": 2}, "Spinosaur spines bent into a neck ring.",
                   ("craft", {"spino_spine": 2, "bog_iron": 1}), "a neck torc of curved red spines on a black iron band, game item icon", "art/dino-v2/first/spino_side.png"),
    # --- tinkered: two trinkets made one (at the workbench) -------------------------------
    "bloodfang": ("Bloodfang Necklace", "epic", {"crit": 0.07, "bleed": 2.0}, "Fangs and a filed plate: every cut counts.",
                  ("tinker", ["fang_necklace", "plate_pendant"], {"crystal_shard": 2}), "a necklace of red-stained fangs around a sharp amber plate, game item icon", C + "raptor.png"),
    "bulwark_charm": ("Bulwark Charm", "epic", {"defense": 5, "steady": 0.45}, "Horn and frill: nothing moves you.",
                      ("tinker", ["horn_guard", "frill_guard"], {"crystal_shard": 2}), "a heavy bracer of horn and frill plates with a crystal stud, game item icon", C + "trike.png"),
    "wanderers_step": ("Wanderer's Step", "epic", {"speed": 0.14, "dodge": 0.25}, "Anklet and plume: light as the Sandblades.",
                       ("tinker", ["wayfarer_anklet", "sandblade_plume"], {"prism_crystal": 1}), "a leather anklet with brass beads and a long striped feather, game item icon", "art/dino-v2/first/utah_side.png"),
    "apex_signet": ("Apex Signet", "legendary", {"melee": 0.12, "crit": 0.08, "knock": 0.25}, "The rex's eye set in the allosaur's ring.",
                    ("tinker", ["tyrant_eye", "rust_signet"], {"prism_crystal": 2}), "a heavy rust-red ring set with a glowing amber slit-pupil eye stone, game item icon", C + "rex.png"),
}

ICONS = {tid: (t[5], t[6]) for tid, t in TRINKETS.items()}


def describe(effects):
    """The effect lines a tooltip shows (the game builds its own from Trinkets.gd;
    this only fills the item's description for tools and the journal)."""
    return ""


def tres(tid):
    name, rarity, effects, story, source, _, _ = TRINKETS[tid]
    icon = os.path.join(ICON_DIR, tid + ".png")
    head = '[gd_resource type="Resource" script_class="Item" load_steps=%d format=3]\n' % (3 if os.path.exists(icon) else 2)
    head += '[ext_resource type="Script" path="res://Items/Item.gd" id="1"]\n'
    if os.path.exists(icon):
        head += '[ext_resource type="Texture2D" path="res://Forest/art/items/%s.png" id="2"]\n' % tid
    body = '[resource]\nscript = ExtResource("1")\nid = "%s"\nname = "%s"\ndescription = "%s"\n' % (tid, name, story.replace('"', '\\"'))
    body += 'icon = ExtResource("2")\n' if os.path.exists(icon) else 'icon_generator = "forest"\n'
    body += 'max_stack = 1\nrarity = "%s"\nequipment_slot = "trinket"\n' % rarity
    body += "effects = {\n" + ",\n".join('"%s": %s' % (k, json.dumps(v)) for k, v in effects.items()) + "\n}\n"
    return head + body


def recipes():
    rows = []
    for tid, t in TRINKETS.items():
        name, _, effects, story, source = t[0], t[1], t[2], t[3], t[4]
        if source[0] == "craft":
            ing = source[1]
        elif source[0] == "tinker":
            ing = {source[1][0]: 1, source[1][1]: 1}
            ing.update(source[2])
        else:
            continue
        rows.append('\t{"name":"%s","item_id":"%s","ingredients":%s,"station":"workbench","category":"Trinkets","description":"%s"},'
                    % (name, tid, json.dumps(ing, separators=(",", ":")), story.replace('"', '\\"')))
    return "\n".join(rows)


def sources_gd():
    """game/Forest/items/TrinketSources.gd: which beast drops which trinket, and
    which chests hold which (Loot.gd rolls them)."""
    beast, chest = {}, {}
    for tid, t in TRINKETS.items():
        src = t[4]
        if src[0] == "beast":
            beast.setdefault(src[1], []).append([tid, src[2]])
        elif src[0] == "chest":
            for kind in src[1]:
                chest.setdefault(kind, []).append(tid)
    out = ["extends RefCounted",
           "## Written by tools/items/trinkets.py (edit the table there, then run it).",
           "## A beast's rare trinket drops: species (\"crystal\": any crystal-sick beast) -> [[id, chance]].",
           "const BEAST := %s" % json.dumps(beast),
           "## The trinkets each kind of chest can hold (Loot.gd rolls them).",
           "const CHEST := %s" % json.dumps(chest), ""]
    return "\n".join(out)


def main():
    if "--recipes" in sys.argv:
        print(recipes())
        return
    for tid in TRINKETS:
        open(os.path.join(DATA, tid + ".tres"), "w", encoding="utf-8", newline="\n").write(tres(tid))
    open(os.path.join(ROOT, "game", "Forest", "items", "TrinketSources.gd"), "w", encoding="utf-8", newline="\n").write(sources_gd())
    print("wrote %d trinkets and TrinketSources.gd" % len(TRINKETS))


if __name__ == "__main__":
    main()
