"""Validation tools: comprehensive project analysis for common Godot issues."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).parent.parent))

from config import ProjectConfig
from godot_finder import find_godot_executable
from godot_project_cfg import parse_project_godot
from tscn_parser import parse_file
from utils import make_response

# Node types that require a CollisionShape child
PHYSICS_BODY_TYPES = {
    "Area2D", "CharacterBody2D", "RigidBody2D", "StaticBody2D",
    "Area3D", "CharacterBody3D", "RigidBody3D", "StaticBody3D",
}
COLLISION_SHAPE_TYPES = {
    "CollisionShape2D", "CollisionShape3D",
    "CollisionPolygon2D", "CollisionPolygon3D",
}


def register_validator_tools(mcp: Any, config: ProjectConfig) -> None:
    @mcp.tool()
    def validate_project(checks: list[str] | None = None) -> dict:
        """Run comprehensive validation on the Godot project.

        Scans for common issues including missing resources, broken signals,
        missing collision shapes, orphaned scripts, and more.

        Args:
            checks: List of specific checks to run. Defaults to all. Options:
                'resources' - Missing scripts, textures, preloads, autoloads
                'collisions' - Physics bodies without collision shapes
                'textures' - Sprite nodes without textures assigned
                'signals' - Signal connections to non-existent methods
                'inputs' - Duplicate input key bindings
                'orphaned_scripts' - Scripts not referenced by any scene
                'scripts' - GDScript syntax issues (basic regex checks)

        Returns:
            Dict with success, errors (list), warnings (list),
            error_count, warning_count, summary.
        """
        all_checks = {
            "resources": _check_resources,
            "collisions": _check_missing_collision_shapes,
            "textures": _check_missing_textures,
            "signals": _check_broken_signal_connections,
            "inputs": _check_duplicate_inputs,
            "orphaned_scripts": _check_orphaned_scripts,
            "scripts": _check_script_syntax,
        }

        selected = checks or list(all_checks.keys())
        errors: list[dict[str, Any]] = []
        warnings: list[dict[str, Any]] = []

        for check_name in selected:
            check_fn = all_checks.get(check_name)
            if check_fn is None:
                warnings.append({
                    "type": "unknown_check",
                    "description": f"Unknown check: {check_name}. Available: {', '.join(all_checks.keys())}",
                })
                continue
            check_errors, check_warnings = check_fn(config)
            errors.extend(check_errors)
            warnings.extend(check_warnings)

        checks_run = ", ".join(selected)
        summary = (
            f"Validation complete ({checks_run}): "
            f"{len(errors)} error(s), {len(warnings)} warning(s)"
        )

        return make_response(
            len(errors) == 0,
            [],
            summary,
            errors=errors,
            warnings=warnings,
            error_count=len(errors),
            warning_count=len(warnings),
            checks_run=selected,
        )

    @mcp.tool()
    def validate_script(script_path: str) -> dict:
        """Validate a single GDScript file for syntax issues.

        Uses the Godot CLI if available, otherwise falls back to regex-based checks.

        Args:
            script_path: Path to .gd file (res:// path or relative to game root).

        Returns:
            Dict with success, errors (list), summary.
        """
        if script_path.startswith("res://"):
            abs_path = config.abs_path(script_path)
        else:
            abs_path = config.game_root / script_path

        if not abs_path.exists():
            return make_response(False, [], f"Script not found: {script_path}")

        errors: list[dict[str, Any]] = []

        # Try Godot CLI validation first
        godot_path = find_godot_executable()
        if godot_path:
            cli_errors = _validate_script_with_godot(godot_path, abs_path, config)
            errors.extend(cli_errors)
        else:
            # Fall back to regex checks
            regex_errors = _validate_script_regex(abs_path)
            errors.extend(regex_errors)

        rel_path = str(abs_path.relative_to(config.game_root))
        if errors:
            return make_response(
                False,
                [],
                f"Script {rel_path}: {len(errors)} issue(s) found",
                errors=errors,
            )
        return make_response(True, [], f"Script {rel_path}: no issues found", errors=[])


# --- Check implementations ---

def _check_resources(config: ProjectConfig) -> tuple[list[dict], list[dict]]:
    """Check for missing resources, scripts, preloads, and autoloads."""
    errors: list[dict[str, Any]] = []
    warnings: list[dict[str, Any]] = []

    # Scan .tscn files for broken ext_resource references
    for tscn_file in config.game_root.rglob("*.tscn"):
        if "addons" in tscn_file.parts or ".godot" in tscn_file.parts:
            continue
        try:
            content = tscn_file.read_text(encoding="utf-8")
        except Exception:
            continue

        for match in re.finditer(r'path="(res://[^"]+)"', content):
            res_path = match.group(1)
            abs_path = config.abs_path(res_path)
            if not abs_path.exists():
                rel_tscn = str(tscn_file.relative_to(config.game_root))
                errors.append({
                    "type": "missing_resource",
                    "file": rel_tscn,
                    "reference": res_path,
                    "description": f"Resource not found: {res_path}",
                })

    # Scan .gd files for broken preload/load references
    for gd_file in config.game_root.rglob("*.gd"):
        if "addons" in gd_file.parts or ".godot" in gd_file.parts:
            continue
        try:
            content = gd_file.read_text(encoding="utf-8")
        except Exception:
            continue

        for i, line in enumerate(content.splitlines(), 1):
            for match in re.finditer(r'(?:preload|load)\s*\(\s*"(res://[^"]+)"', line):
                res_path = match.group(1)
                abs_path = config.abs_path(res_path)
                if not abs_path.exists():
                    rel_gd = str(gd_file.relative_to(config.game_root))
                    errors.append({
                        "type": "missing_preload",
                        "file": rel_gd,
                        "line": i,
                        "reference": res_path,
                        "description": f"preload/load target not found: {res_path}",
                    })

    # Check autoloads
    autoloads = config.get_autoloads()
    for name, path_str in autoloads.items():
        clean_path = path_str.lstrip("*")
        abs_path = config.abs_path(clean_path)
        if not abs_path.exists():
            errors.append({
                "type": "missing_autoload",
                "file": "project.godot",
                "reference": clean_path,
                "description": f"Autoload '{name}' file not found: {clean_path}",
            })

    return errors, warnings


def _check_missing_collision_shapes(config: ProjectConfig) -> tuple[list[dict], list[dict]]:
    """Check that physics body nodes have collision shape children."""
    errors: list[dict[str, Any]] = []
    warnings: list[dict[str, Any]] = []

    for tscn_file in config.game_root.rglob("*.tscn"):
        if "addons" in tscn_file.parts or ".godot" in tscn_file.parts:
            continue
        try:
            scene = parse_file(str(tscn_file))
        except Exception:
            continue

        rel_path = str(tscn_file.relative_to(config.game_root))

        # Build parent -> children type mapping
        for i, node in enumerate(scene.nodes):
            if node.type in PHYSICS_BODY_TYPES:
                # Check if this node has a collision shape child
                node_path = _node_path(scene.nodes, i)
                has_shape = False
                for j, child in enumerate(scene.nodes):
                    child_parent = child.parent
                    if child_parent is None:
                        continue
                    # Match: child's parent should be this node's path
                    expected_parent = "." if node.parent is None else node_path
                    if child_parent == expected_parent and child.type in COLLISION_SHAPE_TYPES:
                        has_shape = True
                        break

                if not has_shape:
                    warnings.append({
                        "type": "missing_collision_shape",
                        "file": rel_path,
                        "node": node_path,
                        "node_type": node.type,
                        "description": f"{node.type} '{node.name}' has no CollisionShape child in {rel_path}",
                    })

    return errors, warnings


def _check_missing_textures(config: ProjectConfig) -> tuple[list[dict], list[dict]]:
    """Check that Sprite nodes have textures assigned."""
    warnings: list[dict[str, Any]] = []

    sprite_types = {"Sprite2D", "Sprite3D"}

    for tscn_file in config.game_root.rglob("*.tscn"):
        if "addons" in tscn_file.parts or ".godot" in tscn_file.parts:
            continue
        try:
            scene = parse_file(str(tscn_file))
        except Exception:
            continue

        rel_path = str(tscn_file.relative_to(config.game_root))

        for i, node in enumerate(scene.nodes):
            if node.type in sprite_types:
                has_texture = "texture" in (node.raw_properties or "")
                if not has_texture:
                    warnings.append({
                        "type": "missing_texture",
                        "file": rel_path,
                        "node": _node_path(scene.nodes, i),
                        "description": f"Sprite '{node.name}' has no texture in {rel_path}",
                    })

    return [], warnings


def _check_broken_signal_connections(config: ProjectConfig) -> tuple[list[dict], list[dict]]:
    """Check that signal connection methods exist in target scripts."""
    errors: list[dict[str, Any]] = []
    warnings: list[dict[str, Any]] = []

    for tscn_file in config.game_root.rglob("*.tscn"):
        if "addons" in tscn_file.parts or ".godot" in tscn_file.parts:
            continue
        try:
            scene = parse_file(str(tscn_file))
        except Exception:
            continue

        if not scene.connections:
            continue

        rel_path = str(tscn_file.relative_to(config.game_root))

        # Build node name -> script path mapping
        node_scripts: dict[str, str] = {}
        for node in scene.nodes:
            if node.raw_properties:
                script_match = re.search(
                    r'script\s*=\s*ExtResource\("([^"]+)"\)', node.raw_properties
                )
                if script_match:
                    ext_id = script_match.group(1)
                    for ext in scene.ext_resources:
                        if ext.id == ext_id and ext.type == "Script":
                            node_name = node.name
                            node_scripts[node_name] = ext.path
                            break

        # Check each connection
        for conn in scene.connections:
            target_node = conn.to_node
            # The to_node is a path like "." or "Player" - extract the node name
            target_name = target_node.split("/")[-1] if "/" in target_node else target_node
            if target_name == ".":
                # Root node - find it
                if scene.nodes:
                    target_name = scene.nodes[0].name

            script_path = node_scripts.get(target_name)
            if script_path is None:
                continue  # Node has no script, can't verify method

            # Read the script and check for the method
            abs_script = config.abs_path(script_path)
            if abs_script.exists():
                try:
                    script_content = abs_script.read_text(encoding="utf-8")
                    method_pattern = rf"func\s+{re.escape(conn.method)}\s*\("
                    if not re.search(method_pattern, script_content):
                        warnings.append({
                            "type": "broken_signal",
                            "file": rel_path,
                            "signal": conn.signal,
                            "from": conn.from_node,
                            "to": conn.to_node,
                            "method": conn.method,
                            "description": (
                                f"Signal '{conn.signal}' connects to method '{conn.method}' "
                                f"but it was not found in {script_path}"
                            ),
                        })
                except OSError:
                    pass

    return errors, warnings


def _check_duplicate_inputs(config: ProjectConfig) -> tuple[list[dict], list[dict]]:
    """Check for duplicate key bindings across input actions."""
    warnings: list[dict[str, Any]] = []

    project_path = config.get_project_godot_path()
    if not project_path.exists():
        return [], warnings

    cfg = parse_project_godot(project_path)
    input_section = cfg.sections.get("input", {})

    # Extract physical_keycode from each action
    key_to_actions: dict[int, list[str]] = {}

    for action_name, raw_value in input_section.items():
        for match in re.finditer(r'"physical_keycode":(\d+)', raw_value):
            keycode = int(match.group(1))
            if keycode == 0:
                continue  # Skip unset keycodes
            key_to_actions.setdefault(keycode, []).append(action_name)

    # Also check mouse buttons
    btn_to_actions: dict[int, list[str]] = {}
    for action_name, raw_value in input_section.items():
        for match in re.finditer(r'"button_index":(\d+)', raw_value):
            btn = int(match.group(1))
            btn_to_actions.setdefault(btn, []).append(action_name)

    for keycode, actions in key_to_actions.items():
        if len(actions) > 1:
            warnings.append({
                "type": "duplicate_input",
                "keycode": keycode,
                "actions": actions,
                "description": f"Key {keycode} is bound to multiple actions: {', '.join(actions)}",
            })

    for btn, actions in btn_to_actions.items():
        if len(actions) > 1:
            warnings.append({
                "type": "duplicate_input",
                "button_index": btn,
                "actions": actions,
                "description": f"Mouse button {btn} is bound to multiple actions: {', '.join(actions)}",
            })

    return [], warnings


def _check_orphaned_scripts(config: ProjectConfig) -> tuple[list[dict], list[dict]]:
    """Find .gd scripts not referenced by any scene or autoload."""
    warnings: list[dict[str, Any]] = []

    # Collect all .gd files
    all_scripts: set[str] = set()
    for gd_file in config.game_root.rglob("*.gd"):
        if "addons" in gd_file.parts or ".godot" in gd_file.parts:
            continue
        rel = str(gd_file.relative_to(config.game_root)).replace("\\", "/")
        all_scripts.add(rel)

    # Collect all script references from .tscn files
    referenced: set[str] = set()
    for tscn_file in config.game_root.rglob("*.tscn"):
        if "addons" in tscn_file.parts or ".godot" in tscn_file.parts:
            continue
        try:
            content = tscn_file.read_text(encoding="utf-8")
        except Exception:
            continue
        for match in re.finditer(r'path="res://([^"]+\.gd)"', content):
            referenced.add(match.group(1))

    # Collect autoload references
    autoloads = config.get_autoloads()
    for path_str in autoloads.values():
        clean = path_str.lstrip("*").replace("res://", "")
        referenced.add(clean)

    # Collect preload/load references from other scripts
    for gd_file in config.game_root.rglob("*.gd"):
        if "addons" in gd_file.parts or ".godot" in gd_file.parts:
            continue
        try:
            content = gd_file.read_text(encoding="utf-8")
        except Exception:
            continue
        for match in re.finditer(r'(?:preload|load)\s*\(\s*"res://([^"]+\.gd)"', content):
            referenced.add(match.group(1))

    # Find orphaned scripts
    orphaned = all_scripts - referenced
    for script in sorted(orphaned):
        warnings.append({
            "type": "orphaned_script",
            "file": script,
            "description": f"Script not referenced by any scene or autoload: {script}",
        })

    return [], warnings


def _check_script_syntax(config: ProjectConfig) -> tuple[list[dict], list[dict]]:
    """Basic GDScript syntax checks using regex patterns."""
    errors: list[dict[str, Any]] = []
    warnings: list[dict[str, Any]] = []

    for gd_file in config.game_root.rglob("*.gd"):
        if "addons" in gd_file.parts or ".godot" in gd_file.parts:
            continue

        file_errors = _validate_script_regex(gd_file)
        rel_path = str(gd_file.relative_to(config.game_root))
        for err in file_errors:
            err["file"] = rel_path
            if err.get("severity") == "warning":
                warnings.append(err)
            else:
                errors.append(err)

    return errors, warnings


# --- Internal helpers ---

def _node_path(nodes: list, idx: int) -> str:
    """Get the tree path of a node."""
    node = nodes[idx]
    if node.parent is None:
        return node.name
    if node.parent == ".":
        return node.name
    return f"{node.parent}/{node.name}"


def _validate_script_with_godot(godot_path: str, script_path: Path, config: ProjectConfig) -> list[dict]:
    """Validate a script using the Godot CLI."""
    errors = []
    try:
        result = subprocess.run(
            [godot_path, "--path", str(config.game_root), "--headless", "--check-only", "--script", str(script_path)],
            capture_output=True,
            text=True,
            timeout=15,
        )
        if result.returncode != 0:
            for line in (result.stderr + result.stdout).splitlines():
                if "error" in line.lower() or "Error" in line:
                    errors.append({
                        "type": "script_error",
                        "description": line.strip(),
                    })
    except (subprocess.TimeoutExpired, OSError):
        pass
    return errors


def _validate_script_regex(gd_file: Path) -> list[dict]:
    """Basic regex-based GDScript syntax checks."""
    errors: list[dict[str, Any]] = []
    try:
        content = gd_file.read_text(encoding="utf-8")
    except Exception:
        return errors

    lines = content.splitlines()
    paren_depth = 0
    bracket_depth = 0

    for i, line in enumerate(lines, 1):
        stripped = line.strip()

        # Skip comments and empty lines
        if not stripped or stripped.startswith("#"):
            continue

        # Track parentheses/brackets across lines
        for ch in stripped:
            if ch == "(":
                paren_depth += 1
            elif ch == ")":
                paren_depth -= 1
            elif ch == "[":
                bracket_depth += 1
            elif ch == "]":
                bracket_depth -= 1

        # Check for func without colon (only if parentheses are balanced)
        if paren_depth == 0 and re.match(r"^func\s+\w+\s*\([^)]*\)\s*$", stripped):
            if not stripped.endswith(":") and "->" not in stripped:
                errors.append({
                    "type": "syntax_warning",
                    "severity": "warning",
                    "line": i,
                    "description": f"Line {i}: 'func' declaration may be missing ':'",
                })

    # Check for deeply negative depth (mismatched brackets)
    if paren_depth != 0:
        errors.append({
            "type": "syntax_error",
            "description": f"Unmatched parentheses (depth: {paren_depth})",
        })
    if bracket_depth != 0:
        errors.append({
            "type": "syntax_error",
            "description": f"Unmatched brackets (depth: {bracket_depth})",
        })

    return errors
