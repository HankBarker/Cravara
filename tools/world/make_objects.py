"""World objects drawn by PixelLab (create_map_object), several at once.

    python tools/world/make_objects.py SPEC.json [NAME ...]

SPEC.json is a list of {"name", "description", "width", "height"} (plus any
create_map_object argument). Each object is written raw to
art/pass11/objects/<name>.png (1 generation each); the game's copies are cut
from those by tools/world/make_pass11_art.py. Names already drawn are skipped
unless named on the command line.
"""
import io
import json
import os
import re
import sys
import threading
import time
import urllib.request
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import pixellab_mcp as pl  # noqa: E402

OUT = os.path.join(ROOT, "art", "pass11", "objects")
UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) CraveraWorld/1.0"}
DEFAULTS = {"view": "low top-down", "outline": "single color outline", "shading": "medium shading", "detail": "medium detail"}
LOCK = threading.Lock()


def say(*parts):
    with LOCK:
        print(*parts, flush=True)


def fetch(object_id, path):
    url = "https://api.pixellab.ai/mcp/map-objects/%s/download" % object_id
    for attempt in range(120):
        try:
            data = urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=60).read()
            if data[:4] == b"\x89PNG":
                open(path, "wb").write(data)
                return True
            if data[:2] == b"PK":
                z = zipfile.ZipFile(io.BytesIO(data))
                for name in z.namelist():
                    if name.lower().endswith(".png"):
                        open(path, "wb").write(z.read(name))
                        return True
        except Exception:
            pass
        time.sleep(8)
    return False


def make(obj):
    args = dict(DEFAULTS)
    args.update({k: v for k, v in obj.items() if k != "name"})
    reply = ""
    for attempt in range(40):
        try:
            reply = pl.text_of(pl.Client().call("create_map_object", args))
        except SystemExit as e:
            reply = str(e)
        if "rate limit" not in reply.lower():
            break
        time.sleep(20)  # PixelLab runs 8 jobs at once per account
    m = re.search(r"\b([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\b", reply)
    if not m:
        say("[%s] no object id in reply: %s" % (obj["name"], reply[:300]))
        return
    path = os.path.join(OUT, obj["name"] + ".png")
    ok = fetch(m.group(1), path)
    with open(os.path.join(OUT, obj["name"] + ".json"), "w", encoding="utf-8") as f:
        json.dump({"id": m.group(1), "args": {k: v for k, v in args.items()}}, f, indent=1)
    say("[%s] %s" % (obj["name"], "wrote " + path if ok else "NOT READY (id %s)" % m.group(1)))


def main():
    spec = json.load(open(sys.argv[1], encoding="utf-8"))
    names = set(sys.argv[2:])
    os.makedirs(OUT, exist_ok=True)
    todo = [o for o in spec if (o["name"] in names) or (not names and not os.path.exists(os.path.join(OUT, o["name"] + ".png")))]
    say("drawing", len(todo), "objects:", ", ".join(o["name"] for o in todo))
    threads = []
    for obj in todo:
        while sum(t.is_alive() for t in threads) >= 3:
            time.sleep(1)
        t = threading.Thread(target=make, args=(obj,))
        t.start()
        threads.append(t)
        time.sleep(1.5)
    for t in threads:
        t.join()


if __name__ == "__main__":
    main()
