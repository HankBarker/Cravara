"""Pass 12: coats for a species' kinds, baked from its exported clips (no
generations): every strip of art/v2/<key>/ recoloured part by part (body,
crystal quills, belly, outline, by hue) onto a new ramp, written as a new art
key <key>_<coat> (strips + catalogue) that ForestCreature.VARIANTS "art" asks for.

  sand   the Sunscar Dunes' raptors: sandy ochre with rust quills and dark
         stripes down the back
  ash    the Pale Lands' Ashfang raptors: soot-dark and shaggy (a fringe of
         ash-pale fur standing up along the back and neck), charcoal quills,
         and the Sky-Fangs' ember glow running in their veins. (First baked
         ash-grey: on the Pale Lands' pale, greyed ground they all but
         vanished; dark with pale tips they read at a glance.)

    python tools/dino/coats.py raptor sand ash
"""
import colorsys
import json
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
V2 = os.path.join(ROOT, "game", "Forest", "creatures", "art", "v2")

# Ramps darkest -> lightest per part.
COATS = {
    "sand": {
        "outline": [(34, 24, 18), (52, 36, 26)],
        "body": [(78, 56, 36), (112, 82, 52), (150, 112, 70), (184, 144, 94), (212, 178, 124), (232, 206, 156)],
        "quill": [(118, 52, 34), (156, 74, 44), (194, 104, 60), (228, 146, 88), (246, 192, 128)],
        "belly": [(120, 92, 66), (170, 136, 96), (214, 182, 134), (240, 218, 176)],
        "stripes": True,
    },
    "ash": {
        "outline": [(14, 12, 12), (28, 24, 24)],
        "body": [(34, 30, 30), (50, 45, 44), (68, 62, 58), (90, 82, 76), (116, 107, 100), (144, 136, 128)],
        "quill": [(30, 26, 26), (48, 42, 40), (72, 62, 58), (230, 110, 44), (255, 170, 70)],
        "belly": [(112, 104, 98), (140, 132, 124), (168, 160, 150), (196, 190, 180)],
        "fur_tip": (214, 208, 198),
        "fur_root": (120, 112, 104),
        "fur": True,
        "embers": True,
    },
}


def part_of(c):
    h, s, v = colorsys.rgb_to_hsv(c[0] / 255.0, c[1] / 255.0, c[2] / 255.0)
    h *= 360.0
    if v < 0.22:
        return "outline"
    if 170.0 <= h <= 192.0 and s > 0.35 and v > 0.6:
        return "quill"
    if (h <= 50.0 or h >= 345.0) and s > 0.12:
        return "belly"
    if s < 0.08 and v > 0.9:
        return "belly"  # claws, teeth: the palest shade
    return "body"


def ramp_pick(ramp, v, lo, hi):
    t = 0.0 if hi <= lo else (v - lo) / (hi - lo)
    return ramp[max(0, min(len(ramp) - 1, int(round(t * (len(ramp) - 1)))))]


def recolour(img, coat):
    spec = COATS[coat]
    px = img.load()
    W, H = img.size
    # Value range per part, to spread each part over its new ramp.
    ranges = {}
    for y in range(H):
        for x in range(W):
            p = px[x, y]
            if p[3] == 0:
                continue
            part = part_of(p[:3])
            v = max(p[:3]) / 255.0
            lo, hi = ranges.get(part, (1.0, 0.0))
            ranges[part] = (min(lo, v), max(hi, v))
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    po = out.load()
    for y in range(H):
        for x in range(W):
            p = px[x, y]
            if p[3] == 0:
                continue
            part = part_of(p[:3])
            v = max(p[:3]) / 255.0
            lo, hi = ranges[part]
            po[x, y] = ramp_pick(spec[part], v, lo, hi) + (255,)
    return out, ranges


def stripes(img, frame_w):
    """Dark bands down the back: body pixels in the upper part of each column
    of the silhouette, every sixth column pair (frame-relative)."""
    px = img.load()
    W, H = img.size
    body_dark = COATS["sand"]["body"]
    for x in range(W):
        col = [y for y in range(H) if px[x, y][3] > 0]
        if not col:
            continue
        top, bottom = min(col), max(col)
        if (x % frame_w) % 6 not in (0, 1):
            continue
        for y in range(top, top + max(2, (bottom - top) // 3)):
            p = px[x, y]
            if p[3] and p[:3] in body_dark[2:]:
                i = body_dark.index(p[:3])
                px[x, y] = body_dark[max(0, i - 2)] + (255,)


def embers(img, frame_w):
    """The Sky-Fangs' mark: a few ember-orange flecks in the body's shade
    (a fixed pattern per frame position), like glowing veins."""
    px = img.load()
    W, H = img.size
    body = COATS["ash"]["body"]
    glow = [(236, 120, 48, 255), (255, 176, 76, 255)]
    for y in range(H):
        for x in range(W):
            p = px[x, y]
            if p[3] == 0 or p[:3] not in body[:3]:
                continue
            fx = x % frame_w
            if (fx * 7 + y * 13) % 29 == 0 or ((fx * 3 + y * 5) % 37 == 0 and p[:3] == body[1]):
                px[x, y] = glow[(fx + y) % 2]


def fur(img, frame_w, coat="ash"):
    """A shaggy fringe: along the top of the silhouette, tufts of 1-2 px of
    pale fur stand up (a fixed pattern per frame column), capped with the
    outline colour."""
    spec = COATS[coat]
    px = img.load()
    W, H = img.size
    tip = tuple(spec.get("fur_tip", spec["body"][-2])) + (255,)
    root = tuple(spec.get("fur_root", spec["body"][-3])) + (255,)
    cap = spec["outline"][1] + (255,)
    for x in range(W):
        col = [y for y in range(H) if px[x, y][3] > 0]
        if not col:
            continue
        top = min(col)
        fx = x % frame_w
        tuft = (1, 2, 1, 0, 2, 1, 0, 1)[(fx * 5 + fx // 3) % 8]
        if tuft == 0 or top - tuft - 1 < 0:
            continue
        # The outline row becomes fur; the tuft rises above it, capped.
        px[x, top] = root
        for k in range(1, tuft + 1):
            px[x, top - k] = tip if k == tuft else root
        px[x, top - tuft - 1] = cap
    return img


def main():
    key = sys.argv[1]
    coats = sys.argv[2:]
    src_dir = os.path.join(V2, key)
    cat = json.load(open(os.path.join(V2, key + ".json"), encoding="utf-8"))
    frame_w = int(cat["canvas"][0])
    for coat in coats:
        out_key = "%s_%s" % (key, coat)
        out_dir = os.path.join(V2, out_key)
        os.makedirs(out_dir, exist_ok=True)
        for name in sorted(os.listdir(src_dir)):
            if not name.endswith(".png"):
                continue
            img = Image.open(os.path.join(src_dir, name)).convert("RGBA")
            new, _ = recolour(img, coat)
            if COATS[coat].get("stripes"):
                stripes(new, frame_w)
            if COATS[coat].get("fur"):
                fur(new, frame_w, coat)
            if COATS[coat].get("embers"):
                embers(new, frame_w)
            new.save(os.path.join(out_dir, name))
        c2 = dict(cat)
        c2["key"] = out_key
        json.dump(c2, open(os.path.join(V2, out_key + ".json"), "w", encoding="utf-8"), indent=1)
        print("coat", out_key, "from", key)


if __name__ == "__main__":
    main()
