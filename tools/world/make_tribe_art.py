"""Pass 12: the tribes' village props, drawn by PixelLab pixflux (1 generation
each) in the colours of the tribe's dress, the tents redrawn from the folk
camp's tent so they sit in the world's perspective and style.

    python tools/world/make_tribe_art.py [name ...]      (all by default)

Writes game/Forest/tribes/art/props/<name>.png (trimmed to the drawing).
Existing ones are kept unless --force. Waits out PixelLab's job limit.
"""
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.dirname(HERE))
sys.path.insert(0, os.path.join(ROOT, "tools", "dino"))
import pixellab_mcp as pl  # noqa: E402
from new_species import job_id  # noqa: E402
from PIL import Image  # noqa: E402

OUT = os.path.join(ROOT, "game", "Forest", "tribes", "art", "props")
SUN = os.path.join(ROOT, "art", "keeper-v2", "source", "sunward", "south.png")
ASH = os.path.join(ROOT, "art", "keeper-v2", "source", "ashen", "south.png")
CAMP = os.path.join(ROOT, "game", "Forest", "folk", "art", "folk_camp.png")

# name: (description, size, colour source, init image or None, keep)
PROPS = {
    "sunward_tent": ("a desert nomad's round dome tent of sand-coloured hides stretched over curved poles, a teal bead trim, "
                     "a dark open doorway, game object", (64, 56), SUN, CAMP, 90),
    "ashen_tent": ("a raider's tent of dark patched hides on crooked poles, bleached bones lashed over the doorway and "
                   "a raptor skull on top, red paint marks, game object", (64, 56), ASH, CAMP, 90),
    "sunward_stall": ("a small desert trading stall: a sand-coloured cloth awning on two wooden poles over a low table "
                      "with clay pots and folded hides, game object", (48, 44), SUN, None, 0),
    "ashen_totem": ("a tall crooked wooden totem pole topped with a bleached raptor skull, wrapped in red cloth with "
                    "dangling bones and feathers, game object", (32, 52), ASH, None, 0),
}


def draw(name, force=False):
    path = os.path.join(OUT, name + ".png")
    if os.path.exists(path) and not force:
        return
    desc, (w, h), colours, init, keep = PROPS[name]
    call = {"description": desc, "width": w, "height": h, "no_background": True, "view": "low top-down",
            "outline": "single color black outline", "shading": "medium shading", "detail": "highly detailed",
            "color_image_base64": pl.inline_files("@" + colours)}
    if init:
        img = Image.open(init).convert("RGBA")
        img = img.crop(img.getbbox())
        board = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        board.alpha_composite(img, ((w - img.width) // 2, h - 2 - img.height))
        tmp_init = os.path.join(OUT, "_init_" + name + ".png")
        board.save(tmp_init)
        call["init_image_base64"] = pl.inline_files("@" + tmp_init)
        call["init_image_strength"] = keep
    client = pl.Client()
    for attempt in range(40):
        try:
            job = job_id(pl.text_of(client.call("create_image_pixflux", call)))
            break
        except SystemExit:
            time.sleep(20)
    else:
        raise SystemExit("gave up waiting for a job slot: " + name)
    tmp = os.path.join(OUT, "_tmp_" + name)
    os.makedirs(tmp, exist_ok=True)
    pl.cmd_wait(job, tmp)
    img = Image.open(os.path.join(tmp, "000.png")).convert("RGBA")
    img.crop(img.getbbox()).save(path)
    print("prop", name, img.getbbox(), flush=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    names = [a for a in sys.argv[1:] if not a.startswith("--")] or list(PROPS)
    for name in names:
        draw(name, "--force" in sys.argv)


if __name__ == "__main__":
    main()
