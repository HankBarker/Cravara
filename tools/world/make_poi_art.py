"""Art for the forest's points of interest.

    python tools/world/make_poi_art.py

Writes game/Forest/art/poi/:
  ruin_*.png   craftpix ruins (Assets, no baked shadow: the game casts its
               own sun shadows from the silhouette), cropped to the drawing
  pieces/ + pieces.json  each drawing split into its parts, with the
               collision at each part's foot (tools/world/poi_pieces.py)
  idol_*.png   the old tribe's carved tree idols (craftpix forest objects)
  grove_shrine.png  the living gazebo (a grove of bent trees round a crystal)
  cache_closed.png / cache_open.png  an ancient cache: a carved stone chest
               with a gold band and a Sky-Fang crystal, drawn here
  relic_mound.png  a heaped mound with a glint: something buried
  wild_roots.png   leafy tops of wild tubers, ready to dig
Sources are the craftpix packs in assets_raw (craftpix.net file licence); the
cache, the mound and the roots are drawn here.
"""
import os
import zipfile
from io import BytesIO

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
RAW = os.path.join(ROOT, "assets_raw")
OUT = os.path.join(ROOT, "game", "Forest", "art", "poi")
RUINS_ZIP = "craftpix-net-934618-free-top-down-ruins-pixel-art.zip"
OBJECTS_ZIP = "craftpix-net-505052-free-forest-objects-top-down-pixel-art.zip"

RUINS = {
    # The broken round observatory (no tree grows through it).
    "ruin_temple": "PNG/Assets/Water_ruins1.png",
    "ruin_statue": "PNG/Assets/Blue-gray_ruins3.png",
    "ruin_tower": "PNG/Assets/Brown_ruins1.png",
    "ruin_stairs": "PNG/Assets/Brown_ruins2.png",
    "ruin_pillar": "PNG/Assets/Brown_ruins4.png",
    "ruin_hall": "PNG/Assets/White_ruins1.png",
    "ruin_arch": "PNG/Assets/White_ruins2.png",
    "ruin_column": "PNG/Assets/White_ruins4.png",
    "ruin_stones": "PNG/Assets/Brown-gray_ruins1.png",
    "ruin_boulders": "PNG/Assets/Brown-gray_ruins2.png",
}
OBJECTS = {
    "idol_deer": "Tree_idol_deer.png",
    "idol_wolf": "Tree_idol_wolf.png",
    "idol_human": "Tree_idol_human.png",
    "grove_shrine": "Living gazebo1.png",
}


def read(zip_name, member_suffix):
    with zipfile.ZipFile(os.path.join(RAW, zip_name)) as z:
        for name in z.namelist():
            if name.replace("\\", "/").endswith(member_suffix):
                return Image.open(BytesIO(z.read(name))).convert("RGBA")
    raise FileNotFoundError(member_suffix)


def tight(img):
    box = img.getbbox()
    return img.crop(box) if box else img


def mound():
    """A heaped 16x8 mound split by a zigzag crack, with a glint and two pebbles."""
    rows = [
        ".....aaaaaa.....",
        "...aabbcbbbaa...",
        "..abbcc#ccbbba..",
        ".abbccc#cccbbba.",
        "abbccccc##cbwbba",
        "abbcccccc#cbbbba",
        ".aabbbbbbbbbbaa.",
        "p..aaaaaaaaaa..p",
    ]
    colors = {"a": (86, 60, 40), "b": (122, 88, 58), "c": (156, 118, 78), "#": (58, 40, 28),
              "w": (252, 244, 204), "p": (168, 172, 164)}
    return draw(rows, colors)


def cache(opened):
    """An ancient cache: a carved stone chest with a gold band, a Sky-Fang
    crystal in the lid and a gold lock plate. Open, the lid stands up behind
    and the inside gleams."""
    closed = [
        "...oooooooooooo...",
        "..oLLLLLLLLLLLLo..",
        ".oLllllllllllllLo.",
        ".oMMMMMggggMMMMMo.",
        ".oMMMMgcCCcgMMMMo.",
        ".oDDDDDggggDDDDDo.",
        "oooooooooooooooooo",
        "oGllllllllllllllGo",
        "oGMMMMMMggMMMMMMGo",
        "oGMMMMMgKKgMMMMMGo",
        "oGMMMMMgKKgMMMMMGo",
        "oGDDDDDDggDDDDDDGo",
        "oGDDDDDDDDDDDDDDGo",
        "oooooooooooooooooo",
    ]
    open_ = [
        "...oooooooooooo...",
        "..oDDDDDDDDDDDDo..",
        ".oDMMMMggggMMMMDo.",
        ".oDMMMgcCCcgMMMDo.",
        ".oDDDDDggggDDDDDo.",
        "oooooooooooooooooo",
        "oGnnnnnnnnnnnnnnGo",
        "oGnnYnnnnnnnYnnnGo",
        "oGllllllllllllllGo",
        "oGMMMMMMggMMMMMMGo",
        "oGMMMMMgKKgMMMMMGo",
        "oGDDDDDDggDDDDDDGo",
        "oGDDDDDDDDDDDDDDGo",
        "oooooooooooooooooo",
    ]
    colors = {"o": (34, 39, 43), "L": (182, 188, 178), "l": (150, 158, 150), "M": (118, 128, 124),
              "D": (84, 94, 94), "g": (232, 188, 88), "G": (200, 150, 60), "K": (126, 86, 34),
              "c": (60, 150, 200), "C": (150, 232, 255), "n": (28, 24, 22), "Y": (250, 222, 120)}
    return draw(open_ if opened else closed, colors)


def roots():
    """Leafy tops of a wild tuber: three leaves over a peeking orange root."""
    rows = [
        "..g....g...",
        ".gGg..gGg..",
        "..gGg.Gg.g.",
        "...gGGg.gGg",
        "....gGGGg..",
        "...ooGGoo..",
        "..oOOOOOOo.",
        "...oooooo..",
    ]
    colors = {"g": (58, 104, 50), "G": (104, 160, 72), "o": (170, 96, 40), "O": (214, 136, 58)}
    return draw(rows, colors)


def draw(rows, colors):
    img = Image.new("RGBA", (len(rows[0]), len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in colors:
                img.putpixel((x, y), colors[ch] + (255,))
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, member in RUINS.items():
        tight(read(RUINS_ZIP, member)).save(os.path.join(OUT, name + ".png"))
    for name, member in OBJECTS.items():
        tight(read(OBJECTS_ZIP, "Assets_no_shadow/" + member)).save(os.path.join(OUT, name + ".png"))
    cache(False).save(os.path.join(OUT, "cache_closed.png"))
    cache(True).save(os.path.join(OUT, "cache_open.png"))
    mound().save(os.path.join(OUT, "relic_mound.png"))
    roots().save(os.path.join(OUT, "wild_roots.png"))
    for n in sorted(os.listdir(OUT)):
        if n.endswith(".png"):
            print(n, Image.open(os.path.join(OUT, n)).size)
    import poi_pieces
    poi_pieces.main()


if __name__ == "__main__":
    main()
