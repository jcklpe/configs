#!/usr/bin/env python3
"""Render bounded Microsoft Graph mail, calendar, contact, and Planner snapshots, and single mail messages."""

import argparse
from pathlib import Path
import runpy
import html
import json
import re
import sys
from html.parser import HTMLParser


_mail = runpy.run_path(str(Path(__file__).resolve().parents[2] / "agent-hands/skills/use-outlook-mail/scripts/render.py"))
render_mail, render_message = _mail["render_mail"], _mail["render_message"]

_calendar = runpy.run_path(str(Path(__file__).resolve().parents[2] / "agent-hands/skills/use-outlook-calendar/scripts/render.py"))
render_calendar = _calendar["render_calendar"]


from pathlib import Path
import runpy
_contacts = runpy.run_path(str(Path(__file__).resolve().parents[2] / "agent-hands/skills/use-outlook-contacts/scripts/render.py"))
render_contacts = _contacts["render_contacts"]


_planner = runpy.run_path(str(Path(__file__).resolve().parents[2] / "agent-hands/skills/use-planner/scripts/render.py"))
render_planner = _planner["render_planner"]


def main(argv):
    parser = argparse.ArgumentParser(prog="m365-render.py")
    subparsers = parser.add_subparsers(dest="command", required=True)
    for name in ("mail", "calendar", "contacts"):
        command = subparsers.add_parser(name)
        command.add_argument("--alias", required=True)
        command.add_argument("--email", required=True)
        command.add_argument("--refreshed", required=True)
        command.add_argument("--input", required=True)
    mail = subparsers.choices["mail"]
    mail.add_argument("--days", required=True, type=int)
    mail.add_argument("--max-results", required=True, type=int)
    mail.add_argument("--body-limit", required=True, type=int)
    calendar = subparsers.choices["calendar"]
    calendar.add_argument("--start", required=True)
    calendar.add_argument("--end", required=True)
    calendar.add_argument("--timezone", required=True)
    calendar.add_argument("--description-limit", required=True, type=int)
    contacts = subparsers.choices["contacts"]
    contacts.add_argument("--max-results", required=True, type=int)
    contacts.add_argument("--notes-limit", required=True, type=int)
    message = subparsers.add_parser("message")
    message.add_argument("--input", required=True)
    message.add_argument("--body-limit", required=True, type=int, help="0 prints the whole body")
    planner = subparsers.add_parser("planner")
    planner.add_argument("--alias", required=True)
    planner.add_argument("--email", required=True)
    planner.add_argument("--me", default="")
    planner.add_argument("--refreshed", required=True)
    planner.add_argument("--input", required=True)
    planner.add_argument("--description-limit", required=True, type=int)
    args = parser.parse_args(argv)
    with open(args.input, "r", encoding="utf-8") as handle:
        data = json.load(handle)
    if args.command == "mail":
        output = render_mail(args, data)
    elif args.command == "calendar":
        output = render_calendar(args, data)
    elif args.command == "message":
        output = render_message(args, data)
    elif args.command == "planner":
        output = render_planner(args, data)
    else:
        output = render_contacts(args, data)
    print(output, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
