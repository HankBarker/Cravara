"""Pass 12: first drawings of the new beasts, each facing restyled by PixelLab
pixflux from an existing species' drawing of the same facing (1 generation
per view; the species palette from palettes12.py is forced).

    python tools/dino/restyle12.py KEY[:view,...] ... [--tag t1] [--keep N]

Writes art/dino-v2/new/KEY/redraw/<view>_<tag>.png (and the init image next
to it). Pick the good ones by eye, then copy them to
art/dino-v2/new/KEY/<east|south|north>.png for new_species.py drawings.
"""
import os
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
ART = os.path.join(ROOT, "game", "Forest", "creatures", "art")
NEW = os.path.join(ROOT, "art", "dino-v2", "new")
sys.path.insert(0, HERE)
from new_species import FRAME  # noqa: E402

LOOK = {
    "dimetrodon": "dimetrodon, a sprawling reptile with a tall curved sail on its back, a red and orange sail "
                  "held up by dark spines, a big head with sharp teeth, thick legs splayed out to the sides, "
                  "a long tail, earthy brown scales",
    "carno": "carnotaurus, a lean red predatory dinosaur with two thick bull-like horns above its eyes, a short "
             "deep snout with sharp teeth, tiny arms, powerful long legs, dark stripes along its back",
    "yuty": "yutyrannus, a huge tyrannosaur covered in shaggy white feathers like fur, pale grey shading, a small "
            "red crest on its snout, dark scaly legs with claws, big jaws with teeth",
    "proto": "protoceratops, a small stocky beaked dinosaur with a broad frill behind its head and no horns, "
             "sandy tan skin with darker stripes, an orange frill, four short legs",
    "anky": "ankylosaurus, a low wide armoured dinosaur covered in bony plates with rows of short spikes along "
            "its sides, a heavy round club at the end of its tail, ochre and brown armour, bone-white spikes",
    "compy": "compsognathus, a tiny slim green dinosaur running on two legs, a long thin tail, small head with "
             "sharp teeth, yellow belly, dark stripes",
}
FACING = {"down": ", seen from the front, facing the viewer", "up": ", seen from behind, walking away",
          "side": ", side view facing right"}
# key: (source species, scale, keep, canvas) per view; the same for all views
# unless a view entry overrides.
SPECS = {
    "dimetrodon": {"src": "stego", "scale": 1.05, "keep": 115, "canvas": 96},
    "carno": {"src": "allo", "scale": 1.0, "keep": 150, "canvas": 96},
    "yuty": {"src": "rex", "scale": 1.0, "keep": 135, "canvas": 96},
    "proto": {"src": "trike", "scale": 0.62, "keep": 130, "canvas": 64},
    "anky": {"src": "stego", "scale": 1.0, "keep": 105, "canvas": 96},
    "compy": {"src": "raptor", "scale": 0.5, "keep": 140, "canvas": 48},
}


def init_image(key, view, scale):
    src = SPECS[key]["src"]
    w, h = FRAME[src]
    path = os.path.join(ART, src + ("" if view == "side" else "_" + view) + ".png")
    cel = Image.open(path).convert("RGBA").crop((0, 0, w, h))
    cel = cel.crop(cel.getbbox())
    cel = cel.resize((max(1, round(cel.width * scale)), max(1, round(cel.height * scale))), Image.NEAREST)
    out = os.path.join(NEW, key)
    os.makedirs(out, exist_ok=True)
    p = os.path.join(out, "init_%s.png" % view)
    cel.save(p)
    return p


def main():
    args = sys.argv[1:]
    tag = "t1"
    keep_override = None
    if "--tag" in args:
        tag = args[args.index("--tag") + 1]
    if "--keep" in args:
        keep_override = int(args[args.index("--keep") + 1])
    jobs = []
    for a in args:
        if a.startswith("--") or a in (tag, str(keep_override)):
            continue
        key, _, views = a.partition(":")
        for view in (views.split(",") if views else ["side", "down", "up"]):
            spec = SPECS[key]
            init = init_image(key, view, spec["scale"])
            keep = keep_override or spec["keep"]
            c = str(spec["canvas"])
            jobs.append([sys.executable, os.path.join(HERE, "redraw_view.py"), key, "%s_%s" % (view, tag),
                         "--desc", LOOK[key] + FACING[view], "--view", view, "--init", init,
                         "--keep", str(keep), "--size", c, c])
    running = []
    for cmd in jobs:
        running.append(subprocess.Popen(cmd))
        if len(running) >= 6:
            running.pop(0).wait()
    for p in running:
        p.wait()


if __name__ == "__main__":
    main()
