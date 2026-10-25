#!/usr/bin/env python3
"""Compatibility dispatch to the service-specific payload builders."""
from pathlib import Path
import runpy
import sys
_root = Path(__file__).resolve().parents[2] / "agent-hands/skills"
if __name__ == "__main__":
    service = {"event": "use-outlook-calendar", "contact": "use-outlook-contacts"}.get(sys.argv[1] if len(sys.argv) > 1 else "")
    if not service:
        raise SystemExit("Expected event or contact")
    runpy.run_path(str(_root / service / "scripts/write.py"), run_name="__main__")
else:
    for service in ("use-outlook-calendar", "use-outlook-contacts"):
        globals().update({k: v for k, v in runpy.run_path(str(_root / service / "scripts/write.py")).items() if not k.startswith("_") and k != "main"})
