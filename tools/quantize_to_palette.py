#!/usr/bin/env python3
"""quantize_to_palette.py — Cravera's "quantize gate".

Cravera mixes art from three sources: AI-generated sprites, purchased/CC0
asset packs, and hand-drawn pixel art. Left alone they each carry their own
colors and the game looks like a collage. The fix is a single MASTER PALETTE
(art/palettes/cravera_master.hex) plus this QUANTIZE GATE: every incoming PNG
is snapped to the master palette BEFORE it enters the project. After the gate,
AI output, pack art, and hand art all draw from the exact same colors, so the
whole game reads as one cohesive piece.

This is the same operation as Aseprite's "Color Mode -> Indexed (map to nearest
palette color)", scriptable so it can run on a folder of assets or in CI.

Color matching uses NEAREST color by Euclidean distance in sRGB space. A
perceptually accurate match would convert to linear-light RGB (or CIE Lab)
first; for a small hand-tuned pixel-art palette plain sRGB distance is more
than good enough and keeps the script dependency-light. Only Pillow is needed.

By default sprites are kept crisp: pixels below the alpha threshold become fully
transparent and everything else becomes a fully-opaque palette color (no soft
anti-aliased edges that would shimmer when pixel-snapped). Use --keep-alpha to
preserve the original per-pixel alpha instead.

Example
-------
    # snap one AI sprite into the project, writing to game/Sprites/
    python tools/quantize_to_palette.py raw/trex_ai.png --out-dir game/Sprites

    # snap a whole folder in place using a custom palette
    python tools/quantize_to_palette.py "packs/*.png" --in-place \\
        --palette art/palettes/cravera_master.hex
"""

import argparse
import glob
import os
import sys

try:
    from PIL import Image
except ImportError:
    sys.exit(
        "This script requires Pillow. Install it with:  pip install Pillow"
    )


DEFAULT_PALETTE = os.path.join("art", "palettes", "cravera_master.hex")


def load_palette(path):
    """Load a Lospec .hex palette (one RRGGBB per line) into a list of RGB
    tuples. Blank lines, comments (#...), and leading '#' on colors are
    tolerated."""
    if not os.path.isfile(path):
        raise FileNotFoundError("Palette not found: %s" % path)
    colors = []
    with open(path, "r", encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()
            if not line:
                continue
            if line.startswith("#") and len(line.lstrip("#").strip()) != 6:
                # a real comment line, not a '#RRGGBB' color
                continue
            hexcode = line.lstrip("#").strip()
            if len(hexcode) != 6:
                continue
            try:
                r = int(hexcode[0:2], 16)
                g = int(hexcode[2:4], 16)
                b = int(hexcode[4:6], 16)
            except ValueError:
                continue
            colors.append((r, g, b))
    if not colors:
        raise ValueError("No colors parsed from palette: %s" % path)
    return colors


def build_nearest_cache(palette):
    """Return a function mapping an (r,g,b) tuple to the nearest palette color.
    Results are memoized because real sprites reuse the same few colors a lot,
    so the O(palette) search runs once per distinct source color."""
    cache = {}

    def nearest(rgb):
        hit = cache.get(rgb)
        if hit is not None:
            return hit
        r, g, b = rgb
        best = palette[0]
        best_d = None
        for pr, pg, pb in palette:
            # squared Euclidean distance in sRGB; sqrt is monotonic so skip it
            d = (r - pr) ** 2 + (g - pg) ** 2 + (b - pb) ** 2
            if best_d is None or d < best_d:
                best_d = d
                best = (pr, pg, pb)
        cache[rgb] = best
        return best

    return nearest


def add_outline(img, colour=(0, 0, 0, 255), expand=True):
    """Wrap the sprite silhouette in a 1px outline.

    Cravera's style rules call for a thick dark outline on every sprite so it
    separates from the ground at 480x270 (see visual-pixel-art.md section 1).
    AI generators routinely omit it, which is what makes raw output read as
    mushy against the terrain.

    Any transparent pixel orthogonally touching an opaque one becomes outline.
    With `expand` the canvas grows 1px on each side first, so an outline can be
    drawn around art that already touches the edge instead of being clipped.
    """
    img = img.convert("RGBA")
    if expand:
        grown = Image.new("RGBA", (img.width + 2, img.height + 2), (0, 0, 0, 0))
        grown.paste(img, (1, 1))
        img = grown

    px = img.load()
    w, h = img.size
    edges = []
    for y in range(h):
        for x in range(w):
            if px[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and px[nx, ny][3] != 0:
                    edges.append((x, y))
                    break
    for x, y in edges:
        px[x, y] = colour
    return img


def quantize_image(img, palette, alpha_threshold, keep_alpha, dither):
    """Return a new RGBA image with every pixel snapped to the palette.

    Transparency: pixels with alpha < alpha_threshold become fully transparent;
    others become opaque palette colors (crisp sprite mode). With keep_alpha the
    original alpha channel is preserved instead.
    """
    img = img.convert("RGBA")
    nearest = build_nearest_cache(palette)

    if dither:
        # Optional ordered/Floyd-Steinberg dithering via Pillow's quantizer.
        # Build a 'P' mode palette image and let Pillow do FS dithering, then
        # restore alpha ourselves (Pillow drops it during quantization).
        flat = []
        for c in palette:
            flat.extend(c)
        flat += [0, 0, 0] * (256 - len(palette))
        pal_img = Image.new("P", (1, 1))
        pal_img.putpalette(flat)
        rgb = img.convert("RGB")
        dithered = rgb.quantize(
            palette=pal_img, dither=Image.Dither.FLOYDSTEINBERG
        ).convert("RGB")
        src = dithered.load()
        alpha = img.getchannel("A").load()
        out = Image.new("RGBA", img.size)
        op = out.load()
        w, h = img.size
        for y in range(h):
            for x in range(w):
                a = alpha[x, y]
                if not keep_alpha:
                    a = 0 if a < alpha_threshold else 255
                if a == 0:
                    op[x, y] = (0, 0, 0, 0)
                else:
                    r, g, b = src[x, y]
                    op[x, y] = (r, g, b, a)
        return out

    # Default: nearest-neighbor only, no resampling, no dithering.
    src = img.load()
    out = Image.new("RGBA", img.size)
    op = out.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = src[x, y]
            if not keep_alpha:
                a = 0 if a < alpha_threshold else 255
            if a == 0:
                op[x, y] = (0, 0, 0, 0)
            else:
                nr, ng, nb = nearest((r, g, b))
                op[x, y] = (nr, ng, nb, a)
    return out


def count_unique_colors(img):
    """Count distinct visible (alpha>0) RGB colors in an RGBA image."""
    rgba = img.convert("RGBA")
    seen = set()
    src = rgba.load()
    w, h = rgba.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = src[x, y]
            if a > 0:
                seen.add((r, g, b))
    return len(seen)


def resolve_inputs(patterns):
    """Expand input args (literal paths and/or globs) into existing PNG paths."""
    paths = []
    seen = set()
    for pat in patterns:
        matches = glob.glob(pat)
        if not matches and os.path.isfile(pat):
            matches = [pat]
        if not matches:
            print("  (warning) no files match: %s" % pat, file=sys.stderr)
            continue
        for m in matches:
            ap = os.path.abspath(m)
            if ap not in seen and m.lower().endswith(".png"):
                seen.add(ap)
                paths.append(m)
            elif not m.lower().endswith(".png"):
                print("  (skip non-PNG) %s" % m, file=sys.stderr)
    return paths


def output_path_for(in_path, out_dir, in_place):
    if in_place:
        return in_path
    base = os.path.basename(in_path)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
        return os.path.join(out_dir, base)
    root, ext = os.path.splitext(in_path)
    return root + "_q" + ext


def main():
    parser = argparse.ArgumentParser(
        prog="quantize_to_palette.py",
        description=(
            "Cravera quantize gate: snap PNGs to the master palette so AI, "
            "asset-pack, and hand-drawn art all share the same colors. Run "
            "this on EVERY asset before it enters the project."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=(
            "examples:\n"
            "  python tools/quantize_to_palette.py raw/sprite.png "
            "--out-dir game/Sprites\n"
            "  python tools/quantize_to_palette.py \"packs/*.png\" --in-place\n"
        ),
    )
    parser.add_argument(
        "inputs", nargs="+",
        help="one or more PNG paths and/or globs (e.g. 'art/*.png')",
    )
    parser.add_argument(
        "--palette", default=DEFAULT_PALETTE,
        help="path to the .hex master palette (default: %(default)s)",
    )
    parser.add_argument(
        "--out-dir", default=None,
        help="write outputs into this directory (default: alongside input "
             "with a _q suffix)",
    )
    parser.add_argument(
        "--in-place", action="store_true",
        help="overwrite each input file in place (ignores --out-dir)",
    )
    parser.add_argument(
        "--alpha-threshold", type=int, default=128, metavar="N",
        help="pixels with alpha < N become fully transparent, the rest fully "
             "opaque (default: %(default)s; ignored with --keep-alpha)",
    )
    parser.add_argument(
        "--keep-alpha", action="store_true",
        help="preserve the original per-pixel alpha instead of hard "
             "transparent/opaque",
    )
    parser.add_argument(
        "--outline", action="store_true",
        help="wrap the silhouette in a 1px dark outline before quantizing "
             "(Cravera style requires one; AI output usually lacks it)",
    )
    parser.add_argument(
        "--outline-color", default=None, metavar="HEX",
        help="outline color as RRGGBB (default: the darkest palette color)",
    )
    parser.add_argument(
        "--dither", action="store_true",
        help="apply Floyd-Steinberg dithering (default is nearest-neighbor "
             "only, recommended for crisp pixel art)",
    )
    args = parser.parse_args()

    if args.alpha_threshold < 0 or args.alpha_threshold > 255:
        parser.error("--alpha-threshold must be between 0 and 255")

    # Load palette (robust to missing file).
    try:
        palette = load_palette(args.palette)
    except (FileNotFoundError, ValueError) as exc:
        sys.exit("Palette error: %s" % exc)

    inputs = resolve_inputs(args.inputs)
    if not inputs:
        sys.exit("No PNG inputs found. Nothing to do.")

    print("Cravera quantize gate")
    print("  palette : %s (%d colors)" % (args.palette, len(palette)))
    print("  mode    : %s%s" % (
        "dither" if args.dither else "nearest",
        ", keep-alpha" if args.keep_alpha else "",
    ))

    processed = 0
    total_before = 0
    total_after = 0
    for in_path in inputs:
        try:
            img = Image.open(in_path)
        except (OSError, ValueError) as exc:
            print("  (error) cannot open %s: %s" % (in_path, exc),
                  file=sys.stderr)
            continue

        before = count_unique_colors(img)
        if args.outline:
            if args.outline_color:
                oc = tuple(int(args.outline_color[i:i + 2], 16) for i in (0, 2, 4)) + (255,)
            else:
                # darkest palette entry, so the outline is already on-palette
                oc = min(palette, key=lambda c: sum(c[:3]))[:3] + (255,)
            img = add_outline(img, oc)
        result = quantize_image(
            img, palette, args.alpha_threshold, args.keep_alpha, args.dither
        )
        after = count_unique_colors(result)

        out_path = output_path_for(in_path, args.out_dir, args.in_place)
        try:
            result.save(out_path)
        except OSError as exc:
            print("  (error) cannot write %s: %s" % (out_path, exc),
                  file=sys.stderr)
            continue

        print("  %s -> %s  (%d -> %d colors)" % (
            in_path, out_path, before, after))
        processed += 1
        total_before += before
        total_after += after

    print("Done: %d file(s) quantized; %d unique colors in -> %d out." % (
        processed, total_before, total_after))


if __name__ == "__main__":
    main()
