"""Item icons drawn by PixelLab pixflux (1 generation each), 32 x 32 on a
transparent ground, in the colours of a source image (an armour set's front
view, a creature's drawing) so they sit with what they come from.

    python tools/keeper/make_icons.py ID [ID ...]      # entries from ICONS below
    python tools/keeper/make_icons.py --all

Armour pieces go to game/Forest/equipment/art/wardrobe/icons/<id>.png (ItemDB
reads them before any other icon); everything else to
game/Forest/art/items/<id>.png. Existing icons are kept unless --force.
"""
import os
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.dirname(HERE))
import pixellab_mcp as pl  # noqa: E402

WARDROBE = os.path.join(ROOT, "game", "Forest", "equipment", "art", "wardrobe", "icons")
ITEMS = os.path.join(ROOT, "game", "Forest", "art", "items")
SETS = os.path.join(ROOT, "art", "keeper-v2", "source")
CREATURES = os.path.join(ROOT, "game", "Forest", "creatures", "art")

# id: (description, colour source (relative to ROOT))
ICONS = {
    # Hornguard (trike).
    "horn_helmet": ("a helmet shaped like a triceratops frill with two short curved horns, red-orange ridged hide with teal crystal studs, game item icon", "art/keeper-v2/source/horn/south.png"),
    "horn_chestplate": ("a heavy chestplate of red-orange ridged triceratops hide with bone plates and teal crystal studs, game item icon", "art/keeper-v2/source/horn/south.png"),
    "horn_leggings": ("a pair of armoured trousers and boots, no creature, made of red-orange ridged hide with bony knee guards and teal studs, game item icon", "art/keeper-v2/source/horn/south.png"),
    # Plateback (stego).
    "plate_helmet": ("a warrior's helmet, no creature, of olive-green scaled hide with a crest of small amber plates along the top, game item icon", "art/keeper-v2/source/plate/south.png"),
    "plate_chestplate": ("a chestplate of olive-green scaled hide with tall amber stegosaurus plates rising from the shoulders and small bone spikes, game item icon", "art/keeper-v2/source/plate/south.png"),
    "plate_leggings": ("leggings of olive-green scaled hide with spiked knee guards and boots, game item icon", "art/keeper-v2/source/plate/south.png"),
    # Rustback (allo).
    "rust_helmet": ("a rust-red scaled allosaurus-head helmet with small brow horns and a jaw of sharp teeth, game item icon", "art/keeper-v2/source/rust/south.png"),
    "rust_chestplate": ("a rust-red scaled chestplate with a collar of sharp teeth and dark leather straps, game item icon", "art/keeper-v2/source/rust/south.png"),
    "rust_leggings": ("rust-red scaled leggings with dark boots, game item icon", "art/keeper-v2/source/rust/south.png"),
    # Weapons.
    "fang_sabre": ("a curved sabre whose blade is one long ivory-white raptor fang, a small teal guard and a hide-wrapped grip, diagonal, game item icon", "art/keeper-v2/source/bone/south.png"),
    "horn_spear": ("a spear tipped with a triceratops horn, a wooden shaft bound with red-orange hide, diagonal, game item icon", "game/Forest/creatures/art/trike.png"),
    "plate_maul": ("a heavy war maul with a head of amber stegosaurus plates and bone spikes on a wooden haft, diagonal, game item icon", "game/Forest/creatures/art/stego.png"),
    "allo_cleaver": ("a broad cleaver edged with serrated allosaurus teeth, a rust-red scaled grip, diagonal, game item icon", "game/Forest/creatures/art/allo.png"),
    "tyrant_fang": ("a great sword made from a tyrannosaurus fang, emerald scales on the guard and grip, diagonal, game item icon", "game/Forest/creatures/art/rex.png"),
    # Materials.
    "raptor_hide": ("a folded piece of speckled blue-grey raptor hide, game item icon", "game/Forest/creatures/art/raptor.png"),
    "trike_horn": ("a single curved triceratops horn, bone-white with a darker base, game item icon", "game/Forest/creatures/art/trike.png"),
    "trike_hide": ("a folded piece of thick red-orange ridged triceratops hide, game item icon", "game/Forest/creatures/art/trike.png"),
    "stego_plate": ("a single amber stegosaurus back plate, diamond shaped, game item icon", "game/Forest/creatures/art/stego.png"),
    "longneck_hide": ("a rolled bundle of smooth blue-grey sauropod hide, game item icon", "game/Forest/creatures/art/longneck.png"),
    "allo_tooth": ("a single long serrated allosaurus tooth, ivory with a rust-red root, game item icon", "game/Forest/creatures/art/allo.png"),
    "parasaur_crest": ("a hollow curved tube of brown bone like a hunting horn, no head, no creature, game item icon", "game/Forest/creatures/art/parasaur.png"),
    # Pass 12: the dunes' and the Pale Lands' beasts, and the tribes' dress.
    "sail_scale": ("a single curved fan-shaped scale of red and orange skin stretched over dark spines, no creature, game item icon", "game/Forest/creatures/art/dimetrodon.png"),
    "anky_plate": ("a thick oval bony armour plate with a short bone-white spike, ochre and brown, no creature, game item icon", "game/Forest/creatures/art/anky.png"),
    "proto_frill": ("a folded piece of sandy tan hide with an orange scalloped edge, no creature, game item icon", "game/Forest/creatures/art/proto.png"),
    "carno_horn": ("a single short thick curved horn, crimson at the base and bone-white at the tip, no creature, game item icon", "game/Forest/creatures/art/carno.png"),
    "ashmane_fur": ("a bundle of long shaggy ash-grey feathery fur tied with a dark cord, no creature, game item icon", "game/Forest/creatures/art/yuty.png"),
    "sail_veil": ("a face veil of thin red and orange sail-skin stretched on a curved cord, no person, no creature, game item icon", "game/Forest/creatures/art/dimetrodon.png"),
    "ashmane_mantle": ("a folded thick hooded cloak of shaggy ash-grey fur with a red bone clasp, no creature, no person, game item icon", "game/Forest/creatures/art/yuty.png"),
    "sun_sail": ("a small wooden post holding up a tall red and orange fan-shaped sail of scales, like a garden lamp, no creature, game item icon", "game/Forest/creatures/art/dimetrodon.png"),
    "club_maul": ("a heavy war club with a big round knobbly bone head on a thick wooden haft, diagonal, game item icon", "game/Forest/creatures/art/anky.png"),
    "scarhorn_lance": ("a long spear tipped with a big curved crimson horn, bound with dark leather, diagonal, game item icon", "game/Forest/creatures/art/carno.png"),
    "raider_club": ("a crude wooden club studded with sharp teeth and bound with red cord, diagonal, game item icon", "art/keeper-v2/source/ashen/south.png"),
    "sunward_helmet": ("an empty sand-coloured cloth desert hood with a dark opening where the face goes, a teal bead band round the brow and a cloth tail hanging down the back, no face, no person, game item icon", "art/keeper-v2/source/sunward/south.png"),
    "sunward_chestplate": ("a loose sand and ochre robe with a terracotta sash and a teal bead necklace, no person, game item icon", "art/keeper-v2/source/sunward/south.png"),
    "sunward_leggings": ("sand-coloured wrapped trousers and leather sandals, no person, game item icon", "art/keeper-v2/source/sunward/south.png"),
    "ashen_helmet": ("a bleached raptor skull mask with a crest of dark red quills, no person, game item icon", "art/keeper-v2/source/ashen/south.png"),
    "ashen_chestplate": ("a dark hide vest with a harness of bone plates, dark fur shoulders and red stripes, no person, game item icon", "art/keeper-v2/source/ashen/south.png"),
    "ashen_leggings": ("a dark hide loincloth over wrapped dark leggings with bone shin guards, no person, game item icon", "art/keeper-v2/source/ashen/south.png"),
}
ARMOUR = ("_helmet", "_chestplate", "_leggings")


def out_path(item_id):
    return os.path.join(WARDROBE if item_id.endswith(ARMOUR) else ITEMS, item_id + ".png")


def draw(item_id):
    desc, colours = ICONS[item_id]
    from new_species import job_id  # noqa: E402  (tools/dino)
    call = {"description": desc, "width": 32, "height": 32, "no_background": True, "view": "side",
            "outline": "single color black outline", "shading": "medium shading", "detail": "highly detailed",
            "color_image_base64": pl.inline_files("@" + os.path.join(ROOT, colours))}
    client = pl.Client()
    # PixelLab runs 8 jobs at once per account; while the clip runs hold every
    # slot, wait for one to free up rather than giving up.
    for attempt in range(120):
        text = pl.text_of(client.call("create_image_pixflux", call))
        if "rate limit" not in text:
            break
        time.sleep(20)
    job = job_id(text)
    # The download lands in a scratch folder (with the job's notes) that goes
    # once the icon is in place.
    tmp = tempfile.mkdtemp(prefix="icon_" + item_id + "_")
    pl.cmd_wait(job, tmp)
    shutil.move(os.path.join(tmp, "000.png"), out_path(item_id))
    shutil.rmtree(tmp, ignore_errors=True)
    print("icon", item_id, "->", os.path.relpath(out_path(item_id), ROOT), flush=True)


def main():
    sys.path.insert(0, os.path.join(ROOT, "tools", "dino"))
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    ids = list(ICONS) if "--all" in sys.argv else args
    force = "--force" in sys.argv
    todo = [i for i in ids if force or not os.path.exists(out_path(i))]
    if len(todo) == 1:
        draw(todo[0])
        return
    # A few at a time (PixelLab runs 8 jobs at once per account).
    running = []
    for item_id in todo:
        running.append(subprocess.Popen([sys.executable, __file__, item_id] + (["--force"] if force else [])))
        if len(running) >= 4:
            running.pop(0).wait()
    for p in running:
        p.wait()


if __name__ == "__main__":
    main()
