"""Redraw one view of a creature with PixelLab pixflux (1 generation), for a
view whose drawing doesn't read as the animal (pass 12: the parasaur's front
view, a narrow head under a thin dark stick for a crest).

    python tools/dino/redraw_view.py KEY OUT_NAME --desc "..." [--view down|side|up]
        [--init PATH --keep N] [--size W H] [--seed S]

With --init the image (any size, pasted bottom-centre on the canvas) is
redrawn keeping --keep of it (pixflux: 500 barely changes it, ~150 is a real
edit); without it the animal is drawn from the words alone. The species'
palette (art/dino-v2/palettes/KEY.hex) is always forced, so the result sits
with its other drawings. Writes art/dino-v2/new/KEY/redraw/OUT_NAME.png.
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.dirname(HERE))
import pixellab_mcp as pl  # noqa: E402
from new_species import job_id  # noqa: E402

DIRECTION = {"down": "south", "side": "east", "up": "north"}


def palette_swatch(key, out_dir):
    colours = open(os.path.join(ROOT, "art", "dino-v2", "palettes", key.split("_")[0] + ".hex")).read().split()
    cols = 8
    cell = 6
    rows = (len(colours) + cols - 1) // cols
    img = Image.new("RGBA", (cols * cell, rows * cell), (0, 0, 0, 0))
    for i, hexc in enumerate(colours):
        c = tuple(int(hexc[j:j + 2], 16) for j in (0, 2, 4)) + (255,)
        x, y = (i % cols) * cell, (i // cols) * cell
        for yy in range(y, y + cell):
            for xx in range(x, x + cell):
                img.putpixel((xx, yy), c)
    path = os.path.join(out_dir, "palette.png")
    img.save(path)
    return path


def main():
    args = sys.argv[1:]
    key, name = args[0], args[1]

    def opt(flag, default=None, n=1):
        if flag not in args:
            return default
        i = args.index(flag)
        return args[i + 1] if n == 1 else args[i + 1:i + 1 + n]

    desc = opt("--desc")
    view = opt("--view", "down")
    w, h = [int(v) for v in opt("--size", ["72", "72"], 2)]
    out_dir = os.path.join(ROOT, "art", "dino-v2", "new", key, "redraw")
    os.makedirs(out_dir, exist_ok=True)
    call = {"description": desc, "width": w, "height": h, "no_background": True,
            "view": "low top-down", "direction": DIRECTION[view], "outline": "single color black outline",
            "shading": "medium shading", "detail": "highly detailed",
            "color_image_base64": pl.inline_files("@" + palette_swatch(key, out_dir))}
    if opt("--seed"):
        call["seed"] = int(opt("--seed"))
    init = opt("--init")
    if init:
        img = Image.open(init).convert("RGBA")
        img = img.crop(img.getbbox())
        board = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        board.alpha_composite(img, ((w - img.width) // 2, h - 4 - img.height))
        init_path = os.path.join(out_dir, name + "_init.png")
        board.save(init_path)
        call["init_image_base64"] = pl.inline_files("@" + init_path)
        call["init_image_strength"] = int(opt("--keep", "150"))
    client = pl.Client()
    job = job_id(pl.text_of(client.call("create_image_pixflux", call)))
    print("job", job, flush=True)
    tmp = os.path.join(out_dir, "tmp_" + name)
    os.makedirs(tmp, exist_ok=True)
    pl.cmd_wait(job, tmp)
    os.replace(os.path.join(tmp, "000.png"), os.path.join(out_dir, name + ".png"))
    print("wrote", os.path.join(out_dir, name + ".png"))


if __name__ == "__main__":
    main()
