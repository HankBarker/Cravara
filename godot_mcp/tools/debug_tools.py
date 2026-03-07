"""Debug tools: scan for errors, run scenes, collect logs."""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).parent.parent))

from config import ProjectConfig
from utils import make_response


def register_debug_tools(mcp: Any, config: ProjectConfig) -> None:
    @mcp.tool()
    def scan_project_for_errors() -> dict:
        """Scan the Godot project for common errors and broken references.

        Detects:
        - Missing scripts referenced in .tscn scene files
        - Missing resources (textures, packed scenes) referenced in scenes
        - Missing files referenced by preload()/load() in GDScript
        - Invalid res:// paths
        - Missing autoload files referenced in project.godot

        Returns:
            Dict with success, errors (list of error dicts), error_count, summary.
        """
        errors = []

        # 1. Scan .tscn files for broken ext_resource references
        for tscn_file in config.game_root.rglob("*.tscn"):
            if "addons" in tscn_file.parts:
                continue
            try:
                content = tscn_file.read_text(encoding="utf-8")
            except Exception:
                continue

            # Find all ext_resource path references
            for match in re.finditer(r'path="(res://[^"]+)"', content):
                res_path = match.group(1)
                abs_path = config.abs_path(res_path)
                if not abs_path.exists():
                    rel_tscn = tscn_file.relative_to(config.game_root)
                    errors.append({
                        "type": "missing_resource",
                        "file": str(rel_tscn),
                        "reference": res_path,
                        "description": f"Resource not found: {res_path}",
                    })

        # 2. Scan .gd files for broken preload/load references
        for gd_file in config.game_root.rglob("*.gd"):
            if "addons" in gd_file.parts:
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
                        rel_gd = gd_file.relative_to(config.game_root)
                        errors.append({
                            "type": "missing_preload",
                            "file": str(rel_gd),
                            "line": i,
                            "reference": res_path,
                            "description": f"preload/load target not found: {res_path}",
                        })

        # 3. Check autoloads in project.godot
        autoloads = config.get_autoloads()
        for name, path_str in autoloads.items():
            # Remove the leading * for autoloads
            clean_path = path_str.lstrip("*")
            abs_path = config.abs_path(clean_path)
            if not abs_path.exists():
                errors.append({
                    "type": "missing_autoload",
                    "file": "project.godot",
                    "reference": clean_path,
                    "description": f"Autoload '{name}' file not found: {clean_path}",
                })

        return make_response(
            True,
            [],
            f"Scan complete: found {len(errors)} issue(s)" if errors else "Scan complete: no issues found",
            errors=errors,
            error_count=len(errors),
        )

    @mcp.tool()
    def run_godot_scene(
        scene_path: str,
        timeout_seconds: int = 10,
    ) -> dict:
        """Run a Godot scene via the command line for quick testing.

        Requires the Godot executable to be available in PATH.
        The scene runs headless and is killed after the timeout.

        Args:
            scene_path: Path to the scene (res:// or relative to game root).
            timeout_seconds: How long to let the scene run before killing (default 10).

        Returns:
            Dict with success, stdout, stderr, summary.
        """
        if scene_path.startswith("res://"):
            abs_scene = config.abs_path(scene_path)
        else:
            abs_scene = config.game_root / scene_path

        if not abs_scene.exists():
            return make_response(False, [], f"Scene not found: {scene_path}")

        # Try common Godot executable names
        godot_cmd = None
        for cmd in ["godot", "godot4", "Godot_v4.4-stable_linux.x86_64"]:
            try:
                subprocess.run([cmd, "--version"], capture_output=True, timeout=5)
                godot_cmd = cmd
                break
            except (FileNotFoundError, subprocess.TimeoutExpired):
                continue

        if godot_cmd is None:
            return make_response(
                False,
                [],
                "Godot executable not found in PATH. Install Godot 4 or add it to PATH.",
                command=f'godot --path "{config.game_root}" --headless "{abs_scene}"',
            )

        try:
            result = subprocess.run(
                [godot_cmd, "--path", str(config.game_root), "--headless", str(abs_scene)],
                capture_output=True,
                text=True,
                timeout=timeout_seconds,
            )
            return make_response(
                result.returncode == 0,
                [],
                f"Scene exited with code {result.returncode}",
                stdout=result.stdout,
                stderr=result.stderr,
            )
        except subprocess.TimeoutExpired as e:
            return make_response(
                True,
                [],
                f"Scene ran for {timeout_seconds}s and was stopped (this is normal for game scenes)",
                stdout=e.stdout.decode() if e.stdout else "",
                stderr=e.stderr.decode() if e.stderr else "",
            )

    @mcp.tool()
    def collect_runtime_logs() -> dict:
        """Read Godot runtime logs from the standard log location.

        Checks common Godot log directories for the Cravara project.

        Returns:
            Dict with success, logs (string content), log_path, summary.
        """
        # Common log locations
        home = Path.home()
        log_dirs = [
            home / ".local/share/godot/app_userdata/Cravara/logs",
            home / ".config/godot/app_userdata/Cravara/logs",
            home / "AppData/Roaming/Godot/app_userdata/Cravara/logs",
        ]

        for log_dir in log_dirs:
            if log_dir.exists():
                log_files = sorted(log_dir.glob("*.log"), key=lambda f: f.stat().st_mtime, reverse=True)
                if log_files:
                    latest = log_files[0]
                    content = latest.read_text(encoding="utf-8", errors="replace")
                    # Return last 200 lines to keep response manageable
                    lines = content.splitlines()
                    if len(lines) > 200:
                        content = "\n".join(lines[-200:])
                        content = f"... (showing last 200 of {len(lines)} lines)\n" + content
                    return make_response(
                        True,
                        [],
                        f"Found log file: {latest.name} ({len(lines)} lines)",
                        logs=content,
                        log_path=str(latest),
                    )

        return make_response(
            False,
            [],
            "No Godot log files found. Run the game at least once to generate logs.",
            searched_paths=[str(d) for d in log_dirs],
        )

    @mcp.tool()
    def list_project_structure() -> dict:
        """List the full directory tree of the Godot game project.

        Excludes the addons/ directory and .import files for cleaner output.

        Returns:
            Dict with success, structure (formatted tree string), summary.
        """
        tree_lines = []
        game_root = config.game_root

        for root, dirs, files in os.walk(game_root):
            # Skip addons and hidden directories
            dirs[:] = [d for d in dirs if d not in ("addons", ".godot", ".import") and not d.startswith(".")]
            root_path = Path(root)
            level = len(root_path.relative_to(game_root).parts)
            indent = "  " * level
            dir_name = root_path.name if level > 0 else "game/"
            tree_lines.append(f"{indent}{dir_name}/")
            for f in sorted(files):
                if f.endswith(".import") or f.startswith("."):
                    continue
                tree_lines.append(f"{indent}  {f}")

        structure = "\n".join(tree_lines)
        return make_response(
            True,
            [],
            f"Project structure: {len(tree_lines)} entries",
            structure=structure,
        )
