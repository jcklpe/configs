#!/usr/bin/env python3
"""Normalize Microsoft 365 calendar events into the Google Calendar event shape.

Input is the JSON written by `_m365_calendar_fetch` ({"calendars": [{id, name, events}]}),
fetched with times in UTC. Output is one Google-shaped (calendar, events) JSON pair per
calendar, written to OUTDIR, so google-calendar-render.py can render both providers as one
agenda. Paths are printed one per line, calendar file then events file.
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

TEAMS_URL = re.compile(r"https://teams\.microsoft\.com/\S+")
# Teams appends its join block after a line of underscores; everything from that rule on is boilerplate.
TEAMS_RULE = re.compile(r"(?m)^_{10,}\s*$")


def local_iso(value, zone):
    """Graph dateTime in UTC (no offset, 7-digit fraction) -> ISO string with the zone's offset."""
    if not value:
        return ""
    base = value.split(".")[0]
    moment = datetime.fromisoformat(base).replace(tzinfo=timezone.utc)
    return moment.astimezone(zone).isoformat(timespec="seconds")


def strip_teams(body):
    text = (body or "").replace("\r", "")
    match = None
    for candidate in TEAMS_RULE.finditer(text):
        if "Microsoft Teams" in text[candidate.end():candidate.end() + 400]:
            match = candidate
            break
    if match:
        text = text[: match.start()]
    return text.strip()


def join_links(event):
    links = []
    online = (event.get("onlineMeeting") or {}).get("joinUrl") or ""
    if online:
        links.append(online)
    for url in TEAMS_URL.findall((event.get("body") or {}).get("content") or ""):
        url = url.rstrip(">)].,")
        if url not in links and not links:
            links.append(url)
    return links


def normalize_event(event, zone):
    start = event.get("start") or {}
    end = event.get("end") or {}
    out = {
        "id": "m365:" + (event.get("id") or ""),
        "summary": event.get("subject") or "",
        "description": strip_teams((event.get("body") or {}).get("content") or ""),
        "location": ((event.get("location") or {}).get("displayName") or ""),
        "htmlLink": event.get("webLink") or "",
    }
    if event.get("iCalUId"):
        out["iCalUID"] = event["iCalUId"]
    if event.get("seriesMasterId"):
        out["recurringEventId"] = "m365:" + event["seriesMasterId"]
    if event.get("isCancelled"):
        out["status"] = "cancelled"
    if event.get("isAllDay"):
        # All-day events are floating dates in Graph; the date part is the calendar date.
        out["start"] = {"date": (start.get("dateTime") or "")[:10]}
        out["end"] = {"date": (end.get("dateTime") or "")[:10]}
    else:
        out["start"] = {"dateTime": local_iso(start.get("dateTime"), zone)}
        out["end"] = {"dateTime": local_iso(end.get("dateTime"), zone)}
    links = join_links(event)
    if links:
        out["conferenceData"] = {"entryPoints": [{"entryPointType": "video", "uri": link} for link in links]}
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True)
    parser.add_argument("--timezone", required=True, help="IANA zone of the target agenda, e.g. America/Chicago")
    parser.add_argument("--alias", required=True)
    parser.add_argument("--outdir", required=True)
    args = parser.parse_args()
    try:
        zone = ZoneInfo(args.timezone)
    except (ZoneInfoNotFoundError, ValueError):
        print(f"ERROR: not an IANA time zone: {args.timezone!r}", file=sys.stderr)
        return 1
    with open(args.input, "r", encoding="utf-8") as handle:
        data = json.load(handle)
    for index, calendar in enumerate(data.get("calendars") or []):
        name = calendar.get("name") or calendar.get("id") or "Calendar"
        meta = {"id": "m365:" + (calendar.get("graphId") or calendar.get("id") or str(index)),
                "summary": f"{args.alias} (Microsoft 365): {name}"}
        items = [normalize_event(event, zone) for event in calendar.get("events") or []]
        meta_path = os.path.join(args.outdir, f"m365-{args.alias}-{index}-calendar.json")
        events_path = os.path.join(args.outdir, f"m365-{args.alias}-{index}-events.json")
        with open(meta_path, "w", encoding="utf-8") as handle:
            json.dump(meta, handle)
        with open(events_path, "w", encoding="utf-8") as handle:
            json.dump({"items": items}, handle)
        print(meta_path)
        print(events_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
