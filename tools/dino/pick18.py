"""Pass 18: the chosen views of the new beasts' PixelLab v3 drawings, copied
to art/dino-v2/new/KEY/{east,south,north}.png for new_species.py drawings.

All were drawn by create_character v3 from words (tools/dino/fetch18.py has
the character ids). As in passes 12-13 the labels rarely match the animal's
facing, so each key names its side (facing right), front and back:
  - ptera, ptera_perch, thyla, dimorph: the labels are true (east/south/north).
  - grimjaw (the Sarcosuchus): true as well.
  - quetzal, quetzal_fly, cinder, reaper: side = north-east, front =
    south-east, back = north-west (the long-bodied pattern of pass 12).

    python tools/dino/pick18.py
"""
import os

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
NEW = os.path.join(ROOT, "art", "dino-v2", "new")
TRUE = {"east": "v3_p18/east", "south": "v3_p18/south", "north": "v3_p18/north"}
# The four redrawn smaller (the first drawings were bigger than a rex): run v3_p18b.
SMALL = {"east": "v3_p18b/east", "south": "v3_p18b/south", "north": "v3_p18b/north"}
TURNED = {"east": "v3_p18/north-east", "south": "v3_p18/south-east", "north": "v3_p18/north-west"}
# Output key -> (the character's download folder, its views). The flying and
# the grounded forms are two drawings and two keys (the pipeline reads a key's
# species as the part before any "_"): ptera (perched) and pterafly, quetzal
# (standing) and quetzalfly.
PICKS = {
    "ptera": ("ptera_perch", SMALL), "pterafly": ("ptera", SMALL), "dimorph": ("dimorph", SMALL), "thyla": ("thyla", SMALL),
    "grimjaw": ("grimjaw", TRUE), "quetzal": ("quetzal", TURNED), "quetzalfly": ("quetzal_fly", TURNED),
    "cinder": ("cinder", TURNED), "reaper": ("reaper", TURNED),
}


def main():
    for key, (folder, views) in PICKS.items():
        sizes = []
        os.makedirs(os.path.join(NEW, key), exist_ok=True)
        for out, src in views.items():
            img = Image.open(os.path.join(NEW, folder, src + ".png")).convert("RGBA")
            img.save(os.path.join(NEW, key, out + ".png"))
            b = img.getbbox()
            sizes.append("%s %dx%d" % (out, b[2] - b[0], b[3] - b[1]))
        print(key.ljust(12), ", ".join(sizes))


if __name__ == "__main__":
    main()
