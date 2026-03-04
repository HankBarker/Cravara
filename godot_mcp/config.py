"""Project path resolution and constants for the Godot MCP server."""

import os
from pathlib import Path


DEFAULT_GAME_ROOT = Path(__file__).parent.parent / "game"


class ProjectConfig:
    def __init__(self, game_root: str | None = None):
        self.game_root = Path(game_root) if game_root else DEFAULT_GAME_ROOT
        self.game_root = self.game_root.resolve()

    def abs_path(self, res_path: str) -> Path:
        """Convert 'res://path/to/file' to absolute filesystem path."""
        relative = res_path.replace("res://", "")
        return self.game_root / relative

    def res_path(self, abs_path: str | Path) -> str:
        """Convert absolute path to 'res://...' path."""
        rel = Path(abs_path).resolve().relative_to(self.game_root)
        return f"res://{rel.as_posix()}"

    def ensure_dir(self, path: Path) -> None:
        """Create directory and parents if they don't exist."""
        path.mkdir(parents=True, exist_ok=True)

    def detect_creature_dir(self, name: str) -> Path:
        """Determine save directory for a creature (follows Sprites/<Name>/ pattern)."""
        creatures_dir = self.game_root / "Creatures"
        if creatures_dir.exists():
            return creatures_dir / name
        return self.game_root / "Sprites" / name

    def detect_scene_dir(self) -> Path:
        """Determine save directory for general scenes."""
        scenes_dir = self.game_root / "Scenes"
        return scenes_dir

    def detect_data_dir(self) -> Path:
        """Determine save directory for JSON data files."""
        return self.game_root / "Data"

    def get_autoloads(self) -> dict[str, str]:
        """Parse project.godot to find current autoloads."""
        project_file = self.game_root / "project.godot"
        if not project_file.exists():
            return {}
        autoloads = {}
        in_autoload = False
        for line in project_file.read_text().splitlines():
            if line.strip() == "[autoload]":
                in_autoload = True
                continue
            if in_autoload:
                if line.startswith("["):
                    break
                if "=" in line and not line.startswith(";"):
                    key, val = line.split("=", 1)
                    autoloads[key.strip()] = val.strip().strip('"')
        return autoloads
