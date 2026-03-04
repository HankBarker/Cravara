"""Engine for reading, writing, and modifying Godot .tscn scene files.

Supports Godot 4 format (format=3). Handles:
- ext_resource entries (scripts, textures, packed scenes)
- sub_resource entries (collision shapes, sprite frames, etc.)
- Node hierarchy with parent paths
- Signal connections
- Multi-line property values (e.g., SpriteFrames animations arrays)
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any

from utils import (
    format_tscn_value,
    generate_ext_resource_id,
    generate_scene_uid,
    generate_sub_resource_id,
)


@dataclass
class ExtResource:
    type: str
    path: str
    id: str
    uid: str = ""


@dataclass
class SubResource:
    type: str
    id: str
    raw_properties: str = ""


@dataclass
class SceneNode:
    name: str
    type: str = ""
    parent: str | None = None
    instance: str = ""
    raw_properties: str = ""


@dataclass
class Connection:
    signal: str
    from_node: str
    to_node: str
    method: str


@dataclass
class TscnScene:
    """Represents a parsed .tscn file."""

    uid: str = ""
    ext_resources: list[ExtResource] = field(default_factory=list)
    sub_resources: list[SubResource] = field(default_factory=list)
    nodes: list[SceneNode] = field(default_factory=list)
    connections: list[Connection] = field(default_factory=list)

    @property
    def load_steps(self) -> int:
        return len(self.ext_resources) + len(self.sub_resources) + 1

    def used_ids(self) -> set[str]:
        """Return all IDs currently in use."""
        ids = set()
        for r in self.ext_resources:
            ids.add(r.id)
        for r in self.sub_resources:
            ids.add(r.id)
        return ids

    def _unique_ext_id(self, counter: int) -> str:
        used = self.used_ids()
        for _ in range(100):
            rid = generate_ext_resource_id(counter)
            if rid not in used:
                return rid
        return generate_ext_resource_id(counter)

    def _unique_sub_id(self, type_name: str) -> str:
        used = self.used_ids()
        for _ in range(100):
            rid = generate_sub_resource_id(type_name)
            if rid not in used:
                return rid
        return generate_sub_resource_id(type_name)

    def add_ext_resource(self, res_type: str, path: str, uid: str = "") -> str:
        """Add an external resource. Returns the ID for referencing."""
        counter = len(self.ext_resources) + 1
        rid = self._unique_ext_id(counter)
        self.ext_resources.append(ExtResource(type=res_type, path=path, id=rid, uid=uid))
        return rid

    def add_sub_resource(self, res_type: str, properties: dict[str, Any] | None = None) -> str:
        """Add a sub-resource. Returns the ID for referencing."""
        rid = self._unique_sub_id(res_type)
        raw = ""
        if properties:
            lines = []
            for k, v in properties.items():
                lines.append(f"{k} = {format_tscn_value(v)}")
            raw = "\n".join(lines)
        self.sub_resources.append(SubResource(type=res_type, id=rid, raw_properties=raw))
        return rid

    def add_node(
        self,
        name: str,
        node_type: str,
        parent: str | None = None,
        properties: dict[str, Any] | None = None,
        instance: str = "",
    ) -> None:
        """Add a node to the scene tree."""
        raw = ""
        if properties:
            lines = []
            for k, v in properties.items():
                lines.append(f"{k} = {format_tscn_value(v)}")
            raw = "\n".join(lines)
        self.nodes.append(
            SceneNode(name=name, type=node_type, parent=parent, instance=instance, raw_properties=raw)
        )

    def add_connection(self, signal: str, from_node: str, to_node: str, method: str) -> None:
        """Add a signal connection."""
        self.connections.append(Connection(signal=signal, from_node=from_node, to_node=to_node, method=method))

    def find_node(self, name: str) -> SceneNode | None:
        """Find a node by name."""
        for node in self.nodes:
            if node.name == name:
                return node
        return None


def serialize(scene: TscnScene) -> str:
    """Serialize a TscnScene to valid .tscn text."""
    lines: list[str] = []

    # Header
    uid_part = f' uid="{scene.uid}"' if scene.uid else ""
    lines.append(f"[gd_scene load_steps={scene.load_steps} format=3{uid_part}]")
    lines.append("")

    # External resources
    for ext in scene.ext_resources:
        uid_part = f' uid="{ext.uid}"' if ext.uid else ""
        lines.append(f'[ext_resource type="{ext.type}"{uid_part} path="{ext.path}" id="{ext.id}"]')
    if scene.ext_resources:
        lines.append("")

    # Sub-resources
    for sub in scene.sub_resources:
        lines.append(f'[sub_resource type="{sub.type}" id="{sub.id}"]')
        if sub.raw_properties:
            lines.append(sub.raw_properties)
        lines.append("")

    # Nodes
    for node in scene.nodes:
        parts = [f'name="{node.name}"']
        if node.type:
            parts.append(f'type="{node.type}"')
        if node.parent is not None:
            parts.append(f'parent="{node.parent}"')
        if node.instance:
            parts.append(f"instance={node.instance}")
        lines.append(f'[node {" ".join(parts)}]')
        if node.raw_properties:
            lines.append(node.raw_properties)
        lines.append("")

    # Connections
    for conn in scene.connections:
        lines.append(
            f'[connection signal="{conn.signal}" from="{conn.from_node}" '
            f'to="{conn.to_node}" method="{conn.method}"]'
        )
    if scene.connections:
        lines.append("")

    return "\n".join(lines)


def parse(content: str) -> TscnScene:
    """Parse .tscn file content into a TscnScene object.

    Uses an insertion-friendly approach: preserves raw property text for
    existing entries so that round-tripping doesn't corrupt multi-line values
    like SpriteFrames animations.
    """
    scene = TscnScene()

    # Extract UID from header
    header_match = re.search(r'uid="(uid://[^"]+)"', content)
    if header_match:
        scene.uid = header_match.group(1)

    # Split content into section blocks. Each block starts with '['
    # We need to handle multi-line property values carefully.
    blocks = _split_into_blocks(content)

    for block_header, block_body in blocks:
        if block_header.startswith("[ext_resource"):
            _parse_ext_resource(block_header, scene)
        elif block_header.startswith("[sub_resource"):
            _parse_sub_resource(block_header, block_body, scene)
        elif block_header.startswith("[node"):
            _parse_node(block_header, block_body, scene)
        elif block_header.startswith("[connection"):
            _parse_connection(block_header, scene)

    return scene


def parse_file(filepath: str) -> TscnScene:
    """Parse a .tscn file from disk."""
    with open(filepath, "r", encoding="utf-8") as f:
        return parse(f.read())


def _split_into_blocks(content: str) -> list[tuple[str, str]]:
    """Split .tscn content into (header_line, body_text) tuples.

    Each block starts with a [...] header line. The body is everything
    after the header until the next [...] line or end of file.
    """
    blocks: list[tuple[str, str]] = []
    lines = content.split("\n")
    current_header = ""
    current_body_lines: list[str] = []

    for line in lines:
        # Check if this line is a section header (not a GDScript array or dict)
        if re.match(r"\[(gd_scene|ext_resource|sub_resource|node|connection)\b", line):
            # Save previous block
            if current_header:
                blocks.append((current_header, "\n".join(current_body_lines).strip()))
            current_header = line
            current_body_lines = []
            continue
        current_body_lines.append(line)

    # Save last block
    if current_header:
        blocks.append((current_header, "\n".join(current_body_lines).strip()))

    return blocks


def _parse_ext_resource(header: str, scene: TscnScene) -> None:
    """Parse an ext_resource header line."""
    type_match = re.search(r'type="([^"]+)"', header)
    path_match = re.search(r'path="([^"]+)"', header)
    id_match = re.search(r'id="([^"]+)"', header)
    uid_match = re.search(r'uid="([^"]+)"', header)

    if type_match and path_match and id_match:
        scene.ext_resources.append(
            ExtResource(
                type=type_match.group(1),
                path=path_match.group(1),
                id=id_match.group(1),
                uid=uid_match.group(1) if uid_match else "",
            )
        )


def _parse_sub_resource(header: str, body: str, scene: TscnScene) -> None:
    """Parse a sub_resource block."""
    type_match = re.search(r'type="([^"]+)"', header)
    id_match = re.search(r'id="([^"]+)"', header)

    if type_match and id_match:
        scene.sub_resources.append(
            SubResource(
                type=type_match.group(1),
                id=id_match.group(1),
                raw_properties=body,
            )
        )


def _parse_node(header: str, body: str, scene: TscnScene) -> None:
    """Parse a node block."""
    name_match = re.search(r'name="([^"]+)"', header)
    type_match = re.search(r'type="([^"]+)"', header)
    parent_match = re.search(r'parent="([^"]*)"', header)
    instance_match = re.search(r"instance=(ExtResource\([^)]+\))", header)

    if name_match:
        scene.nodes.append(
            SceneNode(
                name=name_match.group(1),
                type=type_match.group(1) if type_match else "",
                parent=parent_match.group(1) if parent_match else None,
                instance=instance_match.group(1) if instance_match else "",
                raw_properties=body,
            )
        )


def _parse_connection(header: str, scene: TscnScene) -> None:
    """Parse a connection line."""
    signal_match = re.search(r'signal="([^"]+)"', header)
    from_match = re.search(r'from="([^"]+)"', header)
    to_match = re.search(r'to="([^"]+)"', header)
    method_match = re.search(r'method="([^"]+)"', header)

    if signal_match and from_match and to_match and method_match:
        scene.connections.append(
            Connection(
                signal=signal_match.group(1),
                from_node=from_match.group(1),
                to_node=to_match.group(1),
                method=method_match.group(1),
            )
        )


def build_scene(
    scene_name: str,
    root_type: str,
    node_tree: list[dict[str, Any]] | None = None,
    root_properties: dict[str, Any] | None = None,
) -> TscnScene:
    """Build a new TscnScene from a specification.

    Args:
        scene_name: Name of the root node (PascalCase).
        root_type: Godot node type for root (e.g., "CharacterBody2D").
        node_tree: List of child node dicts, each with keys:
            name, type, parent ("." for root child), properties (optional),
            sub_resources (optional, list of {type, properties, assign_to}).
        root_properties: Properties for the root node.

    Returns:
        A TscnScene ready to serialize.
    """
    scene = TscnScene(uid=generate_scene_uid())

    # Add root node
    scene.add_node(scene_name, root_type, parent=None, properties=root_properties)

    # Add child nodes
    for child in node_tree or []:
        child_props = dict(child.get("properties", {}) or {})

        # Create sub-resources needed by this node
        for sub in child.get("sub_resources", []):
            sub_id = scene.add_sub_resource(sub["type"], sub.get("properties"))
            assign_to = sub.get("assign_to")
            if assign_to:
                child_props[assign_to] = f'SubResource("{sub_id}")'

        scene.add_node(
            child["name"],
            child["type"],
            parent=child.get("parent", "."),
            properties=child_props if child_props else None,
        )

        # Add connections from this child
        for conn in child.get("connections", []):
            scene.add_connection(conn["signal"], conn["from"], conn["to"], conn["method"])

    return scene
