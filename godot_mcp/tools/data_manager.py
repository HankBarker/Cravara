"""Game data manager tools: read/write JSON data files with nested key support."""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).parent.parent))

from config import ProjectConfig
from utils import make_response, safe_write


def register_data_tools(mcp: Any, config: ProjectConfig) -> None:
    @mcp.tool()
    def update_game_data(
        file_path: str,
        key_path: str,
        value: Any,
    ) -> dict:
        """Read or modify a JSON data file with nested key support.

        Creates the file and intermediate directories if they don't exist.
        Used for creature stats, crafting recipes, biome spawn rules,
        item definitions, and boss attributes.

        Args:
            file_path: Path to JSON file relative to game root (e.g. "Data/creatures.json").
            key_path: Dot-separated path to the key (e.g. "creatures.raptor.health").
            value: Value to set. The value can be any JSON-serializable type
                (string, number, bool, list, dict). Use null/None to delete a key.

        Returns:
            Dict with success, files_modified, summary, and current_value.
        """
        abs_path = config.game_root / file_path

        # Load or initialize
        if abs_path.exists():
            try:
                data = json.loads(abs_path.read_text(encoding="utf-8"))
            except json.JSONDecodeError as e:
                return make_response(False, [], f"Invalid JSON in {file_path}: {e}")
        else:
            data = {}

        keys = key_path.split(".")

        # Navigate to parent, creating intermediate dicts as needed
        current = data
        for key in keys[:-1]:
            if key not in current or not isinstance(current[key], dict):
                current[key] = {}
            current = current[key]

        last_key = keys[-1]

        if value is None:
            # Delete mode
            old_value = current.pop(last_key, None)
            summary = f"Deleted {key_path} (was {old_value}) in {file_path}"
        else:
            old_value = current.get(last_key)
            current[last_key] = value
            summary = f"Set {key_path} = {json.dumps(value)} in {file_path}"

        # Write the file
        content = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
        result = safe_write(abs_path, content, overwrite=True)
        result["summary"] = summary
        result["current_value"] = current.get(last_key) if value is not None else old_value
        return result

    @mcp.tool()
    def read_game_data(
        file_path: str,
        key_path: str = "",
    ) -> dict:
        """Read a JSON data file or a specific nested key.

        Args:
            file_path: Path to JSON file relative to game root (e.g. "Data/creatures.json").
            key_path: Optional dot-separated path. Empty string returns entire file contents.

        Returns:
            Dict with success, data (the value at key_path or entire file), summary.
        """
        abs_path = config.game_root / file_path

        if not abs_path.exists():
            return make_response(False, [], f"File not found: {file_path}")

        try:
            data = json.loads(abs_path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as e:
            return make_response(False, [], f"Invalid JSON in {file_path}: {e}")

        if not key_path:
            return make_response(True, [], f"Read {file_path}", data=data)

        # Navigate to key
        current = data
        for key in key_path.split("."):
            if isinstance(current, dict) and key in current:
                current = current[key]
            else:
                return make_response(True, [], f"Key '{key_path}' not found in {file_path}", data=None)

        return make_response(True, [], f"Read {key_path} from {file_path}", data=current)
