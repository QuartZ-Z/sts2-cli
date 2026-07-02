"""Tests for CLI play helpers."""

from __future__ import annotations

import importlib.util
import pathlib
import sys
import json


ROOT = pathlib.Path(__file__).resolve().parents[1]
PLAY_PATH = ROOT / "scripts" / "play.py"

sys.path.insert(0, str(ROOT / "scripts"))
spec = importlib.util.spec_from_file_location("play_module_for_tests", PLAY_PATH)
play = importlib.util.module_from_spec(spec)
assert spec and spec.loader
spec.loader.exec_module(play)


def test_quit_save_defaults_to_save_dir(monkeypatch):
    monkeypatch.setattr("builtins.input", lambda prompt="": "y")

    path = play._quit_with_save(None, "Ironclad", "seed123")

    assert path is not None
    assert path.startswith(play.SAVE_DIR)
    assert path.endswith(".save")


def test_resolve_input_path_explains_sav_typo(tmp_path, capsys):
    actual = tmp_path / "run.save"
    actual.write_text("{}", encoding="utf-8")

    result = play._resolve_input_path(str(tmp_path / "run.sav"), "Native save")

    assert result is None
    output = capsys.readouterr().out
    assert str(actual) in output
    assert ".save extension, not .sav" in output


def test_configured_game_dir_is_preferred(tmp_path, monkeypatch):
    game_dir = tmp_path / "Slay the Spire 2"
    game_dir.mkdir()
    monkeypatch.delenv("STS2_GAME_DIR", raising=False)

    assert play._find_game_dir({"game_path": str(game_dir)}) == str(game_dir)


def test_load_config_from_environment(tmp_path, monkeypatch):
    config_path = tmp_path / "custom.json"
    config_path.write_text(json.dumps({"game_path": "X:/STS2"}), encoding="utf-8")
    monkeypatch.setenv("STS2_CLI_CONFIG", str(config_path))

    assert play.load_config()["game_path"] == "X:/STS2"


def test_configured_launch_args_are_copied():
    config = {"launch_args": ["--lang", "en", "--no-log"]}

    result = play.configured_launch_args(config)
    result.append("--auto")

    assert config["launch_args"] == ["--lang", "en", "--no-log"]


def test_configured_launch_args_accept_command_line_string():
    config = {
        "launch_args": "--lang zh --character Silent --ascension 10",
    }

    assert play.configured_launch_args(config) == [
        "--lang", "zh", "--character", "Silent", "--ascension", "10",
    ]


def test_configured_launch_args_accept_argument_fragments():
    config = {
        "launch_args": ["--lang zh", "--character Silent", "--ascension 10"],
    }

    assert play.configured_launch_args(config) == [
        "--lang", "zh", "--character", "Silent", "--ascension", "10",
    ]
