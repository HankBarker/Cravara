"""Local character approval studio. Generation is performed by the active Codex task.

python tools/character_studio.py serve
python tools/character_studio.py add-clip raptor-v2 walk_right frames/*.png
python tools/character_studio.py export raptor-v2
"""
from __future__ import annotations

import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import mimetypes
from pathlib import Path
import re
import shutil
import time
from urllib.parse import urlparse, unquote

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'art/character-studio'
WEB = ROOT / 'tools/character_studio_web'
REQUIRED = [f'{a}_{d}' for a in ('idle', 'walk', 'bite') for d in ('down', 'up', 'left', 'right')] + ['death']
SUPPORTED = REQUIRED + [f'{a}_{d}' for a in ('run', 'swipe') for d in ('down', 'up', 'left', 'right')]

def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def folder(name):
    if not re.fullmatch(r'[a-z][a-z0-9-]{0,63}', name):
        raise ValueError('Use a lowercase character id, letters, numbers and hyphens only')
    return DATA / name

def read(name):
    return json.loads((folder(name) / 'character.json').read_text(encoding='utf-8'))

def save(name, data):
    p = folder(name) / 'character.json'
    p.parent.mkdir(parents=True, exist_ok=True)
    temp = p.with_suffix('.tmp')
    temp.write_text(json.dumps(data, indent=2), encoding='utf-8')
    temp.replace(p)

def asset(name, relative):
    base = folder(name).resolve()
    p = (base / relative).resolve()
    if not p.is_relative_to(base):
        raise ValueError('Asset must stay inside this character project')
    return p

def audit(path):
    with Image.open(path) as original:
        im = original.convert('RGBA')
    alpha = im.getchannel('A')
    hist = alpha.histogram()
    return {'width': im.width, 'height': im.height, 'transparent_pixels': hist[0],
            'partial_alpha_pixels': sum(hist[1:255]), 'opaque_pixels': hist[255],
            'bounds': alpha.getbbox(), 'sha256': digest(path)}

def concept_ok(name, data):
    c = data.get('concept')
    return bool(c and c.get('approved_sha256') == digest(asset(name, c['file'])))

def clip_hash(name, clip):
    parts = [str(clip['fps']), str(clip['loop']), json.dumps(clip['pivot']), clip['concept_sha256']]
    parts.extend(digest(asset(name, p)) for p in clip['frames'])
    return hashlib.sha256('|'.join(parts).encode()).hexdigest()

def validate_clip(name, clip):
    problems = []
    reports = [audit(asset(name, p)) for p in clip['frames']]
    if not reports:
        return ['No frames supplied']
    sizes = {(r['width'], r['height']) for r in reports}
    if len(sizes) != 1:
        problems.append('All frames must have the same canvas size; do not crop each frame separately')
    if any(not r['transparent_pixels'] or not r['opaque_pixels'] for r in reports):
        problems.append('Every frame needs real transparency and visible opaque artwork')
    if any(r['partial_alpha_pixels'] for r in reports):
        problems.append('Pixel sprites need hard alpha; clean soft edges in Aseprite')
    if any(max(r['width'], r['height']) > 128 for r in reports):
        problems.append('Frames exceed the 128px native canvas gate; prepare at game resolution')
    if any(r['bounds'] and (r['bounds'][0] == 0 or r['bounds'][1] == 0 or r['bounds'][2] == r['width'] or r['bounds'][3] == r['height']) for r in reports):
        problems.append('Artwork touches a canvas edge; add padding to avoid clipping')
    if len(reports) > 1 and len({r['sha256'] for r in reports}) == 1:
        problems.append('All animation frames are identical')
    if not 1 <= clip['fps'] <= 60:
        problems.append('FPS must be 1 through 60')
    return problems

def state(name):
    d = read(name)
    d['id'] = name
    if d.get('concept'):
        d['concept']['audit'] = audit(asset(name, d['concept']['file']))
        d['concept']['approved'] = concept_ok(name, d)
    for clip in d['clips'].values():
        clip['problems'] = validate_clip(name, clip)
        clip['approved'] = clip.get('approved_sha256') == clip_hash(name, clip)
    d['missing'] = [n for n in REQUIRED if n not in d['clips']]
    return d

def new(name, brief):
    if (folder(name) / 'character.json').exists():
        raise ValueError('Character already exists')
    save(name, {'name': name.replace('-', ' ').title(), 'brief': brief, 'concept': None,
                'clips': {}, 'requests': [], 'history': []})

def add_concept(name, source):
    d = read(name)
    stamp = str(time.time_ns())
    dest = folder(name) / f'concept-{stamp}.png'
    shutil.copy2(source, dest)
    d['concept'] = {'file': dest.name, 'approved_sha256': None}
    d['history'].append({'event': 'concept_added', 'file': dest.name, 'time': time.time()})
    save(name, d)

def add_clip(name, animation, paths, fps=8):
    d = read(name)
    if not concept_ok(name, d):
        raise ValueError('Approve the current concept before registering animation')
    if animation not in SUPPORTED:
        raise ValueError('Use a Cravera animation name: ' + ', '.join(SUPPORTED))
    sources = [Path(p) for p in paths]
    if not sources:
        raise ValueError('Supply individual frame PNGs in playback order')
    # Inspect every input before writing anything; one canvas and a fixed pivot.
    sizes = set()
    for path in sources:
        with Image.open(path) as image:
            sizes.add(image.size)
    if len(sizes) != 1:
        raise ValueError('Frame canvas sizes differ')
    w, h = next(iter(sizes))
    dest = folder(name) / 'clips' / f'{animation}-{time.time_ns()}'
    dest.mkdir(parents=True)
    frames = []
    for i, source in enumerate(sources):
        p = dest / f'{i:03}.png'
        shutil.copy2(source, p)
        frames.append(p.relative_to(folder(name)).as_posix())
    d['clips'][animation] = {'frames': frames, 'fps': fps, 'loop': not animation.startswith(('bite', 'swipe', 'death')),
                            'pivot': [w // 2, h // 2], 'concept_sha256': digest(asset(name, d['concept']['file']))}
    save(name, d)

def action(name, body):
    d = read(name)
    event = body['action']
    if event == 'approve_concept':
        if not d.get('concept'):
            raise ValueError('No concept to approve')
        d['concept']['approved_sha256'] = digest(asset(name, d['concept']['file']))
    elif event == 'request_revision':
        if not body.get('notes', '').strip():
            raise ValueError('Describe the change you want')
        if d.get('concept'):
            d['concept']['approved_sha256'] = None
        d['requests'].append({'type': 'concept_revision', 'notes': body['notes'], 'status': 'pending'})
    elif event == 'request_walk':
        if not concept_ok(name, d):
            raise ValueError('Approve the current concept first')
        d['requests'].append({'type': 'walk_right', 'notes': 'Six separately generated poses, fixed canvas and pivot; present contact sheet and loop for review.', 'status': 'pending'})
    elif event == 'approve_clip':
        clip = d['clips'][body['clip']]
        if not concept_ok(name, d) or clip['concept_sha256'] != d['concept']['approved_sha256']:
            raise ValueError('Clip belongs to a different or unapproved concept')
        problems = validate_clip(name, clip)
        if problems:
            raise ValueError('; '.join(problems))
        clip['approved_sha256'] = clip_hash(name, clip)
    else:
        raise ValueError('Unknown action')
    d['history'].append({'event': event, 'notes': body.get('notes', ''), 'time': time.time()})
    save(name, d)
    return state(name)

def export(name):
    """Export an approved complete character to a NEW staging folder, never replace gameplay."""
    d = read(name)
    if not concept_ok(name, d):
        raise ValueError('Concept approval required')
    missing = set(REQUIRED) - d['clips'].keys()
    if missing:
        raise ValueError('Missing animations: ' + ', '.join(sorted(missing)))
    for key, clip in d['clips'].items():
        if clip['concept_sha256'] != d['concept']['approved_sha256'] or clip.get('approved_sha256') != clip_hash(name, clip):
            raise ValueError('Unapproved or changed animation: ' + key)
        problems = validate_clip(name, clip)
        if problems:
            raise ValueError(key + ': ' + '; '.join(problems))
    target = ROOT / 'game/Sprites/CharacterStudio' / f'{name}-{time.time_ns()}'
    target.mkdir(parents=True)
    images, definitions = [], []
    for key, clip in d['clips'].items():
        refs = []
        for source in clip['frames']:
            idx = len(images) + 1
            fn = f'frame-{idx:03}.png'
            shutil.copy2(asset(name, source), target / fn)
            res = (target / fn).relative_to(ROOT / 'game').as_posix()
            images.append(f'[ext_resource type="Texture2D" path="res://{res}" id="{idx}"]')
            refs.append('{"duration": 1.0, "texture": ExtResource("%s")}' % idx)
        definitions.append('{"frames": [%s], "loop": %s, "name": &"%s", "speed": %s}' %
                           (','.join(refs), str(clip['loop']).lower(), key, clip['fps']))
    resource = '[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n%s\n\n[resource]\nanimations = [%s]\n' % (len(images)+1, '\n'.join(images), ',\n'.join(definitions))
    (target / 'frames.tres').write_text(resource, encoding='utf-8')
    (target / 'manifest.json').write_text(json.dumps(d, indent=2), encoding='utf-8')
    return str(target / 'frames.tres')

class Handler(BaseHTTPRequestHandler):
    def respond(self, data, status=200):
        payload = json.dumps(data).encode()
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(payload)

    def do_GET(self):
        path = unquote(urlparse(self.path).path)
        try:
            if path == '/api/characters':
                return self.respond([state(p.parent.name) for p in DATA.glob('*/character.json')])
            if path == '/api/connections':
                return self.respond(json.loads((DATA / 'connections.json').read_text()))
            if path.startswith('/assets/'):
                candidate = (DATA / path[len('/assets/'):]).resolve()
                if not candidate.is_relative_to(DATA.resolve()) or candidate.suffix not in ('.png', '.gif', '.aseprite'):
                    raise ValueError('Invalid asset')
            else:
                candidate = WEB / 'index.html' if path == '/' else WEB / path.lstrip('/')
                candidate = candidate.resolve()
                if not candidate.is_relative_to(WEB.resolve()):
                    raise ValueError('Invalid path')
            raw = candidate.read_bytes()
            self.send_response(200)
            self.send_header('Content-Type', mimetypes.guess_type(candidate)[0] or 'application/octet-stream')
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            self.wfile.write(raw)
        except (ValueError, FileNotFoundError, KeyError) as exc:
            self.respond({'error': str(exc)}, 404)

    def do_POST(self):
        try:
            # Same-origin JSON only. No external site can trigger approvals.
            if self.headers.get('Origin') not in (None, f'http://{self.headers.get("Host")}'):
                raise ValueError('Cross-origin request rejected')
            if self.headers.get('Content-Type') != 'application/json':
                raise ValueError('Expected application/json')
            length = int(self.headers.get('Content-Length', 0))
            if not 0 < length <= 16384:
                raise ValueError('Invalid request size')
            body = json.loads(self.rfile.read(length))
            if self.path == '/api/new':
                new(body['id'], body.get('brief', ''))
                return self.respond(state(body['id']))
            if self.path != '/api/action':
                raise ValueError('Unknown endpoint')
            self.respond(action(body['id'], body))
        except (ValueError, KeyError, FileNotFoundError) as exc:
            self.respond({'error': str(exc)}, 400)

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    p = sub.add_parser('serve'); p.add_argument('--port', type=int, default=18765)
    p = sub.add_parser('new'); p.add_argument('id'); p.add_argument('--brief', default='')
    p = sub.add_parser('add-concept'); p.add_argument('id'); p.add_argument('source')
    p = sub.add_parser('add-clip'); p.add_argument('id'); p.add_argument('animation'); p.add_argument('frames', nargs='+'); p.add_argument('--fps', type=int, default=8)
    p = sub.add_parser('export'); p.add_argument('id')
    args = parser.parse_args()
    try:
        if args.command == 'serve':
            server = HTTPServer(('127.0.0.1', args.port), Handler)
            print(f'Character Studio http://127.0.0.1:{args.port}', flush=True)
            server.serve_forever()
        elif args.command == 'new': new(args.id, args.brief)
        elif args.command == 'add-concept': add_concept(args.id, args.source)
        elif args.command == 'add-clip': add_clip(args.id, args.animation, args.frames, args.fps)
        elif args.command == 'export': print(export(args.id))
    except ValueError as exc:
        parser.exit(1, str(exc) + '\n')

if __name__ == '__main__':
    main()
