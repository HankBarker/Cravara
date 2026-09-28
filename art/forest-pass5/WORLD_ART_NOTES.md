# Fifth-pass furniture and harvest assets

Original image generation + Aseprite native-pixel extraction; no external copyrighted assets. The source PNGs and final prompts remain represented by the source names and tools/forest_art_v5.lua pipeline. New images use the existing Cravera master palette.

- workbench-source.png: near-overhead tabletop with short rim, skywood/bone tools/quartz detail. Export32x24, solid30x15, fits two tiles across.
- chest-source.png: same fixed-base chest closed/half-open/open. Export16x20 states,14x12 body fits one grid cell so existing chest-wall arrangements remain valid. Last five pixel rows shared between frames to anchor base. Animation tracks actual storage panel and reverses on close; inventory logic preserved.
- campfire-source.png: four overhead ring/fire states, export28x24, four-frame strip112x24. Ring edges/bottom anchored. Solid24x16 matches overhead hearth; burn hazard remains.
- vial source: empty quartz flask/cyan water/red mushroom tonic icons32px. Cooked fish source: roasted fish on leaf icon32px.
- Mushroom item icon is extracted from original world mushroom atlas so harvested caps match the world. Tent icon derives from existing hide shelter; neither source artwork replaced.
- Item IDs mushroom (12hunger,20seconds satiation), tent (placeable). Tents have8-hit reclaim durability and return one tent. Mushroom props now drop a usable mushroom, not fiber. Root owns recipes and flask consumables.

Verification:
- Original ForestWorldTest passes, including adjacent wall/chest, water bucket edits, chest save contents.
- WorldPass3:85checks/0failures (mushroom expected loot updated).
- WorldPass4:116checks/0failures. Dynamic assertion count is lower than earlier120 because compact workbench silhouette yields fewer disconnected shadow polygons; no assertions removed.
- WorldPass5:32checks/0failures including lid intermediate frames both directions, physical edge bounds, chest content preservation, mushroom food fields/drop/save, eight-hit tent reclaim/replacement/save, compact furniture sizes and fire hazard.
- Actual captures furniture-closed.png, furniture-opening.png, furniture-open.png, furniture-reclosed.png and furniture-detail.png use the live forest with original dinos and cached terrain. World geometry/lighting optimizations remain intact. Real journey untouched.

All generated originals are preserved. New native assets live in game/Forest/art/v5. Matching item icons use item-ID names for current ItemDB priority.
