"""Front-view tail sweep built from the creature's own art.

    python tools/dino/tail_front.py KEY [--tip PX | --tip-boxes "x0,y0,x1,y1;..."]
                                        [--reach PX] [--view down|up]
                                        [--hip ROW] [--hide x0,y0,x1,y1]

Seen from the front the tail is hidden behind the body, and the animation
models always turned the whole animal side-on to show it. This builds the
clip the way the design asks instead: the body keeps facing the viewer (its
own front idle frames) while the spiked end of the tail - cut from the side
drawing - swings out from behind it to one side in a wide eased arc, holds on
the contact frame and swings back. The tail is drawn behind the body so the
body occludes its root. The clip swings to the viewer's right; the game mirrors
it toward the target (catalogue "swing").

Writes art/dino-v2/clips/KEY/tail_swing_down/ (or tail_swing_up/ with --view
up: the back view, the tail hanging toward the viewer swung out in front of
the body; pass 12's ankylosaur, whose generated back sweep grew a log) with
the side clip's frame count, and records the method in the ledger and the
contact frame in hits.json.
"""
import json
import math
import os
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import gen  # noqa: E402

OUT = gen.OUT


def tail_tip(key, length, boxes=None):
    """The last `length` px of the tail from the side drawing (facing right, so
    the tail is at the left), as its own image pointing right. `boxes`
    [(x0, y0, x1, y1), ...] pick the tail exactly where a column cut would take
    some of the body too (the ankylosaur's pitched drawing: its rump rises over
    the tail's root)."""
    side = Image.open(os.path.join(OUT, "first", "%s_side.png" % key)).convert("RGBA")
    box = side.getbbox()
    if boxes:
        picked = Image.new("RGBA", side.size, (0, 0, 0, 0))
        for b in boxes:
            picked.paste(side.crop(b), (b[0], b[1]))
        tb = picked.getbbox()
        return picked.crop(tb).transpose(Image.FLIP_LEFT_RIGHT)
    crop = side.crop((box[0], box[1], box[0] + length, box[3]))
    tb = crop.getbbox()
    crop = crop.crop(tb)
    return crop.transpose(Image.FLIP_LEFT_RIGHT)  # tip now at the right


def rotate(img, degrees):
    """Pixel-art rotation: 4x nearest upscale, nearest rotate, nearest sample."""
    if abs(degrees) < 0.5:
        return img
    big = img.resize((img.width * 4, img.height * 4), Image.NEAREST)
    rot = big.rotate(degrees, resample=Image.NEAREST, expand=True)
    return rot.resize((max(1, rot.width // 4), max(1, rot.height // 4)), Image.NEAREST)


def ease(u):
    return 1 - (1 - u) ** 3


def opt(flag, default=None):
    return sys.argv[sys.argv.index(flag) + 1] if flag in sys.argv else default


def main():
    key = sys.argv[1]
    tip_len = int(opt("--tip", 22))
    reach = int(opt("--reach", 0))
    # --view up: the back view, the tail hanging toward the viewer and swung
    # out in front of the body (pass 12, the ankylosaur). --hip ROW: the row
    # the tail turns about (default: 62% down the body). --hide x0,y0,x1,y1:
    # the resting tail, where the drawing shows it (the ankylosaur's club over
    # its rump from the front, below its hips from behind), taken out of the
    # body once the swing is under way.
    view = opt("--view", "down")
    back = view == "up"
    hide = [int(v) for v in opt("--hide").split(",")] if opt("--hide") else None
    body_dir = os.path.join(OUT, "clips", key, "idle_" + view)
    bodies = [Image.open(os.path.join(body_dir, n)).convert("RGBA") for n in sorted(os.listdir(body_dir)) if n.endswith(".png")]
    side_dir = os.path.join(OUT, "clips", key, "tail_swing_side")
    n = len([f for f in os.listdir(side_dir) if f.endswith(".png")])
    base = Image.open(os.path.join(OUT, "first", "%s_%s.png" % (key, view))).convert("RGBA")
    bb = base.getbbox()
    w, h = base.size
    boxes = [tuple(int(v) for v in b.split(",")) for b in opt("--tip-boxes").split(";")] if opt("--tip-boxes") else None
    tip = tail_tip(key, tip_len, boxes)
    # Hips: the middle of the body, a little above the feet; the swing arcs
    # from straight behind (hidden) out to the viewer's right at ground level.
    hip = float(opt("--hip", bb[1] + (bb[3] - bb[1]) * 0.62))
    pivot = ((bb[0] + bb[2]) / 2.0, hip)
    arm = reach or int((bb[2] - bb[0]) * 0.5) + tip.width // 2
    contact = int(n * 0.45)
    last = n - 2
    frames = []
    for i in range(n):
        if i <= contact:
            u = ease(i / max(1, contact))
        elif i <= contact + 1:
            u = 1.0
        else:
            u = max(0.0, 1.0 - (i - contact - 1) / max(1, last - contact - 1))
            u = u * u
        theta = math.radians(78.0 * u)  # 0 = straight behind (or at the viewer), 78 = out to the side
        # Screen offset of the tail's middle: out to the right, and from behind
        # (above the hips) down toward the ground line as it comes round; from
        # the back, from below the hips (toward the viewer) up to the side.
        up_down = 1.0 if back else -1.0
        cx = pivot[0] + math.sin(theta) * arm
        cy = pivot[1] + up_down * math.cos(theta) * arm * 0.42
        # The tail points away from the hips: rising behind (or hanging toward
        # the viewer), level at the side.
        seg = rotate(tip, -up_down * math.degrees(math.atan2(math.cos(theta) * 0.42, math.sin(theta) + 1e-6)))
        canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        body = bodies[i % len(bodies)]
        if hide and u >= 0.1:
            body = body.copy()
            body.paste((0, 0, 0, 0), tuple(hide))
        if 0.6 < u:
            # A small lean into the swing.
            shifted = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            shifted.alpha_composite(body, (-1, 0))
            body = shifted
        at = (int(round(cx - seg.width / 2)), int(round(cy - seg.height / 2)))
        # Near-straight-back the tail is hidden by the body; drawing its rotated
        # root there would poke out on the far side (unless the drawing shows
        # its tail at rest, which the swing then replaces).
        show = u >= 0.1 if hide else u > 0.38
        if back:
            canvas.alpha_composite(body)
            if show: canvas.alpha_composite(seg, at)
        else:
            if show: canvas.alpha_composite(seg, at)
            canvas.alpha_composite(body)
        frames.append(canvas)
    frames[0] = bodies[0]
    name = "tail_swing_" + view
    dst = os.path.join(OUT, "clips", key, name)
    os.makedirs(dst, exist_ok=True)
    for old in os.listdir(dst):
        if old.endswith(".png"):
            os.remove(os.path.join(dst, old))
    for i, f in enumerate(frames):
        f.save(os.path.join(dst, "%03d.png" % i))
    led = gen.load_ledger(key)
    entry = led.get(name, {})
    entry.update({"status": "done", "method": "tail_front.py (%s body + side tail tip)" % ("back" if back else "front"), "frames": n})
    led[name] = entry
    gen.save_ledger(key, led)
    hits_path = os.path.join(HERE, "hits.json")
    hits = json.load(open(hits_path)) if os.path.exists(hits_path) else {}
    hits.setdefault(key, {}).setdefault("tail_swing", {})
    if isinstance(hits[key]["tail_swing"], dict):
        hits[key]["tail_swing"][view] = contact
    with open(hits_path, "w") as f:
        json.dump(hits, f, indent=1)
        f.write(chr(10))
    print("built", dst, n, "frames, contact", contact)


if __name__ == "__main__":
    main()
