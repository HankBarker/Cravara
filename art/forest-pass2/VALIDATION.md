# Forest pass 2 validation

Validated September 15, 2026, Godot 4.6.1 on Windows with OpenGL compatibility / AMD Radeon RX 7700S.

## Reproducible checks

`tools/verify_forest.ps1` completed all nine suites with exit code 0:

| Suite | Result |
|---|---|
| World generation and terrain mutation | Passed (12,544 tiles, 2,108 props, 917 water cells) |
| Inventory and crafting transactions | 0 failures |
| Creature baseline | 73 assertions, 0 failures |
| Full forest integration | 32 checks, 0 failures |
| Original GUI input integration | 0 failures |
| Title/pause/map navigation | 0 failures |
| Second-pass AI physics | 19 assertions, 0 failures |
| Second-pass equipment, save, combat and audio | 73 assertions, 0 failures |
| Second-pass rendered UI/input | 0 failures |

Logs reside in `art/forest-playtest/suite-*.log`. GUI input and menu suites ran with hardware rendering; physics/system suites ran headless. All run with `--no-save-playtest`; save tests use isolated temporary filenames.

The new AI test follows an actual companion through an entire river crossing, measures slow wading, checks that a Rex and stego both damage each other and that a lone Rex wins the prolonged duel, then verifies stance/order semantics. Equipment tests check full-inventory conservation, selected stack handling, reversible bonuses, all accessory/armor persistence and old-save defaults. Attack tests verify three timings, one contact, zero-stamina rejection, and that switching hotbar slots midwindup preserves the committed tool and damage.

The UI test dispatches real viewport mouse clicks and physical keys, including held E and Q, targeted/group commands, tap fallback, corpse bypass, movement locking, all seven equipment slots, and valid panel bounds.

## Visual and audio review

- Item/prop atlas and actual-world captures inspected; noisy first downsample revised to clean palette shading.
- Worn armor corrected after initial eyes/face occlusion; front, rear, left and right reviewed. Final gear portrait is in `art/forest-playtest/pass2-ui/04b-full-equipment.png`.
- Tool body sheets preserve the source character and hide its baked weapon/effect layers. Axe sweep, pickaxe lift/strike and dagger thrust use separate timing and visible hand grips.
- `ForestPass2Capture.tscn` renders the real player, world and tool FSM with explicit directional aim fixtures for repeatable art screenshots. This is visual review, separate from the physical input regressions.
- Pause/journal corners and field-guide overflow were found by review and corrected.
- All fifteen Ogg samples decoded without errors using FFmpeg and loaded as nonempty AudioStreamOggVorbis resources in Godot.
- SHA-256 comparison against `dinosaur-art-before.json`: zero dinosaur source/export artwork changes.

## Practical limits

This remains a single-biome playtest. Creatures use local obstacle steering, so complicated player-built mazes may still require proper pathfinding later. Tool body poses reuse the existing character source rather than a fully new hand-animated set. Saddles/riding, eggs/utility and capability/perk progression are recorded future work, not active features. Long-session balance and responsiveness still need the user's playtest.
