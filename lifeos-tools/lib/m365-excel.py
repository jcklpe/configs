#!/usr/bin/env python3
"""Compatibility route to the portable workbook implementation."""
from pathlib import Path
import runpy
_target = Path(__file__).resolve().parents[2] / "agent-hands/skills/use-excel-workbooks/scripts/excel.py"
if __name__ == "__main__":
    runpy.run_path(str(_target), run_name="__main__")
else:
    globals().update(runpy.run_path(str(_target)))
