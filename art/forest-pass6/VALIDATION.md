# Forest pass 6 — playable keeper and companion update

Completed September 16, 2026 in Godot 4.6.1. The existing keeper identity is retained, with a persistent appearance creator, shaped cloth/leather equipment and 52 directional action clips (13 actions, 416 frames). Equipment pixels are composed into the exact body/head pose. Mounted bows use the same customized, equipped character while retaining a separate living player target.

Other implemented systems: charge/release bow and swept arrows; stego/trike mounted shooting; hoe/seed/water/harvest gardens; berry and mushroom crops; dodo eggs and two cooked foods; local stego/trike/dodo gathering jobs and chest delivery; 18 sampled species voices; directional combat anticipation/impact; quick-sort/quick-stack; shared item statistics; power-2 mining/chopping and dense prism seams; softer terrain texture contrast. Twelve items have original native Aseprite source artwork.

## Verification

`tools/verify_forest.ps1` now contains **31 suites**. Every final suite log has a pass marker and zero script/runtime errors; `suite-results.json` is the machine-readable index. Failures found during development were fixed and the affected suites rerun. `tools/summarize_forest_pass6.py` checks the final evidence. The Godot resource scan reports **0 issues**; `git diff --check` is clean.

- Character: 692 assertions, plus 30 actual rendered playback checks. Four-direction equipment, head/grip alignment, identity choices, cache/source immutability and mounted poses.
- New root gameplay: 70 checks. Gardening timing, water-container conservation, save roundtrip, footprint protection, hardness, projectile physics/walls, exact ammo consumption, mounted downward fire, interrupted draws and cooking transactions.
- New real-input actions: 20 checks. Actual mouse/keyboard tilling, planting, watering, harvest, hold/release bow, menu cancellation, four weapon clips and mounted shooting.
- New UI: 30 checks. Protected hotbar, sorting, stack overflow/obstructions, character editor cancel/apply, new-game appearance, worker commands and petting. Menus additionally checked recursively for native 480×270 bounds and creator button overlap.
- Workers: 62 checks. Actual travel around a new wall, harvesting, return/deposit, capacity and obstruction safety, persistence, animation/sound contact, egg production and audio limits. Creature and AI compatibility suites separately rerun after gathering animation changes: 73 and 19 checks.
- Fishing: 80 checks through real held/released Space, all three fish, interruption, full-satchel catch preservation and hole persistence.
- Actual previous journey: 9 compatibility checks against a read-only snapshot. All 35 inventory slots/quantities, armor and creature count survive; legacy cosmetic/garden defaults load and new appearance roundtrips to an isolated file.
- The remaining world, collision, inventory, dragging, mount, death/respawn, save and menu suites remain green.

The user's journey remained byte-identical throughout tests (SHA256 `4537FAA5110AE357DFB5730714BE33777B80997157223B2A37AED30E5094A847`). Tests use `--no-save-playtest`; serializer tests use their own filenames. No user settings or journey were overwritten.

## Review evidence

- `03-bow-draw.png`, `05-mounted-bow.png`: actual input-driven bow, attached rider and equipped appearance in the forest.
- `01-garden-hoe.png`, `02-ripe-garden.png`: tilling and ripe crops in the running scene.
- `../forest-playtest/pass6-ui/02-appearance-editor.png`, `03-new-keeper.png`, `04-worker-commands.png`: reviewed rendered UI.
- `../forest-playtest/v6/wardrobe-review.png`, `direction-action-review.png`: native character comparisons; details in `../forest-playtest/v6/CHARACTER_QA.md`.
- `combat-anticipation.png`, `combat-strike.png`: directional combat cues.
- `creature-engine-audition.mp3`: actual engine mix, ordered dodo, raptor, stego, trike, longneck, rex. All 18 sound exports fully decode; levels/cooldowns/distance limits verified. Artistic sound preference still benefits from human listening.

Independent review found and fixed copied-array mount exclusions, full-footprint crop/building overlap, and bow/attack/hurt interruption. Render review led to stronger armor silhouettes, bounded skin/composite caches, creator sizing correction, and journal pages that fit the native viewport.

## Scope and references

Gardens and jobs use active game time, not offline simulation. Workers have a small local home range and a 12-item cargo limit; this is a simple gathering system. Only stego/trike supported saddles fire bows. Three hairstyles and four skin/hair/tunic palettes establish the editable character foundation. No story progression, magic or second biome was added.

Character styling/mechanism references: [Minecraft custom attachable/armor documentation](https://learn.microsoft.com/en-us/minecraft/creator/documents/addcustomitems?view=minecraft-bedrock-stable) and [official armor trim introduction](https://www.minecraft.net/en-us/article/armor-trims-coming-minecraft-1-20). These informed cosmetic/equipment separation and fitted visuals; all new character/equipment pixels are local Cravera work. Detailed Core Keeper/reference notes are in the character QA document. Sound authors, CC0 source links and transformations are recorded in `game/Forest/audio/creatures/PROVENANCE.md`. No commercial-game/movie audio was copied.

See `docs/SKYFANG_PLAYTEST.md` for the concise sixth-pass play route and recipes; **J** also has a new field-skills help page.
