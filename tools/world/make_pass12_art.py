"""Pass 12 art drawn here (no generations): the keeper's paddle (a held-tool
sprite for the rig's "row" clip) and the item icons of pass 12.

    python tools/world/make_pass12_art.py

The rowboat itself (game/Forest/art/pass12/rowboat.png: 8 headings of a
PixelLab 8-direction object, east clockwise; its diagonals were drawn flipped
top to bottom, and east/west are its south view turned a quarter) is built by
the pass-12 notes, not here.
"""
import json
import math
import os

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
HELD = os.path.join(ROOT, "game", "Forest", "keeper", "art", "held")
OUTLINE = (40, 28, 20, 255)


def seg_dist(p, a, b):
    ax, ay = a
    bx, by = b
    px, py = p
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / float(dx * dx + dy * dy)))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


def paddle():
    """A single-blade canoe paddle, 16 x 16, drawn on the diagonal like every
    held tool: a T-grip bottom-left, the shaft, a leaf blade top-right."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = img.load()
    wood = (172, 124, 74, 255)
    shade = (122, 86, 52, 255)
    light = (206, 158, 100, 255)
    body = {}
    for y in range(16):
        for x in range(16):
            c = (x + 0.5, y + 0.5)
            # Blade: an ellipse along the diagonal, centred up and right.
            u = ((c[0] - 11.4) - (c[1] - 4.6)) / math.sqrt(2)
            v = ((c[0] - 11.4) + (c[1] - 4.6)) / math.sqrt(2)
            if (u / 3.6) ** 2 + (v / 1.9) ** 2 <= 1.0:
                body[(x, y)] = "blade"
            elif seg_dist(c, (3.2, 12.8), (10.0, 6.0)) <= 0.75:
                body[(x, y)] = "shaft"
            elif seg_dist(c, (1.8, 12.4), (3.6, 14.2)) <= 0.7:
                body[(x, y)] = "grip"
    for (x, y), part in body.items():
        if part == "blade":
            # Lit along the upper-left edge.
            px[x, y] = light if (x - 1, y) not in body or (x, y - 1) not in body else wood
        elif part == "grip":
            px[x, y] = shade
        else:
            px[x, y] = wood
    for (x, y) in body:
        for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if n not in body and 0 <= n[0] < 16 and 0 <= n[1] < 16 and px[n][3] == 0:
                px[n] = OUTLINE
    img.save(os.path.join(HELD, "paddle.png"))
    json.dump({"grip": [3.5, 12.5], "angle": -45.0, "hang": False}, open(os.path.join(HELD, "paddle.json"), "w"))
    print("held paddle")


def rowboat_icon():
    """The boat item: the one-seat rowboat from above, bow to the right."""
    rows = [
        "................",
        "................",
        "................",
        "..oooooooooo....",
        ".olllllllllloo..",
        "olwwbbwwwbbwwloo",
        "olwwbbwwwbbwwwlo",
        "olwwbbwwwbbwwloo",
        ".owwwwwwwwwwoo..",
        "..oooooooooo....",
        "................",
    ]
    colours = {"o": OUTLINE, "l": (206, 158, 100, 255), "w": (170, 112, 62, 255), "b": (126, 80, 44, 255)}
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    top = (16 - len(rows)) // 2 + 1
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in colours:
                img.putpixel((x, top + y), colours[ch])
    img.save(os.path.join(ROOT, "game", "Forest", "art", "items", "boat.png"))
    print("icon boat")


def _stroke(body, a, b, radius, part, curve=0.0):
    """Mark pixels within radius of the (optionally bowed) segment a -> b."""
    steps = 40
    pts = []
    for i in range(steps + 1):
        t = i / steps
        x = a[0] + (b[0] - a[0]) * t
        y = a[1] + (b[1] - a[1]) * t
        # Bow it sideways (a sabre's curve) across the diagonal.
        bow = curve * 4.0 * t * (1.0 - t)
        pts.append((x - bow * 0.7071, y - bow * 0.7071))
    for y in range(16):
        for x in range(16):
            c = (x + 0.5, y + 0.5)
            for i in range(steps):
                if seg_dist(c, pts[i], pts[i + 1]) <= radius:
                    body[(x, y)] = part
                    break


def weapon(item_id, parts, colours):
    """A held weapon on the rig's diagonal: `parts` in draw order, each
    (a, b, radius, name, curve); colours[name] = (fill, shade, light).
    Lit along the upper-left edges, shaded along the lower-right, outlined."""
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    px = img.load()
    body = {}
    for (a, b, radius, name, curve) in parts:
        _stroke(body, a, b, radius, name, curve)
    for (x, y), name in body.items():
        fill, shade, light = colours[name]
        up_left = (x - 1, y) not in body or (x, y - 1) not in body
        down_right = (x + 1, y) not in body or (x, y + 1) not in body
        px[x, y] = light if up_left and not down_right else (shade if down_right and not up_left else fill)
    for (x, y) in body:
        for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if n not in body and 0 <= n[0] < 16 and 0 <= n[1] < 16 and px[n][3] == 0:
                px[n] = OUTLINE
    img.save(os.path.join(HELD, item_id + ".png"))
    json.dump({"grip": [2.6, 13.4], "angle": -45.0, "hang": False}, open(os.path.join(HELD, item_id + ".json"), "w"))
    print("held", item_id)


IVORY = ((236, 226, 204, 255), (186, 170, 140, 255), (252, 248, 236, 255))
HIDE = ((120, 84, 50, 255), (86, 58, 36, 255), (152, 110, 70, 255))
WOOD = ((172, 124, 74, 255), (122, 86, 52, 255), (206, 158, 100, 255))


def weapons():
    weapon("fang_sabre", [((2.2, 13.8), (5.2, 10.8), 0.8, "grip", 0.0), ((4.4, 9.8), (6.6, 12.0), 0.9, "guard", 0.0),
                          ((5.6, 10.4), (13.6, 2.4), 1.05, "blade", 1.6)],
           {"grip": HIDE, "guard": ((72, 170, 160, 255), (40, 120, 118, 255), (140, 220, 206, 255)), "blade": IVORY})
    weapon("horn_spear", [((1.4, 14.6), (11.0, 5.0), 0.65, "shaft", 0.0), ((10.4, 5.6), (14.6, 1.4), 1.2, "tip", 0.0),
                          ((9.6, 5.2), (10.8, 6.4), 1.0, "bind", 0.0)],
           {"shaft": WOOD, "tip": IVORY, "bind": ((196, 88, 52, 255), (150, 60, 38, 255), (230, 120, 80, 255))})
    # A heavy head set across the haft (not along it), bone spikes at its ends.
    weapon("plate_maul", [((1.6, 14.4), (10.6, 5.4), 0.8, "haft", 0.0), ((8.8, 2.6), (13.4, 7.2), 1.9, "head", 0.0),
                          ((7.4, 1.2), (8.4, 2.2), 0.6, "spike", 0.0), ((13.8, 7.6), (14.8, 8.6), 0.6, "spike", 0.0),
                          ((12.4, 2.8), (13.6, 1.6), 0.6, "spike", 0.0)],
           {"haft": WOOD, "head": ((212, 128, 44, 255), (168, 92, 30, 255), (240, 170, 80, 255)), "spike": IVORY})
    weapon("allo_cleaver", [((1.6, 14.4), (5.0, 11.0), 0.8, "grip", 0.0), ((5.0, 11.0), (12.6, 3.4), 1.7, "blade", 0.0),
                            ((7.6, 10.6), (13.8, 4.4), 0.55, "teeth", 0.0)],
           {"grip": ((110, 44, 32, 255), (78, 28, 22, 255), (150, 70, 48, 255)),
            "blade": ((150, 150, 144, 255), (108, 108, 104, 255), (196, 196, 188, 255)), "teeth": IVORY})
    weapon("tyrant_fang", [((1.6, 14.4), (4.4, 11.6), 0.8, "grip", 0.0), ((3.4, 10.4), (5.6, 12.6), 1.0, "guard", 0.0),
                           ((4.8, 11.2), (14.2, 1.8), 1.45, "blade", 0.6)],
           {"grip": HIDE, "guard": ((60, 160, 96, 255), (34, 112, 66, 255), (120, 210, 140, 255)), "blade": IVORY})


BONE_OCHRE = ((196, 160, 108, 255), (138, 110, 86, 255), (236, 228, 204, 255))
CRIMSON = ((176, 62, 50, 255), (120, 36, 34, 255), (214, 104, 76, 255))
DARK_WOOD = ((120, 84, 50, 255), (84, 56, 32, 255), (160, 116, 70, 255))


def weapons12():
    """Pass 12: the ankylosaur's club on a haft, the Scarhorn lance, the
    Ashen raiders' toothed club."""
    weapon("club_maul", [((1.6, 14.4), (10.0, 6.0), 0.85, "haft", 0.0), ((10.2, 5.8), (12.2, 3.8), 2.5, "club", 0.0),
                         ((13.6, 1.6), (14.2, 1.0), 0.55, "knob", 0.0), ((9.0, 2.6), (9.4, 2.2), 0.55, "knob", 0.0),
                         ((14.4, 6.2), (14.8, 5.8), 0.55, "knob", 0.0)],
           {"haft": WOOD, "club": BONE_OCHRE, "knob": IVORY})
    weapon("scarhorn_lance", [((1.2, 14.8), (10.4, 5.6), 0.6, "shaft", 0.0), ((10.0, 6.0), (12.6, 3.4), 1.35, "base", 0.0),
                              ((12.4, 3.6), (14.8, 1.2), 0.9, "tip", 0.6), ((9.2, 6.8), (10.2, 5.8), 1.0, "bind", 0.0)],
           {"shaft": WOOD, "base": CRIMSON, "tip": IVORY, "bind": HIDE})
    weapon("raider_club", [((1.8, 14.2), (5.8, 10.2), 0.8, "grip", 0.0), ((5.6, 10.4), (12.8, 3.2), 1.55, "head", 0.0),
                           ((5.2, 10.8), (6.4, 9.6), 1.0, "cord", 0.0), ((9.2, 4.8), (9.6, 4.4), 0.5, "tooth", 0.0),
                           ((12.8, 7.0), (13.2, 6.6), 0.5, "tooth", 0.0), ((13.6, 2.0), (14.0, 1.6), 0.5, "tooth", 0.0)],
           {"grip": DARK_WOOD, "head": DARK_WOOD, "cord": ((170, 52, 44, 255), (120, 34, 30, 255), (206, 84, 66, 255)), "tooth": IVORY})


def sun_sail():
    """The Sun Sail (a placeable, 24 x 30, standing on its base): a dimetrodon
    sail on a wooden frame, as the beast wears it: upright spines with pale
    tips, the skin between them red at the root to orange at the arched top,
    lit from the upper left; a crossbar, two posts on stones."""
    W, H = 24, 30
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    px = img.load()
    body = {}
    left, right, bottom = 5, 18, 19
    spines = (6, 9, 12, 15, 17)

    def top_of(x):
        d = (x + 0.5 - 11.5) / 7.0
        return int(round(4 + d * d * 7))

    for x in range(left, right + 1):
        for y in range(top_of(x), bottom + 1):
            body[(x, y)] = "sail"
    for x in spines:
        for y in range(top_of(x) - 2, bottom + 1):
            body[(x, y)] = "spine"
        body[(x, top_of(x) - 2)] = "tip"
    for x in range(3, 21):
        body[(x, bottom + 1)] = "bar"
    for y in range(bottom - 6, H - 2):
        body[(3, y)] = "post"
        body[(20, y)] = "post"
    for (x, y) in [(2, 28), (3, 28), (4, 28), (19, 28), (20, 28), (21, 28), (2, 27), (21, 27)]:
        body[(x, y)] = "stone"
    reds = [(122, 36, 30, 255), (164, 52, 38, 255), (204, 80, 48, 255), (232, 120, 62, 255), (248, 170, 96, 255)]
    for (x, y), part in body.items():
        if part == "sail":
            t = (bottom - y) / max(1.0, bottom - top_of(x))  # 0 at the root, 1 at the top
            lit = t * 3.2 + (0.8 if x < 11 else 0.0) - (0.6 if x > 15 else 0.0)
            px[x, y] = reds[max(0, min(4, int(lit)))]
        elif part == "spine":
            px[x, y] = (84, 44, 34, 255)
        elif part == "tip":
            px[x, y] = (236, 226, 204, 255)
        elif part in ("bar", "post"):
            px[x, y] = (172, 124, 74, 255) if part == "bar" or x < 12 else (122, 86, 52, 255)
        else:
            px[x, y] = (150, 146, 136, 255) if (x + y) % 2 else (112, 108, 100, 255)
    for (x, y) in list(body):
        for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if n not in body and 0 <= n[0] < W and 0 <= n[1] < H and px[n][3] == 0:
                px[n] = OUTLINE
    out = os.path.join(ROOT, "game", "Forest", "art", "pass12")
    os.makedirs(out, exist_ok=True)
    img.save(os.path.join(out, "sun_sail.png"))
    print("prop sun_sail")


def crest_horn_icon():
    """The Crestcaller Horn trinket: the crestbone's own icon, hung on a cord."""
    src = Image.open(os.path.join(ROOT, "game", "Forest", "art", "items", "parasaur_crest.png")).convert("RGBA")
    img = src.copy()
    px = img.load()
    w, h = img.size
    cord = (150, 110, 90, 255)
    # A loop of cord from the crest's two ends up over the top of the icon.
    box = src.getbbox()
    left = (box[0] + 2, box[1] + (box[3] - box[1]) // 2)
    right = (box[2] - 3, box[1] + 2)
    for t in range(0, 41):
        f = t / 40.0
        x = left[0] + (right[0] - left[0]) * f
        y = min(left[1], right[1]) - 4 * math.sin(math.pi * f) + (left[1] + (right[1] - left[1]) * f - min(left[1], right[1]))
        xi, yi = int(round(x)), int(round(y))
        if 0 <= xi < w and 0 <= yi < h and px[xi, yi][3] == 0:
            px[xi, yi] = cord
    img.save(os.path.join(ROOT, "game", "Forest", "art", "items", "crest_horn.png"))
    print("icon crest_horn")


def main():
    paddle()
    rowboat_icon()
    weapons()
    weapons12()
    sun_sail()
    crest_horn_icon()


if __name__ == "__main__":
    main()
