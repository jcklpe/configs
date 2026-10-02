#!/usr/bin/env python3
"""Render bounded Microsoft Graph mail, calendar, contact, and Planner snapshots."""

import argparse
import html
import json
import re
import sys
from html.parser import HTMLParser


class HtmlCleaner(HTMLParser):
    block_tags = {"br", "div", "li", "p", "tr", "table", "ul", "ol", "blockquote", "h1", "h2", "h3", "h4"}
    # Content inside these tags is never message text.
    skip_tags = {"style", "script", "head", "title"}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.parts = []
        self.links = []
        self.skip_depth = 0

    def newline(self):
        if self.parts and not self.parts[-1].endswith("\n"):
            self.parts.append("\n")

    def handle_starttag(self, tag, attrs):
        tag = tag.lower()
        values = dict(attrs)
        if tag in self.skip_tags:
            self.skip_depth += 1
            return
        if tag in self.block_tags:
            self.newline()
        if tag == "li":
            self.parts.append("- ")
        if tag == "a":
            self.links.append((values.get("href") or "", len(self.parts)))

    def handle_endtag(self, tag):
        tag = tag.lower()
        if tag in self.skip_tags:
            self.skip_depth = max(0, self.skip_depth - 1)
            return
        if tag == "a" and self.links:
            href, start = self.links.pop()
            text = "".join(self.parts[start:]).strip()
            if href and href not in text:
                self.parts.append(f" ({href})" if text else href)
        if tag in self.block_tags and tag != "br":
            self.newline()

    def handle_data(self, data):
        if self.skip_depth:
            return
        self.parts.append(data)

    def text(self):
        return "".join(self.parts)


def clean_text(value, content_type="text"):
    text = value or ""
    if (content_type or "").lower() == "html" or re.search(r"<[^>]+>", text):
        cleaner = HtmlCleaner()
        cleaner.feed(text)
        cleaner.close()
        text = cleaner.text()
    text = html.unescape(text).replace("\r", "").replace("\xa0", " ")
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


def truncate(text, limit):
    if len(text) <= limit:
        return text
    clipped = text[:limit].rstrip()
    split_at = max(clipped.rfind("\n"), clipped.rfind(" "))
    if split_at > limit * 0.7:
        clipped = clipped[:split_at].rstrip()
    return f"{clipped}\n\n[content truncated]"


def quote(text):
    return "\n".join(f"    > {line}" for line in text.split("\n"))


def address(item):
    value = (item or {}).get("emailAddress") or item or {}
    name = value.get("name") or ""
    email = value.get("address") or ""
    if name and email and name.lower() != email.lower():
        return f"{name} <{email}>"
    return email or name


def unsubscribe_line(message):
    headers = {(item.get("name") or "").lower(): item.get("value") or "" for item in message.get("internetMessageHeaders") or []}
    value = " ".join(headers.get("list-unsubscribe", "").split())
    if not value:
        return ""
    one_click = "one-click" in headers.get("list-unsubscribe-post", "").lower()
    return value + (" (one-click supported)" if one_click else "")


def render_mail(args, data):
    lines = [
        f"# Microsoft 365 Mail - {args.alias}",
        "",
        f"Last refreshed: {args.refreshed}",
        "",
        f"Account email: `{args.email}`",
        "",
        f"Folder: `Inbox`",
        "",
        f"Window: last {args.days} days",
        "",
        f"Max results: {args.max_results}",
        "",
        "## Messages",
        "",
    ]
    messages = data.get("value") or []
    if not messages:
        lines.append("_No messages matched this sync window._")
        return "\n".join(lines) + "\n"
    for message in messages:
        subject = message.get("subject") or "(no subject)"
        body = message.get("body") or {}
        content = truncate(clean_text(body.get("content") or message.get("bodyPreview") or "", body.get("contentType")), args.body_limit)
        lines.extend(
            [
                f"### {message.get('receivedDateTime') or 'unknown date'} - {subject}",
                "",
                f"- From: {address(message.get('from')) or 'unknown'}",
                f"- To: {', '.join(filter(None, (address(item) for item in message.get('toRecipients') or [])))}",
                f"- Cc: {', '.join(filter(None, (address(item) for item in message.get('ccRecipients') or [])))}",
                f"- Importance: {message.get('importance') or 'normal'}",
                f"- Read: {'yes' if message.get('isRead') else 'no'}",
                f"- Attachments: {'yes' if message.get('hasAttachments') else 'no'}",
                f"- Categories: {', '.join(message.get('categories') or [])}",
                f"- Conversation ID: `{message.get('conversationId') or ''}`",
                f"- Message ID: `{message.get('id') or ''}`",
            ]
        )
        if message.get("webLink"):
            lines.append(f"- Outlook: {message['webLink']}")
        unsubscribe = unsubscribe_line(message)
        if unsubscribe:
            lines.append(f"- Unsubscribe: {unsubscribe}")
        if content:
            lines.extend(["- Body:", "", quote(content), ""])
        else:
            lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def event_start(event):
    start = event.get("start") or {}
    return start.get("dateTime") or ""


def render_calendar(args, data):
    lines = [
        f"# Microsoft 365 Calendar - {args.alias}",
        "",
        f"Last refreshed: {args.refreshed}",
        "",
        f"Account email: `{args.email}`",
        "",
        f"Window: {args.start} to {args.end}",
        "",
        f"Response time zone: `{args.timezone}`",
        "",
        "## Events",
        "",
    ]
    flattened = []
    for calendar in data.get("calendars") or []:
        for event in calendar.get("events") or []:
            flattened.append((calendar, event))
    flattened.sort(key=lambda item: event_start(item[1]))
    if not flattened:
        lines.append("_No events matched this calendar window._")
        return "\n".join(lines) + "\n"
    for calendar, event in flattened:
        start = event.get("start") or {}
        end = event.get("end") or {}
        body = event.get("body") or {}
        description = truncate(clean_text(body.get("content") or event.get("bodyPreview") or "", body.get("contentType")), args.description_limit)
        attendees = [address(item) for item in event.get("attendees") or []]
        lines.extend(
            [
                f"### {start.get('dateTime') or 'unknown time'} - {event.get('subject') or '(untitled event)'}",
                "",
                f"- Calendar: {calendar.get('name') or calendar.get('id') or 'Calendar'}",
                f"- Calendar ID: `{calendar.get('id') or ''}`",
                f"- Event ID: `{event.get('id') or ''}`",
                f"- Start: {start.get('dateTime') or ''} ({start.get('timeZone') or args.timezone})",
                f"- End: {end.get('dateTime') or ''} ({end.get('timeZone') or args.timezone})",
                f"- All day: {'yes' if event.get('isAllDay') else 'no'}",
                f"- Location: {(event.get('location') or {}).get('displayName') or ''}",
                f"- Organizer: {address(event.get('organizer'))}",
                f"- Attendees: {', '.join(filter(None, attendees))}",
                f"- Online meeting: {'yes' if event.get('isOnlineMeeting') else 'no'}",
            ]
        )
        if event.get("webLink"):
            lines.append(f"- Outlook: {event['webLink']}")
        if description:
            lines.extend(["- Description:", "", quote(description), ""])
        else:
            lines.append("")
    return "\n".join(lines).rstrip() + "\n"


def render_contacts(args, data):
    lines = [
        f"# Microsoft 365 Contacts - {args.alias}",
        "",
        f"Last refreshed: {args.refreshed}",
        "",
        f"Account email: `{args.email}`",
        "",
        f"Max results: {args.max_results}",
        "",
        "## Contacts",
        "",
    ]
    contacts = sorted(data.get("value") or [], key=lambda item: (item.get("displayName") or "").lower())
    if not contacts:
        lines.append("_No Outlook contacts were found._")
        return "\n".join(lines) + "\n"
    for contact in contacts:
        emails = [item.get("address") or "" for item in contact.get("emailAddresses") or []]
        phones = list(contact.get("businessPhones") or [])
        if contact.get("mobilePhone"):
            phones.append(contact["mobilePhone"])
        notes = truncate(clean_text(contact.get("personalNotes") or ""), args.notes_limit)
        lines.extend(
            [
                f"### {contact.get('displayName') or contact.get('givenName') or '(unnamed contact)'}",
                "",
                f"- Contact ID: `{contact.get('id') or ''}`",
                f"- Given name: {contact.get('givenName') or ''}",
                f"- Surname: {contact.get('surname') or ''}",
                f"- Email: {', '.join(filter(None, emails))}",
                f"- Phone: {', '.join(filter(None, phones))}",
                f"- Company: {contact.get('companyName') or ''}",
                f"- Job title: {contact.get('jobTitle') or ''}",
            ]
        )
        if notes:
            lines.extend(["- Notes:", "", quote(notes), ""])
        else:
            lines.append("")
    return "\n".join(lines).rstrip() + "\n"


PLANNER_PRIORITY = [(1, "urgent"), (4, "important"), (7, "medium"), (10, "low")]


def planner_priority(value):
    if value is None:
        return "medium"
    for ceiling, name in PLANNER_PRIORITY:
        if value <= ceiling:
            return name
    return "low"


def planner_status(task):
    percent = task.get("percentComplete") or 0
    if percent >= 100:
        return "done"
    return "in progress" if percent > 0 else "not started"


def planner_person(users, user_id, me):
    if not user_id:
        return ""
    name = (users.get(user_id) or {}).get("displayName") or user_id
    return f"{name} (you)" if user_id == me else name


def planner_date(value):
    return (value or "")[:10]


def render_planner_task(lines, task, plan_entry, users, me, limit):
    categories = (plan_entry.get("details") or {}).get("categoryDescriptions") or {}
    labels = [categories.get(key) or key for key, on in sorted((task.get("appliedCategories") or {}).items()) if on]
    assignees = [planner_person(users, uid, me) for uid in sorted((task.get("assignments") or {}).keys())]
    details = (plan_entry.get("taskDetails") or {}).get(task.get("id")) or {}
    lines.extend([f"#### {task.get('title') or '(untitled task)'}", ""])
    lines.append(f"- Status: {planner_status(task)}")
    if task.get("dueDateTime"):
        lines.append(f"- Due: {planner_date(task.get('dueDateTime'))}")
    if task.get("startDateTime"):
        lines.append(f"- Start: {planner_date(task.get('startDateTime'))}")
    lines.append(f"- Priority: {planner_priority(task.get('priority'))}")
    lines.append(f"- Assignees: {', '.join(assignees) if assignees else 'unassigned'}")
    if labels:
        lines.append(f"- Labels: {', '.join(labels)}")
    created_by = ((task.get("createdBy") or {}).get("user") or {}).get("id")
    lines.append(f"- Created: {planner_date(task.get('createdDateTime'))}" + (f" by {planner_person(users, created_by, me)}" if created_by else ""))
    lines.append(f"- Task ID: `{task.get('id') or ''}`")
    description = truncate(clean_text(details.get("description") or ""), limit)
    if description:
        lines.extend(["- Description:", "", quote(description), ""])
    checklist = sorted((details.get("checklist") or {}).values(), key=lambda item: item.get("orderHint") or "")
    if checklist:
        lines.append("- Checklist:")
        for item in checklist:
            mark = "x" if item.get("isChecked") else " "
            lines.append(f"  - [{mark}] {item.get('title') or ''}")
    lines.append("")


def render_planner(args, data):
    users = data.get("users") or {}
    me = args.me
    lines = [
        f"# Microsoft 365 Planner - {args.alias}",
        "",
        f"Last refreshed: {args.refreshed}",
        "",
        f"Account email: `{args.email}`",
        "",
        "Generated snapshot of the plans configured for this account. Do not edit by hand; change Planner through `lifeos m365 planner` and re-sync.",
        "",
    ]
    plans = data.get("plans") or []
    if not plans:
        lines.append("_No plans are configured._")
        return "\n".join(lines) + "\n"
    for entry in plans:
        plan = entry.get("plan") or {}
        config = entry.get("config") or {}
        tasks = entry.get("tasks") or []
        open_tasks = [task for task in tasks if (task.get("percentComplete") or 0) < 100]
        done_tasks = [task for task in tasks if (task.get("percentComplete") or 0) >= 100]
        mine = [task for task in open_tasks if me and me in (task.get("assignments") or {})]
        lines.extend([f"## {plan.get('title') or config.get('name') or '(untitled plan)'}", ""])
        if config.get("context"):
            lines.extend([config["context"], ""])
        lines.extend(
            [
                f"- Plan ID: `{plan.get('id') or ''}`",
                f"- Group ID: `{(plan.get('container') or {}).get('containerId') or plan.get('owner') or ''}`",
                f"- Open tasks: {len(open_tasks)} | Done: {len(done_tasks)} | Open and assigned to you: {len(mine)}",
                "",
            ]
        )
        buckets = sorted(entry.get("buckets") or [], key=lambda item: item.get("orderHint") or "")
        known = {bucket.get("id") for bucket in buckets}
        groups = [(bucket.get("name") or "(unnamed bucket)", bucket.get("id")) for bucket in buckets]
        if any(task.get("bucketId") not in known for task in open_tasks):
            groups.append(("(no bucket)", None))
        for name, bucket_id in groups:
            in_bucket = [task for task in open_tasks if (task.get("bucketId") if task.get("bucketId") in known else None) == bucket_id]
            lines.extend([f"### {name}", ""])
            if not in_bucket:
                lines.extend(["_No open tasks._", ""])
                continue
            in_bucket.sort(key=lambda task: (task.get("dueDateTime") or "9999", task.get("orderHint") or ""))
            for task in in_bucket:
                render_planner_task(lines, task, entry, users, me, args.description_limit)
        if done_tasks:
            names = {bucket.get("id"): bucket.get("name") for bucket in buckets}
            lines.extend(["### Completed", ""])
            done_tasks.sort(key=lambda task: task.get("completedDateTime") or "", reverse=True)
            for task in done_tasks:
                completed_by = ((task.get("completedBy") or {}).get("user") or {}).get("id")
                who = f" by {planner_person(users, completed_by, me)}" if completed_by else ""
                lines.append(f"- {task.get('title') or '(untitled task)'} | {names.get(task.get('bucketId')) or 'no bucket'} | completed {planner_date(task.get('completedDateTime'))}{who} | `{task.get('id') or ''}`")
            lines.append("")
    return "\n".join(lines).rstrip() + "\n"


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
    elif args.command == "planner":
        output = render_planner(args, data)
    else:
        output = render_contacts(args, data)
    print(output, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
