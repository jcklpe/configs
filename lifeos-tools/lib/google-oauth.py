#!/usr/bin/env python3
"""Compatibility import/entrypoint for the extracted Google implementation."""
import runpy
from pathlib import Path

_target = Path(__file__).resolve().parents[2] / "agent-hands/skills/authorize-google/scripts/oauth.py"
if __name__ == "__main__":
    runpy.run_path(str(_target), run_name="__main__")
else:
    globals().update(runpy.run_path(str(_target)))
