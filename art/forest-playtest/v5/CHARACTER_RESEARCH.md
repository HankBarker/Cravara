# Character source comparison

Reviewed 2026-09-15 against the actual player atlas, native 480x270 presentation, existing equipment compositor, and riding poses.

| Option | Primary source and license | Fit for this pass |
| --- | --- | --- |
| Existing project hero | `game/Sprites/Base Character/Unarmed_Idle_full.png`, existing project-supplied source and layered Aseprite originals | Best continuity. Existing tool, movement, hurt and death animations already use this anatomy. This pass adds no third-party character license or replacement body. |
| Kenney Tiny Dungeon | [Creator page](https://kenney.nl/assets/tiny-dungeon), CC0 | Simple, readable small characters and a permissive asset license. A replacement would alter the established hero silhouette and require new directional action/riding integration. No assets adopted. |
| Universal LPC generator | [Maintainer repository](https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator), asset-specific CC0, CC-BY, CC-BY-SA, OGA-BY or GPL choices; generator exports selected asset credits | Strong future customization source. Each chosen layer requires its own credits/license review. Its broader body/outfit catalog would be a substantial character migration rather than a repair of our current rider. No assets adopted. |
| LPC Revised | [Creator repository](https://github.com/ElizaWy/LPC), CC-BY3.0 or OGA-BY3.0, per-asset credits | Cohesive 32-pixel, three-quarter perspective and larger character bodies. Attractive alternative for a deliberate future art redesign; changes current scale/anatomy and animation integration. No assets adopted. |

Decision: preserve the current hero. The visible mismatch was a source-mapping error plus a generated substitute torso. Current `idle_right` begins at atlas (320,128); `idle_left` begins at (320,64). The old rider used the opposite directional rows and generally frame0. `tools/forest_rider_source.lua` now reads the exact live source cels. All visible pixels above row40, including head, torso and arms, match those cels. Existing leg pixels are reposed at their native size. No generated rider anatomy or new skin palette remains in the runtime assets.

Left-facing riding uses the authored left hero cel. It is pre-mirrored before the shared dinosaur frame flip, so the final view retains the actual left anatomy instead of displaying an arbitrary mirror of the right hero.

Cloth is a cosmetic render treatment shared between standing and seated sources. It creates no armor item and grants no defense. The leather helmet uses a darker brown crown and stitched band while preserving face openings and the original per-frame head mask.
