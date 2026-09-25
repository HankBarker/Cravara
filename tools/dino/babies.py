"""Baby versions of the forest dinosaurs, drawn by PixelLab from their
parents' drawings (tools/dino/new_species.py restyle), in the parents'
palettes, then framed for prepare.py (KEY = <species>_baby).

    python tools/dino/babies.py swatches            # palette swatches from art/dino-v2/palettes
    python tools/dino/babies.py restyle SPECIES [VIEW ...] [--keep N]
    python tools/dino/babies.py drawings SPECIES

A baby is about half its parent's size with a big head, big eyes, short legs
and soft, small plates, horns or crests: cute, but plainly the same animal.
"""
import os
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
NEW = os.path.join(ROOT, "art", "dino-v2", "new")
PALETTES = os.path.join(ROOT, "art", "dino-v2", "palettes")

# species: (scale of the parent's drawing, restyle canvas, frame W H, words)
BABY = {
    "dodo": (0.8, 32, (18, 18), "a fluffy baby dodo chick with a big round head, a small stubby beak and tiny wings"),
    "lystro": (0.8, 32, (22, 16), "a baby lystrosaurus on four short stubby legs: a stout low barrel body, a big round head with a small beak and tiny tusk nubs, olive green"),
    "stego": (0.55, 48, (36, 26), "a baby stegosaurus hatchling with a big round head, big eyes, short stubby legs and small soft back plates"),
    "trike": (0.55, 48, (32, 26), "a baby triceratops hatchling with red-orange skin, a big head, big eyes, a small frill edged with teal crystal, tiny horn nubs and short stubby legs"),
    "longneck": (0.5, 48, (38, 34), "a baby longneck sauropod hatchling with a big head, big eyes, a short neck and short stubby legs"),
    "raptor": (0.65, 40, (28, 26), "a baby raptor hatchling with a big head, big eyes, a short snout, tiny claws, a stubby tail and small teal-blue crystal spines down its back"),
    "allo": (0.55, 48, (36, 28), "a baby allosaurus hatchling with a big head, big eyes, a short snout and short legs"),
    "parasaur": (0.5, 48, (40, 30), "a baby parasaurolophus hatchling with a big head, big eyes, a short rounded nub of a crest sweeping back from its head, a short duck-like snout and short stubby legs, green with a pale belly"),
}
DIRECTION = {"down": "south", "side": "east", "up": "north"}


def swatch(species):
    colours = open(os.path.join(PALETTES, species + ".hex")).read().split()
    n = len(colours)
    side = 48
    cols = 8
    cell = side // cols
    img = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    for i, hexc in enumerate(colours[:cols * cols]):
        c = tuple(int(hexc[j:j + 2], 16) for j in (0, 2, 4)) + (255,)
        x, y = (i % cols) * cell, (i // cols) * cell
        for yy in range(y, y + cell):
            for xx in range(x, x + cell):
                img.putpixel((xx, yy), c)
    out = os.path.join(NEW, species + "_baby")
    os.makedirs(out, exist_ok=True)
    img.save(os.path.join(out, "palette.png"))
    return n


def restyle(species, views, keep):
    scale, canvas, _, words = BABY[species]
    key = species + "_baby"
    palette = os.path.join(NEW, key, "palette.png")
    procs = []
    for view in views:
        desc = "%s, facing %s" % (words, {"side": "right", "down": "the viewer", "up": "away from the viewer"}[view])
        cmd = [sys.executable, os.path.join(HERE, "new_species.py"), "restyle", key, "--from", species,
               "--view", view, "--scale", str(scale), "--canvas", str(canvas), "--keep", str(keep),
               "--palette", palette, "--desc", desc]
        procs.append((view, subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)))
    for view, proc in procs:
        out, _ = proc.communicate()
        print("[%s %s] %s" % (species, view, out.strip().splitlines()[-1] if out.strip() else "(no output)"), flush=True)


# Babies drawn in all three facings; the rest are side-on only.
ALL_VIEWS = []


def drawings(species):
    """Frame the baby's drawings where prepare.py reads them (side, and the
    front and back only for ALL_VIEWS babies)."""
    _, _, (w, h), _ = BABY[species]
    key = species + "_baby"
    art = os.path.join(ROOT, "game", "Forest", "creatures", "art")
    for view, direction in (("side", "east"), ("down", "south"), ("up", "north")):
        path = os.path.join(art, key + ("" if view == "side" else "_" + view) + ".png")
        if view != "side" and species not in ALL_VIEWS:
            if os.path.exists(path):
                os.remove(path)
            continue
        img = Image.open(os.path.join(NEW, key, direction + ".png")).convert("RGBA")
        img = img.crop(img.getbbox())
        if img.width > w or img.height > h:
            raise SystemExit("%s %s view %s is bigger than the frame %dx%d" % (key, view, img.size, w, h))
        frame = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        frame.alpha_composite(img, ((w - img.width) // 2, h - img.height))
        frame.save(path)
        print(key, view, img.size, "->", os.path.relpath(path, ROOT))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    keep = int(sys.argv[sys.argv.index("--keep") + 1]) if "--keep" in sys.argv else 130
    if "--keep" in sys.argv:
        args = [a for a in args if a != str(keep)]
    if args[0] == "swatches":
        for sp in BABY:
            print(sp, swatch(sp), "colours")
    elif args[0] == "restyle":
        restyle(args[1], args[2:] or ["side", "down", "up"], keep)
    elif args[0] == "drawings":
        drawings(args[1])


if __name__ == "__main__":
    main()
