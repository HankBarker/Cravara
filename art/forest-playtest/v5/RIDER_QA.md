# Rider identity and combat QA

Godot4.6.1, isolated `--no-save-playtest` sessions.

- `ForestRiderPass5`: 38 checks, 0 failures. Four-direction exact visible upper-body identity; seated palette contains only source colors; real leg reposing; cosmetic cloth without defense; darker helmet; live separate rider hurtbox; energy-free attack/sprint; actual predator damaging rider independently; small-hit ride retention; substantial-hit knockoff; collision restoration; enclosed safe landing; rider death detaches while mount remains alive.
- `RiderPass5RenderQA`: 42 checks, 0 failures. Actual game captures of both species moving left/right/up/down, mounted attacks, live equipment, root F feeding, native comparison sheet, locator integration. `rider-render-errors.log` is empty.
- Existing `ForestMountPass3`: 31 checks, 0 failures. Inventory, water, body collision, mounting obstruction, dismount and persistence behavior retained. Its sprint assertion now verifies no energy cost.
- Existing `ForestMountPass4`: 48 checks, 0 failures. Attack/feeding, inventory, wall and cooldown behavior retained. The old energy gate assertion now verifies attacks work with zero legacy energy.
- Existing `ForestAIPass2`: 19 checks, 0 failures. Companion water crossing, retaliation, species combat and orders retained.

Runtime: `EquipmentSkin.gd`, `MountedAppearance.gd`, `MountController.gd`, plus mounted-player target selection in `ForestCreature.gd`. Root integrates `ForestPlayer.take_damage()` with `on_rider_damaged(actual_damage,attacker)`. No edits to dinosaur sheets or saddle artwork.

Rider damage affects actual player health and ordinary invulnerability frames. Its hurtbox remains active while the movement body delegates collision to the mount. Rendering stays synchronized in one composite, with rider-only invulnerability flashing. Hits of10 or more actual damage detach into a collision-checked nearby position. If the mount is fully enclosed, forced landing uses its already occupied ground footprint rather than teleporting to an old mounting origin. Death detaches before normal player respawn.

Evidence: `hero-standing-seated-helmet-native.png` and enlarged `hero-standing-seated-helmet-review.png` compare standing cloth, seated cloth, and helmet in four directions. `mounted-{stego,trike}-{side,left,up,down}.png` are actual moving in-game views. `rider-source-native.png` compares unchanged source upper anatomy against the raw seated export.

Rebuild seated sources: run `tools/forest_rider_source.lua` in Aseprite batch mode, then Godot import. The full mount-art build now delegates seated exports to this source-first recipe, preventing regeneration from reintroducing the discarded generated body.
