# PixelLab — AI Sprite Generation for Cravera

[PixelLab](https://www.pixellab.ai) is wired in as an MCP server (`mcp__pixellab__*`). It generates
multi-directional pixel-art characters, animations, tilesets, objects and UI panels. This file is the
playbook for turning "I want a new character" into a creature the player can actually fight.

> **Prerequisite:** the tools are `mcp__pixellab__*`. If not loaded, fetch first:
> `ToolSearch("select:mcp__pixellab__create_character,mcp__pixellab__get_character,mcp__pixellab__animate_character")`.
> The server is HTTP-transport and connects at session start.

---

## 0. BUDGET GUARD — read this before generating anything

The account is on a **trial: 40 generations total**, and generations do not obviously map 1:1 to
tool calls. **Always call `get_balance` before a generation run, and tell the user the estimated
cost before spending more than ~5 generations.**

| Operation | Generations | Notes |
|---|---|---|
| `create_character` standard | **1** | 4 or 8 directions. The workhorse — use this by default. |
| `create_character` v3 | 2–9 | Highest quality, always 8-dir, accepts a reference image. |
| `create_character` **pro** | **20–40** | Half the trial budget in one call. **Never call without explicit user approval.** |
| `animate_character` template | **1 per direction** | 4-dir walk = 4 generations. Cheapest animation route. |
| `animate_character` v3 | ~1 per direction ≤96px | Scales with canvas×frames: 128px≈2/dir, 256px≈8/dir. |
| `animate_character` pro | 20–40 per direction | Effectively off-limits on trial. |
| `create_topdown_tileset` standard | **3–4** (mean 3.1) | *Not* 1 — six tilesets is ~18 generations, not 6. |
| `create_map_object`, `create_1_direction_object` | 20–40 | Expensive for what it is. |
| `create_ui_asset` | 20–40 | Expensive. |

**A fully animated 4-direction creature (idle + walk + bite + death) costs ~13 generations** — a
third of the trial budget. Quote that number to the user before starting, and confirm.

Failed jobs are not charged. `cancel_job` exists. `list_jobs` shows what is in flight.

### Two findings that only show up when you TEST, not when you look

**Judge every sprite on terrain at 1:1, never on a dark backdrop.** A raptor remapped to the
palette's foliage greens looked better in isolation and then *vanished* against grass. The browner
nearest-quantized version read better precisely because it contrasts with the ground. Readability
beats realism — render the candidate on a grass swatch at true game size before choosing.

**Generate at game size, not large.** At 96px wide the model spread detail into hollow 1px
wireframe legs and skulls; the same prompt at 48x32 forced solid mass and fixed it outright.
Bigger is not better here, and **img2img "refinement" of a weak base makes it worse** (murkier,
stray pixels, lower contrast) — regenerate at the right size instead.

---

## 1. The locked Cravera style contract

Cravera's visual rules (see `visual-pixel-art.md`) are non-negotiable, and PixelLab's parameters map
onto them directly. **Use these values on every `create_character` call** so the bestiary stays
cohesive:

```jsonc
{
  "n_directions": 4,              // Cravera is 4-dir facing; 8-dir quadruples cost for nothing
  "view": "low top-down",         // == the locked 3/4 view. NEVER "side" or "high top-down"
  "outline": "single color black outline",
  "shading": "basic shading",
  "detail": "medium detail",
  "size": 48                      // see sizing note below
}
```

Style params are **soft guidance** in standard mode and are **ignored entirely in pro mode** — which
is a second reason to avoid pro: it silently discards the style contract.

**Description prompt shape.** Lead with the creature, then colour, then two or three distinguishing
features. Keep it to physical appearance — no lighting, camera or environment words:

> `"small feathered raptor dinosaur, olive green scales with rust-orange stripes, alert yellow eye,
> sharp claws, standing on two legs"`

**Consistency across the bestiary.** The strongest lever is `style_character_id` (pro only) or v3's
`reference_image_url`. On the trial budget, the practical lever is the **master-palette quantize
gate** — which the importer runs automatically, and which is what actually makes different
generations look like one game.

### Sizing — the canvas is bigger than the art

`size` sets a target, not the output. A `size: 48` request came back on a **68×68 canvas** with the
actual raptor occupying only ~20×45 px. That is fine and expected: PixelLab pads to a square canvas
and pivot-centres the art in it.

- **Never rescale the sheet afterwards.** It is already 1 art-pixel per texture-pixel; resampling
  breaks the project's single-pixels-per-unit rule.
- Judge size by the *art* bbox, not the canvas. ~20×45 art px is a correctly-scaled small creature
  against the 480×270 native resolution.
- Ask for `size: 48` for normal creatures, `size: 64` for hero dinos. Max 128 (256 in v3).

### Body types — a real limitation for a dinosaur game

`body_type` is `humanoid` or `quadruped`, and **quadruped only accepts the templates
`bear`, `cat`, `dog`, `horse`, `lion`** — there is no dinosaur skeleton.

- **USE `quadruped` + `lion` FOR DINOSAURS — including bipedal ones.** This is the single most
  important finding in this file. `humanoid` produces an upright lizard-person and **no amount of
  prompting fixes it** (tested: a hard "hunched, horizontal spine, head low and forward" prompt
  still came back upright — the rig, not the prompt, is the constraint). The `lion` quadruped
  template gives a low horizontal body, a long tail, and a toothed reptilian head, which is what a
  theropod's top-down silhouette actually looks like. A raptor is bipedal and the template is not,
  but at 48px in top-down the horizontal posture matters far more than the leg count.
- The quadruped template also carries **animal-appropriate animations** — `attack`, `walk-4/6/8-frames`,
  `running-*`, `eating`, `idle`, `jump-attack` — instead of the humanoid list's `backflip`,
  `hurricane-kick` and `lead-jab`. `attack` maps straight onto Cravera's `bite_*`. There is no
  quadruped `death`; generate it with `mode="v3"`, `action_description="collapsing and falling
  over..."`, one direction (Cravera's `death` is directionless).
- **Quadruped dinos** (triceratops, ankylosaur): use `quadruped` with the nearest template — `bear`
  for bulky, `horse` for long-necked, `lion` for a prowling stance.
- For a silhouette the templates cannot reach, generate a single south-facing sprite by hand or with
  `create_image_pixflux`, then `create_character` with `mode: "v3"` + `reference_image_url` to rotate
  *that exact sprite* into 8 directions. This is the highest-fidelity route and worth its 2–9
  generations for a hero creature.

---

## 2. Animations — mapping PixelLab to Cravera's naming

Cravera's convention is `walk_<dir>`, `bite_<dir>`, `death`, with dirs `up/down/left/right`.
PixelLab uses compass directions and its own template names. The importer maps directions
automatically (`south→down`, `north→up`, `east→right`, `west→left`), reading the order from the
export's layout JSON rather than assuming it.

**Animation names need an explicit map**, because PixelLab's template library is built for
human action games — there is no "bite". Useful approximations from `available_animations`:

| Cravera | PixelLab template | via |
|---|---|---|
| `walk_*` | `walking-4-frames` / `walk` | `template_animation_id` — 1 gen/direction |
| `bite_*` | *(none suitable)* | `action_description: "lunging forward and biting"` (v3) |
| `death` | `falling-back-death` | `template_animation_id` |
| `hurt` | `taking-punch` | `template_animation_id`, or skip — the white hit-flash shader is cheaper and reads better (`visual-pixel-art.md` §7) |

Then rename at import time: `--map walking_4_frames=walk --map falling_back_death=death`.

**Skip `hurt` animations.** The hit-flash shader already covers damage feedback and costs zero
generations.

---

## 3. The end-to-end workflow

When the user says *"create a new character / creature"*:

**1 — Scaffold the game side first (free).** `mcp__godot_mcp__generate_creature(...)` writes the
CharacterBody2D scene, the FSM AI script, the `Data/creatures.json` entry and the biome spawn row.
Doing this first means the art has somewhere to land. See `mcp-workflow.md`.

**2 — Quote the cost.** `get_balance`, then tell the user what the sprite set will cost (§0) and
confirm before spending.

**3 — Generate the character.**
```
mcp__pixellab__create_character(description=..., name=..., n_directions=4,
    view="low top-down", outline="single color black outline",
    shading="basic shading", detail="medium detail", size=48)
```
Returns immediately with an id. Poll `get_character(character_id)` — expect ~2–3 minutes.
**Look at the result before spending more.** If the silhouette is wrong, fix it here; animating a
bad base multiplies the mistake by four.

**4 — Animate** (only after the base is approved) with `animate_character`, template mode where a
template fits. Poll `get_character` again; animations appear in its `animations:` list.

**5 — Import into the game.** `get_character` exposes a `spritesheet:` URL — a zip holding one
uniform-grid PNG plus a layout JSON, cells pivot-centred. Feed it straight to the importer:

```bash
python tools/pixellab_import.py <spritesheet-url-or-zip> --name Raptor --map walking_4_frames=walk
```

This downloads it, runs the **master-palette quantize gate**, writes
`game/Sprites/<Name>/<name>_sheet.png` + `<name>_frames.tres`, runs Godot's import pass, and
load-tests the resource headlessly. Set `PIXELLAB_API_KEY` for URL downloads and `GODOT` for the
verify step. Use `--skip-diagonals` on an 8-direction character.

**6 — Wire it up.** Point the creature scene's `AnimatedSprite2D.sprite_frames` at the generated
`.tres`. The animation names already match `play("walk_" + facing)`.

**7 — Test.** `mcp__godot_mcp__scan_project_for_errors()`, then run the scene and
`collect_runtime_logs()`.

---

## 4. Gotchas that will cost you a debugging session

- **A new PNG has no `.import` file, and the `.tres` will not load until Godot makes one.** The
  error is a misleading `No loader found for resource ... (expected type: Texture2D)`. Fix:
  `<godot> --headless --path game --import`. The importer does this automatically when it can find
  Godot; it prints the command when it cannot.
- **Godot is not on PATH on this machine.** It lives at
  `C:\Users\lorib\OneDrive\Desktop\Godot_v4.6.1-stable_win64.exe\Godot_v4.6.1-stable_win64.exe`
  — note the binary is *nested inside* a directory of the same name. `godot_mcp`'s
  `run_godot_scene` needs Godot on PATH, so it will not work until that is fixed; call the binary
  directly, or set `$GODOT`.
- **`pro` mode ignores every style parameter** and costs 20–40 generations. Two reasons to avoid it.
- **`size` is a hint; the canvas is padded and square.** Do not "fix" this by rescaling.
- **Quantizing drops colour count hard** (the validation raptor went 34 → 17 colours) and this is
  *desirable* — it is what pulls AI output into Cravera's palette. If a creature needs colours the
  master palette lacks, extend `art/palettes/cravera_master.hex` deliberately rather than bypassing
  the gate with `--no-quantize`.
- **Generated assets are PixelLab-hosted with expiring URLs** (`?t=` timestamps; map objects are
  auto-deleted after 8 hours). Import promptly; do not treat their CDN as storage.

---

## 4b. Skeleton animation — the route to real dinosaurs (v1 REST API)

**This is how you get a proper theropod.** The MCP `create_character`/`animate_character`
tools cannot: `humanoid` yields an upright lizard-person and the quadruped templates are
bear/cat/dog/horse/lion. PixelLab's **v1 REST API** exposes `/animate-with-skeleton`, which drives
generation from explicit pose keypoints — and *that* can express a hunched, horizontal-spine,
tail-out predator.

**The v1 API is a different surface from MCP but the SAME billing pool.** Verified: it authenticates
with the same bearer token and reports `usage: {type: "generations"}`, drawing down the same 40.
(`GET /v1/balance` reports USD credits and reads $0.00 — ignore it, it is a different counter.)

| Endpoint | Cost | Use |
|---|---|---|
| `POST /v1/estimate-skeleton` | **0.1** | Fit the 18-joint rig to an existing sprite. Cheap; use it to seed a pose. |
| `POST /v1/animate-with-skeleton` | **1.0** | Generate 3 frames from 3 pose keyframes. Synchronous — returns images, no polling. |

### What is and is not editable

The skeleton **topology is fixed**: 18 COCO-style joints in a hardcoded bone graph. You cannot add a
tail bone. What you *can* do is put those joints anywhere — and a dinosaur is really a humanoid rig
folded forward. `tools/pixellab_skeleton.py` encodes the retarget:

| Joint chain | Becomes |
|---|---|
| `NECK` | the pelvis / centre of mass (both limb chains hang off it) |
| `NOSE`→`EYE`→`EAR` | neck and skull, thrown **forward and level** |
| `HIP`→`KNEE`→`LEG` | the hind legs, under the body |
| `SHOULDER`→`ELBOW`→`ARM` | **the tail**, trailing back and up from the pelvis |

### Hard constraints (both cost a 422 to discover)

- **`skeleton_keypoints` must contain EXACTLY 3 frames.** It is a 3-frame window; build longer
  cycles by chaining calls with a sliding `--phase`.
- **The canvas must be exactly 16/32/64/128/256 square.** A `size=48` character export is 68x68 and
  is rejected. The tool re-centres the art on the next allowed canvas **by moving pixels, never
  resampling** — rescaling would break the one-pixel-per-unit rule.
- The **reference image must face the same way as `direction`**. Use `--cell-index` to pick the
  matching rotation out of the sheet (column order comes from the export's layout JSON).
- Pass **`color_image`** (the `--palette` flag, on by default) to force the master palette *during*
  generation. Without it the raptor test drifted noticeably teal; with it, output came back on-palette.

### Workflow

```bash
# 1. free — check the pose before spending anything
python tools/pixellab_skeleton.py preview --pose bite --frames 3     --reference game/Sprites/Raptor/raptor_sheet.png --cell 68 --cell-index 2 --out check.png

# 2. 1.0 generation — generate 3 frames
python tools/pixellab_skeleton.py animate --pose bite --direction east --view side     --reference game/Sprites/Raptor/raptor_sheet.png --cell 68 --cell-index 2 --out-dir out/
```

Poses live in `theropod_pose()` as offsets layered onto a `THEROPOD_REST` dict — `walk`, `bite`,
`idle`, `death`. **Always run `preview` first**; it is free and catches a bad pose before it costs a
generation. Tune the rest pose or the per-action offsets rather than hand-authoring frames.

### The Aseprite extension

The PixelLab Aseprite extension is **already installed** at
`%APPDATA%\Aseprite\extensions\pixellab` (Aseprite itself is the Steam build at
`C:\Program Files (x86)\Steam\steamapps\common\Aseprite\Aseprite.exe`). It shares the same
account, the same generation pool, and the same asset database — characters made via MCP appear in
its gallery and vice versa, and deletions propagate both ways.

Its **Skeleton Animation** tool is the GUI for posing a rig by hand; "Export skeleton for API" writes
`{"pose_keypoints": [[{label,x,y,z_index}, ...], ...]}` with x/y normalised over the canvas — the
same format `pixellab_skeleton.py` generates programmatically. So the two are interchangeable: pose
by hand in Aseprite when a motion needs an artist's eye, or generate poses in code when it needs to
be repeatable across a bestiary. Note the extension's Lua errors if invoked headlessly (it builds a
GUI dialog), so drive Aseprite's plugin interactively, not from the CLI.

---

## 5. Beyond characters

| Need | Tool | Cost |
|---|---|---|
| Biome terrain + transitions | `create_topdown_tileset(lower_description, upper_description, tile_size={"width":16,"height":16}, view="high top-down")` | 3–4 |
| Chain a second tileset to an existing biome | same, with `lower_base_tile_id` from the first tileset | 3–4 |
| World props (rocks, bones, bushes) | `create_map_object(description, width, height, view="high top-down")` | 20–40 |
| Item icons | `create_image_pixflux` then quantize | cheap |
| Force existing frames onto one palette | `reduce_colors(image_urls=[...], palette_image_url=...)` | — |

Tilesets are the best value on the list: 3–4 generations for a full Wang autotile set feeding
Godot's Terrain Sets (see `world-generation.md` and `visual-pixel-art.md` §3). Request
**16×16** tiles and `view: "high top-down"` for ground terrain — ground reads better straight-down
even though creatures are 3/4.

Everything from these tools still goes through the quantize gate:
`python tools/quantize_to_palette.py <png> --out-dir <dest>`.
