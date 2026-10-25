#!/usr/bin/env python3
"""Legacy Calendar OAuth/date-window adapter; no credential migration."""
import runpy
import sys
from pathlib import Path

_scripts = Path(__file__).resolve().parents[2] / "agent-hands/skills"
_oauth = runpy.run_path(str(_scripts / "authorize-google/scripts/oauth.py"))
_window = runpy.run_path(str(_scripts / "use-google-calendar/scripts/window.py"))
SCOPES = ["https://www.googleapis.com/auth/" + name for name in ("calendar.calendarlist.readonly", "calendar.events", "contacts.readonly", "contacts.other.readonly")]


def main(argv):
    try:
        if len(argv) == 4 and argv[1] == "date-window":
            return _window["date_window"](*argv[2:])
        if len(argv) >= 4 and argv[1] == "auth":
            return _oauth["auth"](argv[2], argv[3], SCOPES, no_browser="--no-browser" in argv[4:])
        if len(argv) == 4 and argv[1] == "access-token":
            return _oauth["access_token"](*argv[2:])
        raise ValueError("Expected auth CREDENTIALS TOKEN [--no-browser], access-token CREDENTIALS TOKEN, or date-window DAYS_BACK DAYS_AHEAD")
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
