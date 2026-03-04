"""Creature generator tool: auto-generate creature scene, AI script, data, and spawn rules."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).parent.parent))

from config import ProjectConfig
from tscn_parser import TscnScene, serialize
from utils import generate_scene_uid, make_response, safe_write


# Rarity -> base stat multipliers
RARITY_MULTIPLIERS = {
    "common": {"health": 1.0, "damage": 1.0, "speed": 1.0, "xp": 1.0},
    "uncommon": {"health": 1.5, "damage": 1.3, "speed": 1.1, "xp": 1.5},
    "rare": {"health": 2.5, "damage": 1.8, "speed": 1.2, "xp": 3.0},
    "epic": {"health": 4.0, "damage": 2.5, "speed": 1.3, "xp": 5.0},
    "legendary": {"health": 8.0, "damage": 4.0, "speed": 1.5, "xp": 10.0},
    "boss": {"health": 15.0, "damage": 5.0, "speed": 1.0, "xp": 25.0},
}

# creature_type -> base stats
BASE_STATS = {
    "dinosaur": {"health": 5, "damage": 2, "speed": 30, "xp": 10},
    "mutant": {"health": 4, "damage": 3, "speed": 35, "xp": 12},
    "insect": {"health": 2, "damage": 1, "speed": 50, "xp": 5},
    "predator": {"health": 6, "damage": 3, "speed": 40, "xp": 15},
    "herbivore": {"health": 8, "damage": 1, "speed": 20, "xp": 8},
    "boss": {"health": 20, "damage": 5, "speed": 25, "xp": 50},
    "miniboss": {"health": 12, "damage": 3, "speed": 30, "xp": 30},
}


def register_creature_tools(mcp: Any, config: ProjectConfig) -> None:
    @mcp.tool()
    def generate_creature(
        name: str,
        creature_type: str = "dinosaur",
        biome: str = "grassland",
        abilities: list[str] | None = None,
        rarity: str = "common",
        overwrite: bool = False,
    ) -> dict:
        """Generate a complete creature with scene, AI script, stat data, and spawn rules.

        Creates a CharacterBody2D scene following the T-Rex pattern:
        CharacterBody2D -> AnimatedSprite2D, CollisionShape2D, Hurtbox (Area2D),
        AttackArea (Area2D), AggroRange (Area2D).

        Also generates:
        - AI script with state machine (idle/wander/chase/attack/hurt/death)
        - Creature stats entry in Data/creatures.json
        - Spawn rule entry in the biome config

        Args:
            name: Creature name in PascalCase (e.g. "Raptor", "ThornbackAnkylosaur").
            creature_type: Type category. One of: dinosaur, mutant, insect, predator,
                herbivore, boss, miniboss.
            biome: Biome where this creature spawns (e.g. "grassland", "jungle", "tarpit").
            abilities: List of special ability names (e.g. ["bite", "ground_slam", "charge"]).
                Defaults to ["bite"].
            rarity: Rarity tier. One of: common, uncommon, rare, epic, legendary, boss.
                Affects stat multipliers.
            overwrite: Whether to overwrite existing files.

        Returns:
            Dict with success, files_modified, summary.
        """
        abilities = abilities or ["bite"]
        files_modified = []

        # Calculate stats
        base = BASE_STATS.get(creature_type, BASE_STATS["dinosaur"])
        mult = RARITY_MULTIPLIERS.get(rarity, RARITY_MULTIPLIERS["common"])
        stats = {
            "health": int(base["health"] * mult["health"]),
            "damage": int(base["damage"] * mult["damage"]),
            "move_speed": int(base["speed"] * mult["speed"]),
            "chase_speed": int(base["speed"] * mult["speed"] * 1.5),
            "xp_value": int(base["xp"] * mult["xp"]),
        }

        # Determine save directory
        creature_dir = config.detect_creature_dir(name)
        creature_dir_rel = creature_dir.relative_to(config.game_root).as_posix()

        # 1. Generate AI script
        script_name = name[0].lower() + name[1:]  # camelCase -> lower first char
        script_filename = f"{script_name}.gd"
        script_content = _generate_ai_script(name, stats, abilities)
        script_path = creature_dir / script_filename
        result = safe_write(script_path, script_content, overwrite=overwrite)
        if not result["success"]:
            return result
        files_modified.extend(result["files_modified"])

        script_res_path = config.res_path(script_path)

        # 2. Generate scene file
        scene = TscnScene(uid=generate_scene_uid())
        script_id = scene.add_ext_resource("Script", script_res_path)

        # Sub-resources: collision shapes
        body_shape_id = scene.add_sub_resource("CapsuleShape2D", {"radius": 7.0, "height": 26.0})
        hurtbox_shape_id = scene.add_sub_resource("CapsuleShape2D", {"radius": 20.0, "height": 40.0})
        attack_shape_id = scene.add_sub_resource("CapsuleShape2D", {"radius": 15.0, "height": 36.0})
        aggro_shape_id = scene.add_sub_resource("CircleShape2D", {"radius": 120.0})

        # Root node
        scene.add_node(name, "CharacterBody2D", parent=None, properties={
            "collision_mask": 19,
            "script": f'ExtResource("{script_id}")',
        })

        # AnimatedSprite2D (placeholder - no sprite frames yet)
        scene.add_node("AnimatedSprite2D", "AnimatedSprite2D", parent=".")

        # CollisionShape2D
        scene.add_node("CollisionShape2D", "CollisionShape2D", parent=".", properties={
            "shape": f'SubResource("{body_shape_id}")',
        })

        # Hurtbox
        scene.add_node("Hurtbox", "Area2D", parent=".", properties={
            "collision_layer": 8,
            "collision_mask": 4,
        })
        scene.add_node("CollisionShape2D", "CollisionShape2D", parent="Hurtbox", properties={
            "shape": f'SubResource("{hurtbox_shape_id}")',
        })

        # AttackArea
        scene.add_node("AttackArea", "Area2D", parent=".", properties={
            "collision_layer": 2,
        })
        scene.add_node("CollisionShape2D", "CollisionShape2D", parent="AttackArea", properties={
            "shape": f'SubResource("{attack_shape_id}")',
        })

        # AggroRange
        scene.add_node("AggroRange", "Area2D", parent=".", properties={
            "collision_layer": 2,
        })
        scene.add_node("CollisionShape2D", "CollisionShape2D", parent="AggroRange", properties={
            "shape": f'SubResource("{aggro_shape_id}")',
        })

        # Connections
        scene.add_connection("area_entered", "AttackArea", ".", "_on_AttackArea_area_entered")
        scene.add_connection("body_entered", "AggroRange", ".", "_on_AggroRange_body_entered")
        scene.add_connection("body_exited", "AggroRange", ".", "_on_AggroRange_body_exited")

        scene_path = creature_dir / f"{name}.tscn"
        scene_content = serialize(scene)
        result = safe_write(scene_path, scene_content, overwrite=overwrite)
        if not result["success"]:
            return result
        files_modified.extend(result["files_modified"])

        # 3. Add creature data to Data/creatures.json
        data_path = config.detect_data_dir() / "creatures.json"
        if data_path.exists():
            creature_data = json.loads(data_path.read_text(encoding="utf-8"))
        else:
            creature_data = {}

        creature_key = name[0].lower() + name[1:]
        creature_data[creature_key] = {
            "display_name": _to_display_name(name),
            "creature_type": creature_type,
            "rarity": rarity,
            "biome": biome,
            "abilities": abilities,
            "stats": stats,
            "scene_path": config.res_path(scene_path),
            "script_path": script_res_path,
        }

        data_content = json.dumps(creature_data, indent=2, ensure_ascii=False) + "\n"
        result = safe_write(data_path, data_content, overwrite=True)
        files_modified.extend(result["files_modified"])

        # 4. Update biome spawn table if biome config exists
        biome_config_path = config.detect_data_dir() / "Biomes" / f"{_to_pascal(biome)}Biome.json"
        if biome_config_path.exists():
            biome_data = json.loads(biome_config_path.read_text(encoding="utf-8"))
            spawn_entry = {
                "name": name,
                "weight": _rarity_spawn_weight(rarity),
                "max_count": _rarity_max_count(rarity),
                "min_level": 1,
            }
            if "creature_spawn_table" not in biome_data:
                biome_data["creature_spawn_table"] = []
            # Don't duplicate
            existing_names = [c["name"] for c in biome_data["creature_spawn_table"]]
            if name not in existing_names:
                biome_data["creature_spawn_table"].append(spawn_entry)
                biome_content = json.dumps(biome_data, indent=2, ensure_ascii=False) + "\n"
                result = safe_write(biome_config_path, biome_content, overwrite=True)
                files_modified.extend(result["files_modified"])

        return make_response(
            True,
            files_modified,
            f"Generated {rarity} {creature_type} creature '{name}' for {biome} biome "
            f"(HP={stats['health']}, DMG={stats['damage']}, abilities={abilities})",
        )


def _to_display_name(pascal_name: str) -> str:
    """Convert PascalCase to display name: 'ThornbackAnkylosaur' -> 'Thornback Ankylosaur'."""
    import re
    return re.sub(r"(?<=[a-z])(?=[A-Z])", " ", pascal_name)


def _to_pascal(name: str) -> str:
    """Convert simple name to PascalCase: 'jungle' -> 'Jungle', 'tar_pit' -> 'TarPit'."""
    return "".join(word.capitalize() for word in name.replace("_", " ").split())


def _rarity_spawn_weight(rarity: str) -> int:
    weights = {"common": 20, "uncommon": 12, "rare": 6, "epic": 3, "legendary": 1, "boss": 1}
    return weights.get(rarity, 10)


def _rarity_max_count(rarity: str) -> int:
    counts = {"common": 8, "uncommon": 5, "rare": 3, "epic": 2, "legendary": 1, "boss": 1}
    return counts.get(rarity, 5)


def _generate_ai_script(name: str, stats: dict, abilities: list[str]) -> str:
    """Generate a creature AI GDScript following the T-Rex pattern."""
    ability_funcs = ""
    for ability in abilities:
        func_name = ability.replace(" ", "_").lower()
        ability_funcs += f"""
func perform_{func_name}() -> void:
\tif bite_cooldown:
\t\treturn
\tbite_cooldown = true
\t# Play attack animation
\tvar anim_name = "{func_name}_" + last_facing
\tif sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
\t\tsprite.play(anim_name)
\tawait get_tree().create_timer(0.5).timeout
\tbite_cooldown = false
"""

    return f'''extends CharacterBody2D

@onready var sprite := $AnimatedSprite2D
@onready var attack_area := $AttackArea
@onready var aggro_range := $AggroRange

# Stats
var health := {stats["health"]}
var max_health := {stats["health"]}
var damage := {stats["damage"]}
var move_speed := {stats["move_speed"]}
var chase_speed := {stats["chase_speed"]}
var xp_value := {stats["xp_value"]}

# State
var direction := Vector2.ZERO
var last_facing := "down"
var bite_cooldown := false
var is_chasing := false
var is_dead := false
var wander_timer := 0.0
var wander_duration := 2.0
var player: Node2D = null

# AI states
enum State {{ IDLE, WANDER, CHASE, ATTACK, HURT, DEATH }}
var current_state: State = State.IDLE

@export var start_position := Vector2(200, 200)
@export var use_manual_position := true

func _ready() -> void:
\tif use_manual_position:
\t\tglobal_position = start_position
\tplayer = get_tree().get_first_node_in_group("player")
\tif not player:
\t\tplayer = get_node_or_null("/root/Playground/Player")
\tset_new_wander_direction()

func _physics_process(delta: float) -> void:
\tif is_dead:
\t\treturn

\tmatch current_state:
\t\tState.IDLE:
\t\t\t_process_idle(delta)
\t\tState.WANDER:
\t\t\t_process_wander(delta)
\t\tState.CHASE:
\t\t\t_process_chase(delta)
\t\tState.ATTACK:
\t\t\tpass
\t\tState.HURT:
\t\t\tpass
\t\tState.DEATH:
\t\t\tpass

func _process_idle(delta: float) -> void:
\twander_timer -= delta
\tif wander_timer <= 0:
\t\tcurrent_state = State.WANDER
\t\tset_new_wander_direction()

func _process_wander(delta: float) -> void:
\twander_timer -= delta
\tvelocity = direction * move_speed
\tmove_and_slide()
\tupdate_animation("walk")

\tif wander_timer <= 0:
\t\tcurrent_state = State.IDLE
\t\twander_timer = randf_range(1.0, 3.0)
\t\tvelocity = Vector2.ZERO

func _process_chase(delta: float) -> void:
\tif not is_instance_valid(player):
\t\tcurrent_state = State.WANDER
\t\tis_chasing = false
\t\treturn

\tvar dir_to_player = global_position.direction_to(player.global_position)
\tvelocity = dir_to_player * chase_speed
\tupdate_facing(dir_to_player)
\tmove_and_slide()
\tupdate_animation("walk")

\t# Check attack range
\tvar dist = global_position.distance_to(player.global_position)
\tif dist < 30:
\t\tcurrent_state = State.ATTACK
\t\tperform_{abilities[0].replace(" ", "_").lower()}()

func set_new_wander_direction() -> void:
\tvar angle = randf() * TAU
\tdirection = Vector2(cos(angle), sin(angle))
\twander_timer = randf_range(1.5, 3.0)
\tupdate_facing(direction)

func update_facing(dir: Vector2) -> void:
\tif abs(dir.x) > abs(dir.y):
\t\tlast_facing = "right" if dir.x > 0 else "left"
\telse:
\t\tlast_facing = "down" if dir.y > 0 else "up"

func update_animation(action: str) -> void:
\tvar anim_name = action + "_" + last_facing
\tif sprite.sprite_frames and sprite.sprite_frames.has_animation(anim_name):
\t\tsprite.play(anim_name)

func take_damage(amount: int) -> void:
\tif is_dead:
\t\treturn
\thealth -= amount
\tcurrent_state = State.HURT
\tupdate_animation("hurt")
\tif health <= 0:
\t\tdie()
\telse:
\t\tawait get_tree().create_timer(0.3).timeout
\t\tif is_chasing:
\t\t\tcurrent_state = State.CHASE
\t\telse:
\t\t\tcurrent_state = State.WANDER

func die() -> void:
\tis_dead = true
\tcurrent_state = State.DEATH
\tvelocity = Vector2.ZERO
\tupdate_animation("death")
\t# Drop loot
\tdrop_loot()
\tawait get_tree().create_timer(1.5).timeout
\tqueue_free()

func drop_loot() -> void:
\t# Override in subclasses or configure via data
\tpass
{ability_funcs}
func _on_AttackArea_area_entered(area: Area2D) -> void:
\tif area.get_parent().name == "Player":
\t\tvar player_node = area.get_parent()
\t\tif player_node.has_method("take_damage"):
\t\t\tplayer_node.take_damage(damage)

func _on_AggroRange_body_entered(body: Node2D) -> void:
\tif body.name == "Player":
\t\tplayer = body
\t\tis_chasing = true
\t\tcurrent_state = State.CHASE

func _on_AggroRange_body_exited(body: Node2D) -> void:
\tif body.name == "Player":
\t\tis_chasing = false
\t\tcurrent_state = State.WANDER
\t\tset_new_wander_direction()
'''
