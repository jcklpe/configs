#!/usr/bin/env python3
"""Render Google Calendar events as agent-readable Markdown."""

import json
import sys
from collections import defaultdict
from datetime import date, timedelta


def parse_date(value):
    return date.fromisoformat(value)


def date_range(start, end_inclusive):
    current = start
    while current <= end_inclusive:
        yield current
        current += timedelta(days=1)


def date_part(value):
    return value[:10]


def time_part(value):
    return value[11:16] if len(value) >= 16 else ""


def quote_lines(text, indent):
    return "\n".join(f"{indent}> {line}" for line in text.replace("\r", "").split("\n"))


def append_common_parts(parts, event):
    location = event.get("location") or ""
    link = event.get("htmlLink") or ""
    if location:
        parts.append(location)
    if link:
        parts.append(link)


def event_description(event):
    description = event.get("description") or ""
    if not description:
        return ""
    return "\n  - Description:\n" + quote_lines(description, "    ")


def add_occurrence(occurrences, day, sort_time, line, description=""):
    occurrences[day.isoformat()].append(
        {
            "sort_time": sort_time,
            "line": line,
            "description": description,
        }
    )


def expand_all_day(event, occurrences):
    start = parse_date(event["start"]["date"])
    end_exclusive = parse_date(event.get("end", {}).get("date") or event["start"]["date"])
    if end_exclusive <= start:
        end_exclusive = start + timedelta(days=1)

    end_inclusive = end_exclusive - timedelta(days=1)
    multi_day = end_inclusive > start
    summary = event.get("summary") or "Untitled event"

    for day in date_range(start, end_inclusive):
        parts = [f"- all day - {summary}"]
        if multi_day:
            label = "multi-day" if day == start else "continues"
            parts[0] += (
                f" ({label}, {start.isoformat()} through {end_inclusive.isoformat()}; "
                f"end {end_exclusive.isoformat()} exclusive)"
            )
        append_common_parts(parts, event)
        add_occurrence(occurrences, day, "00:00", " | ".join(parts), event_description(event) if day == start else "")


def timed_end_inclusive_date(start_day, end_day, end_time):
    if end_day <= start_day:
        return start_day
    if end_time == "00:00":
        return end_day - timedelta(days=1)
    return end_day


def expand_timed(event, occurrences):
    start_value = event.get("start", {}).get("dateTime") or ""
    end_value = event.get("end", {}).get("dateTime") or start_value
    if not start_value:
        return

    start_day = parse_date(date_part(start_value))
    end_day = parse_date(date_part(end_value)) if end_value else start_day
    start_time = time_part(start_value) or "00:00"
    end_time = time_part(end_value) or start_time
    end_inclusive = timed_end_inclusive_date(start_day, end_day, end_time)
    if end_inclusive < start_day:
        end_inclusive = start_day

    multi_day = end_inclusive > start_day
    summary = event.get("summary") or "Untitled event"
    range_note = (
        f"{start_day.isoformat()} {start_time} to {end_day.isoformat()} {end_time}"
        if multi_day
        else ""
    )

    for day in date_range(start_day, end_inclusive):
        if not multi_day:
            time_label = f"{start_time}-{end_time}"
            continuation = ""
            sort_time = start_time
        elif day == start_day:
            time_label = f"{start_time}-continues"
            continuation = f" (continues, {range_note})"
            sort_time = start_time
        elif day == end_inclusive:
            time_label = f"continues-{end_time}"
            continuation = f" (continues, {range_note})"
            sort_time = "00:00"
        else:
            time_label = "continues all day"
            continuation = f" (continues, {range_note})"
            sort_time = "00:00"

        parts = [f"- {time_label} - {summary}{continuation}"]
        append_common_parts(parts, event)
        add_occurrence(occurrences, day, sort_time, " | ".join(parts), event_description(event) if day == start_day else "")


def render(calendar, events):
    name = calendar.get("summary") or calendar.get("id") or "Calendar"
    calendar_id = calendar.get("id") or ""
    occurrences = defaultdict(list)

    for event in events.get("items", []):
        if event.get("status") == "cancelled":
            continue
        if event.get("start", {}).get("date"):
            expand_all_day(event, occurrences)
        else:
            expand_timed(event, occurrences)

    lines = [f"## {name}", ""]
    if calendar_id:
        lines.extend([f"Calendar ID: `{calendar_id}`", ""])

    if not occurrences:
        lines.append("_No events in this window._")
        return "\n".join(lines) + "\n"

    for day in sorted(occurrences):
        lines.extend([f"### {day}", ""])
        for occurrence in sorted(occurrences[day], key=lambda item: (item["sort_time"], item["line"])):
            lines.append(occurrence["line"])
            if occurrence["description"]:
                lines.append(occurrence["description"])
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def main(argv):
    if len(argv) != 3:
        print("Usage: google-calendar-render.py CALENDAR_JSON EVENTS_JSON", file=sys.stderr)
        return 1
    with open(argv[1], "r", encoding="utf-8") as handle:
        calendar = json.load(handle)
    with open(argv[2], "r", encoding="utf-8") as handle:
        events = json.load(handle)
    print(render(calendar, events), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
