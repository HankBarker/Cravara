"""Pass 15: the dinosaurs' voices, made with ElevenLabs' sound effects.

    python tools/audio/elevenlabs_sfx.py --plan              # what it would make, and how many seconds
    python tools/audio/elevenlabs_sfx.py [--only raptor,rex] [--cues ambient,roar] [--force]

Hank: "sound effects for the dinosaurs... just light, like ARK, where they'd
make a little noise every once in a while... not overwhelming".

The key is read from the environment (ELEVENLABS_API_KEY) or from
.codex/elevenlabs.key (gitignored), and never printed or written anywhere
else. Each sound is written to game/Forest/audio/creatures/v2/<species>-<cue>-<n>.mp3;
CreatureAudio plays these when they exist (a species' own voice, several
takes of each cue so a herd doesn't repeat itself) and falls back to the old
borrowed voices when they don't.

Cues: ambient (the odd call while it goes about its day, often heard from
far off), roar (its alarm or challenge), attack (a snarl as it strikes; the
hunters), hurt, death.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "game", "Forest", "audio", "creatures", "v2")
KEY_FILE = os.path.join(ROOT, ".codex", "elevenlabs.key")
API = "https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128"

# Every prompt shares this: real animals in the wild, not a cartoon, no music.
STYLE = ", realistic animal vocalization, prehistoric wilderness, no music, no voice, no speech"
# species: {cue: (prompt, seconds, takes)}
VOICES = {
    "raptor": {
        "ambient": ("a velociraptor's short chirping clicks and a rasping trill, calling to its pack, from a little way off", 1.6, 3),
        "roar": ("a velociraptor's sharp raspy screech, alarmed", 1.4, 2),
        "attack": ("a velociraptor's hissing snarl as it lunges and snaps", 1.0, 2),
        "hurt": ("a raptor's sharp pained yelp", 0.8, 2),
        "death": ("a raptor's dying screech fading into a choked gurgle", 1.8, 1),
    },
    "rex": {
        "ambient": ("a tyrannosaurus rex's low rumbling growl, deep and resonant, distant", 2.5, 3),
        "roar": ("a massive tyrannosaurus rex roar, deep, long and terrifying, echoing", 3.0, 2),
        "attack": ("the heavy snapping bite and guttural growl of a huge predator", 1.3, 2),
        "hurt": ("a huge dinosaur's pained bellowing growl", 1.4, 2),
        "death": ("a giant tyrannosaurus's dying roar fading into a long rumbling groan", 3.5, 1),
    },
    "allo": {
        "ambient": ("an allosaurus's low rasping growl and huff, prowling", 2.0, 3),
        "roar": ("an allosaurus's rasping roar, harsh and menacing", 2.2, 2),
        "attack": ("an allosaurus's snarling bite and snap", 1.1, 2),
        "hurt": ("a large predator dinosaur's pained snarl", 1.0, 2),
        "death": ("an allosaurus's dying roar fading to a rattling breath", 2.6, 1),
    },
    "trike": {
        "ambient": ("a triceratops's low huffing bellow while grazing, calm", 2.0, 3),
        "roar": ("a triceratops's angry bellowing snort, a warning", 1.8, 2),
        "hurt": ("a triceratops's pained bellow", 1.2, 2),
        "death": ("a triceratops's long dying groan", 2.4, 1),
    },
    "stego": {
        "ambient": ("a stegosaurus's deep lowing grunt, calm and slow", 2.0, 3),
        "roar": ("a stegosaurus's loud warning bellow and snort", 1.8, 2),
        "hurt": ("a stegosaurus's pained grunting bellow", 1.2, 2),
        "death": ("a stegosaurus's long low dying groan", 2.4, 1),
    },
    "longneck": {
        "ambient": ("a brachiosaurus's long deep whale-like call, distant, echoing across a valley", 3.5, 3),
        "roar": ("a brachiosaurus's loud trumpeting call, alarmed", 2.6, 2),
        "hurt": ("a giant sauropod's deep pained moan", 1.8, 2),
        "death": ("a giant sauropod's long fading dying moan", 3.5, 1),
    },
    "parasaur": {
        "ambient": ("a parasaurolophus's low hollow horn-like call, resonant, distant", 2.8, 3),
        "roar": ("a parasaurolophus's loud honking alarm call, urgent", 1.8, 2),
        "hurt": ("a parasaurolophus's pained honk", 1.0, 2),
        "death": ("a parasaurolophus's fading mournful call", 2.4, 1),
    },
    "dodo": {
        "ambient": ("a dodo bird's soft cooing clucks and warbles", 1.4, 3),
        "roar": ("a dodo bird's startled squawk", 0.9, 2),
        "hurt": ("a dodo's pained squawk", 0.7, 2),
        "death": ("a dodo's last feeble squawk", 1.0, 1),
    },
    "lystro": {
        "ambient": ("a small stout reptile's grunting snuffles and squeaks, rooting in the dirt", 1.4, 3),
        "roar": ("a small reptile's startled squeal", 0.8, 2),
        "hurt": ("a small reptile's pained squeak", 0.6, 2),
        "death": ("a small reptile's fading squeal", 1.0, 1),
    },
    "compy": {
        "ambient": ("a compsognathus's tiny chittering chirps and twitters", 1.2, 3),
        "attack": ("a tiny dinosaur's high pitched hiss and snap", 0.7, 2),
        "hurt": ("a tiny dinosaur's squeak of pain", 0.5, 2),
        "death": ("a tiny dinosaur's last squeak", 0.7, 1),
    },
    "dimetrodon": {
        "ambient": ("a large lizard's low hiss and throaty rumble, basking", 2.0, 3),
        "roar": ("a dimetrodon's hissing bellow, a threat", 1.6, 2),
        "attack": ("a large reptile's hissing snapping bite", 1.0, 2),
        "hurt": ("a large reptile's pained hiss", 0.9, 2),
        "death": ("a large reptile's dying hiss fading out", 1.8, 1),
    },
    "proto": {
        "ambient": ("a protoceratops's short grunts and chirping squeaks", 1.4, 3),
        "roar": ("a protoceratops's alarmed squawking grunt", 1.0, 2),
        "hurt": ("a small horned dinosaur's pained squeal", 0.7, 2),
        "death": ("a small horned dinosaur's fading squeal", 1.2, 1),
    },
    "anky": {
        "ambient": ("an ankylosaurus's deep snorting grunts, slow and heavy", 1.8, 3),
        "roar": ("an ankylosaurus's heavy bellow and snort, a warning", 1.8, 2),
        "hurt": ("a heavy armored dinosaur's pained grunt", 1.0, 2),
        "death": ("an ankylosaurus's long low dying groan", 2.4, 1),
    },
    "carno": {
        "ambient": ("a carnotaurus's guttural bark and low growl", 1.8, 3),
        "roar": ("a carnotaurus's harsh bellowing roar", 2.2, 2),
        "attack": ("a carnotaurus's snapping snarling bite", 1.1, 2),
        "hurt": ("a big predator dinosaur's pained bark", 1.0, 2),
        "death": ("a carnotaurus's dying roar fading out", 2.6, 1),
    },
    "yuty": {
        "ambient": ("a feathered tyrannosaur's deep hooting growl, cold and distant", 2.4, 3),
        "roar": ("a huge feathered tyrannosaur's booming roar", 2.8, 2),
        "attack": ("a huge predator's snapping bite and growl", 1.2, 2),
        "hurt": ("a huge feathered dinosaur's pained bellow", 1.3, 2),
        "death": ("a huge feathered dinosaur's dying roar fading into a groan", 3.2, 1),
    },
    "utah": {
        "ambient": ("a large raptor's harsh clicking calls and low trill", 1.6, 3),
        "roar": ("a utahraptor's piercing harsh screech", 1.6, 2),
        "attack": ("a large raptor's snarling hissing lunge", 1.0, 2),
        "hurt": ("a large raptor's pained screech", 0.9, 2),
        "death": ("a large raptor's dying screech fading out", 1.8, 1),
    },
    "deino": {
        "ambient": ("a deinonychus's clicking hiss and soft trilling, hidden in reeds", 1.5, 3),
        "roar": ("a deinonychus's shrill warning shriek", 1.3, 2),
        "attack": ("a deinonychus's hissing snarl as it leaps", 0.9, 2),
        "hurt": ("a mid-sized raptor's pained yelp", 0.8, 2),
        "death": ("a mid-sized raptor's dying shriek", 1.6, 1),
    },
    "sucho": {
        "ambient": ("a crocodile-like dinosaur's deep rumbling growl and hiss by the water", 2.2, 3),
        "roar": ("a suchomimus's wet guttural roar", 2.2, 2),
        "attack": ("a crocodilian jaw snapping shut with a growl", 1.0, 2),
        "hurt": ("a large crocodilian dinosaur's pained growl", 1.0, 2),
        "death": ("a large crocodilian dinosaur's dying growl fading out", 2.4, 1),
    },
    "spino": {
        "ambient": ("a spinosaurus's deep wet rumbling growl from the swamp", 2.6, 3),
        "roar": ("a spinosaurus's huge wet bellowing roar", 3.0, 2),
        "attack": ("the snapping jaws and growl of a giant river predator", 1.3, 2),
        "hurt": ("a giant dinosaur's pained wet bellow", 1.4, 2),
        "death": ("a giant river dinosaur's dying bellow fading into a groan", 3.4, 1),
    },
    "ossuar": {
        "ambient": ("a giant skeletal beast's hollow rattling breath, bones clattering", 2.2, 2),
        "roar": ("a giant undead beast's hollow grinding roar, bones rattling", 3.0, 2),
        "hurt": ("bones cracking and a hollow pained groan", 1.2, 2),
        "death": ("a giant skeleton collapsing, bones clattering down, a last hollow groan", 3.5, 1),
    },
}


def key():
    k = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not k and os.path.exists(KEY_FILE):
        k = open(KEY_FILE, encoding="utf-8").read().strip()
    return k


def out_path(species, cue, n):
    return os.path.join(OUT, "%s-%s-%d.mp3" % (species, cue, n))


def plan(only=None, cues=None, force=False):
    todo = []
    for species, table in VOICES.items():
        if only and species not in only:
            continue
        for cue, (prompt, secs, takes) in table.items():
            if cues and cue not in cues:
                continue
            for n in range(1, takes + 1):
                if force or not os.path.exists(out_path(species, cue, n)):
                    todo.append((species, cue, n, prompt, secs))
    return todo


def make(k, species, cue, n, prompt, secs):
    body = json.dumps({"text": prompt + STYLE, "duration_seconds": max(0.5, min(22.0, secs)), "prompt_influence": 0.45}).encode()
    req = urllib.request.Request(API, data=body, method="POST", headers={"xi-api-key": k, "Content-Type": "application/json", "Accept": "audio/mpeg"})
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                data = resp.read()
            os.makedirs(OUT, exist_ok=True)
            open(out_path(species, cue, n), "wb").write(data)
            return True
        except urllib.error.HTTPError as e:
            detail = e.read()[:300].decode("utf-8", "replace")
            if e.code in (429, 500, 502, 503):
                time.sleep(4 + attempt * 6)
                continue
            print("  failed %s-%s-%d: HTTP %d %s" % (species, cue, n, e.code, detail))
            return False
        except urllib.error.URLError as e:
            time.sleep(4 + attempt * 6)
    return False


def main():
    only = cues = None
    if "--only" in sys.argv:
        only = sys.argv[sys.argv.index("--only") + 1].split(",")
    if "--cues" in sys.argv:
        cues = sys.argv[sys.argv.index("--cues") + 1].split(",")
    todo = plan(only, cues, "--force" in sys.argv)
    seconds = sum(t[4] for t in todo)
    print("%d sounds, %.0f seconds of audio" % (len(todo), seconds))
    if "--plan" in sys.argv:
        for t in todo:
            print("  %s-%s-%d  %.1fs  %s" % (t[0], t[1], t[2], t[4], t[3]))
        return
    k = key()
    if not k:
        sys.exit("No ElevenLabs key: set ELEVENLABS_API_KEY or put it in .codex/elevenlabs.key")
    made = 0
    for species, cue, n, prompt, secs in todo:
        if make(k, species, cue, n, prompt, secs):
            made += 1
            print("made %s-%s-%d" % (species, cue, n), flush=True)
    print("made %d of %d" % (made, len(todo)))


if __name__ == "__main__":
    main()
