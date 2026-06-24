#!/usr/bin/env python3
"""Build a Google Calendar event body (JSON) for lifeos.sh writes.

Pure transformation: no network. lifeos.sh resolves attendee emails and the
target time zone, then calls this to assemble a validated event body that the
shell POSTs (create) or PATCHes (update). Only fields that are supplied are
emitted, so the same builder produces a full create body or a partial patch.

A start/end given as YYYY-MM-DD becomes an all-day event; anything containing a
"T" becomes a timed event in the supplied --tz. Missing ends default to +1 day
(all-day, exclusive) or +1 hour (timed).
"""

import argparse
import json
import re
import sys
from datetime import datetime, timedelta

DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def fail(message):
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def is_all_day(value):
    return bool(DATE_RE.match(value))


def parse_datetime(value):
    text = value.strip().replace("Z", "")
    for fmt in ("%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%M"):
        try:
            return datetime.strptime(text, fmt)
        except ValueError:
            continue
    fail(f"Could not parse datetime: {value!r} (use YYYY-MM-DDTHH:MM)")


def parse_date(value):
    try:
        return datetime.strptime(value.strip(), "%Y-%m-%d")
    except ValueError:
        fail(f"Could not parse date: {value!r} (use YYYY-MM-DD)")


def build_times(start, end, tz):
    if start is None:
        if end is not None:
            fail("--end requires --start")
        return None, None

    if is_all_day(start):
        if end is not None and not is_all_day(end):
            fail("all-day --start needs an all-day (YYYY-MM-DD) --end")
        start_obj = {"date": start}
        if end is None:
            end_date = parse_date(start) + timedelta(days=1)
            end_obj = {"date": end_date.strftime("%Y-%m-%d")}
        else:
            end_obj = {"date": end}
        return start_obj, end_obj

    if not tz:
        fail("timed events require --tz")
    if end is not None and is_all_day(end):
        fail("timed --start needs a timed (YYYY-MM-DDTHH:MM) --end")
    start_dt = parse_datetime(start)
    start_obj = {"dateTime": start_dt.isoformat(timespec="seconds"), "timeZone": tz}
    if end is None:
        end_dt = start_dt + timedelta(hours=1)
    else:
        end_dt = parse_datetime(end)
    if end_dt <= start_dt:
        fail("event end must be after start")
    end_obj = {"dateTime": end_dt.isoformat(timespec="seconds"), "timeZone": tz}
    return start_obj, end_obj


def main(argv):
    parser = argparse.ArgumentParser(prog="google-calendar-write.py build-event")
    parser.add_argument("--title")
    parser.add_argument("--start")
    parser.add_argument("--end")
    parser.add_argument("--tz")
    parser.add_argument("--location")
    parser.add_argument("--description")
    parser.add_argument("--attendee", action="append", default=[], dest="attendees")
    parser.add_argument(
        "--recurrence",
        action="append",
        default=[],
        help="RRULE/RDATE/EXDATE line, e.g. RRULE:FREQ=WEEKLY;BYDAY=MO. Repeatable.",
    )
    args = parser.parse_args(argv)

    body = {}
    if args.title is not None:
        body["summary"] = args.title
    if args.location is not None:
        body["location"] = args.location
    if args.description is not None:
        body["description"] = args.description
    if args.recurrence:
        body["recurrence"] = args.recurrence

    start_obj, end_obj = build_times(args.start, args.end, args.tz)
    if start_obj is not None:
        body["start"] = start_obj
        body["end"] = end_obj

    if args.attendees:
        body["attendees"] = [{"email": email} for email in args.attendees]

    if not body:
        fail("nothing to build: supply at least --title or --start")

    print(json.dumps(body))
    return 0


if __name__ == "__main__":
    argv = sys.argv[1:]
    if argv and argv[0] == "build-event":
        argv = argv[1:]
    raise SystemExit(main(argv))
