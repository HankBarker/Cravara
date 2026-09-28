"""Pass 18: the jungle's giant trees, drawn in code (Hank: "I want the trees to
extend all the way up past the screen, so giant trees... it should feel
almost like the redwoods").

    python tools/world/make_giants.py [--preview PATH]

Writes to game/Forest/art/v9/:
  giant_tree_0..2   the trunk on the jungle floor: buttress roots flaring at
                    its foot, deep-furrowed bark lit from the upper left, moss
                    and vines, running 330 px up (off the top of any screen)
  giant_crown_0..2  the same trunk in the treetops: sunlit bark rising from
                    its crown's platform, boughs parting at its foot
  rope_ladder       a rope ladder hanging down a giant's trunk
  rope_top          its top: the rope tied off round a peg on the bark
  vines             creepers hanging down from the canopy, out of sight above
  wall_basalt, wall_alt_basalt, ore_ember     the volcano's rock
  wall_moss, wall_alt_moss, ore_glimmer       the jungle's
Every colour is one of a few ramps; the outline is the chest's near-black.
"""
import math
import os
import random
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "Forest", "art", "v9")
ART2 = os.path.join(ROOT, "game", "Forest", "art", "v2")
OUTLINE = (26, 23, 38, 255)
# Bark ramps, dark to light: the jungle floor's (shaded, grey-brown) and the
# treetops' (sunlit, warmer).
BARK = [(38, 31, 29), (56, 46, 40), (76, 63, 52), (98, 82, 64), (122, 104, 80), (146, 128, 100)]
BARK_SUN = [(52, 40, 34), (78, 62, 48), (104, 84, 62), (132, 108, 80), (160, 134, 98), (190, 164, 120)]
MOSS = [(38, 62, 40), (56, 86, 48), (78, 112, 58), (104, 138, 70)]
VINE = [(28, 52, 34), (44, 76, 42), (70, 104, 52)]
ROPE = [(92, 70, 44), (138, 108, 70), (178, 146, 98)]


def _noise1(seed):
    r = random.Random(seed)
    pts = [r.random() for _ in range(64)]

    def f(x):
        x = x % 64.0
        i = int(x)
        t = x - i
        t = t * t * (3 - 2 * t)
        return pts[i] * (1 - t) + pts[(i + 1) % 64] * t
    return f


def trunk(seed, sunlit=False, h=330, roots=True):
    """A giant's trunk, `h` px tall, its foot on the bottom row."""
    r = random.Random(seed)
    ramp = BARK_SUN if sunlit else BARK
    w = 72
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    cx = w / 2.0
    furrow = _noise1(seed * 7 + 1)
    streak = _noise1(seed * 7 + 2)
    wobble = _noise1(seed * 7 + 3)
    moss_n = _noise1(seed * 7 + 4)
    moss_m = _noise1(seed * 7 + 5)
    top_w = 15.0 + r.random() * 2.0
    for y in range(h):
        up = (h - 1 - y)                      # px above the foot
        # The trunk's half-width: flaring into buttresses over the lowest 34 px.
        half = top_w + (1.0 - min(1.0, up / 42.0)) ** 2.2 * (21.0 if roots else 7.0)
        half += (wobble(y * 0.05) - 0.5) * 1.6
        centre = cx + (wobble(y * 0.02 + 20) - 0.5) * 2.0
        for x in range(w):
            u = (x - centre) / half            # -1 .. 1 across the trunk
            if abs(u) > 1.0:
                continue
            # Buttress roots: fins, the bark between them in shadow.
            gap_shade = 0.0
            if roots and up < 36:
                fin = abs(math.sin((u * 2.6 + 0.3) * math.pi))
                if fin < 0.2 and abs(u) > 0.52 and up < 28:
                    continue
                if fin < 0.45 and abs(u) > 0.4:
                    gap_shade = 1.3 * (1.0 - up / 36.0)
            # Round shading, lit from the upper left.
            light = 0.5 + 0.5 * math.cos((u + 0.35) * math.pi * 0.62)
            f = furrow(x * 0.9 + (seed % 5) * 11 + math.sin(y * 0.03) * 2.0)
            v = light * 4.2 + (f - 0.5) * 2.4 + (streak(y * 0.13 + x * 0.2) - 0.5) * 0.9
            if f < 0.22:
                v -= 1.6                       # a furrow
            if up < 34 and roots:
                v -= (1.0 - up / 34.0) * 0.8   # the roots' foot in shade
            v -= gap_shade                     # the shadow between two fins
            if not sunlit:
                v -= max(0.0, (up - 200) / 130.0) * 1.8   # up into the canopy's shade
            else:
                v += max(0.0, (up - 150) / 180.0) * 0.8   # up into the sun
            k = int(round(max(0, min(len(ramp) - 1, v))))
            col = ramp[k]
            # Moss on the lit side and round the foot.
            m = moss_n(y * 0.045 + x * 0.05) * 0.6 + moss_m(x * 0.35 + y * 0.012) * 0.4
            if (u < -0.1 and m > 0.6 and up > 20) or (up < 16 and m > 0.5 and abs(u) < 0.95):
                col = MOSS[max(0, min(3, int(light * 3.2 + (m - 0.6) * 3)))]
            px[x, y] = col + (255,)
    # Vines climbing the trunk.
    for v in range(2 + r.randint(0, 2)):
        x0 = cx + r.uniform(-top_w * 0.8, top_w * 0.8)
        phase = r.uniform(0, 6.28)
        top = r.randint(40, h - 60)
        for y in range(top, h - r.randint(4, 30)):
            x = int(round(x0 + math.sin(y * 0.045 + phase) * 4.0))
            if 0 <= x < w and px[x, y][3]:
                px[x, y] = VINE[1] + (255,)
                if x + 1 < w and px[x + 1, y][3]:
                    px[x + 1, y] = VINE[0] + (255,)
                if y % 9 == 0 and x - 1 >= 0:
                    px[x - 1, y] = VINE[2] + (255,)
                    if x - 2 >= 0 and px[x - 2, y][3]:
                        px[x - 2, y] = VINE[1] + (255,)
    _outline(img)
    return img.crop((0, 0, w, h))


def crown(seed):
    """The trunk in the treetops: sunlit, no roots, boughs parting at its foot."""
    img = trunk(seed, sunlit=True, h=260, roots=False)
    px = img.load()
    w, h = img.size
    r = random.Random(seed + 99)
    # Two boughs running off the foot, one to either side, and stubs higher up.
    for side in (-1, 1):
        for i in range(16):
            yy = h - 3 - i // 3
            for t in range(4):
                x = int(w / 2 + side * (14 + i + t))
                y = yy - t + 2
                if 0 <= x < w and 0 <= y < h:
                    px[x, y] = BARK_SUN[2 + (t > 1)] + (255,)
    for s in range(3):
        y = r.randint(40, h - 80)
        side = r.choice((-1, 1))
        for i in range(8):
            x = int(w / 2 + side * (15 + i))
            for t in range(3):
                if 0 <= x < w and 0 <= y - i // 2 + t < h:
                    px[x, y - i // 2 + t] = BARK_SUN[3 - t] + (255,)
        for lx in range(-3, 4):
            for ly in range(-3, 2):
                x = int(w / 2 + side * 23) + lx
                y2 = y - 4 + ly
                if 0 <= x < w and 0 <= y2 < h and abs(lx) + abs(ly) < 5:
                    px[x, y2] = MOSS[2 + (lx + ly) % 2] + (255,)
    _outline(img)
    return img


def rope_ladder():
    w, h = 16, 120
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h):
        for x in (3, 12):
            sway = int(round(math.sin(y * 0.05) * 0.6))
            px[x + sway, y] = ROPE[1] + (255,)
            px[x + sway + 1, y] = ROPE[0] + (255,)
        if y % 7 == 3:
            for x in range(4, 12):
                px[x, y] = ROPE[2] + (255,) if x < 8 else ROPE[1] + (255,)
                px[x, y + 1] = ROPE[0] + (255,)
    _outline(img)
    return img


def rope_top():
    w, h = 20, 18
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    # A peg in the bark, the rope wound round it, the ladder's first rungs
    # going down over the edge.
    for y in range(2, 8):
        for x in range(8, 12):
            px[x, y] = BARK_SUN[3 if x < 10 else 1] + (255,)
    for i in range(22):
        a = i / 22.0 * math.tau
        x = int(round(10 + math.cos(a) * 5))
        y = int(round(8 + math.sin(a) * 3))
        px[x, y] = ROPE[2 if math.sin(a) < 0 else 1] + (255,)
    for y in range(10, h):
        for x in (6, 13):
            px[x, y] = ROPE[1] + (255,)
        if y % 4 == 1:
            for x in range(7, 13):
                px[x, y] = ROPE[2] + (255,)
    _outline(img)
    return img


def vines(seed=5):
    w, h = 26, 150
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    r = random.Random(seed)
    for s in range(3):
        x0 = 5 + s * 7 + r.randint(-1, 1)
        end = h - r.randint(6, 30)
        phase = r.uniform(0, 6)
        for y in range(end):
            x = int(round(x0 + math.sin(y * 0.06 + phase) * 2.0))
            px[x, y] = VINE[1] + (255,)
            if (y + s * 3) % 11 == 0:
                for lx, ly in ((-1, 0), (-2, 1), (1, 0), (2, 1), (-1, 1), (1, 1)):
                    xx, yy = x + lx, y + ly
                    if 0 <= xx < w and 0 <= yy < h:
                        px[xx, yy] = VINE[2 if ly == 0 else 1] + (255,)
    _outline(img)
    return img


def _outline(img):
    px = img.load()
    w, h = img.size
    edge = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] and px[nx, ny] != OUTLINE:
                    edge.append((x, y))
                    break
    for x, y in edge:
        px[x, y] = OUTLINE


def recolour(src, ramp, glow=None, glow_odds=0.0, seed=1):
    """A rock sprite in another stone: each pixel's lightness picks its step
    on `ramp`; a few lit pixels glow (the volcano's cracks)."""
    img = Image.open(src).convert("RGBA")
    px = img.load()
    r = random.Random(seed)
    for y in range(img.height):
        for x in range(img.width):
            c = px[x, y]
            if not c[3]:
                continue
            lum = (c[0] * 0.3 + c[1] * 0.59 + c[2] * 0.11) / 255.0
            k = max(0, min(len(ramp) - 1, int(lum * len(ramp) * 1.15)))
            col = ramp[k]
            if glow and lum > 0.35 and r.random() < glow_odds:
                col = glow
            px[x, y] = col + (c[3],)
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    art = {}
    for i in range(3):
        art["giant_tree_%d" % i] = trunk(11 + i * 13)
        art["giant_crown_%d" % i] = crown(17 + i * 13)
    art["rope_ladder"] = rope_ladder()
    art["rope_top"] = rope_top()
    art["vines"] = vines()
    basalt = [(18, 16, 18), (30, 27, 30), (44, 40, 42), (60, 55, 56), (78, 72, 72), (98, 90, 88)]
    moss_rock = [(40, 50, 40), (56, 70, 52), (74, 92, 62), (96, 118, 74), (122, 144, 88), (150, 170, 108)]
    art["wall_basalt"] = recolour(os.path.join(ART2, "wall.png"), basalt, (236, 112, 40), 0.03)
    art["wall_alt_basalt"] = recolour(os.path.join(ART2, "wall_alt.png"), basalt, (236, 112, 40), 0.03, 2)
    art["ore_ember"] = recolour(os.path.join(ART2, "ore.png"), [(40, 16, 14), (92, 30, 20), (160, 52, 28), (220, 96, 40), (250, 150, 64), (255, 210, 120)])
    art["wall_moss"] = recolour(os.path.join(ART2, "wall.png"), moss_rock)
    art["wall_alt_moss"] = recolour(os.path.join(ART2, "wall_alt.png"), moss_rock, None, 0.0, 3)
    art["ore_glimmer"] = recolour(os.path.join(ART2, "ore.png"), [(14, 40, 44), (20, 78, 80), (30, 124, 118), (60, 180, 160), (120, 226, 196), (200, 255, 236)])
    if "--preview" in sys.argv:
        path = sys.argv[sys.argv.index("--preview") + 1]
        items = list(art.values())
        z = 2
        wid = sum(i.width * z + 12 for i in items) + 12
        hei = max(i.height for i in items) * z + 24
        sheet = Image.new("RGBA", (wid, hei), (40, 70, 44, 255))
        x = 12
        for i in items:
            sheet.alpha_composite(i.resize((i.width * z, i.height * z), Image.NEAREST), (x, hei - 12 - i.height * z))
            x += i.width * z + 12
        sheet.save(path)
        print("preview", path, sheet.size)
        return
    for name, img in art.items():
        img.save(os.path.join(OUT, name + ".png"))
        print("wrote", name, img.size)


if __name__ == "__main__":
    main()
