"""Contact strip of an animation folder (000.png, 001.png, ...) for review.

    python tools/dino/strip.py <frames_dir> <out.png> [--scale 4] [--bg 5c784a] [--cols N]

Frames are laid out left to right (wrapping after --cols) on a flat
background with a 1 px gap, plus a thin baseline guide at each frame's lowest
opaque row so ground drift is easy to spot.
"""
import os
import sys

from PIL import Image, ImageDraw


def main():
    src, out = sys.argv[1], sys.argv[2]
    scale = int(sys.argv[sys.argv.index("--scale") + 1]) if "--scale" in sys.argv else 4
    bg = sys.argv[sys.argv.index("--bg") + 1] if "--bg" in sys.argv else "5c784a"
    names = sorted(n for n in os.listdir(src) if n.endswith(".png") and n[:3].isdigit())
    frames = [Image.open(os.path.join(src, n)).convert("RGBA") for n in names]
    if not frames:
        sys.exit("no frames in " + src)
    cols = int(sys.argv[sys.argv.index("--cols") + 1]) if "--cols" in sys.argv else len(frames)
    w = max(f.width for f in frames)
    h = max(f.height for f in frames)
    rows = (len(frames) + cols - 1) // cols
    sheet = Image.new("RGBA", ((w + 1) * cols * scale, (h + 1) * rows * scale), "#" + bg)
    draw = ImageDraw.Draw(sheet)
    for i, f in enumerate(frames):
        x = (i % cols) * (w + 1) * scale
        y = (i // cols) * (h + 1) * scale
        sheet.alpha_composite(f.resize((f.width * scale, f.height * scale), Image.NEAREST), (x, y))
        box = f.getbbox()
        if box:
            base = y + box[3] * scale
            draw.line([(x, base), (x + w * scale, base)], fill=(255, 230, 120, 140), width=1)
    sheet.save(out)
    print(out, sheet.size, len(frames), "frames")


if __name__ == "__main__":
    main()
