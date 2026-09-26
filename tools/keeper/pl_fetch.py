"""Download PixelLab results to disk (no auth needed; UUIDs are the key).

    python tools/keeper/pl_fetch.py image <job_id> <out.png>
    python tools/keeper/pl_fetch.py character <character_id> <out_dir>   # south/east/north/west rotations

Cloudflare rejects Python's default User-Agent, so a browser UA is sent.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) KeeperPipeline/1.0"}
CHAR_CDN = "https://backblaze.pixellab.ai/file/pixellab-characters/88b32f13-f02d-4540-9dcc-403c6c344192/{cid}/rotations/{d}.png"


def get(url, retries=20):
    for _ in range(retries):
        req = urllib.request.Request(url, headers=UA)
        try:
            with urllib.request.urlopen(req) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            if e.code == 423:  # still generating
                time.sleep(int(e.headers.get("Retry-After", "5")))
                continue
            raise
        except (ConnectionError, OSError):
            time.sleep(2)
            continue
    raise TimeoutError(url)


def main():
    kind, ident, out = sys.argv[1], sys.argv[2], sys.argv[3]
    if kind == "image":
        data = get(f"https://api.pixellab.ai/mcp/images/{ident}/download")
        os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)
        open(out, "wb").write(data)
        print("saved", out, len(data))
    elif kind == "character":
        os.makedirs(out, exist_ok=True)
        for d in ("south", "east", "north", "west", "south-east", "south-west", "north-east", "north-west"):
            data = get(CHAR_CDN.format(cid=ident, d=d))
            open(os.path.join(out, f"{d}.png"), "wb").write(data)
        print("saved rotations to", out)
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
