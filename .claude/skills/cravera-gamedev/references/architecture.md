# Godot 4.6 Architecture & Code Patterns — Cravera Reference

Practical reference for building Cravera (2D top-down dinosaur survival/crafting) in **Godot 4.6 (Forward+)**.
Targets Godot 4.6 APIs. Anything 3.x-only is flagged explicitly. Snippets are GDScript 2.0.

---

## 1. Data-Driven Design with Resources

A `Resource` is pure data (no scene presence): cheap to load, shareable, serializable, editable in the Inspector, version-controllable. Use it for the *data things are made of* — item stats, recipes, creature definitions, biome configs.

### Custom Resource class

```gdscript
class_name ItemData
extends Resource

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export_range(1, 999) var max_stack: int = 1
@export var tool_type: StringName = &""
@export var damage: int = 0
@export var placeable: bool = false
@export_file("*.tscn") var place_scene: String = ""   # file picker in Inspector
@export_enum("", "head", "chest", "legs") var armor_slot: String = ""
@export var defense: int = 0
@export var consumable: bool = false
@export var hunger_value: int = 0
```

`@export` patterns worth knowing in 4.6:
- `@export_range`, `@export_enum`, `@export_file`, `@export_dir`, `@export_color_no_alpha`, `@export_flags` — give designers constrained, validated editor widgets.
- `@export_group("Combat")` / `@export_subgroup` organize the Inspector.
- `@export var loot: Array[LootEntry]` — typed arrays of *other* resources nest cleanly (a creature owns an array of loot resources).
- Prefer `StringName` (`&"basic_axe"`) for ids: interned, fast `==`, ideal as dictionary keys.

### `.tres` files vs code subclasses + factory

| | Code subclass + `create_item_by_id()` factory (Cravera today) | `.tres` resource files |
|---|---|---|
| Add an item | New `.gd` file **and** a `match` arm in the factory | Drop a `.tres` in a folder — zero code |
| Tweak a stat | Edit code, re-read | Edit in Inspector, hot-reloads |
| Type safety | Yes | Yes |
| Designer-friendly | No | Yes (no scripting) |
| Risk | `match` and subclass list drift out of sync | Must guard against orphaned/renamed ids |
| Behavior (methods) | Easy — it's a class | Data-only; behavior lives elsewhere (strategy resource or `tool_type` dispatch) |

`.tres` is text (diff-friendly, merge-able); `.res` is binary (smaller/faster, not human-editable). Convention: **`.tres` in dev, optionally bake to `.res` for release.** Sources: [GDQuest custom resources], [Simon Dalvai].

### Resource-as-database pattern

Load every item once at startup into a registry keyed by id — replaces the `match` factory:

```gdscript
# ItemDB.gd (autoload)
extends Node
var _items: Dictionary = {}   # StringName -> ItemData

func _ready() -> void:
    for path in DirAccess.get_files_at("res://Data/Items"):
        if path.ends_with(".tres"):
            var item := load("res://Data/Items/" + path) as ItemData
            _items[item.id] = item

func get_item(id: StringName) -> ItemData:
    return _items.get(id)
```

> **Immutability:** Resources are **shared by reference** by default. Treat `.tres` definitions as read-only templates. For per-instance mutable state (durability, a chest's contents) call `item.duplicate()` at the mutation boundary, or — better — keep runtime state in a *separate* lightweight object so the definition stays canonical.

`preload()` (compile-time, resolved at parse) vs `load()`/`ResourceLoader.load_threaded_request()` (runtime; use threaded loading for large/streamed assets so you don't stall the frame).

---

## 2. Decoupling: Autoloads + Global SignalBus

Cravera's pattern — autoload singletons (`SignalBus`, `InventoryManager`, `CraftingManager`, `AudioManager`, `TimeCycle`, `SaveManager`) plus a global `SignalBus` of named signals — is the right default for a project this size.

**When the SignalBus is enough:** cross-cutting "something happened" facts that many unrelated systems care about — `inventory_changed`, `creature_defeated`, `player_died`, `object_placed`. The emitter doesn't know or care who listens.

**Pitfalls (signal spaghetti):**
- Untraceable flow — clicking a signal in the editor doesn't reveal listeners across autoloads. Mitigate with **strict naming + ownership**.
- Bidirectional chatter — if A emits to B *and* B emits back to A through the bus, you've hidden a direct dependency. Use a direct reference instead.
- Stale connections — connecting in a node's `_ready` without disconnecting on `queue_free()` leaks. Prefer `signal.connect(cb, CONNECT_ONE_SHOT)` for one-offs, or connect/disconnect in state `enter`/`exit`.

**Naming / ownership conventions:**
- Past tense for facts (`object_destroyed`), not commands (`destroy_object`).
- Group by domain with comment banners (Cravera already does this).
- One owner *emits* a given signal; everyone else only *listens*. Document the owner in a comment.

**Decision guide — bus vs direct ref vs DI:**
- **Global SignalBus** — broadcast events with many/unknown listeners.
- **Direct reference / local signal** — a parent owns a child (player → its state machine, creature → its hurtbox). Don't route parent↔child through the global bus.
- **Dependency injection** (pass the dep into `_ready`/a setter, or `@export var target: Node`) — when a node needs a *specific* collaborator. Cleaner than reaching into `/root/...` paths, which couple you to the scene tree layout.

Avoid `get_node("/root/Playground/Player")` (as in `trex.gd`) — it breaks if the scene is renamed or run standalone. Prefer `get_tree().get_first_node_in_group("player")` (the player already `add_to_group("player")`s).

---

## 3. Component Composition

"Favor composition over inheritance." Build entities from small reusable nodes rather than deep class hierarchies.

### Hurtbox / Hitbox (Area2D) pattern

Two Area2Ds on separate layers/masks: a **Hitbox** *deals* damage, a **Hurtbox** *receives* it. They only interact via layer/mask, so any entity gains combat by adding the nodes.

```gdscript
class_name Hurtbox
extends Area2D
signal damaged(amount: int, source: Node)

func _ready() -> void:
    area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
    if area is Hitbox:
        damaged.emit(area.damage, area.owner)
```

Cravera already does an ad-hoc version (player `SwordHitbox`, T-Rex `AttackArea` + `Hurtbox` + `AggroRange`). Formalizing `Hitbox`/`Hurtbox` `class_name`s removes the brittle `if area.name == "PlayerHurtbox"` string checks in `trex.gd`.

### Reusable component nodes

```gdscript
class_name HealthComponent
extends Node
signal died
signal health_changed(current: int, max: int)
@export var max_health: int = 10
var current: int

func _ready() -> void: current = max_health
func take_damage(amount: int) -> void:
    current = max(0, current - amount)
    health_changed.emit(current, max_health)
    if current == 0: died.emit()
```

Now T-Rex and player share one health implementation; the entity wires `HealthComponent.died` to its own death handler. Same idea for `HurtboxComponent`, `LootComponent`, `StateMachine`.

**Map physics layers** (Cravera: 1=Player, 5=Walls, 6=Ground, 7=Interaction) onto component masks so a component is drop-in configurable.

### When is a 2D ECS justified?

Almost never for Cravera. Godot's node + component-node composition covers hundreds of mixed entities fine. Reach for a data-oriented/ECS approach only at **thousands** of homogeneous, hot-loop entities (bullet-hell, particle-like swarms) where per-node overhead dominates — and even then, prefer servers/MultiMesh (§6) before a full ECS framework.

---

## 4. State Machines

Three idioms:

- **enum + match** — fewest files, fine for ≤4 trivial states. Logic crammed in one script; scales poorly.
- **Node-based FSM** — one `Node` per state with `enter/update/exit`; visible & debuggable in the tree. Cravera's player uses a dictionary-of-states variant (`Idle/Walk/Run/Attack/Hurt/Dead`, `switch_state()`). This is the recommended default and matches GDQuest/Godot community practice. Sources: [GDQuest FSM], [Godot Foundry].
- **Pushdown automaton (PDA)** — a *stack* of states; "push" a temporary state (Stunned) and "pop" back to whatever was underneath (Run vs Idle) without storing it. Worth it for Cravera's `Hurt`/`Stunned` so the creature/player resumes its prior state instead of hard-coding a return to `idle`.

### Clean reusable StateMachine template (4.6)

```gdscript
# State.gd
class_name State
extends Node
var machine: StateMachine
func enter() -> void: pass
func exit() -> void: pass
func update(_delta: float) -> void: pass
func physics_update(_delta: float) -> void: pass

# StateMachine.gd
class_name StateMachine
extends Node
@export var initial: State
var current: State

func _ready() -> void:
    for c in get_children():
        if c is State: c.machine = self
    await owner.ready
    current = initial
    current.enter()

func _physics_process(delta: float) -> void:
    if current: current.physics_update(delta)

func transition_to(name: StringName) -> void:
    var next := get_node_or_null(String(name)) as State
    if not next or next == current: return
    current.exit()
    current = next
    current.enter()
```

Connect Hurtbox signals **inside** `enter()` and disconnect in `exit()` so a state only listens while active. **Footgun:** Cravera's `Attack.gd` chains `create_timer().timeout` callbacks — if the node frees mid-swing those fire on a dead instance. Guard with `is_instance_valid(self)` (it already does for the hitbox) or `CONNECT_ONE_SHOT`, and prefer the state machine to drive timing over loose timers.

---

## 5. Save / Load

| Method | Format | Godot types | Security | Verdict for Cravera |
|---|---|---|---|---|
| `JSON.stringify` + `FileAccess` | text | manual (Vector2 → dict) | **Safe** (no code) | ✅ current Cravera approach — keep |
| `FileAccess.store_var/get_var` | binary | native (Vector2, Color…) free | **Safe by default** (object serialization off) | ✅ good for large/typed saves |
| `ResourceSaver` + custom Resource | `.tres`/`.res` | native | ⚠️ **A loaded resource can carry embedded scripts → code execution** | ❌ do **not** load player-writable saves this way |

Key fact: `store_var()`/`get_var()` use the engine's safe binary serializer (same one as multiplayer) and **disable object/script loading by default** — only pass `full_objects = true` if you fully trust the source. `ResourceLoader.load()` on an untrusted `.tres` is a real exploit vector. Sources: [GDQuest save], [Godot FileAccess docs].

**What to persist (Cravera, per `SaveManager.gd`):**
- Player: position, health, hunger, stamina, inventory (as `{id, qty}`), equipped armor (by id).
- World: `time_of_day` (TimeCycle), placed objects (id + position + per-object `get_save_data()`), chest contents.
- Creatures: only if persistent/tamed — id, position, health, tame/breeding state.
- **Save ids and quantities, not Resource instances.** Reconstruct from `ItemDB`/factory on load. This sidesteps the resource-security problem entirely. Cravera already does this correctly.

**Versioning / migration:** stamp `{"version": 3, ...}` at the top. On load, if `version < CURRENT`, run ordered migration functions (`_migrate_1_to_2`, …). Without this, an added field or renamed id silently corrupts old saves.

**Recommended for Cravera:** keep the **JSON + id-based** scheme. Add a `version` field now (cheap insurance). Consider `store_var` only if save size/parse time becomes a problem with large worlds — JSON is the right call while saves are human-inspectable and small.

---

## 6. Performance at Scale (hundreds of entities)

- **`_physics_process` budget:** every active creature running AI each physics tick is the #1 cost. Cravera's T-Rex does `distance_to(player)` every tick — fine for a few, not for hundreds.
- **Toggle off-screen entities:** add a `VisibleOnScreenNotifier2D`; on `screen_exited` call `set_physics_process(false)` (and `set_process(false)`); re-enable on `screen_entered`. Far cheaper than culling in code.
- **Throttle AI:** don't recompute pathing/aggro every tick. Use a `Timer` or frame-stagger (`if Engine.get_physics_frames() % 6 == id % 6`) so creatures think ~10×/sec, spread across frames.
- **Object pooling:** for frequently spawned/freed things (dropped items, hit particles, projectiles) keep a pool and `visible=false`/reparent instead of `instantiate()`/`queue_free()` churn (GC + scene-tree cost). Cravera's `DroppedItem.tscn` spawns are a prime candidate.
- **Group queries:** `get_tree().get_nodes_in_group("creatures")` once per frame beats N independent scene-tree walks.
- **`MultiMeshInstance2D`:** for **thousands** of identical, mostly-static visuals (grass, foliage, decorative tiles) — one draw call for all instances. For thousands needing constant per-instance logic, talk to the `RenderingServer`/`PhysicsServer2D` directly (no node overhead). Sources: [Godot MultiMesh docs].
- **TileMapLayer**, not per-node tiles, for the ground/world (see §7).
- **Profile first:** Editor → **Debugger → Profiler** (script time) and **Monitors** (object/node counts, draw calls, physics). Optimize what's actually hot, not what you guess.

Rule of thumb: hundreds of entities is comfortable in Godot 4.6 *if* off-screen ones are dormant and on-screen AI is throttled. You don't need an ECS to hit that.

---

## 7. Project Organization & GDScript Style

**Folder layout** (Cravera already largely follows this): group by domain — `Autoloads/`, `Items/`, `Player/{Scripts,States}`, `Sprites/` (creatures), `WorldObjects/`, `Systems/`, `UI/`, `Data/*.json`. Add a `Data/Items/`, `Data/Recipes/`, `Data/Creatures/` for `.tres` if you migrate (§1).

**Naming:** `PascalCase` for nodes/classes/scenes, `snake_case` for vars/funcs/files-with-scripts, `SCREAMING_SNAKE` for consts, `_leading_underscore` for private. Keep `class_name` on anything referenced by type.

**Typed GDScript — do it everywhere:**
```gdscript
var speed: float = 100.0
func chase(target: Node2D) -> Vector2:
    return (target.global_position - global_position).normalized()
```
Static typing isn't just safety — the 4.x compiler emits **typed instructions** that skip runtime type resolution, a measurable perf win in hot loops, plus editor autocomplete and earlier errors.

- **`@onready`** for node refs resolved at scene-ready: `@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D`. Cleaner than assigning in `_ready`.
- **`await` pitfalls:** after `await`, the node may be freed — guard with `if not is_instance_valid(self): return`. Don't `await` inside `_physics_process`. `await` on a signal that never fires hangs that coroutine forever.
- **TileMap deprecation (4.3+):** `TileMap` is **deprecated**; use one **`TileMapLayer`** node per layer sharing a `TileSet`. The editor offers one-click conversion, but it **doesn't reach tilemaps inside instanced scenes or `.tres`** — those need manual migration. Build Cravera's world on `TileMapLayer` from the start. Source: [GameFromScratch / TileMapLayer].
- Other 4.x footguns: `randi_range` not `rand_range`; signals are first-class objects (`sig.connect(cb)`, `sig.emit()`); `yield` is gone (→ `await`); `instance()` → `instantiate()`; `KinematicBody2D` → `CharacterBody2D` with `velocity` + `move_and_slide()` (no argument).

---

## How this maps to Cravera

Prioritized, concrete recommendations against the real files:

1. **Migrate `create_item_by_id()` → `.tres` ItemData + an `ItemDB` autoload registry (highest leverage).** The `match` factory in `CraftingManager.gd` already lists ~13 items and is duplicated as a dependency in `SaveManager._restore_inventory`, `_restore_armor`, and `_respawn_placed_object`. Every new item touches code in 4 places. Convert `Item` (`game/Items/Item.gd`) consumers to load `res://Data/Items/*.tres` into an `ItemDB` keyed by `StringName` id; `CraftingManager`/`SaveManager` then call `ItemDB.get_item(id)`. Recipes (`personal_recipes` array) become `RecipeData` `.tres` similarly. Keep ids as the save format — no security/migration regression. Behavior that currently lives in subclasses (if any) moves to `tool_type` dispatch or a small strategy resource.

2. **Add save versioning and harden node lookups now (cheap, prevents future pain).** Stamp `"version"` into `SaveManager._collect_state()` and branch in `_apply_state()` — costs nothing today, saves corrupted saves later. Keep the JSON+id approach (it's correct and safe — do **not** switch to `ResourceSaver` for player saves). Separately, replace `get_node("/root/Playground/Player")` in `trex.gd` with `get_tree().get_first_node_in_group("player")` so creatures work when the scene is renamed or run standalone.

3. **Extract shared `HealthComponent` + formal `Hitbox`/`Hurtbox` classes, and throttle creature AI.** `trex.gd` reimplements health, a hand-rolled health bar, and string-matched combat (`if area.name == "PlayerHurtbox"`) that the player will duplicate as more creatures arrive. A reusable `HealthComponent` (`died`/`health_changed` signals) and typed `Hitbox`/`Hurtbox` (`class_name`, layer-based) de-duplicate this and kill the brittle name checks. While there, gate creature `_physics_process` behind a `VisibleOnScreenNotifier2D` and stagger the aggro distance check — required before the world holds dozens of dinosaurs. Consider promoting `Hurt` to a **pushdown** state so entities resume their prior state instead of always returning to `idle`.

### Sources
- [Custom Resources / data-driven design — GDQuest](https://www.gdquest.com/) · [Simon Dalvai](https://simondalvai.org/blog/godot-custom-resources/) · [Godot Resources docs](https://docs.godotengine.org/en/stable/tutorials/scripting/resources.html)
- [Saving & Loading in Godot 4 — GDQuest](https://www.gdquest.com/library/save_game_godot4/) · [FileAccess](https://docs.godotengine.org/en/stable/classes/class_fileaccess.html) · [ResourceSaver](https://docs.godotengine.org/en/stable/classes/class_resourcesaver.html)
- [Finite State Machine — GDQuest](https://www.gdquest.com/tutorial/godot/design-patterns/finite-state-machine/) · [Node-Based FSM — Godot Foundry](https://godotfoundry.com/blog/godot-4-state-machine-tutorial) · [Pushdown Automaton addon](https://github.com/godot-addons/godot-pushdown-automaton)
- [Optimization using MultiMeshes](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html) · [MultiMeshInstance2D](https://docs.godotengine.org/en/stable/classes/class_multimeshinstance2d.html)
- [TileMap → TileMapLayer migration — GameFromScratch](https://gamefromscratch.com/godot-tilemap-replaced-with-tilelayers/) · [TileMapLayer docs](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html)
