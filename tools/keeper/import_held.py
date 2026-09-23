"""Import hand-scale held-item sprites into game/Forest/keeper/art/held/.

Each 16x16 sprite is drawn diagonally (grip bottom-left, head top-right) or,
for hanging items, upright with a carry handle on top. Writes <id>.png and
<id>.json {grip:[x,y], angle:deg, hang:bool} used by KeeperTools.gd.
"""
import json
import math
import os
import shutil
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "art", "keeper-v2", "source", "held")
DST = os.path.join(ROOT, "game", "Forest", "keeper", "art", "held")
HANG = {"bucket", "water_bucket", "lantern"}


def grip_for(img, hang):
    pts = [(x, y) for y in range(img.height) for x in range(img.width) if img.getpixel((x, y))[3] > 127]
    if hang:
        top = min(y for _, y in pts)
        row = [x for x, y in pts if y == top]
        return [sum(row) / len(row) + 0.5, top + 1.0], -90.0
    # Bottom-left end of the handle, then 1.5 px up the handle so the fist
    # closes around wood rather than the pommel.
    end = min(pts, key=lambda p: (p[0] - p[1]))
    head = max(pts, key=lambda p: (p[0] - p[1]))
    dx, dy = head[0] - end[0], head[1] - end[1]
    length = math.hypot(dx, dy) or 1.0
    angle = math.degrees(math.atan2(dy, dx))
    gx = end[0] + 0.5 + dx / length * 1.5
    gy = end[1] + 0.5 + dy / length * 1.5
    return [round(gx, 2), round(gy, 2)], round(angle, 1)


def main():
    os.makedirs(DST, exist_ok=True)
    for name in sorted(os.listdir(SRC)):
        if not name.endswith(".png"):
            continue
        item = name[:-4]
        img = Image.open(os.path.join(SRC, name)).convert("RGBA")
        hang = item in HANG
        grip, angle = grip_for(img, hang)
        img.save(os.path.join(DST, name))
        meta = {"grip": grip, "angle": angle, "hang": hang}
        with open(os.path.join(DST, item + ".json"), "w") as f:
            json.dump(meta, f)
        print(item, meta)


if __name__ == "__main__":
    main()
