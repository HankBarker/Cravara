"""Find the separate sprites on a detail sheet (8-connected alpha pieces,
merging pieces whose boxes come within GAP px) and draw a numbered index.

    python tools/world/sheet_pieces.py SHEET.png OUT_INDEX.png [--gap 1]

Prints one line per piece: index, box (x0, y0, x1, y1), pixel count.
"""
import sys

from PIL import Image, ImageDraw


def pieces(img, gap=1):
    px = img.load()
    w, h = img.size
    seen = set()
    found = []
    for y in range(h):
        for x in range(w):
            if (x, y) in seen or px[x, y][3] == 0:
                continue
            stack, box, count = [(x, y)], [x, y, x, y], 0
            seen.add((x, y))
            while stack:
                cx, cy = stack.pop()
                count += 1
                box = [min(box[0], cx), min(box[1], cy), max(box[2], cx), max(box[3], cy)]
                for nx in range(cx - 1, cx + 2):
                    for ny in range(cy - 1, cy + 2):
                        if 0 <= nx < w and 0 <= ny < h and (nx, ny) not in seen and px[nx, ny][3]:
                            seen.add((nx, ny))
                            stack.append((nx, ny))
            found.append([box[0], box[1], box[2] + 1, box[3] + 1, count])
    # Merge pieces whose boxes nearly touch (a flower cluster, a tuft with loose blades).
    merged = True
    while merged:
        merged = False
        for i in range(len(found)):
            for j in range(i + 1, len(found)):
                a, b = found[i], found[j]
                if a[0] - gap <= b[2] and b[0] - gap <= a[2] and a[1] - gap <= b[3] and b[1] - gap <= a[3]:
                    found[i] = [min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3]), a[4] + b[4]]
                    del found[j]
                    merged = True
                    break
            if merged:
                break
    found.sort(key=lambda p: (p[1] // 16, p[0]))
    return found


def main():
    src, out = sys.argv[1], sys.argv[2]
    gap = int(sys.argv[sys.argv.index("--gap") + 1]) if "--gap" in sys.argv else 1
    img = Image.open(src).convert("RGBA")
    found = pieces(img, gap)
    s = 4
    bg = Image.new("RGBA", img.size, (70, 112, 68, 255))
    bg.alpha_composite(img)
    big = bg.resize((img.width * s, img.height * s), Image.NEAREST)
    d = ImageDraw.Draw(big)
    for i, p in enumerate(found):
        d.rectangle([p[0] * s, p[1] * s, p[2] * s - 1, p[3] * s - 1], outline=(255, 255, 0, 160))
        d.text((p[0] * s + 1, p[1] * s), str(i), fill=(255, 60, 60, 255))
        print(i, tuple(p[:4]), p[4])
    big.save(out)


if __name__ == "__main__":
    main()
