#!/usr/bin/env python3
"""Compatibility route to the provider-neutral agenda normalizer."""
import runpy
from pathlib import Path
_target = Path(__file__).resolve().parents[2] / "agent-hands/skills/render-calendar-agenda/scripts/microsoft.py"
if __name__ == "__main__":
    runpy.run_path(str(_target), run_name="__main__")
else:
    globals().update(runpy.run_path(str(_target)))
