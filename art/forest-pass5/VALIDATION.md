# Cravera fifth-pass validation

Godot 4.6.1, September 15, 2026. This pass focuses on survivor identity, fishing, survival pacing and camp objects.

## Implemented

- Original hero anatomy and palette for all four seated directions. The prior side-view atlas rows were reversed and a generated torso had replaced the original body; both are corrected. Basic cloth is cosmetic, and the leather helmet has darker, recognizable coverage. Existing saddled dinosaur artwork is retained.
- The rider remains a separate health/target entity, with a live hurtbox and rider-only hit flashing. Substantial hits (at least 10 damage after armor) knock the player off safely; death detaches the player while the mount can survive.
- Eighteen deterministic shoreline fishing holes, three fish profiles, an original Space hold/release balance game, visible rod/cast/line/bobber, cooldowns, cancellation and saved hole state. Catches remain collectible when the satchel is full, and uncollected drops now survive save/load.
- Only vitality and hunger are displayed. No stamina restrictions on tools, combat or sprinting. Gentle idle/walking hunger, more sprint exertion, and item-specific fullness buffers. Roasted meat fills hunger and provides three walking minutes of fullness. The former stamina pendant improves fed vitality recovery.
- Harvestable edible mushrooms; craftable refillable crystal flasks and mushroom tonics. A tonic restores 40 vitality over 8 seconds, even when hungry, and returns its vessel to the exact source slot. Raw fish and cooked perch have distinct food values.
- Compact overhead two-cell workbench, single-cell chest with animated lid, overhead hearth, matching inventory icons and reclaimable/placeable tents. Companion button feedback uses recorded leather foley.

## Regression evidence

The expanded `tools/verify_forest.ps1` includes **24 suites**: all 19 prior suites plus world pass 5, rider pass 5, root pass 5, graphical fishing and graphical rider pass 5. All have current successful logs under `art/forest-playtest/suite-*.log`. Execution resumed after correcting a typed-array test fixture; final logs contain no failed assertions or engine/script errors.

- World pass 5: **32 checks**, including opening/closing intermediate chest frames, compact collision footprints, mushroom drops and eight-hit tent reclamation. Earlier world suites pass. World pass 4 has 116 checks because the compact workbench yields fewer disconnected shadow polygons; no shadow test was removed.
- Rider pass 5: **38 checks** for original source pixels, four-direction identity, cloth without defense, actual predator damage against the mounted player, small/large hits, enclosure-safe dismount and rider death. Graphical rider suite: **42 checks**, including both species, four directions, attacks, feeding and equipment.
- Root pass 5: **35 checks**, including activity-based hunger, exact meal buffer timing, potion vessel conservation in a full satchel, station-gated brewing, healing refresh, legacy save compatibility, uncollected-drop persistence without duplicates, and death-save parity.
- Fishing suite: **80 checks passed both headless and graphically**, using actual mouse and Space input. It proves a held-key failure and successful balanced catches of all three species, modal input isolation, accepted-damage cancellation, invulnerable-hit retention, pause/death cancellation, full-inventory reward preservation and cooldown save/restore. Eight checks also exercise real water-flask filling, dry/far/blocked rejection, and satchel right-click tonic use at full hunger without losing the vessel. Its final log is `suite-fishing-pass5.log`.
- Final project resource/reference scanner: **0 issues**. Dynamically constructed rider paths are resolved at runtime and also checked by rendered tests.

All automated sessions use `--no-save-playtest`; explicit serializer tests write isolated test filenames. The saved user journey SHA-256 remained `7DA16F562A43F3711BDCF36DA6B63C8C87562E582E1E1F7210D371DBB3F7D9A3` before and after combined regression. Tests did not modify the user's world or settings.

After QA, the older interactive playtest was closed through its normal save-and-exit handler and the updated game reopened at the title screen. That ordinary exit saved the latest interactive session; its resulting journey hash is `885661F9FDCD001A45E9CA46ADFAECDB5390122FEE03019CFD485946987D565D`.

## Review artifacts

- [Character alternatives, licenses and decision](../forest-playtest/v5/CHARACTER_RESEARCH.md)
- [Rider QA](../forest-playtest/v5/RIDER_QA.md)
- [Standing/seated/helmet comparison](../forest-playtest/v5/hero-standing-seated-helmet-review.png)
- [Actual mounted left view](../forest-playtest/v5/mounted-trike-left.png)
- [Fishing controls and QA](../forest-playtest/pass5-fishing/VALIDATION.md)
- [Fishing in the live forest](../forest-playtest/pass5-fishing/01-cast-and-balance.png)
- [Furniture artwork and provenance](WORLD_ART_NOTES.md)
- [Camp objects at native game scale](furniture-detail.png)
- [Open chest](furniture-open.png)
- [User playtest route](../../docs/SKYFANG_PLAYTEST.md)

## Scope limits

Character creation, spell/bow combat and further dedicated body-action clips remain future work. Tents can be broken, reclaimed and placed; this pass does not create a separate enterable tent room. Character-source alternatives were researched but none were imported. New art uses the existing project palette, and original dinosaur/hero sheets are preserved. Performance optimizations from pass 4 remain in place; this pass does not claim a new hardware benchmark.
