"""Screen and state capture tools: screenshots, scene state, UI layout."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import time
from datetime import datetime
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).parent.parent))

from config import ProjectConfig
from godot_finder import find_godot_executable, get_not_found_message
from utils import make_response


def register_capture_tools(mcp: Any, config: ProjectConfig) -> None:
    @mcp.tool()
    def capture_screenshot(output_path: str = "") -> dict:
        """Capture a screenshot of the Godot window using PowerShell.

        Takes a full-screen screenshot and saves it as a PNG file.
        If no output_path is given, saves to game/.screenshots/ with a
        timestamped filename.

        Args:
            output_path: Optional output file path. If empty, auto-generates.

        Returns:
            Dict with success, file_path, summary.
        """
        if output_path:
            out = Path(output_path)
        else:
            screenshots_dir = config.game_root / ".screenshots"
            screenshots_dir.mkdir(parents=True, exist_ok=True)
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            out = screenshots_dir / f"capture_{timestamp}.png"

        out.parent.mkdir(parents=True, exist_ok=True)

        # PowerShell script to capture the screen
        ps_script = f"""
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$screen = [System.Windows.Forms.Screen]::PrimaryScreen
$bounds = $screen.Bounds
$bitmap = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
$bitmap.Save('{str(out).replace(chr(39), chr(39)+chr(39))}', [System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bitmap.Dispose()
Write-Output 'OK'
"""
        try:
            result = subprocess.run(
                ["powershell", "-NoProfile", "-Command", ps_script],
                capture_output=True,
                text=True,
                timeout=15,
            )
            if result.returncode != 0 or not out.exists():
                stderr = result.stderr.strip() if result.stderr else "Unknown error"
                return make_response(False, [], f"Screenshot failed: {stderr}")

            size_kb = out.stat().st_size / 1024
            return make_response(
                True,
                [str(out)],
                f"Screenshot saved: {out.name} ({size_kb:.0f} KB)",
                file_path=str(out),
                size_bytes=out.stat().st_size,
            )
        except subprocess.TimeoutExpired:
            return make_response(False, [], "Screenshot timed out (15s)")
        except OSError as e:
            return make_response(False, [], f"Screenshot failed: {e}")

    @mcp.tool()
    def capture_scene_state(
        scene_path: str,
        timeout_seconds: int = 5,
    ) -> dict:
        """Capture runtime scene state by injecting a diagnostic script.

        Runs a scene headless with a temporary GDScript that dumps the
        scene tree (node names, types, positions) to stdout, then parses
        the output.

        Args:
            scene_path: Path to the scene (res:// or relative).
            timeout_seconds: Max seconds to run (default 5).

        Returns:
            Dict with success, nodes (list of dicts), summary.
        """
        godot_path = find_godot_executable()
        if godot_path is None:
            return make_response(False, [], get_not_found_message())

        if scene_path.startswith("res://"):
            abs_scene = config.abs_path(scene_path)
        else:
            abs_scene = config.game_root / scene_path

        if not abs_scene.exists():
            return make_response(False, [], f"Scene not found: {scene_path}")

        # Create a temporary GDScript that dumps scene tree info
        dump_script = _make_dump_script("tree")

        tmp_dir = Path(tempfile.gettempdir()) / "godot_mcp_capture"
        tmp_dir.mkdir(parents=True, exist_ok=True)
        tmp_script = tmp_dir / "dump_scene_state.gd"
        tmp_script.write_text(dump_script, encoding="utf-8")

        try:
            # Run the scene with the diagnostic script auto-loaded
            result = subprocess.run(
                [
                    godot_path,
                    "--path", str(config.game_root),
                    "--headless",
                    "--script", str(tmp_script),
                ],
                capture_output=True,
                text=True,
                timeout=timeout_seconds,
            )
            output = result.stdout + result.stderr
        except subprocess.TimeoutExpired as e:
            output = ""
            if e.stdout:
                output += e.stdout.decode() if isinstance(e.stdout, bytes) else e.stdout
            if e.stderr:
                output += e.stderr.decode() if isinstance(e.stderr, bytes) else e.stderr
        except OSError as e:
            return make_response(False, [], f"Failed to run scene: {e}")
        finally:
            try:
                tmp_script.unlink(missing_ok=True)
            except OSError:
                pass

        # Parse the dump output
        nodes = _parse_dump_output(output, "SCENE_DUMP")

        if not nodes:
            return make_response(
                True,
                [],
                "Scene ran but no tree data captured (scene may need to run with display)",
                nodes=[],
                raw_output=output[-2000:] if len(output) > 2000 else output,
            )

        return make_response(
            True,
            [],
            f"Captured {len(nodes)} nodes from scene tree",
            nodes=nodes,
        )

    @mcp.tool()
    def capture_ui_layout(scene_path: str) -> dict:
        """Capture UI layout information from a scene.

        Parses the .tscn file to extract Control node positions, sizes,
        anchors, and hierarchy. Does not require running the game.

        Args:
            scene_path: Path to the scene (res:// or relative).

        Returns:
            Dict with success, controls (list of dicts), summary.
        """
        if scene_path.startswith("res://"):
            abs_scene = config.abs_path(scene_path)
        else:
            abs_scene = config.game_root / scene_path

        if not abs_scene.exists():
            return make_response(False, [], f"Scene not found: {scene_path}")

        try:
            content = abs_scene.read_text(encoding="utf-8")
        except OSError as e:
            return make_response(False, [], f"Failed to read scene: {e}")

        # Import tscn_parser
        try:
            from tscn_parser import parse
        except ImportError:
            return make_response(False, [], "tscn_parser not available")

        scene = parse(content)

        # Extract Control-derived nodes
        control_types = {
            "Control", "Panel", "PanelContainer", "MarginContainer",
            "HBoxContainer", "VBoxContainer", "GridContainer",
            "CenterContainer", "ScrollContainer", "TabContainer",
            "Button", "Label", "TextEdit", "LineEdit", "RichTextLabel",
            "TextureRect", "NinePatchRect", "ColorRect",
            "ItemList", "Tree", "OptionButton", "SpinBox",
            "ProgressBar", "HSlider", "VSlider",
            "TabBar", "MenuBar", "PopupMenu",
        }

        controls: list[dict] = []
        for node in scene.nodes:
            if node.type in control_types or _has_control_properties(node.raw_properties):
                info: dict[str, Any] = {
                    "name": node.name,
                    "type": node.type,
                    "parent": node.parent if node.parent is not None else "(root)",
                }

                # Extract layout properties from raw_properties
                props = _extract_layout_properties(node.raw_properties)
                info.update(props)
                controls.append(info)

        return make_response(
            True,
            [],
            f"Found {len(controls)} UI control(s) in {abs_scene.name}",
            controls=controls,
        )


# --- Internal helpers ---


def _make_dump_script(mode: str) -> str:
    """Generate a GDScript that dumps scene tree info and quits."""
    return """extends SceneTree

func _init():
    # Wait one frame for the scene to fully load
    await process_frame
    await process_frame

    var root = get_root()
    if root.get_child_count() > 0:
        var scene_root = root.get_child(root.get_child_count() - 1)
        print("SCENE_DUMP_START")
        _dump_node(scene_root, "")
        print("SCENE_DUMP_END")
    else:
        print("SCENE_DUMP_START")
        print("NO_SCENE_LOADED")
        print("SCENE_DUMP_END")
    quit()

func _dump_node(node: Node, indent: String):
    var info = indent + "NODE|" + node.name + "|" + node.get_class()
    if node is Node2D:
        info += "|pos=" + str(node.position)
    if node is Control:
        info += "|pos=" + str(node.position)
        info += "|size=" + str(node.size)
    print(info)
    for child in node.get_children():
        _dump_node(child, indent + "  ")
"""


def _parse_dump_output(output: str, marker: str) -> list[dict]:
    """Parse node dump output between START/END markers."""
    nodes: list[dict] = []
    in_dump = False

    for line in output.splitlines():
        line = line.strip()
        if line == f"{marker}_START":
            in_dump = True
            continue
        if line == f"{marker}_END":
            break
        if not in_dump:
            continue
        if line == "NO_SCENE_LOADED":
            continue

        # Parse: "  NODE|Name|Type|pos=Vector2(x, y)|size=Vector2(x, y)"
        stripped = line.lstrip()
        depth = (len(line) - len(stripped)) // 2

        parts = stripped.split("|")
        if len(parts) < 3 or parts[0] != "NODE":
            continue

        node_info: dict[str, Any] = {
            "name": parts[1],
            "type": parts[2],
            "depth": depth,
        }

        # Parse extra properties
        for part in parts[3:]:
            if "=" in part:
                key, val = part.split("=", 1)
                node_info[key] = val

        nodes.append(node_info)

    return nodes


def _has_control_properties(raw_properties: str) -> bool:
    """Check if raw properties indicate a Control-derived node."""
    if not raw_properties:
        return False
    control_props = [
        "anchor_left", "anchor_top", "anchor_right", "anchor_bottom",
        "offset_left", "offset_top", "offset_right", "offset_bottom",
        "size_flags_horizontal", "size_flags_vertical",
        "layout_mode",
    ]
    for prop in control_props:
        if prop in raw_properties:
            return True
    return False


def _extract_layout_properties(raw_properties: str) -> dict[str, str]:
    """Extract layout-relevant properties from raw property text."""
    result: dict[str, str] = {}
    if not raw_properties:
        return result

    layout_keys = [
        "anchor_left", "anchor_top", "anchor_right", "anchor_bottom",
        "offset_left", "offset_top", "offset_right", "offset_bottom",
        "position", "size", "custom_minimum_size",
        "size_flags_horizontal", "size_flags_vertical",
        "layout_mode", "anchors_preset",
        "grow_horizontal", "grow_vertical",
    ]

    for line in raw_properties.splitlines():
        line = line.strip()
        if "=" in line:
            key, _, val = line.partition("=")
            key = key.strip()
            val = val.strip()
            if key in layout_keys:
                result[key] = val

    return result
