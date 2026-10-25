#!/usr/bin/env python3
"""Compatibility route to the shared Google Sheets response formatter."""
import runpy
import sys
from pathlib import Path

_target = Path(__file__).resolve().parents[2] / "agent-hands/skills/authorize-google/scripts/sheets_render.py"
if __name__ == "__main__":
    raise SystemExit(runpy.run_path(str(_target))["main"](sys.argv))
else:
    globals().update(runpy.run_path(str(_target)))
