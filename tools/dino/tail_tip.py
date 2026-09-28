"""Pass 13: finish a tail that runs off the left edge of a v3 drawing (the
spinosaur's side view: PixelLab drew it 96 px wide with the paddle tail cut
flat at x=0).

The tail is continued EXTEND px to the left: every new column is a copy of the
drawing's own edge column, squeezed toward the tail's centre line so the
silhouette tapers to a rounded tip, then outlined in the drawing's darkest
outline colour. Colours are the drawing's own (copied rows), so the red paddle
fin carries on above and below the tail.

    python tools/dino/tail_tip.py IN.png OUT.png [--extend 11]
"""
import argparse
from PIL import Image


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("dst")
    ap.add_argument("--extend", type=int, default=11)
    a = ap.parse_args()
    im = Image.open(a.src).convert("RGBA")
    w, h = im.size
    px = im.load()
    # The edge column's opaque run (the cut tail).
    rows = [y for y in range(h) if px[0, y][3] > 0]
    if not rows:
        print("nothing at the left edge")
        return
    top, bot = min(rows), max(rows)
    mid = (top + bot) / 2.0
    half = (bot - top) / 2.0
    # The outline colour: the darkest opaque pixel on the drawing.
    dark = min((px[x, y] for x in range(w) for y in range(h) if px[x, y][3] > 0), key=lambda c: c[0] + c[1] + c[2])
    ext = a.extend
    out = Image.new("RGBA", (w + ext, h), (0, 0, 0, 0))
    out.alpha_composite(im, (ext, 0))
    op = out.load()
    # Body pixels of the source edge column (inside its outline).
    src = {y: px[1, y] for y in range(top, bot + 1) if px[1, y][3] > 0}
    for i in range(1, ext + 1):
        x = ext - i
        t = i / float(ext)
        # A tip that rounds off: the span shrinks slowly, then fast.
        k = (1.0 - t ** 2.2)
        span = half * k
        # The tail droops a little as it goes.
        c = mid + t * 1.5
        lo, hi = int(round(c - span)), int(round(c + span))
        if hi < lo:
            continue
        for y in range(lo, hi + 1):
            # Map this row back to the source column's rows.
            f = (y - c) / max(span, 0.5)
            sy = int(round(mid + f * half))
            sy = max(top, min(bot, sy))
            col = src.get(sy)
            if col is None:
                continue
            op[x, y] = col
    # Outline the new part.
    add = []
    for x in range(0, ext + 1):
        for y in range(h):
            if op[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < ext and 0 <= ny < h and op[nx, ny][3] > 0 and op[nx, ny][:3] != dark[:3]:
                        add.append((x, y))
                        break
    for x, y in add:
        op[x, y] = dark
    out.save(a.dst)
    print("tail extended", a.extend, "px:", a.dst, out.size)


if __name__ == "__main__":
    main()
