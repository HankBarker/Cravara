# Creature AI, Movement & Taming (Godot 4.6)

Reference for Cravera creature behavior: AI architecture, steering, pathfinding,
group/ecosystem AI, combat & bosses, ARK-style taming/breeding, and animation sync.
All snippets target **Godot 4.6** (`NavigationAgent2D`, `CharacterBody2D`,
`AStarGrid2D`). 3.x-only advice is flagged.

> Cravera baseline: `game/Sprites/trex.gd` is a `CharacterBody2D` with a hand-rolled
> FSM in `_physics_process` (wander -> chase -> attack -> hurt -> die), **no
> pathfinding** (moves straight at the player), random-cardinal wander, and night
> boosts via `TimeCycle`. The MCP `generate_creature` emits an enum-FSM template
> (`State.IDLE/WANDER/CHASE/ATTACK/HURT/DEATH`). Creatures emit
> `SignalBus.creature_defeated` and drop loot via `DroppedItem.tscn`. Stats live in
> `Data/creatures.json`.

---

## 1. AI Architectures: pick the lightest tool that fits

| Arch | What it is | Strength | When to upgrade to it | Cost |
|------|-----------|----------|----------------------|------|
| **FSM (flat)** | One state active; explicit transitions. Cravera today. | Trivial to read/debug, cheap. | Default for <~6 states. | Transition explosion at scale (N² edges). |
| **Hierarchical SM (HSM)** | States nest; parent handles shared logic (e.g. "Combat" -> Chase/Attack/Reposition). | Reuse, fewer duplicate transitions, clean "interrupt to Flee" from any sub-state. | When several states share entry/exit (hurt, flee, stagger). | Slightly more plumbing. |
| **Behavior Tree (BT)** | Tree of Sequence/Selector/Decorator/Leaf nodes ticked each frame. | Composable, designer-friendly, great for layered priorities (flee > attack > wander). | When AI has many conditional behaviors or you want data-driven reuse across creatures. | Tick overhead; harder to express "sticky" states. |
| **Utility AI** | Each action scores 0..1 from world inputs; highest wins. | Emergent, smooth priority blending (hungry vs scared vs aggressive). | Ecosystem/herd creatures with competing drives. | Tuning curves is fiddly; non-deterministic feel. |
| **GOAP** | Planner chains actions to reach a goal state. | Genuinely emergent, replans on failure. | Rarely needed for survival-game fauna. | Heavy; overkill for Cravera. |

**Recommended evolution path for Cravera (don't throw away the FSM):**
1. Keep the enum FSM as the **top-level** controller (it already maps to animation
   states cleanly).
2. Promote to a tiny **HSM**: add a `Combat` super-state grouping CHASE/ATTACK/
   REPOSITION, and a global `interrupt()` that any state can call to force HURT/FLEE.
3. For complex creatures/bosses, run a **BT-lite** *inside* a single FSM state
   (e.g. inside ATTACK, a Selector chooses bite/charge/ground_slam). This is the
   80/20 win: FSM for coarse mode, BT for tactical choice.
4. Reserve Utility AI for herd/ecosystem drives (section 4).

### Reusable BT-lite skeleton (no plugin, ~plain GDScript)
```gdscript
# Status enum returned by every node
enum BT { SUCCESS, FAILURE, RUNNING }

class BTNode:
    func tick(agent, delta: float) -> int: return BT.FAILURE

class Sequence extends BTNode:          # AND: fail/run on first non-success
    var children: Array[BTNode]
    func tick(agent, delta):
        for c in children:
            var s = c.tick(agent, delta)
            if s != BT.SUCCESS: return s
        return BT.SUCCESS

class Selector extends BTNode:          # OR: succeed/run on first non-failure
    var children: Array[BTNode]
    func tick(agent, delta):
        for c in children:
            var s = c.tick(agent, delta)
            if s != BT.FAILURE: return s
        return BT.FAILURE

# Leaf example
class FleeIfLowHP extends BTNode:
    func tick(agent, delta):
        if agent.health > agent.max_health * 0.25: return BT.FAILURE
        agent.flee_from(agent.player.global_position, delta)
        return BT.RUNNING
```
Tick the root once per `_physics_process`. Keep state on `agent`, not the tree, so
trees are shareable across instances. For a full plugin, **LimboAI** ships HSM+BT
nodes for Godot 4 — adopt only if hand-rolled trees get unwieldy.

**HSM idea (lighter than BT, closest to current code):** group sub-states under a
super-state and run global interrupts first, so e.g. HURT/FLEE can fire from any mode:
```gdscript
func _physics_process(delta):
    if health <= 0: state = "death"          # global transitions from ANY state
    elif _was_hurt: state = "hurt"
    match state:
        "wander", "idle":                _mode_passive(delta)
        "chase", "attack", "reposition": _mode_combat(delta)   # shared super-state
```

---

## 2. Steering behaviors in 2D (Reynolds), with CharacterBody2D

Steering = compute a desired velocity, steer current velocity toward it, write to
`velocity`, then `move_and_slide()`. Far better than random-cardinal wander.

```gdscript
@export var max_speed := 60.0
@export var max_force := 240.0      # accel cap (units/s^2-ish); higher = snappier
var steer := Vector2.ZERO

func _apply(desired: Vector2) -> void:
    var force := (desired - velocity).limit_length(max_force)
    velocity = (velocity + force * get_physics_process_delta_time()).limit_length(max_speed)

func seek(target: Vector2) -> Vector2:
    return global_position.direction_to(target) * max_speed

func flee(threat: Vector2) -> Vector2:
    return threat.direction_to(global_position) * max_speed

func arrive(target: Vector2, slow_radius := 48.0) -> Vector2:
    var to := target - global_position
    var d := to.length()
    if d < 1.0: return Vector2.ZERO
    var speed := max_speed * (clamp(d / slow_radius, 0.0, 1.0))
    return to / d * speed                       # eases to a stop, no overshoot

# Pursue/Evade: lead the target by its velocity
func pursue(t_pos: Vector2, t_vel: Vector2) -> Vector2:
    var lead := global_position.distance_to(t_pos) / max_speed
    return seek(t_pos + t_vel * lead)

# PROPER wander: a point on a circle ahead, jittered each frame (smooth, organic)
var _wander_angle := 0.0
func wander() -> Vector2:
    _wander_angle += randf_range(-0.5, 0.5)     # jitter
    var ahead := velocity.normalized() * 24.0 if velocity.length() > 1.0 else Vector2.RIGHT * 24.0
    var circle := Vector2(cos(_wander_angle), sin(_wander_angle)) * 12.0
    return (ahead + circle).normalized() * max_speed * 0.5
```
**Obstacle avoidance (cheap raycast whisker):** cast a `RayCast2D` along `velocity`;
if it hits, add a lateral push `hit_normal * max_force`. For real maps, prefer
`NavigationAgent2D` avoidance (section 3). **Separation** is in section 4.

Combine behaviors by weighted sum, then `_apply()` the result:
`_apply(wander()*0.4 + separation()*1.0 + avoid()*1.5)`.

---

## 3. Pathfinding in Godot 4.6 (Cravera has none — add this)

Two systems. **Pick one per creature type; mixing is normal.**

### A) NavigationRegion2D + NavigationAgent2D — free-form motion, mostly-static maps
> In 4.6, `NavigationAgent2D`/`NavigationObstacle2D` avoidance is still marked
> **Experimental**. Stable enough to ship; expect minor API churn.

**Setup:** add a `NavigationRegion2D`, give it a `NavigationPolygon`. Bake from a
`TileMapLayer` by either (a) enabling **Navigation layers** in the TileSet so source
geometry comes from painted tiles, then `region.bake_navigation_polygon()`, or
(b) drawing the polygon manually for simple arenas. Add a `NavigationAgent2D` child
to each creature.

```gdscript
@onready var agent: NavigationAgent2D = $NavigationAgent2D

func _ready() -> void:
    agent.path_desired_distance = 4.0
    agent.target_desired_distance = 8.0
    agent.avoidance_enabled = true                 # local collision avoidance (RVO)
    agent.velocity_computed.connect(_on_velocity_computed)
    # First-frame guard: nav map isn't synced yet — set target deferred.
    call_deferred("_set_target", player.global_position)

func _set_target(p: Vector2) -> void:
    agent.target_position = p

func _physics_process(_delta: float) -> void:
    # Skip until the navigation map has synchronized at least once.
    if NavigationServer2D.map_get_iteration_id(agent.get_navigation_map()) == 0:
        return
    if agent.is_navigation_finished():
        return
    agent.target_position = player.global_position             # repath each frame in chase
    var next := agent.get_next_path_position()
    var desired := global_position.direction_to(next) * chase_speed
    if agent.avoidance_enabled:
        agent.set_velocity(desired)        # -> emits velocity_computed (safe vel)
    else:
        _on_velocity_computed(desired)

func _on_velocity_computed(safe_velocity: Vector2) -> void:
    velocity = safe_velocity
    update_facing(velocity)                # reuse trex.gd facing logic
    move_and_slide()
```
Useful signals: `velocity_computed` (avoidance result — you MUST move with this when
avoidance is on), `navigation_finished`, `target_reached`, `waypoint_reached`,
`path_changed`. Don't repath every frame for idle creatures — throttle (section 4).

### B) AStarGrid2D — tile-locked worlds, frequent runtime blockers
Better than navmesh when movement is grid-aligned, the world changes often (placed
walls/objects — Cravera has a `PlacementController`), or you need to *explain* why a
path failed. Stable since 4.x.
```gdscript
var grid := AStarGrid2D.new()
func build_grid(tilemap: TileMapLayer) -> void:
    grid.region = tilemap.get_used_rect()
    grid.cell_size = tilemap.tile_set.tile_size
    grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
    grid.update()
    for cell in tilemap.get_used_cells():
        if _is_solid(tilemap, cell):
            grid.set_point_solid(cell, true)        # cheap dynamic blocker toggle

func path_to(from_world: Vector2, to_world: Vector2, tilemap) -> PackedVector2Array:
    var a := tilemap.local_to_map(tilemap.to_local(from_world))
    var b := tilemap.local_to_map(tilemap.to_local(to_world))
    return grid.get_point_path(a, b)                # world-space points to follow
```
Follow the returned points with `arrive()`/`seek()` from section 2.

**Rule of thumb:** navmesh for smooth free-roaming predators; AStarGrid2D for
grid/base-building contexts. Re-`update()` / toggle `set_point_solid` when the player
places or destroys objects.

---

## 4. Group & ecosystem AI

### Boids / flocking (herds of herbivores) — separation is the must-have
```gdscript
@export_flags_2d_physics var herd_mask := 0
func separation(radius := 28.0) -> Vector2:
    var push := Vector2.ZERO
    for other in get_tree().get_nodes_in_group("herd"):
        if other == self: continue
        var off := global_position - other.global_position
        var d := off.length()
        if d > 0.0 and d < radius:
            push += off / (d * d)          # closer = stronger, inverse-square
    return push.normalized() * max_speed if push != Vector2.ZERO else Vector2.ZERO
# Full boids = separation + alignment (match avg neighbor velocity) + cohesion
# (steer toward avg neighbor position). Weight separation highest.
```
For perception use **spatial queries**, not O(N²) loops at scale: an `Area2D`
"senses" ring per creature, or `PhysicsDirectSpaceState2D.intersect_shape()` for
on-demand neighbor scans. The group-loop above is fine for <~30 creatures.

**Predator/prey & packs:** prey runs `flee()` from any creature in `predators`
group within sense radius; predators `pursue()`. **Aggro propagation:** when one pack
member enters CHASE, emit a local signal — `SignalBus` could gain
`creature_alerted(source, target)` — and nearby same-species creatures flip to CHASE
(a "call for help" within radius). Coordinated packs: assign roles (one flanks via an
offset `arrive` target, others seek directly).

### Performance: AI LOD & time-slicing (essential for survival-game density)
- **Distance LOD:** if `> N` px from camera/player, `set_physics_process(false)` or
  drop to a cheap "frozen" tick (no pathfinding, no animation). Re-enable on approach.
- **Time-slicing:** stagger expensive work (repaths, neighbor scans) across frames —
  e.g. `if Engine.get_physics_frames() % 8 == instance_id % 8:` so only 1/8 of
  creatures repath per frame.
- **Shared blackboard:** a small autoload/`Resource` per faction holding `last_known_
  player_pos`, `alert_level`, herd centroid — so creatures don't each re-query.
- Cap active AI; despawn far creatures and respawn from the `creature_spawn_table`.

---

## 5. Combat AI: telegraphs, windups, bosses

Readable combat = **windup (telegraph) -> active (hitbox on) -> recovery (vulnerable)**.
Cravera's bite already does this loosely (anim + `AttackArea.monitoring` on for 0.3s).
Formalize it:
```gdscript
enum Atk { WINDUP, ACTIVE, RECOVERY }
func do_attack(name: String) -> void:
    state = "attack"; velocity = Vector2.ZERO
    sprite.play(name + "_windup_" + last_facing)   # TELL: clear pixel-art pose/flash
    await get_tree().create_timer(0.35).timeout     # windup — player can react/dodge
    attack_area.monitoring = true                   # ACTIVE frames
    sprite.play(name + "_strike_" + last_facing)
    await get_tree().create_timer(0.15).timeout
    attack_area.monitoring = false
    sprite.play(name + "_recover_" + last_facing)    # RECOVERY — punish window
    await get_tree().create_timer(0.40).timeout
    _end_attack()
```
- **Readable tells in pixel art:** a held wind-up pose, a 1–2 frame white/color flash
  (`modulate`), a ground-marker `Sprite2D`/`Line2D` for AoE, or a brief screen shake
  on impact. The windup duration *is* the player's reaction budget — keep it visible.
- **I-frames interplay:** during ACTIVE frames the player's dodge should grant
  i-frames; expose attack windows long enough to dodge through.
- **Ranged vs melee:** ranged kites — `if dist < min_range: flee else if dist >
  max_range: seek else: strafe & fire`. Spawn a projectile scene on the ACTIVE frame.
- **Multi-phase BOSS patterns** (Core Keeper/Terraria style): drive phases off HP
  thresholds, each phase a state with its own attack pool (BT-lite Selector picks the
  next move, weighted/anti-repeat). Optionally lock an arena with collision walls.
```gdscript
func _check_phase() -> void:
    var pct := float(health) / max_health
    var next := 0 if pct > 0.66 else (1 if pct > 0.33 else 2)
    if next != phase:
        phase = next
        _telegraph_phase_transition()   # roar anim, brief invuln, spawn adds
```

---

## 6. Taming & breeding (ARK-style, in 2D)

Add a **TamingComponent** (child node) rather than bloating the creature script, so
wild/tamed share one creature scene. Three taming loops to choose from:
- **Knock-out + feed** (classic ARK): reduce a `torpor` stat with ranged hits; while
  unconscious, feed preferred food over time; tame % fills.
- **Passive feed / befriend:** approach calmly, feed from hotbar; each accepted feed
  raises affinity. Gentler, good for herbivores.
- **Bola/trap then feed:** immobilize, then passive-feed.

**Taming effectiveness (TE):** starts at 100%, drops with each food eaten and with
damage taken while taming. Higher TE -> more post-tame stat levels and better stats.
```gdscript
# TamingComponent.gd  (child of the creature CharacterBody2D)
extends Node
@export var required_food := "TRexMeat"
@export var feeds_needed := 5
var taming_progress := 0.0          # 0..1
var taming_effectiveness := 1.0     # 0..1, decays as it eats
func feed(item_id: String) -> void:
    if item_id != required_food: taming_effectiveness *= 0.9; return
    taming_progress += 1.0 / feeds_needed
    taming_effectiveness = max(0.5, taming_effectiveness - 0.04)
    if taming_progress >= 1.0:
        _finish_tame()
func _finish_tame() -> void:
    var owner_creature := get_parent()
    var bonus_levels := int(round(taming_effectiveness * 10))   # TE -> extra levels
    owner_creature.set_meta("tamed", true)
    owner_creature.set_meta("owner_id", "player")
    SignalBus.creature_tamed.emit(owner_creature)   # signal already exists
```

**Orders for tamed creatures** (follow / stay / aggressive — a small enum the FSM
respects above wander/chase):
```gdscript
enum Order { FOLLOW, STAY, AGGRESSIVE, PASSIVE }
var order := Order.FOLLOW
# In FSM: FOLLOW -> arrive(player.global_position) keeping a leash distance;
# STAY -> hold home_pos; AGGRESSIVE -> chase nearest hostile in sense radius.
```

**Data: extend `Data/creatures.json`** (per-creature template + per-instance saves).
Add to each creature definition:
```jsonc
{
  "trex": {
    "display_name": "T-Rex", "creature_type": "predator", "rarity": "rare",
    "stats": { "health": 8, "damage": 20, "move_speed": 20, "chase_speed": 40 },
    "tameable": true,
    "taming": { "method": "knockout", "food": "TRexMeat", "feeds_needed": 8,
                 "torpor_max": 500, "preferred_kibble": "raptor_egg" },
    "breeding": { "can_breed": true, "gestation_sec": 300, "maturation_sec": 1800,
                   "imprint_interval_sec": 480 },
    "inheritable_stats": ["health", "damage", "move_speed", "stamina"]
  }
}
```
Per **instance** (runtime/save), track the genome so inheritance works:
```gdscript
# stats are stored as LEVELS per inheritable stat, plus a mutation counter
var genome := {
    "levels": {"health": 30, "damage": 22, "move_speed": 18, "stamina": 25},
    "mut_matrilineal": 0, "mut_patrilineal": 0,
    "te_at_tame": 1.0, "imprint": 0.0,
}
```

**Breeding + inheritance + mutation math** (ARK-style, tunable):
```gdscript
func breed(mother: Dictionary, father: Dictionary) -> Dictionary:
    var child := {"levels": {}, "mut_matrilineal": 0, "mut_patrilineal": 0,
                  "te_at_tame": 1.0, "imprint": 0.0}
    for stat in mother.levels:
        # 55% chance to inherit the HIGHER parent's stat (ARK), else the other.
        var hi: int = max(mother.levels[stat], father.levels[stat])
        var lo: int = min(mother.levels[stat], father.levels[stat])
        child.levels[stat] = hi if randf() < 0.55 else lo
    # Mutation: ~7.31% overall, applied per parent line if its counter < 20.
    var counter := mother.mut_matrilineal + mother.mut_patrilineal
    if counter < 20 and randf() < 0.0731:
        var s: String = child.levels.keys().pick_random()
        child.levels[s] += 2                 # +2 levels per mutation (ARK)
        child.mut_matrilineal = counter + 1   # mutation counter ticks up
    return child
```
**Imprinting:** during maturation, periodic care interactions raise `imprint` (0..1);
higher imprint grants a flat stat/damage bonus and loyalty to the imprinter. Offspring
are computed *as if tamed at 100% TE*, so good breeding can exceed wild stats.

---

## 7. Animation-driven AI (sync AnimatedSprite2D with state)

Cravera already derives `last_facing` from velocity and plays `walk_<dir>` /
`bite_<dir>`. Keep that 4-direction selector; centralize it:
```gdscript
func update_facing(dir: Vector2) -> void:
    if dir.length() < 0.1: return
    last_facing = ("right" if dir.x > 0 else "left") if abs(dir.x) > abs(dir.y) \
        else ("down" if dir.y > 0 else "up")

func play_for_state() -> void:
    var base := {"wander":"walk","chase":"walk","attack":"bite",
                 "hurt":"hurt","death":"death"}.get(state, "walk")
    var anim := base + "_" + last_facing
    if sprite.sprite_frames.has_animation(anim) and sprite.animation != anim:
        sprite.play(anim)
    elif base in ["wander","chase"] and velocity.length() < 1.0:
        sprite.pause()        # fall back to first walk frame as idle (current trick)
```
**Hitbox timing via `AnimationPlayer` call-method tracks:** instead of hard-coded
`await ...timeout`, add an `AnimationPlayer`, give the strike animation **Call Method
Track** keyframes that call `_enable_hitbox()` / `_disable_hitbox()` on the exact
frames. This keeps tells, hitbox windows, and sprites perfectly in sync and lets
artists retune without touching code. Use `animation_finished` to return to the FSM.
Connect `frame_changed` on `AnimatedSprite2D` if you must trigger off a specific
sprite frame instead.

---

## How this maps to Cravera

Prioritized upgrades to `trex.gd` and the `generate_creature` MCP template
(`godot_mcp/tools/creature_generator.py`):

1. **Replace random-cardinal wander with proper `wander()` steering** (section 2).
   Smallest, highest-readability win; drop it into both `trex.gd` `wander()` and the
   template's `set_new_wander_direction`/`_process_wander`. Keep the enum FSM.
2. **Add `NavigationAgent2D` + `velocity_computed` chase** (section 3A) so creatures
   stop walking into walls/placed objects. Add the node to the scene the generator
   emits (alongside Hurtbox/AttackArea/AggroRange) and swap `_process_chase`'s
   straight-line steering for `get_next_path_position()`. Add `AStarGrid2D` as the
   alt path for base/grid contexts that integrates with `PlacementController`.
3. **Add a `TamingComponent` child + extend `creatures.json`** (section 6) with
   `tameable`/`taming`/`breeding`/`inheritable_stats`, and use the existing
   `SignalBus.creature_tamed` signal. This unlocks the ARK north-star with no rewrite
   of the combat FSM.

Then, as creatures grow: formalize combat into windup/active/recovery with
`AnimationPlayer` call-method tracks (section 5/7); add HP-threshold boss phases for
miniboss/boss `creature_type`s; add `creature_alerted` to `SignalBus` for pack aggro
propagation (section 4); and apply distance LOD + time-sliced repaths once spawn
density climbs.

---

### Sources
- NavigationAgent2D usage (set_velocity / velocity_computed / get_next_path_position): https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationagents.html
- NavigationAgent2D class ref: https://docs.godotengine.org/en/stable/classes/class_navigationagent2d.html
- 2D navigation overview: https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_introduction_2d.html
- AStarGrid2D class ref: https://docs.godotengine.org/en/stable/classes/class_astargrid2d.html
- AStarGrid2D vs navmesh (when to use each): https://vav-labs.com/blog/godot-pathfinding-grid-vs-navmesh/
- AStarGrid2D from TileMap tutorial: https://casraf.dev/2024/09/pathfinding-guide-for-2d-top-view-tiles-in-godot-4-3/
- Reynolds steering behaviors (seek/flee/arrive/wander/pursue): https://www.red3d.com/cwr/steer/
- ARK breeding, stat inheritance (55%) & mutation (7.31%): https://ark.fandom.com/wiki/Breeding and https://ark.fandom.com/wiki/Mutations
- LimboAI (HSM + Behavior Trees for Godot 4): https://github.com/limbonaut/limboai
