"""Pass 17: the blasting bomb's icon (the cave miner teaches the recipe).

    python tools/items/make_bomb_icon.py [--force]

PixelLab pixflux, 1 generation, 32 x 32, side view, the items' single black
outline (as tools/items/foods.py draws the food icons). Writes
game/Forest/art/items/bomb.png.
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, HERE)
import foods  # noqa: E402  (its _pixflux and palette)

OUT = os.path.join(ROOT, "game", "Forest", "art", "items", "bomb.png")
PROMPT = ("a round black-powder bomb: a dark iron-grey ball bound with leather straps, glowing blue Sky-Fang crystal "
          "shards set in it, a short fuse on top with a small spark, game item icon")


def main():
    if os.path.exists(OUT) and "--force" not in sys.argv:
        print("have", os.path.relpath(OUT, ROOT))
        return
    call = {"description": PROMPT, "width": 32, "height": 32, "no_background": True, "view": "side",
            "outline": "single color black outline", "shading": "medium shading", "detail": "highly detailed",
            "color_image_base64": "@" + foods.palette()}
    foods._pixflux(call, OUT)


if __name__ == "__main__":
    main()
