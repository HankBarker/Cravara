"""Pass 15: the new villages' buildings and the caves' mouths (PixelLab
pixflux, 1 generation each), in the forest props' palette.

    python tools/world/make_village_art.py [NAME ...] [--force]

  stilt_hut      Stillwater's houses: reed huts on stilts (the Mirefen's safe haven)
  fish_rack      a drying rack of fish and reeds (Stillwater)
  well           the oasis town's well (Tamar Oasis)
  canopy         a market canopy over fruit baskets (Tamar Oasis)
  reed_lantern   a lantern on a reed pole (Stillwater's light)
  cave_mouth     a cave's mouth in a rock face (recoloured per land by
                 tools/world/make_material_art.py's ramps: --caves)

Writes game/Forest/art/v7/<name>.png. The sprites are asked for without any
ground under them: ForestProp draws their contact with the ground.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "items"))
import foods  # noqa: E402  (its _pixflux and palette)

OUT = os.path.join(ROOT, "game", "Forest", "art", "v7")
NO_GROUND = ", standing alone, no ground, no grass, no shadow, no base, transparent background, top-down game prop"
ART = {
    "stilt_hut": ("a small round hut of woven reeds with a pointed thatched roof, raised on wooden stilts, a short ladder to its doorway, marsh fisherfolk house" + NO_GROUND, 48, 56),
    "fish_rack": ("a wooden drying rack of two posts and a crossbar hung with silver fish and bundles of reeds" + NO_GROUND, 32, 32),
    "well": ("a round stone well with a wooden roof frame, a crank and a hanging bucket, desert oasis well" + NO_GROUND, 32, 40),
    "canopy": ("a market canopy of striped sun-bleached orange and cream cloth on four wooden poles, baskets of fruit and melons under it" + NO_GROUND, 48, 40),
    "reed_lantern": ("a warm glowing paper lantern hanging from a tall bent reed pole" + NO_GROUND, 24, 48),
    "cave_mouth": ("a dark cave entrance in a craggy grey rock outcrop, a black opening under a stone arch, a few boulders at its sides" + NO_GROUND, 48, 40),
    # The Drip Cave's lost explorer (the quest cave), and after the tonic.
    "explorer_hurt": ("a wounded explorer in a torn green hooded cloak slumped sitting against a rock, clutching their side, a leather satchel and a snuffed lantern beside them" + NO_GROUND, 32, 32),
}
# Item icons (32x32, side view) for the caves' rewards.
ICONS = {
    "sleeper_fang": "a single enormous curved tyrannosaur fang, ivory yellowed with age, a crack of glowing blue crystal through its root, bound with a leather cord, game item icon",
}


def draw(name):
    desc, w, h = ART[name]
    call = {"description": desc, "width": w, "height": h, "no_background": True, "view": "low top-down",
            "outline": "selective outline", "shading": "medium shading", "detail": "highly detailed",
            "color_image_base64": "@" + os.path.join(ROOT, "game/WorldObjects/Images/Objects.png")}
    foods._pixflux(call, os.path.join(OUT, name + ".png"))


def draw_icon(name):
    call = {"description": ICONS[name], "width": 32, "height": 32, "no_background": True, "view": "side",
            "outline": "single color black outline", "shading": "medium shading", "detail": "highly detailed",
            "color_image_base64": "@" + foods.palette()}
    foods._pixflux(call, os.path.join(ROOT, "game", "Forest", "art", "items", name + ".png"))


## The cave mouth in each land's stone: the grey rock by brightness onto the
## bog's wet dark stone, the sand's warm stone, the ash country's pale stone.
CAVE_RAMPS = {
    "bog": ["141612", "20241c", "2e3428", "3f4636", "525a46", "687258", "7e886a"],
    "sand": ["3e2a1c", "5e412a", "815a38", "a47648", "c3955e", "dcb57a", "f0d49a"],
    "pale": ["2e2c2a", "47443f", "625e57", "7e7a71", "9a968c", "b6b2a6", "d0ccc0"],
}


def cave_recolours():
    from PIL import Image
    src = Image.open(os.path.join(OUT, "cave_mouth.png")).convert("RGBA")
    px = src.load()
    colours = sorted({px[x, y][:3] for y in range(src.height) for x in range(src.width) if px[x, y][3]}, key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2])
    for land, ramp in CAVE_RAMPS.items():
        out = src.copy()
        op = out.load()
        lo = 0.299 * colours[0][0] + 0.587 * colours[0][1] + 0.114 * colours[0][2]
        hi = 0.299 * colours[-1][0] + 0.587 * colours[-1][1] + 0.114 * colours[-1][2]
        for y in range(src.height):
            for x in range(src.width):
                c = px[x, y]
                if not c[3]:
                    continue
                l = 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
                if l < 14:
                    continue  # the opening stays black
                t = (l - lo) / max(1.0, hi - lo)
                h = ramp[min(len(ramp) - 1, int(round(t * (len(ramp) - 1))))]
                op[x, y] = (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), c[3])
        out.save(os.path.join(OUT, "cave_mouth_%s.png" % land))
        print("cave mouth", land)


def main():
    import subprocess
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    force = "--force" in sys.argv
    if "--caves" in sys.argv:
        cave_recolours()
        return
    if "--one" in sys.argv:
        if args[0] in ICONS:
            draw_icon(args[0])
        else:
            draw(args[0])
        return
    if "--icons" in sys.argv:
        todo = [n for n in (args or list(ICONS)) if force or not os.path.exists(os.path.join(ROOT, "game", "Forest", "art", "items", n + ".png"))]
        running = [subprocess.Popen([sys.executable, __file__, "--one", n]) for n in todo]
        for p in running:
            p.wait()
        return
    todo = [n for n in (args or list(ART)) if force or not os.path.exists(os.path.join(OUT, n + ".png"))]
    print("drawing", todo, flush=True)
    running = [subprocess.Popen([sys.executable, __file__, "--one", n]) for n in todo]
    for p in running:
        p.wait()


if __name__ == "__main__":
    main()
