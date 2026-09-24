# Dinosaurs v2 — animation, moves and behaviour (pass 9)

The forest dinosaurs (rex, raptor, stego, trike, longneck, dodo) keep their original drawings but
every clip is new: PixelLab animated each species' own drawing per facing, a cleaning pipeline
locks it back to the species palette, and the game drives clips from a catalogue. Read this before
touching creature art, attacks, AI or mounts.

## Runtime (all in `game/Forest/creatures/`)
| File | Role |
|---|---|
| `DinoArt.gd` | Loads `art/v2/<key>/<clip>_<facing>.png` strips + the catalogue `art/v2/<key>.json` (`frames, fps, loop, hit, takeoff, seat, swing`) into one shared SpriteFrames per key (`<clip>_<facing>`, facing side/down/up, left = side flipped). Keys: species + `stego_saddle`/`trike_saddle`. `hit_time()` = contact frame, `sprite_offset()` stands the canvas ground row on the creature's feet. A clip may exist in only some facings (catalogue `views`, e.g. `tail_swing_far` is side-on only): `has_view()`. |
| `DinoMoves.gd` | Every species' attacks as data (`MOVES`) + the runtime: kinds `strike` / `charge` (wind-up clip, lane locked 0.22 s before the dash) / `pounce` (leap onto the prey's spot at take-off); shapes `jaws` (cone), `tail` (arc from the rear out to the aim's side — the body keeps its facing, pivoting side-on only for a target dead ahead), `ring` (stomp in front), `body` (charging body), `claws` (landing). Damage = `stats.damage × dmg`, shove = `knock × MASS[victim]`. Wild blows hit the keeper + companions (and the target); companions never hit friends. `telegraph()` feeds the faint ground lane/ring. Rider strikes: `MOUNT_MOVE`, `MOUNT_DAMAGE`, played faster so contact lands 0.3 s after the click. `strike_clip` is the clip a move actually plays: a side-on tail sweep at a target up the screen (`aim.y < -0.25`) plays `<clip>_far` (the tail swings away, behind the body); below or behind, the near sweep (toward the viewer). Front/back sweeps are mirrored toward the aim instead (`flip_override`, catalogue `swing`). `start()` turns before it plays, since a clip may lack the old facing. A tail sweep is an attack, not a turn: `_end_tail_turn()` gives the body back the facing it began in once the tail is back, even after pivoting side-on for a target straight ahead. **Rider charge:** `start(m, null, aim, hold=true)` on a `charge` move keeps the wind-up going while the rider holds the button (`_tick_hold`: the pawing half of the clip loops, dust thumps build, a thud at full), `steer_hold()` follows the mouse, and `release_hold()` stomps (`_stomp_fx`) and rushes `distance × lerp(0.6, 1.25, charge)` for `MOUNT_RAM_DAMAGE × lerp(0.55, 1, charge)`. The ground lane is shown to the rider while holding. **Bleed:** a move with `bleed` (the stego's tail: 0.25 of the blow per second for 4 s) calls `victim.apply_bleed()`. |
| `ForestCreature.gd` | Body + brain. `BODY` per species: accel (heavy bodies build/shed speed slowly), walk/run stride speeds (walk/run `speed_scale` follows real speed → no foot sliding), `run_at`, `armour` (heavy bodies keep attacking through hits; light ones flinch and lose a wind-up), idle clip. Wild: herbivores graze and drift toward their herd, look up at a close keeper, a trike paws the ground at a sprinting one (warning only); dodos bolt from a rushing keeper and peck when cornered; raptors hunting the same prey take alternating flanks (`_pack_side`), pounce from mid range, slash and dart back out, circle at 46–62 px while moves cool down and never stack (`_pack_spread`); a hurt raptor calls its pack, a hurt herbivore brings its herd round, a startled dodo scatters the flock (`_rally`); the rex roars when it locks on, stalks, charges from mid range, bites/chomps close. Heavy walkers thud (tiny camera shake, dust, sound). `take_damage(amount, source, knockback := -1)`; `_die()` plays the fall, holds, fades. |
| `MountedAppearance.gd` | Ridden composites: saddled clips (`MOUNT_CLIPS`, incl. the stego's `tail_swing_far`) with the Keeper rig rider on each frame's tracked seat (`hip()`), canvas + `TOP` rows for the head; `rider_offset()` places the real (hidden) player node. Facings a clip lacks are skipped. |
| `MountController.gd` | Riding input. Rider strikes go through `DinoMoves` (`_strike_time` mirrors them). `mount_press` / `mount_release`: the stego sweeps on press; the trike gores on a click, and held past `HOLD_TO_CHARGE` (0.2 s) it winds up the ram, which goes on release (a missed release is caught by polling the button, except headless). Riding takes the keeper off every physics layer, so `DroppedItem` also collects anything within the mount's radius + 10 px of its feet. |
| `Forest/combat/Bleed.gd` | Damage over time for creatures and the keeper. One bleed per body: a fresh cut refreshes the time and keeps the stronger rate. It ignores armour; ticks drain health with no shove, flinch or new target; blood drips from the wound onto a fading ground spot. The HUD shows "BLEEDING Ns"; a creature's bar gets a red drop. |

Worker strikes use the species' attack clip on its contact frame (the stego turns its back to the
tree and fells it with the tail; the trike gores bushes).

## Art pipeline (`tools/dino/`, cost ≈ 1–2 generations per clip)
1. `prepare.py` → `art/dino-v2/{palettes,base,first}`: one ~64-colour palette per species (the
   originals carry thousands of near-identical shades), palette-snapped drawings, and each drawing on
   its species canvas with feet on row `H-7` (`CANVAS` leaves room for sweeps, rearing, leaps).
2. `clips.json` — the spec: per key its clips, per clip model/frames/fps/loop/clean options/motion.
3. `gen.py run` — submits (≤7 in flight; PixelLab caps an account at 8), ledgers every job
   (`art/dino-v2/ledger/<key>.json`, never pays twice), downloads raw frames, scores them
   (`effect_score`: extra near-white pixels, silhouette area/width growth), **auto-retries flagged
   clips with a new seed (up to `MAX_ATTEMPTS`) and keeps the least-bad attempt**, cleans
   (`clean.py`: palette snap, binary alpha, drop islands not touching the body, ground/anchor
   alignment, `clamp_top` for loops, frame 0 = the untouched drawing, pinned loop frame dropped).
   `gen.py qa` lists suspect clips; `requeue --only …` / `redo KEY/CLIP_VIEW --motion "…" --model pmm`
   remake them. `peek.py KEY clips views` makes review strips; `pixellab_mcp.py` is the file-based client.
4. `export.py` → game strips + catalogue; contact/take-off frames **per facing** (`hit_view`,
   `takeoff_view` — each facing was animated separately) from `hits.json`, set by eye on
   `peek.py --numbers` strips (the auto-guess, "most extended pose", is only a fallback and is wrong
   for leaps); saddle seat tracking. For front/back tail sweeps, `swing` records the side the tail
   is out on **at the contact frame**. Back views often sweep one way and then the other, and taking
   the widest reach anywhere once baked "right" for a contact pose out on the left, which mirrored
   the blow away from the target.
   - `tail_front.py KEY` builds the **front-view tail sweep procedurally** (front idle body + the
     spiked tail tip cut from the side drawing, swung out from behind the body and back): the models
     always turned the whole animal side-on for it, which is exactly what the design forbids.
   - `tail_side.py KEY [--near] [--far]` builds **side-view tail sweeps procedurally**: the side
     drawing's body stays still while its tail (cut at the hips, `CUT`) bends about its root, from
     nothing at the hips to the full angle at the tip, so the root stays attached and the spiked end
     leads. It is drawn from a Scale2x-upsampled copy and splatted forward with a per-pixel colour
     vote, so every colour is the drawing's own. `near` = `tail_swing_side` (down the screen, in
     front of the body), `far` = `tail_swing_far_side` (up the screen, behind). The models always
     turned the stego round, smeared the tail into flame or curled it into a glowing crescent. True
     foreshortening read as the tail retracting, so the tail keeps (and briefly exceeds) its length.
     Stego and stego_saddle use both; the longneck keeps its AI near sweep (its tail wraps in front
     of its legs) and gets the far one at a lower angle (`SWING_KEY`, since its curled tail hooks).
   - `walk_back.py KEY [--run]` builds **back-view (walking away) locomotion** from the resting back drawing. The hind legs are two columns at the bottom sides, with the tail between them (`RIG` boxes per key). They lift in turn (2 px walking, 3 running) and never leave their columns. The body dips on each footfall; the planted leg stretches by the bob so it never tears from the rump; the tail sways against the step. Used for the stego and trike (and saddled) walk_up and the trike run_up: the models' back walks splayed the hind legs out sideways.
   - **Back views stand on their feet:** prepare.py stood each drawing's lowest pixel on the ground line, and from behind that is the tail tip hanging toward the viewer. `export.py` `VIEW_DROP` drops every up strip (rex 6, stego 6, trike 4, raptor 4, longneck 4 px) so the hind feet meet the shadow, and moves the up `origin` by the same amount so riders stay on the saddle.
   - `cap_clamp.py KEY CLIP_VIEW… [--tol N | --cap ROWS]` removes growths out of the top of a
     front/back loop that `clamp_top` only caps. It follows each frame's bob (frill and face band)
     and either clears everything above the resting per-column top, or (`--cap`, for a growth
     standing inside that profile) replaces the top rows with the resting drawing's. Front views
     of the trike were the problem: the saddled walk grew a post from the saddle's cantle
     (`--cap 6`) and the saddled run a smear over the frill (`--tol 1`); the wild idle and run
     flicked the tail up behind the horn and the wild eat stretched the horn into a spike
     (`--cap 6`); the longneck's front idle flared its back spikes out like wings (`--tol 1`).
     Pieces the clearing cuts loose (under 25 px, more than 2 px off the body: clean.py's island
     rule) are dropped. The QA scores miss thin growths, so check front/back loops by eye for
     anything above the resting top.
   - A procedural or post-fixed clip carries `method` in its ledger entry, so `gen.py clean` leaves
     it alone. In `clips.json`, `procedural` clips get no generation jobs, and `views` limits a clip
     to some facings.
   - `clips.json` `overrides` give one KEY/CLIP_VIEW its own model/motion; `gen.py run` re-reads the
     spec every round, so edits apply without a restart.
5. `godot --headless --import`, then `Tests/DinoV2Suite.tscn` and `Tests/DinoCapture.tscn`.

### Prompt lessons (each cost real generations)
- **Short, motion-only prompts.** The model sees the drawing. Naming the body ("crystal spikes"),
  listing effects to avoid, or words like *breathing / struck / snorts / slams* made it paint steam,
  sparkles, flame columns, hit flashes and dust. Good: "Swings its spiked tail out to the side in a
  wide fast sweep, then brings it back behind it. Its body and feet stay still. It stays in place,
  facing away from the viewer."
- `animate_image_pixminimax` ("pmm") is cleaner and livelier than `animate_image` for almost
  everything; loops pin `last_frame` to the first frame so the cycle closes.
- Front/back views drift: crests grow into pillars, attacks turn side-on. The QA flags catch most;
  "hunched with its head held low" fixed the rex's front walk.

## Tests
- `Tests/DinoV2Suite.tscn` (headless): catalogue for all keys/clips/facings (side-only clips
  absent elsewhere; each front/back sweep's contact pose on its baked `swing` side), side-on sweeps
  choosing near/far by the target's side for stego, longneck and stego_saddle facing both ways, every strike's
  telegraph → contact → damage → shove → once, tail arc sides, stomp ring, charge lanes (incl. a wall
  bonk), pounce landing, who can be hit, dodo flee/peck, flinch vs armour, speed-matched walking,
  death, rider seat tracking. Step moves with position integration (`advance_move`): many
  `move_and_slide()` calls inside one frame do not advance like real frames.
- `Tests/DinoCapture.tscn` (rendered): every species/move in the real forest → `art/dino-v2/world/`
  (tail sweepers twice: a target below the rear and one above it).
- `Tests/DinoBehaviourCapture.tscn` (rendered): raptor pack, rex roar/charge, herd defence, dodo
  scatter around an invulnerable keeper, with per-creature state logs and checks.
- Knockback lives in `_knock`, layered on the steering velocity (`_move_velocity`) each frame and
  never folded into it — folding it in once compounded a shove to ~700 px/s. External code halts a
  creature with `stop()`.
- Older suites updated for v2: creatures (clip catalogue), ai-pass2 (telegraphed pacing),
  workers-pass6 (tail-first felling), mount-pass4 / render QA (composite size, strike clips, tail arc;
  a ridden far-side sweep baked with the rider, side-on only).
