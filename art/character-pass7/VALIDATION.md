# Character pass 7 validation

Completed September 21, 2026 in Godot 4.6.1. Scope: keeper appearance editor, wearable artwork, equipment composition, hairstyle/clothing variations and matching armor content.

## Results

**35 suites passed, zero failed.** `tools/summarize_wardrobe_pass7.py` aggregates the 34 forest suites configured in `tools/verify_forest.ps1` plus the actual-world wardrobe render suite. Machine-readable evidence: `suite-results.json`.

- 823 character assertions: original source immutability, animation timing, frame-specific head attachment, exposed hands, helmet hair occlusion for every cel/set, appearance and mounted cache identity.
- 190 wardrobe assertions: nine distinct pieces, 27 fully armored mixed combinations, actual inventory equip/swap/unequip, six workbench recipe transactions and material costs.
- 145 editor checks: appearance-only persistence, independent preview pieces, all motion/direction previews, hand-anchored props, native layout and no inventory mutation.
- 15 current-save assertions: fresh September 21 journey loads without lost inventory/equipment/creatures; new hair and mixed armor serialize/reload in an isolated file.
- 14 actual-world rendering checks: all three sets on terrain, mounted crystal armor through movement, dismount retains real equipment.
- Additional read-only light probe: torch and lantern remain distinct from unlit and one another across all 550 source/action frames. Evidence `review-light.log`.
- Godot project resource scan: **no issues found**. `git diff --check`: no whitespace errors (existing line-ending notices only).
- Asset audit: 61 PNG files, including 36 armor layers, 12 hair layers, four clothing layers and nine icons; all expected dimensions, nonempty, binary alpha and master-palette colors. Four layered Aseprite source documents. Evidence `asset-validation.json`.

## Visual inspection

Inspected four-direction armor and hairstyle sheets, action contact sheets, native forest rendering, mounted rendering and actual editor screenshots. Rejected oversized first leather generation and regenerated on cropped input. Corrected helmet hair leakage, a source-mask issue that tinted a raised hand, leather material palette, and editor fishing-prop clipping. Old tests that assumed one exact brown pixel were replaced with authored-art attachment and overall dark-material checks; their behavioral assertions remain intact.

## Save protection

All gameplay tests used `--no-save-playtest`. Current journey SHA256 before and after:

`6BB0CF84B08AC7D8EAD3179F2A1D227279950226AD8A3D60F5AB3B5B55F078A4`

The snapshot `user-save-before.json` is separate from the legacy pass-6 fixture. No player progression was granted or overwritten. Wardrobe preview selections never grant equipment.

## Review

Continue → K → Appearance. The Wardrobe tab previews pieces; real new armor is crafted at a workbench and equipped through Gear. See `REVIEW.md`, `PROVENANCE.md` and `ARMOR-CONTENT-VALIDATION.md` for controls, generation ledger and recipes.

PixelLab subscription generations used: **160**; remaining after generation: **1,840**. The original keeper body scale and existing action animation library were retained. This is an original Godot equipment compositor informed by public Core Keeper modding documentation, not a copy of proprietary game code. Visual preference remains for the user's playtest judgment.
