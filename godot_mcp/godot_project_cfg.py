"""Parser and serializer for Godot's project.godot configuration file.

Handles the quirky INI-like format including:
- Multi-line values (input mappings with Object(...) spanning multiple lines)
- Brace-delimited blocks { ... }
- Godot expression values: PackedStringArray(...), Vector2(...), Object(...)
- Comment lines starting with ;
- Top-level keys outside any section (like config_version=5)
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


@dataclass
class GodotProjectConfig:
    """Parsed project.godot file."""

    top_level: dict[str, str] = field(default_factory=dict)
    sections: dict[str, dict[str, str]] = field(default_factory=dict)
    raw_text: str = ""


def parse_project_godot(filepath: Path) -> GodotProjectConfig:
    """Parse a project.godot file into structured data.

    Uses brace-depth counting to correctly handle multi-line values
    like input mappings that contain Object(...) expressions.

    Args:
        filepath: Path to the project.godot file.

    Returns:
        GodotProjectConfig with parsed sections and raw text.
    """
    raw_text = filepath.read_text(encoding="utf-8")
    cfg = GodotProjectConfig(raw_text=raw_text)

    lines = raw_text.split("\n")
    current_section: str | None = None
    current_key: str | None = None
    current_value_lines: list[str] = []
    brace_depth = 0

    for line in lines:
        stripped = line.strip()

        # Skip empty lines and comments when not accumulating multi-line value
        if brace_depth == 0:
            if not stripped or stripped.startswith(";"):
                # If we were accumulating a key, flush it
                if current_key is not None:
                    _store_setting(cfg, current_section, current_key, current_value_lines)
                    current_key = None
                    current_value_lines = []
                continue

            # Section header
            section_match = re.match(r"^\[(.+)\]$", stripped)
            if section_match:
                # Flush any pending key
                if current_key is not None:
                    _store_setting(cfg, current_section, current_key, current_value_lines)
                    current_key = None
                    current_value_lines = []
                current_section = section_match.group(1)
                if current_section not in cfg.sections:
                    cfg.sections[current_section] = {}
                continue

            # Key=Value line
            eq_pos = stripped.find("=")
            if eq_pos > 0 and current_key is None:
                # Flush any previous key
                key = stripped[:eq_pos].strip()
                value_part = stripped[eq_pos + 1:]
                current_key = key
                current_value_lines = [value_part]
                # Count braces to detect multi-line values
                brace_depth = _count_brace_depth(value_part)
                if brace_depth == 0:
                    # Single-line value, flush immediately
                    _store_setting(cfg, current_section, current_key, current_value_lines)
                    current_key = None
                    current_value_lines = []
                continue

        # Accumulating multi-line value
        if brace_depth > 0 and current_key is not None:
            current_value_lines.append(line)
            brace_depth += _count_brace_depth(line)
            if brace_depth <= 0:
                brace_depth = 0
                _store_setting(cfg, current_section, current_key, current_value_lines)
                current_key = None
                current_value_lines = []
            continue

    # Flush any remaining key
    if current_key is not None:
        _store_setting(cfg, current_section, current_key, current_value_lines)

    return cfg


def get_setting(cfg: GodotProjectConfig, key: str) -> str | None:
    """Get a project setting by section/key path.

    The key format is 'section/rest_of_key', where:
    - First segment is the section name (e.g., 'display', 'input', 'application')
    - Remaining segments form the setting key within that section

    Examples:
        'display/window/size/viewport_width'  -> section='display', key='window/size/viewport_width'
        'application/config/name'              -> section='application', key='config/name'
        'input/Up'                             -> section='input', key='Up'

    For top-level keys (outside any section):
        'config_version'                       -> top_level key

    Args:
        cfg: Parsed project config.
        key: Slash-separated key path.

    Returns:
        The value as a string, or None if not found.
    """
    # Check top-level first
    if key in cfg.top_level:
        return cfg.top_level[key]

    # Split into section + setting key
    parts = key.split("/", 1)
    if len(parts) == 1:
        # Single segment - could be a top-level key or section name
        return cfg.top_level.get(key)

    section = parts[0]
    setting_key = parts[1]

    section_data = cfg.sections.get(section, {})
    return section_data.get(setting_key)


def set_setting(cfg: GodotProjectConfig, key: str, value: str) -> bool:
    """Set a project setting value using targeted text replacement.

    Modifies both the structured data and the raw_text to maintain consistency.
    Uses surgical replacement to avoid corrupting multi-line values we did not modify.

    Args:
        cfg: Parsed project config.
        key: Setting path (same format as get_setting).
        value: New value as a string.

    Returns:
        True if the setting was modified, False if it was a new key that was added.
    """
    # Determine section and setting key
    parts = key.split("/", 1)
    if len(parts) == 1:
        old_value = cfg.top_level.get(key)
        cfg.top_level[key] = value
        if old_value is not None:
            cfg.raw_text = _replace_setting_in_raw(cfg.raw_text, None, key, old_value, value)
            return True
        else:
            # Add new top-level key before the first section
            cfg.raw_text = _add_setting_to_raw(cfg.raw_text, None, key, value)
            return False

    section = parts[0]
    setting_key = parts[1]

    if section not in cfg.sections:
        cfg.sections[section] = {}

    old_value = cfg.sections[section].get(setting_key)
    cfg.sections[section][setting_key] = value

    if old_value is not None:
        cfg.raw_text = _replace_setting_in_raw(cfg.raw_text, section, setting_key, old_value, value)
        return True
    else:
        cfg.raw_text = _add_setting_to_raw(cfg.raw_text, section, setting_key, value)
        return False


def serialize_project_godot(cfg: GodotProjectConfig) -> str:
    """Return the raw text of the config (with any modifications applied).

    Since set_setting() maintains raw_text via targeted replacement,
    this simply returns the raw_text.
    """
    return cfg.raw_text


def write_project_godot(cfg: GodotProjectConfig, filepath: Path) -> None:
    """Write the config back to disk."""
    filepath.write_text(cfg.raw_text, encoding="utf-8")


# --- Keycode mappings for human-readable input action display ---

# Common Godot physical keycodes to readable names
KEYCODE_MAP: dict[int, str] = {
    32: "Space", 39: "'", 44: ",", 45: "-", 46: ".", 47: "/",
    48: "0", 49: "1", 50: "2", 51: "3", 52: "4", 53: "5",
    54: "6", 55: "7", 56: "8", 57: "9",
    59: ";", 61: "=",
    65: "A", 66: "B", 67: "C", 68: "D", 69: "E", 70: "F",
    71: "G", 72: "H", 73: "I", 74: "J", 75: "K", 76: "L",
    77: "M", 78: "N", 79: "O", 80: "P", 81: "Q", 82: "R",
    83: "S", 84: "T", 85: "U", 86: "V", 87: "W", 88: "X",
    89: "Y", 90: "Z",
    91: "[", 92: "\\", 93: "]", 96: "`",
    # Special keys
    4194304: "Escape", 4194305: "Escape", 4194306: "Tab",
    4194309: "Enter", 4194310: "KP_Enter",
    4194311: "Insert", 4194312: "Delete",
    4194319: "Up", 4194320: "Down", 4194321: "Left", 4194322: "Right",
    4194323: "Home", 4194324: "End",
    4194325: "Shift", 4194326: "Ctrl", 4194327: "Alt", 4194328: "Meta",
    4194332: "F1", 4194333: "F2", 4194334: "F3", 4194335: "F4",
    4194336: "F5", 4194337: "F6", 4194338: "F7", 4194339: "F8",
    4194340: "F9", 4194341: "F10", 4194342: "F11", 4194343: "F12",
    # Mouse buttons (button_index values)
    1: "Mouse Left", 2: "Mouse Right", 3: "Mouse Middle",
}


def parse_input_actions(cfg: GodotProjectConfig) -> list[dict[str, Any]]:
    """Parse the [input] section into a readable list of input actions.

    Returns:
        List of dicts with keys: name, deadzone, events (list of readable strings).
    """
    input_section = cfg.sections.get("input", {})
    actions = []

    for action_name, raw_value in input_section.items():
        action: dict[str, Any] = {
            "name": action_name,
            "deadzone": 0.2,
            "events": [],
        }

        # Extract deadzone
        dz_match = re.search(r'"deadzone":\s*([\d.]+)', raw_value)
        if dz_match:
            action["deadzone"] = float(dz_match.group(1))

        # Extract event objects
        for obj_match in re.finditer(r"Object\((\w+),([^)]*(?:\([^)]*\))*[^)]*)\)", raw_value):
            event_type = obj_match.group(1)
            event_data = obj_match.group(2)

            if event_type == "InputEventKey":
                keycode_match = re.search(r'"physical_keycode":(\d+)', event_data)
                if keycode_match:
                    code = int(keycode_match.group(1))
                    key_name = KEYCODE_MAP.get(code, f"Key({code})")
                    action["events"].append(f"Key: {key_name}")
            elif event_type == "InputEventMouseButton":
                btn_match = re.search(r'"button_index":(\d+)', event_data)
                if btn_match:
                    btn = int(btn_match.group(1))
                    btn_name = KEYCODE_MAP.get(btn, f"Button({btn})")
                    action["events"].append(f"Mouse: {btn_name}")
            elif event_type == "InputEventJoypadButton":
                btn_match = re.search(r'"button_index":(\d+)', event_data)
                if btn_match:
                    action["events"].append(f"Joypad: Button({btn_match.group(1)})")

        actions.append(action)

    return actions


# --- Internal helpers ---

def _count_brace_depth(text: str) -> int:
    """Count net brace depth change in a line (opening minus closing)."""
    depth = 0
    in_string = False
    escape_next = False
    for ch in text:
        if escape_next:
            escape_next = False
            continue
        if ch == "\\":
            escape_next = True
            continue
        if ch == '"':
            in_string = not in_string
            continue
        if not in_string:
            if ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
    return depth


def _store_setting(
    cfg: GodotProjectConfig,
    section: str | None,
    key: str,
    value_lines: list[str],
) -> None:
    """Store a parsed key-value pair into the config."""
    value = "\n".join(value_lines)
    if section is None:
        cfg.top_level[key] = value
    else:
        if section not in cfg.sections:
            cfg.sections[section] = {}
        cfg.sections[section][key] = value


def _replace_setting_in_raw(
    raw_text: str,
    section: str | None,
    key: str,
    old_value: str,
    new_value: str,
) -> str:
    """Replace a setting's value in the raw text using targeted substitution.

    For single-line values, replaces `key=old_value` with `key=new_value`.
    For multi-line values, replaces the entire block.
    """
    lines = raw_text.split("\n")
    result_lines: list[str] = []
    in_target_section = section is None  # Top-level is always "in section"
    found = False
    skip_until_brace_close = False
    brace_depth = 0

    for i, line in enumerate(lines):
        stripped = line.strip()

        # Track section changes
        section_match = re.match(r"^\[(.+)\]$", stripped)
        if section_match:
            if section is None:
                in_target_section = False
            else:
                in_target_section = section_match.group(1) == section

        # Skip lines that are part of a multi-line value being replaced
        if skip_until_brace_close:
            brace_depth += _count_brace_depth(line)
            if brace_depth <= 0:
                skip_until_brace_close = False
            continue

        # Look for the key in the target section
        if in_target_section and not found and stripped.startswith(key + "="):
            found = True
            # Check if old value is multi-line
            if "\n" in old_value:
                # Replace key=first_line and skip subsequent lines
                result_lines.append(f"{key}={new_value}")
                brace_depth = _count_brace_depth(line.split("=", 1)[1] if "=" in line else "")
                if brace_depth > 0:
                    skip_until_brace_close = True
            else:
                result_lines.append(f"{key}={new_value}")
            continue

        result_lines.append(line)

    if found:
        return "\n".join(result_lines)
    return raw_text


def _add_setting_to_raw(
    raw_text: str,
    section: str | None,
    key: str,
    value: str,
) -> str:
    """Add a new setting to the raw text."""
    if section is None:
        # Add before the first section
        lines = raw_text.split("\n")
        insert_idx = 0
        for i, line in enumerate(lines):
            if line.strip().startswith("["):
                insert_idx = i
                break
        else:
            insert_idx = len(lines)
        lines.insert(insert_idx, f"{key}={value}")
        return "\n".join(lines)

    # Find the section and add at the end of it
    lines = raw_text.split("\n")
    in_section = False
    last_section_line = -1

    for i, line in enumerate(lines):
        stripped = line.strip()
        section_match = re.match(r"^\[(.+)\]$", stripped)
        if section_match:
            if in_section:
                # We've left the target section, insert before this line
                lines.insert(i, f"{key}={value}")
                return "\n".join(lines)
            in_section = section_match.group(1) == section
            if in_section:
                last_section_line = i
            continue

        if in_section and stripped:
            last_section_line = i

    if last_section_line >= 0:
        # Add after the last line in the section
        lines.insert(last_section_line + 1, f"{key}={value}")
    else:
        # Section doesn't exist, create it
        lines.append("")
        lines.append(f"[{section}]")
        lines.append("")
        lines.append(f"{key}={value}")

    return "\n".join(lines)
