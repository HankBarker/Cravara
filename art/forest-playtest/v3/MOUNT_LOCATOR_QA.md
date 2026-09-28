# Rendered mount and locator QA

- Mounted ride anchor corrected: rider root now follows the animal at y = -26 (with one-pixel animation bob); saddle overlay sits separately at the back. Camera compensation remains stable.
- Saddle overlay is shaped leather with small seams, buckles, open stirrups and thin straps. It no longer covers the creature with a solid rectangular block.
- All six actual-render captures were visually inspected: side, up and down for both stego and trike. Player helmet and creature health bar remain separated.
- Side captures are actual input-driven motion: logs verify `walk_side` on the creature and `idle_right` on the rider. Up/down shots likewise follow directional input, not manually assigned sprites.
- The rider currently reuses the existing directional idle body pose, positioned on the saddle. A bespoke seated rider animation is future art work. Existing composed armor remains intact.
- Native dinosaur source artwork was not changed.

## Results

- ForestMountPass3: 31 assertions, 0 failures, after corrected rider anchor.
- ForestRootPass3: 53 assertions, 0 failures, after corrected rider anchor and camera compensation.
- MountLocatorRenderQA: 22 assertions, 0 failures, OpenGL rendered pass after final saddle polish.
- Locator: visible offscreen marker, correct live tile distance, target/player movement refresh, and clean removal when target disappears.
- Locator movement checks wait for render/process frames because the marker updates in `_process`; no runtime locator fix was necessary.
- All runs used `--no-save-playtest`. No user save or settings were written.

## Evidence

Recommended overview: `mounted-trike-side.png`.

Other captures: `mounted-stego-side.png`, `mounted-stego-up.png`, `mounted-stego-down.png`, `mounted-trike-up.png`, `mounted-trike-down.png`, `companion-locator-offscreen.png`.

Clean logs: `mount-after-seating.log`, `root-after-seating.log`, `mount-locator-render.log`; `mount-locator-render-errors.log` is empty.
