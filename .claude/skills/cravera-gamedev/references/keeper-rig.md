# Keeper v2 — the player character rig (pass 8)

The player ("the Keeper") is rendered by a **skeletal pixel rig**, not painted sprite sheets.
Read this before touching the player's look, armour, animations, held items or mounted rider.

## Why it exists
Pass 7 painted armour onto finished 64px frames at *auto-detected* anchors
(`pose_anchors.json`). The detector recorded cel-trim offsets such as `run_left body (-34,-10)`,
so chest and leg armour slid off the body (or vanished) while running left/right/up. The rig
removes the whole class of bug: armour pieces *are* body parts hanging off the same joints, so
they cannot drift in any clip, facing, action or mounted pose. `Tests/keeper_rig_pass8.gd`
proves it for every set × slot × clip × facing × frame.

## Anatomy (all in `res://Forest/keeper/`)
| File | Role |
|---|---|
| `KeeperRig.gd` | Renders one 64×64 cel from a pose. Head + torso are **sprites**; arms/legs are **rasterised capsules** (2-bone IK) coloured from 5-shade ramps `[deep,dark,mid,light,highlight]`; hands are discs; boots, shoulder guards and held tools are sprites stamped at joints. Views `down`/`up`/`side` (side = facing right; left = whole-cel `flip_x`). Draw order `ORDER` + keyframe-selectable `ORDER_EXTRA`. Lossless quarter-turns (`rot`) for falls/rolls; independent head glances (`head_view`/`head_flip`). |
| `KeeperParts.gd` | Loads `art/rig.json` (rest skeleton, metrics, ramps, part origins, sets, hair styles) and builds a **look** for an armour combo + appearance. Appearance recolours use `*.mat.png` masks (R = material id, G = shade rank, B = shade count). |
| `KeeperMotion.gd` + `motions/*.gd` | Clip catalogue. Locomotion (idle/walk/run) is procedural; every other clip is **joint keyframes per view** (field reference in the header: `b hip hd hm ho ho_grip fm fo ta tl em eo km ko blink rot order hv hf`). `held_rule(kind)`: `"held"` = selected hotbar item, a fixed prop id (net, garden_hoe, fishing_rod, reed_bow, bucket, stone_hammer), or none. `pose(kind, facing, i, seated)` — `seated` swaps in the riding legs for mounted actions. |
| `KeeperSkin.gd` | SpriteFrames builder with the old `EquipmentSkin` API (`build(source, armor, light, appearance[, held_id])`, `pose(anim, frame)` → hand/offhand/tool_angle/tool_layer/tip). Static shared part data; LRU cache of 4 outfits; renders side cels once and mirrors them for left. `base_frames()` = every clip × 4 facings (the player's `_base_frames`). `EquipmentSkin.gd` is now a one-line alias of this. |
| `KeeperTools.gd` | Held-item sprites (`art/held/<id>.png` + `<id>.json` grip/angle/hang), RotSprite-style rotation (3× Scale2x → nearest rotate → centre sample) cached per 15°, `frame_mirrored`, `reach` (grip→tip distance for fishing line / bowstring). |
| `KeeperHeld.gd` | Two overlay nodes under the player's AnimatedSprite2D (back layer via `show_behind_parent`, front layer with the fist re-stamped over the handle). They draw the **selected hotbar item** in lockstep (`frame_changed`/`animation_changed`) for clips whose rule is `"held"`, so switching tools never rebuilds the outfit. Fixed-prop clips bake the prop into the cels instead. |

Gameplay contract kept: clip names `<kind>_<down|up|left|right>`; tool clips 8 frames with the
contact pose on **frame 4** (ToolAttack resolves hits at `duration × contact_ratio`); durations =
`ActionFrames.DURATIONS`; `bow_draw` holds frame 7; `fishing_reel` loops; `death_<facing>` is
one-shot and ends lying down; the `ride` pose puts the hips on cel (32,39) (MountedAppearance's
saddle contract); cel (32,32) = player origin; soles on cel row 43 (local +11).

## Art pipeline (tools/keeper/)
1. **Base hero**: PixelLab `create_character_pro_flash` 32×32, low top-down, style image = a 32×32
   crop of the lush forest world (keeps palette/outline in family). Character id
   `4664c6a4-6dcf-494b-8904-7d39a2afd9cc`; sources in `art/keeper-v2/source/base_*.png`.
2. **Armour sets / hair styles**: PixelLab `create_character_state` on that character ("same hero,
   same standing pose with arms held slightly away from the body, now wearing …"). The state keeps
   the body pixel-aligned with the base, so one set of region rules cuts every outfit. 20–40
   generations each. Download: `python tools/keeper/pl_fetch.py character <id> art/keeper-v2/source/<set>`.
3. `python tools/keeper/extract_parts.py <base|setid> --name "…"` → `game/Forest/keeper/art/{base,sets/<id>}/`
   (head/torso/boot/pauldron PNG + `.mat.png` + `set.json` with limb ramps). Per-set hand fixes live in
   `art/keeper-v2/source/<set>/overrides.json`.
4. `python tools/keeper/build_rig.py` → `art/rig.json` (REST skeleton, METRICS, ramps, appearance ramps,
   parts, sets, hair styles).
5. Held props: PixelLab `create_image_pixen` 16×16 (1 generation), diagonal grip-bottom-left
   convention; `python tools/keeper/import_held.py`. Download raw-image jobs with
   `pl_fetch.py image <job_id> out.png` (the `/mcp/images/<job>/download` route; Cloudflare needs a
   browser User-Agent).

## Adding things
- **New armour set**: generate a state → download → `extract_parts.py <id>` → `build_rig.py` → add
  `<id>_helmet/_chestplate/_leggings.tres` (+ icons in `Forest/equipment/art/wardrobe/icons/`, recipes)
  → the rig picks it up automatically (visual set = item id prefix, or `Item.visual_set`). Run
  `Tests/keeper_rig_pass8.gd`.
- **New clip**: add keyframes to a `motions/*.gd` table (8 frames, contact on 4 for hits), a duration
  to `ActionFrames.DURATIONS`, then `player.play_action(kind, target)`.
- **New held prop**: sprite + `import_held.py`; set the clip's `"hold"` or rely on `"held"`.

## Review loop (always look at the pixels)
- Sheets: `bash tools/keeper/godot.sh --headless --quit-after 900 --script res://Tests/keeper_preview.gd -- --no-save-playtest --clips idle,walk,axe --armor moss,moss,moss --held basic_axe --out name`
  → `art/keeper-v2/review/name.png` (options `--look skin,hair,style,cloth,trousers`, `--seated`, `--facings`).
- In-world (window): `res://Tests/KeeperWorldCapture.tscn`, `res://Tests/KeeperMountCapture.tscn`
  (`--rendering-method gl_compatibility --resolution 960x540 … -- --no-save-playtest`) → `art/keeper-v2/world/`.
- Regression: `Tests/keeper_rig_pass8.gd` (headless `--script`, ~25 s).

## Gotchas
- A subclass-free constant named like a native class (`const Skin = …`) fails to parse in 4.6 — use `KeeperSkinScript`.
- GDScript type inference fails on `var x := someArray[i]` and on `Resource.duplicate()` results — annotate (`var img: Image = src.duplicate()`).
- PixelLab: max 8 concurrent jobs per account; failed jobs return 410 on download and are not charged.
- Rebuild cost ≈ 0.25 s per outfit (≈770 cels). Journey load batches rebuilds via `begin_skin_batch()/end_skin_batch()`.
