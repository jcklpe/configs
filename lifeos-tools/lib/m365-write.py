#!/usr/bin/env python3
"""Build validated Microsoft Graph event and contact request bodies."""

import argparse
import json
import re
import sys
from datetime import datetime, timedelta

DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def fail(message):
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def parse_date(value):
    try:
        return datetime.strptime(value, "%Y-%m-%d")
    except ValueError:
        fail(f"Could not parse date: {value!r} (use YYYY-MM-DD)")


def parse_datetime(value):
    text = value.strip()
    if text.endswith("Z") or "+" in text[10:] or "-" in text[10:]:
        fail("timed events use local YYYY-MM-DDTHH:MM plus --tz, not an offset or Z suffix")
    for fmt in ("%Y-%m-%dT%H:%M:%S", "%Y-%m-%dT%H:%M"):
        try:
            return datetime.strptime(text, fmt)
        except ValueError:
            continue
    fail(f"Could not parse datetime: {value!r} (use YYYY-MM-DDTHH:MM)")


def event_times(start, end, timezone):
    if start is None:
        if end is not None:
            fail("--end requires --start")
        return {}
    if DATE_RE.match(start):
        if end is not None and not DATE_RE.match(end):
            fail("all-day --start needs an all-day YYYY-MM-DD --end")
        start_date = parse_date(start)
        end_date = parse_date(end) if end else start_date + timedelta(days=1)
        if end_date <= start_date:
            fail("event end must be after start")
        zone = timezone or "UTC"
        return {
            "isAllDay": True,
            "start": {"dateTime": start_date.strftime("%Y-%m-%dT00:00:00"), "timeZone": zone},
            "end": {"dateTime": end_date.strftime("%Y-%m-%dT00:00:00"), "timeZone": zone},
        }
    if not timezone:
        fail("timed events require --tz")
    if end is not None and DATE_RE.match(end):
        fail("timed --start needs a timed YYYY-MM-DDTHH:MM --end")
    start_time = parse_datetime(start)
    end_time = parse_datetime(end) if end else start_time + timedelta(hours=1)
    if end_time <= start_time:
        fail("event end must be after start")
    return {
        "start": {"dateTime": start_time.isoformat(timespec="seconds"), "timeZone": timezone},
        "end": {"dateTime": end_time.isoformat(timespec="seconds"), "timeZone": timezone},
    }


def build_event(args):
    body = {}
    if args.title is not None:
        body["subject"] = args.title
    if args.description is not None:
        body["body"] = {"contentType": "text", "content": args.description}
    if args.location is not None:
        body["location"] = {"displayName": args.location}
    body.update(event_times(args.start, args.end, args.timezone))
    if args.attendees:
        body["attendees"] = [
            {"emailAddress": {"address": address, "name": address}, "type": "required"}
            for address in args.attendees
        ]
    if not body:
        fail("nothing to build: supply an event field")
    return body


def build_contact(args):
    body = {}
    fields = {
        "displayName": args.display_name,
        "givenName": args.given_name,
        "surname": args.surname,
        "companyName": args.company,
        "jobTitle": args.job_title,
        "mobilePhone": args.mobile,
        "personalNotes": args.notes,
    }
    for key, value in fields.items():
        if value is not None:
            body[key] = value
    if args.emails:
        label = args.display_name or ""
        body["emailAddresses"] = [{"address": address, "name": label or address} for address in args.emails]
    if args.phones:
        body["businessPhones"] = args.phones
    if not body:
        fail("nothing to build: supply a contact field")
    return body


def main(argv):
    parser = argparse.ArgumentParser(prog="m365-write.py")
    subparsers = parser.add_subparsers(dest="command", required=True)

    event = subparsers.add_parser("event")
    event.add_argument("--title")
    event.add_argument("--start")
    event.add_argument("--end")
    event.add_argument("--tz", dest="timezone")
    event.add_argument("--location")
    event.add_argument("--description")
    event.add_argument("--attendee", action="append", default=[], dest="attendees")

    contact = subparsers.add_parser("contact")
    contact.add_argument("--display-name")
    contact.add_argument("--given-name")
    contact.add_argument("--surname")
    contact.add_argument("--email", action="append", default=[], dest="emails")
    contact.add_argument("--phone", action="append", default=[], dest="phones")
    contact.add_argument("--mobile")
    contact.add_argument("--company")
    contact.add_argument("--job-title")
    contact.add_argument("--notes")

    args = parser.parse_args(argv)
    body = build_event(args) if args.command == "event" else build_contact(args)
    print(json.dumps(body, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
