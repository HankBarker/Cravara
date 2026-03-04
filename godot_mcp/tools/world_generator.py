"""World generator tools: create biome configurations and world data."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).parent.parent))

from config import ProjectConfig
from tscn_parser import TscnScene, serialize
from utils import generate_scene_uid, make_response, safe_write


def register_world_tools(mcp: Any, config: ProjectConfig) -> None:
    @mcp.tool()
    def generate_biome_config(
        biome_name: str,
        terrain_type: str,
        creatures: list[dict] | None = None,
        resources: list[dict] | None = None,
        difficulty_level: int = 1,
        overwrite: bool = False,
    ) -> dict:
        """Generate a structured biome configuration with spawn tables and metadata.

        Creates both a JSON config file and a placeholder .tscn scene for the biome.
        The config includes creature spawn tables, resource nodes, and difficulty parameters.

        Args:
            biome_name: Name of the biome (PascalCase, e.g. "TarPitBiome", "JungleBiome").
            terrain_type: Terrain category (e.g. "grassland", "desert", "swamp", "jungle",
                "volcanic", "tundra").
            creatures: List of creature spawn entries. Each dict has:
                - name (str): Creature name (e.g. "Raptor")
                - weight (int): Spawn weight (higher = more common), default 10
                - max_count (int): Max simultaneous spawns, default 5
                - min_level (int): Minimum difficulty to spawn, default 1
            resources: List of resource node entries. Each dict has:
                - name (str): Resource name (e.g. "Tree", "SimpleRock")
                - scene_path (str): res:// path to the resource scene
                - density (int): Spawn density (instances per chunk), default 10
            difficulty_level: Base difficulty (1-10). Affects creature stats and spawn rates.
            overwrite: Whether to overwrite existing files.

        Returns:
            Dict with success, files_modified, summary.
        """
        files_modified = []

        # Build biome config data
        biome_config = {
            "biome_name": biome_name,
            "terrain_type": terrain_type,
            "difficulty_level": difficulty_level,
            "metadata": {
                "base_temperature": _terrain_temperature(terrain_type),
                "base_humidity": _terrain_humidity(terrain_type),
                "ambient_color": _terrain_ambient(terrain_type),
            },
            "creature_spawn_table": [],
            "resource_nodes": [],
            "difficulty_parameters": {
                "creature_health_multiplier": 1.0 + (difficulty_level - 1) * 0.15,
                "creature_damage_multiplier": 1.0 + (difficulty_level - 1) * 0.1,
                "spawn_rate_multiplier": 1.0 + (difficulty_level - 1) * 0.05,
                "resource_scarcity": max(0.5, 1.0 - (difficulty_level - 1) * 0.05),
            },
        }

        for creature in creatures or []:
            biome_config["creature_spawn_table"].append({
                "name": creature["name"],
                "weight": creature.get("weight", 10),
                "max_count": creature.get("max_count", 5),
                "min_level": creature.get("min_level", 1),
            })

        for resource in resources or []:
            biome_config["resource_nodes"].append({
                "name": resource["name"],
                "scene_path": resource.get("scene_path", ""),
                "density": resource.get("density", 10),
            })

        # Write config JSON
        config_dir = config.detect_data_dir() / "Biomes"
        config_path = config_dir / f"{biome_name}.json"
        content = json.dumps(biome_config, indent=2, ensure_ascii=False) + "\n"
        result = safe_write(config_path, content, overwrite=overwrite)
        if not result["success"]:
            return result
        files_modified.extend(result["files_modified"])

        # Generate placeholder .tscn scene
        scene = TscnScene(uid=generate_scene_uid())
        scene.add_node(biome_name, "Node2D", parent=None)
        scene.add_node("TileMapLayer", "TileMapLayer", parent=".")
        scene.add_node("Creatures", "Node2D", parent=".")
        scene.add_node("Resources", "Node2D", parent=".")

        scene_dir = config.game_root / "Biomes"
        scene_path = scene_dir / f"{biome_name}.tscn"
        scene_content = serialize(scene)
        result = safe_write(scene_path, scene_content, overwrite=overwrite)
        if not result["success"]:
            return make_response(True, files_modified, f"Config created but scene already exists at {scene_path}")
        files_modified.extend(result["files_modified"])

        return make_response(
            True,
            files_modified,
            f"Generated biome config and scene for '{biome_name}' "
            f"(terrain={terrain_type}, difficulty={difficulty_level}, "
            f"{len(creatures or [])} creatures, {len(resources or [])} resources)",
        )


def _terrain_temperature(terrain_type: str) -> str:
    temps = {
        "grassland": "temperate",
        "desert": "hot",
        "swamp": "warm",
        "jungle": "hot",
        "volcanic": "extreme_hot",
        "tundra": "cold",
        "cave": "cool",
    }
    return temps.get(terrain_type, "temperate")


def _terrain_humidity(terrain_type: str) -> str:
    humidity = {
        "grassland": "moderate",
        "desert": "arid",
        "swamp": "saturated",
        "jungle": "humid",
        "volcanic": "dry",
        "tundra": "dry",
        "cave": "damp",
    }
    return humidity.get(terrain_type, "moderate")


def _terrain_ambient(terrain_type: str) -> str:
    colors = {
        "grassland": "Color(0.9, 1.0, 0.85, 1.0)",
        "desert": "Color(1.0, 0.95, 0.8, 1.0)",
        "swamp": "Color(0.7, 0.8, 0.6, 1.0)",
        "jungle": "Color(0.6, 0.9, 0.5, 1.0)",
        "volcanic": "Color(1.0, 0.6, 0.4, 1.0)",
        "tundra": "Color(0.85, 0.9, 1.0, 1.0)",
        "cave": "Color(0.4, 0.4, 0.5, 1.0)",
    }
    return colors.get(terrain_type, "Color(1.0, 1.0, 1.0, 1.0)")
