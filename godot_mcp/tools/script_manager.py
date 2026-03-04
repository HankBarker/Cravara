"""Script manager tools: create GDScript files and attach them to scene nodes."""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).parent.parent))

from config import ProjectConfig
from tscn_parser import parse_file, serialize
from utils import format_tscn_value, make_response, safe_write


def register_script_tools(mcp: Any, config: ProjectConfig) -> None:
    @mcp.tool()
    def attach_script_to_node(
        scene_path: str,
        node_name: str,
        script_name: str,
        script_contents: str,
        script_directory: str = "",
        overwrite: bool = False,
    ) -> dict:
        """Create a GDScript file and attach it to a node in a scene.

        Args:
            scene_path: Path to the .tscn file (res:// path or relative to game root).
            node_name: Name of the node to attach the script to (e.g. "Raptor", "." for root).
                Use the node name, not path. For root node, use the root node's name.
            script_name: Filename for the script (without .gd extension, PascalCase).
            script_contents: Full GDScript source code.
            script_directory: Directory for the script relative to game root.
                Defaults to same directory as the scene.
            overwrite: Whether to overwrite existing script file.

        Returns:
            Dict with success, files_modified, summary.
        """
        # Resolve scene path
        if scene_path.startswith("res://"):
            scene_abs = config.abs_path(scene_path)
        else:
            scene_abs = config.game_root / scene_path

        if not scene_abs.exists():
            return make_response(False, [], f"Scene not found: {scene_path}")

        # Determine script save location
        if script_directory:
            script_dir = config.game_root / script_directory
        else:
            script_dir = scene_abs.parent

        script_path = script_dir / f"{script_name}.gd"
        script_res = config.res_path(script_path)

        # Write the script file
        write_result = safe_write(script_path, script_contents, overwrite=overwrite)
        if not write_result["success"]:
            return write_result

        files_modified = list(write_result["files_modified"])

        # Parse the scene and attach the script
        scene = parse_file(str(scene_abs))
        ext_id = scene.add_ext_resource("Script", script_res)

        # Find the target node and add the script property
        target = None
        for node in scene.nodes:
            if node.name == node_name:
                target = node
                break

        if target is None:
            return make_response(
                False,
                files_modified,
                f"Node '{node_name}' not found in scene. Script was written but not attached.",
            )

        # Add script property to the node's raw_properties
        script_line = f'script = ExtResource("{ext_id}")'
        if target.raw_properties:
            target.raw_properties = script_line + "\n" + target.raw_properties
        else:
            target.raw_properties = script_line

        content = serialize(scene)
        scene_result = safe_write(scene_abs, content, overwrite=True)
        files_modified.extend(scene_result["files_modified"])

        return make_response(
            True,
            files_modified,
            f"Created script '{script_name}.gd' and attached to node '{node_name}' in {scene_path}",
        )
