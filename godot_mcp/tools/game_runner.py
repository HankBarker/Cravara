"""Game execution tools: run project/scenes, stop, collect logs."""

from __future__ import annotations

import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).parent.parent))

from config import ProjectConfig
from godot_finder import find_godot_executable, get_not_found_message
from utils import make_response

# Module-level state persists across tool calls within a session
_running_process: subprocess.Popen | None = None
_log_buffer: list[str] = []
_pid_file = Path(tempfile.gettempdir()) / "godot_mcp_pid.txt"


def register_game_runner_tools(mcp: Any, config: ProjectConfig) -> None:
    @mcp.tool()
    def run_project(headless: bool = False, timeout_seconds: int = 0) -> dict:
        """Run the project's main scene using the Godot executable.

        Launches Godot with `--path <game_root>` which uses the main_scene
        configured in project.godot. The process runs in the background.

        Args:
            headless: If True, run with --headless flag (no window, for log capture).
            timeout_seconds: If >0, kill after this many seconds and return output.
                If 0, run indefinitely (use stop_project to stop).

        Returns:
            Dict with success, pid, stdout, stderr, summary.
        """
        global _running_process, _log_buffer

        godot_path = find_godot_executable()
        if godot_path is None:
            return make_response(False, [], get_not_found_message())

        # Stop any existing process first
        _stop_current_process()
        _log_buffer.clear()

        cmd = [godot_path, "--path", str(config.game_root)]
        if headless:
            cmd.append("--headless")

        try:
            if timeout_seconds > 0:
                # Run with timeout, capture output
                result = subprocess.run(
                    cmd,
                    capture_output=True,
                    text=True,
                    timeout=timeout_seconds,
                )
                _log_buffer.extend(result.stdout.splitlines())
                _log_buffer.extend(result.stderr.splitlines())
                return make_response(
                    result.returncode == 0,
                    [],
                    f"Project exited with code {result.returncode}",
                    stdout=result.stdout,
                    stderr=result.stderr,
                    pid=None,
                )
            else:
                # Run in background
                proc = subprocess.Popen(
                    cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                )
                _running_process = proc
                _save_pid(proc.pid)
                return make_response(
                    True,
                    [],
                    f"Project running (PID {proc.pid})"
                    + (" [headless]" if headless else "")
                    + ". Use stop_project() to stop.",
                    pid=proc.pid,
                )
        except subprocess.TimeoutExpired as e:
            stdout = e.stdout.decode() if e.stdout else ""
            stderr = e.stderr.decode() if e.stderr else ""
            _log_buffer.extend(stdout.splitlines())
            _log_buffer.extend(stderr.splitlines())
            return make_response(
                True,
                [],
                f"Project ran for {timeout_seconds}s and was stopped (normal for game scenes)",
                stdout=stdout,
                stderr=stderr,
                pid=None,
            )
        except OSError as e:
            return make_response(False, [], f"Failed to launch Godot: {e}")

    @mcp.tool()
    def run_scene(
        scene_path: str,
        headless: bool = True,
        timeout_seconds: int = 10,
    ) -> dict:
        """Run a specific Godot scene for testing.

        Args:
            scene_path: Path to the scene (res:// path or relative to game root).
            headless: If True, run with --headless flag (default True for testing).
            timeout_seconds: Kill after this many seconds (default 10).

        Returns:
            Dict with success, stdout, stderr, summary.
        """
        global _log_buffer

        godot_path = find_godot_executable()
        if godot_path is None:
            return make_response(False, [], get_not_found_message())

        if scene_path.startswith("res://"):
            abs_scene = config.abs_path(scene_path)
        else:
            abs_scene = config.game_root / scene_path

        if not abs_scene.exists():
            return make_response(False, [], f"Scene not found: {scene_path}")

        cmd = [godot_path, "--path", str(config.game_root)]
        if headless:
            cmd.append("--headless")
        cmd.append(str(abs_scene))

        _log_buffer.clear()

        try:
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=timeout_seconds,
            )
            _log_buffer.extend(result.stdout.splitlines())
            _log_buffer.extend(result.stderr.splitlines())
            return make_response(
                result.returncode == 0,
                [],
                f"Scene exited with code {result.returncode}",
                stdout=result.stdout,
                stderr=result.stderr,
            )
        except subprocess.TimeoutExpired as e:
            stdout = e.stdout.decode() if e.stdout else ""
            stderr = e.stderr.decode() if e.stderr else ""
            _log_buffer.extend(stdout.splitlines())
            _log_buffer.extend(stderr.splitlines())
            return make_response(
                True,
                [],
                f"Scene ran for {timeout_seconds}s and was stopped (normal for game scenes)",
                stdout=stdout,
                stderr=stderr,
            )
        except OSError as e:
            return make_response(False, [], f"Failed to launch Godot: {e}")

    @mcp.tool()
    def stop_project() -> dict:
        """Stop the currently running Godot process.

        Sends SIGTERM first, then SIGKILL if it doesn't stop within 5 seconds.
        Also reads any buffered output before stopping.

        Returns:
            Dict with success, stdout, stderr, summary.
        """
        global _running_process

        if _running_process is None:
            # Try to find and kill orphaned process from PID file
            pid = _load_pid()
            if pid is not None:
                try:
                    os.kill(pid, 9)
                    _clear_pid()
                    return make_response(True, [], f"Killed orphaned Godot process (PID {pid})")
                except (ProcessLookupError, PermissionError):
                    _clear_pid()
                    return make_response(False, [], "No running Godot process found")
            return make_response(False, [], "No running Godot process found")

        stdout_text = ""
        stderr_text = ""

        try:
            _running_process.terminate()
            try:
                stdout_bytes, stderr_bytes = _running_process.communicate(timeout=5)
                stdout_text = stdout_bytes.decode() if stdout_bytes else ""
                stderr_text = stderr_bytes.decode() if stderr_bytes else ""
            except subprocess.TimeoutExpired:
                _running_process.kill()
                stdout_bytes, stderr_bytes = _running_process.communicate(timeout=3)
                stdout_text = stdout_bytes.decode() if stdout_bytes else ""
                stderr_text = stderr_bytes.decode() if stderr_bytes else ""

            _log_buffer.extend(stdout_text.splitlines())
            _log_buffer.extend(stderr_text.splitlines())

            pid = _running_process.pid
            _running_process = None
            _clear_pid()

            return make_response(
                True,
                [],
                f"Stopped Godot process (PID {pid})",
                stdout=stdout_text,
                stderr=stderr_text,
            )
        except Exception as e:
            _running_process = None
            _clear_pid()
            return make_response(False, [], f"Error stopping process: {e}")

    @mcp.tool()
    def get_debug_log(
        filter_level: str = "all",
        last_n_lines: int = 100,
    ) -> dict:
        """Get debug logs from the last Godot run.

        Reads from both Godot's log files and the in-memory buffer
        captured during the last run_project/run_scene call.

        Args:
            filter_level: Filter by log level:
                'all' - All log lines (default)
                'errors' - Only ERROR and SCRIPT ERROR lines
                'warnings' - Only WARNING lines
                'info' - Only non-error, non-warning lines
            last_n_lines: Number of lines to return from the end (default 100).

        Returns:
            Dict with success, logs (string), line_count, source, summary.
        """
        all_lines: list[str] = []
        source = "none"

        # Try Godot log files first
        log_file_lines = _read_godot_log_file()
        if log_file_lines:
            all_lines.extend(log_file_lines)
            source = "log_file"

        # Add in-memory buffer
        if _log_buffer:
            all_lines.extend(_log_buffer)
            source = "buffer" if source == "none" else "log_file+buffer"

        if not all_lines:
            return make_response(
                False,
                [],
                "No logs available. Run the game first with run_project() or run_scene().",
            )

        # Apply filter
        if filter_level == "errors":
            all_lines = [l for l in all_lines if _is_error_line(l)]
        elif filter_level == "warnings":
            all_lines = [l for l in all_lines if _is_warning_line(l)]
        elif filter_level == "info":
            all_lines = [l for l in all_lines if not _is_error_line(l) and not _is_warning_line(l)]

        # Trim to last N lines
        total = len(all_lines)
        if total > last_n_lines:
            all_lines = all_lines[-last_n_lines:]

        logs = "\n".join(all_lines)
        return make_response(
            True,
            [],
            f"Logs: {len(all_lines)} lines (of {total} total), source: {source}, filter: {filter_level}",
            logs=logs,
            line_count=len(all_lines),
            total_lines=total,
            source=source,
        )

    @mcp.tool()
    def get_errors() -> dict:
        """Get only ERROR and SCRIPT ERROR lines from the latest logs.

        Convenience wrapper around get_debug_log with filter_level='errors'.

        Returns:
            Dict with success, logs, line_count, summary.
        """
        return get_debug_log(filter_level="errors", last_n_lines=200)

    @mcp.tool()
    def clear_debug_log() -> dict:
        """Clear the in-memory log buffer.

        Does not delete Godot's log files on disk.

        Returns:
            Dict with success, summary.
        """
        global _log_buffer
        count = len(_log_buffer)
        _log_buffer.clear()
        return make_response(True, [], f"Cleared {count} buffered log lines")


# --- Internal helpers ---

def _stop_current_process() -> None:
    """Stop any currently running Godot process."""
    global _running_process
    if _running_process is not None:
        try:
            _running_process.terminate()
            _running_process.wait(timeout=3)
        except (subprocess.TimeoutExpired, OSError):
            try:
                _running_process.kill()
            except OSError:
                pass
        _running_process = None
        _clear_pid()


def _read_godot_log_file() -> list[str]:
    """Read the latest Godot log file."""
    home = Path.home()
    log_dirs = [
        home / "AppData/Roaming/Godot/app_userdata/Cravara/logs",
        home / ".local/share/godot/app_userdata/Cravara/logs",
        home / ".config/godot/app_userdata/Cravara/logs",
    ]

    for log_dir in log_dirs:
        if log_dir.exists():
            log_files = sorted(
                log_dir.glob("*.log"),
                key=lambda f: f.stat().st_mtime,
                reverse=True,
            )
            if log_files:
                try:
                    content = log_files[0].read_text(encoding="utf-8", errors="replace")
                    return content.splitlines()
                except OSError:
                    continue
    return []


def _is_error_line(line: str) -> bool:
    """Check if a log line is an error."""
    upper = line.upper()
    return any(
        marker in upper
        for marker in ["ERROR", "SCRIPT ERROR", "FATAL", "EXCEPTION"]
    )


def _is_warning_line(line: str) -> bool:
    """Check if a log line is a warning."""
    return "WARNING" in line.upper()


def _save_pid(pid: int) -> None:
    """Save PID to temp file for orphan cleanup."""
    try:
        _pid_file.write_text(str(pid), encoding="utf-8")
    except OSError:
        pass


def _load_pid() -> int | None:
    """Load PID from temp file."""
    try:
        if _pid_file.exists():
            return int(_pid_file.read_text(encoding="utf-8").strip())
    except (OSError, ValueError):
        pass
    return None


def _clear_pid() -> None:
    """Remove the PID file."""
    try:
        if _pid_file.exists():
            _pid_file.unlink()
    except OSError:
        pass
