# Cravera fourth-pass validation

Completed September 15, 2026 in Godot 4.6.1. Ready for the next user playtest.

## Delivered

- Tap E interacts with nearby workbenches, doors and beds, or mounts/dismounts a saddled companion. Hold E opens its commands; hold Q targets a nearby companion or opens group orders when away.
- Original generated saddled stego/trike variants and seated rider poses render together in a single animated frame. Equipped armor follows the seated rider. Original dinosaur source sheets are preserved.
- Left click performs an aimed stego tail strike or trike horn strike. F feeds a wounded mount one appropriate berry, restoring up to 18 vitality with a cooldown. Attacks respect walls, stamina and friendly creatures.
- Richer leaf, moss and soil textures; silhouette-based grounded sun shadows; object-shaped local occluders and restrained surface illumination for nearby furniture.
- Independent floor, structure and roof layers. Doors and furniture can sit on floors; roofs can cover occupied cells. Old floor saves migrate without losing structures.
- Small floating collectible icons, recorded cloth/leather inventory and equipment sounds, stitched-hide shortcut buttons and a settings toggle to hide those buttons.
- Helmet coverage follows the original head silhouette, ears and per-frame idle glances.
- Craftable hide bed sets the spawn point. Death shows a five-second countdown and restores movement without reloading. Missing beds fall back to camp.

Bow and magic systems remain future work. Lighting is stylized 2D illumination, not volumetric 3D lighting.

## Combined regression

All **19 suites passed** through `tools/verify_forest.ps1`. The final run was resumed after correcting outdated UI expectations and synchronizing the rendered test pointer with the camera; no failed final suite remains. Each suite exits successfully, reports zero failures or its explicit success marker, and contains no engine/script error.

| Suite | Result |
|---|---|
| World generation | PASS; 12,544 tiles, 2,339 props, 917 water tiles |
| Inventory | PASS |
| Creatures | 73 assertions, 0 failures |
| Integration | 32 checks, 0 failures |
| GUI input | PASS |
| Menu flow | PASS |
| AI pass 2 | 19 assertions, 0 failures |
| Equipment pass 2 | 73 assertions, 0 failures |
| UI pass 2 | PASS |
| World pass 3 | 85 checks, 0 failures |
| Mount pass 3 | 31 assertions, 0 failures |
| UI pass 3 | PASS |
| Root pass 3 | 53 assertions, 0 failures |
| World pass 4 | 120 checks, 0 failures |
| Mount pass 4 | 48 assertions, 0 failures |
| UI pass 4 | PASS |
| Root pass 4 | 52 assertions, 0 failures |
| Interaction pass 4 | 25 checks, 0 failures |
| Mount render pass 4 | 36 assertions, 0 failures |

Logs: `../forest-playtest/suite-*.log`. Rendered suites use actual keyboard/mouse input and the Compatibility renderer. Root pass 4 exercises the real timed respawn and subsequent movement, bed fallback, save integration and animated helmet coverage. Interaction checks include held-input modal suppression and real selected-item placement routing.

Additional rendered terrain-cache checks: **10 passed**, including actual pixel changes after water placement/collection, save restoration and no needless static-frame refresh. Four recorded foley clips fully decoded with FFmpeg without errors.

Final project scan: **0 missing-resource, script-reference or autoload errors**.

## Visual and performance evidence

- [Mount artwork and combat QA](../forest-playtest/v4/MOUNT_QA.md)
- [Mounted trike](../forest-playtest/v4/mounted-trike-side.png)
- [World artwork, shadows and performance methodology](WORLD_ART_NOTES.md)
- [Daylight shadows](shadows-noon.png)
- [Torch illumination](shadows-night-torch.png)
- [House interior and bed](house-interior-bed.png)
- [Death countdown](death-screen.png)
- [Helmet animation comparison](helmet-idle-comparison.png)
- [UI, input and audio QA](../forest-playtest/pass4-ui/VALIDATION.md)
- Audio license and editing provenance: `game/Forest/audio/leather/PROVENANCE.md`.

The initial richer-terrain implementation exposed a rendering bottleneck during QA. Caching static terrain and sun-shadow geometry improved the measured daytime route from **11.9 to 101.5 FPS**, with median draw calls dropping from 31,842 to 353. The nighttime route measured 392.8 FPS after the fix. These are uncapped local 10-second walking samples on AMD Radeon RX 7700S at a 1440x810 window and 480x270 native canvas, not a cross-machine performance guarantee. Texture memory rose from 30.4 MB to 56.1 MB. Full timings and settings are in `performance-baseline.json` and `performance-results.json`.

## Preservation and replay

All automated gameplay sessions use `--no-save-playtest`. The user's saved journey SHA-256 remains `265A5CA5D479E53376DAE3D5B1C4A9E7E1DC67492AD5DD1C01C820C1595C5B0A`, identical to the before snapshot. The actual house was reviewed using a separate copied save. UI tests verify that the user's settings hash remains unchanged. Original dinosaur image/source files were compared against the earlier artwork baseline with no changes.

Launch with `Play Cravera.cmd`. Follow the fourth-pass route in [the playtest guide](../../docs/SKYFANG_PLAYTEST.md). Re-run all suites with `powershell -File tools/verify_forest.ps1`.
