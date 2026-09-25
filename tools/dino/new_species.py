"""Draw a new dinosaur for the v2 pipeline with PixelLab (files in, files out;
no base64 passes through the chat).

    python tools/dino/new_species.py restyle KEY --from SPECIES --scale S --canvas N --desc "..."
    python tools/dino/new_species.py rotate  KEY --desc "..."
    python tools/dino/new_species.py drawings KEY --frame W H

restyle   1 generation. SPECIES' front (down) drawing, scaled S times (nearest)
          onto an N x N canvas, feet near the bottom, redrawn by
          create_image_pixflux as the new animal (init strength --keep, 160 by
          default: a real redraw that keeps the pose and the project's look)
          -> art/dino-v2/new/KEY/south.png.
rotate    2-9 generations. create_character mode v3 with that front view as
          the reference (it is the identity; the text only guides the turn):
          8 directions -> art/dino-v2/new/KEY/character.zip and <dir>.png.
drawings  The east (side), south (down) and north (up) views, cropped to the
          animal and bottom-centred on a W x H frame, written where
          prepare.py reads them: game/Forest/creatures/art/KEY[_down|_up].png.
"""
import argparse
import io
import json
import os
import re
import sys
import time
import urllib.request
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
import pixellab_mcp as pl  # noqa: E402
from PIL import Image  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
ART = os.path.join(ROOT, "game", "Forest", "creatures", "art")
NEW = os.path.join(ROOT, "art", "dino-v2", "new")
FRAME = {"dodo": (20, 24), "longneck": (70, 60), "raptor": (42, 32), "rex": (76, 56), "stego": (60, 40), "trike": (54, 42),
         "alpha": (84, 60), "allo": (64, 46), "lystro": (24, 20), "parasaur": (76, 52), "ossuar": (84, 64),
         "dimetrodon": (60, 56), "carno": (68, 70), "yuty": (68, 68), "anky": (56, 52), "proto": (32, 30), "compy": (24, 20)}
UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) CraveraDino/1.0"}


def first_cel(species, view):
    w, h = FRAME[species]
    path = os.path.join(ART, species + ("" if view == "side" else "_" + view) + ".png")
    return Image.open(path).convert("RGBA").crop((0, 0, w, h))


def job_id(text):
    m = re.search(r"\b([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\b", text)
    if not m:
        raise SystemExit("no job id in reply:\n" + text)
    return m.group(1)


DIRECTION = {"down": "south", "side": "east", "up": "north"}


def restyle(key, species, scale, canvas, desc, keep, view="down", palette=None):
    out = os.path.join(NEW, key)
    os.makedirs(out, exist_ok=True)
    cel = first_cel(species, view)
    cel = cel.crop(cel.getbbox())
    cel = cel.resize((round(cel.width * scale), round(cel.height * scale)), Image.NEAREST)
    board = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    board.alpha_composite(cel, ((canvas - cel.width) // 2, canvas - 4 - cel.height))
    init = os.path.join(out, "init_%s.png" % view)
    board.save(init)
    args = {"description": desc, "width": canvas, "height": canvas, "no_background": True,
            "init_image_base64": pl.inline_files("@" + init), "init_image_strength": keep,
            "view": "low top-down", "direction": DIRECTION[view], "outline": "single color black outline",
            "shading": "medium shading", "detail": "highly detailed"}
    if palette:
        args["color_image_base64"] = pl.inline_files("@" + palette)
    client = pl.Client()
    reply = pl.text_of(client.call("create_image_pixflux", args))
    job = job_id(reply)
    print("restyle job", job, flush=True)
    # Each view downloads into its own folder: views restyled at the same
    # time must not trade files.
    tmp = os.path.join(out, "tmp_" + view)
    os.makedirs(tmp, exist_ok=True)
    pl.cmd_wait(job, tmp)
    os.replace(os.path.join(tmp, "000.png"), os.path.join(out, DIRECTION[view] + ".png"))
    print("wrote", os.path.join(out, DIRECTION[view] + ".png"))


def rotate(key, desc):
    out = os.path.join(NEW, key)
    south = os.path.join(out, "south.png")
    args = {"description": desc, "mode": "v3", "reference_image_base64": pl.inline_files("@" + south),
            "name": key, "view": "low top-down"}
    client = pl.Client()
    reply = pl.text_of(client.call("create_character", args))
    character = job_id(reply)
    print("character", character, flush=True)
    url = "https://api.pixellab.ai/mcp/characters/%s/download" % character
    for attempt in range(90):
        try:
            data = urllib.request.urlopen(urllib.request.Request(url, headers=UA)).read()
            if data[:2] == b"PK":
                break
        except Exception:
            pass
        time.sleep(10)
    else:
        raise SystemExit("character not ready: " + character)
    open(os.path.join(out, "character.zip"), "wb").write(data)
    z = zipfile.ZipFile(io.BytesIO(data))
    meta = json.loads(z.read("metadata.json"))
    rotations = meta["states"][0]["frames"]["rotations"]
    for direction, path in rotations.items():
        Image.open(io.BytesIO(z.read(path))).convert("RGBA").save(os.path.join(out, direction + ".png"))
    json.dump({"character": character}, open(os.path.join(out, "character.json"), "w"))
    print("wrote", len(rotations), "views to", out)


def drawings(key, w, h):
    out = os.path.join(NEW, key)
    for view, direction in (("side", "east"), ("down", "south"), ("up", "north")):
        img = Image.open(os.path.join(out, direction + ".png")).convert("RGBA")
        img = img.crop(img.getbbox())
        if img.width > w or img.height > h:
            raise SystemExit("%s %s view %s is bigger than the frame %dx%d" % (key, view, img.size, w, h))
        frame = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        frame.alpha_composite(img, ((w - img.width) // 2, h - img.height))
        path = os.path.join(ART, key + ("" if view == "side" else "_" + view) + ".png")
        frame.save(path)
        print(view, img.size, "->", path)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("cmd", choices=("restyle", "rotate", "drawings"))
    p.add_argument("key")
    p.add_argument("--from", dest="species")
    p.add_argument("--scale", type=float, default=1.0)
    p.add_argument("--canvas", type=int, default=96)
    p.add_argument("--desc", default="")
    p.add_argument("--keep", type=int, default=160)
    p.add_argument("--frame", type=int, nargs=2)
    p.add_argument("--view", default="down", choices=("down", "side", "up"))
    p.add_argument("--palette", default=None)
    a = p.parse_args()
    if a.cmd == "restyle":
        restyle(a.key, a.species, a.scale, a.canvas, a.desc, a.keep, a.view, a.palette)
    elif a.cmd == "rotate":
        rotate(a.key, a.desc)
    else:
        drawings(a.key, *a.frame)


if __name__ == "__main__":
    main()
