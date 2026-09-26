# Skyfang Wilds validation

Validated locally using Godot 4.6.1 on 2026-09-15. All gameplay tests isolate the original and forest save files.

| Suite | Result | Evidence |
| --- | --- | --- |
| World | PASS | suite-world.log |
| Inventory / crafting | 0 failures | suite-inventory.log |
| Creatures | 73 assertions, 0 failures | suite-creatures.log |
| Full gameplay integration | 32 checks, 0 failures | suite-integration.log |
| Real GUI input | 11 checks, 0 failures | suite-gui-input.log |
| Title / scene transition / overlay layout | 7 checks, 0 failures | suite-menu-flow.log |

Godot MCP reference scan: zero missing resource/script references. Both supplied MP3 tracks passed full ffmpeg decoding without errors. Native 480×270 layouts were reviewed at integer scaling. Screenshots: menu.png, forest-spawn.png, forest-wildlife.png, inventory-integration.png, journal.png, map.png. Directional creature comparison: ../forest-creatures/direction-review.png.

The tests exercised real body collision, actual GUI events, and saved/loaded mutated world state. They do not certify long-session balancing, complete pathfinding, or final animation quality. See ../../docs/SKYFANG_PLAYTEST.md for scope and known prototype limitations.

Reproduce: ../../tools/verify_forest.ps1. The runner verifies success markers and fails on Godot script errors or nonzero exit codes. GUI/menu suites open brief graphical test windows.
