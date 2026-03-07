"""Scene builder tools: create and modify Godot .tscn scene files."""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).parent.parent))

from config import ProjectConfig
from tscn_parser import TscnScene, build_scene, parse_file, serialize
from utils import make_response, safe_write


def register_scene_tools(mcp: Any, config: ProjectConfig) -> None:
    @mcp.tool()
    def create_scene(
        scene_name: str,
        root_node_type: str,
        node_tree: list[dict] | None = None,
        root_properties: dict | None = None,
        save_directory: str = "",
        overwrite: bool = False,
    ) -> dict:
        """Create a new Godot .tscn scene file.

        Args:
            scene_name: Name of the scene and root node (PascalCase, e.g. "Raptor").
            root_node_type: Godot node type for root (e.g. "CharacterBody2D", "Node2D").
            node_tree: List of child node dicts. Each dict has keys:
                - name (str): Node name
                - type (str): Godot node type
                - parent (str): Parent path ("." for root child, "Parent/Child" for nested)
                - properties (dict, optional): Node properties
                - sub_resources (list, optional): List of {type, properties, assign_to} dicts
                  for inline resources like collision shapes.
                - connections (list, optional): List of {signal, from, to, method} dicts.
            root_properties: Properties dict for the root node.
            save_directory: Directory relative to game root (e.g. "Sprites/Raptor").
                Defaults to "Scenes/".
            overwrite: Whether to overwrite an existing file.

        Returns:
            Dict with success, files_modified, summary, and scene_path.
        """
        scene = build_scene(scene_name, root_node_type, node_tree, root_properties)
        content = serialize(scene)

        if save_directory:
            save_dir = config.game_root / save_directory
        else:
            save_dir = config.detect_scene_dir()

        filepath = save_dir / f"{scene_name}.tscn"
        result = safe_write(filepath, content, overwrite=overwrite)
        if result["success"]:
            result["summary"] = f"Created scene '{scene_name}' ({root_node_type}) at {filepath.relative_to(config.game_root)}"
            result["scene_path"] = config.res_path(filepath)
        return result

    @mcp.tool()
    def add_node_to_scene(
        scene_path: str,
        parent_node: str,
        node_type: str,
        node_name: str,
        properties: dict | None = None,
        sub_resources: list[dict] | None = None,
        connections: list[dict] | None = None,
    ) -> dict:
        """Add a new node to an existing .tscn scene file.

        Args:
            scene_path: Path to the scene file (res:// path or relative to game root).
            parent_node: Parent node path ("." for root's child, "Parent/Child" for nested).
            node_type: Godot node type (e.g. "Area2D", "CollisionShape2D").
            node_name: Name of the new node.
            properties: Node properties dict.
            sub_resources: List of sub-resource dicts to create. Each has:
                - type (str): e.g. "CapsuleShape2D", "RectangleShape2D"
                - properties (dict): e.g. {"radius": 7.0, "height": 26.0}
                - assign_to (str): property name to assign on the node (e.g. "shape").
            connections: List of signal connection dicts: {signal, from, to, method}.

        Returns:
            Dict with success, files_modified, summary.
        """
        if scene_path.startswith("res://"):
            abs_path = config.abs_path(scene_path)
        else:
            abs_path = config.game_root / scene_path

        if not abs_path.exists():
            return make_response(False, [], f"Scene not found: {scene_path}")

        scene = parse_file(str(abs_path))

        # Build properties with sub-resources
        node_props = dict(properties or {})
        for sub in sub_resources or []:
            sub_id = scene.add_sub_resource(sub["type"], sub.get("properties"))
            assign_to = sub.get("assign_to")
            if assign_to:
                node_props[assign_to] = f'SubResource("{sub_id}")'

        scene.add_node(node_name, node_type, parent=parent_node, properties=node_props if node_props else None)

        for conn in connections or []:
            scene.add_connection(conn["signal"], conn["from"], conn["to"], conn["method"])

        content = serialize(scene)
        result = safe_write(abs_path, content, overwrite=True)
        if result["success"]:
            result["summary"] = f"Added node '{node_name}' ({node_type}) to {scene_path} under '{parent_node}'"
        return result
