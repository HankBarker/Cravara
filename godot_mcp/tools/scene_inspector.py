"""Scene and node inspection tools: read scene trees, inspect/modify node properties."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).parent.parent))

from config import ProjectConfig
from tscn_parser import SceneNode, parse_file, serialize
from utils import make_response, safe_write


def register_scene_inspector_tools(mcp: Any, config: ProjectConfig) -> None:
    @mcp.tool()
    def get_scene_tree(scene_path: str) -> dict:
        """Parse a .tscn scene file and return the full node hierarchy.

        Returns a tree structure showing each node's name, type, attached script,
        key properties, and children.

        Args:
            scene_path: Path to the .tscn file (res:// path or relative to game root).

        Returns:
            Dict with success, tree (nested node hierarchy), node_count, summary.
        """
        abs_path = _resolve_scene_path(config, scene_path)
        if not abs_path.exists():
            return make_response(False, [], f"Scene not found: {scene_path}")

        scene = parse_file(str(abs_path))

        # Build parent -> children mapping
        children_map: dict[str, list[int]] = {}
        for i, node in enumerate(scene.nodes):
            if node.parent is None:
                # Root node
                children_map.setdefault("__root__", []).append(i)
            else:
                # Build the full path for this node's parent
                parent_key = node.parent if node.parent != "." else "__root_child__"
                children_map.setdefault(parent_key, []).append(i)

        def _build_node_dict(node: SceneNode, node_idx: int) -> dict[str, Any]:
            info: dict[str, Any] = {
                "name": node.name,
                "type": node.type or "(instance)",
            }

            # Check for attached script
            if node.raw_properties:
                script_match = re.search(r'script\s*=\s*ExtResource\("([^"]+)"\)', node.raw_properties)
                if script_match:
                    ext_id = script_match.group(1)
                    # Find the ext_resource path
                    for ext in scene.ext_resources:
                        if ext.id == ext_id:
                            info["script"] = ext.path
                            break

                # Extract key properties (position, visible, z_index, etc.)
                key_props = _extract_key_properties(node.raw_properties)
                if key_props:
                    info["properties"] = key_props

            if node.instance:
                info["instance"] = node.instance

            # Find children
            node_path = _get_node_path(scene.nodes, node_idx)
            child_indices = children_map.get(node_path, [])
            # Also check "." parent for root's direct children
            if node.parent is None:
                child_indices = children_map.get("__root_child__", [])

            if child_indices:
                info["children"] = [
                    _build_node_dict(scene.nodes[ci], ci) for ci in child_indices
                ]

            return info

        # Build tree starting from root
        root_indices = children_map.get("__root__", [])
        if not root_indices:
            return make_response(False, [], "No root node found in scene")

        tree = _build_node_dict(scene.nodes[root_indices[0]], root_indices[0])

        # Include signal connections
        if scene.connections:
            tree["connections"] = [
                {
                    "signal": c.signal,
                    "from": c.from_node,
                    "to": c.to_node,
                    "method": c.method,
                }
                for c in scene.connections
            ]

        return make_response(
            True,
            [],
            f"Scene tree: {len(scene.nodes)} nodes, {len(scene.connections)} connections",
            tree=tree,
            node_count=len(scene.nodes),
        )

    @mcp.tool()
    def get_node_properties(scene_path: str, node_path: str) -> dict:
        """Get all properties of a specific node in a scene file.

        Args:
            scene_path: Path to the .tscn file (res:// path or relative).
            node_path: Node path in the scene tree. Use the node name for root's
                direct children (e.g., 'Player'), or slash-separated path for nested
                nodes (e.g., 'Player/CollisionShape2D'). Use '.' for the root node.

        Returns:
            Dict with success, node_name, node_type, properties (dict), raw, summary.
        """
        abs_path = _resolve_scene_path(config, scene_path)
        if not abs_path.exists():
            return make_response(False, [], f"Scene not found: {scene_path}")

        scene = parse_file(str(abs_path))
        node = _find_node_by_path(scene.nodes, node_path)

        if node is None:
            available = [_get_node_path(scene.nodes, i) for i in range(len(scene.nodes))]
            return make_response(
                False,
                [],
                f"Node not found: {node_path}. Available: {', '.join(available[:20])}",
            )

        # Parse all properties from raw_properties
        properties = _parse_raw_properties(node.raw_properties)

        return make_response(
            True,
            [],
            f"Node '{node.name}' ({node.type}): {len(properties)} properties",
            node_name=node.name,
            node_type=node.type,
            properties=properties,
            raw=node.raw_properties,
        )

    @mcp.tool()
    def set_node_property(
        scene_path: str,
        node_path: str,
        property_name: str,
        value: str,
    ) -> dict:
        """Set a property on a node in a .tscn scene file.

        If the property already exists, its value is updated. If it doesn't exist,
        it is added to the node.

        Args:
            scene_path: Path to the .tscn file (res:// path or relative).
            node_path: Node path (e.g., 'Player', 'Enemies/Trex', '.' for root).
            property_name: Property key (e.g., 'position', 'visible', 'z_index').
            value: Value in Godot format (e.g., 'Vector2(100, 200)', 'true', '5').

        Returns:
            Dict with success, files_modified, summary.
        """
        abs_path = _resolve_scene_path(config, scene_path)
        if not abs_path.exists():
            return make_response(False, [], f"Scene not found: {scene_path}")

        scene = parse_file(str(abs_path))
        node = _find_node_by_path(scene.nodes, node_path)

        if node is None:
            return make_response(False, [], f"Node not found: {node_path}")

        # Update or add the property in raw_properties
        new_line = f"{property_name} = {value}"
        if node.raw_properties:
            # Check if property already exists
            pattern = re.compile(rf"^{re.escape(property_name)}\s*=\s*.*$", re.MULTILINE)
            if pattern.search(node.raw_properties):
                node.raw_properties = pattern.sub(new_line, node.raw_properties, count=1)
            else:
                node.raw_properties += "\n" + new_line
        else:
            node.raw_properties = new_line

        content = serialize(scene)
        result = safe_write(abs_path, content, overwrite=True)
        if result["success"]:
            result["summary"] = f"Set {property_name} = {value} on node '{node_path}' in {scene_path}"
        return result

    @mcp.tool()
    def remove_node(scene_path: str, node_path: str) -> dict:
        """Remove a node and all its children from a .tscn scene file.

        Also removes signal connections involving the removed nodes.

        Args:
            scene_path: Path to the .tscn file (res:// path or relative).
            node_path: Node path to remove (e.g., 'Player/SwordHitbox').
                Cannot remove the root node (use '.' to reference it).

        Returns:
            Dict with success, files_modified, removed_nodes (list), summary.
        """
        abs_path = _resolve_scene_path(config, scene_path)
        if not abs_path.exists():
            return make_response(False, [], f"Scene not found: {scene_path}")

        scene = parse_file(str(abs_path))

        if node_path == ".":
            return make_response(False, [], "Cannot remove the root node")

        # Find the target node and all descendants
        target_node = _find_node_by_path(scene.nodes, node_path)
        if target_node is None:
            return make_response(False, [], f"Node not found: {node_path}")

        # Build full paths for all nodes
        all_paths = [_get_node_path(scene.nodes, i) for i in range(len(scene.nodes))]

        # Find indices to remove: the target and any node whose path starts with target_path/
        removed_paths = []
        indices_to_remove = []
        for i, path in enumerate(all_paths):
            if path == node_path or path.startswith(node_path + "/"):
                indices_to_remove.append(i)
                removed_paths.append(path)

        if not indices_to_remove:
            return make_response(False, [], f"Node not found: {node_path}")

        # Remove nodes (in reverse order to preserve indices)
        for i in sorted(indices_to_remove, reverse=True):
            scene.nodes.pop(i)

        # Remove connections involving removed nodes
        removed_names = {scene.nodes[i].name if i < len(scene.nodes) else "" for i in indices_to_remove}
        # More robust: filter connections by from/to paths
        scene.connections = [
            c for c in scene.connections
            if c.from_node not in removed_paths and c.to_node not in removed_paths
        ]

        content = serialize(scene)
        result = safe_write(abs_path, content, overwrite=True)
        if result["success"]:
            result["summary"] = f"Removed {len(removed_paths)} node(s) from {scene_path}: {', '.join(removed_paths)}"
            result["removed_nodes"] = removed_paths
        return result


# --- Internal helpers ---

def _resolve_scene_path(config: ProjectConfig, scene_path: str) -> Path:
    """Resolve a scene path to an absolute filesystem path."""
    if scene_path.startswith("res://"):
        return config.abs_path(scene_path)
    return config.game_root / scene_path


def _get_node_path(nodes: list[SceneNode], idx: int) -> str:
    """Get the full tree path of a node by index.

    Root node -> '.'
    Root's child 'Player' -> 'Player'
    Player's child 'CollisionShape2D' -> 'Player/CollisionShape2D'
    """
    node = nodes[idx]
    if node.parent is None:
        return "."
    if node.parent == ".":
        return node.name
    return f"{node.parent}/{node.name}"


def _find_node_by_path(nodes: list[SceneNode], target_path: str) -> SceneNode | None:
    """Find a node by its tree path."""
    for i, node in enumerate(nodes):
        path = _get_node_path(nodes, i)
        if path == target_path:
            return node
    return None


def _extract_key_properties(raw_properties: str) -> dict[str, str]:
    """Extract commonly interesting properties from raw_properties text."""
    key_names = {
        "position", "rotation", "scale", "visible", "z_index", "modulate",
        "collision_layer", "collision_mask", "process_mode", "texture",
    }
    props = {}
    for line in raw_properties.split("\n"):
        line = line.strip()
        if " = " in line:
            key, val = line.split(" = ", 1)
            key = key.strip()
            if key in key_names:
                props[key] = val.strip()
    return props


def _parse_raw_properties(raw_properties: str) -> dict[str, str]:
    """Parse all properties from a node's raw_properties string."""
    if not raw_properties:
        return {}
    props = {}
    current_key = None
    current_lines: list[str] = []
    brace_depth = 0

    for line in raw_properties.split("\n"):
        if brace_depth > 0:
            current_lines.append(line)
            brace_depth += line.count("{") - line.count("}")
            if brace_depth <= 0:
                if current_key:
                    props[current_key] = "\n".join(current_lines)
                current_key = None
                current_lines = []
                brace_depth = 0
            continue

        stripped = line.strip()
        if not stripped:
            continue

        if " = " in stripped:
            key, val = stripped.split(" = ", 1)
            key = key.strip()
            brace_depth = val.count("{") - val.count("}")
            if brace_depth > 0:
                current_key = key
                current_lines = [val]
            else:
                props[key] = val
        elif "=" in stripped:
            key, val = stripped.split("=", 1)
            props[key.strip()] = val.strip()

    return props
