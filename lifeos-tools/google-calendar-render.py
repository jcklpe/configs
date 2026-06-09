#!/usr/bin/env python3
"""Render Google Calendar events as an agent-readable combined agenda."""

import html
import json
import re
import sys
from collections import defaultdict
from datetime import date, timedelta
from html.parser import HTMLParser


DESCRIPTION_LIMIT = 800
BLOCK_TAGS = {
    "address",
    "article",
    "aside",
    "blockquote",
    "br",
    "div",
    "h1",
    "h2",
    "h3",
    "h4",
    "h5",
    "h6",
    "li",
    "ol",
    "p",
    "section",
    "table",
    "tr",
    "ul",
}


class DescriptionCleaner(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.parts = []
        self.links = []

    def newline(self):
        if self.parts and not self.parts[-1].endswith("\n"):
            self.parts.append("\n")

    def handle_starttag(self, tag, attrs):
        tag = tag.lower()
        attrs = dict(attrs)
        if tag in BLOCK_TAGS:
            self.newline()
        if tag == "li":
            self.parts.append("- ")
        if tag == "a":
            self.links.append((attrs.get("href") or "", len(self.parts)))

    def handle_endtag(self, tag):
        tag = tag.lower()
        if tag == "a" and self.links:
            href, start_index = self.links.pop()
            linked_text = "".join(self.parts[start_index:]).strip()
            if href and href not in linked_text:
                if linked_text:
                    self.parts.append(f" ({href})")
                else:
                    self.parts.append(href)
        if tag in BLOCK_TAGS and tag != "br":
            self.newline()

    def handle_data(self, data):
        self.parts.append(data)

    def text(self):
        return "".join(self.parts)


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


def inline_text(value):
    return re.sub(r"\s+", " ", html.unescape(value or "").replace("\xa0", " ")).strip()


def normalize_description_text(text):
    text = html.unescape(text or "").replace("\r", "")
    if re.search(r"<[A-Za-z/!][^>]*>", text):
        cleaner = DescriptionCleaner()
        cleaner.feed(text)
        cleaner.close()
        text = cleaner.text()
    text = html.unescape(text).replace("\xa0", " ")

    lines = []
    blank = False
    for line in text.split("\n"):
        line = re.sub(r"[ \t]+", " ", line).strip()
        if not line:
            if lines and not blank:
                lines.append("")
            blank = True
            continue
        lines.append(line)
        blank = False

    while lines and not lines[-1]:
        lines.pop()

    return "\n".join(lines)


def truncate_description(text):
    if len(text) <= DESCRIPTION_LIMIT:
        return text

    truncated = text[:DESCRIPTION_LIMIT].rstrip()
    split_at = max(truncated.rfind("\n"), truncated.rfind(" "))
    if split_at > DESCRIPTION_LIMIT * 0.7:
        truncated = truncated[:split_at].rstrip()
    return f"{truncated}\n\n[description truncated]"


def meeting_links(event):
    if event.get("_meeting_links"):
        return event["_meeting_links"]

    links = []

    hangout_link = event.get("hangoutLink") or ""
    if hangout_link:
        links.append(hangout_link)

    conference_data = event.get("conferenceData") or {}
    for entry_point in conference_data.get("entryPoints") or []:
        uri = entry_point.get("uri") or ""
        if uri and uri.startswith(("http://", "https://")) and uri not in links:
            links.append(uri)

    return links


def calendar_label(event):
    names = event.get("_calendar_summaries") or []
    if not names:
        name = event.get("_calendar_summary") or ""
        names = [name] if name else []
    return ", ".join(names)


def append_common_parts(parts, event):
    calendar_name = calendar_label(event)
    if calendar_name:
        parts.append(f"calendar: {calendar_name}")
    location = inline_text(event.get("location") or "")
    link = event.get("htmlLink") or ""
    if location:
        parts.append(f"location: {location}")
    links = meeting_links(event)
    if links:
        parts.append(f"meeting: {', '.join(links)}")
    if link:
        parts.append(link)


def event_description(event):
    description = truncate_description(normalize_description_text(event.get("description") or ""))
    if not description:
        return ""
    return "\n  - Description:\n\n" + quote_lines(description, "    ")


def add_occurrence(occurrences, day, sort_group, sort_time, line, description=""):
    occurrences[day.isoformat()].append(
        {
            "sort_group": sort_group,
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
    summary = inline_text(event.get("summary")) or "Untitled event"

    for day in date_range(start, end_inclusive):
        parts = [f"- all day - {summary}"]
        if multi_day:
            label = "multi-day" if day == start else "continues"
            parts[0] += (
                f" ({label}, {start.isoformat()} through {end_inclusive.isoformat()}; "
                f"end {end_exclusive.isoformat()} exclusive)"
            )
        append_common_parts(parts, event)
        add_occurrence(occurrences, day, 0, "00:00", " | ".join(parts), event_description(event) if day == start else "")


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
    summary = inline_text(event.get("summary")) or "Untitled event"
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
        add_occurrence(occurrences, day, 1, sort_time, " | ".join(parts), event_description(event) if day == start_day else "")


def event_key(event):
    event_id = event.get("id") or ""
    if not event_id:
        return None
    return "|".join(
        [
            event_id,
            inline_text(event.get("summary")),
            json.dumps(event.get("start") or {}, sort_keys=True),
            json.dumps(event.get("end") or {}, sort_keys=True),
        ]
    )


def merge_missing_event_data(target, source):
    for field in ("description", "location", "htmlLink", "hangoutLink"):
        if not target.get(field) and source.get(field):
            target[field] = source[field]
    if not target.get("conferenceData") and source.get("conferenceData"):
        target["conferenceData"] = source["conferenceData"]

    links = meeting_links(target)
    for link in meeting_links(source):
        if link not in links:
            links.append(link)
    if links:
        target["_meeting_links"] = links


def merged_events(calendar_events):
    merged = []
    by_key = {}

    for calendar, events in calendar_events:
        name = calendar.get("summary") or calendar.get("id") or "Calendar"
        for event in events.get("items", []):
            if event.get("status") == "cancelled":
                continue
            event = dict(event)
            event["_calendar_summaries"] = [name]
            key = event_key(event)
            if key and key in by_key:
                existing = by_key[key]
                if name not in existing["_calendar_summaries"]:
                    existing["_calendar_summaries"].append(name)
                merge_missing_event_data(existing, event)
                continue
            if key:
                by_key[key] = event
            merged.append(event)

    return merged


def add_events(events, occurrences):
    for event in events:
        if event.get("status") == "cancelled":
            continue
        if event.get("start", {}).get("date"):
            expand_all_day(event, occurrences)
        else:
            expand_timed(event, occurrences)


def render_combined(calendar_events):
    occurrences = defaultdict(list)
    add_events(merged_events(calendar_events), occurrences)

    lines = ["## Combined Agenda", ""]
    if not occurrences:
        lines.append("_No events across synced calendars in this window._")
        return "\n".join(lines) + "\n"

    for day in sorted(occurrences):
        lines.extend([f"### {day}", ""])
        seen = set()
        for occurrence in sorted(
            occurrences[day],
            key=lambda item: (item["sort_group"], item["sort_time"], item["line"]),
        ):
            seen_key = (occurrence["line"], occurrence["description"])
            if seen_key in seen:
                continue
            seen.add(seen_key)
            lines.append(occurrence["line"])
            if occurrence["description"]:
                lines.append(occurrence["description"])
                lines.append("")
        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def main(argv):
    if len(argv) < 3 or len(argv[1:]) % 2 != 0:
        print("Usage: google-calendar-render.py CALENDAR_JSON EVENTS_JSON [CALENDAR_JSON EVENTS_JSON ...]", file=sys.stderr)
        return 1

    calendar_events = []
    args = argv[1:]
    for index in range(0, len(args), 2):
        with open(args[index], "r", encoding="utf-8") as handle:
            calendar = json.load(handle)
        with open(args[index + 1], "r", encoding="utf-8") as handle:
            events = json.load(handle)
        calendar_events.append((calendar, events))

    print(render_combined(calendar_events), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
