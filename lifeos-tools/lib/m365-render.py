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


def recipients(message, key):
    return ", ".join(filter(None, (address(item) for item in message.get(key) or [])))


def message_body(message, body_limit):
    body = message.get("body") or {}
    content = clean_text(body.get("content") or message.get("bodyPreview") or "", body.get("contentType"))
    return truncate(content, body_limit) if body_limit > 0 else content


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
        content = message_body(message, args.body_limit)
        lines.extend(
            [
                f"### {message.get('receivedDateTime') or 'unknown date'} - {subject}",
                "",
                f"- From: {address(message.get('from')) or 'unknown'}",
                f"- To: {recipients(message, 'toRecipients')}",
                f"- Cc: {recipients(message, 'ccRecipients')}",
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


def attachment_summary(item):
    parts = [item.get("name") or "(unnamed)", item.get("contentType") or "", f"{item.get('size') or 0} bytes"]
    if item.get("isInline"):
        parts.append("inline")
    return " | ".join(part for part in parts if part)


def render_message(args, message):
    """One message read by ID from any folder; the same fields as the Inbox snapshot plus folder, sent time, Bcc, and attachment names."""
    lines = [f"# {message.get('subject') or '(no subject)'}", ""]
    fields = [
        ("Received", message.get("receivedDateTime")),
        ("Sent", message.get("sentDateTime")),
        ("From", address(message.get("from")) or "unknown"),
        ("To", recipients(message, "toRecipients")),
        ("Cc", recipients(message, "ccRecipients")),
        ("Bcc", recipients(message, "bccRecipients")),
        ("Reply-To", recipients(message, "replyTo")),
        ("Folder", message.get("folder")),
        ("Read", "yes" if message.get("isRead") else "no"),
        ("Draft", "yes" if message.get("isDraft") else ""),
        ("Importance", message.get("importance") or "normal"),
        ("Categories", ", ".join(message.get("categories") or [])),
        ("Conversation ID", f"`{message['conversationId']}`" if message.get("conversationId") else ""),
        ("Message ID", f"`{message.get('id') or ''}`"),
        ("Outlook", message.get("webLink")),
        ("Unsubscribe", unsubscribe_line(message)),
    ]
    lines.extend(f"- {label}: {value}" for label, value in fields if value)
    attachments = message.get("attachments") or []
    if attachments:
        lines.append("- Attachments:")
        lines.extend(f"  - {attachment_summary(item)}" for item in attachments)
    content = message_body(message, args.body_limit)
    lines.extend(["- Body:", "", quote(content) if content else "    _No body text._"])
    return "\n".join(lines).rstrip() + "\n"



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
