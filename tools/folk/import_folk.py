"""Import the folk's PixelLab characters into the game.

    python tools/folk/import_folk.py [guide merchant warden]

Downloads each character's zip (rotations + the "idle" and "walk" animations,
south/north/east/west), keeps the raw frames in art/folk/source/<id>/, and
writes game/Forest/folk/art/<id>/sheet.png + sheet.json for FolkActor:
  {"cell": N, "foot": [x, y], "animations": {"idle_down": {"fps": 5,
   "frames": [[col, row], ...]}, ...}}
Rows are idle_down, idle_up, idle_left, idle_right, walk_down ... walk_right;
"foot" is the pixel under the feet (the bottom of the idle-down frame), where
the actor stands. The characters were made with create_character_pro_flash
(32x32, the Keeper's south view as the style reference) and animated with the
walking-8-frames and breathing-idle templates (1 generation per direction).
"""
import io
import json
import os
import sys
import time
import urllib.error
import urllib.request
import zipfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
CAST = {
    "guide": "c66d9ff6-5bef-4f97-af5f-da8d8fc5855d",
    "merchant": "b420ff4c-88b6-4446-922e-26611b9996c2",
    "warden": "9b7ce210-0e4c-4670-96e4-3ddcc614fe84",
}
UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) FolkPipeline/1.0"}
FACING = {"south": "down", "north": "up", "west": "left", "east": "right"}
FPS = {"idle": 5, "walk": 10}


def fetch(character_id, retries=30):
    url = "https://api.pixellab.ai/mcp/characters/%s/download" % character_id
    for _ in range(retries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA)) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code == 423:
                time.sleep(int(e.headers.get("Retry-After", "5")))
                continue
            raise
        except OSError:
            time.sleep(2)
    raise TimeoutError(url)


def build(folk_id):
    data = fetch(CAST[folk_id])
    z = zipfile.ZipFile(io.BytesIO(data))
    meta = json.loads(z.read("metadata.json"))
    state = meta["states"][0]
    source = os.path.join(ROOT, "art", "folk", "source", folk_id)
    os.makedirs(source, exist_ok=True)
    with open(os.path.join(source, "character.zip"), "wb") as f:
        f.write(data)
    anims = state["frames"]["animations"]
    rows = []
    for kind in ("idle", "walk"):
        if kind not in anims:
            raise SystemExit("%s has no '%s' animation yet" % (folk_id, kind))
        for compass in ("south", "north", "west", "east"):
            frames = [Image.open(io.BytesIO(z.read(p))).convert("RGBA") for p in anims[kind][compass]]
            rows.append(("%s_%s" % (kind, FACING[compass]), kind, frames))
    cell = max(max(f.width, f.height) for _, _, frames in rows for f in frames)
    cols = max(len(frames) for _, _, frames in rows)
    sheet = Image.new("RGBA", (cols * cell, len(rows) * cell), (0, 0, 0, 0))
    index = {"cell": cell, "animations": {}}
    for r, (name, kind, frames) in enumerate(rows):
        spots = []
        for c, frame in enumerate(frames):
            # Frames share one canvas size per animation; centre them in the cell.
            sheet.alpha_composite(frame, (c * cell + (cell - frame.width) // 2, r * cell + (cell - frame.height) // 2))
            spots.append([c, r])
        index["animations"][name] = {"fps": FPS[kind], "frames": spots}
    # Feet: the lowest opaque row of the first idle-down frame, its middle column.
    first = sheet.crop((0, 0, cell, cell))
    box = first.getbbox()
    index["foot"] = [(box[0] + box[2]) // 2, box[3] - 1]
    out = os.path.join(ROOT, "game", "Forest", "folk", "art", folk_id)
    os.makedirs(out, exist_ok=True)
    sheet.save(os.path.join(out, "sheet.png"))
    with open(os.path.join(out, "sheet.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(index, f, indent=1)
    print(folk_id, "sheet", sheet.size, "cell", cell, "foot", index["foot"])


def main():
    for folk_id in sys.argv[1:] or list(CAST):
        build(folk_id)


if __name__ == "__main__":
    main()
