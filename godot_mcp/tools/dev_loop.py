"""Development loop tools: orchestrate validate -> run -> log -> report cycles."""

from __future__ import annotations

import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).parent.parent))

from config import ProjectConfig
from utils import make_response

# Module-level state persists across tool calls within a session
_last_validation: dict | None = None
_last_run: dict | None = None
_cycle_history: list[dict] = []


def register_dev_loop_tools(mcp: Any, config: ProjectConfig) -> None:
    @mcp.tool()
    def dev_loop_status() -> dict:
        """Get the current development loop status.

        Returns a summary of the last validation, last run, outstanding
        errors, and basic project statistics.

        Returns:
            Dict with success, validation, run, project_stats, summary.
        """
        # Gather project stats
        stats = _gather_project_stats(config)

        validation_summary = "No validation run yet"
        if _last_validation:
            ts = _last_validation.get("timestamp", "unknown")
            errs = _last_validation.get("error_count", 0)
            warns = _last_validation.get("warning_count", 0)
            validation_summary = f"Last validation at {ts}: {errs} errors, {warns} warnings"

        run_summary = "No game run yet"
        if _last_run:
            ts = _last_run.get("timestamp", "unknown")
            success = _last_run.get("success", False)
            run_summary = f"Last run at {ts}: {'OK' if success else 'FAILED'}"

        return make_response(
            True,
            [],
            f"Dev status: {validation_summary}; {run_summary}",
            validation=_last_validation,
            run=_last_run,
            project_stats=stats,
            cycle_count=len(_cycle_history),
        )

    @mcp.tool()
    def run_dev_cycle(
        checks: list[str] | None = None,
        run_main: bool = True,
        timeout_seconds: int = 10,
    ) -> dict:
        """Run a full development cycle: validate -> run -> collect logs -> report.

        This is the main orchestration tool that:
        1. Validates the project (scripts, scenes, resources)
        2. Optionally runs the main scene
        3. Collects and filters logs
        4. Returns a unified report

        Args:
            checks: Specific validation checks to run (None = all).
                Options: resources, collision_shapes, textures, signals,
                         inputs, orphaned_scripts, script_syntax
            run_main: If True, also run the main scene after validation.
            timeout_seconds: How long to run the game (default 10).

        Returns:
            Dict with success, validation_result, run_result, report, summary.
        """
        global _last_validation, _last_run

        cycle_start = time.time()
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        report_parts: list[str] = []

        # --- Step 1: Validate ---
        report_parts.append("=== VALIDATION ===")
        validation_result = _run_validation(config, checks)
        _last_validation = {
            "timestamp": timestamp,
            "error_count": validation_result.get("error_count", 0),
            "warning_count": validation_result.get("warning_count", 0),
            "checks_run": validation_result.get("checks_run", []),
        }

        v_errors = validation_result.get("error_count", 0)
        v_warnings = validation_result.get("warning_count", 0)
        report_parts.append(f"Errors: {v_errors}, Warnings: {v_warnings}")

        if v_errors > 0:
            report_parts.append("Error details:")
            for err in validation_result.get("errors", [])[:10]:
                report_parts.append(f"  - [{err.get('check', '?')}] {err.get('message', '?')}")
            if v_errors > 10:
                report_parts.append(f"  ... and {v_errors - 10} more")

        # --- Step 2: Run (optional) ---
        run_result = None
        if run_main:
            report_parts.append("")
            report_parts.append("=== GAME RUN ===")
            run_result = _run_game(config, timeout_seconds)
            _last_run = {
                "timestamp": timestamp,
                "success": run_result.get("success", False),
                "had_errors": bool(run_result.get("error_lines")),
            }

            if run_result.get("success"):
                report_parts.append(f"Game ran for {timeout_seconds}s - OK")
            else:
                report_parts.append(f"Game run FAILED: {run_result.get('summary', 'unknown')}")

            # Report runtime errors
            error_lines = run_result.get("error_lines", [])
            if error_lines:
                report_parts.append(f"Runtime errors ({len(error_lines)}):")
                for line in error_lines[:10]:
                    report_parts.append(f"  - {line}")
                if len(error_lines) > 10:
                    report_parts.append(f"  ... and {len(error_lines) - 10} more")

        # --- Build final report ---
        cycle_time = time.time() - cycle_start
        report_parts.append("")
        report_parts.append(f"=== CYCLE COMPLETE ({cycle_time:.1f}s) ===")

        overall_ok = v_errors == 0 and (run_result is None or run_result.get("success", False))
        if overall_ok:
            report_parts.append("Status: ALL CLEAR")
        else:
            issues = []
            if v_errors > 0:
                issues.append(f"{v_errors} validation error(s)")
            if run_result and not run_result.get("success"):
                issues.append("game run failed")
            if run_result and run_result.get("error_lines"):
                issues.append(f"{len(run_result['error_lines'])} runtime error(s)")
            report_parts.append(f"Status: ISSUES FOUND - {', '.join(issues)}")

        report = "\n".join(report_parts)

        # Store in history
        cycle_entry = {
            "timestamp": timestamp,
            "duration": cycle_time,
            "validation_errors": v_errors,
            "validation_warnings": v_warnings,
            "ran_game": run_main,
            "game_success": run_result.get("success") if run_result else None,
            "overall_ok": overall_ok,
        }
        _cycle_history.append(cycle_entry)

        return make_response(
            overall_ok,
            [],
            f"Dev cycle: {v_errors} error(s), {v_warnings} warning(s)"
            + (f", game {'OK' if run_result and run_result.get('success') else 'FAILED'}" if run_main else "")
            + f" ({cycle_time:.1f}s)",
            validation_result=validation_result,
            run_result=run_result,
            report=report,
            cycle_time=cycle_time,
        )


# --- Internal helpers ---


def _gather_project_stats(config: ProjectConfig) -> dict[str, Any]:
    """Gather basic project statistics."""
    game_root = config.game_root
    stats: dict[str, Any] = {"game_root": str(game_root)}

    try:
        gd_files = list(game_root.rglob("*.gd"))
        tscn_files = list(game_root.rglob("*.tscn"))
        tres_files = list(game_root.rglob("*.tres"))
        png_files = list(game_root.rglob("*.png"))

        stats["script_count"] = len(gd_files)
        stats["scene_count"] = len(tscn_files)
        stats["resource_count"] = len(tres_files)
        stats["texture_count"] = len(png_files)

        # Check project.godot exists
        stats["has_project_godot"] = (game_root / "project.godot").exists()
    except OSError:
        pass

    return stats


def _run_validation(config: ProjectConfig, checks: list[str] | None) -> dict[str, Any]:
    """Run project validation using the validator module.

    Imports and calls validate_project dynamically to avoid circular imports.
    """
    try:
        from tools.validator import register_validator_tools
    except ImportError:
        pass

    # Direct validation logic (avoids needing the MCP registration)
    all_errors: list[dict] = []
    all_warnings: list[dict] = []
    checks_run: list[str] = []

    available_checks = {
        "resources": _check_resources,
        "collision_shapes": _check_collision_shapes,
        "script_syntax": _check_script_syntax,
    }

    selected = checks if checks else list(available_checks.keys())

    for check_name in selected:
        if check_name in available_checks:
            checks_run.append(check_name)
            try:
                errs, warns = available_checks[check_name](config)
                all_errors.extend(errs)
                all_warnings.extend(warns)
            except Exception as e:
                all_warnings.append({
                    "check": check_name,
                    "message": f"Check failed: {e}",
                })

    return {
        "error_count": len(all_errors),
        "warning_count": len(all_warnings),
        "errors": all_errors,
        "warnings": all_warnings,
        "checks_run": checks_run,
    }


def _run_game(config: ProjectConfig, timeout_seconds: int) -> dict[str, Any]:
    """Run the game and collect results."""
    import subprocess
    from godot_finder import find_godot_executable, get_not_found_message

    godot_path = find_godot_executable()
    if godot_path is None:
        return {"success": False, "summary": get_not_found_message(), "error_lines": []}

    cmd = [godot_path, "--path", str(config.game_root), "--headless"]

    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout_seconds,
        )
        stdout = result.stdout
        stderr = result.stderr
        success = result.returncode == 0
    except subprocess.TimeoutExpired as e:
        stdout = e.stdout.decode() if e.stdout else ""
        stderr = e.stderr.decode() if e.stderr else ""
        success = True  # Timeout is normal for game scenes
    except OSError as e:
        return {"success": False, "summary": f"Failed to launch: {e}", "error_lines": []}

    # Filter error lines
    all_output = (stdout + "\n" + stderr).splitlines()
    error_lines = [
        line for line in all_output
        if any(m in line.upper() for m in ["ERROR", "SCRIPT ERROR", "FATAL", "EXCEPTION"])
    ]

    return {
        "success": success and len(error_lines) == 0,
        "summary": f"Ran for {timeout_seconds}s, {len(error_lines)} error(s) in output",
        "error_lines": error_lines,
        "stdout": stdout[-3000:] if len(stdout) > 3000 else stdout,
        "stderr": stderr[-3000:] if len(stderr) > 3000 else stderr,
    }


# --- Simplified validation checks for dev loop ---
# These are lightweight versions that don't depend on the full validator module


def _check_resources(config: ProjectConfig) -> tuple[list[dict], list[dict]]:
    """Check for missing resource references in scene files."""
    errors: list[dict] = []
    warnings: list[dict] = []

    for tscn in config.game_root.rglob("*.tscn"):
        try:
            content = tscn.read_text(encoding="utf-8")
        except OSError:
            continue

        # Check ext_resource paths
        import re
        for match in re.finditer(r'path="(res://[^"]+)"', content):
            res_path = match.group(1)
            abs_path = config.abs_path(res_path)
            if not abs_path.exists():
                errors.append({
                    "check": "resources",
                    "file": str(tscn.relative_to(config.game_root)),
                    "message": f"Missing resource: {res_path}",
                })

    return errors, warnings


def _check_collision_shapes(config: ProjectConfig) -> tuple[list[dict], list[dict]]:
    """Check for physics bodies without collision shapes."""
    errors: list[dict] = []
    warnings: list[dict] = []

    body_types = {"CharacterBody2D", "RigidBody2D", "StaticBody2D", "Area2D"}

    for tscn in config.game_root.rglob("*.tscn"):
        try:
            from tscn_parser import parse_file
            scene = parse_file(str(tscn))
        except Exception:
            continue

        for node in scene.nodes:
            if node.type in body_types:
                # Check if any child is a collision shape
                node_path = node.name if node.parent is None else (
                    node.name if node.parent == "." else f"{node.parent}/{node.name}"
                )
                has_shape = any(
                    n.type in ("CollisionShape2D", "CollisionPolygon2D")
                    and (n.parent == "." and node.parent is None
                         or n.parent == node_path
                         or n.parent == node.name)
                    for n in scene.nodes
                )
                if not has_shape:
                    warnings.append({
                        "check": "collision_shapes",
                        "file": str(tscn.relative_to(config.game_root)),
                        "message": f"{node.type} '{node.name}' has no CollisionShape2D child",
                    })

    return errors, warnings


def _check_script_syntax(config: ProjectConfig) -> tuple[list[dict], list[dict]]:
    """Basic script syntax checks."""
    errors: list[dict] = []
    warnings: list[dict] = []

    for gd_file in config.game_root.rglob("*.gd"):
        try:
            content = gd_file.read_text(encoding="utf-8")
        except OSError:
            continue

        rel = str(gd_file.relative_to(config.game_root))
        lines = content.splitlines()

        # Check for unmatched braces/brackets across the file
        open_count = sum(l.count("{") - l.count("}") for l in lines)
        if open_count != 0:
            warnings.append({
                "check": "script_syntax",
                "file": rel,
                "message": f"Unmatched braces (open count: {open_count})",
            })

    return errors, warnings
