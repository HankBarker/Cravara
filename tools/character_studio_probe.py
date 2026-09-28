"""Read-only MCP handshake and operation checks; never prints credentials."""
import asyncio
import json
import os
from pathlib import Path
import tomllib

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

ROOT = Path(__file__).resolve().parents[1]

async def probe(name, cfg):
    try:
        params = StdioServerParameters(command=cfg['command'], args=cfg.get('args', []),
                                       env={**os.environ, **cfg.get('env', {})})
        async with asyncio.timeout(50):
            async with stdio_client(params) as (read, write):
                async with ClientSession(read, write) as session:
                    info = await session.initialize()
                    listed = await session.list_tools()
                    names = [t.name for t in listed.tools]
                    result = {'server': info.serverInfo.name, 'tools': len(names)}
                    tool = 'scan_project_for_errors' if name == 'godot_mcp' else 'get_sprite_info'
                    args = {} if name == 'godot_mcp' else {'filename': str(ROOT / 'art/character-studio/connection-check.aseprite')}
                    if tool in names:
                        response = await session.call_tool(tool, args)
                        result['operation'] = tool
                        result['response'] = response.model_dump(mode='json')
                    result['status'] = 'connected'
                    return name, result
    except Exception as exc:
        return name, {'status': 'failed', 'error_type': type(exc).__name__, 'message': str(exc)[:300]}

async def main():
    config = tomllib.loads((ROOT / '.codex/config.toml').read_text())['mcp_servers']
    results = dict(await asyncio.gather(*(probe(n, config[n]) for n in ('godot_mcp', 'aseprite'))))
    path = ROOT / 'art/character-studio/connections.json'
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(results, indent=2), encoding='utf-8')
    print(json.dumps(results, indent=2))

if __name__ == '__main__':
    asyncio.run(main())
