"""Pass 18: download the new beasts' PixelLab v3 drawings (8 views each) into
art/dino-v2/new/KEY/v3_p18/<direction>.png, and write a review sheet.

    python tools/dino/fetch18.py [KEY ...] [--sheet PATH]
"""
import os
import sys
import urllib.request

from PIL import Image, ImageDraw

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
NEW = os.path.join(ROOT, "art", "dino-v2", "new")
USER = "88b32f13-f02d-4540-9dcc-403c6c344192"
CHARS = {
    "ptera": "77d539f6-f4ba-436e-8087-1f28cc6a703b",
    "ptera_perch": "f5bec2b3-4e08-4a67-926e-fd0467022105",
    "dimorph": "5b558af4-c200-4675-b9c7-2e6d92f8c2f2",
    "thyla": "3ed03fc5-840b-4d3f-b81a-1584c53d0f50",
    "quetzal": "eee0fbde-3868-405d-b65c-0b44ec81cbc2",
    "quetzal_fly": "c042cf0f-d45b-40ac-b402-c9a226b634aa",
    "cinder": "a341e7d2-08a0-462e-98cd-32b8babe149f",
    "grimjaw": "146c0d1c-f025-478e-b0c9-af5f14faff60",
    "reaper": "afe9b544-bd00-4415-bd3a-727a57d2abcf",
}
# The smaller redraws (the first drawings of these four were bigger than a rex).
SMALL = {
    "ptera": "d0acda97-5558-44d5-838c-ab90e991e2bf",
    "ptera_perch": "df8b6e3b-e850-40e0-9ede-8b57deb974a7",
    "dimorph": "0369e6ef-eba9-4bca-bd40-e1283572a4c1",
    "thyla": "82c275ef-82b7-4615-b219-9c74ca8d9347",
}
DIRS = ["south", "south-east", "east", "north-east", "north", "north-west", "west", "south-west"]


def fetch(key, run="v3_p18"):
    cid = SMALL[key] if run == "v3_p18b" else CHARS[key]
    out = os.path.join(NEW, key, run)
    os.makedirs(out, exist_ok=True)
    got = 0
    for d in DIRS:
        dst = os.path.join(out, d + ".png")
        if os.path.exists(dst):
            got += 1
            continue
        url = "https://backblaze.pixellab.ai/file/pixellab-characters/%s/%s/rotations/%s.png" % (USER, cid, d)
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
            data = urllib.request.urlopen(req, timeout=30).read()
            open(dst, "wb").write(data)
            got += 1
        except Exception as e:
            print(key, d, "not ready:", e)
    return got


def sheet(keys, path, run="v3_p18"):
    rows = []
    for key in keys:
        ims = []
        for d in DIRS:
            p = os.path.join(NEW, key, run, d + ".png")
            ims.append(Image.open(p).convert("RGBA") if os.path.exists(p) else None)
        rows.append((key, ims))
    cell = max((im.width for _, ims in rows for im in ims if im), default=64)
    z = 2 if cell <= 96 else 1
    W = 110 + len(DIRS) * (cell * z + 6)
    H = sum(max((im.height for im in ims if im), default=cell) * z + 22 for _, ims in rows)
    img = Image.new("RGBA", (W, H), (88, 120, 70, 255))
    dr = ImageDraw.Draw(img)
    y = 0
    for key, ims in rows:
        h = max((im.height for im in ims if im), default=cell) * z
        dr.text((4, y + 4), key, fill=(255, 255, 255, 255))
        for i, im in enumerate(ims):
            x = 110 + i * (cell * z + 6)
            dr.text((x, y + 2), DIRS[i], fill=(230, 230, 200, 255))
            if im:
                img.alpha_composite(im.resize((im.width * z, im.height * z), Image.NEAREST), (x, y + 14))
        y += h + 22
    img.save(path)
    print("sheet", path, img.size)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    keys = [a for a in args if a in CHARS] or list(CHARS)
    run = "v3_p18b" if "--small" in sys.argv else "v3_p18"
    if run == "v3_p18b":
        keys = [k for k in keys if k in SMALL]
    for k in keys:
        print(k, fetch(k, run), "of 8")
    if "--sheet" in sys.argv:
        sheet(keys, sys.argv[sys.argv.index("--sheet") + 1], run)
