#!/usr/bin/env python3
"""Compatibility renderer; domain implementations live in Agent Hands."""
import runpy
from pathlib import Path
import sys

skills = Path(__file__).resolve().parents[2] / "agent-hands/skills"
kind = sys.argv[1] if len(sys.argv) > 1 else ""
if kind in ("issue-index", "item-detail"):
    path = skills / "authorize-github/scripts/render_items.py"
elif kind in ("discussions", "discussion-detail"):
    path = skills / "use-github-discussions/scripts/render.py"
elif kind == "board":
    path = skills / "use-github-projects/scripts/render.py"
else:
    raise SystemExit("Expected issue-index, item-detail, discussions, discussion-detail, or board")
sys.path.insert(0, str(path.parent))
runpy.run_path(str(path), run_name="__main__")
