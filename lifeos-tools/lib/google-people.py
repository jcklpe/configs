#!/usr/bin/env python3
"""Compatibility import/entrypoint; private aliases and attendee policy remain in the caller."""
import os
import runpy
import sys
from pathlib import Path

_target = Path(__file__).resolve().parents[2] / "agent-hands/skills/use-google-contacts/scripts/contacts.py"
if __name__ == "__main__":
    if len(sys.argv) == 4 and sys.argv[1] == "resolve":
        os.environ["GOOGLE_ACCESS_TOKEN"] = sys.argv[2]
        sys.argv = [sys.argv[0], "resolve", sys.argv[3]]
    runpy.run_path(str(_target), run_name="__main__")
else:
    globals().update(runpy.run_path(str(_target)))
