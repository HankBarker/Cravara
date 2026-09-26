"""Pass 14: give a crystal-sick key the same procedural fixes its clean kind got.

    python tools/dino/crystal_fix.py KEY_crystal [--list]

The crystal keys (tools/dino/crystal_bases.py) were animated by gen.py from
drawings that stand exactly like their clean kind's, so the clips the models
could not draw for the clean kind (front walks, back walks, tail sweeps, the
trike's gore, the parasaur's front displays...) are rebuilt the same way, with
the same tools and arguments. FIXES mirrors the `method` entries in the clean
keys' ledgers (art/dino-v2/ledger/<species>.json).
"""
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
CLIPS = os.path.join(ROOT, "art", "dino-v2", "clips")
sys.path.insert(0, HERE)
import gen  # noqa: E402


def mark(key, clip_view, method):
    """Record the method in the ledger so `gen.py clean` leaves the clip be."""
    led = gen.load_ledger(key)
    e = led.get(clip_view, {})
    e.update({"status": "done", "method": method})
    led[clip_view] = e
    gen.save_ledger(key, led)

FIXES = {
    "raptor": [["walk_front.py", "{k}"], ["walk_front.py", "{k}", "--run"]],
    "trike": [["cap_clamp.py", "{k}", "idle_down", "run_down", "eat_down", "--cap", "6"],
              ["walk_back.py", "{k}"], ["walk_back.py", "{k}", "--run"],
              ["gore_from_windup.py", "{k}"]],
    "stego": [["tail_side.py", "{k}"], ["walk_back.py", "{k}"],
              ["walk_front.py", "{k}"], ["walk_front.py", "{k}", "--run"],
              ["tail_front.py", "{k}"],
              ["copy", "tail_swing_down", "threat_down"], ["copy", "tail_swing_up", "threat_up"]],
    "longneck": [["cap_clamp.py", "{k}", "idle_down", "--tol", "1"],
                 ["walk_front.py", "{k}"], ["walk_front.py", "{k}", "--run"],
                 ["tail_side.py", "{k}", "--far"]],
    "parasaur": [["lunge_front.py", "{k}", c] for c in ("idle", "eat", "stomp", "roar", "hurt", "death")]
    + [["walk_front.py", "{k}"], ["walk_front.py", "{k}", "--run"]],
    "deino": [["cap_clamp.py", "{k}", "walk_down", "run_down", "--tol", "1"]],
    "sucho": [["hold", "bite_down", "5,6", "7"],
              ["lift_back.py", "{k}", "roar", "--hip", "91", "--lift", "4"]],
    "spino": [["lift_back.py", "{k}", "bite", "--hip", "120", "--lift", "5"]],
    "utah": [],
}
# Fixes the crystal clips needed of their own (found by eye; the AI frames are
# kept in <clip>_ai): tails reared into pale spikes, a back tail sweep
# flattened into a bar, a post grown over the head, a crest pushed into a
# pillar, a crest that came and went.
CRYSTAL_EXTRA = {
    "raptor": [["keep", "sniff_down"], ["lunge_front.py", "{k}", "eat", "--view", "down"], ["move", "eat_down", "sniff_down"]],
    "trike": [["keep", "walk_down"], ["walk_front.py", "{k}"]],
    "stego": [["keep", "tail_swing_up"], ["tail_front.py", "{k}", "--view", "up"], ["copy", "tail_swing_up", "threat_up"]],
    "parasaur": [["keep", "roar_up"], ["lunge_front.py", "{k}", "roar", "--view", "up"]],
    "utah": [["keep", "walk_down"], ["keep", "run_down"], ["walk_front.py", "{k}"], ["walk_front.py", "{k}", "--run"]],
    "deino": [["keep", "slash_up"], ["lunge_front.py", "{k}", "bite", "--view", "up"], ["move", "bite_up", "slash_up"]],
    # The Suchomimus' front and back actions reared its snout and tail into spikes and bars.
    "sucho": [["keep", "bite_down"], ["keep", "bite_up"], ["keep", "chomp_down"], ["keep", "eat_down"],
              ["keep", "eat_up"], ["keep", "hurt_down"], ["keep", "run_up"],
              ["lunge_front.py", "{k}", "bite", "--view", "down"], ["lunge_front.py", "{k}", "bite", "--view", "up"],
              ["lunge_front.py", "{k}", "chomp", "--view", "down"], ["lunge_front.py", "{k}", "eat", "--view", "down"],
              ["lift_back.py", "{k}", "eat", "--hip", "91", "--lift", "-3"],
              ["lunge_front.py", "{k}", "hurt", "--view", "down"],
              ["copy", "walk_up", "run_up"]],
    # The spinosaur's front run thinned the sail into posts, its front graze reared the tail,
    # its back flinch flattened the sail into a disc.
    "spino": [["keep", "run_down"], ["keep", "eat_down"], ["keep", "hurt_up"],
              ["walk_front.py", "{k}", "--run"], ["lunge_front.py", "{k}", "eat", "--view", "down"],
              ["lift_back.py", "{k}", "hurt", "--hip", "120", "--lift", "2"]],
}


def copy_clip(key, src, dst):
    a = os.path.join(CLIPS, key, src)
    b = os.path.join(CLIPS, key, dst)
    if not os.path.isdir(a):
        print("  no", src, "to copy")
        return
    if os.path.isdir(b) and not os.path.isdir(b + "_ai"):
        shutil.copytree(b, b + "_ai")
    if os.path.isdir(b):
        shutil.rmtree(b)
    shutil.copytree(a, b)
    mark(key, dst, "copied from %s (as the clean kind's; the AI frames kept in %s_ai)" % (src, dst))
    print("  copied", src, "->", dst)


def hold(key, clip_view, frames, source):
    d = os.path.join(CLIPS, key, clip_view)
    src = os.path.join(d, "%03d.png" % int(source))
    for f in frames.split(","):
        shutil.copy2(src, os.path.join(d, "%03d.png" % int(f)))
    mark(key, clip_view, "frames %s = frame %s (as the clean kind's)" % (frames, source))
    print("  held frame", source, "over", frames, "in", clip_view)


def keep(key, clip_view):
    """Keep the AI frames beside the fix (once)."""
    d = os.path.join(CLIPS, key, clip_view)
    if os.path.isdir(d) and not os.path.isdir(d + "_ai"):
        shutil.copytree(d, d + "_ai")


def move(key, src, dst):
    """A procedural clip built under another clip's name, moved into place."""
    a = os.path.join(CLIPS, key, src)
    b = os.path.join(CLIPS, key, dst)
    if os.path.isdir(b):
        shutil.rmtree(b)
    shutil.move(a, b)
    led = gen.load_ledger(key)
    led.pop(src, None)
    gen.save_ledger(key, led)
    mark(key, dst, "lunge_front.py %s (as %s; the AI frames in %s_ai)" % (src, dst, dst))


def main():
    key = sys.argv[1]
    base = key.replace("_crystal", "")
    steps = FIXES.get(base, []) + (CRYSTAL_EXTRA.get(base, []) if key.endswith("_crystal") else [])
    for step in steps:
        args = [a.format(k=key) for a in step]
        if "--list" in sys.argv:
            print(" ".join(args))
            continue
        if args[0] == "copy":
            copy_clip(key, args[1], args[2])
        elif args[0] == "hold":
            hold(key, args[1], args[2], args[3])
        elif args[0] == "keep":
            keep(key, args[1])
        elif args[0] == "move":
            move(key, args[1], args[2])
        else:
            print(">", " ".join(args))
            subprocess.run([sys.executable, os.path.join(HERE, args[0])] + args[1:], check=True, cwd=ROOT)


if __name__ == "__main__":
    main()
