"""Sandstone versions of the forest's stone for the Bonelands.

The forest's walls, veins and boulders are grey stone under moss. Out in the
Bonelands the same shapes are sun-baked sandstone: the moss becomes sunlit
sand on the tops, the grey stone becomes banded red-brown strata, and the
violet flecks become dusty rose. Crystal blues stay as they are, so a vein
still reads as a vein.

Writes game/Forest/art/bonelands/sand_{wall,wall_alt,ore,rock}.png from
game/Forest/art/v2/{wall,wall_alt,ore,rock}.png. Every colour in the sources
must be in MAP or in KEEP, or the script stops (so new art can't slip through
half-recoloured).

    python tools/world/make_bonelands_art.py
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "game/Forest/art/v2"
OUT = ROOT / "game/Forest/art/bonelands"

MAP = {
    # Moss, darkest to lightest: sand, shade to sun.
    "2a3320": "5e3f2c",
    "2a3d33": "6a4631",
    "3f5128": "8f6340",
    "3f6b4e": "9a6a44",
    "5e7a33": "b88a55",
    "5c9461": "c29a62",
    "86a84a": "d8b27a",
    "8fc066": "e0bf88",
    # Grey stone: red-brown strata.
    "2e3640": "6e4432",
    "4a5560": "a0694a",
    "74808c": "c48a5c",
    "a7b1ba": "e2c290",
    # Violet flecks: dusty rose.
    "473f66": "6e3e36",
    "6e5c8c": "9c5a4a",
    # Browns and outlines, warmed.
    "1a1726": "2a1810",
    "2e241f": "3a2418",
    "3a2a1e": "4a2e1e",
    "3b2b33": "4a2c26",
    "6b4a4a": "8a5040",
    "6e5a3e": "7a5236",
    "9c8348": "c9a060",
    "a88862": "d6b07a",
}
# Crystal blues (a vein must still look like a vein).
KEEP = {"2a4a66", "2f6e8c", "4fa3b8", "8fd4d6", "dce2e6"}


def recolour(name: str) -> Image.Image:
    im = Image.open(SRC / f"{name}.png").convert("RGBA")
    out = im.copy()
    px = out.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            key = "%02x%02x%02x" % (r, g, b)
            if key in KEEP:
                continue
            if key not in MAP:
                raise SystemExit(f"{name}.png: #{key} at {x},{y} has no sandstone colour")
            m = MAP[key]
            px[x, y] = (int(m[0:2], 16), int(m[2:4], 16), int(m[4:6], 16), a)
    return out


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name in ["wall", "wall_alt", "ore", "rock"]:
        recolour(name).save(OUT / f"sand_{name}.png")
        print("wrote", (OUT / f"sand_{name}.png").relative_to(ROOT))


if __name__ == "__main__":
    main()
