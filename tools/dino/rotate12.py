"""Pass 12: turn a new beast's chosen side view (art/dino-v2/new/KEY/east.png)
into the other facings with PixelLab create_character v3 (2-9 generations),
for animals whose front/back restyles wouldn't read (the dimetrodon's sail
seen edge-on, the ankylosaur's shell).

    python tools/dino/rotate12.py KEY --desc "..." [--size N]

Writes art/dino-v2/new/KEY/rot/<direction>.png (all 8).
"""
import io
import json
import os
import sys
import time
import urllib.request
import zipfile

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.dirname(HERE))
sys.path.insert(0, HERE)
import pixellab_mcp as pl  # noqa: E402
from new_species import UA, job_id  # noqa: E402


def main():
    key = sys.argv[1]
    desc = sys.argv[sys.argv.index("--desc") + 1]
    size = int(sys.argv[sys.argv.index("--size") + 1]) if "--size" in sys.argv else 0
    new = os.path.join(ROOT, "art", "dino-v2", "new", key)
    out = os.path.join(new, "rot")
    os.makedirs(out, exist_ok=True)
    side = Image.open(os.path.join(new, "east.png")).convert("RGBA")
    side = side.crop(side.getbbox())
    n = size or max(side.width, side.height) + 16
    board = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    board.alpha_composite(side, ((n - side.width) // 2, n - 4 - side.height))
    ref = os.path.join(out, "reference.png")
    board.save(ref)
    args = {"description": desc, "mode": "v3", "reference_image_base64": pl.inline_files("@" + ref),
            "name": key + "_rot", "view": "low top-down"}
    client = pl.Client()
    character = job_id(pl.text_of(client.call("create_character", args)))
    print("character", character, flush=True)
    url = "https://api.pixellab.ai/mcp/characters/%s/download" % character
    for attempt in range(120):
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


if __name__ == "__main__":
    main()
