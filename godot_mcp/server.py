"""Godot MCP Server - enables Claude Code to programmatically create and modify
Godot 4 game project files for the Cravara project.

Run with: python server.py
Or with FastMCP dev tools: mcp dev server.py
"""

from __future__ import annotations

import sys
from pathlib import Path

# Ensure the package directory is on the path
sys.path.insert(0, str(Path(__file__).parent))

from fastmcp import FastMCP

from config import ProjectConfig
from tools.creature_generator import register_creature_tools
from tools.data_manager import register_data_tools
from tools.debug_tools import register_debug_tools
from tools.scene_builder import register_scene_tools
from tools.script_manager import register_script_tools
from tools.system_generator import register_system_tools
from tools.world_generator import register_world_tools

# Initialize the MCP server
mcp = FastMCP(name="godot_mcp")

# Initialize shared project config
config = ProjectConfig()

# Register all tool groups
register_scene_tools(mcp, config)
register_script_tools(mcp, config)
register_data_tools(mcp, config)
register_world_tools(mcp, config)
register_creature_tools(mcp, config)
register_system_tools(mcp, config)
register_debug_tools(mcp, config)


def main():
    """Run the MCP server with stdio transport."""
    mcp.run()


if __name__ == "__main__":
    main()
