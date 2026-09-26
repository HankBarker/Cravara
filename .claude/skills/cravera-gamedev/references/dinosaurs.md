# Dinosaurs v2 — animation, moves and behaviour (passes 9–10)

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
3. `gen.py run` — submits (≤7 in flight by default, `--inflight 8` when nothing else generates;
   PixelLab caps an account at 8; a restart resumes the ledger's in-flight jobs), ledgers every job
   (`art/dino-v2/ledger/<key>.json`, never pays twice), downloads raw frames, scores them
   (`effect_score`: extra near-white pixels beyond 30 + a quarter of the drawing's own, so a pale
   beast like the white Ashmane isn't flagged for its coat; silhouette area/width growth), **auto-retries flagged
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
     Pass 12 (the ankylosaur, whose generated sweeps grew a giant sausage, a fan and a log):
     `--view up` builds the back sweep (the tail hanging toward the viewer, swung out in front of
     the body); `--hip ROW` sets the row it turns about; `--hide x0,y0,x1,y1` takes the resting
     tail out of the body frames once the swing is under way (a club that shows at rest: over
     the rump from the front, below the hips from behind; box the whole bob); `--tip-boxes`
     picks the tail from the side drawing by boxes where a column cut would take body too. Anky:
     `--tip-boxes "28,44,38,60;30,56,46,68" --hip 42 --reach 20 --hide 53,26,67,40` (down) and
     `--view up ... --hip 68 --hide 48,71,62,83`, then drop 1-3 px specks.
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
     The ankylosaur (pass 12) keeps its AI near sweep and gets the far one (`CUT` 39: its drawing
     pitches forward, the club up behind the hips).
   - `walk_back.py KEY [--run]` builds **back-view (walking away) locomotion** from the resting back drawing. The hind legs are two columns at the bottom sides, with the tail between them (`RIG` boxes per key). They lift in turn (2 px walking, 3 running) and never leave their columns. The body dips on each footfall; the planted leg stretches by the bob so it never tears from the rump; the tail sways against the step. Used for the stego and trike (and saddled) walk_up and the trike run_up: the models' back walks splayed the hind legs out sideways. Pass 12: the Ashmane's run_up (its model run away turned the whole animal round); a tail that curls up over the back rides with the body (an empty tail box).
   - **Back views stand on their feet:** prepare.py stood each drawing's lowest pixel on the ground line, and from behind that is the tail tip hanging toward the viewer. `export.py` `VIEW_DROP` drops every up strip (rex 6, stego 6, trike 4, raptor 4, longneck 4, anky 6 px: its club hangs 10 below its feet, capped by the canvas) so the hind feet meet the shadow, and moves the up `origin` by the same amount so riders stay on the saddle.
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
5. `stride.py KEY [CLIP …]` measures how fast a walk or run clip's planted feet drift under the
   body (px/s): `ForestCreature.BODY[KEY].walk/.run`, the speed at which the feet don't slide. It
   matched the tuned stego and trike walks, the allo and rex runs and the Blender carno's exact 30.
   Hunters' runs sit higher on purpose (the run clip plays at most 2.4x, so it suggests
   `chase / 2.4` when that's more). A sprawling gait whose feet step in place (the dimetrodon's
   walk) reads near zero: keep a sensible value there.
6. `godot --headless --import`, then `Tests/DinoV2Suite.tscn` and `Tests/DinoCapture.tscn`.

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
- **Back-view displays turn the animal round** (pass 13): screeches, roars, eats and chomps from
  behind came back showing the open jaws to the viewer, side-on, or with the tail reared into a pale
  spike (deinonychus threat, Suchomimus roar/eat/chomp). The QA scores don't see facing: check every
  `_up` action by eye. What worked: `"Keeps its back to the viewer the whole time: ..."` on the
  steady `ai` model for small motions (deino threat_up, sucho eat_up; 12-frame ai clips cost 3), the
  rex's "lunges forward away from the viewer..." on pmm for bites; and when the model insists,
  `lift_back.py` (below). A front slash drew a dark swoosh (utah): "rakes both clawed hands down"
  fixed it; a white burst on a snap (sucho bite_down) was replaced by holding the closed-jaw frame.
- `lift_back.py KEY CLIP --hip ROW [--lift PX]`: a back-view roar/threat from the back idle loop,
  everything above the hips lifted by a rise-hold-settle curve with the leg tops stretched (negative
  `--lift` dips, for eating). The Suchomimus roar_up (`--hip 91 --lift 4`).
- Run-loop hygiene: `gen.py redo` while `gen.py run` is going is safe only when that key has no job
  the loop could collect in the same round (it saves its round-start copy of the ledger); a job stuck
  at "processing 95%" for half an hour is cancelled with PixelLab `cancel_job` (frees the slot) and
  redone. When a clip runs out of attempts the loop keeps the *least-bad by score* attempt, which
  can bring back an old wrong-facing one: look at `kept_attempt` in the ledger.
- Frame time: the machine varies more than the builds (pass 12 and pass 13 both 10-15 ms one
  morning, 15-45 ms that evening). Judge a change with `Tests/PerfProbe.tscn` on both builds back to
  back (the previous commit in a `git worktree`, imported once), and `Tests/PerfSplit.tscn --at dunes
  --all-species` for each species' share against a fresh baseline.
- Exports: `export.py KEY` writes the catalogue (`art/v2/KEY.json`) that `DinoArt.has_key` reads, so
  the game spawns the species at once; never leave a catalogue in place without `--import` while
  suites run (they'd load unimported strips). Pass-13 strides: utah walk 22, deino 16/44, sucho 28.

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
- `Tests/Beasts12Capture.tscn` (rendered, pass 12): the new beasts posed in their own ground
  (`place()` stops physics and sets the facing and idle clip; wandering spoiled the shots), then
  let walk → `art/pass12/beasts-*.png`: the dunes (dimetrodon, protoceratops herd, ankylosaur,
  compy swarm), Dune raptors, the Pale Lands (the Ashmane and Ashfang raptors), the Ashmane
  roaring front-on. A species without exported art is skipped.
- The creatures suite checks only the side view for a side-on species (the compy; `DinoArt.has_view`).
- Knockback lives in `_knock`, layered on the steering velocity (`_move_velocity`) each frame and
  never folded into it — folding it in once compounded a shove to ~700 px/s. External code halts a
  creature with `stop()`.
- Older suites updated for v2: creatures (clip catalogue), ai-pass2 (telegraphed pacing),
  workers-pass6 (tail-first felling), mount-pass4 / render QA (composite size, strike clips, tail arc;
  a ridden far-side sweep baked with the rider, side-on only).

## Pass 10: new beasts, patient taming, hunting, the first boss
**Species** (`ForestCreature.SPECIES`/`BODY`, `DinoMoves.MOVES`/`MASS`, art keys of the same name):
- `allo`, Rustback Allosaurus: the mid predator between raptor and rex (hp 170, speed 47, dmg 15,
  bite + chomp, roars as it locks on). Its drops (`trex_scale` ×3) are the armour material; it
  roams the south and west of the forest alone and hunts the Bonelands.
- `lystro`, Mossback Lystrosaurus: a small easy tame like the dodo (feeds 2, pecks when cornered,
  flees hunters and rushing keepers).
- `alpha`, "Skarn, the Shardback Alpha": the first boss (hp 560, speed 56, slash + a 40–150 px
  pounce, `feeds 0`, `boss: true`). See `AlphaBoss.gd` below.
- `rex`: only **one** per world, and a mini-boss (hp 650, dmg 30, 40 feeds): not meant to be killed
  on foot in the first region without companions and a bow.

**Patient taming** (`_tick_patience`, `interact`): dodo and lystro (`EASY`) take 2 feeds. The rest
take `stats.feeds` (15–40) and need patience: after each feed the beast won't eat again until
the keeper has backed off to `SPACE × 1.5` (46 px) and `settle` (6 s) has run down. Standing within
`SPACE` of an unsettled beast builds `unease`; after `UNEASE` (3.5 s) it lashes out, loses 2 trust
and is provoked for 4 s. `FEED_WAIT` spaces the feeds. **Nets** (`net`): raptor, allo, rex are
knocked **down** for `NET_TIME` s (the death clip held as a downed pose; getting up plays it
backwards at speed 2.4, `_action "rise"`); only a netted predator eats from the hand.

**Hunting** (`_wild_target`): the keeper and companions within reach (105 px; rex and alpha
145), prey (`PREY`) out to the hunting range (160 px). Raptors take stego and trike (`PACK_PREY`)
only as a pack of 3+ (`_pack_size` within 150 px). After a kill (`on_kill`) a hunter is `sated`
for 90–150 s; the rex never is. Dodos and lystros run from any hunter coming for them
(`_hunter_near`). Predators don't herd. Tests call `_wild_target()` and `_hunter_near()` directly,
so those stay pure; the per-tick code uses the throttled `_current_target()`/`_hunter_nearby()`.

**Wildlife placement** (`ForestPlaytest.WILDLIFE`, `BONELANDS_LIFE`): each new world places its
groups from its own seed (arcs and distances from camp: flocks close, herds further, raptor packs
north-east, allosaurs south and west, the rex far south-east). The Bonelands get allosaurs,
lystros, a raptor pack and stegos; a journey saved before them gains them once (`regions`).

**The boss** (`creatures/AlphaBoss.gd`, a node in the session, group `alpha_boss`): `prepare()`
finds a dry den away from ruins in the north-east (`DEN_NEAR`), clears brush into `world.mined`,
lays a dirt floor and bone piles, and raises Skarn dormant. Stepping within `WAKE` (7 cells) or
hitting it: roar, screen shake, the boss music (`audio/boss-echoes.mp3`, a stand-in: Hank's own
"Travel Music (Cave)"), `hud.show_boss(name, fraction)`. Below 60% it howls for two raptors; below
30% it enrages (`haste 1.3`: speed and move cooldowns). Past `LEASH` (17 cells) or if the keeper
falls it goes back to sleep, healed. Beaten: milestone `alpha`, a banner and `alpha_crest`
("Skarn's Crest", trinket, +3 damage) plus 6 raptor fangs. Saves skip the alpha; the den raises
it again on load (`prepare()` at the end of `_load_journey`).

**Audio**: roars (`<species>-roar.ogg`, rex/allo/alpha, from `tools/build_creature_audio.py`) play
through `play_action("roar")`; a species without one roars with its attack call. Footsteps come
from `STEPS` (`[volume, pitch, shake, shake_max, range]`): the rex shakes the camera a little.

**New-species art** (`tools/dino/new_species.py`): `restyle KEY --from SP --view down|side|up`
(pixflux img2img from an existing species' drawing, `--palette` locks colours: the allo came out
green like the rex until a rust palette was forced), `rotate`, `drawings KEY --frame W H`. Build
each facing from its own restyle: `create_character` v3 rotation turned the alpha into an iguana.
`prepare.py [species]` takes a filter. Every clip's motion text must resolve for the species'
kind: gen.py stops at "no motion for KEY/CLIP" (the lystro's `run` needed its own quadruped line).
A facing whose clip fails QA after `MAX_ATTEMPTS` is exported from the resting pose and listed in
the catalogue as `stand_in` (the allo's back-view roar); `placeholder` now means no generated art
in any facing. Hit/take-off frames for the new moves are in `hits.json` (allo bite/chomp 5 in all
facings; alpha pounce take-off 4 → landing 8 side-on).

## Performance (pass 10: 12 → 54 creatures)
Measured with `Tests/PerfProbe.tscn` (rendered; splits each frame into physics, scripts and
render). Before the fixes the camp ran at ~105 ms a frame: every creature scanned every other one
several times a tick (a raptor's `_pack_side` even re-ran each mate's full target scan), and once a
frame ran long Godot ran up to 8 physics ticks per frame to catch up, which made it longer still.
Now about 14 ms everywhere once settled:
- `ForestCreature.roster(tree)`: the creature list gathered once per physics tick (static;
  invalidated in `_enter_tree`/`_exit_tree`). Use it instead of `get_nodes_in_group`.
- Looks round are throttled and staggered: `_current_target()` and `_hunter_nearby()` rescan every
  0.2–0.28 s (a fresh threat is answered at once; a kill rescans at once).
- `_avoid_obstacles` keeps the way it found for 3 ticks while the heading holds (dot > 0.96).
- `_separation` skips bodies more than 40 px away on either axis before measuring.
- Only creatures within 420 px of the view redraw (`_on_view`).
- **Lazy far beasts**: wild, not mid-move and over `LAZY_RANGE` (640 px) from the keeper, a creature
  runs its whole update every 4th tick with the summed delta, and `move_and_slide` gets its velocity
  stretched by the same factor so it covers the same ground.
- The sun-shadow pass (`ForestLighting`) was ~12 ms a frame on its own before pass 10:
  it re-triangulated every nearby prop's shadow every frame. Shadows are now triangulated once
  per sun step (`_sun_meshes`, drawn with `canvas_item_add_triangle_array`), redrawn only when
  something changes (who's near, a door or lid, the sun's step, shadows toggled), and at most 6
  stale shapes are rebuilt per frame when the sun moves on. Occluder polygons are set only when they
  change, and lights are looked for only on campfires, shrines and torches.

## Pass 11: lives, nests, babies, the wilds' beasts and bosses
- **Lives** (`Forest/creatures/CreatureLife.gd`, `c.life`): hunger (`Life.HUNGER_TIME`) and thirst
  (`THIRST_TIME`) drive goals: graze (the `GRAZE` table), drink (nearest water), rest at night,
  keep to the nest, follow the mother (babies), and move on (the herd's leader, its lowest instance
  id, picks new ground 18-34 cells away in the same region; predators keep 24+ cells from camp).
  Goals only steer when nothing is being hunted or fled: `_wild_behaviour` asks
  `life.steer(delta)` after `_current_target()`, and `NO_GOAL` (Vector2.INF) falls through to
  wandering. Kin within 220 px rush anything that hurts a baby (`PROTECT`); nest guardians
  (`NEST_GUARD`) stay by their nest and `CreatureLife.rob(tree, cell, thief)` rouses them all.
- **Babies** (`Life.gd`): every `BREEDS` kind has a `<species>_baby` art key (side view only;
  `tools/dino/babies.py`: pixflux restyle of the parent at half scale on its palette, then
  prepare.py `prepare_baby` and gen.py clips idle/walk/run/eat, hurt/death as stand-ins).
  `Life.baby_stats`: hp x0.3, damage x0.25, radius x0.55, feeds ceil(/4), never a predator,
  "Baby X". `set_baby(true, grown)`, `grow_up()` after `GROW_TIME`; saved as baby/growth.
- **Nests and eggs** (`Forest/world/Nesting.gd`, world-owned; `Forest/life/LifeKeeper.gd`,
  session-owned): `SITES` per species, `EGGS` each, `REGROW` 420 s; guardians per nest (`GUARDS`)
  and a chance of young (`YOUNG`); an incubator hatches after `HATCH_TIME` (x0.35 away from a
  campfire or torch within `WARM_CELLS` 3); the hatchling comes out tamed and following
  (`SignalBus.egg_hatched`). Two tamed adults of a kind kept at home for `TOGETHER` seconds lay an
  egg, then rest `REST_AFTER`. Wild nests keep the wilds from emptying (wildlife is never
  re-spawned and hunters take their toll): `LifeKeeper.wild_hatch()`, once a minute at most
  world-wide, hatches one egg of a nest whose kind has fewer than `THIN` 3 within `THIN_RANGE`
  640 px, never within `UNSEEN` 360 px of the keeper; the baby keeps to the nest (`life.nest`).
- **Kin never hunt kin:** `_hunter_near()` skips its own species. Without that a raptor pack
  hunting beside one of its babies counted as a threat to it and `_guard_baby` set the adults
  on their own packmate (7 raptors killed by raptors in a new world's first minute).
- **Gifts** (`Forest/life/Buffs.gd`, group `companion_buffs`): a tamed beast within `NEAR` 480 px
  gives its species' gift (`GIFTS`); the keeper, gardens, incubators, harvest and berry code ask
  the accessors (`crop_speed`, `incubation_speed`, `defense_bonus`, `break_bonus`, `extra_berries`,
  `speed_mult`, `damage_mult`, `recovery_mult`); the parasaur's `_alarm` toasts a nearby hunter.
- **New species:** the Crestcaller Parasaur (Glassmere's herds; the crest is hand-drawn onto the
  PixelLab drawings by `tools/dino/parasaur_crest.py`) and Ossuar, the Buried King (boss only,
  never wild). Both were drawn with `new_species.py` and animated by gen.py (bipeds). Front and
  back views that fell apart were rebuilt from the resting drawing: `tools/dino/walk_front.py`
  (the parasaur's front walk and run: its crest pumped) and `tools/dino/lunge_front.py` (legs
  planted, the body above the hips rears and snaps: Ossuar's front/back bite and chomp, its
  front/back roar and side hurt, the parasaur's front graze; pass 12: the Ashmane's back chomp,
  which spread its arms and flexed, and its back roar). Ossuar's glowing crystal trips gen.py's
  "bright" QA on every retry, so its roars and hurt were built this way instead. lunge_front now
  writes its contact frame into hits.json itself (it only said so before). A clip flagged "wide"
  isn't always turned: the Ashmane's front chomp swung its tail up behind, and its slam frame
  was the best of the set, so look before rebuilding.
- **Variants** (`ForestCreature.VARIANTS`, `set_variant`): `crystal` (Crystalback X, the Pale
  Hills), `dune` (the Dunestalker allosaur), `old` (Greyhorn, a hostile trike), `bone` (the Buried
  King's Bone Raptors: `Forest/creatures/bone.gdshader` turns the raptor's drawing to old bone;
  no meat, never saved). A variant with a `title`, and the rex (`MINIBOSS`), wear a `Nameplate`
  (name and a slim health bar, within 250 px, z 60).
- **Ossuar** (`Forest/creatures/OssuarBoss.gd`, like AlphaBoss): called with the Grave Horn at
  `world.ossuary` (`use_ossuary`: E asks, a second E or using the horn blows it; the horn is
  spent). It rises from the sand (`_emerge`: the sprite slides up 26 px and fades in), then
  bone spikes (`Forest/fx/BoneSpikes.gd`: a cracked ring for 0.85 s, then damage), a burrow
  (`untouchable`, physics off, a `SandMound` chases the keeper 1.7 s, holds 0.75 s, then it bursts
  up), three bone raptors below 60%, rage below 30% (haste 1.25). Leash 22 cells; beaten ->
  milestone `ossuar`, the crown (`bone_crown`, trinket +6 defence: trinket `defense` now guards).
- **Old Maw** (`Forest/creatures/OldMaw.gd`, group `sea_beasts`, not a ForestCreature): a shadow
  under `world.deep` (roam -> stalk a boat on the deep -> charge -> breach -> dive). Only a
  breaching Maw can be hit (`can_be_hit()`): the keeper's melee and arrows check `sea_beasts`.
  It never leaves the deep (a breach that lands in the shallows swims straight back). Beaten ->
  milestone `maw`, maw teeth (the Maw Charm) and pearls.
- **Piranhas** (`Forest/creatures/Piranhas.gd`): 16 drawn fish in `world.piranha`; a wader (or
  their mount) in the bay is nipped for 3 every 0.5 s (no attacker passed, so a mount never turns
  on its rider); a boat is safe.

## Performance (pass 11: ~180 creatures, a world 3.7x bigger)
(Superseded in pass 12, below.) Tiers by distance from the keeper (`_lazy_step`): full rate within `OFFSCREEN` 400 px, every 2nd
tick to `LAZY_RANGE` 640, every 4th to `FAR_RANGE` 1400, every 16th beyond (always full rate
when tamed, mid-move, or hunting/fighting a foe within `CLOSE_FIGHT` 110 px: a lazy stride
carried a far rex right into the stego it fought, and jaws that close on a body already inside
them miss; ai-pass2 caught it). Beyond `HIDE_RANGE` 760 px a creature isn't drawn at all. Neighbour
queries go through `ForestCreature.near(tree, at, radius)`: the roster sorted into 64 px buckets
once per physics tick. `MountController._process` returns at once when nobody rides. Camp, the
Bonelands and the south-west forest measure 10-12 ms a frame (`Tests/PerfProbe.tscn`).

## Performance (pass 12: ~240 creatures and two villages; frames had crept to 25-39 ms)
Measured with `Tests/PerfProbe.tscn` (frame split; pass 12 adds the camps, the bog and a
sandstorm) and `Tests/PerfSplit.tscn -- --at <village id|camp|dunes>` (mean physics time a tick
with each group's physics switched off in turn; mean, because the engine's own
`TIME_PHYSICS_PROCESS` monitor holds each second's *worst* tick and was too noisy to compare). A
creature's full tick costs ~90-160 us of GDScript, spread over targeting, obstacle probes,
herd spacing and the clip choice: no single hotspot, so the wins came from ticking less.
- **Lazy ticks are cached:** a full tick sets `_lazy_wait` (ticks to bank before the next one,
  on the beast's own staggered slot of the cycle); in between `_physics_process` only banks the
  time and returns. `wake()` ends the wait (a blow, a tame); `wake_all(tree)` after a respawn.
- **Tiers:** full rate in or within `VIEW_MARGIN` 110 px of the view (`HALF_VIEW` 240 x 135: a
  circle counted beasts well above and below the screen as near), every 2nd tick beyond that,
  4th past `LAZY_RANGE` 640, 16th past `FAR_RANGE` 1400, 32nd past `REMOTE_RANGE` 2400.
- **Hidden beasts skip what only shows:** herd spacing (`_separation`: beasts don't collide with
  each other) and the clip choice, unless a move is playing.
- **Per-frame nodes sleep:** each beast's `MountController` stops processing until `mount()`;
  its `CreatureAudio` processes only within `EARSHOT` 520 px.
- **Once-a-tick caches:** `folk(tree)` (the tribesmen), `_rex_shadow()`. Tribesmen look for
  companions and game through `ForestCreature.near()`, not the whole group.
Result: 10-19 ms a frame across runs (camp ~11-14, the villages ~10-18, a sandstorm ~15), from 25-39, with 252 beasts.

## Pass 12: tougher beasts, new species, coats, territory, the Blender Scarhorn
- **Tougher and faster** (Hank: "I shouldn't be faster than a raptor"). hp roughly doubled to
  quadrupled. BODY `chase` is a hunter's run-down speed and `tire` how long before it's winded
  (`_chase_speed`, `_give_up`). Raptors (132), allosaurs (118), rex (110) and the Scarhorn (146)
  all outrun the keeper's 125 sprint.
- **Stuck detection:** `_watch_stuck` sidesteps and paths with A* for a while.
- **Rival fights end short of a kill:** below 35% hp from a wild creature, a beast breaks off and
  runs (`_rival_check`).
- **Territory** (`RIVALS`, `DISPUTE_RANGE` 170):
  - Rival hunters (rex, carno, yuty, allo in pairs) square up when they meet (`_find_rival` and
    `_start_dispute`, checked once a second in `_current_target`).
  - The loser runs; the winner lets it go with a roar and won't pick another fight for 90–120 s.
  - Against the keeper they fight to the end.
- **New species**. SPECIES/BODY/MOVES/PREY/NOTICE, loot, gifts in `Buffs.GIFTS`, spawns in
  `ForestPlaytest.WILDS12_LIFE` (with the `wilds12` region marker for old saves):
  - **Sunsail Dimetrodon** (dunes):
    - `_sun_pace`: sluggish at night, quick at noon; basks side-on by day (`_basking`).
    - Notices a keeper only within 64 px.
    - Drops sail scale: the Sun Sail placeable and the Sail-skin Veil.
    - Gift "Sun-warmed": crops +25% by day.
  - **Dune Protoceratops:** SKITTISH herds that flee and peck when cornered. Gift "Sand digger":
    digs up bones, fossils and coins on sand.
  - **Sandclub Ankylosaur:**
    - `PLATED` takes 9 off every blow, so bring heavy weapons.
    - Club tail knock 460.
    - Drops plates for the Sandclub Maul. Gift "Rockbreaker" (the vision's anky = mining): one more stone, crystal or ore per rock or vein broken (`Buffs.extra_ore`, `ForestWorld.mine_at`), +3 defence.
  - **Scarhorn Carnotaurus** (dunes apex): a bellow on lock-on, then a horned charge. Drops horns
    for the Scarhorn Lance.
  - **Ashmane Yutyrannus** (Pale Lands apex, a pair): its roar blasts ash (`_ash_roar` →
    `apply_ash`). Drops fur for the Ashmane Mantle.
  - **Compy:** swarms that won't come for the keeper unless 3 or more are about. It uses the
    raptor's pack tactics (its move is a "slash").
- **Drawings:**
  - Most were drawn with PixelLab **create_character v3 from words alone** (2 generations, 8
    views; `tools/dino/pick12.py`).
  - v3 fills its canvas, so pick the canvas size as the animal's game size.
  - For these long bodies the side view came out as "north-east", the front as "south-east" and
    the back as "north-west".
  - Per-view pixflux restyles couldn't make the dimetrodon's sail or the ankylosaur's shell read
    from the front.
  - v3 *rotation* of a side-view reference treats the reference as the front, so every label is
    off by 90°. Give it a front view or nothing.
  - The protoceratops stayed a pixflux restyle (v3 gave it horns, like a baby trike).
  - The compy is side-on only (`prepare.py has_view`).
- **Coats** (`tools/dino/coats.py`, no generations): recolour a species' exported strips part by
  part (outline, body, crystal quills, belly by hue) into a new art key. `VARIANTS[...].art` picks
  it (`wanted_art_key`).
  - `raptor_sand`: Dune raptors, sandy with dark back stripes.
  - `raptor_ash`: Ashfang raptors of the Pale Lands: soot-dark with a baked fringe of ash-pale
    fur and ember flecks, the Sky-Fang mutation look. First baked ash-grey, they all but vanished
    on the Pale Lands' pale, greyed ground (`Tests/Beasts12Capture.tscn` showed it): a beast
    that lives on a pale ground needs a dark body to read as a threat.
- **Tribe beasts:** `master` (see folk-and-housing.md → Tribes).
- **The Scarhorn's art is Blender-made** (`blender-pipeline.md`): catalogue `"source": "blender"`,
  and BODY walk/run matched to the render's stride.

## Pass 13: telegraphs, calmer wilds, new beasts, each beast its own animal
- **Pace:** `ForestCreature.PACE` (0.72) scales every species' `stats.speed` in `_stage_stats`;
  BODY `chase` values were lowered to match (raptor 98 > keeper sprint 88). BODY `walk`/`run` are
  art strides (stride.py) and `run_at` the walk-to-run switch: don't scale them with the pace
  (pass 13 did, briefly, and the raptor's walk never played at 1x).
- **The alert** (`ALERT_TIME`, `_alert_needed`, `_begin_alert`, `_draw_alert_mark`): before going for
  the keeper, a tribesman or a companion, a beast stops, faces it, plays its display
  (`ALERT_CLIPS`: threat, roar, windup, stomp, sniff) and shows a red "!". Struck first, it skips
  most of it (`ALERT_STRUCK`). Bosses and babies don't. The old per-species lock-on roars are gone.
- **Who hunts whom:** `NOTICE` (hungry) vs `DANGER` (fed: `sated > 0` only reacts inside it);
  `TERRITORY`: past its ground a hunter gives up and walks home (`_wander_velocity` walks back at
  0.8 of its pace when well off its ground). Herbivores ward off (`COMFORT` display, `WARD_LEASH`/
  `WARD_GAP` give-up). Babies' kin react to `life.disturbed()` (the keeper reaching for the baby),
  nests to `rob()` only.
- **Pounce** (`DinoMoves.FLIGHT_MAX` 0.3 s, `HOP_PER_PX`): the flight's frames play faster, the body
  hops (`c.hop`, the shadow shrinks) and dust kicks up at both ends.
- **LOD bug fixed:** the lazy-tick stretch must divide by `get_physics_process_delta_time()` (it
  multiplied by `physics_ticks_per_second`, which counted `Engine.time_scale` twice: 4x tests moved
  every beast 16x per frame and the rex's bites whiffed through the stego). Tribesman.gd too.
- **New species** (PixelLab v3 from words, `tools/dino/pick13.py`; clips via gen.py):
  - `deino` (Reedstalker Deinonychus, bog packs; raptor tactics),
  - `utah` (Sandblade Utahraptor, Bonelands pairs; the longest pounce),
  - `sucho` (Mirefang Suchomimus: lurks in the shallows by its home, `LURK`; eats fish),
  - `spino` (Sailking Spinosaurus, the bog apex: wades the deep mere, `DEEP_WADERS` clear the
    deep-water collision bit; `AQUATIC` keeps most of their pace in water).
  - The **Scarhorn** is PixelLab again (Blender retired). v3 read "horns" as a ceratopsian frill twice.
    "Built like a slim tyrannosaur ... two stubby bull horns jutting sideways above the eyes" gave a
    theropod. The deinonychus came out with side = "east", front = "south-west", back = "north-east"
    (not the usual north-east/south-east/north-west): check every set by eye.
  - The spinosaur's 96 px side view had its paddle tail cut flat by the canvas. `tools/dino/tail_tip.py`
    carries the edge column on, tapering, in the drawing's own colours. The 128 px redraw was whole but
    twice the rex.
  - `threat` clips for the beasts that had no display (raptor, stego, anky, proto, compy; deino).
- **Genes** (`Genes.gd`, `genes.gdshader`): each beast's hue/sat/val, markings (the art's own dark
  bands made bold or faded, or frame-local speckles), a rare mutation colour, temperament, traits and
  stats (x0.88-1.12) are rolled at `_ready` from where it was born, saved with it, and blended for the
  keeper's own young (`LifeKeeper.bred`). The shader samples `TEXTURE` itself, so it multiplies by
  the incoming `COLOR` (the modulate hurt-flash still works). A bone thrall keeps its bone shader.
- **Taming ways** (`TamingWays.gd`): every species has its own way (see the table there). Offerings
  (`Offering.gd`) are food set down; a beast whose way it is walks to it once the keeper is
  `OFFER_SHY` away. The Taming tree's lore (`Skills.LORE`) gates hunters and the apex.
- **Siege** (`SIEGE_SECONDS`, `_find_blocker`, `_tick_siege`, `ForestWorld.siege_hit`): hunting and
  blocked, a beast bashes through a keeper's building (fractions of a blow add up in `prop.siege`); the
  big ones shoulder through trees.

## Pass 14 (2026-09-25): the crystal-sick herds, the Ashmane's face, the Suchomimus' ridge
- **Crystal keys** `<species>_crystal` for raptor, trike, stego, longneck, parasaur, utah, deino,
  sucho and spino: a Crystalback (`ForestCreature.crystal == 2`) wears one.
  - **Bases** (`tools/dino/crystal_bases.py`): PixelLab `edit_image` on the clean `first/`
    drawings, up to 4 frames at <= 128 px per batch (a canvas over 128 px is cropped to a shared
    window and pasted back). Three looks were tried: ridge, heavy and light. The raptor took
    "ridge"; heavy was too much crystal. `adopt` stands each result feet-aligned where the clean
    one stands. Palettes are `palettes/<key>.hex`; `clips.json` gives each key `palette` (gen.py
    `palette()` reads it).
  - **Clips**: gen.py, like any key. Then `tools/dino/crystal_fix.py KEY` applies the clean kind's
    procedural fixes, the same tools and arguments that the clean key's ledger `method` entries
    record: front and back walks, the stego's tail sweeps and copied threats, the trike's gore and
    cap clamps, the parasaur's front displays, the Suchomimus' held bite frame, the lift_back
    roars. `walk_back.py`, `tail_side.py` and `export.py` (`kind_of`: frame origin and
    `VIEW_DROP`) fall back to the clean kind's rig for a `_crystal` key; `hits.json` was seeded
    with the clean kind's contact frames.
  - **Look at every front and back action.** The crystal models rear tails into pale spikes (the
    raptor's sniff_down became a lunge_front graze) and flatten a back tail sweep into a bar (the
    stego's tail_swing_up became `tail_front.py --view up`, and its threat_up a copy). They grow
    posts over the head (the trike's walk_down became walk_front) and push a crest into a pillar
    (the parasaur's roar_up became `lunge_front.py roar --view up`). The Utahraptor's front walk
    and run lost their crest partway through (walk_front). The deinonychus' back slash turned round
    to show its jaws (`lunge_front.py bite --view up`, moved to slash_up). The raptor's side slash
    smeared an arm into a long dark bar, trimmed back by hand. The AI frames are kept in
    `<clip>_ai`, and `crystal_fix.py`'s `CRYSTAL_EXTRA` replays these fixes after a regeneration
    (the hand trim excepted).
  - **Stride**: the crystal clips stride differently. `stride.py` measures clean against crystal,
    and `ForestCreature.ART_STRIDE[key]` is the clean species' tuned walk/run scaled by that ratio.
- **Skytouched** (level 1) is shader-only: `genes.gdshader` `sick` greys and cools the hide and runs
  pale veins through it (two crossing sine fields, with a slow pulse). The clean art stays in use.
- **The Ashmane's side face** was scrunched. `edit_image` on the flipped profile fixed it
  (`inpaint` drew a tube for a head). The new `first/yuty_side.png` stands on the same ground row;
  the old files are in `fix/yuty/`. Its eight side clips were requeued.
- **The Suchomimus read like the spinosaur** (the same orange banded sail).
  `tools/dino/mute_sail.py sucho` pulls every warm, saturated sail colour down to a dull olive
  ridge, in every clip and drawing (backup in `fix/sucho-sail/`), then `export.py sucho`. No
  generations.
- **The Sandblades died out unseen**: the Bonelands' five allosaurs shared their ground and counted
  them as `RIVALS`. The rivalry is gone, there are three packs of 2-3, and
  `ForestPlaytest.RESTOCK` sends a new pack at dawn when a kind that doesn't breed has none left.

## Pass 15 (2026-09-26): look, rest and stalk clips; pack and ambush tactics

- **Clips**: `look` (13 frames, a head turn), `rest` (lying down, 13) and `stalk` (low creep, 8)
  for 19 species, specs in `tools/dino/clips.json`. `gen.py flagged()` exempts `rest` from the width
  QA. ForestCreature plays them only if `DinoArt.has_clip` finds them: idle glances, herds resting,
  hunters creeping while `stalk_time > 0`. Every third idle action is a look (a higher share crowded
  out grazing).
- **Front/back stalks**: PixelLab kept drawing them standing tall (a raptor's tail as a post above its
  head, the allosaur's neck as a column) even with a tail-low prompt; allo/up, deino/down, rex/up and
  utah/down are their walk frames (`tools/dino/stalk_from_walk.py`, free). Floating specks within 2 px
  of a mane survive gen.py's cleaning: `tools/dino/speck_fix.py` (yuty stalk_side 2,3; dimetrodon
  stalk_up 4 held from 3). Rerun both after `gen.py clean` of those clips.
- **Tactics** (`creatures/Tactics.gd`, hooked in `_hunt`, never for tamed/provoked/boss beasts):
  - Packs (`PACK`: raptor, deino, utah, compy) share a plan per quarry (`plans[target id]`):
    gather at a rally point `GATHER_R` 124 px out, spread on a ring `SURROUND_R` 66 px, then strike;
    `TOO_CLOSE` 44 px forces the strike. A plan only starts with a packmate within 200 px and
    against quarry that fights back (the keeper, folk, tribesmen, tamed beasts); otherwise the
    usual chase.
  - Allosaur ambush (`_will_ambush`): slip to cover (tree/rock 130-240 px from the keeper, far
    side), lurk still, burst with a roar when the keeper is within `SPRING_AT` 96 px or turns their
    back within 160 px. `_wild_target` keeps the keeper while an ambush is on.
- **Variants**: `grotto` (cave-dwelling crystal beasts) and `sleeper` (the lair rex: 2.6x hp, its
  own loot incl. `sleeper_fang`; asleep until CaveLife wakes it).
- **Stampede** (WorldEvents): a herd flees a `world/Fright.gd` node 900 px behind it, at
  `STAMPEDE_PACE` 1.6x chase speed while the `stampede` meta is set. Anything used as
  `_retreat_from` needs an `is_dead` property.
- **Two-tone mutations** (`Genes.gd`): body and accent hues separately; speckles no longer roll
  (they read as stray spots on the allosaur).
