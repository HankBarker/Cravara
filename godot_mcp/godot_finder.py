"""Discover the Godot 4 executable on the system.

Searches common Windows install locations and caches the result.
If not found, provides instructions for the user to configure the path.
"""

from __future__ import annotations

import glob
import json
import os
import subprocess
from pathlib import Path

# Module-level cache
_cached_godot_path: str | None = None
_cache_checked: bool = False

# Config file for user-specified path
_CONFIG_FILE = Path(__file__).parent / "godot_config.json"


def find_godot_executable(config_path: Path | None = None) -> str | None:
    """Search for a Godot 4 executable on Windows.

    Search order:
    1. User-specified path from godot_config.json
    2. PATH (common command names)
    3. Program Files directories
    4. Steam installation
    5. Scoop package manager
    6. Common user directories (Downloads, Desktop)

    Returns:
        Absolute path to the Godot executable, or None if not found.
    """
    global _cached_godot_path, _cache_checked

    if _cache_checked:
        return _cached_godot_path

    config_file = config_path or _CONFIG_FILE

    # 1. Check user-specified config
    if config_file.exists():
        try:
            data = json.loads(config_file.read_text(encoding="utf-8"))
            user_path = data.get("godot_path", "")
            if user_path and _verify_godot(user_path):
                _cached_godot_path = user_path
                _cache_checked = True
                return _cached_godot_path
        except (json.JSONDecodeError, OSError):
            pass

    # 2. Check PATH with common command names
    path_candidates = [
        "godot",
        "godot4",
        "godot.exe",
        "godot4.exe",
    ]
    for cmd in path_candidates:
        if _verify_godot(cmd):
            _cached_godot_path = cmd
            _cache_checked = True
            return _cached_godot_path

    # 3. Search filesystem locations
    search_dirs: list[str] = []

    # Program Files
    for pf in [
        os.environ.get("ProgramFiles", r"C:\Program Files"),
        os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)"),
    ]:
        if pf:
            search_dirs.append(os.path.join(pf, "Godot"))
            search_dirs.append(pf)

    # Steam
    steam_paths = [
        r"C:\Program Files (x86)\Steam\steamapps\common",
        r"C:\Program Files\Steam\steamapps\common",
    ]
    for sp in steam_paths:
        if os.path.isdir(sp):
            # Look for any Godot-related directory
            for entry in os.listdir(sp):
                if "godot" in entry.lower():
                    search_dirs.append(os.path.join(sp, entry))

    # Scoop
    home = Path.home()
    scoop_dir = home / "scoop" / "apps" / "godot" / "current"
    if scoop_dir.exists():
        search_dirs.append(str(scoop_dir))

    # User directories (portable installs)
    for user_dir in [home / "Downloads", home / "Desktop", home / "Documents"]:
        if user_dir.exists():
            search_dirs.append(str(user_dir))

    # Glob for Godot executables in each search directory
    exe_patterns = [
        "Godot_v4*.exe",
        "Godot_v4*_console.exe",
        "godot.exe",
        "godot4.exe",
        "Godot.exe",
    ]

    for search_dir in search_dirs:
        if not os.path.isdir(search_dir):
            continue
        for pattern in exe_patterns:
            matches = glob.glob(os.path.join(search_dir, pattern))
            # Prefer console executables for headless/CLI use
            matches.sort(key=lambda p: ("console" not in p.lower(), p))
            for match in matches:
                if _verify_godot(match):
                    _cached_godot_path = match
                    _cache_checked = True
                    return _cached_godot_path

    _cache_checked = True
    return None


def get_godot_version(godot_path: str) -> str | None:
    """Run the Godot executable with --version and return the version string.

    Args:
        godot_path: Path to the Godot executable.

    Returns:
        Version string (e.g., "4.6.stable") or None if it fails.
    """
    try:
        result = subprocess.run(
            [godot_path, "--version"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError):
        pass
    return None


def get_not_found_message() -> str:
    """Return a helpful message when Godot is not found."""
    return (
        "Godot executable not found. To fix this, either:\n"
        "1. Add Godot to your system PATH, or\n"
        f'2. Create {_CONFIG_FILE} with: {{"godot_path": "C:/path/to/godot.exe"}}\n'
        "The Godot executable is typically named Godot_v4.x-stable_win64.exe or similar."
    )


def clear_cache() -> None:
    """Clear the cached Godot path (useful for testing or after config changes)."""
    global _cached_godot_path, _cache_checked
    _cached_godot_path = None
    _cache_checked = False


def _verify_godot(path: str) -> bool:
    """Verify that a path points to a working Godot 4 executable."""
    try:
        result = subprocess.run(
            [path, "--version"],
            capture_output=True,
            text=True,
            timeout=10,
        )
        version = result.stdout.strip()
        # Check it's Godot 4.x
        return result.returncode == 0 and version.startswith("4")
    except (FileNotFoundError, subprocess.TimeoutExpired, OSError, PermissionError):
        return False
