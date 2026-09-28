# Skyfang forest visual pass 2

Original assets generated with the built-in image generation tool, then prepared in Aseprite. No art was copied from Core Keeper, Terraria, Emberville or an external asset pack. Existing tree, fern, berry bush and mushroom sprites remain unchanged; dinosaur art remains unchanged.

## Production recipe

- Source images: `items-source.png` and `props-source.png` in this folder. Both have genuine PNG alpha and are preserved at original resolution.
- Export script: `C:/Cravera/tools/forest_art_v2.lua`, Aseprite `--script-param mode=items` or `mode=props`.
- Runtime exports: `C:/Cravera/game/Forest/art/v2/`.
- All opaque pixels map to the project's 39-color master palette. Output alpha is binary. Four-by-four area sampling before palette mapping removes the high-frequency speckling of the first nearest-sample draft.
- Icons: 30 original 32x32 images, plus a 192x160 atlas and editable Aseprite document. 29 currently registered item IDs consume these; `dodo_egg` is reserved artwork only.
- Construction tiles: stone16x24, ore16x28, palisade16x28, floor16x16. Collision/grid semantics unchanged.
- Workbench42x34, rock40x44, tent64x54, shrine54x64, chest28x26, torch16x32. Rendered at native pixel size with nearest filtering.
- Campfire: four32x36 frames at140ms,128x36 strip and editable Aseprite animation. Shared lower hearth pixels prevent base jitter while flame shape and embers change.

## Generation brief

Both requests specified production sprites on transparent alpha, no labels, no grid, a slight overhead/front view, readable silhouettes at game scale, shaded pixel clusters rather than flat vector shapes, mossy slate, bark, rope, bone, aqua quartz and amber flame. Prehistoric and tribal materials only.

The item sheet requested six columns by five rows in this exact order:

1. Crystal stone axe, crystal pickaxe, red jungle berries, wrapped bone dagger, empty wooden bucket, campfire.
2. Tribal chest, cooked meat, quartz cluster, leather chest armor, leather cap, leather legs.
3. Cut log, braided net, planks, plant fibers, raptor fang, mossy stone.
4. Torch, raw meat, reptile scales, water bucket, wood floor, palisade.
5. Workbench, crystal pendant, hunter tooth-and-feather charm, carved river totem, amber crystal lantern, speckled dinosaur egg.

The prop sheet requested four columns by four rows:

1. Moss-capped fractured slate block, fern-root block variant, quartz-veined ore block, rope palisade.
2. Timber floor, primitive crafting bench with bone/stone tools and quartz, mossy quartz boulder, leaf/hide tribal tent.
3. Four successive campfire frames, identical hearth and logs, curl-left/rise/curl-right/settle flame progression.
4. Crystal shrine on rune slate dais, tribal chest, standing torch, fractured slate chips.

## Review evidence

`production-art-review.png` renders the actual ForestProp implementation alongside actual ItemDB textures at gameplay pixel scale. `art-review.log` verifies29 real item textures with alpha and12 instantiated props. The first noisier draft is preserved as `production-art-review-first.png` for comparison.

`forest-spawn-v2.png` and `forest-wildlife-v2.png` are actual rendered forest captures. `capture.log` contains a clean run after equipment integration dependencies were available. The scene captures show the new blocks, workbench, fire, rock and hotbar artwork together with the existing player, forest and dinosaur sprites.

Reference tooling documentation reviewed: [Aseprite repository](https://github.com/aseprite/aseprite) and [Aseprite Image API](https://www.aseprite.org/api/image). Aseprite is the installed sprite editor and export tool, not a bundled game dependency.
