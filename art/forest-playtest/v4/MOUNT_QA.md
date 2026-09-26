# Fourth-pass mounts

Verified in Godot 4.6.1, isolated `--no-save-playtest` sessions.

- ForestMountPass4: **48 assertions, 0 failures**. Both species: physical wall blocks mounting before any state change; single composite rendering; live gear changes; delayed aimed contact; one hit per attack; rear/friendly exclusion; wall obstruction; cooldown; stamina and panel gates; herbivore food validation; exactly one berry consumed; 18 healing capped at maximum; 2.5-second feeding recovery; normal dismount restoration.
- ForestMountPass3: **31 assertions, 0 failures**. Existing inventory transactions, water movement, sprint, collision, safe dismount, saddle persistence, death cleanup.
- ForestRootPass3: **53 assertions, 0 failures**. Existing camera, survival, equipment, input, UI bounds and save integration.
- MountPass4RenderQA: **36 assertions, 0 failures**. Actual OpenGL game renders with equipped armor/lantern; directional movement; strike playback; real root F-key route; locator distance, motion and removal.

Logs: `mount-mechanics.log`, `mount-existing.log`, `root-integration.log`, `render.log`. Corresponding `*-errors.log` files are empty.

## Art and rendering

`saddled-generated.png` is an image-generation edit of the six-view original dinosaur reference. `rider-generated.png` supplies bent-knee seated torso/leg poses. Aseprite exports live under `game/Forest/creatures/mount_art/`: six 17-frame full saddle variants and four seated hero sources, each with editable `.aseprite` source. Rebuild with `tools/forest_mount_art.lua` in Aseprite batch mode.

Original creature sheets and original hero sheets are read-only inputs. The seated sources retain the original hero's head pixels. `MountedAppearance.gd` applies the current `EquipmentSkin` compositor, then bakes dinosaur, saddle and seated rider into each 96x80 frame. The walking hero sprite is hidden only while mounted and restored on dismount. Camera/body/lighting continue to use the real player node. The saddle and rider share one animation frame, eliminating independent overlay drift. Side art mirrors for leftward travel.

Each directional sheet uses one native canvas and fixed ground. Walk cels move legs and saddle/rider bob together. Stego attack cels fan the tail toward the aimed strike; trike attack cels lunge its horned head with the rider. The original dinosaur source artwork is not overwritten.

## Evidence

`mounted-trike-side.png` is the clearest overview. `mounted-{stego,trike}-{side,up,down}.png` are real input-driven directional captures, with explicit up/down facing assertions. `mounted-{stego,trike}-attack.png` shows strike playback. `stego-composite-native.png` and `trike-composite-native.png` show native walk-side, walk-front and strike frames. `companion-locator-offscreen.png` covers locator integration.

## API

`ForestCreature.mount_attack(aim_world: Vector2) -> bool`: mounted only, 12 energy, 0.28-second windup, once-per-swing contact, 18 stego / 22 trike damage, directional reach/cone and collision-layer16 line-of-sight. Cooldown 1.15 / 0.95 seconds. Tamed creatures excluded.

`ForestCreature.feed_mount() -> bool`: mounted and wounded, menus closed, one species-appropriate berry, 18 vitality capped at maximum, 2.5-second recovery. Failure consumes nothing.

Matching saddle equip/unequip calls `AudioManager.play_sfx("equip_gear")`. Existing saddle APIs and save payload remain compatible.
