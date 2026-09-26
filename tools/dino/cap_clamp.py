"""Clear whatever grows out of the top of a loop's resting silhouette.

    python tools/dino/cap_clamp.py KEY CLIP_VIEW [CLIP_VIEW ...] [--tol N] [--cap ROWS]

The saddled trike's front walk and run sprouted a post out of the saddle's
cantle (the run also a dark smear over the frill) that pops in and out of the
loop; the row clamp in gen.py only caps how high such things may reach. This
follows each frame's bob (the resting top band matched onto the frame, as
export.py tracks saddles) and clears every pixel above the resting drawing's
own top in that column, moved by the bob, plus `tol` rows of give.

A growth standing in the same columns as the resting top (the walk's post
rises right behind the horn) is inside that profile; `--cap ROWS` instead
replaces each frame's top ROWS rows with the resting drawing's (the horn and
the top of the saddle), moved by the frame's bob, and clears anything above.

Pieces the clearing cuts loose from the body (a flare's tip beyond the resting
width) are dropped as specks.

Works on the cleaned frames in place, so run it after `gen.py run`/`clean`;
the ledger records it, and `gen.py clean` then leaves the clip alone.
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen  # noqa: E402

OUT = gen.OUT
# Rows (below the resting top) used to follow the bob: the frill and face,
# not the very top, where the growths themselves would pull the match.
BAND = (5, 22)
RADIUS = 3
SPECK = 25  # a piece this small and more than 2 px off the body is dropped


def column_tops(img):
    px = img.load()
    tops = {}
    for x in range(img.width):
        for y in range(img.height):
            if px[x, y][3]:
                tops[x] = y
                break
    return tops


def top_band(img):
    box = img.getbbox()
    px = img.load()
    return [(x, y, px[x, y][:3]) for y in range(box[1] + BAND[0], min(img.height, box[1] + BAND[1]))
            for x in range(img.width) if px[x, y][3]]


def track(frame, band):
    px = frame.load()
    w, h = frame.size
    best, best_off = -1, (0, 0)
    for dy in range(-RADIUS, RADIUS + 1):
        for dx in range(-RADIUS, RADIUS + 1):
            score = 0
            for x, y, c in band:
                q = (x + dx, y + dy)
                if 0 <= q[0] < w and 0 <= q[1] < h:
                    p = px[q]
                    if p[3] and abs(p[0] - c[0]) + abs(p[1] - c[1]) + abs(p[2] - c[2]) < 60:
                        score += 1
            score = score * 100 - abs(dx) - abs(dy)
            if score > best:
                best, best_off = score, (dx, dy)
    return best_off


def drop_specks(img):
    """Clear the small 8-connected pieces (under SPECK pixels) lying more than
    2 px from the largest one, the body: clean.py's island rule, applied again
    after the clearing. Returns how many pixels went."""
    px = img.load()
    w, h = img.size
    seen = set()
    pieces = []
    for y in range(h):
        for x in range(w):
            if (x, y) in seen or not px[x, y][3]:
                continue
            stack, piece = [(x, y)], []
            seen.add((x, y))
            while stack:
                cx, cy = stack.pop()
                piece.append((cx, cy))
                for nx in (cx - 1, cx, cx + 1):
                    for ny in (cy - 1, cy, cy + 1):
                        if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and px[nx, ny][3]:
                            seen.add((nx, ny))
                            stack.append((nx, ny))
            pieces.append(piece)
    pieces.sort(key=len, reverse=True)
    body = set(pieces[0]) if pieces else set()
    gone = 0
    for piece in pieces[1:]:
        near = any((qx + ox, qy + oy) in body for qx, qy in piece for ox in range(-3, 4) for oy in range(-3, 4)
                   if max(abs(ox), abs(oy)) <= 2)
        if len(piece) < SPECK and not near:
            for q in piece:
                px[q] = (0, 0, 0, 0)
            gone += len(piece)
    return gone


def clamp(key, name, tol, cap=0):
    d = os.path.join(OUT, "clips", key, name)
    names = sorted(n for n in os.listdir(d) if n.endswith(".png"))
    ref = Image.open(os.path.join(d, names[0])).convert("RGBA")
    tops = column_tops(ref)
    band = top_band(ref)
    cleared = []
    for n in names[1:]:
        path = os.path.join(d, n)
        f = Image.open(path).convert("RGBA")
        dx, dy = track(f, band)
        px = f.load()
        count = 0
        if cap:
            box = ref.getbbox()
            cut = box[1] + cap
            rpx = ref.load()
            for x in range(f.width):
                for y in range(max(0, min(f.height, cut + dy))):
                    if px[x, y][3]:
                        px[x, y] = (0, 0, 0, 0)
                        count += 1
            for y in range(box[1], cut):
                for x in range(box[0], box[2]):
                    q = (x + dx, y + dy)
                    if rpx[x, y][3] and 0 <= q[0] < f.width and 0 <= q[1] < f.height:
                        px[q] = rpx[x, y]
        for x in range(f.width):
            top = tops.get(x - dx)
            if top is None:
                continue
            for y in range(max(0, top + dy - tol)):
                if px[x, y][3]:
                    px[x, y] = (0, 0, 0, 0)
                    count += 1
        count += drop_specks(f)
        f.save(path)
        cleared.append((dx, dy, count))
    led = gen.load_ledger(key)
    e = led.get(name, {})
    e["method"] = "AI clip + cap_clamp.py (%s)" % ("cap %d" % cap if cap else "tol %d" % tol)
    led[name] = e
    gen.save_ledger(key, led)
    print(key, name, "(bob dx, dy, pixels cleared) per frame:", cleared)


def main():
    tol = int(sys.argv[sys.argv.index("--tol") + 1]) if "--tol" in sys.argv else 1
    cap = int(sys.argv[sys.argv.index("--cap") + 1]) if "--cap" in sys.argv else 0
    args = [a for i, a in enumerate(sys.argv[1:], 1) if not a.startswith("--") and sys.argv[i - 1] not in ("--tol", "--cap")]
    key = args[0]
    for name in args[1:]:
        clamp(key, name, tol, cap)


if __name__ == "__main__":
    main()
