"""Safe code-modification tools: read, edit, and validate GDScript files."""

from __future__ import annotations

import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).parent.parent))

from config import ProjectConfig
from godot_finder import find_godot_executable
from utils import make_response


def register_code_editor_tools(mcp: Any, config: ProjectConfig) -> None:
    @mcp.tool()
    def read_script(
        script_path: str,
        start_line: int = 0,
        end_line: int = 0,
    ) -> dict:
        """Read a GDScript file with optional line range.

        Args:
            script_path: Path to the script (res:// or relative to game root).
            start_line: First line to return (1-based). 0 = from beginning.
            end_line: Last line to return (1-based). 0 = to end of file.

        Returns:
            Dict with success, content, line_count, summary.
        """
        abs_path = _resolve_script_path(config, script_path)
        if not abs_path.exists():
            return make_response(False, [], f"Script not found: {script_path}")

        try:
            content = abs_path.read_text(encoding="utf-8")
        except OSError as e:
            return make_response(False, [], f"Failed to read script: {e}")

        lines = content.splitlines()
        total = len(lines)

        if start_line > 0 or end_line > 0:
            s = max(start_line - 1, 0)
            e = end_line if end_line > 0 else total
            selected = lines[s:e]
            # Number lines for easy reference
            numbered = []
            for i, line in enumerate(selected, start=s + 1):
                numbered.append(f"{i:4d} | {line}")
            content = "\n".join(numbered)
            return make_response(
                True,
                [],
                f"Lines {s+1}-{min(e, total)} of {total} in {abs_path.name}",
                content=content,
                line_count=len(selected),
                total_lines=total,
            )

        # Full file with line numbers
        numbered = []
        for i, line in enumerate(lines, start=1):
            numbered.append(f"{i:4d} | {line}")
        content = "\n".join(numbered)
        return make_response(
            True,
            [],
            f"{abs_path.name}: {total} lines",
            content=content,
            line_count=total,
            total_lines=total,
        )

    @mcp.tool()
    def edit_script(
        script_path: str,
        edits: list[dict[str, Any]],
        create_backup: bool = True,
    ) -> dict:
        """Apply targeted edits to a GDScript file.

        Each edit is a dict with a 'type' key and type-specific fields:

        - replace_lines: Replace a range of lines.
            {type: "replace_lines", start: int, end: int, content: str}
            start/end are 1-based line numbers (inclusive).

        - insert_after: Insert lines after a given line number.
            {type: "insert_after", line: int, content: str}

        - insert_before: Insert lines before a given line number.
            {type: "insert_before", line: int, content: str}

        - delete_lines: Delete a range of lines.
            {type: "delete_lines", start: int, end: int}

        - find_replace: Find and replace text.
            {type: "find_replace", find: str, replace: str, count: int}
            count: max replacements (0 = all). Default 1.

        Edits are applied in order. Line numbers refer to the original file
        for the first edit and to the state after each preceding edit for
        subsequent edits.

        Args:
            script_path: Path to the script (res:// or relative).
            edits: List of edit operation dicts.
            create_backup: If True, create a .bak file before editing.

        Returns:
            Dict with success, files_modified, diff_preview, summary.
        """
        abs_path = _resolve_script_path(config, script_path)
        if not abs_path.exists():
            return make_response(False, [], f"Script not found: {script_path}")

        try:
            original = abs_path.read_text(encoding="utf-8")
        except OSError as e:
            return make_response(False, [], f"Failed to read script: {e}")

        if create_backup:
            bak_path = abs_path.with_suffix(abs_path.suffix + ".bak")
            try:
                shutil.copy2(abs_path, bak_path)
            except OSError as e:
                return make_response(False, [], f"Failed to create backup: {e}")

        lines = original.splitlines()
        edit_count = 0
        errors: list[str] = []

        for i, edit in enumerate(edits):
            edit_type = edit.get("type", "")
            try:
                if edit_type == "replace_lines":
                    s = edit["start"] - 1
                    e = edit["end"]
                    new_lines = edit["content"].splitlines()
                    lines[s:e] = new_lines
                    edit_count += 1

                elif edit_type == "insert_after":
                    idx = edit["line"]
                    new_lines = edit["content"].splitlines()
                    for j, nl in enumerate(new_lines):
                        lines.insert(idx + j, nl)
                    edit_count += 1

                elif edit_type == "insert_before":
                    idx = edit["line"] - 1
                    new_lines = edit["content"].splitlines()
                    for j, nl in enumerate(new_lines):
                        lines.insert(idx + j, nl)
                    edit_count += 1

                elif edit_type == "delete_lines":
                    s = edit["start"] - 1
                    e = edit["end"]
                    del lines[s:e]
                    edit_count += 1

                elif edit_type == "find_replace":
                    find_text = edit["find"]
                    replace_text = edit["replace"]
                    count = edit.get("count", 1)
                    joined = "\n".join(lines)
                    if count == 0:
                        joined = joined.replace(find_text, replace_text)
                    else:
                        joined = joined.replace(find_text, replace_text, count)
                    lines = joined.splitlines()
                    edit_count += 1

                else:
                    errors.append(f"Edit {i+1}: unknown type '{edit_type}'")

            except (KeyError, IndexError, TypeError) as e:
                errors.append(f"Edit {i+1} ({edit_type}): {e}")

        if errors:
            return make_response(
                False,
                [],
                f"Edit errors: {'; '.join(errors)}",
                errors=errors,
            )

        new_content = "\n".join(lines)
        # Ensure trailing newline
        if original.endswith("\n") and not new_content.endswith("\n"):
            new_content += "\n"

        # Generate simple diff preview
        diff_preview = _simple_diff(original, new_content)

        try:
            abs_path.write_text(new_content, encoding="utf-8")
        except OSError as e:
            return make_response(False, [], f"Failed to write script: {e}")

        files = [str(abs_path)]
        if create_backup:
            files.append(str(abs_path.with_suffix(abs_path.suffix + ".bak")))

        return make_response(
            True,
            files,
            f"Applied {edit_count} edit(s) to {abs_path.name}",
            diff_preview=diff_preview,
            edits_applied=edit_count,
        )

    @mcp.tool()
    def validate_gdscript(script_path: str) -> dict:
        """Validate a GDScript file for syntax issues.

        Tries Godot CLI --check-only first. Falls back to regex-based
        checks if Godot is not available.

        Args:
            script_path: Path to the script (res:// or relative).

        Returns:
            Dict with success, errors, warnings, summary.
        """
        abs_path = _resolve_script_path(config, script_path)
        if not abs_path.exists():
            return make_response(False, [], f"Script not found: {script_path}")

        try:
            content = abs_path.read_text(encoding="utf-8")
        except OSError as e:
            return make_response(False, [], f"Failed to read script: {e}")

        errors: list[dict] = []
        warnings: list[dict] = []

        # Try Godot CLI validation first
        godot_path = find_godot_executable()
        if godot_path:
            cli_errors = _validate_with_godot_cli(godot_path, config, abs_path)
            if cli_errors is not None:
                for err in cli_errors:
                    errors.append(err)
                if not errors:
                    return make_response(
                        True,
                        [],
                        f"No errors found in {abs_path.name} (Godot CLI check)",
                        errors=[],
                        warnings=[],
                        method="godot_cli",
                    )
                return make_response(
                    False,
                    [],
                    f"{len(errors)} error(s) in {abs_path.name}",
                    errors=errors,
                    warnings=[],
                    method="godot_cli",
                )

        # Fallback: regex-based checks
        _regex_check_script(content, abs_path.name, errors, warnings)

        if errors:
            return make_response(
                False,
                [],
                f"{len(errors)} error(s), {len(warnings)} warning(s) in {abs_path.name}",
                errors=errors,
                warnings=warnings,
                method="regex",
            )

        return make_response(
            True,
            [],
            f"No errors found in {abs_path.name} ({len(warnings)} warning(s))",
            errors=[],
            warnings=warnings,
            method="regex",
        )


# --- Internal helpers ---


def _resolve_script_path(config: ProjectConfig, script_path: str) -> Path:
    """Resolve a script path to absolute."""
    if script_path.startswith("res://"):
        return config.abs_path(script_path)
    p = Path(script_path)
    if p.is_absolute():
        return p
    return config.game_root / script_path


def _simple_diff(old: str, new: str) -> str:
    """Generate a simple diff preview showing changed lines."""
    old_lines = old.splitlines()
    new_lines = new.splitlines()

    preview_parts: list[str] = []
    max_lines = max(len(old_lines), len(new_lines))

    changes = 0
    for i in range(max_lines):
        old_line = old_lines[i] if i < len(old_lines) else None
        new_line = new_lines[i] if i < len(new_lines) else None

        if old_line != new_line:
            changes += 1
            if changes > 20:
                preview_parts.append(f"... and more changes (total diff too large)")
                break
            if old_line is not None:
                preview_parts.append(f"-{i+1:4d} | {old_line}")
            if new_line is not None:
                preview_parts.append(f"+{i+1:4d} | {new_line}")

    if not preview_parts:
        return "(no changes)"

    return "\n".join(preview_parts)


def _validate_with_godot_cli(
    godot_path: str, config: ProjectConfig, script_path: Path
) -> list[dict] | None:
    """Try to validate a script using Godot CLI --check-only.

    Returns list of error dicts, or None if CLI validation not available.
    """
    try:
        result = subprocess.run(
            [godot_path, "--path", str(config.game_root), "--check-only", "--headless"],
            capture_output=True,
            text=True,
            timeout=30,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None

    errors: list[dict] = []
    script_name = script_path.name

    for line in (result.stdout + result.stderr).splitlines():
        if script_name in line and ("error" in line.lower() or "Error" in line):
            # Try to extract line number
            line_match = re.search(r":(\d+)", line)
            errors.append({
                "file": script_name,
                "line": int(line_match.group(1)) if line_match else 0,
                "message": line.strip(),
            })

    return errors


def _regex_check_script(
    content: str,
    filename: str,
    errors: list[dict],
    warnings: list[dict],
) -> None:
    """Perform regex-based syntax checks on GDScript content."""
    lines = content.splitlines()

    indent_stack: list[int] = [0]
    in_multiline_string = False

    for i, line in enumerate(lines, start=1):
        stripped = line.strip()

        # Skip empty lines and comments
        if not stripped or stripped.startswith("#"):
            continue

        # Track multiline strings
        triple_quote_count = line.count('"""')
        if triple_quote_count % 2 == 1:
            in_multiline_string = not in_multiline_string
            continue
        if in_multiline_string:
            continue

        # Check for common syntax issues

        # Unmatched parentheses on single line (simple check)
        open_parens = stripped.count("(") - stripped.count(")")
        if open_parens < 0:
            warnings.append({
                "file": filename,
                "line": i,
                "message": "Possible unmatched closing parenthesis",
            })

        # Assignment in condition (common mistake)
        if re.match(r"\s*if\s+\w+\s*=[^=]", line) and "==" not in line:
            warnings.append({
                "file": filename,
                "line": i,
                "message": "Possible assignment in condition (use == for comparison)",
            })

        # Duplicate function definitions
        func_match = re.match(r"\s*func\s+(\w+)\s*\(", line)
        if func_match:
            func_name = func_match.group(1)
            # Check if this function was already defined
            for j, other_line in enumerate(lines[:i-1], start=1):
                if re.match(rf"\s*func\s+{re.escape(func_name)}\s*\(", other_line):
                    errors.append({
                        "file": filename,
                        "line": i,
                        "message": f"Duplicate function definition: {func_name} (first at line {j})",
                    })
                    break

        # Missing colon after control structures
        for keyword in ["if", "elif", "else", "for", "while", "match"]:
            pattern = rf"^\s*{keyword}\b.*[^:]$"
            if re.match(pattern, line):
                # Exclude multi-line conditions (ending with \)
                if not stripped.endswith("\\") and not stripped.endswith(","):
                    # "else" needs special handling
                    if keyword == "else" and stripped == "else":
                        warnings.append({
                            "file": filename,
                            "line": i,
                            "message": f"Missing colon after '{keyword}'",
                        })
