"""Clean a generated dinosaur animation so it matches the original drawing.

    python tools/dino/clean.py <raw_dir> <base.png> <out_dir> [options]

  --keep-first      keep 000.png (the unchanged input frame) as frame 0
  --ground          shift each frame vertically so its lowest opaque row matches
                    the base drawing's (planted-feet clips: walk, idle, attacks)
  --anchor-x        remove horizontal drift: align each frame's body centre
                    (mean x of the upper half of opaque pixels) to the base's
  --min-speck N     drop opaque islands smaller than N px (default 4)

Every opaque pixel is snapped to the nearest colour of the base drawing's own
palette (weighted RGB), alpha becomes binary (>= 128 is opaque), and specks
disconnected from the body are removed. Output frames are 000.png... with the
same canvas size as the input.
"""
import os
import sys

from PIL import Image

N8 = ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1))


def palette_of(img):
    cols = {}
    for c in img.getdata():
        if c[3] >= 128:
            cols[c[:3]] = cols.get(c[:3], 0) + 1
    return list(cols)


def nearest(c, pal, cache):
    if c in cache:
        return cache[c]
    r, g, b = c
    best = None
    bd = 1e18
    for p in pal:
        dr, dg, db = r - p[0], g - p[1], b - p[2]
        rm = (r + p[0]) / 2
        d = (2 + rm / 256) * dr * dr + 4 * dg * dg + (2 + (255 - rm) / 256) * db * db
        if d < bd:
            bd, best = d, p
    cache[c] = best
    return best


def islands(opaque, w, h):
    seen = set()
    out = []
    for start in opaque:
        if start in seen:
            continue
        stack = [start]
        seen.add(start)
        comp = []
        while stack:
            x, y = stack.pop()
            comp.append((x, y))
            for dx, dy in N8:
                q = (x + dx, y + dy)
                if q in opaque and q not in seen:
                    seen.add(q)
                    stack.append(q)
        out.append(comp)
    return out


def body_x(img):
    box = img.getbbox()
    if not box:
        return None
    mid = (box[1] + box[3]) // 2
    xs = [x for y in range(box[1], mid) for x in range(img.width) if img.getpixel((x, y))[3] >= 128]
    return sum(xs) / len(xs) if xs else None


def clean(img, pal, cache, min_speck):
    w, h = img.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    opaque = set()
    for y in range(h):
        for x in range(w):
            c = img.getpixel((x, y))
            if c[3] >= 128:
                out.putpixel((x, y), nearest(c[:3], pal, cache) + (255,))
                opaque.add((x, y))
    comps = sorted(islands(opaque, w, h), key=len, reverse=True)
    if not comps:
        return out
    # Keep the body and whatever touches it (within 2 px); floating bits the
    # model adds (bubbles, sparks, shards, dust) are not part of the animal.
    near = set()
    for x, y in comps[0]:
        for dy in range(-2, 3):
            for dx in range(-2, 3):
                near.add((x + dx, y + dy))
    for comp in comps[1:]:
        if len(comp) < min_speck or not any(p in near for p in comp):
            for p in comp:
                out.putpixel(p, (0, 0, 0, 0))
    return out


def shifted(img, dx, dy):
    if dx == 0 and dy == 0:
        return img
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.alpha_composite(img, (dx, dy))
    return out


def main():
    raw, base_path, dst = sys.argv[1], sys.argv[2], sys.argv[3]
    args = sys.argv[4:]
    keep_first = "--keep-first" in args
    ground = "--ground" in args
    anchor_x = "--anchor-x" in args
    min_speck = int(args[args.index("--min-speck") + 1]) if "--min-speck" in args else 4
    base = Image.open(base_path).convert("RGBA")
    pal = palette_of(base)
    cache = {}
    names = sorted(n for n in os.listdir(raw) if n.endswith(".png") and n[:3].isdigit())
    if not keep_first:
        names = names[1:]
    frames = [clean(Image.open(os.path.join(raw, n)).convert("RGBA"), pal, cache, min_speck) for n in names]
    first = Image.open(os.path.join(raw, sorted(n for n in os.listdir(raw) if n[:3].isdigit())[0])).convert("RGBA")
    ref_bottom = first.getbbox()[3] if first.getbbox() else None
    ref_x = body_x(first)
    os.makedirs(dst, exist_ok=True)
    for old in os.listdir(dst):
        if old.endswith(".png"):
            os.remove(os.path.join(dst, old))
    for i, f in enumerate(frames):
        dx = dy = 0
        box = f.getbbox()
        if ground and box and ref_bottom is not None:
            dy = ref_bottom - box[3]
        if anchor_x and ref_x is not None:
            bx = body_x(f)
            if bx is not None:
                dx = int(round(ref_x - bx))
        shifted(f, dx, dy).save(os.path.join(dst, "%03d.png" % i))
    print("cleaned", len(frames), "frames ->", dst, "palette", len(pal))


if __name__ == "__main__":
    main()
