"""Call PixelLab MCP tools from the command line with images read from disk.

The MCP tools in an agent session take images as inline base64, which is easy to
corrupt when copied by hand. This client sends files directly:

    python tools/pixellab_mcp.py call animate_image_pixminimax args.json
    python tools/pixellab_mcp.py wait <job_id> <out_dir> [--frames N]
    python tools/pixellab_mcp.py balance

In args.json any string value "@path/to/file.png" is replaced by that file's
base64. `call` prints the tool's text reply (job id etc.). `wait` polls
get_image until the job completes and writes <out_dir>/000.png, 001.png, ...

The bearer token comes from PIXELLAB_API_KEY or the local, git-ignored
.codex/config.toml ([mcp_servers.pixellab.http_headers] Authorization). It is
never printed.
"""
import base64
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
URL = "https://api.pixellab.ai/mcp"
UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36"


def token():
    t = os.environ.get("PIXELLAB_API_KEY", "").strip()
    if t:
        return t
    cfg = os.path.join(ROOT, ".codex", "config.toml")
    if os.path.exists(cfg):
        m = re.search(r'Authorization\s*=\s*"Bearer\s+([^"]+)"', open(cfg, encoding="utf-8").read())
        if m:
            return m.group(1).strip()
    sys.exit("No PixelLab token: set PIXELLAB_API_KEY or configure .codex/config.toml.")


class Client:
    def __init__(self):
        self.token = token()
        self.session = None
        self.next_id = 1
        self._rpc("initialize", {
            "protocolVersion": "2025-03-26",
            "capabilities": {},
            "clientInfo": {"name": "cravera-pixellab-cli", "version": "1.0"},
        })
        self._send({"jsonrpc": "2.0", "method": "notifications/initialized"}, expect=False)

    def _send(self, payload, expect=True):
        headers = {
            "Authorization": "Bearer " + self.token,
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
            "User-Agent": UA,
        }
        if self.session:
            headers["Mcp-Session-Id"] = self.session
        req = urllib.request.Request(URL, data=json.dumps(payload).encode(), headers=headers, method="POST")
        for attempt in range(5):
            try:
                with urllib.request.urlopen(req, timeout=180) as resp:
                    sid = resp.headers.get("Mcp-Session-Id")
                    if sid:
                        self.session = sid
                    body = resp.read().decode("utf-8", "replace")
                    ctype = resp.headers.get("Content-Type", "")
                break
            except urllib.error.HTTPError as e:
                if e.code in (429, 500, 502, 503, 504) and attempt < 4:
                    time.sleep(3 + attempt * 4)
                    continue
                raise SystemExit("PixelLab HTTP %d: %s" % (e.code, e.read().decode("utf-8", "replace")[:500]))
            except (urllib.error.URLError, OSError):
                if attempt < 4:
                    time.sleep(3 + attempt * 4)
                    continue
                raise
        if not expect:
            return None
        if "text/event-stream" in ctype:
            msgs = [json.loads(line[5:].strip()) for line in body.splitlines() if line.startswith("data:") and line[5:].strip()]
            for m in msgs:
                if m.get("id") == payload.get("id"):
                    return m
            return msgs[-1] if msgs else {}
        return json.loads(body) if body.strip() else {}

    def _rpc(self, method, params):
        payload = {"jsonrpc": "2.0", "id": self.next_id, "method": method, "params": params}
        self.next_id += 1
        reply = self._send(payload)
        if "error" in reply:
            raise SystemExit("PixelLab error: %s" % json.dumps(reply["error"])[:800])
        return reply.get("result", {})

    def call(self, tool, args):
        return self._rpc("tools/call", {"name": tool, "arguments": args})


def inline_files(value):
    if isinstance(value, str) and value.startswith("@"):
        with open(value[1:], "rb") as f:
            return base64.b64encode(f.read()).decode()
    if isinstance(value, dict):
        return {k: inline_files(v) for k, v in value.items()}
    if isinstance(value, list):
        return [inline_files(v) for v in value]
    return value


def text_of(result):
    return "\n".join(c.get("text", "") for c in result.get("content", []) if c.get("type") == "text")


def images_of(result):
    return [c for c in result.get("content", []) if c.get("type") == "image"]


def cmd_call(tool, args_path):
    args = json.load(open(args_path, encoding="utf-8"))
    result = Client().call(tool, inline_files(args))
    print(text_of(result))
    m = re.search(r"\b([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\b", text_of(result))
    if m:
        print("JOB_ID", m.group(1))


def _download(url, path):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=120) as resp, open(path, "wb") as f:
                f.write(resp.read())
            return True
        except urllib.error.HTTPError as e:
            if e.code == 410:
                return False
            time.sleep(2 + attempt * 3)
        except (urllib.error.URLError, OSError):
            time.sleep(2 + attempt * 3)
    return False


def cmd_wait(job, out_dir, frames=None, timeout=900):
    os.makedirs(out_dir, exist_ok=True)
    client = Client()
    start = time.time()
    while True:
        result = client.call("get_image", {"job_id": job})
        text = text_of(result)
        imgs = images_of(result)
        low = text.lower()
        if "fail" in low and not imgs:
            raise SystemExit("Job failed: " + text[:600])
        done = bool(imgs) or "completed" in low
        if done:
            break
        if time.time() - start > timeout:
            raise SystemExit("Timed out waiting for " + job + ": " + text[:300])
        time.sleep(10)
    urls = re.findall(r"https://\S+?\.png\b|https://\S+/download\S*", text)
    count = frames
    m = re.search(r"(\d+)\s+(?:frames|images)", text)
    if count is None and m:
        count = int(m.group(1))
    saved = 0
    if count and count > len(imgs):
        # Long animations only inline the first few frames: fetch each by index.
        for i in range(count):
            r = client.call("get_image", {"job_id": job, "index": i})
            im = images_of(r)
            if not im:
                break
            with open(os.path.join(out_dir, "%03d.png" % i), "wb") as f:
                f.write(base64.b64decode(im[0]["data"]))
            saved += 1
    else:
        for i, im in enumerate(imgs):
            with open(os.path.join(out_dir, "%03d.png" % i), "wb") as f:
                f.write(base64.b64decode(im["data"]))
            saved += 1
    if saved == 0 and urls:
        for i, u in enumerate(urls):
            if _download(u.rstrip(").,"), os.path.join(out_dir, "%03d.png" % i)):
                saved += 1
    with open(os.path.join(out_dir, "job.txt"), "w", encoding="utf-8") as f:
        f.write(job + "\n" + text)
    print("SAVED", saved, "frames to", out_dir)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    cmd = sys.argv[1]
    if cmd == "call":
        cmd_call(sys.argv[2], sys.argv[3])
    elif cmd == "wait":
        frames = None
        if "--frames" in sys.argv:
            frames = int(sys.argv[sys.argv.index("--frames") + 1])
        cmd_wait(sys.argv[2], sys.argv[3], frames)
    elif cmd == "balance":
        print(text_of(Client().call("get_balance", {})))
    elif cmd == "tools":
        result = Client()._rpc("tools/list", {})
        print("\n".join(t["name"] for t in result.get("tools", [])))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
