"""Clear what the model left floating over a few cleaned frames (pass 15).

    python tools/dino/speck_fix.py KEY/CLIP_VIEW FRAME[,FRAME...] [--cap N] [--copy M]

gen.py's cleaning keeps any island within 2 px of the body (claws and teeth
come apart that much), so a speck just over a mane stays. For the frames named:
  - every island not touching the body (8-neighbours) goes;
  - with --cap N, anything more than N px above the neighbouring frames' top goes
    too (a growth joined to the body by a thread, like the dimetrodon's).
  - with --copy M, the frames become copies of frame M instead (a hold of one
    step, for a growth too tangled with the body to cut out).
Run it again after `gen.py clean` for the same clip (clean rewrites the frames).
Used on: yuty/stalk_side 2,3; dimetrodon/stalk_up 4 --copy 3.
"""
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CLIPS = os.path.join(ROOT, "art", "dino-v2", "clips")
N8 = [(-1, -1), (0, -1), (1, -1), (-1, 0), (1, 0), (-1, 1), (0, 1), (1, 1)]


def islands(img):
    w, h = img.size
    opaque = {(x, y) for y in range(h) for x in range(w) if img.getpixel((x, y))[3] >= 128}
    seen, out = set(), []
    for start in opaque:
        if start in seen:
            continue
        seen.add(start)
        stack, comp = [start], []
        while stack:
            x, y = stack.pop()
            comp.append((x, y))
            for dx, dy in N8:
                q = (x + dx, y + dy)
                if q in opaque and q not in seen:
                    seen.add(q)
                    stack.append(q)
        out.append(comp)
    return sorted(out, key=len, reverse=True)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    cap = int(sys.argv[sys.argv.index("--cap") + 1]) if "--cap" in sys.argv else None
    copy = int(sys.argv[sys.argv.index("--copy") + 1]) if "--copy" in sys.argv else None
    # (The options' numbers come after the clip and its frames.)
    args = args[:2]
    name, frames = args[0], [int(f) for f in args[1].split(",")]
    key, clip = name.split("/")
    folder = os.path.join(CLIPS, key, clip)
    count = len([n for n in os.listdir(folder) if n.endswith(".png")])
    for f in frames:
        path = os.path.join(folder, "%03d.png" % f)
        if copy is not None:
            Image.open(os.path.join(folder, "%03d.png" % copy)).save(path)
            print("%s %03d: now a copy of %03d" % (name, f, copy))
            continue
        # The frames either side (wrapping round a loop) say where its top should be.
        top = min(Image.open(os.path.join(folder, "%03d.png" % (n % count))).convert("RGBA").getbbox()[1] for n in (f - 1, f + 1))
        img = Image.open(path).convert("RGBA")
        comps = islands(img)
        gone = 0
        for comp in comps[1:]:
            for p in comp:
                img.putpixel(p, (0, 0, 0, 0))
                gone += 1
        if cap is not None:
            for y in range(0, max(0, top - cap)):
                for x in range(img.width):
                    if img.getpixel((x, y))[3]:
                        img.putpixel((x, y), (0, 0, 0, 0))
                        gone += 1
        img.save(path)
        print("%s %03d: %d px cleared" % (name, f, gone))


if __name__ == "__main__":
    main()
