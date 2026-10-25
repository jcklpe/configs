#!/usr/bin/env python3
"""Compatibility route to shared Microsoft authorization."""
from pathlib import Path
import runpy
_target = Path(__file__).resolve().parents[2] / "agent-hands/skills/authorize-microsoft/scripts/auth.py"
if __name__ == "__main__":
    runpy.run_path(str(_target), run_name="__main__")
else:
    globals().update(runpy.run_path(str(_target)))
