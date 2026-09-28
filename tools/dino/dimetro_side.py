"""Pass 17: the dimetrodon's side-on legs (Hank: "the Dimetrodon in its side,
when it's moving sideways, its legs are a little wonky, doesn't really, like,
move properly").

    python tools/dino/dimetro_side.py        # then: python tools/dino/export.py dimetrodon

Two faults, both in its side view:
  - walk: PixelLab drew it walking in place without moving its legs (its feet
    travel 2 px/s: tools/dino/stride.py), so it slid along the ground. Its side
    walk is now its run's stride played slower: clips.json's override
    "dimetrodon/walk_side" sets that view's fps (export.py writes it as the
    clip's "fps_view"; DinoArt plays it) so the feet keep pace with its walking
    speed (BODY.dimetrodon.walk: 15 px/s; the run's feet travel 46 px/s at 13 fps).
  - run: its far hind leg is a solid black blob in frames 2 to 5. The inside of
    each thick patch of pure black below the belly becomes a leg in the body's
    shadow (a lighter edge along its top), its rim left black as the outline.
The original frames are kept in art/dino-v2/fix/dimetrodon/ (and this always
starts again from them).
"""
import os
import shutil

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CLIPS = os.path.join(ROOT, "art", "dino-v2", "clips", "dimetrodon")
KEEP = os.path.join(ROOT, "art", "dino-v2", "fix", "dimetrodon")
# Below this row (of the 112 x 96 canvas) the black is a leg's, not an eye or a mouth.
BELLY = 58
LEG = (46, 44, 49, 255)
LEG_EDGE = (62, 60, 64, 255)


def originals(clip):
    """The clip's frames as PixelLab made them (kept the first time)."""
    keep = os.path.join(KEEP, clip)
    if not os.path.isdir(keep):
        shutil.copytree(os.path.join(CLIPS, clip), keep)
    return [os.path.join(keep, n) for n in sorted(os.listdir(keep)) if n.endswith(".png")]


def shade_black_legs(img):
    """The inside of every thick patch of pure black below the belly (black
    with black all round it): a leg's silhouette. Its rim stays black (the
    outline), and so do the drawing's thin black lines of shade."""
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    black = lambda x, y: 0 <= x < w and 0 <= y < h and px[x, y][3] > 40 and px[x, y][:3] == (0, 0, 0)
    fill = set()
    for y in range(BELLY, h):
        for x in range(w):
            if black(x, y) and all(black(x + dx, y + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                fill.add((x, y))
    for x, y in sorted(fill, key=lambda c: (c[1], c[0])):
        px[x, y] = LEG if (x, y - 1) in fill else LEG_EDGE
    return img, len(fill)


def main():
    run = originals("run_side")
    originals("walk_side")
    for d in ("run_side", "walk_side"):
        out = os.path.join(CLIPS, d)
        for n in os.listdir(out):
            if n.endswith(".png"):
                os.remove(os.path.join(out, n))
    for path in run:
        fixed, n = shade_black_legs(Image.open(path))
        name = os.path.basename(path)
        fixed.save(os.path.join(CLIPS, "run_side", name))
        fixed.save(os.path.join(CLIPS, "walk_side", name))
        print("%s: %d black leg pixels shaded" % (name, n))


if __name__ == "__main__":
    main()
