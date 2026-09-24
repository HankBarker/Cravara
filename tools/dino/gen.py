"""Batch-generate the dinosaur v2 animations with PixelLab (spec: tools/dino/clips.json).

    python tools/dino/gen.py plan  [--only KEY[/CLIP[_VIEW]]]     # list jobs and estimated cost
    python tools/dino/gen.py run   [--only ...] [--inflight 7]   # submit, wait, download, clean
    python tools/dino/gen.py redo  KEY/CLIP_VIEW [--seed N] [--model ai|pmm] [--motion "..."]
    python tools/dino/gen.py clean [--only ...]                  # re-clean downloaded clips
    python tools/dino/gen.py board KEY                           # art/dino-v2/boards/KEY.png
    python tools/dino/gen.py status

Per key a ledger (art/dino-v2/ledger/KEY.json) records every job id, so a rerun
never pays twice for a clip. Raw frames land in art/dino-v2/raw/KEY/CLIP_VIEW/,
cleaned frames in art/dino-v2/clips/KEY/CLIP_VIEW/ (000.png ...).
PixelLab allows 8 concurrent jobs per account; keep --inflight below that when
another process also generates.
"""
import hashlib
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))
sys.path.insert(0, HERE)
import pixellab_mcp as pl  # noqa: E402
from clean import clean as clean_frame, palette_of, shifted, body_x  # noqa: E402
from PIL import Image  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "art", "dino-v2")
SPEC = json.load(open(os.path.join(HERE, "clips.json"), encoding="utf-8"))
VIEWS = ("side", "down", "up")


# ------------------------------------------------------------------ spec
def motion_text(key, clip):
    spec = SPEC["clips"][clip]["motion"]
    if isinstance(spec, str):
        return spec
    species = SPEC["keys"][key]["species"]
    kind = "biped" if species in SPEC["bipeds"] else "quadruped"
    for k in (species, kind, "default"):
        if k in spec:
            return spec[k]
    raise SystemExit("no motion for %s/%s" % (key, clip))


def prompt(key, clip, view, override=None):
    """Short and motion-only (see clips.json _doc): the motion, then the facing."""
    motion = override or motion_text(key, clip)
    return ("%s %s %s" % (motion, SPEC["facing"][view]["clause"], SPEC.get("style", ""))).strip()


def selected(name, only):
    """only entries: KEY, KEY/CLIP (all views) or KEY/CLIP_VIEW."""
    if not only:
        return True
    return any(name == o or name.startswith(o + "/") or name.startswith(o + "_") and "/" in o for o in only)


def jobs(only=None):
    out = []
    for key, info in SPEC["keys"].items():
        for clip in info["clips"]:
            if SPEC["clips"][clip].get("procedural"):
                continue  # built by its own tool, never generated
            for view in SPEC["clips"][clip].get("views", VIEWS):
                if selected("%s/%s_%s" % (key, clip, view), only):
                    out.append((key, clip, view))
    return out


def seed_of(name, extra=0):
    return int(hashlib.md5(name.encode()).hexdigest()[:6], 16) + extra


def first_frame(key, view):
    return os.path.join(OUT, "first", "%s_%s.png" % (key, view))


def args_for(key, clip, view, seed=None, model=None, motion=None):
    c = SPEC["clips"][clip]
    name = "%s/%s_%s" % (key, clip, view)
    ov = SPEC.get("overrides", {}).get(name, {})
    model = model or ov.get("model") or c["model"]
    motion = motion or ov.get("motion")
    first = "@" + first_frame(key, view)
    text = prompt(key, clip, view, motion)
    frames = int(c["frames"])
    a = {"first_frame_base64": first, "no_background": True, "seed": seed if seed is not None else seed_of(name)}
    if model == "ai":
        tool = "animate_image"
        a.update({"action": text[:1000], "frame_count": frames})
    else:
        tool = "animate_image_pixminimax"
        a.update({"description": text[:1000], "frame_count": max(4, frames - frames % 4), "direction": SPEC["facing"][view]["direction"]})
    if c.get("loop"):
        a["last_frame_base64"] = first
    return tool, a


# ------------------------------------------------------------------ ledger
def ledger_path(key):
    return os.path.join(OUT, "ledger", key + ".json")


def load_ledger(key):
    p = ledger_path(key)
    return json.load(open(p, encoding="utf-8")) if os.path.exists(p) else {}


def save_ledger(key, data):
    os.makedirs(os.path.dirname(ledger_path(key)), exist_ok=True)
    tmp = ledger_path(key) + ".tmp"
    json.dump(data, open(tmp, "w", encoding="utf-8"), indent=1)
    os.replace(tmp, ledger_path(key))


# ------------------------------------------------------------------ pixellab
def submit(client, key, clip, view, seed=None, model=None, motion=None):
    tool, a = args_for(key, clip, view, seed, model, motion)
    result = client.call(tool, pl.inline_files(a))
    text = pl.text_of(result)
    import re
    m = re.search(r"\b([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\b", text)
    if not m:
        raise RuntimeError("no job id for %s/%s_%s: %s" % (key, clip, view, text[:300]))
    cost = re.search(r"cost:\s*([0-9.]+)", text)
    return {"job": m.group(1), "tool": tool, "seed": a["seed"], "status": "submitted",
            "cost": float(cost.group(1)) if cost else None, "prompt": a.get("action") or a.get("description"),
            "frames": a["frame_count"] + 1, "submitted": time.time()}


def fetch(client, entry, out_dir):
    """-> 'pending' | 'done' | 'failed'"""
    import base64
    result = client.call("get_image", {"job_id": entry["job"]})
    text = pl.text_of(result)
    imgs = pl.images_of(result)
    low = text.lower()
    if not imgs and ("fail" in low or "error" in low):
        return "failed"
    if not imgs and "complete" not in low:
        return "pending"
    os.makedirs(out_dir, exist_ok=True)
    for old in os.listdir(out_dir):
        if old.endswith(".png"):
            os.remove(os.path.join(out_dir, old))
    want = int(entry["frames"])
    if len(imgs) >= want:
        for i, im in enumerate(imgs[:want]):
            open(os.path.join(out_dir, "%03d.png" % i), "wb").write(base64.b64decode(im["data"]))
    else:
        for i in range(want):
            r = client.call("get_image", {"job_id": entry["job"], "index": i})
            im = pl.images_of(r)
            if not im:
                break
            open(os.path.join(out_dir, "%03d.png" % i), "wb").write(base64.b64decode(im[0]["data"]))
    return "done"


# ------------------------------------------------------------------ quality
MAX_ATTEMPTS = 4
TAIL_OK = {"tail_swing", "death", "pounce", "stomp", "eat"}


def _lum(c):
    return (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255.0


def effect_score(key, clip, view, raw_dir=None):
    """How much a generated clip looks like the model painted effects or
    changed the view: {"bright": most extra bright pixels in any frame,
    "area": largest silhouette area ratio, "wide": largest width ratio}.
    Painted sparkles, flashes and slashes add many near-white pixels; flames
    and view changes swell the silhouette."""
    d = raw_dir or os.path.join(OUT, "raw", key, "%s_%s" % (clip, view))
    names = sorted(n for n in os.listdir(d) if n.endswith(".png") and n[:3].isdigit())
    if len(names) < 2:
        return {"bright": 0, "area": 1.0, "wide": 1.0}
    def stats(img):
        px = [p for p in img.getdata() if p[3] >= 128]
        box = img.getbbox()
        return len(px), sum(1 for p in px if _lum(p) > 0.78), (box[2] - box[0]) if box else 1
    n0, b0, w0 = stats(Image.open(os.path.join(d, names[0])).convert("RGBA"))
    worst = {"bright": 0, "area": 1.0, "wide": 1.0}
    for n in names[1:]:
        n1, b1, w1 = stats(Image.open(os.path.join(d, n)).convert("RGBA"))
        worst["bright"] = max(worst["bright"], b1 - b0)
        worst["area"] = max(worst["area"], round(n1 / max(1, n0), 2))
        worst["wide"] = max(worst["wide"], round(w1 / max(1, w0), 2))
    return worst


def flagged(clip, view, sc):
    """True when a clip should be regenerated."""
    if sc["bright"] > 30:
        return True
    if SPEC["clips"][clip].get("loop") and sc["area"] > 1.15:
        return True
    if view != "side" and clip not in TAIL_OK and sc["wide"] > 1.7:
        return True  # a front/back clip that turned side-on
    return False


def badness(sc):
    return sc["bright"] + max(0.0, sc["area"] - 1.0) * 400 + max(0.0, sc["wide"] - 1.0) * 150


# ------------------------------------------------------------------ cleaning
def palette(species):
    return [tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) for h in open(os.path.join(OUT, "palettes", species + ".hex")).read().split()]


def clean_clip(key, clip, view):
    c = SPEC["clips"][clip]
    raw = os.path.join(OUT, "raw", key, "%s_%s" % (clip, view))
    dst = os.path.join(OUT, "clips", key, "%s_%s" % (clip, view))
    names = sorted(n for n in os.listdir(raw) if n.endswith(".png") and n[:3].isdigit())
    if not names:
        return 0
    pal = palette(SPEC["keys"][key]["species"])
    cache = {}
    first = Image.open(first_frame(key, view)).convert("RGBA")
    ref_bottom = first.getbbox()[3]
    ref_x = body_x(first)
    frames = []
    for n in names:
        img = Image.open(os.path.join(raw, n)).convert("RGBA")
        if img.size != first.size:
            img = img.resize(first.size, Image.NEAREST)
        frames.append(clean_frame(img, pal, cache, 4))
    frames[0] = clean_frame(first, pal, cache, 1)  # the untouched drawing, not the model's re-quantised copy
    if c.get("loop") and len(frames) > 2:
        frames = frames[:-1]  # the pinned last frame repeats frame 0
    opts = c.get("clean", {})
    os.makedirs(dst, exist_ok=True)
    for old in os.listdir(dst):
        if old.endswith(".png"):
            os.remove(os.path.join(dst, old))
    ref_top = first.getbbox()[1]
    for i, f in enumerate(frames):
        dx = dy = 0
        box = f.getbbox()
        if box and opts.get("ground"):
            dy = ref_bottom - box[3]
        if "clamp_sides" in opts and i > 0 and view != "side":
            # Front/back loops stay within the resting drawing's width.
            ref_box = first.getbbox()
            left = ref_box[0] - int(opts["clamp_sides"]) - dx
            right = ref_box[2] + int(opts["clamp_sides"]) - dx
            f = f.copy()
            if left > 0:
                f.paste((0, 0, 0, 0), (0, 0, left, f.height))
            if right < f.width:
                f.paste((0, 0, 0, 0), (right, 0, f.width, f.height))
        if "clamp_top" in opts and i > 0:
            # Nothing may grow more than clamp_top px above the resting top.
            limit = ref_top - int(opts["clamp_top"]) - dy
            if limit > 0:
                f = f.copy()
                f.paste((0, 0, 0, 0), (0, 0, f.width, limit))
        if box and opts.get("anchor"):
            bx = body_x(f)
            if bx is not None:
                dx = int(round(ref_x - bx))
        shifted(f, dx, dy).save(os.path.join(dst, "%03d.png" % i))
    return len(frames)


# ------------------------------------------------------------------ boards
def board(key, scale=2):
    from PIL import ImageDraw
    info = SPEC["keys"][key]
    rows = []
    for clip in info["clips"]:
        for view in VIEWS:
            d = os.path.join(OUT, "clips", key, "%s_%s" % (clip, view))
            if not os.path.isdir(d):
                continue
            fr = [Image.open(os.path.join(d, n)).convert("RGBA") for n in sorted(os.listdir(d)) if n.endswith(".png")]
            if fr:
                rows.append(("%s %s" % (clip, view), fr))
    if not rows:
        return None
    w, h = rows[0][1][0].size
    cols = max(len(r[1]) for r in rows)
    label = 70
    sheet = Image.new("RGBA", (label + cols * (w + 2) * scale, len(rows) * (h + 2) * scale), (72, 96, 60, 255))
    draw = ImageDraw.Draw(sheet)
    for r, (name, fr) in enumerate(rows):
        y = r * (h + 2) * scale
        draw.text((3, y + 3), name, fill=(255, 240, 200, 255))
        for i, f in enumerate(fr):
            sheet.alpha_composite(f.resize((w * scale, h * scale), Image.NEAREST), (label + i * (w + 2) * scale, y))
    os.makedirs(os.path.join(OUT, "boards"), exist_ok=True)
    path = os.path.join(OUT, "boards", key + ".png")
    sheet.save(path)
    return path


# ------------------------------------------------------------------ commands
def opt(flag, default=None):
    return sys.argv[sys.argv.index(flag) + 1] if flag in sys.argv else default


def only_list():
    o = opt("--only")
    return o.split(",") if o else None


def cmd_plan():
    todo = jobs(only_list())
    fresh = [(k, c, v) for k, c, v in todo if "%s_%s" % (c, v) not in load_ledger(k)]
    print("%d jobs in scope, %d not yet submitted" % (len(todo), len(fresh)))
    for k, c, v in fresh[:400]:
        tool, a = args_for(k, c, v)
        print("  %-14s %-11s %-4s %s x%d" % (k, c, v, "ai " if tool == "animate_image" else "pmm", a["frame_count"]))


def cmd_run():
    inflight_max = int(opt("--inflight", "7"))
    todo = [(k, c, v) for k, c, v in jobs(only_list())]
    client = pl.Client()
    spent = 0.0
    global SPEC
    while True:
        # Prompt/override edits in clips.json apply from the next round on.
        SPEC = json.load(open(os.path.join(HERE, "clips.json"), encoding="utf-8"))
        ledgers = {k: load_ledger(k) for k in {t[0] for t in todo}}
        pending = [(k, c, v) for k, c, v in todo if "%s_%s" % (c, v) not in ledgers[k]]
        inflight = [(k, c, v) for k, c, v in todo if ledgers[k].get("%s_%s" % (c, v), {}).get("status") == "submitted"]
        # collect finished jobs
        for k, c, v in inflight:
            e = ledgers[k]["%s_%s" % (c, v)]
            try:
                state = fetch(client, e, os.path.join(OUT, "raw", k, "%s_%s" % (c, v)))
            except Exception as ex:  # transient network trouble: try again next round
                print("fetch error", k, c, v, ex)
                continue
            if state == "pending":
                continue
            e["status"] = state
            e["finished"] = time.time()
            name = "%s_%s" % (c, v)
            if state == "done":
                sc = effect_score(k, c, v)
                e["score"] = sc
                history = ledgers[k].get("_history", {}).get(name, [])
                raw = os.path.join(OUT, "raw", k, name)
                if flagged(c, v, sc) and len(history) + 1 < MAX_ATTEMPTS:
                    # Keep this attempt's frames aside and try another seed.
                    keep = raw + "@%d" % len(history)
                    if os.path.isdir(keep):
                        import shutil
                        shutil.rmtree(keep)
                    os.replace(raw, keep)
                    e["raw"] = keep
                    ledgers[k].setdefault("_history", {}).setdefault(name, []).append(ledgers[k].pop(name))
                    print("RETRY %s/%s (score %s)" % (k, name, sc), flush=True)
                else:
                    if flagged(c, v, sc) and history:
                        # Out of attempts: keep the least-bad version.
                        best = min(history + [e], key=lambda h: badness(h.get("score", {"bright": 999, "area": 9, "wide": 9})))
                        if best is not e and best.get("raw") and os.path.isdir(best["raw"]):
                            import shutil
                            shutil.rmtree(raw)
                            shutil.copytree(best["raw"], raw)
                            e["kept_attempt"] = best["raw"]
                    n = clean_clip(k, c, v)
                    print("DONE %s/%s (%d frames, score %s%s)" % (k, name, n, sc, " FLAGGED" if flagged(c, v, sc) else ""), flush=True)
            else:
                print("FAILED %s/%s_%s" % (k, c, v), flush=True)
            save_ledger(k, ledgers[k])
        ledgers = {k: load_ledger(k) for k in ledgers}
        inflight = [(k, c, v) for k, c, v in todo if ledgers[k].get("%s_%s" % (c, v), {}).get("status") == "submitted"]
        # submit more
        slots = inflight_max - len(inflight)
        for k, c, v in pending[:max(0, slots)]:
            try:
                attempt = len(load_ledger(k).get("_history", {}).get("%s_%s" % (c, v), []))
                e = submit(client, k, c, v, seed_of("%s/%s_%s" % (k, c, v), 1000 * attempt) if attempt else None)
            except Exception as ex:
                print("submit error", k, c, v, str(ex)[:300], flush=True)
                time.sleep(15)
                break
            spent += e["cost"] or 0
            led = load_ledger(k)
            led["%s_%s" % (c, v)] = e
            save_ledger(k, led)
            print("SUBMIT %s/%s_%s job %s cost %s" % (k, c, v, e["job"], e["cost"]), flush=True)
        if not pending and not inflight:
            break
        time.sleep(20)
    for k in sorted({t[0] for t in todo}):
        p = board(k)
        if p:
            print("BOARD", p)
    print("RUN COMPLETE, spent this run: %.1f generations" % spent)


def cmd_redo():
    name = sys.argv[2]
    key, rest = name.split("/")
    clip, view = rest.rsplit("_", 1)
    seed = opt("--seed")
    led = load_ledger(key)
    old = led.get(rest)
    if old:
        led.setdefault("_history", {}).setdefault(rest, []).append(old)
    client = pl.Client()
    e = submit(client, key, clip, view, int(seed) if seed else seed_of(name, 1000 + len(led.get("_history", {}).get(rest, []))),
               opt("--model"), opt("--motion"))
    led[rest] = e
    save_ledger(key, led)
    print("SUBMIT %s job %s cost %s (collect with: gen.py run --only %s)" % (name, e["job"], e["cost"], name))


def cmd_requeue():
    """Move the selected clips' ledger entries to history so `run` makes them
    again (with a fresh seed)."""
    n = 0
    for k, c, v in jobs(only_list()):
        led = load_ledger(k)
        name = "%s_%s" % (c, v)
        if name in led and led[name].get("status") != "submitted":
            led.setdefault("_history", {}).setdefault(name, []).append(led.pop(name))
            save_ledger(k, led)
            n += 1
    print("requeued", n)


def cmd_qa():
    """Score every downloaded clip; list the ones that look wrong."""
    bad = 0
    for k, c, v in jobs(only_list()):
        d = os.path.join(OUT, "raw", k, "%s_%s" % (c, v))
        if not os.path.isdir(d):
            continue
        sc = effect_score(k, c, v)
        if flagged(c, v, sc) or "--all" in sys.argv:
            bad += flagged(c, v, sc)
            print("%-14s %-11s %-4s %s%s" % (k, c, v, sc, "  FLAG" if flagged(c, v, sc) else ""))
    print("flagged:", bad)


def cmd_clean():
    for k, c, v in jobs(only_list()):
        e = load_ledger(k).get("%s_%s" % (c, v), {})
        if e.get("method"):
            print(k, c, v, "kept (built by", e["method"] + ")")
        elif e.get("status") == "done":
            print(k, c, v, clean_clip(k, c, v))


def cmd_status():
    total = done = failed = sub = 0
    cost = 0.0
    for k in SPEC["keys"]:
        led = load_ledger(k)
        for name, e in led.items():
            if name.startswith("_"):
                continue
            total += 1
            cost += e.get("cost") or 0
            done += e["status"] == "done"
            failed += e["status"] == "failed"
            sub += e["status"] == "submitted"
    print("jobs %d: done %d, in flight %d, failed %d; generations %.1f" % (total, done, sub, failed, cost))


def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    {"plan": cmd_plan, "run": cmd_run, "redo": cmd_redo, "clean": cmd_clean, "status": cmd_status, "requeue": cmd_requeue, "qa": cmd_qa,
     "board": lambda: print(board(sys.argv[2]))}[cmd]()


if __name__ == "__main__":
    main()
