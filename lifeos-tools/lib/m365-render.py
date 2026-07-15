#!/usr/bin/env python3
"""Render bounded Microsoft Graph mail, calendar, and contact snapshots."""

import argparse
import html
import json
import re
import sys
from html.parser import HTMLParser


class HtmlCleaner(HTMLParser):
    block_tags = {"br", "div", "li", "p", "tr", "table", "ul", "ol", "blockquote", "h1", "h2", "h3", "h4"}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.parts = []
        self.links = []

    def newline(self):
        if self.parts and not self.parts[-1].endswith("\n"):
            self.parts.append("\n")

    def handle_starttag(self, tag, attrs):
        tag = tag.lower()
        values = dict(attrs)
        if tag in self.block_tags:
            self.newline()
        if tag == "li":
            self.parts.append("- ")
        if tag == "a":
            self.links.append((values.get("href") or "", len(self.parts)))

    def handle_endtag(self, tag):
        tag = tag.lower()
        if tag == "a" and self.links:
            href, start = self.links.pop()
            text = "".join(self.parts[start:]).strip()
            if href and href not in text:
                self.parts.append(f" ({href})" if text else href)
        if tag in self.block_tags and tag != "br":
            self.newline()

    def handle_data(self, data):
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
                f"- Conversation ID: `{message.get('conversationId') or ''}`",
                f"- Message ID: `{message.get('id') or ''}`",
            ]
        )
        if message.get("webLink"):
            lines.append(f"- Outlook: {message['webLink']}")
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
    args = parser.parse_args(argv)
    with open(args.input, "r", encoding="utf-8") as handle:
        data = json.load(handle)
    if args.command == "mail":
        output = render_mail(args, data)
    elif args.command == "calendar":
        output = render_calendar(args, data)
    else:
        output = render_contacts(args, data)
    print(output, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
