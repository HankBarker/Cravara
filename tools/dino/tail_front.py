"""Front-view tail sweep built from the creature's own art.

    python tools/dino/tail_front.py KEY [--tip PX] [--reach PX] [--hold N]

Seen from the front the tail is hidden behind the body, and the animation
models always turned the whole animal side-on to show it. This builds the
clip the way the design asks instead: the body keeps facing the viewer (its
own front idle frames) while the spiked end of the tail - cut from the side
drawing - swings out from behind it to one side in a wide eased arc, holds on
the contact frame and swings back. The tail is drawn behind the body so the
body occludes its root. The clip swings to the viewer's right; the game mirrors
it toward the target (catalogue "swing").

Writes art/dino-v2/clips/KEY/tail_swing_down/ (same frame count as the side
clip) and records the method in art/dino-v2/ledger/KEY.json.
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


def tail_tip(key, length):
    """The last `length` px of the tail from the side drawing (facing right, so
    the tail is at the left), as its own image pointing right."""
    side = Image.open(os.path.join(OUT, "first", "%s_side.png" % key)).convert("RGBA")
    box = side.getbbox()
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


def main():
    key = sys.argv[1]
    tip_len = int(sys.argv[sys.argv.index("--tip") + 1]) if "--tip" in sys.argv else 22
    reach = int(sys.argv[sys.argv.index("--reach") + 1]) if "--reach" in sys.argv else 0
    body_dir = os.path.join(OUT, "clips", key, "idle_down")
    bodies = [Image.open(os.path.join(body_dir, n)).convert("RGBA") for n in sorted(os.listdir(body_dir)) if n.endswith(".png")]
    side_dir = os.path.join(OUT, "clips", key, "tail_swing_side")
    n = len([f for f in os.listdir(side_dir) if f.endswith(".png")])
    base = Image.open(os.path.join(OUT, "first", "%s_down.png" % key)).convert("RGBA")
    bb = base.getbbox()
    w, h = base.size
    tip = tail_tip(key, tip_len)
    # Hips: the middle of the body, a little above the feet; the swing arcs
    # from straight behind (hidden) out to the viewer's right at ground level.
    pivot = ((bb[0] + bb[2]) / 2.0, bb[1] + (bb[3] - bb[1]) * 0.62)
    arm = reach or int((bb[2] - bb[0]) * 0.5) + tip.width // 2
    contact = int(n * 0.45)
    back = n - 2
    frames = []
    for i in range(n):
        if i <= contact:
            u = ease(i / max(1, contact))
        elif i <= contact + 1:
            u = 1.0
        else:
            u = max(0.0, 1.0 - (i - contact - 1) / max(1, back - contact - 1))
            u = u * u
        theta = math.radians(78.0 * u)  # 0 = straight behind, 78 = out to the side
        # Screen offset of the tail's middle: out to the right, and from behind
        # (above the hips) down toward the ground line as it comes round.
        cx = pivot[0] + math.sin(theta) * arm
        cy = pivot[1] - math.cos(theta) * arm * 0.42
        # The tail points away from the hips: rising behind, level at the side.
        seg = rotate(tip, math.degrees(math.atan2(math.cos(theta) * 0.42, math.sin(theta) + 1e-6)))
        canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        # Near-straight-back the tail is hidden by the body; drawing its rotated
        # root there would poke out on the far side.
        if u > 0.38:
            canvas.alpha_composite(seg, (int(round(cx - seg.width / 2)), int(round(cy - seg.height / 2))))
        body = bodies[i % len(bodies)]
        if 0.6 < u:
            # A small lean into the swing.
            shifted = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            shifted.alpha_composite(body, (-1, 0))
            body = shifted
        canvas.alpha_composite(body)
        frames.append(canvas)
    frames[0] = bodies[0]
    dst = os.path.join(OUT, "clips", key, "tail_swing_down")
    os.makedirs(dst, exist_ok=True)
    for old in os.listdir(dst):
        if old.endswith(".png"):
            os.remove(os.path.join(dst, old))
    for i, f in enumerate(frames):
        f.save(os.path.join(dst, "%03d.png" % i))
    led = gen.load_ledger(key)
    entry = led.get("tail_swing_down", {})
    entry.update({"status": "done", "method": "tail_front.py (front body + side tail tip)", "frames": n})
    led["tail_swing_down"] = entry
    gen.save_ledger(key, led)
    hits_path = os.path.join(HERE, "hits.json")
    hits = json.load(open(hits_path)) if os.path.exists(hits_path) else {}
    hits.setdefault(key, {}).setdefault("tail_swing", {})
    if isinstance(hits[key]["tail_swing"], dict):
        hits[key]["tail_swing"]["down"] = contact
    json.dump(hits, open(hits_path, "w"), indent=1)
    print("built", dst, n, "frames, contact", contact)


if __name__ == "__main__":
    main()
