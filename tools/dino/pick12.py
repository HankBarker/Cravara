"""Pass 12: the chosen drawings of the new beasts, copied to
art/dino-v2/new/KEY/{east,south,north}.png for new_species.py drawings.

Most were drawn by PixelLab create_character v3 from words alone (8
directions, 2 generations each; the canvas size sets the animal's size, so
each was drawn at the size it should be in the game). v3's direction labels
don't match the animal's facing for these long bodies: for all of them the
side view (facing right) came out as "north-east", the front as
"south-east" and the back as "north-west". The protoceratops is the pixflux
restyle (v3 gave it horns, like a baby trike); the compy is side-on only.

    python tools/dino/pick12.py
"""
import os
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
NEW = os.path.join(ROOT, "art", "dino-v2", "new")

PICKS = {
    "dimetrodon": {"east": "v3_60/north-east", "south": "v3_60/south-east", "north": "v3_60/north-west"},
    "carno": {"east": "v3_b/north-east", "south": "v3_b/south-east", "north": "v3_b/north-west"},
    "yuty": {"east": "v3_68/north-east", "south": "v3_68/south-east", "north": "v3_68/north-west"},
    "anky": {"east": "v3_56/north-east", "south": "v3_56/south-east", "north": "v3_56/north-west"},
    "proto": {"east": "redraw/side_t1", "south": "redraw/down_t2", "north": "redraw/up_t2"},
    "compy": {"east": "v3_24/north"},
}


def main():
    for key, views in PICKS.items():
        for out, src in views.items():
            path = os.path.join(NEW, key, src + ".png")
            if not os.path.exists(path):
                print(key, out, "<-", src, "not drawn yet")
                continue
            img = Image.open(path).convert("RGBA")
            img.crop(img.getbbox()).save(os.path.join(NEW, key, out + ".png"))
            print(key, out, "<-", src, img.getbbox())


if __name__ == "__main__":
    main()
