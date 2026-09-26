"""Pass 15: take the baked-in ground off the tribe camps' props.

    python tools/world/unbase_props.py [--preview OUT.png]

The Sunward tent, the Sunward stall and the Ashen totem were drawn standing on
a flat sandy oval, and the Ashen tent's poles splay out past its fabric at
the bottom. On the dunes that passed; on grass or in the bog the oval read as
a pasted-on platform ("the bottom of it just kind of sticks out weird").
This clears the oval (and the stray pole ends) so each prop stands straight on
whatever ground it is on; ForestProp draws a ground contact (a soft shadow and
a few tufts of the ground's own growth) where it meets the earth.

Rules per sprite, from their brightness maps (rows counted from the top):
  sunward_tent   rows > 42 cleared; rows 35-42 cleared outside the outer wall
                 outline (the darkest pixels)
  ashen_tent     the pole ends outside the fabric cleared: left of x 9 from
                 row 38 down, right of x 45 from row 44 down, and the ends
                 below the fabric (x 40 on, row 48 down)
  sunward_stall  rows >= 34 keep only the dark legs; rows 31-33 cleared left
                 of the table's left leg
  ashen_totem    rows >= 45 keep only the dark base of the pole
  folk_camp      (the villagers' camp) its olive grass-and-dirt oval cleared by
                 colour; the tent, its sandy doorway, stones and basket stay
  tent           (the keeper's camp tent) the pole feet splayed past the fabric
The first run backs the sprites up to art/tribes-props-before/.
"""
import os
import shutil
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
ART = os.path.join(ROOT, "game", "Forest", "tribes", "art", "props")
BACKUP = os.path.join(ROOT, "art", "tribes-props-before")


def value(c):
    return max(c[0], c[1], c[2]) / 255.0


def clear(px, x, y):
    px[x, y] = (0, 0, 0, 0)


def sunward_tent(im):
    px = im.load()
    w, h = im.size
    for y in range(h):
        if y > 42:
            for x in range(w):
                clear(px, x, y)
        elif y >= 35:
            dark = [x for x in range(w) if px[x, y][3] and value(px[x, y]) < 0.28]
            if not dark:
                continue
            left, right = min(dark), max(dark)
            for x in range(w):
                if x < left or x > right:
                    clear(px, x, y)


def ashen_tent(im):
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            if (y >= 38 and x < 9) or (y >= 44 and x > 45) or (y >= 48 and x >= 40):
                clear(px, x, y)


def sunward_stall(im):
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            if not px[x, y][3]:
                continue
            if y >= 34 and value(px[x, y]) >= 0.45:
                clear(px, x, y)
            elif 31 <= y <= 33 and x < 4:
                clear(px, x, y)


def ashen_totem(im):
    px = im.load()
    w, h = im.size
    for y in range(45, h):
        for x in range(w):
            if px[x, y][3] and value(px[x, y]) >= 0.45:
                clear(px, x, y)


def folk_camp(im):
    """The villagers' camp: its olive grass-and-dirt oval (yellow-green, mid-dark)
    goes; the tent, its sandy doorway, the stones and the basket stay."""
    import colorsys
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if not a or y < 20:
                continue
            hh, ss, vv = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            hue = hh * 360.0
            if 40.0 <= hue <= 150.0 and ss >= 0.2 and vv <= 0.62:
                clear(px, x, y)


def tent(im):
    """The keeper's camp tent: the pole feet splayed out past the fabric like skis."""
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            if y >= 49 or (y >= 46 and (x < 12 or x > 52)):
                clear(px, x, y)


RULES = {"sunward_tent": sunward_tent, "ashen_tent": ashen_tent, "sunward_stall": sunward_stall, "ashen_totem": ashen_totem,
         "folk_camp": folk_camp, "tent": tent}
PATHS = {"folk_camp": os.path.join(ROOT, "game", "Forest", "folk", "art", "folk_camp.png"),
         "tent": os.path.join(ROOT, "game", "Forest", "art", "v2", "tent.png")}


def main():
    os.makedirs(BACKUP, exist_ok=True)
    out = []
    for name, rule in RULES.items():
        path = PATHS.get(name, os.path.join(ART, name + ".png"))
        keep = os.path.join(BACKUP, name + ".png")
        if not os.path.exists(keep):
            shutil.copy2(path, keep)
        im = Image.open(keep).convert("RGBA")
        rule(im)
        # Stand the prop on its own bottom again (ForestProp draws a sprite's
        # bottom edge on the cell's ground line).
        bottom = im.getbbox()[3]
        im = im.crop((0, 0, im.width, bottom))
        out.append(im)
        if "--preview" not in sys.argv:
            im.save(path)
            print("cleared", name, im.getbbox())
    if "--preview" in sys.argv:
        dest = sys.argv[sys.argv.index("--preview") + 1]
        w = sum(i.width for i in out) + 10 * len(out)
        h = max(i.height for i in out)
        sheet = Image.new("RGBA", (w, h), (90, 140, 70, 255))
        x = 0
        for i in out:
            sheet.alpha_composite(i, (x, h - i.height))
            x += i.width + 10
        sheet.resize((sheet.width * 4, sheet.height * 4), Image.NEAREST).save(dest)
        print("preview", dest)


if __name__ == "__main__":
    main()
