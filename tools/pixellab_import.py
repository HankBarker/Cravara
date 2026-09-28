#!/usr/bin/env python3
"""pixellab_import.py — turn a PixelLab character export into Cravera game art.

PixelLab (https://www.pixellab.ai) generates multi-directional pixel-art
characters. Its `spritesheet` export is a zip holding one uniform-grid PNG plus
a layout JSON describing the grid (cell size, columns, and one row per
rotation-set / animation). This script is the bridge from that export to
something Godot can actually play:

    zip  ->  quantize gate  ->  game/Sprites/<Name>/  ->  SpriteFrames .tres

Three things happen on the way in:

1. QUANTIZE GATE. Every incoming pixel is snapped to Cravera's master palette
   (art/palettes/cravera_master.hex) by reusing quantize_to_palette.py. This is
   what stops AI output from looking like a different game than the hand-drawn
   and asset-pack art. See references/visual-pixel-art.md.

2. DIRECTION MAPPING. PixelLab names directions south/north/east/west (plus
   diagonals); Cravera's animation convention is walk_down/up/left/right. The
   column order is read from the layout JSON rather than assumed, because
   PixelLab does not emit a fixed order.

3. SPRITEFRAMES GENERATION. Each cell becomes an AtlasTexture region on the one
   sheet texture, grouped into `<animation>_<dir>` animations. Cells are
   pivot-centred by PixelLab ("pivot": "cell-center"), so every frame of every
   direction shares one anchor — the fix for the sprite-jitter/anchor-drift
   problem described in references/visual-pixel-art.md section 2.

The sheet is imported at its native resolution and never rescaled: PixelLab
art is already 1 art-pixel per texture-pixel, so resampling it would break the
project's single pixels-per-unit rule.

Examples
--------
    # straight from the MCP download URL (needs PIXELLAB_API_KEY for auth)
    python tools/pixellab_import.py \\
        https://api.pixellab.ai/mcp/characters/<id>/spritesheet --name Raptor

    # from an already-downloaded zip, renaming PixelLab animations to
    # Cravera's convention
    python tools/pixellab_import.py raptor.zip --name Raptor \\
        --map walking=walk --map lead-jab=bite
"""

import argparse
import json
import os
import re
import shutil
import sys
import tempfile
import urllib.request
import zipfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from PIL import Image
except ImportError:
    sys.exit("This script requires Pillow. Install it with:  pip install Pillow")

from quantize_to_palette import DEFAULT_PALETTE, load_palette, quantize_image


# PixelLab compass directions -> Cravera's 4-direction facing names. The
# diagonals collapse onto their dominant axis so an 8-direction PixelLab
# character still imports cleanly into a 4-direction game (the extra frames are
# simply aliases; pass --skip-diagonals to drop them instead).
DIRECTION_MAP = {
    "south": "down",
    "north": "up",
    "east": "right",
    "west": "left",
    "south-east": "down_right",
    "south-west": "down_left",
    "north-east": "up_right",
    "north-west": "up_left",
}

DIAGONALS = {"down_right", "down_left", "up_right", "up_left"}

# Animations that should not loop in Cravera. Everything else loops.
NON_LOOPING = {"death", "hurt", "attack", "bite"}

# Cravera plays these regardless of facing, so they are stored WITHOUT a
# direction suffix — creature scripts call `play("death")`, not "death_down".
# Generating them in one direction is enough.
NO_DIRECTION = {"death"}


def sanitize(name):
    """PixelLab animation names ('lead-jab', 'walking 4') -> gdscript-safe."""
    s = re.sub(r"[^a-zA-Z0-9]+", "_", name.strip().lower())
    return s.strip("_")


def fetch_zip(source, token, workdir):
    """Return a local path to the export zip, downloading it if needed."""
    if not source.startswith(("http://", "https://")):
        if not os.path.isfile(source):
            sys.exit("Not a file or URL: %s" % source)
        return source

    if not token:
        sys.exit(
            "Downloading from PixelLab needs an API token. Pass --token or set\n"
            "PIXELLAB_API_KEY in the environment. (The key also lives in your\n"
            "local Claude MCP config; it is deliberately not stored in this repo.)"
        )

    dest = os.path.join(workdir, "export.zip")
    req = urllib.request.Request(
        source, headers={"Authorization": "Bearer %s" % token}
    )
    print("Downloading %s" % source)
    with urllib.request.urlopen(req) as resp, open(dest, "wb") as fh:
        shutil.copyfileobj(resp, fh)
    return dest


def read_export(zip_path, workdir):
    """Unpack the export and return (layout_dict, sheet_image)."""
    extract_dir = os.path.join(workdir, "export")
    with zipfile.ZipFile(zip_path) as zf:
        zf.extractall(extract_dir)

    layouts = [f for f in os.listdir(extract_dir) if f.endswith(".json")]
    if not layouts:
        sys.exit("No layout JSON in the export zip — is this a PixelLab spritesheet export?")

    with open(os.path.join(extract_dir, layouts[0]), encoding="utf-8") as fh:
        layout = json.load(fh)

    sheet_name = layout["spritesheet"]["path"]
    sheet_path = os.path.join(extract_dir, sheet_name)
    if not os.path.isfile(sheet_path):
        sys.exit("Layout references %s but it is not in the zip." % sheet_name)

    return layout, Image.open(sheet_path).convert("RGBA")


def build_animations(layout, name_map, skip_diagonals):
    """Walk the layout rows into {animation_name: [(col, row), ...]}.

    A PixelLab row is either the character's static rotations (one cell per
    direction) or one animation in one or more directions (frame_count cells
    per direction, laid out left to right).
    """
    sheet = layout["spritesheet"]
    columns = sheet["columns"]
    animations = {}

    for row in sheet["rows"]:
        row_index = row["row"]
        # Rotation rows carry `directions` (plural, one cell each); animation
        # rows carry `direction` (singular) with the whole row being that one
        # direction's frames. Missing the singular form silently labels every
        # animation "south".
        directions = row.get("directions")
        if not directions:
            directions = [row["direction"]] if row.get("direction") else ["south"]
        row_type = row.get("type", "animation")

        if row_type == "rotations":
            base = "idle"
            frames_per_direction = 1
        else:
            raw = row.get("name") or row.get("animation") or "anim"
            base = sanitize(raw)
            # frame_count is the per-direction frame count.
            frames_per_direction = row.get("frame_count", 1) // max(len(directions), 1)
            frames_per_direction = max(frames_per_direction, 1)

        base = name_map.get(base, base)

        col = 0
        for direction in directions:
            facing = DIRECTION_MAP.get(direction, sanitize(direction))
            if skip_diagonals and facing in DIAGONALS:
                col += frames_per_direction
                continue

            cells = []
            for _ in range(frames_per_direction):
                # Rows wider than `columns` wrap onto following sheet rows.
                cells.append((row_index + col // columns, col % columns))
                col += 1

            anim_name = base if base in NO_DIRECTION else "%s_%s" % (base, facing)
            animations.setdefault(anim_name, []).extend(cells)

    return animations


def write_spriteframes(path, texture_res_path, animations, cell_w, cell_h, fps):
    """Emit a Godot 4 SpriteFrames .tres referencing AtlasTexture regions."""
    atlas_ids = {}
    atlas_blocks = []

    for anim_name in sorted(animations):
        for (row, col) in animations[anim_name]:
            if (row, col) in atlas_ids:
                continue
            atlas_id = "AtlasTexture_r%dc%d" % (row, col)
            atlas_ids[(row, col)] = atlas_id
            atlas_blocks.append(
                '[sub_resource type="AtlasTexture" id="%s"]\n'
                'atlas = ExtResource("1_sheet")\n'
                "region = Rect2(%d, %d, %d, %d)\n"
                % (atlas_id, col * cell_w, row * cell_h, cell_w, cell_h)
            )

    entries = []
    for anim_name in sorted(animations):
        frames = "".join(
            '{\n"duration": 1.0,\n"texture": SubResource("%s")\n}, '
            % atlas_ids[cell]
            for cell in animations[anim_name]
        ).rstrip(", ")
        base = anim_name.rsplit("_", 1)[0]
        loop = "false" if base in NON_LOOPING else "true"
        entries.append(
            '{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}'
            % (frames, loop, anim_name, fps)
        )

    # load_steps = 1 (resource) + 1 (ext_resource) + one per AtlasTexture
    load_steps = 2 + len(atlas_blocks)
    body = (
        '[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n'
        '[ext_resource type="Texture2D" path="%s" id="1_sheet"]\n\n'
        "%s\n[resource]\nanimations = [%s]\n"
        % (
            load_steps,
            texture_res_path,
            "\n".join(atlas_blocks),
            ", ".join(entries),
        )
    )

    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(body)


# GDScript run headlessly to prove Godot can actually parse the generated
# resource. Written into the project temporarily because `res://` is rooted at
# game/, then removed.
VERIFY_SCRIPT = """extends SceneTree

func _initialize() -> void:
\tvar sf := load("%s") as SpriteFrames
\tif sf == null:
\t\tpush_error("VERIFY FAILED: SpriteFrames did not load")
\t\tquit(1)
\t\treturn
\tvar names := sf.get_animation_names()
\tprint("VERIFY OK animations=", names.size())
\tfor n in names:
\t\tvar tex := sf.get_frame_texture(n, 0)
\t\tprint("  ", n, " frames=", sf.get_frame_count(n),
\t\t\t" loop=", sf.get_animation_loop(n),
\t\t\t" size=", (tex.get_size() if tex else Vector2.ZERO))
\tquit(0)
"""


def find_godot(explicit):
    """Locate the Godot binary: --godot, $GODOT, or PATH."""
    if explicit:
        return explicit
    if os.environ.get("GODOT"):
        return os.environ["GODOT"]
    return shutil.which("godot") or shutil.which("Godot")


def verify_in_godot(godot, tres_res_path, project_dir="game"):
    """Import the new texture, then confirm Godot parses the SpriteFrames.

    The import pass is not optional: a freshly written PNG has no `.import`
    file, and until Godot generates one the `.tres` fails to resolve its
    ext_resource with "No loader found for resource".
    """
    import subprocess

    print("\nVerifying in Godot (%s)" % godot)
    subprocess.run(
        [godot, "--headless", "--path", project_dir, "--import"],
        capture_output=True, text=True, timeout=600,
    )

    check_path = os.path.join(project_dir, "_pixellab_verify.gd")
    with open(check_path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(VERIFY_SCRIPT % tres_res_path)
    try:
        proc = subprocess.run(
            [godot, "--headless", "--path", project_dir,
             "--script", "res://_pixellab_verify.gd"],
            capture_output=True, text=True, timeout=600,
        )
    finally:
        os.remove(check_path)

    out = proc.stdout + proc.stderr
    # Print only our own verify output and genuine resource errors; the project's
    # autoloads emit unrelated warnings and backtraces on every headless run.
    for line in out.splitlines():
        stripped = line.strip()
        if (stripped.startswith("VERIFY")
                or " frames=" in stripped
                or "Parse Error" in stripped):
            print("  " + stripped)
    return "VERIFY OK" in out


def main():
    ap = argparse.ArgumentParser(
        description="Import a PixelLab character export into Cravera as a Godot SpriteFrames resource."
    )
    ap.add_argument("source", help="PixelLab spritesheet export: a .zip path or an https URL")
    ap.add_argument("--name", required=True, help="Creature name, e.g. Raptor (PascalCase)")
    ap.add_argument(
        "--out-dir",
        default=os.path.join("game", "Sprites"),
        help="Parent sprite directory (default game/Sprites); a <Name>/ folder is created inside",
    )
    ap.add_argument("--palette", default=DEFAULT_PALETTE, help="Master palette .hex")
    ap.add_argument("--fps", type=float, default=8.0, help="SpriteFrames playback speed (default 8)")
    ap.add_argument(
        "--map",
        action="append",
        default=[],
        metavar="FROM=TO",
        help="Rename a PixelLab animation, e.g. --map walking=walk --map lead-jab=bite",
    )
    ap.add_argument(
        "--skip-diagonals",
        action="store_true",
        help="Drop the 4 diagonal directions of an 8-direction character (Cravera is 4-dir)",
    )
    ap.add_argument("--no-quantize", action="store_true", help="Skip the master-palette gate (not recommended)")
    ap.add_argument("--alpha-threshold", type=int, default=128, help="Alpha cutoff for crisp edges (default 128)")
    ap.add_argument("--token", default=os.environ.get("PIXELLAB_API_KEY"), help="PixelLab API token for URL downloads")
    ap.add_argument(
        "--godot",
        default=None,
        metavar="PATH",
        help="Godot binary; also read from $GODOT or PATH. When found, the new texture is "
             "imported and the generated SpriteFrames is load-tested headlessly.",
    )
    ap.add_argument("--no-verify", action="store_true", help="Skip the Godot import + load check")
    args = ap.parse_args()

    name_map = {}
    for pair in args.map:
        if "=" not in pair:
            sys.exit("--map expects FROM=TO, got %r" % pair)
        old, new = pair.split("=", 1)
        name_map[sanitize(old)] = sanitize(new)

    workdir = tempfile.mkdtemp(prefix="pixellab_")
    try:
        zip_path = fetch_zip(args.source, args.token, workdir)
        layout, sheet = read_export(zip_path, workdir)

        before = len(sheet.getcolors(maxcolors=1 << 24) or [])
        if not args.no_quantize:
            palette = load_palette(args.palette)
            sheet = quantize_image(
                sheet, palette, args.alpha_threshold, keep_alpha=False, dither=False
            )
        after = len(sheet.getcolors(maxcolors=1 << 24) or [])

        target_dir = os.path.join(args.out_dir, args.name)
        os.makedirs(target_dir, exist_ok=True)

        sheet_file = "%s_sheet.png" % args.name.lower()
        sheet.save(os.path.join(target_dir, sheet_file))

        cell = layout["spritesheet"]["cell_size"]
        animations = build_animations(layout, name_map, args.skip_diagonals)
        if not animations:
            sys.exit("No animations built from the layout — nothing to import.")

        # game/Sprites/Raptor/x.png -> res://Sprites/Raptor/x.png
        rel = os.path.relpath(os.path.join(target_dir, sheet_file), "game")
        res_path = "res://" + rel.replace(os.sep, "/")

        tres_path = os.path.join(target_dir, "%s_frames.tres" % args.name.lower())
        write_spriteframes(
            tres_path, res_path, animations, cell["width"], cell["height"], args.fps
        )

        print("Imported %s" % args.name)
        print("  sheet      %s  (%dx%d, %d cells of %dx%d)" % (
            os.path.join(target_dir, sheet_file),
            sheet.width, sheet.height,
            layout["spritesheet"]["columns"], cell["width"], cell["height"],
        ))
        print("  colors     %d -> %d%s" % (
            before, after, "" if args.no_quantize else " (snapped to master palette)"))
        print("  frames     %s" % tres_path)
        print("  animations %s" % ", ".join(
            "%s(%d)" % (k, len(v)) for k, v in sorted(animations.items())))
        tres_res = "res://" + os.path.relpath(tres_path, "game").replace(os.sep, "/")

        godot = None if args.no_verify else find_godot(args.godot)
        if godot:
            if not verify_in_godot(godot, tres_res):
                sys.exit("\nGodot could not load the generated SpriteFrames — see errors above.")
        else:
            print()
            print("  NOTE: Godot not found, so the resource was not load-tested.")
            print("  A new PNG has no .import file until Godot imports it, and the .tres")
            print("  will not resolve until then. Run:")
            print("      <godot> --headless --path game --import")
            print("  (or pass --godot PATH / set $GODOT to have this script do it).")

        print()
        print("Next: set the creature's AnimatedSprite2D sprite_frames to")
        print("      %s" % tres_res)
    finally:
        shutil.rmtree(workdir, ignore_errors=True)


if __name__ == "__main__":
    main()
