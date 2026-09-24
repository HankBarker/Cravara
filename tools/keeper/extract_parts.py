"""Slice PixelLab Keeper v2 rotations into rig parts.

    python tools/keeper/extract_parts.py base                    # art/keeper-v2/source/base_*.png
    python tools/keeper/extract_parts.py leather [--name "Trail Leather"]   # art/keeper-v2/source/leather/*.png
    python tools/keeper/extract_parts.py hair [cropped ...]      # art/keeper-v2/source/hair_<style>/*.png
    python tools/keeper/extract_parts.py all                     # base + every set + every hair style
    add --debug to also write art/keeper-v2/review/labels-<id>.png (region/material overlays)

Armour states and hair styles are generated with PixelLab create_character_state
from the base hero, so the body, arms and legs occupy (nearly) the same pixels
in every state. One set of region rules therefore cuts every outfit:

  head      -> helmet / hair sprite (face, eyes and fringe keep skin/eye/hair
               materials so appearance recolouring still applies) + a closed-eye
               "_blink" copy when eyes are visible
  torso     -> chest sprite (arms removed; the side view's hidden back is rebuilt
               from the set's own back view, with an outline)
  pauldrons -> shoulder-guard sprites re-outlined as clean shapes, stamped by the
               rig over the top of each arm
  arms/legs -> 5-shade ramps [deep, dark, mid, light, highlight] of the piece's
               dominant material (the rig draws limbs as shaded capsules)
  boots     -> 3-row sole sprites aligned to the ground row

Outputs: game/Forest/keeper/art/{base|sets/<id>}/ + set.json, or
game/Forest/keeper/art/hair/<style>_<view>.png + hair.json.

Per-source overrides (all keys optional) live next to the sources:
art/keeper-v2/source/base_overrides.json, source/<set>/overrides.json,
source/hair_<style>/overrides.json. Views are the rig's names (down/up/side);
coordinates are 32x32 SOURCE pixels, rects are inclusive [x0, y0, x1, y1].

  "notes":   free text - say why each override exists.
  "labels":  {view: [{"rect"|"px": ..., "label": L, "only": "armor"|"skin"|"any"}]}
             re-label source pixels after the default region rules.
             L in head, torso, arm_m, arm_o, legs, boot_m, boot_o,
             pauldron_m, pauldron_o, drop.
  "face":    {view: [rect, ...]}  skin area of the face (default: the base's)
  "eyes":    {view: [rect, ...]}  eye boxes incl. the lash row (default: base's)
  "ramps":   {"arm_upper"|"arm_lower"|"hand"|"leg_upper"|"leg_lower": [5 hex] | "skin" | "auto"}
             "skin" = bare skin (the appearance skin ramp is used).
  "ramp_hint": {segment: "hex"}  build the ramp from the colour family of hex.
  "patches": [{"part": head|torso|pauldron_m|..., "view": v, "x": sx, "y": sy,
               "hex": "rrggbb" | "clear" | "fill", "mat": material?}]
             "fill" repaints the pixel from its neighbours (e.g. stray hand pixels).
  "blink_line": {view: "mid"|"low"}  row of the closed-eye lash line (default mid).
  "materials": {view: [{"rect"|"px": ..., "mat": material}]}  per-pixel material fixes.
  "flags":   ["no_side_pauldron", "no_blink", "pauldron_skinlike_ok", ...]
  "side_back_x": 12   source column of the rebuilt side-view torso back outline.
"""
import colorsys
import json
import math
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from keeper_palette import MATERIALS, dist2, hexc, hls, lum, nearest, parse_hex  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "art", "keeper-v2", "source")
ART = os.path.join(ROOT, "game", "Forest", "keeper", "art")
REVIEW = os.path.join(ROOT, "art", "keeper-v2", "review")
CEL_OFFSET = (16, 13)
VIEWS = {"down": "south", "up": "north", "side": "east"}
# Rest foot x per view/side (cel) - must match tools/keeper/build_rig.py REST.
FOOT_X = {"down": {"m": 35.0, "o": 29.0}, "up": {"m": 35.0, "o": 29.0}, "side": {"m": 31.2, "o": 32.8}}
SHOULDER = {"down": {"m": (36.8, 30.6), "o": (27.2, 30.6)}, "up": {"m": (37.0, 30.4), "o": (27.0, 30.4)},
            "side": {"m": (30.2, 30.8), "o": (33.4, 30.6)}}
LEG_TOP = 26           # first source row of the legs
BOOT_H = 3             # boots are the bottom 3 rows of each leg
ARM_ROWS = (17, 23)    # side view rows hidden by the near arm
OUTLINE = (0x22, 0x09, 0x07)
HAIR_STYLES = ("cropped", "tied", "braid", "curly", "ponytail")
N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))
N8 = N4 + ((1, 1), (1, -1), (-1, 1), (-1, -1))


# ------------------------------------------------------------------ io
def load_views(folder, prefix=""):
    """South/east/north rotations; the south view is snapped onto the palette
    of the east/north rotations (the pro model and the rotation model differ
    by a few RGB steps)."""
    ims = {}
    for view in ("south", "east", "north"):
        ims[view] = Image.open(os.path.join(folder, f"{prefix}{view}.png")).convert("RGBA")
    pal = set()
    for key in ("east", "north"):
        for p in ims[key].getdata():
            if p[3] > 127:
                pal.add(p[:3])
    pal = sorted(pal)
    out = {}
    for key, im in ims.items():
        pix = {}
        for y in range(im.height):
            for x in range(im.width):
                p = im.getpixel((x, y))
                if p[3] > 127:
                    pix[(x, y)] = nearest(p, pal) if key == "south" else p[:3]
        out[key] = pix
    return out


def load_overrides(kind, ident):
    if kind == "base":
        path = os.path.join(SRC, "base_overrides.json")
    elif kind == "hair":
        path = os.path.join(SRC, f"hair_{ident}", "overrides.json")
    else:
        path = os.path.join(SRC, ident, "overrides.json")
    if os.path.exists(path):
        with open(path) as f:
            return json.load(f)
    return {}


# ------------------------------------------------------------------ colour tests
def is_outline(c):
    return hls(c)[1] < 0.14


def skin_like(c):
    h, l, s = hls(c)
    return 4 <= h <= 46 and s >= 0.28 and 0.3 <= l <= 0.96


def hair_like(c):
    h, l, s = hls(c)
    return 34 <= h <= 62 and s >= 0.22 and l >= 0.2


def outline_of(pix):
    """The source's dominant outline colour (sets differ: warm brown, black...)."""
    counts = {}
    for c in pix.values():
        if is_outline(c):
            counts[c] = counts.get(c, 0) + 1
    return max(counts, key=lambda c: (counts[c], -lum(c))) if counts else OUTLINE


def rects_to_set(rects):
    out = set()
    for r in rects or []:
        x0, y0, x1, y1 = r
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                out.add((x, y))
    return out


# ------------------------------------------------------------------ regions
def default_label(view, x, y):
    if view == "down":
        if y <= 15:
            return "head"
        if y >= LEG_TOP:
            return "legs"
        if 16 <= y <= 23 and (x <= 10 or x >= 20):
            return "arm_o" if x <= 10 else "arm_m"   # main hand = screen right
        if y >= 24 and (x <= 9 or x >= 20):
            return "arm_o" if x <= 9 else "arm_m"    # low-hanging hands
        return "torso"
    if view == "up":
        if y <= 14:
            return "head"
        if y >= LEG_TOP:
            return "legs"
        if 15 <= y <= 23 and (x <= 11 or x >= 21):
            return "arm_o" if x <= 11 else "arm_m"
        if y >= 24 and (x <= 10 or x >= 21):
            return "arm_o" if x <= 10 else "arm_m"
        return "torso"
    if view == "side":
        if y <= 15:
            return "head"
        if y >= LEG_TOP:
            return "legs"
        if ARM_ROWS[0] <= y <= ARM_ROWS[1] and 11 <= x <= 15:
            return "arm_m"                            # near arm
        return "torso"
    raise ValueError(view)


def label_map(view, pix, ov):
    lab = {p: default_label(view, *p) for p in pix}
    # Boots: the bottom BOOT_H rows of the legs. The side view keeps only the
    # near (grounded) foot; the far foot of a stride is dropped.
    legs = [p for p, l in lab.items() if l == "legs"]
    if legs:
        ground = max(p[1] for p in legs)
        top = ground - BOOT_H + 1
        if view == "side":
            xs = [p[0] for p in legs if p[1] == ground]
            x0, x1 = min(xs) - 1, max(xs) + 1
        for p in legs:
            if p[1] < top:
                continue
            if view == "side":
                lab[p] = "boot_m" if x0 <= p[0] <= x1 else "drop"
            else:
                lab[p] = "boot_m" if p[0] >= 16 else "boot_o"
    for rule in ov.get("labels", {}).get(view, []):
        pts = rects_to_set([rule["rect"]]) if "rect" in rule else {tuple(p) for p in rule["px"]}
        only = rule.get("only", "any")
        for p in pts:
            if p not in pix:
                continue
            c = pix[p]
            if only == "armor" and (is_outline(c) or skin_like(c)):
                continue
            if only == "skin" and not skin_like(c):
                continue
            if only == "opaque" and is_outline(c):
                continue
            lab[p] = rule["label"]
    return lab


# ------------------------------------------------------------------ materials
class Zones:
    """Face / eye areas of one view (source coords)."""

    def __init__(self, face, eyes):
        self.face = face
        self.eyes = eyes


def material_overrides(view, ov):
    """{pos: material} from an overrides "materials" block."""
    out = {}
    for rule in ov.get("materials", {}).get(view, []):
        pts = rects_to_set([rule["rect"]]) if "rect" in rule else {tuple(p) for p in rule["px"]}
        for p in pts:
            out[p] = rule["mat"]
    return out


def zones_for(view, ov, base_ov):
    face = ov.get("face", {}).get(view, base_ov.get("face", {}).get(view, []))
    eyes = ov.get("eyes", {}).get(view, base_ov.get("eyes", {}).get(view, []))
    return Zones(rects_to_set(face), rects_to_set(eyes))


def head_material(c, p, z, base_c=None, base_m=None, armored=False):
    """Material of a head pixel. `armored`: helmet source (unknown pixels are
    armour) instead of a bare head (unknown pixels are hair)."""
    h, l, s = hls(c)
    if p in z.eyes:
        if l < 0.2:
            return "eye"                      # lash / pupil
        if l >= 0.84 and (h >= 40 or l > 0.95):
            return "eye"                      # eye white / catch light
        if skin_like(c) and l >= 0.45:
            return "skin"
        return "eye"
    if l < 0.14:
        return "outline"
    if p in z.face:
        if l < 0.2:
            return "outline"
        if not armored and h >= 40 and hair_like(c):
            return "hair"                     # fringe over the face
        if skin_like(c) and (h < 39.5 or _near_skin(c)):
            return "skin"
        if hair_like(c) and (not armored or (base_m == "hair" and base_c is not None and dist2(c, base_c) < 900)):
            return "hair"
        return "armor" if armored else "skin"   # jaw / cheek shadows on a bare head
    if base_m in ("hair", "skin") and base_c is not None and dist2(c, base_c) < 700:
        return base_m
    if armored:
        if base_m == "skin" and skin_like(c) and _near_skin(c):
            return "skin"
        if hair_like(c) and _near_hair(c):
            return "hair"                     # hair peeking out under a hood
        return "armor"
    if skin_like(c) and h < 39.5 and l >= 0.45 and _near_skin(c) \
            and any((p[0] + dx, p[1] + dy) in z.face for dx, dy in N8):
        return "skin"                         # ears / neck just outside the face box
    return "hair"


_SKIN_REF = []
_HAIR_REF = []


def _near_skin(c):
    return bool(_SKIN_REF) and min(dist2(c, s) for s in _SKIN_REF) < 2000


def _near_hair(c):
    return bool(_HAIR_REF) and min(dist2(c, s) for s in _HAIR_REF) < 700


def torso_material_base(c, y=None):
    """Material of a bare-tunic torso pixel; skin only at the neck opening
    (a warm highlight lower down is a buckle or stitching)."""
    h, l, s = hls(c)
    if l < 0.14:
        return "outline"
    if 70 <= h <= 170:
        return "cloth"
    if l > 0.62 and h >= 39.5:
        return "trim"
    if l > 0.55 and h < 39.5:
        return "skin" if y is None or y <= 17 else "trim"
    return "leather"


# ------------------------------------------------------------------ parts
def crop(part):
    """part: {(x,y): (rgb, mat)} in source coords -> (Image, mats{(lx,ly): mat}, origin)."""
    xs = [p[0] for p in part]
    ys = [p[1] for p in part]
    x0, y0 = min(xs), min(ys)
    img = Image.new("RGBA", (max(xs) - x0 + 1, max(ys) - y0 + 1))
    mats = {}
    for (x, y), (c, m) in part.items():
        img.putpixel((x - x0, y - y0), tuple(c) + (255,))
        mats[(x - x0, y - y0)] = m
    return img, mats, (x0, y0)


def rank_table(img, mats):
    by_mat = {}
    for (x, y), m in mats.items():
        by_mat.setdefault(m, set()).add(img.getpixel((x, y))[:3])
    return {m: sorted(cols, key=lambda c: (lum(c), c)) for m, cols in by_mat.items()}


def write_part(img, mats, folder, name, ranks=None):
    """mats: dict (x,y)->material name for opaque pixels of img. `ranks`
    (material -> sorted colours) keeps shade indices identical between a head
    and its blink copy; colours missing from it are ranked by luminance."""
    own = rank_table(img, mats)
    if ranks is None:
        ranks = own
    else:
        merged = {}
        for m, cols in own.items():
            base = list(ranks.get(m, []))
            for c in cols:
                if c not in base:
                    base.append(c)
            merged[m] = sorted(base, key=lambda c: (lum(c), c))
        ranks = merged
    mask = Image.new("RGBA", img.size, (0, 0, 0, 0))
    for (x, y), m in mats.items():
        col = img.getpixel((x, y))[:3]
        mask.putpixel((x, y), (MATERIALS[m], ranks[m].index(col), len(ranks[m]), 255))
    os.makedirs(folder, exist_ok=True)
    img.save(os.path.join(folder, name + ".png"))
    mask.save(os.path.join(folder, name + ".mat.png"))
    return ranks


def apply_patches(part, patches, name, view, pix, line=OUTLINE):
    fills = []
    for pt in patches:
        if pt.get("part") != name or pt.get("view") != view:
            continue
        p = (pt["x"], pt["y"])
        val = pt.get("hex", "fill")
        if val == "clear":
            part.pop(p, None)
        elif val == "fill":
            fills.append(p)
        else:
            c = parse_hex(val)
            mat = pt.get("mat") or (part[p][1] if p in part else ("outline" if is_outline(c) else "armor"))
            part[p] = (c, mat)
    # Repaint "fill" pixels from their neighbours (majority colour, outline last).
    todo = set(fills)
    for _ in range(4):
        for p in sorted(todo):
            cand = {}
            for dx, dy in N4:
                q = (p[0] + dx, p[1] + dy)
                if q in part and q not in todo and part[q][1] != "outline":
                    cand[part[q]] = cand.get(part[q], 0) + 1
            if cand:
                part[p] = max(cand.items(), key=lambda kv: (kv[1], -lum(kv[0][0])))[0]
                todo.discard(p)
    for p in todo:
        part[p] = (line, "outline")


def outline_ring(core, pix, colour=OUTLINE):
    """4-neighbour outline around `core` ({pos: (rgb, mat)}); source outline
    colours are reused where the source already has an outline pixel."""
    ring = {}
    for (x, y) in core:
        for dx, dy in N4:
            q = (x + dx, y + dy)
            if q in core or q in ring:
                continue
            c = pix.get(q)
            ring[q] = ((c if c is not None and is_outline(c) else colour), "outline")
    return ring


def components(points, nbrs=N8):
    points = set(points)
    out = []
    while points:
        seed = points.pop()
        comp = {seed}
        stack = [seed]
        while stack:
            x, y = stack.pop()
            for dx, dy in nbrs:
                q = (x + dx, y + dy)
                if q in points:
                    points.discard(q)
                    comp.add(q)
                    stack.append(q)
        out.append(comp)
    return out


# ------------------------------------------------------------------ ramps
def _hue_shift(h, toward, amount):
    d = (toward - h + 540) % 360 - 180
    step = max(-amount, min(amount, d))
    return (h + step) % 360


def step_lum(c, dlum):
    """A darker (dlum<0) / lighter (dlum>0) shade of `c` whose luminance
    differs by about |dlum|, hue-shifted like a hand-made ramp (shadows lean
    cool, lights lean warm)."""
    h, l, s = hls(c)
    target = lum(c) + dlum
    best = c
    for i in range(1, 100):
        t = i / 100.0
        if dlum < 0:
            l2 = max(0.02, l * (1 - t))
            s2 = min(1.0, s * (1 + 0.25 * t))
            h2 = _hue_shift(h, 250 if 70 < h < 250 else 330, 20 * t)
        else:
            l2 = min(0.98, l + (1 - l) * t)
            s2 = max(0.0, s * (1 - 0.2 * t))
            h2 = _hue_shift(h, 55, 20 * t)
        r, g, b = colorsys.hls_to_rgb(h2 / 360.0, l2, s2)
        best = (int(round(r * 255)), int(round(g * 255)), int(round(b * 255)))
        if (dlum < 0 and lum(best) <= target) or (dlum > 0 and lum(best) >= target):
            break
    return best


def _hdist(a, b):
    d = abs(a - b) % 360
    return min(d, 360 - d)


def same_ramp(anchor, c):
    """True when `c` reads as a lighter/darker shade of the same material as
    `anchor` (hue and saturation may drift further the more the lightness
    differs - pixel-art ramps hue-shift)."""
    h0, l0, s0 = hls(anchor)
    h, l, s = hls(c)
    dl = abs(l - l0)
    if s0 < 0.12 or s < 0.12:
        return abs(s - s0) <= 0.14 + 0.2 * dl
    return _hdist(h, h0) <= 12 + 45 * dl and abs(s - s0) <= 0.16 + 0.45 * dl


def _pick_step(mid, cands, counts, target):
    """Candidate whose luminance offset from `mid` is closest to `target`."""
    best, score = None, 1e9
    for c in cands:
        d = lum(c) - lum(mid)
        if (target < 0 and d > -12) or (target > 0 and d < 12) or abs(d) > abs(target) * 1.7:
            continue
        sc = abs(d - target) - 3.0 * math.log(1 + counts.get(c, 0))
        if sc < score:
            best, score = c, sc
    return best


def build_ramp(counts, hint=None, palette=None):
    """Five distinct, luminance-ordered shades [deep, dark, mid, light,
    highlight] of the dominant material in `counts` ({rgb: n}). Shades are
    chosen from `palette` (the whole source's colours) when a harmonious one
    exists, otherwise synthesised with hue shifting."""
    counts = {c: n for c, n in counts.items() if not is_outline(c)}
    if not counts and hint is None:
        return None
    palette = dict(palette or {})
    for c, n in counts.items():
        palette[c] = palette.get(c, 0) + n
    if hint is not None:
        mid = min(palette, key=lambda c: dist2(hint, c))
        if dist2(mid, hint) > 300:
            mid = hint
    else:
        # Anchor = the colour whose material family covers most samples.
        def cover(a):
            return sum(n for c, n in counts.items() if same_ramp(a, c))
        mid = max(counts, key=lambda a: (cover(a), counts[a], -abs(lum(a) - 120)))
        fam = {c: n for c, n in counts.items() if same_ramp(mid, c)}
        # Prefer the most used colour of the family unless it is an extreme.
        by_l = sorted(fam, key=lum)
        top = max(fam, key=lambda c: (fam[c], -abs(lum(c) - 120)))
        if len(by_l) >= 3 and top in (by_l[0], by_l[-1]):
            acc, half = 0, sum(fam.values()) / 2.0
            for c in by_l:
                acc += fam[c]
                if acc >= half:
                    top = c
                    break
        mid = top
    def down(c, most):
        # Dark materials get proportionally smaller steps so the deep shade
        # never collapses into the outline.
        return -max(10.0, min(most, 0.42 * lum(c)))

    cands = [c for c in palette if not is_outline(c) and same_ramp(mid, c)]
    dark = _pick_step(mid, cands, palette, down(mid, 30)) or step_lum(mid, down(mid, 30))
    light = _pick_step(mid, cands, palette, 30) or step_lum(mid, 30)
    cands_d = [c for c in palette if not is_outline(c) and same_ramp(dark, c)]
    cands_l = [c for c in palette if not is_outline(c) and same_ramp(light, c)]
    deep = _pick_step(dark, cands_d, palette, down(dark, 26)) or step_lum(dark, down(dark, 26))
    hi = _pick_step(light, cands_l, palette, 26) or step_lum(light, 26)
    ramp = [deep, dark, mid, light, hi]
    # Enforce strictly increasing luminance with a visible step.
    for i in range(1, 5):
        if lum(ramp[i]) < lum(ramp[i - 1]) + 10:
            ramp[i] = step_lum(ramp[i - 1], 14)
    for i in range(3, -1, -1):
        if lum(ramp[i]) > lum(ramp[i + 1]) - 8:
            ramp[i] = step_lum(ramp[i + 1], -10)
    return [hexc(c) for c in ramp]


def _count(d, c):
    d[c] = d.get(c, 0) + 1


# ------------------------------------------------------------------ side torso
def _back_samples(back_pix, back_lab, y, n):
    """n colours for row y of the side view's hidden back, taken from the
    right flank of the back (north) view so belts and plates continue.
    Glints and glows (gems, orbs, catch-lights) are replaced by the row's
    dominant colour: they belong to the back view's centre, not the flank."""
    row = [back_pix[(x, y)] for x in range(0, 32)
           if back_lab.get((x, y)) == "torso" and (x, y) in back_pix and not is_outline(back_pix[(x, y)])]
    if not row:
        return []
    counts = {}
    for c in row:
        counts[c] = counts.get(c, 0) + 1
    mode = max(counts, key=lambda c: (counts[c], -abs(lum(c) - 110)))

    def odd(c):
        h, l, s = hls(c)
        return lum(c) > 190 or (s > 0.5 and not same_ramp(mode, c) and counts[c] < 3)

    flank = [back_pix[(x, y)] for x in range(16, 32)
             if back_lab.get((x, y)) == "torso" and (x, y) in back_pix and not is_outline(back_pix[(x, y)])]
    flank = [mode if odd(c) else c for c in flank] or [mode]
    if len(flank) >= n:
        return flank[-n:]
    return [flank[0]] * (n - len(flank)) + flank


def rebuild_side_back(torso, back_pix, back_lab, back_x, mat_of, line=OUTLINE):
    """The near arm hides the back half of the side-view torso. Rebuild it as
    the same garment wrapping round: colours come from the same rows of the
    back view's flank (belts and plates continue), the column next to the new
    back outline is one shade darker for form, and the back gets an outline."""
    for y in range(ARM_ROWS[0], ARM_ROWS[1] + 1):
        row = sorted(x for (x, yy) in torso if yy == y)
        vis = [x for x in row if x > back_x and torso[(x, y)][1] != "outline"]
        for x in list(row):
            if x < back_x:
                torso.pop((x, y), None)
        if not vis:
            continue
        xf = min(vis)
        hidden = list(range(back_x + 1, xf))
        if hidden:
            take = _back_samples(back_pix, back_lab, y, len(hidden)) or [torso[(xf, y)][0]] * len(hidden)
            for x, c in zip(hidden, take):
                torso[(x, y)] = (c, mat_of(c))
            c0, m0 = torso[(hidden[0], y)]
            torso[(hidden[0], y)] = (_darker_in(c0, torso, m0), m0)
        torso[(back_x, y)] = (line, "outline")
    # Below the arm rows the near hand can still hang over the hip: repaint
    # those skin pixels like hidden ones.
    for y in (ARM_ROWS[1] + 1, ARM_ROWS[1] + 2):
        spots = sorted(x for (x, yy) in torso if yy == y and x <= 15 and torso[(x, y)][1] != "outline"
                       and skin_like(torso[(x, y)][0]) and _near_skin(torso[(x, y)][0]))
        if not spots:
            continue
        take = _back_samples(back_pix, back_lab, y, len(spots))
        for i, x in enumerate(spots):
            c = take[i] if take else line
            torso[(x, y)] = (c, "outline" if is_outline(c) else mat_of(c))


def _darker_in(c, part, mat):
    """Next darker colour of the same material already used in `part`."""
    pal = sorted({pc for (pc, pm) in part.values() if pm == mat}, key=lum)
    cands = [q for q in pal if lum(c) - 70 < lum(q) < lum(c) - 6 and same_ramp(c, q)]
    if cands:
        return max(cands, key=lum)
    h, l, s_ = hls(c)
    r, g, b = colorsys.hls_to_rgb(h / 360.0, l * 0.8, s_)
    return (int(round(r * 255)), int(round(g * 255)), int(round(b * 255)))


# ------------------------------------------------------------------ blink
def make_blink(head, line_mode="mid"):
    """Closed-eye copy of a head part ({pos: (rgb, mat)}), or None when no
    eye is visible. Each eye box (iris + lash row) becomes lid skin with a
    dark lash line across its lower-middle row."""
    eyes = [p for p, (c, m) in head.items() if m == "eye"]
    if not eyes:
        return None
    skins = {}
    for c, m in head.values():
        if m == "skin":
            skins[c] = skins.get(c, 0) + 1
    if not skins:
        return None
    lid = max(skins, key=lambda c: (skins[c], lum(c)))
    lash = min((c for c, m in head.values() if m in ("eye", "outline")), key=lum)
    out = dict(head)
    for comp in components(eyes, N8):
        xs = [p[0] for p in comp]
        ys = [p[1] for p in comp]
        x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
        line = y0 + (y1 - y0 + 1) // 2 if y1 > y0 else y0
        for p in comp:
            below = (p[0], p[1] + 1)
            fill = head[below][0] if below in head and head[below][1] == "skin" else lid
            out[p] = (fill, "skin")
        # The closed lid is a lash line across the eye's widest row; a side
        # view eye (1px iris) gets a 2px line so it does not read as a pupil.
        width = {y: [p[0] for p in comp if p[1] == y] for y in range(y0, y1 + 1)}
        iris = [p for p in comp if head[p][0] != lash and lum(head[p][0]) >= 20]
        irx = sorted({p[0] for p in iris}) or list(range(x0, x1 + 1))
        if len(irx) == 1:
            line = max(p[1] for p in iris) if iris else y1
            for x in (irx[0] - 1, irx[0]):
                if (x, line) in out and out[(x, line)][1] in ("skin", "eye"):
                    out[(x, line)] = (lash, "outline")
        else:
            if line_mode == "low":
                line = max(p[1] for p in iris) if iris else y1
                xs_line = [p[0] for p in iris if p[1] == line]
            else:
                xs_line = width.get(line, [])
            for x in xs_line:
                out[(x, line)] = (lash, "outline")
    return out


# ------------------------------------------------------------------ extraction
def classify_parts(kind, ident, views, base, ov, base_ov):
    """Label every source pixel and build the part dicts for every view."""
    parts = {}
    labels = {}
    for dname, sname in VIEWS.items():
        pix = views[sname]
        lab = label_map(dname, pix, ov)
        labels[dname] = lab
        z = zones_for(dname, ov, base_ov)
        bpix = base[sname] if base else {}
        blab = base_labels(dname, bpix, base_ov) if base else {}
        vp = {}
        # ---- head
        head = {}
        mat_ov = material_overrides(dname, ov)
        for p, c in pix.items():
            if lab[p] != "head":
                continue
            bc = bpix.get(p)
            bm = blab.get(p)
            if kind == "set":
                m = head_material(c, p, z, bc, bm, armored=True)
            elif kind == "hair" and bc is not None and bm in ("hair", "skin", "eye", "outline") \
                    and dist2(c, bc) < 500:
                m = bm                        # unchanged from the base: same material
            else:
                m = head_material(c, p, z)
            head[p] = (c, mat_ov.get(p, m))
        if kind == "hair" and base and dname != "down":
            # Tails and braids hang behind the body: they show in the side
            # and back views only (the front view keeps the plain head).
            head.update(hair_extras(dname, pix, lab, bpix, head, z, blab))
        vp["head"] = head
        # ---- torso
        torso = {}
        for p, c in pix.items():
            if lab[p] != "torso":
                continue
            if kind == "set":
                bm = blab.get(p)
                m = "outline" if is_outline(c) else ("skin" if (bm == "skin" and skin_like(c)) else "armor")
            else:
                m = torso_material_base(c, p[1])
            torso[p] = (c, m)
        vp["torso"] = torso
        # ---- pauldrons (clean shapes with a fresh outline)
        for side in ("m", "o"):
            keep_skin = "pauldron_skinlike_ok" in ov.get("flags", [])
            core = {p: (c, "armor") for p, c in pix.items()
                    if lab[p] == "pauldron_" + side and not is_outline(c)
                    and (keep_skin or not (skin_like(c) and _near_skin(c)))}
            if dname == "side" and side == "m" and "no_side_pauldron" in ov.get("flags", []):
                core = {}
            if len(core) >= 3:
                comps = sorted(components(core, N8), key=len, reverse=True)
                core = {p: core[p] for comp in comps if len(comp) >= 2 for p in comp}
                vp["pauldron_" + side] = {**core, **outline_ring(core, pix, outline_of(pix))}
        # ---- boots
        for side in ("m", "o"):
            pts = {p: pix[p] for p in pix if lab[p] == "boot_" + side}
            if pts:
                vp["boot_" + side] = {p: (c, "outline" if is_outline(c) else ("leather" if kind == "base" else "armor"))
                                      for p, c in pts.items()}
        parts[dname] = vp
    return parts, labels


_BASE_LABEL_CACHE = {}


def base_labels(dname, bpix, base_ov):
    """Material of every base pixel (used as the reference for states)."""
    key = dname
    if key in _BASE_LABEL_CACHE:
        return _BASE_LABEL_CACHE[key]
    lab = label_map(dname, bpix, base_ov)
    z = zones_for(dname, {}, base_ov)
    mat_ov = material_overrides(dname, base_ov)
    out = {}
    for p, c in bpix.items():
        if lab[p] == "head":
            out[p] = mat_ov.get(p, head_material(c, p, z))
        elif lab[p] == "torso":
            out[p] = torso_material_base(c, p[1])
        else:
            out[p] = "skin" if skin_like(c) and not is_outline(c) else "other"
    _BASE_LABEL_CACHE[key] = out
    return out


def hair_extras(dname, pix, lab, bpix, head, z, blab):
    """Hair below the head rows (tails, braids): hair-coloured pixels that
    differ from the base and connect to the head, plus their outline."""
    extra = {}
    frontier = [p for p in head]
    seen = set(head)
    palette = {c for (c, m) in head.values() if m == "hair"}

    def differs(p):
        return p not in bpix or dist2(pix[p], bpix[p]) > 900

    def hairy(c, q):
        if blab.get(q) == "skin" and skin_like(c):
            return False                      # the base shows skin here (arm, nape)
        if palette and min(dist2(c, h) for h in palette) < 900:
            return True
        h, l, s = hls(c)
        return (34 <= h <= 62 and s >= 0.2 and l >= 0.2) or (22 <= h <= 50 and s >= 0.3 and 0.1 <= l < 0.4)

    while frontier:
        x, y = frontier.pop()
        here = head.get((x, y)) or extra.get((x, y))
        from_line = here is not None and here[1] == "outline"
        for dx, dy in N4:
            q = (x + dx, y + dy)
            if q in seen or q not in pix or lab.get(q) in ("head", "arm_m", "arm_o"):
                continue
            c = pix[q]
            if not differs(q):
                continue
            if q not in bpix:
                ok = True                     # outside the base body: only new hair lives there
            elif is_outline(c):
                ok = not from_line            # cross a 1px line (a braid tie), never run along one
            else:
                ok = hairy(c, q)
            if ok:
                seen.add(q)
                extra[q] = (c, "outline" if is_outline(c) else "hair")
                frontier.append(q)
    # Specks (1-2 px) are AI noise around the neck, not hair.
    for comp in components(list(extra), N4):
        if len(comp) <= 2:
            for q in comp:
                del extra[q]
    # True outline pixels hugging the new hair.
    for (x, y) in list(extra):
        if extra[(x, y)][1] != "hair":
            continue
        for dx, dy in N4:
            q = (x + dx, y + dy)
            if q in pix and q not in head and q not in extra and lum(pix[q]) < 20 and differs(q) \
                    and lab.get(q) not in ("arm_m", "arm_o"):
                extra[q] = (pix[q], "outline")
    return extra


def sample_ramps(dname, pix, lab, samples):
    for arm in ("arm_m", "arm_o"):
        pts = [p for p in pix if lab[p] == arm]
        if not pts:
            continue
        top = min(p[1] for p in pts)
        bottom = max(p[1] for p in pts)
        for (x, y) in pts:
            c = pix[(x, y)]
            if is_outline(c):
                continue
            if y >= bottom - 1:
                _count(samples["hand"], c)
            elif y <= top + 3:
                _count(samples["arm_upper"], c)
            else:
                _count(samples["arm_lower"], c)
    legs = [p for p in pix if lab[p] == "legs"]
    for p in legs:
        if not is_outline(pix[p]):
            _count(samples["leg"], pix[p])


def extract(kind, ident, views, base, ov, base_ov, debug=False):
    """kind: base | set | hair."""
    global _SKIN_REF, _HAIR_REF
    if base:
        _SKIN_REF = sorted({c for sname, bp in base.items() for p, c in bp.items()
                            if skin_like(c) and hls(c)[0] < 39.5 and hls(c)[1] > 0.45})
        _HAIR_REF = sorted({c for dname, sname in VIEWS.items() for p, c in base[sname].items()
                            if default_label(dname, *p) == "head" and hair_like(c)
                            and head_material(c, p, zones_for(dname, {}, base_ov)) == "hair"})
    parts, labels = classify_parts(kind, ident, views, base, ov, base_ov)
    patches = ov.get("patches", [])
    if kind == "hair":
        folder = os.path.join(ART, "hair")
    else:
        folder = os.path.join(ART, "base" if kind == "base" else os.path.join("sets", ident))
    meta = {"parts": {}, "materials": {}}
    samples = {"arm_upper": {}, "arm_lower": {}, "hand": {}, "leg": {}}
    for dname, sname in VIEWS.items():
        pix = views[sname]
        lab = labels[dname]
        vp = parts[dname]
        sample_ramps(dname, pix, lab, samples)
        if kind == "hair":
            names = ["head"]
        else:
            names = ["head", "torso", "pauldron_m", "pauldron_o", "boot_m", "boot_o"]
        if kind != "hair" and dname == "side" and vp.get("torso"):
            back_x = ov.get("side_back_x", 12)
            bl = labels["up"]
            mat_of = (lambda c: torso_material_base(c, 20)) if kind == "base" else \
                     (lambda c: "outline" if is_outline(c) else "armor")
            rebuild_side_back(vp["torso"], views["north"], bl, back_x, mat_of, outline_of(pix))
        for name in names:
            part = vp.get(name)
            if not part:
                continue
            apply_patches(part, patches, name, dname, pix, outline_of(pix))
            if not part:
                continue
            img, mats, origin = crop(part)
            cel = [origin[0] + CEL_OFFSET[0], origin[1] + CEL_OFFSET[1]]
            fname = f"{ident}_{dname}" if kind == "hair" else f"{name}_{dname}"
            ranks = write_part(img, mats, folder, fname)
            if name == "head":
                meta["parts"][fname] = {"origin": cel}
                mode = ov.get("blink_line", {}).get(dname, "mid")
                blink = None if "no_blink" in ov.get("flags", []) else make_blink(part, mode)
                if blink:
                    bimg, bmats, borigin = crop(blink)
                    assert borigin == origin
                    write_part(bimg, bmats, folder, fname + "_blink", ranks)
                    meta["parts"][fname + "_blink"] = {"origin": cel}
                else:
                    for ext in (".png", ".mat.png"):
                        stale = os.path.join(folder, fname + "_blink" + ext)
                        if os.path.exists(stale):
                            os.remove(stale)
            elif name == "torso":
                meta["parts"][fname] = {"origin": cel}
            elif name.startswith("pauldron"):
                sh = SHOULDER[dname][name[-1]]
                meta["parts"][fname] = {"origin": cel, "shoulder": [sh[0], sh[1]]}
            elif name.startswith("boot"):
                side = name[-1]
                meta["parts"][fname] = {"pivot": [round(FOOT_X[dname][side] - cel[0], 2), 0.0], "origin": [0, 0]}
        if kind != "hair":
            # Drop stale files of parts this run no longer produces.
            for name in ("pauldron_m", "pauldron_o", "boot_m", "boot_o"):
                if not vp.get(name):
                    for ext in (".png", ".mat.png"):
                        stale = os.path.join(folder, f"{name}_{dname}{ext}")
                        if os.path.exists(stale):
                            os.remove(stale)
    if kind == "set":
        palette = {}
        for sname in VIEWS.values():
            for c in views[sname].values():
                if not is_outline(c) and not (skin_like(c) and _near_skin(c)):
                    palette[c] = palette.get(c, 0) + 1
        meta["materials"] = limb_ramps(samples, ov, palette)
    if debug:
        debug_sheet(kind, ident, views, labels, parts)
    return meta


def limb_ramps(samples, ov, palette):
    """Limb ramps of an armour state. Hands stay bare skin unless the
    overrides give them a glove ramp ("hand": [..] or "auto")."""
    hints = {k: parse_hex(v) for k, v in ov.get("ramp_hint", {}).items()}
    forced = ov.get("ramps", {})
    mats = {}
    plan = {
        "arm_upper": samples["arm_upper"],
        "arm_lower": samples["arm_lower"],
        "hand": samples["hand"] if forced.get("hand") == "auto" or "hand" in hints else None,
        "leg_upper": samples["leg"],
        "leg_lower": samples["leg"],
    }
    for key, counts in plan.items():
        f = forced.get(key, "auto")
        if f == "skin":
            continue
        if isinstance(f, list):
            mats[key] = [h.lstrip("#") for h in f]
            continue
        if counts is None:
            continue
        if key not in hints:
            # Bare skin on a sleeve segment means "no sleeve": keep appearance skin.
            sk = sum(n for c, n in counts.items() if skin_like(c) and _near_skin(c))
            tot = sum(n for c, n in counts.items() if not is_outline(c))
            if tot and sk / tot > 0.6:
                continue
        counts = {c: n for c, n in counts.items() if not (skin_like(c) and _near_skin(c))} or counts
        r = build_ramp(counts, hints.get(key), palette)
        if r:
            mats[key] = r
    return mats


# ------------------------------------------------------------------ debug
LABEL_TINT = {"head": (255, 60, 60), "torso": (60, 90, 255), "legs": (255, 230, 0), "arm_m": (0, 230, 0),
              "arm_o": (255, 0, 255), "boot_m": (255, 140, 0), "boot_o": (160, 90, 0),
              "pauldron_m": (0, 255, 255), "pauldron_o": (0, 150, 150), "drop": (255, 255, 255)}
MAT_TINT = {"outline": (30, 30, 30), "skin": (255, 170, 120), "hair": (255, 230, 0), "eye": (0, 200, 255),
            "cloth": (60, 180, 60), "trim": (255, 255, 255), "leather": (140, 80, 30), "trousers": (120, 60, 160),
            "armor": (160, 160, 180), "glow": (255, 0, 255)}


def debug_sheet(kind, ident, views, labels, parts):
    Z = 10
    sheet = Image.new("RGBA", (3 * (32 * Z * 2 + 20), 32 * Z + 10), (50, 60, 45, 255))
    d = ImageDraw.Draw(sheet)
    for i, (dname, sname) in enumerate(VIEWS.items()):
        pix = views[sname]
        ox = i * (32 * Z * 2 + 20)
        for (x, y), c in pix.items():
            d.rectangle([ox + x * Z, y * Z, ox + x * Z + Z - 1, y * Z + Z - 1], fill=c)
            t = LABEL_TINT.get(labels[dname].get((x, y)), (0, 0, 0))
            d.rectangle([ox + x * Z, y * Z, ox + x * Z + 3, y * Z + 3], fill=t)
        mx = ox + 32 * Z + 10
        for name, part in parts[dname].items():
            for (x, y), (c, m) in part.items():
                t = MAT_TINT.get(m, (255, 0, 0))
                k = 0.5 + 0.5 * lum(c) / 255.0
                d.rectangle([mx + x * Z, y * Z, mx + x * Z + Z - 1, y * Z + Z - 1],
                            fill=tuple(int(v * k) for v in t))
        for k in range(0, 33, 4):
            d.line([(ox, k * Z), (ox + 32 * Z, k * Z)], fill=(255, 255, 255, 70))
            d.line([(ox + k * Z, 0), (ox + k * Z, 32 * Z)], fill=(255, 255, 255, 70))
    os.makedirs(REVIEW, exist_ok=True)
    sheet.save(os.path.join(REVIEW, f"labels-{ident}.png"))


# ------------------------------------------------------------------ main
def run_base(debug):
    base_ov = load_overrides("base", "base")
    base = load_views(SRC, "base_")
    meta = extract("base", "base", base, base, base_ov, base_ov, debug)
    with open(os.path.join(ART, "base", "set.json"), "w") as f:
        json.dump(meta, f, indent=1)
    print("base parts:", sorted(meta["parts"].keys()))


def run_set(set_id, name, debug):
    base_ov = load_overrides("base", "base")
    base = load_views(SRC, "base_")
    ov = load_overrides("set", set_id)
    views = load_views(os.path.join(SRC, set_id))
    meta = extract("set", set_id, views, base, ov, base_ov, debug)
    old = os.path.join(ART, "sets", set_id, "set.json")
    if name is None and os.path.exists(old):
        name = json.load(open(old)).get("name", set_id)
    meta["name"] = name or set_id
    os.makedirs(os.path.join(ART, "sets", set_id), exist_ok=True)
    with open(old, "w") as f:
        json.dump(meta, f, indent=1)
    print(set_id, "parts:", sorted(meta["parts"].keys()))
    print("materials:", json.dumps(meta.get("materials", {})))


def run_hair(styles, debug):
    base_ov = load_overrides("base", "base")
    base = load_views(SRC, "base_")
    path = os.path.join(ART, "hair", "hair.json")
    data = {"styles": {}, "parts": {}}
    if os.path.exists(path):
        data = json.load(open(path))
    for style in styles:
        folder = os.path.join(SRC, f"hair_{style}")
        if not os.path.isdir(folder):
            print("missing", folder)
            continue
        ov = load_overrides("hair", style)
        views = load_views(folder)
        meta = extract("hair", style, views, base, ov, base_ov, debug)
        data["styles"][style] = True
        for k in list(data["parts"]):
            if k.startswith(style + "_"):
                del data["parts"][k]
        data["parts"].update(meta["parts"])
        print("hair", style, sorted(meta["parts"].keys()))
    os.makedirs(os.path.join(ART, "hair"), exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, indent=1)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    debug = "--debug" in sys.argv
    name = None
    if "--name" in sys.argv:
        name = sys.argv[sys.argv.index("--name") + 1]
        args = [a for a in args if a != name]
    target = args[0] if args else "all"
    if target == "base":
        run_base(debug)
    elif target == "hair":
        run_hair(args[1:] or list(HAIR_STYLES), debug)
    elif target == "all":
        run_base(debug)
        for sid in sorted(os.listdir(os.path.join(SRC))):
            if os.path.isfile(os.path.join(SRC, sid, "south.png")) and not sid.startswith("hair_") and sid != "held":
                run_set(sid, None, debug)
        run_hair(list(HAIR_STYLES), debug)
    else:
        run_set(target, name, debug)


if __name__ == "__main__":
    main()
