"""A stalk seen from the front or behind, made from the walk (pass 15).

    python tools/dino/stalk_from_walk.py KEY/VIEW [KEY/VIEW ...]

From the front or behind, a hunter creeping low reads as its walk, slowed (the
stalk clip plays at 6 fps to the walk's 9, at a creeping pace). PixelLab kept
drawing these views standing up tall instead (the allosaur's neck grew into a
post; raptors raised their tails straight up), so for the views named the
cleaned walk frames are copied in as the stalk (8 and 8). No generations.
Run it again after `gen.py clean` for the same clip (clean rewrites it).
Used on: allo/up, deino/down, rex/up, utah/down.
"""
import os
import shutil
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
CLIPS = os.path.join(ROOT, "art", "dino-v2", "clips")


def main():
    for arg in sys.argv[1:]:
        key, view = arg.split("/")
        src = os.path.join(CLIPS, key, "walk_" + view)
        dst = os.path.join(CLIPS, key, "stalk_" + view)
        frames = sorted(n for n in os.listdir(src) if n.endswith(".png"))
        os.makedirs(dst, exist_ok=True)
        for old in os.listdir(dst):
            if old.endswith(".png"):
                os.remove(os.path.join(dst, old))
        for n in frames:
            shutil.copyfile(os.path.join(src, n), os.path.join(dst, n))
        print("%s stalk_%s: %d frames from its walk" % (key, view, len(frames)))


if __name__ == "__main__":
    main()
