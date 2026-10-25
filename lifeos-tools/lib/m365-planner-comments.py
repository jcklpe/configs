#!/usr/bin/env python3
"""Compatibility entry for task-scoped group comments."""
from pathlib import Path
import runpy
runpy.run_path(str(Path(__file__).resolve().parents[2] / "agent-hands/skills/use-planner/scripts/comments.py"), run_name="__main__")
