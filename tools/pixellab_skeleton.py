#!/usr/bin/env python3
"""pixellab_skeleton.py — skeleton-driven animation for Cravera's dinosaurs.

WHY THIS EXISTS
---------------
PixelLab's MCP server can only animate a character from a fixed library of
*humanoid* motion templates (walk, jab, backflip...) or from a text description.
Neither knows what a theropod is: `body_type="humanoid"` produces an upright
lizard-person, and the quadruped templates are bear/cat/dog/horse/lion.

PixelLab's **v1 REST API** exposes the piece the MCP server does not:
`/animate-with-skeleton`, which drives generation from explicit pose keypoints.
That is the route to a proper hunched, horizontal-spine, tail-out dinosaur.

WHAT CAN AND CANNOT BE CHANGED
------------------------------
The skeleton *topology* is fixed — 18 COCO-style joints in a hardcoded bone
graph (see SKELETON_BONES). You cannot add a tail bone or invent a new rig.

What you CAN do is put those 18 joints wherever you like, and that is enough:
a dinosaur is not a new skeleton so much as a humanoid skeleton folded forward.
This module RETARGETS the joints onto theropod anatomy:

    NECK          -> the pelvis / centre of mass (both limb chains hang off it)
    NOSE+EYE+EAR  -> neck and skull, thrown FORWARD and level
    HIP/KNEE/LEG  -> the powerful hind legs, under the body
    SHOULDER/     -> the TAIL, trailing back and up from the pelvis
      ELBOW/ARM      (the forelimbs of a raptor are tiny; the tail matters more)

That mapping is what turns "upright lizard-man" into "hunched predator".

COORDINATES
-----------
x and y are normalised 0..1 over the canvas. x grows right, y grows DOWN
(image convention). `z_index` orders limbs front-to-back so the near leg
overlaps the far one.

Poses here are authored facing EAST (to the right) in side view, then mirrored
or re-projected for other directions.

USAGE
-----
    # fit the rig to an existing sprite (0.1 generations)
    python tools/pixellab_skeleton.py estimate game/Sprites/Raptor/raptor_sheet.png

    # draw a pose over the sprite to check it before spending anything (free)
    python tools/pixellab_skeleton.py preview --pose walk --phase 0.0 \
        --reference game/Sprites/Raptor/raptor_sheet.png --out check.png

    # generate animation frames from the rig
    python tools/pixellab_skeleton.py animate \
        --reference game/Sprites/Raptor/raptor_sheet.png \
        --pose walk --direction east --view side --out-dir out/
"""

import argparse
import base64
import io
import json
import math
import os
import sys
import urllib.error
import urllib.request

try:
    from PIL import Image, ImageDraw
except ImportError:
    sys.exit("This script requires Pillow. Install it with:  pip install Pillow")


API = "https://api.pixellab.ai/v1"

# The bone graph is fixed by PixelLab; reproduced from the Aseprite extension's
# skeleton.lua. Used for drawing previews, not sent to the API.
SKELETON_BONES = [
    ("NECK", "NOSE"),
    ("NECK", "RIGHT SHOULDER"), ("RIGHT SHOULDER", "RIGHT ELBOW"), ("RIGHT ELBOW", "RIGHT ARM"),
    ("NECK", "LEFT SHOULDER"), ("LEFT SHOULDER", "LEFT ELBOW"), ("LEFT ELBOW", "LEFT ARM"),
    ("NECK", "RIGHT HIP"), ("RIGHT HIP", "RIGHT KNEE"), ("RIGHT KNEE", "RIGHT LEG"),
    ("NECK", "LEFT HIP"), ("LEFT HIP", "LEFT KNEE"), ("LEFT KNEE", "LEFT LEG"),
    ("NOSE", "RIGHT EYE"), ("NOSE", "LEFT EYE"),
    ("RIGHT EYE", "RIGHT EAR"), ("LEFT EYE", "LEFT EAR"),
]

# Theropod rest pose, facing EAST (right), side view. Normalised canvas coords.
# The animal reads left-to-right as: tail tip -> pelvis -> ribcage -> neck -> snout,
# with the legs dropping from the pelvis. This is the shape the humanoid
# templates cannot produce.
THEROPOD_REST = {
    "NECK":           (0.46, 0.46),   # pelvis / pivot
    "NOSE":           (0.83, 0.34),   # snout, forward and level
    "LEFT EYE":       (0.78, 0.31),
    "RIGHT EYE":      (0.78, 0.33),
    "LEFT EAR":       (0.72, 0.30),
    "RIGHT EAR":      (0.72, 0.32),
    # tail: shoulder -> elbow -> arm, trailing back and lifting slightly
    "LEFT SHOULDER":  (0.36, 0.45),
    "RIGHT SHOULDER": (0.36, 0.47),
    "LEFT ELBOW":     (0.22, 0.40),
    "RIGHT ELBOW":    (0.22, 0.42),
    "LEFT ARM":       (0.09, 0.34),
    "RIGHT ARM":      (0.09, 0.36),
    # hind legs
    "LEFT HIP":       (0.48, 0.50),
    "RIGHT HIP":      (0.45, 0.51),
    "LEFT KNEE":      (0.52, 0.66),
    "RIGHT KNEE":     (0.43, 0.67),
    "LEFT LEG":       (0.50, 0.86),
    "RIGHT LEG":      (0.45, 0.87),
}

# Near-side limbs draw in front. Depth ordering for an east-facing animal.
Z_INDEX = {
    "LEFT HIP": 2, "LEFT KNEE": 2, "LEFT LEG": 2,
    "LEFT SHOULDER": 1, "LEFT ELBOW": 1, "LEFT ARM": 1,
    "LEFT EYE": 1, "LEFT EAR": 1,
    "RIGHT HIP": -2, "RIGHT KNEE": -2, "RIGHT LEG": -2,
    "RIGHT SHOULDER": -1, "RIGHT ELBOW": -1, "RIGHT ARM": -1,
    "RIGHT EYE": -1, "RIGHT EAR": -1,
    "NECK": 0, "NOSE": 0,
}


def _offset(pose, label, dx, dy):
    x, y = pose[label]
    pose[label] = (x + dx, y + dy)


def theropod_pose(action, phase):
    """Return {label: (x, y)} for a theropod at `phase` (0..1) of `action`.

    Motion is layered onto THEROPOD_REST rather than authored per frame, so the
    silhouette stays consistent and only the moving parts move.
    """
    pose = dict(THEROPOD_REST)
    t = phase * 2.0 * math.pi

    if action == "idle":
        # Breathing: whole body rises a hair, tail and head counter-drift.
        bob = math.sin(t) * 0.008
        for label in pose:
            _offset(pose, label, 0.0, -bob)
        _offset(pose, "NOSE", 0.0, -bob)
        for label in ("LEFT ARM", "RIGHT ARM"):
            _offset(pose, label, 0.0, bob * 2.0)

    elif action == "walk":
        # Legs alternate; body bobs twice per cycle; tail and head sway to
        # counterbalance, which is what sells weight on a two-legged animal.
        swing = math.sin(t) * 0.075
        lift = abs(math.sin(t)) * 0.045
        bob = abs(math.sin(t)) * 0.012

        _offset(pose, "LEFT KNEE", swing * 0.6, -lift * 0.5)
        _offset(pose, "LEFT LEG", swing, -lift)
        _offset(pose, "RIGHT KNEE", -swing * 0.6, -(0.045 - lift) * 0.5)
        _offset(pose, "RIGHT LEG", -swing, -(0.045 - lift))

        for label in ("NECK", "LEFT HIP", "RIGHT HIP", "LEFT SHOULDER", "RIGHT SHOULDER"):
            _offset(pose, label, 0.0, -bob)
        # tail sways opposite the stride
        for label, k in (("LEFT ELBOW", 0.5), ("RIGHT ELBOW", 0.5),
                         ("LEFT ARM", 1.0), ("RIGHT ARM", 1.0)):
            _offset(pose, label, -swing * 0.25 * k, -bob + math.sin(t) * 0.02 * k)
        for label in ("NOSE", "LEFT EYE", "RIGHT EYE", "LEFT EAR", "RIGHT EAR"):
            _offset(pose, label, swing * 0.12, -bob)

    elif action == "bite":
        # Anticipation (pull back) -> lunge -> recover. Readability beats
        # realism here: the wind-up is what telegraphs the attack to the player.
        if phase < 0.34:
            k = phase / 0.34
            reach, drop, tail = -0.06 * k, -0.04 * k, 0.05 * k
        elif phase < 0.67:
            k = (phase - 0.34) / 0.33
            reach, drop, tail = -0.06 + 0.20 * k, -0.04 + 0.10 * k, 0.05 - 0.11 * k
        else:
            k = (phase - 0.67) / 0.33
            reach, drop, tail = 0.14 * (1 - k), 0.06 * (1 - k), -0.06 * (1 - k)

        for label in ("NOSE", "LEFT EYE", "RIGHT EYE", "LEFT EAR", "RIGHT EAR"):
            _offset(pose, label, reach, drop)
        for label in ("NECK", "LEFT SHOULDER", "RIGHT SHOULDER"):
            _offset(pose, label, reach * 0.35, drop * 0.3)
        for label in ("LEFT ELBOW", "RIGHT ELBOW"):
            _offset(pose, label, -tail * 0.5, -tail * 0.4)
        for label in ("LEFT ARM", "RIGHT ARM"):
            _offset(pose, label, -tail, -tail * 0.8)

    elif action == "death":
        # Topple onto the flank: body sinks, legs fold, tail goes limp.
        k = phase
        for label in pose:
            _offset(pose, label, 0.0, 0.16 * k)
        for label in ("NOSE", "LEFT EYE", "RIGHT EYE", "LEFT EAR", "RIGHT EAR"):
            _offset(pose, label, -0.10 * k, 0.14 * k)
        for label in ("LEFT KNEE", "RIGHT KNEE"):
            _offset(pose, label, -0.05 * k, 0.02 * k)
        for label in ("LEFT LEG", "RIGHT LEG"):
            _offset(pose, label, -0.12 * k, -0.06 * k)
        for label in ("LEFT ARM", "RIGHT ARM"):
            _offset(pose, label, 0.04 * k, 0.10 * k)

    else:
        sys.exit("Unknown pose action: %s (walk, bite, idle, death)" % action)

    return pose


def pose_to_points(pose, mirror=False):
    """{label: (x,y)} -> the API's list of Point dicts."""
    points = []
    for label, (x, y) in pose.items():
        if mirror:
            x = 1.0 - x
        points.append({
            "x": round(min(max(x, 0.0), 1.0), 5),
            "y": round(min(max(y, 0.0), 1.0), 5),
            "label": label,
            "z_index": Z_INDEX.get(label, 0),
        })
    return points


def draw_preview(points, size, base=None, scale=6):
    """Render the skeleton over the sprite so a pose can be judged for free."""
    w, h = size
    img = Image.new("RGBA", (w * scale, h * scale), (24, 22, 30, 255))
    if base is not None:
        img.alpha_composite(base.resize((w * scale, h * scale), Image.NEAREST))

    at = {p["label"]: (p["x"] * w * scale, p["y"] * h * scale) for p in points}
    d = ImageDraw.Draw(img)
    for a, b in SKELETON_BONES:
        if a in at and b in at:
            d.line([at[a], at[b]], fill=(255, 90, 90, 255), width=max(2, scale // 3))
    for label, (x, y) in at.items():
        r = max(3, scale // 2)
        colour = (255, 220, 60, 255) if label in ("NECK", "NOSE") else (90, 200, 255, 255)
        d.ellipse([x - r, y - r, x + r, y + r], fill=colour)
    return img


def palette_image(hex_path):
    """Build a 1-pixel-per-colour swatch from the master palette.

    /animate-with-skeleton accepts `color_image` as a forced palette. Passing
    Cravera's master palette here keeps the generator on-palette from the start
    instead of relying only on the post-hoc quantize gate — the skeleton walk
    test drifted noticeably teal without it.
    """
    with open(hex_path, encoding="utf-8") as fh:
        colours = [c.strip() for c in fh if c.strip()]
    img = Image.new("RGB", (len(colours), 1))
    img.putdata([tuple(int(c[i:i + 2], 16) for i in (0, 2, 4)) for c in colours])
    return img


def _b64(img):
    buf = io.BytesIO()
    img.save(buf, "PNG")
    return base64.b64encode(buf.getvalue()).decode()


def _post(endpoint, payload, token):
    req = urllib.request.Request(
        "%s/%s" % (API, endpoint),
        data=json.dumps(payload).encode(),
        headers={"Authorization": "Bearer %s" % token,
                 "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode()[:600]
        if e.code == 402:
            sys.exit("HTTP 402 — out of generations/credits. Check `get_balance`.")
        sys.exit("HTTP %d from /%s:\n%s" % (e.code, endpoint, body))


def load_reference(path, cell, index=0):
    """Load the reference sprite, cropping cell `index` out of a sheet.

    The reference should FACE THE SAME WAY as the pose being generated — the
    east-facing poses here want the sheet's east cell, not its first cell.
    Column order comes from the PixelLab export's layout JSON (commonly
    south, west, east, north — check, do not assume).
    """
    img = Image.open(path).convert("RGBA")
    if cell and img.width > cell:
        img = img.crop((index * cell, 0, (index + 1) * cell, cell))
    return fit_canvas(img)


# /animate-with-skeleton only accepts these canvases.
ALLOWED_CANVASES = (16, 32, 64, 128, 256)


def fit_canvas(img):
    """Re-centre the sprite on the smallest allowed canvas that fits its art.

    PixelLab rejects anything but 16/32/64/128/256 square, but a character
    export is padded to its own size (68x68 for a `size=48` request). Rescaling
    to fit would resample the art and break the project's one-pixel-per-pixel
    rule, so instead the opaque content is cropped out and re-centred on the
    next allowed canvas up. Pixels are moved, never resampled.
    """
    if img.width == img.height and img.width in ALLOWED_CANVASES:
        return img

    box = img.getbbox() or (0, 0, img.width, img.height)
    content = img.crop(box)
    need = max(content.width, content.height)
    target = next((c for c in ALLOWED_CANVASES if c >= need), ALLOWED_CANVASES[-1])
    if need > target:
        sys.exit("Sprite art is %dpx — larger than the 256px maximum canvas." % need)

    canvas = Image.new("RGBA", (target, target), (0, 0, 0, 0))
    canvas.alpha_composite(
        content, ((target - content.width) // 2, (target - content.height) // 2)
    )
    return canvas


def cmd_estimate(args):
    img = load_reference(args.image, args.cell, args.cell_index)
    out = _post("estimate-skeleton", {"image": {"type": "base64", "base64": _b64(img)}}, args.token)
    points = out if isinstance(out, list) else (out.get("keypoints") or out.get("points"))
    if args.out:
        with open(args.out, "w", encoding="utf-8") as fh:
            json.dump(points, fh, indent=1)
        print("Wrote %s (%d keypoints)" % (args.out, len(points)))
    for p in points:
        print("  %-16s x=%.3f y=%.3f z=%s" % (p["label"], p["x"], p["y"], p.get("z_index")))
    if isinstance(out, dict) and out.get("usage"):
        print("usage:", out["usage"])


def cmd_preview(args):
    # A fitted skeleton (from `estimate`) is drawn as-is; otherwise the
    # synthetic theropod pose is sampled across the cycle.
    if args.keypoints:
        with open(args.keypoints, encoding="utf-8") as fh:
            fitted = json.load(fh)
        base = Image.open(args.reference).convert("RGBA") if args.reference else None
        size = base.size if base else (args.size, args.size)
        draw_preview(fitted, size, base).save(args.out)
        print("Wrote %s — fitted skeleton, %d keypoints" % (args.out, len(fitted)))
        return

    base = load_reference(args.reference, args.cell, args.cell_index) if args.reference else None
    size = base.size if base else (args.size, args.size)
    frames = []
    for i in range(args.frames):
        phase = i / float(args.frames)
        points = pose_to_points(theropod_pose(args.pose, phase), args.mirror)
        frames.append(draw_preview(points, size, base))
    strip = Image.new("RGBA", (sum(f.width for f in frames), frames[0].height))
    x = 0
    for f in frames:
        strip.paste(f, (x, 0))
        x += f.width
    strip.save(args.out)
    print("Wrote %s — %d frame(s) of '%s'" % (args.out, args.frames, args.pose))


def cmd_animate(args):
    ref = load_reference(args.reference, args.cell, args.cell_index)
    # The endpoint is a strict 3-frame window.
    window = [pose_to_points(theropod_pose(args.pose, p), args.mirror)
              for p in (args.phase, args.phase + args.step, args.phase + 2 * args.step)]
    payload = {
        "image_size": {"width": ref.width, "height": ref.height},
        "reference_image": {"type": "base64", "base64": _b64(ref)},
        "skeleton_keypoints": window,
        "view": args.view,
        "direction": args.direction,
        "guidance_scale": args.guidance,
    }
    if args.palette:
        payload["color_image"] = {"type": "base64", "base64": _b64(palette_image(args.palette))}
    if args.seed is not None:
        payload["seed"] = args.seed

    print("Generating 3 frames of '%s' (%s, %s)..." % (args.pose, args.direction, args.view))
    out = _post("animate-with-skeleton", payload, args.token)
    os.makedirs(args.out_dir, exist_ok=True)
    for i, im in enumerate(out["images"]):
        raw = im["base64"].split(",", 1)[-1]
        path = os.path.join(args.out_dir, "%s_%02d.png" % (args.pose, i))
        with open(path, "wb") as fh:
            fh.write(base64.b64decode(raw))
        print("  wrote", path)
    print("usage:", out.get("usage"))


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--token", default=os.environ.get("PIXELLAB_API_KEY"))
    sub = ap.add_subparsers(dest="cmd", required=True)

    common_ref = dict(help="Reference sprite PNG (a sheet is cropped to its first cell)")

    e = sub.add_parser("estimate", help="Fit the rig to an existing sprite (0.1 generations)")
    e.add_argument("image", **common_ref)
    e.add_argument("--cell", type=int, default=None, help="Cell size if the PNG is a sheet")
    e.add_argument("--cell-index", type=int, default=0, help="Which cell of the sheet to use")
    e.add_argument("--out", default=None, help="Write keypoints JSON here")
    e.set_defaults(func=cmd_estimate)

    p = sub.add_parser("preview", help="Draw a pose over the sprite — free, no API call")
    p.add_argument("--pose", default="walk", choices=["walk", "bite", "idle", "death"])
    p.add_argument("--frames", type=int, default=4)
    p.add_argument("--reference", default=None, **common_ref)
    p.add_argument("--cell", type=int, default=None)
    p.add_argument("--cell-index", type=int, default=0, help="Which cell of the sheet to use")
    p.add_argument("--size", type=int, default=64, help="Canvas size when there is no reference")
    p.add_argument("--mirror", action="store_true", help="Face west instead of east")
    p.add_argument("--keypoints", default=None,
                   help="Draw a fitted skeleton JSON (from `estimate`) instead of a synthetic pose")
    p.add_argument("--out", default="pose_preview.png")
    p.set_defaults(func=cmd_preview)

    a = sub.add_parser("animate", help="Generate 3 animation frames from the rig")
    a.add_argument("--reference", required=True, **common_ref)
    a.add_argument("--cell", type=int, default=None)
    a.add_argument("--cell-index", type=int, default=0,
                   help="Which cell of the sheet to use — must face the same way as --direction")
    a.add_argument("--pose", default="walk", choices=["walk", "bite", "idle", "death"])
    a.add_argument("--phase", type=float, default=0.0, help="Cycle start position 0..1")
    a.add_argument("--step", type=float, default=0.125, help="Phase advance per frame")
    a.add_argument("--direction", default="east",
                   choices=["north", "north-east", "east", "south-east",
                            "south", "south-west", "west", "north-west"])
    a.add_argument("--view", default="side", choices=["side", "low top-down", "high top-down"])
    a.add_argument("--guidance", type=float, default=4.0, help="1-20, how strictly to follow the pose")
    a.add_argument("--mirror", action="store_true")
    a.add_argument("--palette", default=os.path.join("art", "palettes", "cravera_master.hex"),
                   help="Force this palette during generation (pass '' to disable)")
    a.add_argument("--seed", type=int, default=None)
    a.add_argument("--out-dir", default="out")
    a.set_defaults(func=cmd_animate)

    args = ap.parse_args()
    if args.cmd in ("estimate", "animate") and not args.token:
        sys.exit("Set PIXELLAB_API_KEY or pass --token.")
    args.func(args)


if __name__ == "__main__":
    main()
