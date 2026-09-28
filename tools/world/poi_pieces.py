"""Split point-of-interest art into pieces: depth, collision and shadows.

    python tools/world/poi_pieces.py        (make_poi_art.py runs it too)

Each ruin or idol drawing in game/Forest/art/poi is split into its separate
parts (8-connected opaque regions; specks and soft edges join their nearest
part). Every part becomes game/Forest/art/poi/pieces/<kind>_<n>.png and an
entry in pieces.json:
  pos     the part's top-left in the whole drawing
  size    the part's size
  base    the part's lowest opaque row in the whole drawing (its ground line)
  solid   collision rects [x, y, w, h] in whole-drawing pixels
The game (ForestProp) draws each part as its own y-sorted sprite standing on
its base, so the keeper can walk among the stones of a ring and behind the
near ones; makes each part solid at its foot, a band that follows the part's
bottom edge and is as deep as the part is solid (passages under arches and
between a grove's trunks stay open); and casts a sun shadow from each part
(ForestLighting). art/world-v2/poi-shapes.png shows the solids over the art.
"""
import json
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
POI = os.path.join(ROOT, "game", "Forest", "art", "poi")
PIECES = os.path.join(POI, "pieces")
REVIEW = os.path.join(ROOT, "art", "world-v2", "poi-shapes.png")

KINDS = ["ruin_temple", "ruin_statue", "ruin_tower", "ruin_stairs", "ruin_pillar", "ruin_hall", "ruin_arch",
         "ruin_column", "ruin_stones", "ruin_boulders", "idol_deer", "idol_wolf", "idol_human", "grove_shrine"]
# Gateways: a column whose foot is far above both neighbours is a passage.
GATES = {"ruin_arch"}
# Rings of stones that touch in the drawing: parted where they only just meet.
STONES = {"ruin_stones", "ruin_boulders"}
# Hand-set footings (whole-drawing px). Living trees are solid at their trunks
# and roots; the grove's middle, under the crystal, is the way through. The
# arch is solid under its walls and pillars; the way under it, over the fallen
# rubble, is open.
TRUNKS = {
    "ruin_arch": [[2, 37, 26, 12], [44, 36, 30, 13]],
    "idol_deer": [[30, 64, 37, 25]],
    "idol_wolf": [[12, 56, 34, 17]],
    "idol_human": [[30, 78, 64, 24], [22, 88, 8, 12], [94, 88, 8, 12]],
    "grove_shrine": [[16, 90, 18, 17], [42, 96, 12, 11], [78, 88, 20, 19]],
}
SOLID_ALPHA = 128
SPECK = 16          # parts smaller than this (pixels) join their nearest part
PEBBLE_AREA = 30    # parts smaller than this, or under 6px tall, stay walkable


def label_parts(img):
    """8-connected parts of the opaque pixels; returns (label grid, pixel lists)."""
    w, h = img.size
    alpha = img.getchannel("A").load()
    label = [[-1] * w for _ in range(h)]
    parts = []
    for y in range(h):
        for x in range(w):
            if alpha[x, y] < SOLID_ALPHA or label[y][x] >= 0:
                continue
            index = len(parts)
            label[y][x] = index
            stack, pixels = [(x, y)], []
            while stack:
                cx, cy = stack.pop()
                pixels.append((cx, cy))
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        nx, ny = cx + dx, cy + dy
                        if 0 <= nx < w and 0 <= ny < h and label[ny][nx] < 0 and alpha[nx, ny] >= SOLID_ALPHA:
                            label[ny][nx] = index
                            stack.append((nx, ny))
            parts.append(pixels)
    return label, parts


def merge_specks(label, parts):
    """Specks join the part nearest to them (by closest pixel)."""
    big = [i for i, p in enumerate(parts) if len(p) >= SPECK] or [max(range(len(parts)), key=lambda i: len(parts[i]))]
    target = {}
    for i, pixels in enumerate(parts):
        if i in big:
            continue
        best, best_d = big[0], 1e9
        for j in big:
            for (x, y) in pixels[:8]:
                for (bx, by) in parts[j][::3]:
                    d = (bx - x) ** 2 + (by - y) ** 2
                    if d < best_d:
                        best, best_d = j, d
        target[i] = best
    for i, j in target.items():
        for (x, y) in parts[i]:
            label[y][x] = j
        parts[j].extend(parts[i])
    return label, [parts[i] if i in big else [] for i in range(len(parts))]


def part_stones(label, parts, w, h):
    """Stones that only just touch become separate parts: erode each part twice,
    label what is left, and give every pixel to the nearest eroded core."""
    out = []
    for pixels in parts:
        if len(pixels) < 2 * PEBBLE_AREA:
            out.append(pixels)
            continue
        inside = set(pixels)
        core = inside
        for _ in range(2):
            core = {(x, y) for (x, y) in core if all((x + dx, y + dy) in core for dx in (-1, 0, 1) for dy in (-1, 0, 1))}
        seeds, owner = [], {}
        for start in core:
            if start in owner:
                continue
            index = len(seeds)
            stack, grown = [start], []
            owner[start] = index
            while stack:
                cx, cy = stack.pop()
                grown.append((cx, cy))
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        n = (cx + dx, cy + dy)
                        if n in core and n not in owner:
                            owner[n] = index
                            stack.append(n)
            seeds.append(grown)
        big = [i for i, g in enumerate(seeds) if len(g) >= 12]
        if len(big) < 2:
            out.append(pixels)
            continue
        claim = {p: owner[p] for p in core if owner[p] in big}
        frontier = list(claim)
        while frontier:
            nxt = []
            for (x, y) in frontier:
                for dy in (-1, 0, 1):
                    for dx in (-1, 0, 1):
                        n = (x + dx, y + dy)
                        if n in inside and n not in claim:
                            claim[n] = claim[(x, y)]
                            nxt.append(n)
            frontier = nxt
        groups = {}
        for p, i in claim.items():
            groups.setdefault(i, []).append(p)
        out.extend(groups.values())
    for index, pixels in enumerate(out):
        for (x, y) in pixels:
            label[y][x] = index
    return label, out


def soft_edges(img, label):
    """Semi-transparent pixels join the part of their nearest solid neighbour."""
    w, h = img.size
    alpha = img.getchannel("A").load()
    frontier = [(x, y) for y in range(h) for x in range(w) if label[y][x] >= 0]
    while frontier:
        nxt = []
        for (x, y) in frontier:
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and label[ny][nx] < 0 and alpha[nx, ny] > 0:
                        label[ny][nx] = label[y][x]
                        nxt.append((nx, ny))
        frontier = nxt
    return label


def solids(pixels, gate, stones=False):
    """Collision for one part: a band under its bottom edge, as deep as the part
    is solid. Only feet in the lower half count (a leaf tip is no foot). A
    column whose foot is far above both neighbours is a doorway: a gateway
    (an arch) keeps it open, a solid ruin is closed across it (you cannot walk
    into a ruin drawn as one sprite). In a pile of stones every stone stands on
    its own bottom edge, so each run of pixels down a column has a foot."""
    xs = [p[0] for p in pixels]
    ys = [p[1] for p in pixels]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    pw, ph = x1 - x0 + 1, y1 - y0 + 1
    if ph < 6 or len(pixels) < PEBBLE_AREA:
        return []
    depth = max(4, min(28, round(min(0.4 * ph, 0.45 * pw))))
    if stones:
        return stone_feet(pixels, x0, x1, y0, y1)
    foot = {}
    for (x, y) in pixels:
        foot[x] = max(foot.get(x, -1), y)
    keep = {}
    for x, b in foot.items():
        if b < y1 - max(6, ph * 0.45):
            continue
        keep[x] = b
    for x in list(keep):
        left = [keep[i] for i in range(x - 14, x) if i in keep]
        right = [keep[i] for i in range(x + 1, x + 15) if i in keep]
        if left and right and keep[x] < min(max(left), max(right)) - 8:
            if gate:
                del keep[x]
            else:
                keep[x] = min(max(left), max(right))
    return bands(keep, depth, y0)


def stone_feet(pixels, x0, x1, y0, y1):
    """Feet of every stone in a pile: the bottom of each run down each column."""
    column = {}
    for (x, y) in pixels:
        column.setdefault(x, set()).add(y)
    feet = []
    for x in range(x0, x1 + 1):
        run = 0
        for y in range(y0, y1 + 2):
            if y in column.get(x, ()):
                run += 1
            elif run:
                if run >= 4:
                    feet.append((x, y - 1, run))
                run = 0
    rects = []
    used = set()
    for i, (x, b, run) in enumerate(feet):
        if i in used:
            continue
        group = [(x, b, run)]
        used.add(i)
        grew = True
        while grew:
            grew = False
            for j, (fx, fb, fr) in enumerate(feet):
                if j in used:
                    continue
                last = group[-1]
                if fx == last[0] + 1 and abs(fb - last[1]) <= 3:
                    group.append((fx, fb, fr))
                    used.add(j)
                    grew = True
        if len(group) < 3:
            continue
        depth = max(4, min(12, round(0.4 * min(r for _, _, r in group))))
        top = min(g[1] for g in group) - depth + 1
        rects.append([group[0][0], top, group[-1][0] - group[0][0] + 1, max(g[1] for g in group) - top + 1])
    return rects


def bands(keep, depth, y0):
    rects, run = [], []

    def flush():
        if len(run) < 3:
            return
        feet = [keep[x] for x in run]
        top = max(y0, min(feet) - depth + 1)
        rects.append([run[0], top, run[-1] - run[0] + 1, max(feet) - top + 1])

    for x in sorted(keep):
        if run and (x != run[-1] + 1 or abs(keep[x] - keep[run[0]]) > 3):
            flush()
            run = []
        run.append(x)
    flush()
    return rects


def split(kind):
    img = Image.open(os.path.join(POI, kind + ".png")).convert("RGBA")
    label, parts = label_parts(img)
    label, parts = merge_specks(label, parts)
    w, h = img.size
    if kind in STONES:
        label, parts = part_stones(label, [p for p in parts if p], w, h)
    label = soft_edges(img, label)
    members = {}
    for y in range(h):
        for x in range(w):
            if label[y][x] >= 0:
                members.setdefault(label[y][x], []).append((x, y))
    alpha = img.getchannel("A").load()
    pieces = []
    # Back to front, so the list reads like the drawing (its order does not matter in game).
    for index in sorted(members, key=lambda i: max(p[1] for p in members[i])):
        pixels = members[index]
        xs = [p[0] for p in pixels]
        ys = [p[1] for p in pixels]
        x0, y0, x1, y1 = min(xs), min(ys), max(xs), max(ys)
        piece = Image.new("RGBA", (x1 - x0 + 1, y1 - y0 + 1), (0, 0, 0, 0))
        src = img.load()
        for (x, y) in pixels:
            piece.putpixel((x - x0, y - y0), src[x, y])
        name = "%s_%d.png" % (kind, len(pieces))
        piece.save(os.path.join(PIECES, name))
        opaque = [p for p in pixels if alpha[p[0], p[1]] >= SOLID_ALPHA]
        pieces.append({"file": name, "pos": [x0, y0], "size": [x1 - x0 + 1, y1 - y0 + 1],
                       "base": max(p[1] for p in opaque) if opaque else y1,
                       "solid": [] if kind in TRUNKS else solids(opaque, kind in GATES, kind in STONES)})
    # Trunk solids go to the part whose box holds each one's middle.
    for rect in TRUNKS.get(kind, []):
        cx, cy = rect[0] + rect[2] / 2, rect[1] + rect[3] / 2
        best = min(pieces, key=lambda pc: 0 if (pc["pos"][0] <= cx < pc["pos"][0] + pc["size"][0] and pc["pos"][1] <= cy < pc["pos"][1] + pc["size"][1]) else 1)
        best["solid"].append(rect)
    return {"size": [w, h], "pieces": pieces}


def review(data):
    """The drawings with each part's box, ground line and solids."""
    tiles = []
    for kind in KINDS:
        img = Image.open(os.path.join(POI, kind + ".png")).convert("RGBA")
        scale = 3
        big = Image.new("RGBA", (img.width * scale, img.height * scale), (46, 70, 62, 255))
        big.alpha_composite(img.resize(big.size, Image.NEAREST))
        overlay = Image.new("RGBA", big.size, (0, 0, 0, 0))
        dr = ImageDraw.Draw(overlay)
        for piece in data[kind]["pieces"]:
            px, py = piece["pos"]
            pw, ph = piece["size"]
            dr.rectangle([px * scale, py * scale, (px + pw) * scale - 1, (py + ph) * scale - 1], outline=(120, 200, 255, 160))
            dr.line([px * scale, (piece["base"] + 1) * scale - 1, (px + pw) * scale - 1, (piece["base"] + 1) * scale - 1], fill=(255, 230, 80, 255))
            for (x, y, rw, rh) in piece["solid"]:
                dr.rectangle([x * scale, y * scale, (x + rw) * scale - 1, (y + rh) * scale - 1], fill=(255, 60, 60, 110), outline=(255, 80, 80, 255))
        big.alpha_composite(overlay)
        tiles.append((kind, big))
    cols = 5
    rows = (len(tiles) + cols - 1) // cols
    cw = max(t[1].width for t in tiles) + 12
    ch = max(t[1].height for t in tiles) + 24
    sheet = Image.new("RGBA", (cw * cols, ch * rows), (24, 34, 32, 255))
    dr = ImageDraw.Draw(sheet)
    for i, (kind, big) in enumerate(tiles):
        x, y = (i % cols) * cw + 6, (i // cols) * ch + 18
        sheet.alpha_composite(big, (x, y))
        dr.text((x, y - 14), "%s  (%d parts)" % (kind, len(data[kind]["pieces"])), fill=(255, 255, 255, 255))
    os.makedirs(os.path.dirname(REVIEW), exist_ok=True)
    sheet.save(REVIEW)


def main():
    os.makedirs(PIECES, exist_ok=True)
    for old in os.listdir(PIECES):
        if old.endswith(".png"):
            os.remove(os.path.join(PIECES, old))
    data = {kind: split(kind) for kind in KINDS}
    with open(os.path.join(POI, "pieces.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, indent=1, sort_keys=True)
    review(data)
    for kind in KINDS:
        print(kind, "parts", len(data[kind]["pieces"]), "solids", sum(len(p["solid"]) for p in data[kind]["pieces"]))


if __name__ == "__main__":
    main()
