# Keeper wardrobe, September 21, 2026

Original character identity and animation source are retained from the project's existing hero pack. PixelLab edited those supplied direction frames through the authenticated MCP toolkit. No third-party game sprites or proprietary game code were copied.

## Generation ledger

| Job | Result | Use |
| --- | --- | --- |
| f5683801-dd56-4574-9bfd-871ccf9010dc | Leather pilot, four directions | Rejected: enlarged body |
| 10733540-68e7-4fb9-bb48-ebe67bb5793a | Bone armor | Registered independent pieces; original face restored |
| 7fa28c46-53ad-4ee0-be1f-012a00844e9c | Crystal armor | Registered independent pieces |
| 8b6ddb5f-9703-4519-b683-ce5bda1d100e | Trail braid | Hair cutouts, dyed in engine |
| 2b620aa8-9b47-43bd-a1d3-b648151152ec | Tousled curls | Hair cutouts, dyed in engine |
| fc56dc08-9553-457e-9347-04bb53fac883 | High ponytail | Hair cutouts, dyed in engine |
| 9ceaf5d0-472f-450a-9f5a-4cb859839a12 | Compact leather armor revision | Accepted; brown material palette |
| f3082e94-5d17-473c-aa8f-bf09a07d4bbc | Woven explorer clothing | Dyable cloth, preserved strap/trim |

Each job used 20 subscription generations, 160 total. Initial balance 2,000. API credentials are not part of the asset pipeline or project files.

Raw PNGs are in `raw/`; extracted originals are in `input/`. Reproducible registration/palette extraction: `tools/wardrobe_pass7_import.py`. Editable layered Aseprite documents: `game/Forest/equipment/art/wardrobe/wardrobe_{direction}.aseprite`, assembled by `tools/wardrobe_pass7_sources.lua`.

Registration uses integer cut/paste, no sprite resizing. Face openings retain the real source face and selected skin color. Head pieces follow authored head silhouettes and glance direction; body pieces follow torso anchors; greaves follow actual foot columns. All are composed into one animation cel, so no overlay clock can lag. Equipment cache keys include item IDs and normalized appearance. Hair is hidden beneath equipped helmets.

## Research informing implementation

- [PixelLab MCP toolkit](https://www.pixellab.ai/mcp): generation, multi-image edits and asset access. PixelLab's help agent explicitly confirmed there is no one-click modular paper-doll exporter; layer extraction and registration are implemented locally.
- [Core Keeper modding armor guide](https://core-keeper-modding.gitbook.io/modding-wiki/creating-mods/modding-examples/items/armor): documents armor-specific sprite sheets and `ModEquipmentSkinAuthoring` alongside independent item properties. This informs the separation of equipment data and visual skins.
- [CoreLib source repository](https://github.com/CoreKeeperMods/CoreLib): public community modding library, not the proprietary game's full source. No code was ported. Godot uses an original compositor suited to this project's source frames and action anchors.

The aim is Core Keeper-like readable equipment and cohesive pixel art in Cravera's primitive crystal palette, not an assertion that Cravera runs Core Keeper's exact internal implementation.
