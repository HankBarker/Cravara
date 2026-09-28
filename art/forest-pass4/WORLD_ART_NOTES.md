# Fourth pass: world, shelter and lighting

Original terrain and bed artwork generated for Cravera, then processed through Aseprite using tools/forest_art_v4.lua. Generated source PNGs remain untouched in this directory; native exports are game/Forest/art/v4. Assets use the existing 39-color Cravera palette. Six 64px material swatches render as continuous four-cell patches; 70% texture opacity preserves leaf/soil detail while reducing contrast against characters and furniture. Bed sprite is 30x40, item icon32x32. No dinosaur artwork changed.

Floor storage is now independent from props and roofs. Old world.placed wood_floor entries migrate to world.floors on restore; new serializations write floors with durability. Doors and furniture can coexist with floors. Roof art/hit bounds occupy exactly their16px target cell. Bed is hide_bed and calls forest_session.set_spawn_bed on E. World supplies get_bed_at and get_bed_spawn_position.

Sun projection uses the opaque sprite bottom rather than transparent canvas bottom, unions an explicit contact footprint, and validates triangulation. Native point-light occluders use the actual artwork contour. Prop surfaces receive a restrained unshadowed companion light on mask2 while ground and actors receive occluded light on mask1; this deliberately avoids 2D self-shadow making a lit bench black. This is stylized2D lighting, not volumetric3D. Shadows setting disables shadowing without disabling illumination.

Verification:
- ForestWorldPass3:85 checks,0 failures.
- ForestWorldPass4:120 checks,0 failures, including the read-only copied user's house, inventory-preserving placement/reclaim, three independent layer states and durability, bed binding and safe spawn, valid connected sun shadows dawn/noon/dusk, and object-shaped occluders.
- shadow_review.gd: dawn, noon, dusk, night torch, moving lantern, settings-disabled captures;0 failures.
- house_review.gd: copied actual house migrated with8 floors/7 roofs, missing corner filled to8 roofs, bed placed and bound at(-12,-5), interior fade rendered. The real journey file was never modified.

Evidence: shadows-noon.png, shadows-night-torch.png, shadows-lantern-left.png, shadows-lantern-right.png; house-original-migrated.png, house-completed-roof.png, house-interior-bed.png. All captures run --no-save-playtest.

## Performance regression caught and fixed

Uncapped rendered walking probe, AMD Radeon RX7700S, Compatibility renderer,1440x810 window/480x270 canvas, VSync disabled, live AI/HUD, equipped lantern. Three10-second samples with warmups and roughly655px actual walking per sample. This is a local capacity probe, not a cross-machine FPS guarantee.

| Sample | Before average FPS | Final average FPS | Final median /95th percentile frame ms | Final median drawcalls |
|---|---:|---:|---:|---:|
| Day with shadows |11.9|101.5|8.85 /18.81|353|
| Night with shadows |14.6|392.8|2.20 /4.09|196|
| Night shadows off |14.5|364.8|2.32 /4.73|194|

The slight night on/off reversal is sample/route/AI scheduling variation; this is not evidence that shadows make rendering faster. Baseline median drawcalls were31,842 day /31,680 night. A full static ground render target now replaces all per-cell materials/verge commands in the live scene; it refreshes on terrain edits and restore. Texture memory increased from30.4MB to56.1MB. Sun projection union/triangulation now caches local polygons per art variant and512-step sun phase, clearing old entries as time advances. Moving lights, surface lights, animated water and all props remain live.

Performance raw evidence: performance-baseline.json and performance-results.json; reusable harness performance_review.gd. Godot TIME_PROCESS monitor values are included raw; wall-clock frame percentiles are the meaningful rendered frame timings here.

Rendered cache_edit_review.gd checks actual cache image pixels before/after water bucket placement/collection and save restoration, plus no static-frame invalidation. Ordinary WorldPass4 and RootPass3 tests re-run after these changes.
