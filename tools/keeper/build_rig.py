"""Write game/Forest/keeper/art/rig.json: rest skeleton, metrics, ramps, part metadata.

Rest joints are measured from the PixelLab base rotations (source + CEL_OFFSET)
and made symmetric about the hero's centre line x=32.0 so that mirrored
left-facing cels line up with right-facing ones.
"""
import json
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from keeper_palette import MATERIALS, lum, parse_hex  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ART = os.path.join(ROOT, "game", "Forest", "keeper", "art")

REST = {
    # main hand = screen-right in down/up views, near side in the side view.
    "down": {
        "neck": [32.0, 29.0], "belt": [36.5, 37.0],
        "shoulder_m": [36.8, 30.6], "shoulder_o": [27.2, 30.6],
        "hand_m": [39.3, 35.4], "hand_o": [24.7, 35.4],
        "hip_m": [35.0, 37.6], "hip_o": [29.0, 37.6],
        "foot_m": [35.0, 41.0], "foot_o": [29.0, 41.0],
    },
    "up": {
        "neck": [32.0, 28.4], "belt": [27.5, 37.0],
        "shoulder_m": [37.0, 30.4], "shoulder_o": [27.0, 30.4],
        "hand_m": [39.6, 35.2], "hand_o": [24.4, 35.2],
        "hip_m": [35.0, 37.6], "hip_o": [29.0, 37.6],
        "foot_m": [35.0, 41.0], "foot_o": [29.0, 41.0],
    },
    "side": {
        "neck": [32.0, 29.0], "belt": [33.5, 37.0],
        "shoulder_m": [30.2, 30.8], "shoulder_o": [33.4, 30.6],
        "hand_m": [30.4, 36.3], "hand_o": [33.8, 36.0],
        "hip_m": [31.2, 37.6], "hip_o": [32.8, 37.6],
        "foot_m": [31.2, 41.0], "foot_o": [32.8, 41.0],
    },
}

METRICS = {
    "arm_upper": 2.8, "arm_lower": 2.8, "arm_radius": 1.0,
    "leg_upper": 1.7, "leg_lower": 1.7, "leg_radius": 1.45,
    "hand_radius": 1.0,
}

# [deep, dark, mid, light, highlight]
RAMPS = {
    "skin": ["a55c2d", "eca052", "f9bc6d", "fec480", "ffce83"],
    "trousers": ["2e1a0f", "422811", "503618", "624016", "774f24"],
    "leather": ["2e1a0f", "422811", "5a3919", "774f24", "946432"],
}
OUTLINE = "220907"

APPEARANCE_RAMPS = {
    "skin_warm": RAMPS["skin"],
    "skin_sand": ["8a5a3c", "cf9c6c", "e8b989", "f5d0a4", "fde6c8"],
    "skin_umber": ["3d2014", "6a3c26", "8c583e", "a8714c", "c08a62"],
    "skin_rose": ["7a4038", "b87466", "cd9b87", "e2b8a5", "f2d3c4"],
    "hair_chestnut": ["2e140c", "52261a", "74382a", "8d5135", "b0714a"],
    "hair_charcoal": ["141418", "25262c", "35373f", "4a4d57", "676b76"],
    "hair_silver": ["4f5a57", "748480", "98a8a3", "b8c5be", "dde7e2"],
    "cloth_ochre": ["4a3314", "7a5623", "a07232", "bd9248", "d9b56a"],
    "cloth_river": ["1b3338", "2c5058", "427078", "558f98", "7bb3b8"],
    "cloth_clay": ["4a2219", "74382a", "985040", "b8684f", "d48c70"],
    "trousers_earth": RAMPS["trousers"],
    "trousers_slate": ["1c222b", "2e3845", "404d5d", "57697b", "73889b"],
    "trousers_olive": ["22271a", "363f28", "4b5637", "65704c", "838f68"],
}

# Boots: '#' outline, d/m/l leather shades. Pivot = ankle point (continuous).
BOOTS = {
    "down": (["#mlm#", "#dmd#", "#####"], [2.5, 0.0]),
    "up": (["#mdm#", "#dmd#", "#####"], [2.5, 0.0]),
    "side": (["#ml#.", "#dmml#", "######"], [2.0, 0.0]),
}


def write_boot(view, rows, pivot, ramp, outline, folder):
    w = max(len(r) for r in rows)
    img = Image.new("RGBA", (w, len(rows)))
    mat = Image.new("RGBA", (w, len(rows)))
    shades = {"d": 1, "m": 2, "l": 3}
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "#":
                img.putpixel((x, y), parse_hex(outline) + (255,))
                mat.putpixel((x, y), (MATERIALS["outline"], 0, 1, 255))
            elif ch in shades:
                img.putpixel((x, y), parse_hex(ramp[shades[ch]]) + (255,))
                mat.putpixel((x, y), (MATERIALS["leather"], shades[ch], 5, 255))
    os.makedirs(folder, exist_ok=True)
    img.save(os.path.join(folder, f"boot_{view}.png"))
    mat.save(os.path.join(folder, f"boot_{view}.mat.png"))
    return {"pivot": pivot, "origin": [0, 0]}


def main():
    base_meta = json.load(open(os.path.join(ART, "base", "set.json")))
    parts = {f"base/{k}": v for k, v in base_meta["parts"].items()}
    # Armour sets register their own part metadata in sets/<id>/set.json.
    sets = {}
    sets_dir = os.path.join(ART, "sets")
    if os.path.isdir(sets_dir):
        for sid in sorted(os.listdir(sets_dir)):
            meta_path = os.path.join(sets_dir, sid, "set.json")
            if os.path.exists(meta_path):
                meta = json.load(open(meta_path))
                sets[sid] = meta.get("materials", {})
                for key, val in meta.get("parts", {}).items():
                    parts[f"sets/{sid}/{key}"] = val
    hair = {}
    hair_dir = os.path.join(ART, "hair")
    if os.path.isdir(hair_dir):
        meta_path = os.path.join(hair_dir, "hair.json")
        if os.path.exists(meta_path):
            meta = json.load(open(meta_path))
            hair = meta.get("styles", {})
            for key, val in meta.get("parts", {}).items():
                parts[f"hair/{key}"] = val
    rig = {
        "version": 2,
        "rest": REST,
        "metrics": METRICS,
        "ramps": RAMPS,
        "outline": OUTLINE,
        "appearance_ramps": APPEARANCE_RAMPS,
        "parts": parts,
        "sets": sets,
        "hair_styles": hair,
    }
    with open(os.path.join(ART, "rig.json"), "w") as f:
        json.dump(rig, f, indent=1)
    print("rig.json written:", len(parts), "parts,", len(sets), "sets")


if __name__ == "__main__":
    main()
