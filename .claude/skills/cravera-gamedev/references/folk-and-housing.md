# The folk, housing and stone building

Terraria-style townsfolk for the forest. There is no village: each person is
found somewhere in the wilds, moves into a house the keeper builds, and helps
the keeper along. Hank's brief (2026-09-24): the guide spawns right beside
the keeper and has no house of his own. The others are "randomly found": in
their own little hut, stranded, or locked in a cage. Each arrival pops a
message ("X is ready to move in"). Folk can be moved between houses, houses
have requirements, and you can talk with everyone. They should look unique
while keeping the established style.

## Who, when, where (`game/Forest/folk/Folk.gd`, data only)

| id | name, title | arrives | found (one picked per world) | services |
|---|---|---|---|---|
| guide | Orrin, the Wayfinder | `start`: beside the keeper on a new journey, and on an older journey's first load | never (he keeps to the camp fire) | help (next step from milestones), recipes ("what can I make with…"), lore |
| merchant | Tamsin, the Trader | `cache`: the first ancient cache opened (milestone `cache`) | stranded, hut | trade: buys and sells for `ancient_coin`, plus two rare pieces that change at each dawn |
| warden | Kaya, the Beast-Warden | `tames:2`: two dinosaurs trust you (the count of tames, or the tamed alive now) | caged, hut, stranded | advice (every beast: food, trust, riding), tend (heal hurt companions, 1 coin each), trade (saddles, nets, arrows) |

Lines are in `greet`, `chat`, `lore`, `found_line[kind]` and `ready_line`.
Prices: `STOCK`, `RARE`, `BUYS`, `TEND_PRICE`.

## Stages (`FolkManager.gd`: one node under the session, `session.folk`)

`camp` (at the first camp fire, roaming 56 px), `wild` (at their site),
`ready` (met, waiting for a house), `home` (living in a room). The flow:

- `arrive(id)`: the guide goes beside the keeper. Anyone else gets a hash-picked
  circumstance and `place_site(id, kind)`, and a HUD banner says "X has come
  to the wilds" with the direction. The map marks everyone (violet).
- Talking to someone `wild` calls `meet(id)` → `ready` (banner). A caged one
  must be freed first ("Break the trap open" → `release(id)`: the trap becomes
  `folk_cage_open`).
- `settle()` runs every second. Anyone whose house stopped being valid loses it
  (toast) and goes to `camp`. Then anyone `ready`, and any non-guide at `camp`,
  moves into the nearest vacant valid room (banner the first time).
- The "Your home" page: move into a free house, swap houses with someone
  (`swap(a, b)`; nobody is put out in the cold), or leave (`leave_home`).
- `serialize()` / `restore(data)`: stages, sites, homes, positions, `day`,
  `tames`. No folk data means an older journey, which gets its guide.
  `restore` resets `day`/`tames` first.

### Where someone is found (`site_for(id, kind)`)

Meadow or moss 18–34 cells from camp, no ruin within 10 cells, no water under
the site's drawing or within 12 px of it, and the cell in front can be walked
to from camp. That is a BFS from (0,0) with `is_blocked_at`, where water can be
waded. Where they stand (`spot_at`) must be open, except in a trap.

- First choice: nothing is drawn over the spot (`_clear_for_find`).
- Fallback: only `BRUSH` (trees, rocks, bushes…) overlaps, and the spot is out
  of the keeper's sight. `place_site` clears it and records it in
  `world.mined`, so it stays cleared after a save.
- Ranking is hashed per world seed and person, so it is deterministic.
- Never fall back to a fixed cell in a real world. The suite checks every kind
  for everyone.

## Housing (`Housing.gd`, static)

A room is a 4-way flood fill from a floor cell, bounded by `WALLS` (wood or
stone walls and doors). It is a home when all of these hold:

- it is closed (the fill never escapes)
- 6–60 tiles
- at least one door in its boundary
- a roof over every tile
- a light: a torch or campfire inside
- a bed: a hide bed inside

`room_at(world, cell)` → `{key, cells, valid, checks[{id,label,ok}], doors,
stone, centre}`. `survey(world)` finds every room. `describe(room)` gives
"Stone house, 12 tiles, west of the first camp".

- Room keys are the smallest cell ("x,y"). A rebuilt room with the same
  corner keeps its key.
- Roofs fade only over the room the keeper stands in:
  `ForestWorld.is_roof_open(cell)`, a roof-to-roof flood from the keeper's
  cell, cached per frame and keeper cell.

## Stone building

Items `stone_wall`, `stone_floor`, `stone_door`, `slate_roof` (`.tres`, icons
in `Forest/art/items/`). Recipes are workbench-gated (category Building) in
`CraftingManager`. Art comes from `tools/world/make_stone_art.py`. The kind
lists are `Prop.WALLS/DOORS/FLOORS/ROOFS`. `STRUCTURE_HP` is: stone wall 10,
stone floor 6, stone door 8, slate roof 5.

- Floors and roofs save their kind as the 4th element; older saves load as
  timber and thatch.
- Code that builds for the keeper must also set `world.placed[c]` and
  `props[c].is_placed`, or the build vanishes on load.

## Talking (`UI/FolkDialogue.gd`, CanvasLayer 28, pauses the tree)

A plate at the foot of the screen that grows with its page (`_fit`), so the
world stays in view. It holds:

- the portrait (the first idle-down frame)
- the name in IM Fell, the title in mint caps
- typewriter words at 70 chars/s
- the page: talk, recipes (satchel icon grid), trade (buy list and sell
  column), advice, house

E goes to whichever is nearest: a folk member (within 40 px of the feet), a
companion or a camp object (`ForestPlaytest._folk_first`). A camp object the
keeper aims at comes first. Nothing happens while mounted. The context hint
reads "E  Talk to X" or "E  Free X". E or Esc closes the plate; Esc steps
back to the talk page first.

## Folk & houses panel (`UI/FolkHousesPanel.gd`, H or the pause menu)

The Terraria housing menu, drawn in the session overlay (kind `houses`):

- head-and-shoulders buttons for everyone who has arrived (16×16 crops of
  the portrait)
- a status line: lives in… / ready / camps by the fire / waits in the wilds,
  with the direction / caught in a trap
- every room, nearest the camp first, with who lives there
- "Needs: …" in ember for rooms that aren't homes yet: the builder's
  checklist
- "Move in" (a free house) and "Swap" (someone else's, when the picked person
  has a home)
- "Leave the house"

`open(session, selected)` rebuilds after each action.

## Art

- **Characters.** PixelLab `create_character_pro_flash`, 32×32 with the Keeper's
  south view as the style reference (6 generations each). Then
  `animate_character` with `walking-8-frames` and `breathing-idle`
  (1 generation per direction, max 8 concurrent jobs). Import with
  `python tools/folk/import_folk.py <id>`: it keeps the raw zip in
  `art/folk/source/<id>/` and writes `Forest/folk/art/<id>/sheet.png` +
  `sheet.json` (rows idle/walk × down/up/left/right, `foot` = the ground
  pixel). The download needs no auth, and a 423 means animations are still
  running (it retries). `FolkActor.frames_for(id)` builds SpriteFrames from the
  sheet.
- **Sites.** Made by `tools/folk/make_folk_art.py`:
  - the hut: the rocky pack's `House.png`
  - the stranded camp: a front-on PixelLab map object, kept in
    `art/folk/source/sites/camp2.png`. Ask for "front view … facing the
    camera straight on", view `low top-down`, or it comes out isometric and
    clashes.
  - the cage: code-drawn and see-through, so the trapped person shows. The
    AI cages came out solid.
- **Physics and shadows.** `POI_SOLID` gives solid footings (hut, camp tent,
  closed cage). `POI_HEIGHT` sets how tall the outline shadow is, and
  `POI_SHADOW` holds flat ones (the open cage). The folk stand on the
  keeper's two-layer contact shadow (`FolkActor._draw_shadow`, hidden while
  wading).

## Tests and captures

- `tools/playtest_forest.ps1 -FolkPreview` (`--folk-playtest`, no-save runs
  only) is the hands-on check. It adds:
  - a cache beside the camp (open it and Tamsin comes)
  - two extra dodos nearby (tame two and Kaya comes)
  - two stone houses' worth of kit, coins and sellable finds

- `res://Tests/FolkSuite.tscn` (headless, in `tools/verify_forest.ps1` as
  `folk`) covers:
  - stone building and its saves
  - every housing rule and a closet
  - arrivals, and that sites are dry, reachable and clear
  - the trap
  - moving in, eviction and re-housing
  - swaps, and roofs opening per house
  - trade (two different rare pieces every day), tending, recipes
  - dialogue pages and sizing, E-to-talk
  - save/load, and an old journey getting Orrin
- `res://Tests/FolkLookCapture.tscn` (rendered) writes `art/folk/look-*.png`
  and `look-sheet.png`.

- Suites written before the folk run with `--no-folk` (their `UserArgs` in
  `verify_forest.ps1`: ui-pass2, interaction-pass4). Orrin stands 22 px from
  the keeper at the start and rightly takes E presses they aim at companions
  farther off. `FolkManager.enabled` is false under that flag: nobody
  arrives and nothing is raised. Add it to a new suite only if the folk are
  truly in the way, and keep the folk in everything else.

## Gotchas

- Never name a method `free()` on a Node script: it shadows `Object.free`.
  That is why it's `release()`.
- Values from untyped nodes (`manager.who_lives_in(...)`, `world.serialize()`)
  need explicit types: `var x: String = …`. `:=` fails with "Cannot infer the
  type".
- `meet()` calls `settle()` at once: with a free house, the person moves
  straight in (stage `home`, not `ready`).
- Banners queue, one at a time for about 6 s each. Several arrivals in a row
  show in order.
