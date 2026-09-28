"""Pass 12 starter palettes for the new beasts (art/dino-v2/palettes/KEY.hex).

The restyles (redraw_view.py) force these colours so each animal comes out
in its own hues; prepare.py later rebuilds each species' full palette from
its finished drawings.

    python tools/dino/palettes12.py
"""
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "dino-v2", "palettes")

PALETTES = {
    # Sunsail Dimetrodon: earthy body, a red-orange sail with dark spines.
    "dimetrodon": [(40, 32, 28), (70, 56, 46), (96, 80, 64), (122, 104, 84), (150, 132, 106), (184, 166, 132),
                   (214, 200, 164), (110, 38, 28), (150, 56, 38), (192, 80, 50), (226, 118, 70), (244, 160, 100),
                   (70, 70, 52), (104, 104, 72), (136, 134, 92), (232, 196, 80), (240, 236, 220)],
    # Scarhorn Carnotaurus: crimson with maroon stripes, pale belly, bone horns.
    "carno": [(32, 18, 20), (54, 30, 34), (70, 24, 28), (104, 34, 36), (140, 46, 42), (176, 62, 50), (206, 90, 64),
              (196, 150, 110), (222, 184, 140), (240, 214, 176), (200, 188, 160), (232, 224, 200), (240, 200, 70),
              (250, 246, 236), (90, 84, 86)],
    # Frostmane Yutyrannus: shaggy white feathers, blue-grey shade, a red crest.
    "yuty": [(26, 28, 36), (70, 78, 96), (100, 110, 128), (134, 144, 160), (170, 178, 192), (204, 210, 220),
             (232, 236, 240), (250, 250, 252), (86, 80, 84), (120, 112, 114), (150, 60, 64), (190, 90, 86),
             (220, 214, 196), (20, 20, 24), (120, 160, 170)],
    # Dune Protoceratops: sand body, darker back stripes, an orange frill.
    "proto": [(40, 30, 24), (88, 64, 44), (112, 84, 56), (148, 114, 76), (184, 146, 100), (212, 178, 128),
              (234, 208, 160), (240, 226, 190), (170, 90, 50), (206, 120, 64), (232, 156, 90), (70, 66, 64),
              (104, 98, 94), (24, 20, 18)],
    # Sandclub Ankylosaur: ochre shell, dark bands, bone spikes, a heavy club.
    "anky": [(36, 28, 22), (70, 52, 38), (96, 72, 48), (128, 98, 64), (162, 128, 84), (196, 160, 108),
             (222, 192, 138), (244, 224, 176), (236, 228, 204), (206, 196, 170), (138, 110, 86), (170, 140, 110),
             (84, 70, 60), (30, 24, 20)],
    # Compy: a small olive-green hunter with a yellow belly and dark stripes.
    "compy": [(22, 30, 20), (40, 54, 34), (52, 80, 40), (76, 110, 52), (104, 142, 62), (140, 176, 80),
              (178, 204, 110), (220, 206, 120), (240, 230, 160), (230, 120, 40), (240, 236, 220)],
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for key, colours in PALETTES.items():
        with open(os.path.join(OUT, key + ".hex"), "w") as f:
            f.write("\n".join("%02x%02x%02x" % c for c in colours))
        print(key, len(colours), "colours")


if __name__ == "__main__":
    main()
