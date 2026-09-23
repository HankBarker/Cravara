# Forest world contract

`ForestWorld.gd` is a self-contained, seeded 112 x 112 cell forest at 16 world pixels per cell. Instantiate under a y-sorted Node2D alongside the player. The world joins `forest_world` and also enables y sorting for its props. Terrain is rendered at z=-20, water ripples -19, built floors -18, other objects at normal y-sorted depth.

- `get_spawn_position() -> Vector2`: safe origin.
- `get_spawnable_position(preferred: Vector2) -> Vector2`: nearby dry, unblocked creature spawn.
- `is_water_at(world_position) -> bool`: wading state for player/creature movement.
- `is_blocked_at(world_position) -> bool`: wall/tree/boulder/building or outside map.
- `mine_at(world_position, tool_type: String) -> bool`: accepts `axe` for trees, `pickaxe` for rocks/walls/crystals. Three hits for trees/walls, two for rocks. Wrong tool returns false; `last_feedback` explains it. Drops real ItemDB items through DroppedItem.tscn. The caller must enforce reach and attack cadence.
- `interact_at(world_position, item_id: String) -> bool`: gathers berry bushes and fiber ferns; exchanges `bucket` / `water_bucket` in the existing inventory slot; consumes and places `wood_wall`, `wood_floor`, `campfire`, `workbench`, `torch`, `chest` on vacant dry grid cells. The caller must enforce reach and interaction cadence. Do not also consume successful actions in the caller.
- `get_interaction_hint(world_position) -> String`: hovered resource/landmark text.
- `serialize() -> Dictionary`, `restore(Dictionary)`: seed, depleted prop coordinates, water edits, constructed props and chest contents. Save via root playtest controller. Chest and torch props wrap the existing scene as `PlacedObject`; chest preserves its `chests` group/proximity API for inventory UI integration.

Solid bodies use collision layer 16, included in the existing player's mask 22. Camp objects are static physical landmarks. The outermost cells cannot be mined. A natural ford east of spawn allows passage across the river. Water is an editable single-cell volume with animated surface and wading integration, not a pressure/flow simulation.

World updates CraftingManager's nearby stations within 64px every 0.4s. Initial workbench: (-56,-88); campfire: (56,-40). World tries player group first, then sibling `Player`.

## Validation

Run `res://Forest/ForestWorldTest.tscn` headless. Assertions cover dimensions, dry safe spawn, tool restrictions, repeated mining, exact modified-world serialization, bucket fill/empty, inventory exchange, placed wall collision and persisted construction, chest content restoration, and torch light existence. The graphical fixture with user argument `--capture` writes `res://Forest/world_review.png` for visual review.

Art: native pixel tree/fern/rock regions are reused from the project's pre-existing `WorldObjects/Images/Objects.png`. No external artwork was downloaded. Tribal tents, Sky-Fang shards, workbench, mineable banks, campfire, terrain details, and water animation are new original code-drawn artwork using the project palette. This preserves existing source assets.
