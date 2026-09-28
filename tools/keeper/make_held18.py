"""Pass 18: hand-scale held sprites for the far ring's weapons, recoloured
from the ones they're shaped like (no generations), into
art/keeper-v2/source/held/; then run import_held.py.

    python tools/keeper/make_held18.py [--preview PATH]

Each: a base held sprite, and its two ramps (dark to light): the head (blade,
tip, maul head) and the handle, told apart by the base's own colours (a
handle is brown wood, the rest is the head). Outline pixels stay as they are.
"""
import colorsys
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HELD = os.path.join(ROOT, "game", "Forest", "keeper", "art", "held")
SRC = os.path.join(ROOT, "art", "keeper-v2", "source", "held")


def ramp(*hexes):
    return [tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) for h in hexes]


GLIMMER = ramp("1f5a3c", "2f8a55", "4fc27a", "8ff0b0", "d8ffe8")
VINE = ramp("2c3a1c", "3f5426", "5a6e32", "7a8a44")
GLASS = ramp("120e18", "231d2e", "3a3148", "5d5470", "a49ab8")
EMBER = ramp("5a1a08", "9a3410", "e0621c", "ffb04a")
ICE = ramp("5a7486", "8aa6b8", "b8d2e0", "e2f2fa", "ffffff")
PALE = ramp("4e4a46", "6e6a64", "8e8a82", "b0aca2")
STORM = ramp("3a4450", "5a6878", "8494a4", "b8c6d2", "e4ecf2")
DARK = ramp("1a1612", "2a221c", "3e332a", "54463a")

# id: (base, head ramp, handle ramp, accent: (x, y, rgb) pixels to set after)
WEAPONS = {
    "glimmer_spear": ("horn_spear", GLIMMER, VINE, []),
    "obsidian_blade": ("shard_sword", GLASS, EMBER, []),
    "reaper_scythe": ("fang_sabre", ICE, PALE, []),
    "storm_glaive": ("scarhorn_lance", STORM, DARK, []),
    "cinderbrand": ("plate_maul", GLASS, DARK, "core"),
    # (Older weapons that had no held sprite and so showed an empty hand.)
    "ashglass_knife": ("bone_dagger", ramp("16131a", "2c2630", "4a4050", "6e6478", "b0a2b8"), PALE, []),
    "bogiron_harpoon": ("horn_spear", ramp("16181a", "2a2e30", "464c4e", "6e7676", "9aa2a0"), ramp("20180e", "34281a", "4a3a26", "5e4a32"), []),
    "rustjaw_sabre": ("fang_sabre", ramp("4a140c", "7a2a16", "a8482a", "cc6e44", "e89a6e"), DARK, []),
    "spinesail_glaive": ("scarhorn_lance", ramp("5a1410", "962a18", "d4502a", "f08a3a", "ffc070"), ramp("12302e", "1c4644", "2a5e58", "3c7a70"), []),
    "sunstone_maul": ("plate_maul", ramp("6a3a08", "a86410", "e09a20", "ffcc48", "fff0a0"), ramp("3a2a1c", "54402a", "6e563a", "8a6e4a"), []),
}


def is_handle(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
    return 0.03 <= h <= 0.12 and 0.3 <= s <= 0.85 and 0.2 <= v <= 0.75


def recolour(base, head, handle, accent):
    src = Image.open(os.path.join(HELD, base + ".png")).convert("RGBA")
    out = src.copy()
    px = []
    for y in range(src.height):
        for x in range(src.width):
            r, g, b, a = src.getpixel((x, y))
            if a < 128:
                continue
            lum = (0.3 * r + 0.59 * g + 0.11 * b) / 255.0
            if lum < 0.13:
                continue  # the outline
            px.append((x, y, lum, is_handle(r, g, b)))
    for part, table in ((True, handle), (False, head)):
        lums = sorted(p[2] for p in px if p[3] == part)
        if not lums:
            continue
        lo, hi = lums[0], lums[-1]
        for x, y, lum, hnd in px:
            if hnd != part:
                continue
            t = 0.5 if hi - lo < 1e-6 else (lum - lo) / (hi - lo)
            c = table[min(len(table) - 1, int(round(t * (len(table) - 1))))]
            out.putpixel((x, y), c + (255,))
    if accent == "core":
        # A molten core in the maul's head: its brightest head pixels glow.
        heads = sorted([p for p in px if not p[3]], key=lambda p: -p[2])
        for x, y, _, _ in heads[:5]:
            out.putpixel((x, y), EMBER[3] + (255,))
        for x, y, _, _ in heads[5:9]:
            out.putpixel((x, y), EMBER[2] + (255,))
    return out


def main():
    os.makedirs(SRC, exist_ok=True)
    made = []
    for iid, (base, head, handle, accent) in WEAPONS.items():
        im = recolour(base, head, handle, accent)
        made.append(im)
        if "--preview" not in sys.argv:
            im.save(os.path.join(SRC, iid + ".png"))
            print("held", iid, "from", base)
    if "--preview" in sys.argv:
        sheet = Image.new("RGBA", (20 * len(made), 20), (90, 120, 80, 255))
        for i, im in enumerate(made):
            sheet.alpha_composite(im, (i * 20 + 2, 2))
        sheet.resize((sheet.width * 8, sheet.height * 8), Image.NEAREST).save(sys.argv[sys.argv.index("--preview") + 1])


if __name__ == "__main__":
    main()
