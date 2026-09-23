"""Project control tools: read/modify project.godot settings, open editor."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).parent.parent))

from config import ProjectConfig
from godot_finder import find_godot_executable, get_godot_version, get_not_found_message
from godot_project_cfg import (
    parse_input_actions,
    parse_project_godot,
    get_setting,
    set_setting,
    write_project_godot,
)
from utils import make_response


def register_project_control_tools(mcp: Any, config: ProjectConfig) -> None:
    @mcp.tool()
    def get_project_settings() -> dict:
        """Parse project.godot and return all settings organized by section.

        Returns a structured dict with each section name mapping to its key-value pairs.
        Top-level keys (like config_version) appear under a '_top_level' key.

        Returns:
            Dict with success, data (section -> key -> value), summary.
        """
        project_path = config.get_project_godot_path()
        if not project_path.exists():
            return make_response(False, [], f"project.godot not found at {project_path}")

        cfg = parse_project_godot(project_path)

        data: dict[str, Any] = {}
        if cfg.top_level:
            data["_top_level"] = dict(cfg.top_level)
        for section_name, section_data in cfg.sections.items():
            data[section_name] = dict(section_data)

        total_keys = sum(len(v) for v in data.values())
        return make_response(
            True,
            [],
            f"Parsed project.godot: {len(cfg.sections)} sections, {total_keys} settings",
            data=data,
        )

    @mcp.tool()
    def get_project_setting(key: str) -> dict:
        """Get a specific project setting by section/key path.

        The key format is 'section/setting_path'. For example:
        - 'display/window/size/viewport_width' -> viewport width
        - 'application/config/name' -> project name
        - 'application/run/main_scene' -> main scene path
        - 'rendering/textures/canvas_textures/default_texture_filter' -> texture filter

        For top-level keys (outside sections), use just the key name:
        - 'config_version' -> config version number

        Args:
            key: Slash-separated setting path (section/key).

        Returns:
            Dict with success, value, summary.
        """
        project_path = config.get_project_godot_path()
        if not project_path.exists():
            return make_response(False, [], f"project.godot not found at {project_path}")

        cfg = parse_project_godot(project_path)
        value = get_setting(cfg, key)

        if value is None:
            return make_response(False, [], f"Setting not found: {key}")

        return make_response(True, [], f"{key} = {value}", value=value)

    @mcp.tool()
    def set_project_setting(key: str, value: str) -> dict:
        """Modify a project.godot setting and write back to disk.

        Uses targeted text replacement to preserve the file format.

        Args:
            key: Setting path (e.g., 'display/window/size/viewport_width').
            value: New value as a string. Use Godot format for complex types:
                - Numbers: '640', '1080'
                - Strings: '"Cravara"' (include the quotes)
                - Booleans: 'true', 'false'
                - Expressions: 'PackedStringArray("4.6", "Forward Plus")'

        Returns:
            Dict with success, files_modified, old_value, new_value, summary.
        """
        project_path = config.get_project_godot_path()
        if not project_path.exists():
            return make_response(False, [], f"project.godot not found at {project_path}")

        cfg = parse_project_godot(project_path)
        old_value = get_setting(cfg, key)
        was_existing = set_setting(cfg, key, value)
        write_project_godot(cfg, project_path)

        if was_existing:
            summary = f"Changed {key}: {old_value} -> {value}"
        else:
            summary = f"Added new setting {key} = {value}"

        return make_response(
            True,
            [str(project_path)],
            summary,
            old_value=old_value,
            new_value=value,
        )

    @mcp.tool()
    def open_project_in_editor() -> dict:
        """Open the Cravara project in the Godot editor.

        Launches the Godot editor as a detached process.
        Requires the Godot executable to be discoverable.

        Returns:
            Dict with success, pid, godot_version, summary.
        """
        godot_path = find_godot_executable()
        if godot_path is None:
            return make_response(False, [], get_not_found_message())

        version = get_godot_version(godot_path)

        try:
            proc = subprocess.Popen(
                [godot_path, "--path", str(config.game_root), "--editor"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            return make_response(
                True,
                [],
                f"Opened Godot editor (PID {proc.pid}, version {version})",
                pid=proc.pid,
                godot_version=version,
            )
        except OSError as e:
            return make_response(False, [], f"Failed to launch Godot: {e}")

    @mcp.tool()
    def list_input_actions() -> dict:
        """List all input actions from the [input] section of project.godot.

        Parses the input mappings and provides human-readable key/button names.

        Returns:
            Dict with success, actions (list of {name, deadzone, events}), summary.
        """
        project_path = config.get_project_godot_path()
        if not project_path.exists():
            return make_response(False, [], f"project.godot not found at {project_path}")

        cfg = parse_project_godot(project_path)
        actions = parse_input_actions(cfg)

        return make_response(
            True,
            [],
            f"Found {len(actions)} input actions",
            actions=actions,
        )
