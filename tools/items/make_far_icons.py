"""Pass 18: the far ring's materials' icons (tools/items/materials.py has the
items): PixelLab pixflux 32x32, 1 generation each, in the items' style.

    python tools/items/make_far_icons.py [ID ...] [--force]
"""
import os
import sys
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
import foods  # noqa: E402

OUT = os.path.join(ROOT, "game", "Forest", "art", "items")
P = "game item icon"
ICONS = {
    "vine": "a coiled length of thick green jungle vine with a few small leaves, " + P,
    "glimmer_shard": "a glowing teal-green crystal shard, bright glinting facets, " + P,
    "orchid": "a single pale pink and white orchid flower with a short green stem, " + P,
    "amber": "a smooth lump of golden amber with a small insect trapped inside, glowing honey colour, " + P,
    "charcoal": "two black lumps of charcoal with a faint grey sheen, " + P,
    "emberstone": "a chunk of black volcanic rock with glowing orange-red veins of ore, " + P,
    "sulfur": "a crusty chunk of bright yellow sulfur crystals, " + P,
    "obsidian": "a sharp shard of glossy black obsidian volcanic glass with a purple sheen, " + P,
}


def draw(iid):
    call = {"description": ICONS[iid], "width": 32, "height": 32, "no_background": True, "view": "side",
            "outline": "single color black outline", "shading": "medium shading", "detail": "highly detailed"}
    foods._pixflux(call, os.path.join(OUT, iid + ".png"))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    todo = [i for i in (args or list(ICONS)) if "--force" in sys.argv or not os.path.exists(os.path.join(OUT, i + ".png"))]
    with ThreadPoolExecutor(max_workers=6) as pool:
        for f in [pool.submit(draw, i) for i in todo]:
            try:
                f.result()
            except Exception as e:
                print("FAILED", e, flush=True)


if __name__ == "__main__":
    main()
