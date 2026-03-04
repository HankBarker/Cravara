"""System generator tool: create larger gameplay systems with scripts, scenes, and data."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).parent.parent))

from config import ProjectConfig
from tscn_parser import TscnScene, serialize
from utils import generate_scene_uid, make_response, safe_write


def register_system_tools(mcp: Any, config: ProjectConfig) -> None:
    @mcp.tool()
    def generate_game_system(
        system_name: str,
        description: str = "",
        components: list[str] | None = None,
        autoload: bool = False,
        signals: list[dict] | None = None,
        overwrite: bool = False,
    ) -> dict:
        """Generate a gameplay system with scripts, scenes, data structures, and autoloads.

        Use this to create larger systems like crafting, taming, inventory expansions,
        quest systems, skill trees, or boss mechanics.

        Args:
            system_name: PascalCase name (e.g. "TamingSystem", "QuestManager", "SkillTree").
            description: Human-readable description of what the system does.
            components: List of component names to generate. Each becomes a GDScript file
                in the system directory. Common patterns:
                - "manager" -> Main system manager script (Node)
                - "ui" -> UI controller script (Control) + .tscn scene
                - "data" -> JSON data structure in Data/
                - "spawner" -> Spawner node script (Node2D)
                - "component" -> Reusable component script
                Defaults to ["manager"].
            autoload: Whether to register the main manager as a project autoload.
            signals: Signals to add to SignalBus.gd. Each dict has:
                - name (str): Signal name (snake_case)
                - params (str, optional): Parameter declaration (e.g. "item: Item, amount: int")
            overwrite: Whether to overwrite existing files.

        Returns:
            Dict with success, files_modified, summary.
        """
        components = components or ["manager"]
        files_modified = []
        system_dir = config.game_root / "Systems" / system_name

        # Generate component files
        for component in components:
            if component == "manager":
                result = _create_manager(system_name, description, system_dir, config, overwrite)
            elif component == "ui":
                result = _create_ui(system_name, description, system_dir, config, overwrite)
            elif component == "data":
                result = _create_data(system_name, description, config, overwrite)
            elif component == "spawner":
                result = _create_spawner(system_name, description, system_dir, config, overwrite)
            else:
                result = _create_component(system_name, component, description, system_dir, config, overwrite)

            if not result["success"]:
                return result
            files_modified.extend(result["files_modified"])

        # Add signals to SignalBus.gd
        if signals:
            signalbus_path = config.game_root / "Autoloads" / "SignalBus.gd"
            if signalbus_path.exists():
                content = signalbus_path.read_text(encoding="utf-8")
                new_signals = []
                for sig in signals:
                    params = f'({sig["params"]})' if sig.get("params") else ""
                    line = f"signal {sig['name']}{params}"
                    if line not in content:
                        new_signals.append(line)
                if new_signals:
                    content = content.rstrip() + "\n\n# " + system_name + " signals\n"
                    content += "\n".join(new_signals) + "\n"
                    result = safe_write(signalbus_path, content, overwrite=True)
                    files_modified.extend(result["files_modified"])

        # Register autoload in project.godot
        if autoload:
            manager_script = system_dir / f"{system_name}.gd"
            res_path = config.res_path(manager_script)
            result = _register_autoload(config, system_name, res_path)
            if result["success"]:
                files_modified.extend(result["files_modified"])

        return make_response(
            True,
            files_modified,
            f"Generated game system '{system_name}' with components: {', '.join(components)}"
            + (f" (autoload={'registered' if autoload else 'no'})" if autoload else ""),
        )


def _create_manager(
    system_name: str, description: str, system_dir: Path, config: ProjectConfig, overwrite: bool
) -> dict:
    """Create the main manager script."""
    script = f'''extends Node

# {system_name} - {description}
# Autoload singleton for {system_name.lower()} management

signal {_to_snake(system_name)}_updated

var _initialized := false

func _ready() -> void:
\t_initialize()

func _initialize() -> void:
\tif _initialized:
\t\treturn
\t_initialized = true
\tprint("[{system_name}] Initialized")

# Add system-specific methods below
'''
    path = system_dir / f"{system_name}.gd"
    return safe_write(path, script, overwrite=overwrite)


def _create_ui(
    system_name: str, description: str, system_dir: Path, config: ProjectConfig, overwrite: bool
) -> dict:
    """Create a UI controller script and scene."""
    files_modified = []

    # UI Script
    ui_script = f'''extends Control

# {system_name} UI Controller

@onready var panel := $Panel

var is_visible := false

func _ready() -> void:
\thide()

func toggle() -> void:
\tis_visible = !is_visible
\tif is_visible:
\t\tshow()
\t\t_refresh_ui()
\telse:
\t\thide()

func _refresh_ui() -> void:
\t# Update UI elements based on current state
\tpass
'''
    script_path = system_dir / f"{system_name}UI.gd"
    result = safe_write(script_path, ui_script, overwrite=overwrite)
    if not result["success"]:
        return result
    files_modified.extend(result["files_modified"])

    # UI Scene
    scene = TscnScene(uid=generate_scene_uid())
    script_res = config.res_path(script_path)
    script_id = scene.add_ext_resource("Script", script_res)

    scene.add_node(f"{system_name}UI", "Control", parent=None, properties={
        "layout_mode": 3,
        "anchors_preset": 15,
        "script": f'ExtResource("{script_id}")',
    })
    scene.add_node("Panel", "Panel", parent=".", properties={
        "layout_mode": 1,
        "anchors_preset": 8,
    })
    scene.add_node("VBoxContainer", "VBoxContainer", parent="Panel", properties={
        "layout_mode": 1,
        "anchors_preset": 15,
    })
    scene.add_node("TitleLabel", "Label", parent="Panel/VBoxContainer", properties={
        "layout_mode": 2,
        "text": f'"{_to_display(system_name)}"',
    })

    scene_path = system_dir / f"{system_name}UI.tscn"
    scene_content = serialize(scene)
    result = safe_write(scene_path, scene_content, overwrite=overwrite)
    files_modified.extend(result["files_modified"])

    return make_response(True, files_modified, f"Created UI for {system_name}")


def _create_data(
    system_name: str, description: str, config: ProjectConfig, overwrite: bool
) -> dict:
    """Create a JSON data structure."""
    data = {
        "_description": description or f"Data for {system_name}",
        "_version": 1,
    }
    data_path = config.detect_data_dir() / f"{_to_snake(system_name)}.json"
    content = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    return safe_write(data_path, content, overwrite=overwrite)


def _create_spawner(
    system_name: str, description: str, system_dir: Path, config: ProjectConfig, overwrite: bool
) -> dict:
    """Create a spawner script following the ResourceSpawner pattern."""
    script = f'''extends Node2D

# {system_name} Spawner - {description}

@export var spawn_scenes: Array[PackedScene] = []
@export var spawn_count: int = 10
@export var spawn_area: Rect2 = Rect2(-500, -500, 1000, 1000)

var spawned_instances: Array[Node] = []

func _ready() -> void:
\tspawn_all()

func spawn_all() -> void:
\tfor i in range(spawn_count):
\t\tspawn_random()

func spawn_random() -> void:
\tif spawn_scenes.is_empty():
\t\treturn
\tvar scene = spawn_scenes.pick_random()
\tvar instance = scene.instantiate()
\tvar pos = Vector2(
\t\trandf_range(spawn_area.position.x, spawn_area.position.x + spawn_area.size.x),
\t\trandf_range(spawn_area.position.y, spawn_area.position.y + spawn_area.size.y)
\t)
\tinstance.global_position = pos
\tadd_child(instance)
\tspawned_instances.append(instance)

func clear_all() -> void:
\tfor instance in spawned_instances:
\t\tif is_instance_valid(instance):
\t\t\tinstance.queue_free()
\tspawned_instances.clear()
'''
    path = system_dir / f"{system_name}Spawner.gd"
    return safe_write(path, script, overwrite=overwrite)


def _create_component(
    system_name: str, component_name: str, description: str, system_dir: Path,
    config: ProjectConfig, overwrite: bool
) -> dict:
    """Create a generic component script."""
    class_name = f"{system_name}{component_name.replace('_', ' ').title().replace(' ', '')}"
    script = f'''extends Node

class_name {class_name}

# {class_name} - Component of {system_name}
# {description}

func _ready() -> void:
\tpass
'''
    path = system_dir / f"{class_name}.gd"
    return safe_write(path, script, overwrite=overwrite)


def _register_autoload(config: ProjectConfig, name: str, res_path: str) -> dict:
    """Add an autoload entry to project.godot."""
    godot_path = config.game_root / "project.godot"
    if not godot_path.exists():
        return make_response(False, [], "project.godot not found")

    content = godot_path.read_text(encoding="utf-8")
    autoload_line = f'{name}="*{res_path}"'

    # Check if already registered
    if autoload_line in content:
        return make_response(True, [], f"Autoload '{name}' already registered")

    lines = content.split("\n")
    in_autoload = False
    insert_idx = None
    for i, line in enumerate(lines):
        if line.strip() == "[autoload]":
            in_autoload = True
            continue
        if in_autoload:
            if line.startswith("[") or (line.strip() == "" and i + 1 < len(lines) and lines[i + 1].startswith("[")):
                insert_idx = i
                break

    if insert_idx is None:
        return make_response(False, [], "Could not find [autoload] section in project.godot")

    lines.insert(insert_idx, autoload_line)
    return safe_write(godot_path, "\n".join(lines), overwrite=True)


def _to_snake(name: str) -> str:
    """Convert PascalCase to snake_case."""
    import re
    return re.sub(r"(?<=[a-z0-9])(?=[A-Z])", "_", name).lower()


def _to_display(name: str) -> str:
    """Convert PascalCase to display name."""
    import re
    return re.sub(r"(?<=[a-z])(?=[A-Z])", " ", name)
