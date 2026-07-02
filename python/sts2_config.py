"""Configuration helpers shared by the sts2-cli Python entry points."""

from __future__ import annotations

import json
import os
import shlex
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG_PATH = ROOT / "config.json"


def load_config(path: str | os.PathLike[str] | None = None) -> dict[str, Any]:
    """Load config.json, returning an empty configuration when it is absent."""
    config_path = Path(path or os.environ.get("STS2_CLI_CONFIG", DEFAULT_CONFIG_PATH))
    if not config_path.is_file():
        return {}
    try:
        with config_path.open(encoding="utf-8-sig") as stream:
            data = json.load(stream)
    except (OSError, json.JSONDecodeError) as exc:
        raise RuntimeError(f"Cannot read configuration {config_path}: {exc}") from exc
    if not isinstance(data, dict):
        raise RuntimeError(f"Configuration {config_path} must contain a JSON object")
    return data


def configured_game_dir(config: dict[str, Any] | None = None) -> str | None:
    """Resolve the game directory; the environment wins over config.json."""
    value = os.environ.get("STS2_GAME_DIR")
    if not value:
        value = (config or load_config()).get("game_path")
    if not isinstance(value, str) or not value.strip():
        return None
    return os.path.abspath(os.path.expandvars(os.path.expanduser(value.strip())))


def configured_launch_args(config: dict[str, Any] | None = None) -> list[str]:
    """Return command-line arguments prepended to play.py invocations."""
    value = (config or load_config()).get("launch_args", [])
    if value is None:
        return []
    if isinstance(value, str):
        return shlex.split(value)
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise RuntimeError(
            "Configuration field 'launch_args' must be a string or an array of strings"
        )

    # Accept both token arrays and convenient command fragments such as
    # ["--lang zh", "--character Silent"]. Quoting preserves values with spaces.
    result: list[str] = []
    for item in value:
        result.extend(shlex.split(item))
    return result
