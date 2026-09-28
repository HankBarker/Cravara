# Crystal forest bestiary

The six species interpret the Sky-Fangs lore as organic prehistoric creatures carrying mineral growths. Raptor: slate, ivory, rust and cyan dorsal shards. Stego: moss and amber plates. Trike: terracotta with jade frill and horns. Longneck: blue and moonstone ridges. Dodo: ochre with blue crest. Rex: moss and emerald spikes.

Original source art generated for Cravera. `source.png` is the six-species side sheet; `directions-source.png` contains true front and rear poses. Both have alpha even though some viewers display their RGB backdrop. Native extraction thresholds alpha to binary transparency. No third-party creature art is incorporated.

`tools/forest_creatures.lua` extracts fixed-canvas, nearest-sampled pixel sprites through Aseprite and builds idle (4), walk (8), attack (5) frames for each of side/down/up. Run once without parameters, once with `vertical=1 facing=down`, once with `vertical=1 facing=up`. `tools/forest_creature_frames.py` assembles Godot resources. Native `.aseprite` source and PNG sheets live in `game/Forest/creatures/art`.

Animation uses restrained rigid-source limb, body, head and tail motion rather than independently generated frames. It is a playable foundation, with 54 clips and 306 frames, not a claim of polished hand-keyed dinosaur locomotion. Left mirrors right; up and down are independently drawn views. Raptor canvas is 42x32 native pixels; Rex is 76x56. Fixed canvas and grounding are retained across a clip.

Interaction contract: `interact(item_id)` returns `{ok, consume, message}`; caller removes exactly one selected item only if consume is true. Herbivores eat `berry`; raptor/Rex require `net` then `trex_meat`. Feeding cooldown is 3.2 seconds, restraint lasts 9 seconds on raptor / 7 on Rex; another net is required when a long tame outlasts restraint. Progress persists. Tamed interaction cycles follow, stay, guard. Guard companions protect against nearby hostile creatures. Predator attacks have a visible windup, one checked contact, and recovery.

Test: run `res://Tests/ForestCreaturesTest.tscn` with `-- --no-save-playtest`. Checks all species and directional clips, food rejection, cooldowns, hand feeding, restraint expiry and re-netting, companion orders and movement, real player attack timing, save restoration, and death persistence. The common project exit resource warning remains separate from assertion results.
