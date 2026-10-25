#!/usr/bin/env python3
"""Compatibility runner for the extracted offline Slack checks."""
from pathlib import Path
import subprocess
import sys

skills = Path(__file__).resolve().parents[2] / "agent-hands" / "skills"
for domain in ("lists", "messages"):
    result = subprocess.run([sys.executable, str(skills / f"use-slack-{domain}" / "tests" / "test_operations.py")])
    if result.returncode:
        raise SystemExit(result.returncode)
