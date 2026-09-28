# Cravera forest pass three — validation

Validated September 15, 2026 in Godot 4.6.1. This iteration targets collision, lighting, equipment attachment, inventory gestures, recovery, building and saddle riding. Original dinosaur artwork is unchanged (SHA-256 comparison against the existing artwork baseline: zero changed files).

## Automated regression

`tools/verify_forest.ps1` completed successfully after the final lighting correction: **13 suites passed**, with no engine or script errors in their logs. Tests use `--no-save-playtest` and isolated saves. Graphical input suites use the real Godot viewport and held mouse events.

| Suite | Result |
| --- | --- |
| World generation | Passed |
| Inventory transactions | Passed |
| Creatures | Passed |
| Integrated forest gameplay and persistence | Passed |
| GUI input | Passed |
| Title/pause flow | Passed |
| Second-pass AI | Passed |
| Second-pass equipment | Passed |
| Second-pass UI | Passed |
| Third-pass world | 85 checks, zero failures |
| Third-pass mounts | 31 assertions, zero failures |
| Third-pass UI | Zero failures, headless and graphical |
| Third-pass root integration | 53 assertions, zero failures |

Logs: `art/forest-playtest/suite-*.log`.

The Godot project scanner also reported zero broken references or other detected issues.

Final rendered riding review found and corrected a low rider anchor and an oversized opaque saddle overlay. After the correction, the 31 mount and 53 root-integration assertions passed again. A further OpenGL riding/locator pass completed 22 assertions with zero failures and an empty error log.

The new regressions cover deeper object footprints, resource durability, damage persistence, safe structure reclamation, protected chest contents, door obstruction, roofing, plant harvesting, mount prerequisites and safe dismounting, inventory drag/merge/swap/cancel, all five hotbar pouches, equipment source-frame preservation, camera modes, healing over time, pause/settings and save restoration. Settings tests verified the user's settings-file hash remains unchanged.

## Rendered review

- `art/forest-v3/SHADOW_REVIEW.md`: dawn/noon/dusk/night, moving lantern occlusion, emitter self-shadow correction, daylight light intensity, silhouette projections and disabled-shadow behavior. Clean render and regression logs.
- `art/forest-v3/WORLD_PASS.md`: base construction, roof fade and grounded collision footprints.
- `art/forest-playtest/pass3-ui/VALIDATION.md`: held drag/drop, fonts, satchel, settings and saddle command screenshots.
- `art/forest-playtest/v3/equipment-motion-native.png`: source and equipped directional run/pickaxe frames inspected at native scale. Equipment is composed per frame, with head anchors exported from the original Aseprite head cels.
- `art/forest-playtest/v3/MOUNT_LOCATOR_QA.md`: six input-driven mounted views, corrected rider seating and shaped saddle details, live locator distance and cleanup. Recommended preview: `mounted-trike-side.png`.

Six bundled Kenney interface sound files also passed full ffmpeg decoding. Licenses are included alongside fonts and audio. Technical/source references appear in `docs/SKYFANG_PLAYTEST.md`.

## Review limits

This remains a single-biome playtest. Sun shadows are stylized finite sprite projections; nearby lights use native 2D occlusion, not 3D height/normal lighting. Roofing is a fading tile layer. Saddled stegosaurus and triceratops support movement, sprinting, wading and dismounting; mounted combat, harvesting bonuses, Rex riding, eggs and perk progression remain future work. Riders currently reuse directional idle body poses positioned on the saddle; bespoke seated animation is future art work. Creature steering is local rather than full long-distance pathfinding. Human playtesting is still needed for feel, balance and long sessions.

See `docs/SKYFANG_PLAYTEST.md`, “Third-pass review route,” for a ten-step review of the changes and controls.
