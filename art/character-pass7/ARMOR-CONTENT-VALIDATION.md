# Character wardrobe content and save checks

September 21, 2026. Godot 4.6.1. Tests run with `--no-save-playtest`.

## New equippable items

Each set has independent head, chest and leg equipment slots. Existing leather items retain their IDs and defense values. New items are ordinary ItemDB resources, so inventory, equipment and save systems resolve them by stable item ID.

| Item ID | Display name | Defense | Workbench ingredients |
|---|---|---:|---|
| bone_helmet | Fangbound Helmet | 3 | 4 raptor fangs, 2 T-Rex scales, 3 plant fiber |
| bone_chestplate | Fangbound Chestplate | 7 | 6 raptor fangs, 4 T-Rex scales, 5 plant fiber |
| bone_leggings | Fangbound Leggings | 4 | 4 raptor fangs, 3 T-Rex scales, 4 plant fiber |
| crystal_helmet | Skyshard Helmet | 4 | 3 prism crystals, 4 crystal shards, 2 T-Rex scales |
| crystal_chestplate | Skyshard Chestplate | 9 | 5 prism crystals, 6 crystal shards, 4 T-Rex scales |
| crystal_leggings | Skyshard Leggings | 5 | 4 prism crystals, 4 crystal shards, 3 T-Rex scales |

Leather totals 10 defense; Fangbound totals 14; Skyshard totals 18. These are initial balance values. No new crafting station, ingredient or damage formula was introduced. Item definitions live in `game/Items/Data/`; recipes live in `game/Scripts/CraftingManager.gd`. Icons reference `game/Forest/equipment/art/wardrobe/icons/`.

## Runtime verification

- `res://Tests/WardrobePass7.tscn`: **190 assertions, zero failures**. Tests actual pixel differences for all nine pieces and 27 mixed sets, distinct cache entries, four-direction idle/axe/bow/fishing animation timing, source sprite immutability, appearance JSON normalization, full-inventory equip/swap/unequip transactions, and all six crafting transactions. Log: `art/forest-pass7/wardrobe-tests.log`.
- `res://Tests/WardrobeSavePass7.tscn`: **15 assertions, zero failures**. Loads the fresh September 21 snapshot `art/character-pass7/user-save-before.json`, verifies inventory IDs/quantities, armor IDs, appearance and creature count; then equips mixed bone/crystal armor and Trail braid, saves to a unique temporary file, and reloads it. Both the actual user journey and original snapshot remain byte-identical. Temporary test files are removed. Log: `art/character-pass7/wardrobe-save-tests.log`.

Both runs completed without script or runtime errors. Pixel-difference assertions establish distinct functioning equipment visuals; visual quality review and PixelLab asset provenance are documented separately by the character artwork pass.
