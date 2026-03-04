"""Shared utilities for the Godot MCP server."""

import random
import string
from pathlib import Path
from typing import Any


def generate_id_suffix(length: int = 5) -> str:
    """Generate a random alphanumeric suffix like 'jmhoe' for resource IDs."""
    return "".join(random.choices(string.ascii_lowercase + string.digits, k=length))


def generate_ext_resource_id(counter: int) -> str:
    """Generate ext_resource ID like '1_jmhoe'."""
    return f"{counter}_{generate_id_suffix()}"


def generate_sub_resource_id(type_name: str) -> str:
    """Generate sub_resource ID like 'CapsuleShape2D_jmhoe'."""
    return f"{type_name}_{generate_id_suffix()}"


def generate_scene_uid() -> str:
    """Generate scene UID like 'uid://dsm7g22v86nxj'."""
    chars = string.ascii_lowercase + string.digits
    uid_str = "".join(random.choices(chars, k=13))
    return f"uid://{uid_str}"


def safe_write(path: Path, content: str, overwrite: bool = False) -> dict[str, Any]:
    """Write file content safely, refusing to overwrite unless told to."""
    if path.exists() and not overwrite:
        return {
            "success": False,
            "files_modified": [],
            "summary": f"File already exists: {path}. Use overwrite=True to replace.",
        }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return {
        "success": True,
        "files_modified": [str(path)],
        "summary": f"Wrote {path}",
    }


def make_response(
    success: bool, files_modified: list[str], summary: str, **extra: Any
) -> dict[str, Any]:
    """Build a standard tool response dict."""
    resp = {
        "success": success,
        "files_modified": files_modified,
        "summary": summary,
    }
    resp.update(extra)
    return resp


def format_tscn_value(value: Any) -> str:
    """Format a Python value for .tscn property output.

    Handles Godot-specific types: Vector2(...), ExtResource(...), SubResource(...),
    Color(...), Rect2(...), booleans, numbers, and quoted strings.
    """
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, str):
        # Godot expression patterns that should not be quoted
        godot_prefixes = (
            "ExtResource(",
            "SubResource(",
            "Vector2(",
            "Vector3(",
            "Color(",
            "Rect2(",
            "Array[",
            "PackedStringArray(",
            "&\"",
        )
        if value in ("true", "false"):
            return value
        for prefix in godot_prefixes:
            if value.startswith(prefix):
                return value
        # Check if it looks like a number
        try:
            float(value)
            return value
        except ValueError:
            pass
        return f'"{value}"'
    return str(value)
