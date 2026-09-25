"""Pass 13: the chosen drawings of the new beasts (and the remade Scarhorn),
copied to art/dino-v2/new/KEY/{east,south,north}.png for new_species.py
drawings.

All were drawn by PixelLab create_character v3 from words alone (8
directions, 2-3 generations each). As in pass 12, v3's labels rarely match the
animal's facing: for most the side view (facing right) is "north-east", the
front "south-east" and the back "north-west"; the deinonychus came out with
its side as "east", its front "south-west" and its back "north-east".

  - carno: v3_p13b. The first two tries (v3, v3_p13) gave it a ceratopsian
    frill ("horns" pulls the model toward triceratops); "a slim tyrannosaur
    ... stubby bull horns jutting sideways above the eyes" gave a theropod.
  - sucho: v3_p13 (a curled tail, but whole; the 80 px redraw cut its tail
    off at the canvas edge). A stray green leaf on the front view's tail is
    cleared (LEAF).
  - spino: v3_p13 (96 px) with its side view's paddle tail, cut flat by the
    canvas, finished by tail_tip.py (side_fixed.png). The 128 px redraw was
    whole but twice the rex.

    python tools/dino/pick13.py
"""
import os
from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
NEW = os.path.join(ROOT, "art", "dino-v2", "new")

PICKS = {
    "carno": {"east": "v3_p13b/north-east", "south": "v3_p13b/south-east", "north": "v3_p13b/north-west"},
    "utah": {"east": "v3_p13/north-east", "south": "v3_p13/south-east", "north": "v3_p13/north-west"},
    "deino": {"east": "v3_p13/east", "south": "v3_p13/south-west", "north": "v3_p13/north-east"},
    "sucho": {"east": "v3_p13/north-east", "south": "v3_p13/south-east", "north": "v3_p13/north-west"},
    "spino": {"east": "side_fixed", "south": "v3_p13/south-east", "north": "v3_p13/north-west"},
}


def is_leaf(c):
    """The stray leaf: a bright, saturated green the animal's muddy hide never uses."""
    r, g, b, a = c
    return a > 0 and g > 110 and g > r + 45 and g > b + 45


def main():
    for key, views in PICKS.items():
        for out, src in views.items():
            path = os.path.join(NEW, key, src + ".png")
            if not os.path.exists(path):
                print(key, out, "<-", src, "not drawn yet")
                continue
            img = Image.open(path).convert("RGBA")
            if key == "sucho" and out == "south":
                px = img.load()
                cleared = 0
                for y in range(img.height):
                    for x in range(img.width):
                        if is_leaf(px[x, y]):
                            px[x, y] = (0, 0, 0, 0)
                            cleared += 1
                # The leaf's dark outline pixels left floating: drop any opaque
                # pixel with no opaque 4-neighbour.
                for y in range(img.height):
                    for x in range(img.width):
                        if px[x, y][3] == 0:
                            continue
                        n = sum(1 for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
                                if 0 <= x + dx < img.width and 0 <= y + dy < img.height and px[x + dx, y + dy][3] > 0)
                        if n == 0:
                            px[x, y] = (0, 0, 0, 0)
                print("  sucho front: leaf cleared (%d px)" % cleared)
            img.crop(img.getbbox()).save(os.path.join(NEW, key, out + ".png"))
            print(key, out, "<-", src, img.getbbox())


if __name__ == "__main__":
    main()
