"""Review strips of cleaned clips, cropped to the union of their content.

    python tools/dino/peek.py KEY CLIP[,CLIP...] [VIEW[,VIEW...]] [--scale 2] [--out path.png]

One row per clip x view, frames left to right, on the forest-green review
background. Writes art/dino-v2/peek.png unless --out is given.
"""
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CLIPS = os.path.join(ROOT, "art", "dino-v2", "clips")


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    scale = int(sys.argv[sys.argv.index("--scale") + 1]) if "--scale" in sys.argv else 2
    out = sys.argv[sys.argv.index("--out") + 1] if "--out" in sys.argv else os.path.join(ROOT, "art", "dino-v2", "peek.png")
    if "--scale" in sys.argv:
        args = [a for a in args if a != str(scale)]
    if "--out" in sys.argv:
        args = [a for a in args if a != out]
    key, clips = args[0], args[1].split(",")
    views = args[2].split(",") if len(args) > 2 else ["side", "down", "up"]
    rows = []
    for clip in clips:
        for view in views:
            d = os.path.join(CLIPS, key, "%s_%s" % (clip, view))
            if not os.path.isdir(d):
                continue
            fr = [Image.open(os.path.join(d, n)).convert("RGBA") for n in sorted(os.listdir(d)) if n.endswith(".png")]
            if fr:
                rows.append(("%s %s" % (clip, view), fr))
    if not rows:
        sys.exit("nothing to show")
    box = None
    for _, fr in rows:
        for f in fr:
            b = f.getbbox()
            if b:
                box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    box = (max(0, box[0] - 2), max(0, box[1] - 2), box[2] + 2, box[3] + 2)
    w, h = box[2] - box[0], box[3] - box[1]
    cols = max(len(fr) for _, fr in rows)
    label = 12
    sheet = Image.new("RGBA", (cols * (w + 1) * scale, len(rows) * (h * scale + label)), (72, 96, 60, 255))
    draw = ImageDraw.Draw(sheet)
    for r, (name, fr) in enumerate(rows):
        y = r * (h * scale + label)
        draw.text((2, y), name, fill=(255, 240, 200, 255))
        for i, f in enumerate(fr):
            sheet.alpha_composite(f.crop(box).resize((w * scale, h * scale), Image.NEAREST), (i * (w + 1) * scale, y + label))
            if "--numbers" in sys.argv:
                draw.text((i * (w + 1) * scale + w * scale - 12, y), str(i), fill=(255, 255, 120, 255))
    sheet.save(out)
    print(out, sheet.size)


if __name__ == "__main__":
    main()
