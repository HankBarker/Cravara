"""Pass 17: the furniture of the wilds' fallen houses and inns (Hank: "old
dilapidated stone building... we don't have chairs, but we could add in chairs,
and there's a bed and a chest... an old dining hall with food in it, or an old
inn"). PixelLab pixflux, 1 generation each, in the forest props' palette.

    python tools/world/make_ruin_art.py [NAME ...] [--force] [--finish]

  --finish   redo the game's sprites from the kept drawings (no generation)

  chair        a plain wooden chair, a little worn
  table        a wooden table
  table_food   the same table set with a meal (bread, a roast, mugs)
  barrel       an old wooden barrel
  rubble       a heap of fallen stones and broken timber (a ruin's floor)

Writes game/Forest/art/v8/<name>.png. Asked for without any ground under them:
ForestProp draws their contact with the ground. PixelLab draws nothing smaller
than 32 x 32, so each is drawn at twice its size (kept in art/pass17/raw/),
cleaned of the ground the model set it on anyway and shrunk (finish).
"""
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "items"))
import foods  # noqa: E402  (its _pixflux and palette)

OUT = os.path.join(ROOT, "game", "Forest", "art", "v8")
NO_GROUND = ", standing alone, no ground, no grass, no shadow, no base, transparent background, top-down game prop"
ART = {
    "chair": ("a simple old wooden chair with a straight back, worn planks, seen from above at an angle" + NO_GROUND, 16, 24),
    "table": ("a sturdy old rectangular wooden table on four legs, worn plank top, seen from above at an angle" + NO_GROUND, 32, 24),
    "table_food": ("an old rectangular wooden table set with a meal: a round loaf of bread, a roast leg of meat on a plate, two wooden mugs and an apple, seen from above at an angle" + NO_GROUND, 32, 24),
    "barrel": ("an old wooden barrel with dark iron hoops, seen from above at an angle" + NO_GROUND, 16, 24),
    "rubble": ("a low heap of fallen grey stones, broken mortar and a snapped wooden beam, the rubble of a collapsed wall" + NO_GROUND, 32, 24),
}


def clean(name, img):
    """The model sets some on a patch of ground anyway: grass under the chair
    and barrel (and the barrel's pale ring), a pale slab under the laid table."""
    import colorsys
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a < 8:
                continue
            hh, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            green = g > r + 12 and g > b + 6
            if green and (y > h * 0.55 or name in ("chair", "barrel")):
                px[x, y] = (0, 0, 0, 0)
            elif name == "barrel" and ((y > h * 0.8 and v > 0.6) or (y > h * 0.85 and 0.1 < hh < 0.3)):
                px[x, y] = (0, 0, 0, 0)
            elif name == "table_food" and y > h * 0.5 and s < 0.3 and 0.5 < v < 0.9:
                px[x, y] = (0, 0, 0, 0)
    # And the specks left of it (fewer than two neighbours).
    snap = img.copy().load()
    for y in range(h):
        for x in range(w):
            if snap[x, y][3] < 8:
                continue
            near = sum(1 for dy in (-1, 0, 1) for dx in (-1, 0, 1)
                       if (dx or dy) and 0 <= x + dx < w and 0 <= y + dy < h and snap[x + dx, y + dy][3] > 8)
            if near < 2:
                px[x, y] = (0, 0, 0, 0)
    return img


def shrink(img):
    """Half size: each 2 x 2 block its colour nearest the block's mean (the
    mode darkened the drawings: their outlines won every tie)."""
    box = img.getbbox()
    img = img.crop((box[0] - box[0] % 2, box[1] - box[1] % 2, box[2] + box[2] % 2, box[3] + box[3] % 2))
    w, h = img.width // 2, img.height // 2
    px = img.load()
    out = Image.new("RGBA", (w, h))
    op = out.load()
    for y in range(h):
        for x in range(w):
            solid = [c for c in (px[x * 2 + i, y * 2 + j] for j in (0, 1) for i in (0, 1)) if c[3] > 96]
            if len(solid) < 2:
                continue
            mean = [sum(c[k] for c in solid) / len(solid) for k in range(3)]
            best = min(solid, key=lambda c: sum((c[k] - mean[k]) ** 2 for k in range(3)))
            op[x, y] = best[:3] + (255,)
    return out.crop(out.getbbox())


def finish(name):
    """The game's sprite from the kept drawing (art/pass17/raw/<name>.png)."""
    raw = os.path.join(ROOT, "art", "pass17", "raw", name + ".png")
    small = shrink(clean(name, Image.open(raw)))
    small.save(os.path.join(OUT, name + ".png"))
    print("finished", name, small.size, flush=True)


def draw(name):
    desc, w, h = ART[name]
    call = {"description": desc, "width": w * 2, "height": h * 2, "no_background": True, "view": "low top-down",
            "outline": "selective outline", "shading": "medium shading", "detail": "highly detailed",
            "color_image_base64": "@" + os.path.join(ROOT, "game/WorldObjects/Images/Objects.png")}
    raw = os.path.join(ROOT, "art", "pass17", "raw", name + ".png")
    foods._pixflux(call, raw)
    finish(name)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    force = "--force" in sys.argv
    if "--finish" in sys.argv:
        for name in args or list(ART):
            finish(name)
        return
    for name in args or list(ART):
        if name not in ART:
            print("unknown", name)
            continue
        out = os.path.join(OUT, name + ".png")
        if os.path.exists(out) and not force:
            print("have", os.path.relpath(out, ROOT))
            continue
        draw(name)


if __name__ == "__main__":
    main()
