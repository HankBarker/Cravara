"""Draw a species' crystal-sick variant from its resting drawings (pass 14).

    python tools/dino/crystal_bases.py KEY [--level heavy|light] [--seed N] [--submit-only]

The Sky-Fang's sickness: crystal breaking out through the hide. PixelLab's
edit_image takes the key's three resting drawings (art/dino-v2/first/KEY_side,
_down, _up) and applies ONE edit to all of them in the same call, so the three
facings stay consistent (images up to 128 px go together; bigger ones one at a
time). Results land in art/dino-v2/crystal/KEY/ for review; `adopt` copies a
reviewed set to art/dino-v2/first/KEY_crystal_*.png, where gen.py animates it.

    python tools/dino/crystal_bases.py adopt KEY

Cost: 20-40 generations per call (billed by the frame grid).
"""
import base64
import json
import os
import re
import shutil
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import pixellab_mcp as pl  # noqa: E402

from PIL import Image  # noqa: E402

FIRST = os.path.join(ROOT, "art", "dino-v2", "first")
OUT = os.path.join(ROOT, "art", "dino-v2", "crystal")
VIEWS = ("side", "down", "up")
EDIT = {
    "ridge": ("A ridge of sharp pale blue quartz crystals has grown out along its spine and down its "
              "tail, with a few smaller crystals on its shoulders. Keep the same animal, its shape, pose "
              "and colours everywhere else."),
    "heavy": ("Pale blue Sky-Fang crystal has broken out through its hide: clusters of sharp icy-blue "
              "quartz crystals jut from its back, shoulders and tail, a few smaller ones on its legs. "
              "Keep the same animal, pose and colours everywhere else."),
    "light": ("A few small pale blue quartz crystals poke out of its back and shoulders. Keep the same "
              "animal, pose and colours everywhere else."),
}


def opt(flag, default=None):
    return sys.argv[sys.argv.index(flag) + 1] if flag in sys.argv else default


def poll(client, job):
    for _ in range(90):
        r = client.call("get_image", {"job_id": job})
        imgs = pl.images_of(r)
        low = pl.text_of(r).lower()
        if imgs:
            return imgs
        if "fail" in low or "error" in low:
            raise RuntimeError(pl.text_of(r)[:300])
        time.sleep(10)
    raise RuntimeError("timed out waiting for %s" % job)


def submit(client, paths, text, seed):
    args = {"images_base64": ["@" + p for p in paths], "description": text, "no_background": True}
    if seed is not None:
        args["seed"] = int(seed)
    r = client.call("edit_image", pl.inline_files(args))
    t = pl.text_of(r)
    m = re.search(r"\b([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\b", t)
    if not m:
        raise RuntimeError("no job id: " + t[:300])
    cost = re.search(r"cost:\s*([0-9.]+)", t)
    print("SUBMIT edit_image job %s cost %s (%d frames)" % (m.group(1), cost.group(1) if cost else "?", len(paths)), flush=True)
    return m.group(1)


def main():
    if sys.argv[1] == "adopt":
        key = sys.argv[2]
        for v in VIEWS:
            shutil.copy(os.path.join(OUT, key, v + ".png"), os.path.join(FIRST, "%s_crystal_%s.png" % (key, v)))
        print("adopted", key)
        return
    key = sys.argv[1]
    level = opt("--level", "heavy")
    seed = opt("--seed")
    paths = [os.path.join(FIRST, "%s_%s.png" % (key, v)) for v in VIEWS]
    images = [Image.open(p).convert("RGBA") for p in paths]
    canvas = images[0].size
    os.makedirs(os.path.join(OUT, key), exist_ok=True)
    # A big canvas whose drawings all fit one 128 px window (with room above
    # for the crystals) is edited as that window, all views in one call.
    window = None
    if max(canvas) > 128:
        boxes = [im.getbbox() for im in images]
        x0, y0 = min(b[0] for b in boxes), min(b[1] for b in boxes)
        x1, y1 = max(b[2] for b in boxes), max(b[3] for b in boxes)
        if x1 - x0 <= 124 and y1 - y0 <= 110:
            cx = (x0 + x1) // 2
            wx = min(max(0, cx - 64), canvas[0] - 128)
            wy = min(max(0, y1 + 2 - 128), canvas[1] - 128) if canvas[1] >= 128 else 0
            window = (wx, max(0, wy), wx + 128, max(0, wy) + min(128, canvas[1]))
    src = []
    for v, im in zip(VIEWS, images):
        p = os.path.join(OUT, key, "_in_%s.png" % v)
        (im.crop(window) if window else im).save(p)
        src.append(p)
    size = max(Image.open(src[0]).size)
    groups = [list(range(3))] if size <= 128 else [[i] for i in range(3)]
    client = pl.Client()
    for group in groups:
        job = submit(client, [src[i] for i in group], EDIT[level], seed)
        if "--submit-only" in sys.argv:
            continue
        imgs = poll(client, job)
        for i, im in zip(group, imgs):
            dst = os.path.join(OUT, key, VIEWS[i] + ".png")
            got = Image.open(__import__("io").BytesIO(base64.b64decode(im["data"]))).convert("RGBA")
            if window:
                full = Image.new("RGBA", canvas, (0, 0, 0, 0))
                full.paste(got, window[:2])
                got = full
            got.save(dst)
            print("SAVED", dst, flush=True)
    json.dump({"level": level, "seed": seed, "edit": EDIT[level]}, open(os.path.join(OUT, key, "edit.json"), "w"), indent=1)


if __name__ == "__main__":
    main()
