"""Pass 18: the far ring's and the treetops' props (Hank: "the jungle area is
very lush, very, very tall trees... a lot more crystals"; "the volcano...
rare materials and ores"; the treetops: "walking along branches and bark").
PixelLab pixflux, 1 generation each, drawn at twice their size and shrunk
(tools/world/make_ruin_art.py's clean-free shrink), several at once.

    python tools/world/make_far_art.py [NAME ...] [--force] [--finish] [--jobs N]

  --finish   redo the game's sprites from the kept drawings (no generation)

Writes game/Forest/art/v9/<name>.png; the drawings are kept in
art/pass18/raw/<name>.png. The jungle's and the treetops' props take the
forest props' palette (WorldObjects/Images/Objects.png) so they sit with the
rest of the world; the volcano's and the glowing ones choose their own
colours (the forest palette has no ember reds or crystal teals).
The giant trees, their crowns, the rope ladders and the vines are drawn in
code (tools/world/make_giants.py).
"""
import os
import sys
from concurrent.futures import ThreadPoolExecutor

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "items"))
sys.path.insert(0, HERE)
import foods  # noqa: E402  (its _pixflux)
from make_ruin_art import shrink  # noqa: E402

OUT = os.path.join(ROOT, "game", "Forest", "art", "v9")
RAW = os.path.join(ROOT, "art", "pass18", "raw")
FOREST = os.path.join(ROOT, "game", "WorldObjects", "Images", "Objects.png")
BARE = ", standing alone, no ground, no grass, no shadow, no base, transparent background, top-down game prop"
# name: (prompt, game width, game height, palette: "forest" or None)
ART = {
    # The jungle floor.
    "jungle_tree": ("a tall tropical jungle tree, a straight grey-brown trunk with buttress roots and a dense broad crown of big glossy dark green leaves, a few vines hanging from its branches" + BARE, 48, 96, "forest"),
    "giant_fern": ("a huge prehistoric tree fern, a burst of long feathery green fronds arching out from a short hairy stump" + BARE, 32, 28, "forest"),
    "jungle_bush": ("a dense tropical shrub with big glossy dark green leaves and clusters of bright red berries" + BARE, 28, 22, "forest"),
    "glowcap": ("a cluster of glowing bioluminescent mushrooms with pale cyan caps and softly shining stems" + BARE, 16, 18, None),
    "jungle_flower": ("a large tropical flowering plant, a bright magenta and orange bloom on broad green leaves" + BARE, 16, 18, None),
    "fallen_log": ("a fallen mossy tree trunk lying on its side, rotten brown bark with ferns and little mushrooms growing on it" + BARE, 48, 22, "forest"),
    "glimmer_crystal": ("a cluster of glowing teal and green crystals jutting up from the ground, bright glinting facets" + BARE, 24, 30, None),
    # The treetops.
    "leaf_clump": ("a thick clump of big broad glossy jungle leaves, seen from above" + BARE, 32, 22, "forest"),
    "canopy_flower": ("a small orchid with pink and white flowers growing from a tuft of moss" + BARE, 16, 16, None),
    "fruit_pod": ("a bunch of ripe orange tropical fruit on a short leafy stem" + BARE, 16, 16, None),
    "bromeliad": ("a bromeliad plant, a rosette of stiff red and green leaves holding a little cup of water in its centre" + BARE, 16, 16, None),
    "amber": ("a lump of glowing golden amber resin with a small insect trapped inside" + BARE, 16, 16, None),
    # The volcano.
    "charred_tree": ("a dead burnt tree, a charred black trunk and bare twisted branches, glowing orange embers in the cracks of its bark" + BARE, 32, 48, None),
    "vent": ("a volcanic fumarole, a small cracked mound of dark grey rock around a glowing orange vent hole" + BARE, 24, 16, None),
    "ember_crystal": ("a cluster of glowing red and orange ember crystals growing out of black volcanic rock" + BARE, 20, 28, None),
    "sulfur": ("a crusty deposit of bright yellow sulfur crystals on dark rock" + BARE, 16, 16, None),
    "ash_bush": ("a dead shrub coated in grey volcanic ash, brittle bare twigs" + BARE, 20, 16, None),
    "basalt": ("a cluster of tall hexagonal black basalt columns with a few thin glowing orange cracks" + BARE, 32, 32, None),
    # The bog's own trees (Hank: "in the bog, maybe we could add a little bit
    # more variation"): drawn over the forest trees that stand in the bog
    # (ForestProp.boggy), so a world's trees stay where they were.
    "bog_cypress": ("a swamp bald cypress tree, a wide flared buttressed trunk with knobby cypress knees around its foot, a ragged dark olive green crown draped with long grey hanging Spanish moss" + BARE, 62, 80, "forest"),
    "bog_mangrove": ("a mangrove tree standing on a tangle of arching stilt roots, a low dark green leafy crown, dark wet bark" + BARE, 62, 74, "forest"),
    "bog_willow": ("a weeping swamp willow tree with long drooping curtains of pale green leaves and hanging moss almost touching the ground, a gnarled dark trunk" + BARE, 64, 80, "forest"),
    "bog_mirewood": ("a crooked black-barked swamp tree with twisted leaning trunk, sparse clumps of dark green leaves and pale shelf fungus on its bark" + BARE, 56, 78, "forest"),
    # The volcano's fallen forges.
    "ember_forge": ("an ancient forge built of black basalt blocks, a hearth of glowing orange coals under a stone hood" + BARE, 32, 32, None),
    "anvil": ("an old dark iron blacksmith's anvil on a squat stone block" + BARE, 16, 16, None),
}


def finish(name):
    raw = os.path.join(RAW, name + ".png")
    small = shrink(Image.open(raw).convert("RGBA"))
    small.save(os.path.join(OUT, name + ".png"))
    print("finished", name, small.size, flush=True)


def draw(name):
    desc, w, h, palette = ART[name]
    call = {"description": desc, "width": w * 2, "height": h * 2, "no_background": True, "view": "low top-down",
            "outline": "selective outline", "shading": "medium shading", "detail": "highly detailed"}
    if palette == "forest":
        call["color_image_base64"] = "@" + FOREST
    foods._pixflux(call, os.path.join(RAW, name + ".png"))
    finish(name)


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(RAW, exist_ok=True)
    args = [a for a in sys.argv[1:] if not a.startswith("--") and not a.isdigit()]
    if "--finish" in sys.argv:
        for name in args or list(ART):
            finish(name)
        return
    todo = []
    for name in args or list(ART):
        if name not in ART:
            print("unknown", name)
            continue
        if os.path.exists(os.path.join(OUT, name + ".png")) and "--force" not in sys.argv:
            print("have", name)
            continue
        todo.append(name)
    jobs = int(sys.argv[sys.argv.index("--jobs") + 1]) if "--jobs" in sys.argv else 6
    with ThreadPoolExecutor(max_workers=jobs) as pool:
        for f in [pool.submit(draw, n) for n in todo]:
            try:
                f.result()
            except Exception as e:
                print("FAILED", e, flush=True)


if __name__ == "__main__":
    main()
