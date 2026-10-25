#!/usr/bin/env python3
"""Compatibility route to the portable Calendar implementation."""
import runpy
from pathlib import Path
import os
os.environ["GOOGLE_CALENDAR_NO_DESCRIPTION"] = os.environ.get("LIFEOS_CALENDAR_NO_DESCRIPTION", "")
_target = Path(__file__).resolve().parents[2] / "agent-hands/skills/use-google-calendar/scripts/render.py"
if __name__ == "__main__":
    runpy.run_path(str(_target), run_name="__main__")
else:
    globals().update(runpy.run_path(str(_target)))
